/* Pure learning rules: shared by browser and automated regression tests. */
(function(root){
const normalize=s=>String(s??'').normalize('NFKC').replace(/[\u064B-\u065F\u0670ـ]/g,'').replace(/[أإآ]/g,'ا').replace(/[.,،؛؟!]/g,'').replace(/\s+/g,' ').trim();
const accepts=(v,a)=>a.some(x=>normalize(v)===normalize(x));
function grade(q,v,mode){switch(mode){case'single':return v===q.answer;case'multi':return Array.isArray(v)&&v.length===q.correct.length&&new Set(v).size===v.length&&q.correct.every(x=>v.includes(x));case'text':return accepts(v,q.accepted);case'order':return Array.isArray(v)&&v.length===q.correct.length&&v.every((x,i)=>x===q.correct[i]);case'match':return Array.isArray(v)&&v.length===q.pairs.length&&q.pairs.every((p,i)=>p.right===v[i]);case'group':return Array.isArray(v)&&v.length===q.parts.length&&q.parts.every((p,i)=>accepts(v[i],p.accepted));default:return false}}
function shuffle(items,rng=Math.random){const a=[...items];for(let i=a.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function varied(items,previous=[],rng=Math.random){const a=shuffle(items,rng);if(a.length>1&&a.every((x,i)=>x===previous[i]))a.push(a.shift());return a}
function pending(memory){return Object.entries(memory).filter(([,v])=>v.wrong>0&&v.streak<2).sort((a,b)=>a[1].last-b[1].last).map(([id])=>Number(id))}
function record(memory,id,correct,sessionId,now=Date.now()){
 const old=memory[id]||{wrong:0,streak:0,total:0,last:0};
 const streak=correct?(old.lastSession===sessionId?old.streak:old.streak+1):0;
 memory[id]={wrong:old.wrong+(correct?0:1),streak,total:old.total+1,last:now,lastSession:sessionId,due:now+(correct?streak>=2?7:1:0)*86400000};
}
function plan(questions,memory,{count=10,section='',type='',source='',variant='',exam=false,review=false,ids=null}={},rng=Math.random){
 const eligible=questions.filter(q=>!q.reviewOnly&&(!source||q.sourceId===source)&&(!variant||q.variant===variant)&&(!section||q.section===section)&&(!type||q.type===type)&&(!ids||ids.includes(q.id))),map=new Map(eligible.map(q=>[q.id,q]));
 // Replay only within the selected source/variant; keep the requested exam size.
 const due=(exam||review)?pending(memory).map(id=>map.get(id)).filter(Boolean):[];
 count=Number.isFinite(count)?Math.max(0,Math.floor(count)):10;
 if(review)return due.slice(0,count);
 const pool=shuffle(eligible.filter(q=>(!section||q.section===section)&&(!type||q.type===type)&&(!ids||ids.includes(q.id))),rng);
 // New material before previously practised material; shuffle preserves variety within a tier.
 const priority=q=>!memory[q.id]?0:memory[q.id].streak<2?1:2;
 pool.sort((a,b)=>priority(a)-priority(b));
 const selected=due.slice(0,Math.max(0,count)),seen=new Set(selected.map(q=>q.id)),concepts=new Set(selected.map(q=>q.conceptKey||q.id));
 const target=Math.max(0,count);
 for(const q of pool){if(selected.length>=target)break;if(!seen.has(q.id)&&!concepts.has(q.conceptKey||q.id)){selected.push(q);seen.add(q.id);concepts.add(q.conceptKey||q.id)}}
 // Small filtered sets can contain several intended variants of the same concept.
 for(const q of pool){if(selected.length>=target)break;if(!seen.has(q.id)){selected.push(q);seen.add(q.id)}}
 return selected;
}
function scopeOf(list){return list.length&&list.every(q=>q.sourceId===list[0].sourceId&&q.variant===list[0].variant)?{source:list[0].sourceId,variant:list[0].variant}:null}
function sourceProgress(questions,memory){const groups=new Map();for(const q of questions.filter(q=>!q.reviewOnly)){const key=q.sourceId+':'+q.variant;if(!groups.has(key))groups.set(key,{source:q.sourceId,variant:q.variant,total:0,tried:0,mastered:0,pending:0});const g=groups.get(key),m=memory[q.id];g.total++;if(m?.total>0||m?.last>0)g.tried++;if(m?.streak>=2)g.mastered++;if(m?.wrong>0&&m.streak<2)g.pending++;}return [...groups.values()]}
function validSession(s,map,modes){
 if(!s||typeof s!=='object'||typeof s.id!=='string'||typeof s.exam!=='boolean'||!Array.isArray(s.ids)||!s.ids.length||new Set(s.ids).size!==s.ids.length||!s.ids.every(id=>map.has(id)&&!map.get(id).reviewOnly)||!Number.isInteger(s.index)||s.index<0||s.index>s.ids.length||!Array.isArray(s.answers)||s.answers.length!==s.index)return false;
 if(!s.answers.every((a,i)=>a&&a.id===s.ids[i]&&(typeof a.correct==='boolean'||(a.correct===null&&s.exam&&modes[map.get(a.id).type].mode==='self'))))return false;
 if(s.index===s.ids.length)return true;
 const q=map.get(s.ids[s.index]),m=modes[q.type].mode;
 if(s.currentRecorded!==undefined&&(typeof s.currentRecorded!=='boolean'||(s.currentRecorded&&(!s.revealed||s.exam||m==='self'))))return false;
 const perm=(a,b)=>Array.isArray(a)&&a.length===b.length&&new Set(a).size===a.length&&a.every(x=>b.includes(x));
 if(!Array.isArray(s.options)||!Number.isInteger(s.hints)||s.hints<0||s.hints>(q.hints||[]).length||typeof s.revealed!=='boolean')return false;
 if(['single','multi'].includes(m)&&!perm(s.options,q.options))return false;
 if(m==='single')return typeof s.selected==='string'&&(!s.selected||q.options.includes(s.selected));
 if(m==='multi')return Array.isArray(s.selected)&&new Set(s.selected).size===s.selected.length&&s.selected.every(v=>q.options.includes(v));
 if(m==='order')return perm(s.selected,q.options);
 if(m==='match'||m==='group'){const parts=m==='match'?q.pairs:q.parts,order=m==='match'?s.pairOrder:s.partOrder;if(!perm(order,parts.map((_,i)=>i))||!Array.isArray(s.selected)||s.selected.length!==parts.length||!s.selected.every(v=>typeof v==='string'))return false;return m!=='match'||perm(s.options,q.pairs.map(p=>p.right));}
 return typeof s.selected==='string';
}
function sanitizeState(raw,defaults,questions,modes,retired=[]){
 const obj=v=>v&&typeof v==='object'&&!Array.isArray(v),array=v=>Array.isArray(v)?v:[],map=new Map(questions.map(q=>[q.id,q]));
 const data={...defaults,...(obj(raw)?raw:{})},eligible=id=>map.has(id)&&!map.get(id).reviewOnly;
 data.saved=[...new Set(array(data.saved).filter(eligible))];
 data.memory=Object.fromEntries(Object.entries(obj(data.memory)?data.memory:{}).filter(([id,v])=>eligible(Number(id))&&obj(v)&&['wrong','streak','last'].every(k=>Number.isFinite(v[k])&&v[k]>=0)).map(([id,v])=>[id,{...v,total:Number.isFinite(v.total)?Math.max(0,v.total):1}]));
 data.orders=Object.fromEntries(Object.entries(obj(data.orders)?data.orders:{}).filter(([id,v])=>eligible(Number(id))&&Array.isArray(v)&&v.every(x=>typeof x==='string')));
 data.attempts=array(data.attempts).filter(a=>obj(a)&&Array.isArray(a.answers)).map(a=>({...a,date:typeof a.date==='string'?a.date:'',answers:a.answers.filter(x=>obj(x)&&(map.has(x.id)||retired.includes(x.id))&&typeof x.correct==='boolean')})).filter(a=>a.answers.length);
 const settings=obj(data.settings)?data.settings:{};data.settings={large:settings.large===true,motion:settings.motion!==false,focus:settings.focus===true,goal:[5,10,15,20].includes(settings.goal)?settings.goal:10};
 data.active=validSession(data.active,map,modes)?data.active:null;data.schema=2;return data;
}
const api={scopeOf,sourceProgress,validSession,sanitizeState,normalize,accepts,grade,shuffle,varied,pending,record,plan};root.Learning=api;if(typeof module!=='undefined')module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
