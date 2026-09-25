"""Rebuild the only active bank from sorular.txt; standard library only.

Original Q/A are retained in full, with line references. Adapted activities use
only this file, are labeled separately and never replace the verbatim records.
"""
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / 'assets/data'
COMMIT = '5a33de834bf9a9fc7b16ef90c56d4bf63a97270b'
EXPECTED_SHA256 = '7673d1306e1b1ecdd0f929d559b0d5d4b790e534f34274622260356c91df5452'
REPO = 'ogooom11-lgtm/sinav-0984510541987-8941500'
NOTICE = 'الإجابات منقولة من sorular.txt وفق عباراته وآرائه، وليست فتوى أو توثيقًا لصحة الاقتباسات. أبقينا أخطاء النسخ والخلافات دون تصحيح صامت.'
SENSITIVE = 'نقل توثيقي للدراسة النقدية، وليس إقرارًا للحكم الوارد أو دعوة لتطبيقه على أي إنسان. لا يجيز التطبيق إيذاء الأشخاص بسبب معتقدهم أو الاستيلاء على أموالهم. يلزم الرجوع إلى مختص لفهم السياق.'


def parse_source(raw):
    text = raw.decode('utf-8')
    starts = list(re.finditer(r'^\*سؤال\*[^\S\r\n]*\r?$', text, re.M))
    assert starts and not text[:starts[0].start()].strip(), 'Unexpected preamble: review instead of dropping content'
    records = []
    for i, start in enumerate(starts):
        end = starts[i+1].start() if i+1 < len(starts) else len(text)
        block = text[start.start():end]
        marks = list(re.finditer(r'^\*الاجابة او التعريف\*[^\S\r\n]*\r?$', block, re.M))
        assert len(marks) == 1, f'Unexpected answer structure in block {i+1}'
        mark = marks[0]
        prompt = block[start.end()-start.start():mark.start()].strip()
        answer = block[mark.end():].strip()
        assert bool(prompt) == bool(answer), f'Missing prompt/answer in block {i+1}; manual review required'
        begin_line = text[:start.start()].count('\n') + 1
        end_line = text[:end].count('\n') if block.endswith('\n') else text[:end].count('\n')+1
        section = 'الطهارة والعبادات' if i < 140 else 'الصلاة' if i < 168 else 'العقيدة'
        issues = []
        if i+1 in {9,17,27,57,60,63,65,73,77,90,97,99,102,117,118,123,127,128,137,138,140,147,155,157,158,166,183}:
            issues.append('موضع خلاف أو أحكام تحتاج مراجعة سياقية؛ أُبقي النص كاملًا كما ورد.')
        if i+1 == 176:
            issues.append(SENSITIVE)
        records.append(dict(number=i+1, lineStart=begin_line, lineEnd=end_line,
            charStart=start.start(), charEnd=end, text=block, prompt=prompt,
            answer=answer, empty=not prompt, section=section, issues=issues))
    assert ''.join(r['text'] for r in records) == text, 'Every source character must be retained'
    return records


