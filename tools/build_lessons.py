"""Build lessons from explicitly selected source excerpts; assert provenance."""
import json,sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'content'))
from lesson_plan import LESSONS

def build():
    bank=json.loads((ROOT/'assets/data/questions.json').read_text())
    originals={(q['sourceId'],q['page']):q for q in bank if q['kind']=='verbatim'}
    lessons=[]
    for n,(sid,title,specs) in enumerate(LESSONS,1):
        lid=f'lesson-{n:02d}';facts=[]
        for i,(term,block,text) in enumerate(specs):
            src=originals[sid,block]
            assert text in src['answer'],(sid,block,text)
            assert block!=176 if sid=='sorular' else not(sid=='file3' and block==8)
            facts.append(dict(id=f'{lid}-f{i}',title=term,text=text,sourceBlock=block,sourceFile=src['sourceFile'],lineStart=src['lineStart'],lineEnd=src['lineEnd'],sourceSha256=src['sourceSha256']))
        questions=[]
        for i,fact in enumerate(facts):
            # All alternatives are true excerpts/labels from this same curated lesson,
            # not invented rulings. Only the requested mapping is assessed.
            peers=[f for f in facts if f!=fact][:3]
            for reverse in [False,True]:
                field='title' if reverse else 'text'
                prompt=(f'في درس «{title}»، أي عنوان يناسب العبارة: «{fact["text"]}»؟' if reverse else f'في درس «{title}»، أي عبارة تقابل «{fact["title"]}»؟')
                options=[fact[field]]+[f[field] for f in peers]
                assert len(set(options))==len(options)
                questions.append(dict(id=f'{lid}-q{i}-{int(reverse)}',factId=fact['id'],prompt=prompt,answer=fact[field],options=options,explanation=f'{fact["title"]}: {fact["text"]}',sourceBlock=fact['sourceBlock']))
        lessons.append(dict(id=lid,sourceId=sid,title=title,objective='ميّز بين المفاهيم التالية واربط كل عنوان بعبارته في المصدر.',facts=facts,questions=questions))
    payload=dict(version=1,notice='مقتطفات منتقاة من ملفاتك فقط؛ ليست تغطية كاملة لها ولا توثيقًا مستقلًا للأحكام. البدائل من الدرس نفسه وليست أقوالًا منسوبة إلى مصطلحات أخرى.',lessons=lessons)
    (ROOT/'assets/data/lessons.json').write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n')
    print(len(lessons),'lessons;',sum(len(l['questions']) for l in lessons),'choice questions')
if __name__=='__main__':build()
