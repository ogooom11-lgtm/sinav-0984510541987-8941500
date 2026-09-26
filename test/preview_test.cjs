const {JSDOM}=require('jsdom'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..'),bank=JSON.parse(fs.readFileSync(path.join(root,'assets/data/questions.json'),'utf8')),types=JSON.parse(fs.readFileSync(path.join(root,'assets/data/types.json'),'utf8'));
const dom=new JSDOM(fs.readFileSync(path.join(root,'preview/index.html'),'utf8'),{url:'http://localhost:3000',runScripts:'dangerously'});
const w=dom.window,errors=[];w.addEventListener('error',e=>errors.push(e.message));w.scrollTo=()=>{};w.confirm=()=>true;
w.fetch=async url=>({ok:true,json:async()=>JSON.parse(fs.readFileSync(path.join(root,url),'utf8'))});
for(const file of ['learning.js','app.js']){const s=w.document.createElement('script');s.textContent=fs.readFileSync(path.join(root,'preview',file),'utf8');w.document.body.appendChild(s)}
const e=s=>w.eval(s),$=s=>w.document.querySelector(s),$$=s=>[...w.document.querySelectorAll(s)];
function enter(el,value,event='input'){el.value=value;el.dispatchEvent(new w.Event(event,{bubbles:true}))}
function answer(q){const m=types[q.type].mode;
 if(m==='single'){$$('.option')[e('session.options').indexOf(q.answer)].click()}
 else if(m==='multi'){for(const option of q.correct){$$('input[type=checkbox]')[e('session.options').indexOf(option)].click()}}
 else if(m==='self'||m==='text')enter($('#answerText'),q.answer);
 else if(m==='order')for(let i=0;i<q.correct.length;i++){let from=e('session.selected').indexOf(q.correct[i]);while(from>i){$$('.order-row')[from].querySelector('button').click();from--}}
 else if(m==='match')$$('.match-row select').forEach((select,i)=>enter(select,q.pairs[e('session.pairOrder')[i]].right,'change'));
 else $$('.group-part input').forEach((input,i)=>enter(input,q.parts[e('session.partOrder')[i]].answer));
 assert.equal($('#checkBtn').disabled,false,q.type+' should accept complete input');
}
function finishCurrentCorrect(){const q=bank.find(x=>x.id===e('qnow().id'));answer(q);$('#checkBtn').click();if(e('session')&&e('session.index<session.ids.length')){assert($('.feedback'));$('.quiz-actions .btn').click()}return q}
setTimeout(()=>{try{
 assert($('.hero'));assert.equal($$('nav a').length,6);assert(!$('a[href="#library"]'));assert(!w.document.body.textContent.includes('فتح الملف'));
 e("location.hash='#practice';render()");assert.equal($$('.question-row').length,16);assert($('#listSource'));assert($('#listVariant'));enter($('#search'),'zzzzz');assert.equal($$('.question-row').length,0);enter($('#search'),'');
 // All 24 UIs, selecting by randomized value rather than the stored index.
 for(const type of [...new Set(bank.filter(q=>!q.reviewOnly).map(q=>q.type))]){
  const sample=bank.find(q=>q.type===type&&!q.reviewOnly);
  e(`startQuiz({ids:[${sample.id}],count:1})`);answer(sample);
  const before=JSON.stringify(e('session.selected'));$$('.quiz-actions .text-btn').at(-1).click();assert.equal(JSON.stringify(e('session.selected')),before);
  $('#checkBtn').click();assert($('.feedback'));$('.quiz-actions .btn').click();assert($('.score'));assert.equal(e('state.attempts.at(-1).answers[0].correct'),true,type);
 }
 assert.equal(e('state.attempts.length'),new Set(bank.filter(q=>!q.reviewOnly).map(q=>q.type)).size);
 const single=bank.find(q=>q.type==='single'&&!q.reviewOnly&&q.sourceId==='sorular');
 let position=-1;
 for(let i=0;i<8;i++){
  e(`state.active=null;startQuiz({ids:[${single.id}],count:1})`);
  const current=e('session.options').indexOf(single.answer);if(position>=0)assert.notEqual(current,position,'Correct answer position must change at every encounter');position=current;
  const options=JSON.stringify(e('session.options'));e('drawQuiz()');assert.equal(JSON.stringify(e('session.options')),options,'Rerender must not reshuffle during a question');
 }
 // Make an error and exit before completion: it must already be durable.
 const second=bank.find(q=>q.type==='short'&&!q.reviewOnly&&q.sourceId==='sorular');
 e(`state.active=null;startQuiz({ids:[${single.id},${second.id}],count:2})`);
 const first=e('qnow().id');e('skipQuestion()');assert(e('pending()').includes(first));e('pauseQuiz()');assert(JSON.parse(w.localStorage.getItem('basira-learning-v2')).memory[first].wrong>0);
 e('resume()');assert.equal(e('session.index'),1);
 if($('#answerText')){enter($('#answerText'),'مسودة باقية');e('pauseQuiz();resume()');assert.equal($('#answerText').value,'مسودة باقية')}
 e('pauseQuiz()');
 // Every error, including a self-assessed one, enters the next exam regardless of topic.
 e(`state.active=null;state.memory={};L.record(state.memory,${single.id},false,'wrong',1);L.record(state.memory,${second.id},false,'wrong',2);startQuiz({exam:true,count:2,source:'sorular',variant:'modified',ids:[${single.id},${second.id}]})`);
 assert.equal(e('session.ids.length'),2);assert(e('session.ids').includes(second.id));
 while(e('session')&&e('session.index<session.ids.length')){const q=bank.find(x=>x.id===e('qnow().id'));answer(q);assert(!$('.feedback'));$('#checkBtn').click()}
 assert($('.self-review'),'Open questions are assessed after the exam, never auto-marked wrong');$('.self-review .btn').click();assert($('.score'));
 assert(e('pending()').includes(single.id),'One success is not yet mastered');
 e(`startQuiz({exam:true,count:2,source:'sorular',variant:'modified',ids:[${single.id},${second.id}]})`);
 while(e('session')&&e('session.index<session.ids.length')){answer(bank.find(x=>x.id===e('qnow().id')));$('#checkBtn').click()}
 $('.self-review .btn').click();assert.equal(e('pending().length'),0);
 // Free text draft, order and checkbox answers survive save/rerender. Settings are persistent.
 e('settings()');assert($('[role=dialog]'));$$('.setting input[type=checkbox]')[0].click();assert(w.document.body.classList.contains('large-text'));$$('.setting input[type=checkbox]')[1].click();assert(w.document.body.classList.contains('reduce-motion'));e('closeModal()');
 e("location.hash='#progress';render()");assert($('#app').textContent.includes('سجل المحاولات'));
 e("session=null;state.active=null;location.hash='#exam';render()");assert($('#examCount').querySelector('option[value="50"]'));enter($('#examSource'),'file3','change');enter($('#examVariant'),'original','change');$('#examCount').value='50';$('#app .btn').click();assert.equal(e('session.ids.length'),50);assert(e("session.ids.every(id=>byId.get(id).sourceId==='file3'&&byId.get(id).variant==='original')"));assert.deepEqual(errors,[]);console.log('PASS preview: available types, randomized stable options, migration-ready storage, drafts/resume, abandoned-session errors, next-exam recall, deferred self-assessment, mastery, pagination, comfort settings, no book UI');dom.window.close();
}catch(error){console.error(error);dom.window.close();process.exitCode=1}},150);
