const assert=require('node:assert/strict'),fs=require('node:fs'),Engine=require('../preview/lessons/engine.js');
const lessons=JSON.parse(fs.readFileSync('assets/data/lessons.json')).lessons;
let saved;const e=new Engine(lessons,{},s=>{saved=JSON.parse(JSON.stringify(s))},()=>.3),scope=lessons.filter(l=>l.sourceId==='sorular');
e.start(scope);assert.equal(e.session.ids.length,24);assert(!e.session.ids.some(id=>e.questions.get(id).sourceId!=='sorular'));
const q=e.current(),wrong=q.options.find(o=>o!==q.answer);assert(e.answer(wrong));assert(!e.answer(q.answer));assert(e.pending(q.id));assert.equal(e.session.score,0);
const resume=new Engine(lessons,saved);assert.equal(resume.session.selected,wrong);assert.deepEqual(resume.session.options,e.session.options);assert(!resume.answer(q.answer));
e.start(scope,{errorsOnly:true});assert.deepEqual(e.session.ids,[q.id]);e.answer(q.answer);assert(e.pending(q.id));e.next();e.start(scope,{errorsOnly:true});e.answer(q.answer);assert(!e.pending(q.id));e.next();e.start(scope,{errorsOnly:true});assert.equal(e.session.ids.length,0);
let position=-1;for(let i=0;i<10;i++){e.start([lessons[0]]);const q=e.current(),p=e.session.options.indexOf(q.answer);if(position!==-1)assert.notEqual(position,p);position=p;}
assert.throws(()=>e.start([lessons[0],lessons.find(l=>l.sourceId==='file3')]));
const corrupt=new Engine(lessons,{session:{ids:['missing'],index:0},progress:{bad:{streak:90}}});assert.equal(corrupt.session,null);assert.deepEqual(corrupt.progress,{});
const fail=new Engine(lessons,{},()=>{throw Error('quota')});fail.start(scope);assert(fail.error);assert(fail.answer(fail.current().answer));assert(fail.error);
console.log('PASS lesson engine: immediate once-only feedback, errors, two-session mastery, resume, scope, varied stable options, storage failures');
