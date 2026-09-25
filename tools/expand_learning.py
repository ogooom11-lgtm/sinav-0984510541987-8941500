"""Source-only learning variants. Reproducible, with a sentence/line coverage ledger.

Activities are extraction/cloze transformations, not independently verified fiqh.
No claim that generated distractors are facts: they are candidate missing words.
"""
import json
import re
from collections import Counter
from pathlib import Path
from import_sorular import build, parse_source

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT/'assets/data'
STOP = set('هو هي من في على إلى الى عن أن ان إن كان كانت يكون تكون هذا هذه ذلك التي الذي فيما مما بها به ثم أو او كل ولا لا ما مع بين عند وقد بعد قبل له لها فيه فيها وهم حيث فقط وهي وهو فإن فان أما اما حتى فيه قال قوله تعالى الله صلى عليه وسلم رضي عنه عنها النبي حديث لقوله لحديث رسول سبحانه وتعالى فإذا اذا إذا بأنه بأن لأن لان كما وما ولم لم قد إنما انما أهل أحد يعني إلا الا قالوا وما'.split())
def norm(s):
    return re.sub(r'[\u064b-\u065f\u0670ـ]', '', s).replace('أ','ا').replace('إ','ا').replace('آ','ا')
NORMAL_STOP = {norm(w) for w in STOP}
def words(s):
    return [m for m in re.finditer(r'[\u0621-\u064a\u064b-\u065f\u0670]+',s)
            if len(norm(m.group()))>=4 and norm(m.group()) not in NORMAL_STOP]

