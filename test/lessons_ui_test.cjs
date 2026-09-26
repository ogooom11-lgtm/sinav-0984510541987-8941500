const fs=require('node:fs'),assert=require('node:assert/strict'),{JSDOM}=require('jsdom');
const dom=new JSDOM(fs.readFileSync('preview/lessons/index.html','utf8'),{url:'https://example.test',runScripts:'dangerously'}),w=dom.window;
w.fetch=async()=>({ok:true,json:async()=>JSON.parse(fs.readFileSync('assets/data/lessons.json'))});
for(const f of ['engine.js','app.js'])w.eval(fs.readFileSync('preview/lessons/'+f,'utf8'));
setTimeout(()=>{try{
 const click=s=>{const el=w.document.querySelector(s);assert(el,s);el.click();};
 assert.equal(w.document.querySelectorAll('.card').length,3);click('[data-action^="lesson:"]');assert(w.document.querySelector('.fact').textContent.includes('sorular.txt'));
 click('[data-action="read"]');assert(JSON.parse(w.localStorage.getItem('basira-lessons-v1')).read.length===1);
 click('[data-action="practice"]');assert.equal(w.document.querySelector('.feedback'),null);click('[data-option="0"]');assert(w.document.querySelector('.feedback'));assert(w.document.querySelector('.feedback').textContent.includes('الإجابة الصحيحة'));assert([...w.document.querySelectorAll('.option')].every(b=>b.disabled));
 click('[data-action="next"]');assert.equal(w.document.querySelector('.feedback'),null);click('#home');assert(w.document.querySelector('[data-action="resume"]'));click('[data-source="file2"]');assert.equal(w.document.querySelectorAll('.card').length,5);
 console.log('PASS lessons UI: sources, readable evidence, read progress, immediate feedback, locked answers, next and resume');
}catch(e){console.error(e);process.exitCode=1;}finally{w.close();}},100);
