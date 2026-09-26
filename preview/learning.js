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
 if(review)return due;
 const pool=shuffle(eligible.filter(q=>(!section||q.section===section)&&(!type||q.type===type)&&(!ids||ids.includes(q.id))),rng);
 const selected=due.slice(0,Math.max(0,count)),seen=new Set(selected.map(q=>q.id)),concepts=new Set(selected.map(q=>q.conceptKey||q.id));
 const target=Math.max(0,count);
 for(const q of pool){if(selected.length>=target)break;if(!seen.has(q.id)&&!concepts.has(q.conceptKey||q.id)){selected.push(q);seen.add(q.id);concepts.add(q.conceptKey||q.id)}}
 // Small filtered sets can contain several intended variants of the same concept.
 for(const q of pool){if(selected.length>=target)break;if(!seen.has(q.id)){selected.push(q);seen.add(q.id)}}
 return selected;
}
const api={normalize,accepts,grade,shuffle,varied,pending,record,plan};root.Learning=api;if(typeof module!=='undefined')module.exports=api;
})(typeof window!=='undefined'?window:globalThis);