def expand():
    build()
    bank=json.loads((DATA/'questions.json').read_text())
    coverage=json.loads((DATA/'coverage.json').read_text())
    records=parse_source((ROOT/'sorular.txt').read_bytes())
    ledger=[]
    for r in records:
        if r['empty']: continue
        # Every nonempty answer line is represented, even an awkward wrapped line.
        # Full parent context remains attached for explanation after answering.
        for n,line in enumerate(r['answer'].replace('\r\n','\n').splitlines(),1):
            if not line.strip(): continue
            ledger.append(dict(key=f"s{r['number']}-u{n}",block=r['number'],line=n,
                text=line,context=r['prompt'],section=r['section'],reviewOnly=r['number']==176,
                generatedIds=[]))
    vocab={topic:sorted({m.group() for u in ledger if u['section']==topic and not u['reviewOnly'] for m in words(u['text'])},key=lambda x:(len(x),x)) for topic in {u['section'] for u in ledger}}
    by_block={r['number']:r for r in records}
    for q in bank:
        q['conceptKey']=f"block-{q['page']}"
        q['difficulty']='متوسط' if len(q['answer'])>150 else 'أساسي'
    def add(u,i,t,prompt,answer,**extra):
        r=by_block[u['block']]
        q=dict(id=(300000+i*30+len(u['generatedIds']) if i<10000 else 1000000+len(bank)),book='sorular',page=u['block'],type=t,
            prompt=prompt,answer=answer,options=[],kind='generated',origin='تدريب استخراجي من محتوى sorular.txt',
            sourceBlocks=[u['block']],section=u['section'],lineStart=r['lineStart'],lineEnd=r['lineEnd'],
            sourceSha256=coverage['sourceSha256'],warning='\n'.join(r['issues']),reviewOnly=False,
            conceptKey=u['key'],unitKey=u['key'],evidence=u['text'],
            explanation=u['text'],context=u['context'],difficulty='أساسي' if len(u['text'])<100 else 'متوسط')
        q.update(extra);bank.append(q);u['generatedIds'].append(q['id'])
    for i,u in enumerate(ledger):
        if u['reviewOnly']: continue
        text=u['text']; matches=words(text)
        # Every unit gets a contextual retrieval question, including short lines.
        add(u,i,'short',f"ضمن موضوع «{u['context']}»، استحضر التفصيل الآتي واشرحه: {text[:32].rstrip()}…" if len(text)>80 else f"ما التفصيل الوارد في مادة «{u['context']}»؟",text,
            passage=None)
        if not matches:
            add(u,i,'qa',f"راجع معنى «{u['context']}» واذكر الإجابة الواردة في المادة.",text)
            continue
        # Up to three genuinely different masked positions, not 24 renamed clones.
        chosen=[]
        for m in sorted(matches,key=lambda m:(-len(norm(m.group())),m.start())):
            if norm(m.group()) not in [norm(x.group()) for x in chosen]: chosen.append(m)
            if len(chosen)==3: break
        for j,m in enumerate(chosen):
            token=m.group();cloze=text[:m.start()]+' ____ '+text[m.end():]
            candidates=[v for v in vocab[u['section']] if norm(v)!=norm(token) and norm(v) not in norm(text)
                and abs(len(norm(v))-len(norm(token)))<=3]
            # A stable set is stored; runtime randomizes presentation on every encounter.
            alternatives=candidates[(i+j)%max(1,len(candidates)):] + candidates[:(i+j)%max(1,len(candidates))]
            alternatives=list(dict.fromkeys(alternatives))[:3]
            if len(alternatives)==3:
                add(u,i,['choice','single','correct_word'][j],f"أكمل المعنى في سياق «{u['context']}» باختيار الكلمة المناسبة:\n{cloze}",token,
                    options=[token,*alternatives])
            add(u,i,['blank','missing_word','sentence'][j],f"استرجع الكلمة الناقصة من المراجعة، في موضوع «{u['context']}»:\n{cloze}",token,accepted=[token])
        if len(chosen)>=2 and len(text)<650:
            chosen2=sorted(chosen[:2],key=lambda m:m.start())
            masked=text
            for m in reversed(chosen2): masked=masked[:m.start()]+' ____ '+masked[m.end():]
            correct=[m.group() for m in chosen2]
            decoys=[v for v in vocab[u['section']] if norm(v) not in norm(text)][:2]
            if len(decoys)==2:
                add(u,i,'multiple',f"اختر الكلمتين اللتين تُكملان الفراغين (دون اشتراط ترتيب الاختيار):\n{masked}", '، '.join(correct),options=[*correct,*decoys],correct=correct)
            add(u,i,'passage_group','اقرأ المقطع، ثم أجب عن موضعي الإكمال.', ' | '.join(correct),passage=text,
                parts=[dict(prompt=text[:m.start()]+' ____ '+text[m.end():],answer=m.group(),accepted=[m.group()]) for m in chosen2])
        # Verbatim-comparison true/false; does not invent a new religious ruling.
        if len(text)<450:
            m=chosen[0]; token=m.group()
            alt=next((v for v in vocab[u['section']] if norm(v) not in norm(text) and abs(len(v)-len(token))<3),None)
            if alt:
                incorrect=text[:m.start()]+alt+text[m.end():]
                add(u,i,'boolean','هل العبارة التالية مطابقة لما ورد في هذه الجزئية من المراجعة؟\n'+(text if i%2==0 else incorrect),'صح' if i%2==0 else 'خطأ',options=['صح','خطأ'])
                add(u,i,'correction','في العبارة التالية كلمة مستبدلة؛ أعد كتابة العبارة كما وردت في المراجعة:\n'+incorrect,text)
                add(u,i,'correct_statement','حدّد الصياغة المطابقة لما ورد في المراجعة.',text,options=[incorrect,text])
                add(u,i,'incorrect_statement','حدّد الصياغة التي لا تطابق النص (بها كلمة مستبدلة).',incorrect,options=[text,incorrect],explanation='الصياغة الواردة: '+text)
        # Text reconstruction is explicitly lexical, not a newly invented ritual order.
        tokens=text.split()
        if 9 <= len(tokens) <= 36 and i%3==0 and not any(x in text for x in ['قال تعالى','لقوله','الدليل','حديث','ﷺ','﴿','{']):
            size=(len(tokens)+2)//3
            pieces=[' '.join(tokens[n:n+size]) for n in range(0,len(tokens),size)]
            if len(set(pieces))==len(pieces):
                add(u,i,'order','أعد ترتيب أجزاء العبارة لتكوين نص المراجعة (ترتيب نصّي، لا ترتيب أحكام جديد).',' '.join(pieces),options=list(reversed(pieces)),correct=pieces)
        # Passage understanding uses the complete unit, not a truncated excerpt.
        if len(text)>90:
            add(u,i,'passage_question',f"ما الفكرة أو الحكم وشروطه في هذا المقطع المتعلق بـ«{u['context']}»؟",text,passage=text)
            add(u,i,'read_answer','اقرأ النص ثم اشرح معناه بكلماتك، مع إبقاء الحكم وشروطه وأدلته المذكورة.',text,passage=text)
        if 'لأن' in text or 'لانه' in text or 'وذلك' in text:
            add(u,i,'effect_cause',f"بيّن التعليل في الجزئية التي تبدأ بـ«{text[:55].rstrip()}…» ضمن موضوع «{u['context']}».",text)
        if re.search(r'إذا|فإذا|فإن',text):
            add(u,i,'cause_effect',f"ما الحالة ونتيجتها في الجزئية التي تبدأ بـ«{text[:55].rstrip()}…» ضمن موضوع «{u['context']}»؟",text)
    # Definitions: reverse retrieval, meaningful hints, and matching from explicit labels.
    for r in records:
        if r['empty'] or r['number']==176: continue
        candidates=[]
        for line_number,line in enumerate(r['answer'].replace('\r\n','\n').splitlines(),1):
            m=re.match(r'^\s*([^:：]{3,40})\s*[:：]\s*(.{20,})$',line)
            if m and not any(w in m[1] for w in ['الدليل','قوله','لقوله','حديث','حكمه','تعريفه','مثال','السنة','القرآن']):
                term=re.sub(r'^[\d٠-٩.\s•*-]+','',m[1]).strip();definition=m[2].strip()
                if 3<=len(term)<=35: candidates.append((term,definition,line_number))
        if not candidates:continue
        u=next(u for u in ledger if u['block']==r['number'])
        # Separate ID range avoids collisions with per-line variants.
        i=10000+r['number']
        for term,definition,line_number in candidates[:3]:
            u=next(u for u in ledger if u['block']==r['number'] and u['line']==line_number)
            add(u,i,'definition',f"ما المصطلح أو العنوان الذي وصفته المراجعة هكذا؟\n{definition}",term,accepted=[term])
            add(u,i,'description',f"استنتج المصطلح أو العنوان من الوصف:\n{definition}",term)
            chunks=re.split(r'،|,|\.\s',definition)
            if len(chunks)>=2:
                add(u,i,'hints',f"استنتج المصطلح في موضوع «{r['prompt']}» بمساعدة التلميحات.",term,accepted=[term],hints=[c.strip() for c in chunks if c.strip()][:3])
        if len(candidates)>=2:
            u=next(u for u in ledger if u['block']==r['number'] and u['line']==candidates[0][2])
            pairs=[dict(left=t,right=d) for t,d,_ in candidates[:4]]
            if len({p['left'] for p in pairs})==len(pairs) and len({p['right'] for p in pairs})==len(pairs):
                add(u,i,'match','صل كل عنوان بوصفه الوارد في المراجعة.',' | '.join(t+': '+d for t,d,_ in candidates[:4]),pairs=pairs)
                add(u,i,'comparison','قارن بين العناوين التالية مستعينًا بالمعاني والشروط الواردة: '+'، '.join(t for t,d,_ in candidates[:4]),'\n'.join(t+': '+d for t,d,_ in candidates[:4]))
    coverage['baseQuestionCount']=coverage['questionCount']
    coverage['questionCount']=len(bank)
    coverage['generatedQuestions']=sum(q['kind']=='generated' for q in bank)
    coverage['typeCounts']=dict(Counter(q['type'] for q in bank))
    coverage['learningUnits']=len(ledger)
    coverage['trainedUnits']=sum(bool(u['generatedIds']) for u in ledger)
    coverage['criticalUnits']=sum(u['reviewOnly'] for u in ledger)
    coverage['unitCoverageMeaning']='كل سطر غير فارغ من الأجوبة له تمارين استرجاع/إكمال أو أنشطة سياقية. المقطع 176 محفوظ توثيقيًا ولا يُحوّل إلى تدريب على استباحة الأشخاص.'
    coverage['units']=ledger
    for block in coverage['blocks']:
        block['questionIds']=[q['id'] for q in bank if block['number'] in q['sourceBlocks']]
    (DATA/'questions.json').write_text(json.dumps(bank,ensure_ascii=False,indent=2)+'\n')
    (DATA/'coverage.json').write_text(json.dumps(coverage,ensure_ascii=False,indent=2)+'\n')
    report=ROOT/'docs/sorular-coverage.md'
    with report.open('a') as f:
        f.write(f"\n## التوسعة التعليمية\n\n- {len(bank)} نشاطًا/سجلًا، منها {coverage['generatedQuestions']} نشاطًا استخراجيًا جديدًا.\n- {len(ledger)} وحدة نصية في الأجوبة: {coverage['trainedUnits']} لها تمارين و{coverage['criticalUnits']} محفوظة للمراجعة النقدية فقط.\n- تمثيل الأنواع:\n")
        for k,n in coverage['typeCounts'].items():f.write(f'- {k}: {n}\n')
        f.write('\nهذه أنشطة استخراج وتذكّر نصّي، وليست آلاف الأحكام المستقلة أو أسئلة مولدة بتحكيم بشري. بعض الأنواع الأكثر تعقيدًا أقل عددًا لعدم اصطناع علاقات لا يذكرها النص.\n')
    print('Expanded:',len(bank),'records;',len(ledger),'units;',coverage['trainedUnits'],'trained')
    return coverage
if __name__=='__main__':expand()