def build():
    raw = (ROOT / 'sorular.txt').read_bytes()
    digest = sha256(raw).hexdigest()
    assert digest == EXPECTED_SHA256, 'Source changed: review the new file, then update COMMIT and EXPECTED_SHA256 together'
    records = parse_source(raw)
    lookup = {r['number']: r for r in records}
    populated = [r for r in records if not r['empty']]
    bank = []
    for r in populated:
        bank.append(dict(id=100000+r['number'], book='sorular', page=r['number'],
            type='qa', prompt=r['prompt'], answer=r['answer'], options=[],
            origin='نقل كامل للسؤال والجواب من sorular.txt', kind='verbatim',
            sourceBlocks=[r['number']], section=r['section'],
            lineStart=r['lineStart'], lineEnd=r['lineEnd'], sourceSha256=digest,
            warning='\n'.join(r['issues']), reviewOnly=r['number'] == 176))

    def original(n): return lookup[n]['answer'].replace('\r\n','\n')
    def line(n, index=0): return original(n).splitlines()[index]
    def add(type, refs, prompt, answer, options=None, **extra):
        if isinstance(refs, int): refs = [refs]
        bank.append(dict(id=200001+sum(q['kind']=='adapted' for q in bank), book='sorular',
            page=refs[0], type=type, prompt=prompt, answer=answer, options=options or [],
            origin='نشاط معاد الصياغة من sorular.txt؛ المرجع الكامل متاح',kind='adapted',
            sourceBlocks=refs, section=lookup[refs[0]]['section'],
            lineStart=lookup[refs[0]]['lineStart'],lineEnd=lookup[refs[0]]['lineEnd'],
            sourceSha256=digest, warning='', reviewOnly=False, **extra))

    # Choices are actual source phrases, not new factual claims. Scope is explicit.
    add('choice',[143,152,139], 'بحسب sorular.txt، متى فرضت الصلاة؟', original(143),
        options=['ليلة المزدلف',original(143),'عند دخول وقت كل صلاة'])
    add('single',[151,148], 'ما الصلاة الوسطى التي يحددها الملف؟', original(151),
        options=['صلاة المغرب','صلاة العشاء',original(151),'صلاة الصبح'])
    tawhid=original(172).splitlines()
    add('multiple',[172,173], 'اختر جميع أقسام التوحيد الثلاثة كما عُدّدت في الملف.', ' | '.join(tawhid),
        options=[tawhid[1],'دلالة العقل.',tawhid[0],tawhid[2]], correct=tawhid)
    add('boolean',98,'بحسب الملف: «التيمم رافع للحدث مطلقا.»','خطأ',options=['صح','خطأ'],explanation=original(98))
    add('blank',143,'أكمل بحسب الملف: فرضت الصلاة في ليلة ____ .','المعراج',accepted=['المعراج'])
    add('short',135,lookup[135]['prompt'],original(135))
    add('definition',28,'ما المصطلح الذي يعرّفه الملف بأنه «'+original(28)+'»؟','السواك',accepted=['السواك'])
    add('description',53,'استنتج نوع النوم الناقض للوضوء من الوصف: «'+original(53)+'».','النوم المستغرق',explanation=original(53))
    add('hints',28,'استنتج المصطلح اعتمادًا على تلميحات مستخرجة من تعريفه في الملف.','السواك',
        accepted=['السواك'],hints=['يستعمل عود أو نحوه.','يستعمل في الأسنان أو اللثة.','لإزالة ما يعلق بهما من الأطعمة والروائح.'])
    add('cause_effect',103,'بحسب الملف، ما النتيجة إذا وجد المتيمم الماء بعد دخوله في الصلاة وقبل الفراغ منها؟',
        'ينتقض تيممه ويجب عليه التطهر بالماء لأداء الصلاة فيقطع الصلاة ويتوضأ ثم يعيد الصلاة')
    add('effect_cause',149,'لماذا بدأ المصنف بصلاة الظهر بحسب الملف؟',original(149))
    add('comparison',77,lookup[77]['prompt'],original(77))
    steps=['الوجه','اليدين','الرأس','الرجلين']
    add('order',40,'رتّب أعضاء الوضوء بحسب الترتيب المذكور في الملف.',' ← '.join(steps),
        options=[steps[2],steps[0],steps[3],steps[1]],correct=steps)
    pairs=[{'left':'الاستعانة','right':'طلب العون'}, {'left':'الاستعاذة','right':'طلب الإعاذة و الحماية من المكروه'}, {'left':'الاستغاثة','right':'طلب الغوث والإنقاذ من الشدة والهلاك'}]
    add('match',186,'صل المصطلح بمعناه بحسب الفروق الواردة في الملف.',' | '.join(p['left']+': '+p['right'] for p in pairs),pairs=pairs)
    add('missing_word',180,'الكلمة الناقصة في أصول العبادة: كمال الحب، كمال الرجاء، كمال ____ .','الخوف',accepted=['الخوف'])
    add('passage_question',168,'ما معنى الطمأنينة في الصلاة، وما مقدارها بحسب النص؟',line(168),passage=original(168))
    add('read_answer',88,'اقرأ النص ثم بيّن الفرق بين كيفية الإجزاء وكيفية الاستحباب في الغسل.',original(88),passage=original(88))
    add('passage_group',38,'أجب عن السؤالين من النص.','السَحور: الطعام الذي يؤكل | السُحور: عملية الأكل',passage=original(38),
        parts=[{'prompt':'ما السَحور (بفتح السين)؟','answer':'الطعام الذي يؤكل','accepted':['الطعام الذي يؤكل']},
               {'prompt':'ما السُحور (بضم السين)؟','answer':'عملية الأكل','accepted':['عملية الأكل']}])
    add('correct_word',[141,115,94],'اختر الكلمة التي تكمل التعريف: الصلاة لغةً هي ____ .','الدعاء',options=['السيلان','القصد','الدعاء'])
    # Each alternative's status can be checked in these source blocks.
    add('correct_statement',[98,41,76],'حدّد العبارة الصحيحة بحسب نص الملف.','مدة المسح على الخفين تبدأ من المسح بعد الحدث',
        options=['التيمم رافع للحدث مطلقا.','المضمضة والاستنشاق ليست ركن من أركان الوضوء؟','مدة المسح على الخفين تبدأ من المسح بعد الحدث'])
    add('incorrect_statement',[98,76,143],'حدّد العبارة التي يصحّحها الملف بوصفها خاطئة.','التيمم رافع للحدث مطلقا.',
        options=['مدة المسح على الخفين تبدأ من المسح بعد الحدث','فرضت الصلاة في ليلة المعراج','التيمم رافع للحدث مطلقا.'],explanation=original(98))
    add('correction',98,'صحّح العبارة بالاعتماد على تصحيح الملف: «التيمم رافع للحدث مطلقا.»',original(98))
    add('sentence',76,'أكمل الجملة: مدة المسح على الخفين تبدأ ____ .',original(76),accepted=[original(76)])

    # Focused follow-ups expose details nested inside longer original answers.
    details=[
        (6,'ما المراد بزوال الخبث بحسب الملف؟','زوال النجاسة من البدن والثوب والمكان.'),
        (6,'هل تجب النية لرفع الحدث ولزوال الخبث على السواء؟',line(6,-1)),
        (7,'اذكر تعريف الماء الطهور وأمثلته كما وردت في الملف.',line(7,1)),
        (9,'ما الضابط المذكور في أول الجواب للماء الذي خالطته نجاسة؟',line(9)),
        (11,'عرّف الماء المستعمل في الطهارة بحسب الملف.',line(11)),
        (12,'ما حكم وضوء المرأة بفضل الرجل والرجل بفضل المرأة في النص؟',line(12,1)),
        (30,'ما دليل تأكد السواك عند دخول البيت؟',line(30,5)),
        (39,'ما الشرط المتعلق بما يمنع وصول الماء إلى البشرة؟',line(39,3)+'\n'+line(39,4)),
        (41,'ما معنى «إلى» في غسل اليدين إلى المرفقين في هذا الجواب؟',line(41,-1)),
        (43,'عرّف اللمعة المذكورة في دليل الموالاة.',line(43,2)),
        (44,'اذكر الذكر الوارد بعد الوضوء وفضله كما ورد في الملف.',line(44,-1)),
        (48,'ماذا يذكر الملف بشأن أكل لحم الإبل والوضوء؟',line(48,5)+'\n'+line(48,6)),
        (54,'كيف يعرّف الملف النوم اليسير؟',line(54,-1)),
        (61,'ما القاعدة المذكورة في ختام الأحوال التي يستحب لها الوضوء؟',line(61,-1)),
        (66,'ما المواضع التي لا يجزئ أو لا يسن مسحها من الخف؟',line(66,-1)),
        (68,'ما أثر انقضاء مدة المسح على الوضوء بحسب آخر الجواب؟',line(68,-1)),
        (70,'هل للمسح على الجبيرة وقت محدد؟ وفي أي حدث يجوز؟',line(70,-1)),
        (73,'ما حكم المسح على الطاقية والقلنسوة في النص، وما تعليله؟',line(73,-1)),
        (90,'ما حكم نقض المرأة شعرها للغسل كما ورد في النص؟',line(90,-1)),
        (94,'اذكر نص الإجماع الذي أورده الملف في مشروعية التيمم.',line(94,-2)),
        (97,'ما معنى الصعيد الآخر المذكور في نهاية الجواب؟',line(97,-1)),
        (99,'لماذا لم يذكر المصنف دخول الوقت شرطًا للتيمم؟','\n'.join(original(99).splitlines()[4:])),
        (101,'ما حكم النفخ والترتيب في صفة التيمم بحسب النص؟',line(101,-1)),
        (105,'بأي شيء يجوز التيمم على الصحيح المذكور في آخر الجواب؟',line(105,-1)),
        (111,'ما طريقة إزالة دم الحيض عن الثوب ومعاني الألفاظ المذكورة في النص؟','\n'.join(original(111).splitlines()[-2:])),
        (112,'كيف يطهّر جلد الميتة مأكول اللحم بحسب النص؟',line(112,6)),
        (114,'ما القول المذكور في آخر الجواب بشأن دم الإنسان غير دم الحيض؟',line(114,-1)),
        (120,'ما الأصل في المرأة وفي الدم النازل منها بحسب النص؟','\n'.join(original(120).splitlines()[1:])),
        (137,'ما الأقوال المذكورة في الدم السابق للولادة؟','\n'.join(original(137).splitlines()[-2:])),
        (140,'ماذا تفعل المستحاضة إذا نسيت عادتها؟',line(140,-1)),
        (144,'ماذا يقول الملف عن ثبوت وجوب الصلاة وفرضيتها؟',line(144,-1)),
        (152,'ما الوارد في تأخير المغرب ليلة المزدلفة؟',line(152,3)),
        (152,'ما حكم النوم قبل العشاء والحديث بعدها لغير مصلحة كما ورد في النص؟',line(152,-1)),
        (158,'ما حقيقة النية؟ وهل يشرع التلفظ بها في النص؟',line(158,-1)),
        (165,'ما حكم القيام في النافلة وفضله بحسب النص؟',line(165,1)),
        (165,'ما تكبيرة الإحرام، وما أثر تركها بحسب الجواب؟',line(165,2)),
        (168,'ماذا يقول المصلي عند التسليم عن يمينه ويساره وفق الملف؟',line(168,-1)),
        (180,'ما الدليل الجامع لأصول العبادة الذي أورده الملف؟',line(180,-1)),
        (182,'ما الدليل الوارد في النص على اختصاص الله بالدعاء؟',line(182,-1)),
        (185,'ما معنى كلمة «على» كما شرحها الجواب؟',line(185,-1)),
        (187,'ما الأدلة التي أوردها النص لعبادة الذبح؟','\n'.join(original(187).splitlines()[1:])),
        (189,'ما ضابط الرقى الذي ورد في الحديث المنقول في آخر الملف؟',line(189,-1)),
    ]
    for n,prompt,answer in details:
        assert answer.strip() and answer in original(n), (n,prompt)
        add('short',n,prompt,answer)
        bank[-1]['warning']='\n'.join(lookup[n]['issues'])

    all_lines = raw.decode('utf-8').splitlines()
    content_lines = [i for i,line_text in enumerate(all_lines,1)
        if line_text.strip() and line_text.strip() not in ('*سؤال*','*الاجابة او التعريف*')]
    covered_lines = [i for i in content_lines if any(r['lineStart'] <= i <= r['lineEnd'] for r in populated)]
    assert content_lines == covered_lines
    counts = Counter(q['type'] for q in bank)
    metadata = dict(datasetId='sorular-'+digest[:16]+'-v1',sourceFile='sorular.txt',sourceSha256=digest,
        githubCommit=COMMIT,githubUrl=f'https://github.com/{REPO}/blob/{COMMIT}/sorular.txt',
        sourceBytes=len(raw),sourceLines=len(all_lines),totalBlocks=len(records),
        populatedBlocks=len(populated),emptyBlocks=len(records)-len(populated),
        importedQuestions=len(populated),adaptedQuestions=len(bank)-len(populated),
        questionCount=len(bank),contentLines=len(content_lines),coveredContentLines=len(covered_lines),
        uncoveredContentLines=[],typeCounts=dict(counts),notice=NOTICE,
        coverageMeaning='كل سؤال وجواب غير فارغ نُقل كاملًا دون اختصار. لا تعني هذه التغطية أن كل جملة صارت تمرينًا مستقلًا أو أن المحتوى دُقّق شرعيًا.',
        blocks=[dict(number=r['number'],lineStart=r['lineStart'],lineEnd=r['lineEnd'],
            empty=r['empty'],questionIds=[q['id'] for q in bank if r['number'] in q['sourceBlocks']],issues=r['issues']) for r in records])
    books=[dict(id='sorular',file='sorular.txt',title='أسئلة sorular',subtitle='الطهارة · الصلاة · العقيدة',
        format='txt',unit='مقطع',notice=NOTICE,sourceSha256=digest,githubUrl=metadata['githubUrl'],
        populatedBlocks=len(populated),emptyBlocks=metadata['emptyBlocks'],pages=records)]
    DATA.mkdir(parents=True,exist_ok=True)
    for name,value in [('books.json',books),('questions.json',bank),('coverage.json',metadata)]:
        (DATA/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report=['# تقرير استيراد sorular.txt','',f"المصدر: [{COMMIT}]({metadata['githubUrl']})",f'بصمة SHA-256: `{digest}`','',
        f"- الملف: {len(raw):,} بايت، {len(all_lines)} سطرًا.",
        f'- المجموعات: {len(records)}؛ منها {len(populated)} مكتملة و{metadata["emptyBlocks"]} قوالب فارغة.',
        f'- البنك الجديد: {len(bank)} سؤالًا = {len(populated)} نقل كامل + {len(bank)-len(populated)} نشاطًا إضافيًا من النص.',
        f'- سطور المحتوى غير الفارغة (دون علامتي السؤال والجواب): {len(content_lines)}؛ محفوظة كلها.',
        '- أزيلت الأسئلة التجريبية الـ51 من البنك النشط. لا تُستخدم ملفات PDF لإنشاء هذا البنك.',
        '- أرقام الأسئلة الجديدة مستقلة عن البنك السابق، وتُمسح النتائج والمحفوظات القديمة عند فتح التطبيق.',
        '', '## معنى التغطية', metadata['coverageMeaning'],'', '## تنبيهات التحرير',NOTICE,
        'النص يحوي أخطاء ظاهرة في نقل آيات وأحاديث وألفاظ، وبعض إجابات مركبة وأقوالًا مختلفة. لم تُصحّح تلقائيًا. المقطع 176 محفوظ للقراءة النقدية فقط مع تنبيه، ولا يدخل التدريبات أو التقييم.',
        '', '## توزيع الأنواع']
    types=json.loads((DATA/'types.json').read_text())
    report += [f"- {types[k]['label']}: {v}" for k,v in counts.items()]
    report += ['', '## سجل كل المقاطع', '| المقطع | أسطر الملف | الحالة | الأسئلة المرتبطة |', '|---|---|---|---|']
    report += [f"| {r['number']} | {r['lineStart']}–{r['lineEnd']} | {'فارغ؛ لا سؤال مصنوع له' if r['empty'] else 'منقول كاملًا'} | {', '.join(map(str,metadata['blocks'][r['number']-1]['questionIds'])) or '—'} |" for r in records]
    (ROOT/'docs/sorular-coverage.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
    print(f"Imported {len(populated)} full Q/A; {metadata['emptyBlocks']} empty templates; {len(bank)} total questions; {len(counts)} types")
    return metadata

if __name__ == '__main__':
    # Public CLI always builds the complete learning bank, never a reduced bank.
    from expand_learning import expand
    expand()
