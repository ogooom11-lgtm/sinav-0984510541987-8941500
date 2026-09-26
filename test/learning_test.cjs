const assert=require('node:assert/strict'),fs=require('node:fs');
const L=require('../preview/learning.js');
const bank=JSON.parse(fs.readFileSync('assets/data/questions.json','utf8'));
const types=JSON.parse(fs.readFileSync('assets/data/types.json','utf8'));
const sample=type=>bank.find(q=>q.type===type&&!q.reviewOnly);
const memory={};const a=sample('choice'),b=sample('short');
L.record(memory,a.id,false,'first',1);L.record(memory,b.id,false,'first',2);
assert.equal(L.plan(bank,memory,{exam:true,count:1,section:'موضوع لا يطابق'}).length,0);
let exam=L.plan(bank,memory,{exam:true,count:2});
assert.deepEqual(new Set(exam.map(q=>q.id)),new Set([a.id,b.id]));
assert.equal(exam.length,2,'Eligible mistakes have priority within the requested count');
L.record(memory,a.id,true,'second',3);assert(L.pending(memory).includes(a.id));
L.record(memory,a.id,true,'second',4);assert(L.pending(memory).includes(a.id),'Cannot master with two responses in the same session');
L.record(memory,a.id,true,'third',5);assert(!L.pending(memory).includes(a.id));
L.record(memory,a.id,false,'fourth',6);assert(L.pending(memory).includes(a.id),'A relapse restores the review queue');
assert(L.pending(memory).includes(b.id),'Open-response mistakes are not silently excluded');
assert(!L.plan(bank,memory,{exam:true,count:20}).some(q=>q.reviewOnly));
const small=[{id:1,conceptKey:'a',section:'x',type:'choice'},{id:2,conceptKey:'a',section:'x',type:'choice'},{id:3,conceptKey:'b',section:'x',type:'choice'}];
assert.equal(new Set(L.plan(small,{}, {count:2}).map(q=>q.conceptKey)).size,2);
let prev=['a','b','c','d'];for(let i=0;i<20;i++){const next=L.varied(prev,prev,()=>0.99);assert.notDeepEqual(next,prev);assert.deepEqual(new Set(next),new Set(prev));prev=next}
for(const q of bank.filter(q=>!q.reviewOnly)){
 const mode=types[q.type].mode;let correct;
 if(mode==='self'){assert.equal(L.grade(q,q.answer,mode),false);continue}
 if(['single','text'].includes(mode))correct=q.answer;
 else if(['multi','order'].includes(mode))correct=q.correct;
 else if(mode==='match')correct=q.pairs.map(p=>p.right);
 else correct=q.parts.map(p=>p.answer);
 assert.equal(L.grade(q,correct,mode),true,`${q.id}/${q.type}`);
 assert.equal(L.grade(q,null,mode),false,`${q.id}/null`);
}
console.log('PASS learning engine: full-bank grading, complete error recall, same-session guard, mastery/relapse, concept diversity, permutation preservation');

for(const source of ['file2','file3'])for(const variant of ['original','modified']){
 const scoped=L.plan(bank,memory,{exam:true,count:50,source,variant});
 assert.equal(scoped.length,source==='file2'&&variant==='original'?38:50);
 assert(scoped.every(q=>q.sourceId===source&&q.variant===variant));
 assert.equal(new Set(scoped.map(q=>q.id)).size,scoped.length);
}
const m={};for(const q of bank.filter(q=>q.sourceId==='file3'&&q.variant==='modified'))L.record(m,q.id,false,'old',q.id);
const capped=L.plan(bank,m,{exam:true,count:50,source:'file3',variant:'modified'});assert.equal(capped.length,50);assert.equal(L.pending(m).length,80);
assert.equal(L.plan(bank,m,{exam:true,count:50,source:'file2',variant:'modified'}).filter(q=>q.sourceId!=='file2').length,0);
console.log('PASS independent sources and modes, 50-question exams, limited exact notes, overflow mistakes retained');
const removedTypes=['blank','missing_word','correct_word','correction','sentence'];
assert(!Object.keys(types).some(k=>removedTypes.includes(k)));
assert(!bank.some(q=>removedTypes.includes(q.type)));
assert(!bank.some(q=>q.nativeBlank&&!q.reviewOnly));
const archived=bank.find(q=>q.nativeBlank),legacy={};L.record(legacy,archived.id,false,'legacy');
assert.equal(L.plan(bank,legacy,{ids:[archived.id],exam:true,count:1}).length,0);
console.log('PASS removed types absent from catalog/bank; original completions never replayed');
