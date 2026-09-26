const {JSDOM}=require('jsdom'),fs=require('node:fs'),assert=require('node:assert/strict');
const dom=new JSDOM(fs.readFileSync('preview/index.html','utf8'),{url:'http://localhost:3000',runScripts:'dangerously'}),w=dom.window,errors=[];
w.scrollTo=()=>{};w.confirm=()=>true;w.addEventListener('error',e=>errors.push(e.message));w.fetch=async url=>({ok:true,json:async()=>JSON.parse(fs.readFileSync('.'+url,'utf8'))});
for(const file of ['learning.js','app.js']){const s=w.document.createElement('script');s.textContent=fs.readFileSync('preview/'+file,'utf8');w.document.body.append(s)}
const e=code=>w.eval(code),$=s=>w.document.querySelector(s);
setTimeout(()=>{try{
 // All supported controls keep legitimate initial drafts across reload restoration.
 for(const type of e('[...new Set(questions.filter(q=>!q.reviewOnly).map(q=>q.type))]')){e(`state.active=null;session=null;startQuiz({ids:[questions.find(q=>q.type==='${type}'&&!q.reviewOnly).id],count:1});pauseQuiz();restore()`);assert(e('state.active'),type+' draft retained');e('resume()');assert(e('session'),type+' draft resumed');e('pauseQuiz()');}
 e("state.active=null;session=null;state.memory={};startQuiz({ids:[questions.find(q=>q.type==='single'&&!q.reviewOnly).id],count:1});session.selected=qnow().options.find(v=>v!==qnow().answer);check()");
 const wrongId=e('qnow().id');assert(e('pending()').includes(wrongId),'Verified wrong answer is saved before Next');assert.equal(e(`state.memory[${wrongId}].wrong`),1);
 e('pauseQuiz();restore();resume();next(false)');assert.equal(e(`state.memory[${wrongId}].wrong`),1,'Next must not record the same verified answer twice');assert.equal(e(`state.memory[${wrongId}].total`),1);
 e("selection={source:'file2',variant:'original'};location.hash='#exam';render()");assert.equal($('#summaryCount').textContent,'0');
 e("$('#examVariant').value='modified';$('#examVariant').onchange()");assert.equal($('#summaryCount').textContent,'50');
 e("state.active=null;startQuiz({source:'file3',variant:'original',count:1,exam:true});input('مسودة محفوظة');pauseQuiz();selection={source:'file2',variant:'modified'};state.scope=selection;persist();resume()");
 assert.equal(e('selection.source'),'file3');assert.equal(e('selection.variant'),'original');assert.equal($('#answerText').value,'مسودة محفوظة');
 e('check()');assert($('.self-review'));e('pauseQuiz();resume()');assert($('.self-review'),'Deferred assessment survives pause and resume');e('assess(0,true)');assert($('.score'));assert.equal(e('state.attempts.at(-1).source'),'file3');
 e("selection={source:'file2',variant:'modified'};state.memory={};for(const t of ['order','match']){const q=questions.find(q=>q.sourceId==='file2'&&q.variant==='modified'&&q.type===t);L.record(state.memory,q.id,false,'x',1)}L.record(state.memory,3000001,false,'x',2);location.hash='#review';render();$('#typeFilter').value='order';filter();reviewFiltered()");
 assert.equal(e('session.ids.length'),1);assert.equal(e('qnow().type'),'order');e('pauseQuiz()');
 e("jumpScope('file2','original')");assert($('#listScopes').textContent.includes('3.txt'));assert($('#questionList').textContent.includes('اختيارات أخرى'));
 e("location.hash='#progress';render()");assert.equal(w.document.querySelectorAll('.source-progress').length,5);assert($('#app').textContent.includes('الملف 3'));
 e("localStorage.setItem(KEY,JSON.stringify({schema:2,saved:'bad',attempts:[{date:'',answers:[{id:3000001,correct:true}]}],memory:{3000001:{wrong:1,streak:0,last:1}},orders:42,settings:{goal:0},active:{ids:[3000001],index:999}}));restore();render()");
 assert.equal(e('state.active'),null);assert.equal(e('state.attempts.length'),1);assert.equal(e('state.settings.goal'),10);assert.equal(e('state.memory[3000001].wrong'),1);assert(e("localStorage.getItem(KEY+'.recovery')"));
 e("state.active=null;startQuiz({source:'file2',variant:'modified',count:1});const realSet=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw new Error('quota')};pauseQuiz();Storage.prototype.setItem=realSet");assert($('#toast').textContent.includes('لم يتم الحفظ'));assert(e('state.active'),'Draft stays in memory after write failure');
 assert.deepEqual(errors,[]);console.log('PASS audit UI: real exam size, correct resumed scope, assessment resume, filtered review, cross-section visibility and partial recovery');
}catch(err){console.error(err);process.exitCode=1}finally{w.close()}},180);
