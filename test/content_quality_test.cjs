const assert=require('node:assert/strict'),fs=require('node:fs'),L=require('../preview/learning.js');
const bank=JSON.parse(fs.readFileSync('assets/data/questions.json')),types=JSON.parse(fs.readFileSync('assets/data/types.json'));
const quarantined=bank.filter(q=>q.reviewOnly),memory={};
for(const q of quarantined)L.record(memory,q.id,false,'before-audit',1);
for(const mode of [{exam:true},{review:true},{}]){
 const plan=L.plan(bank,memory,{...mode,count:5000});
 assert(plan.every(q=>!q.reviewOnly));
}
const old=quarantined.find(q=>q.kind==='generated');
const state=L.sanitizeState({saved:quarantined.map(q=>q.id),memory,orders:{},attempts:[{answers:[{id:old.id,correct:false}]}],active:{id:'old',exam:false,ids:[old.id],index:0,answers:[]}}, {},bank,types);
assert.deepEqual(state.saved,[]);assert.deepEqual(state.memory,{});assert.equal(state.active,null);
assert.equal(state.attempts[0].answers[0].id,old.id,'Historical attempts retained, not requeued');
console.log('PASS quality gate: quarantined questions cannot return via exams, review, saves, or old sessions');
