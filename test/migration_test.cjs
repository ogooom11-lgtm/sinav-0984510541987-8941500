const {JSDOM}=require('jsdom'),fs=require('node:fs'),assert=require('node:assert/strict');
const meta=JSON.parse(fs.readFileSync('assets/data/coverage.json','utf8'));
const dom=new JSDOM(fs.readFileSync('preview/index.html','utf8'),{url:'http://localhost:3000',runScripts:'dangerously'}),w=dom.window;
w.scrollTo=()=>{};w.fetch=async url=>({ok:true,json:async()=>JSON.parse(fs.readFileSync('.'+url,'utf8'))});
w.localStorage.setItem('basira-'+meta.datasetId,JSON.stringify({saved:[100001,99999],attempts:[{date:'2026-09-25T09:00:00.000Z',exam:false,answers:[{id:100001,selected:'محاولة',correct:false,self:true}]}]}));
for(const name of ['learning.js','app.js']){const script=w.document.createElement('script');script.textContent=fs.readFileSync('preview/'+name,'utf8');w.document.body.appendChild(script)}
setTimeout(()=>{try{assert.equal(w.eval('state.attempts.length'),1);assert.deepEqual(Array.from(w.eval('state.saved')),[100001]);assert(w.eval('pending()').includes(100001));const persisted=JSON.parse(w.localStorage.getItem('basira-learning-v2'));assert.equal(persisted.memory['100001'].wrong,1);assert.equal(persisted.schema,2);console.log('PASS migration: old sorular saved questions, history and mistakes preserved; stale IDs removed')}catch(e){console.error(e);process.exitCode=1}finally{w.close()}},100);
