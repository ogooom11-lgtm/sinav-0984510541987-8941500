"""Conservative editorial gate, applied on every build. Never rewrites originals.
Quarantined records remain archival only. New IDs prevent old scores transferring.
No claim of independent scholarly verification.
"""
import copy

BLOCKED = {
 'sorular': {6,7,9,12,23,24,25,26,27,36,37,40,41,43,47,56,57,59,60,61,66,81,99,102,105,107,114,127,128,131,135,136,137,152,157,158,163,164,165,168,176,178,187},
 'file2': {6,20},
 'file3': {8,16,17,18,22,41,43,55,56},
}
# Explicitly authored replacements: (source, block, task, answer). Answers either
# extract a complete source statement or reorganize it without adding a ruling.
REPAIRS = [
 ('sorular',37,'ميّزي بين الوَضوء بفتح الواو والوُضوء بضمها بحسب المراجعة.','الوَضوء بفتح الواو: الماء الذي يُتوضأ به.\nالوُضوء بضم الواو: استعمال الماء في أعضاء الوضوء.'),
 ('sorular',6,'ما المراد بزوال الخبث بحسب المراجعة؟','زوال النجاسة من البدن والثوب والمكان.'),
 ('sorular',6,'هل تشترط النية لرفع الحدث ولزوال الخبث على السواء بحسب المراجعة؟','رفع الحدث لابد فيه من نية أما زوال الخبث فلا تجب فيه النية ( كالمطر يزيل النجاسة من الثوب).'),
 ('sorular',7,'عرّفي الماء الطهور بحسب المراجعة، دون تعداد الأدلة.','هو الطاهر في ذاته المطهر لغيره وهو الباقي على أصل خلقته أي على صفته التي خلق عليها.'),
 ('sorular',40,'عددي فروض الوضوء الستة المذكورة في المراجعة، دون الاستدلال.','غسل الوجه، وغسل اليدين إلى المرفقين، ومسح الرأس، وغسل الرجلين إلى الكعبين، والترتيب، والموالاة.'),
 ('sorular',41,'بحسب المراجعة، لماذا تدخل المضمضة والاستنشاق في غسل الوجه؟','لأن الفم والأنف من جملة الوجه وغسل الوجه ركن'),
 ('sorular',43,'ما معنى اللمعة في الكلام على الوضوء والغسل؟','المكان الذي لم يصبه الماء في الوضوء أو الغسل.'),
 ('sorular',66,'ما موضع المسح المشروع من الخف بحسب المراجعة؟','ظاهر الخف'),
 ('sorular',105,'بحسب المراجعة، كيف يتطهر من وجد ماء يكفي بعض أعضاء الوضوء فقط؟','إذا كان الماء قليلا يكفي لبعض أعضاء الوضوء ، فيغسل ما قدر عليه من أعضاء وضوئه على الترتيب ويتيمم عن الباقي.'),
 ('sorular',114,'بحسب المراجعة، هل يعيد الصلاة من لم يعلم بالنجاسة في ثيابه إلا بعد انقضاء الصلاة؟','لا يعيد الصلاة'),
 ('sorular',158,'ما حقيقة النية بحسب المراجعة؟','العزم على الشيء.'),
 ('sorular',163,'عرّفي الركن في العبادة، وبيّني أثر تركه بحسب المراجعة.','ما تتكون منها العبادات ، ولا تصح العبادة إلا بها ولا تسقط سهوا ولا عمدا ولا جهلاً ولا يجبرها سجود السهو.'),
 ('sorular',164,'ما الفرق بين الشرط والركن في علاقتهما بالعبادة بحسب المراجعة؟','الشرط يجب أن يتقدم على العبادة ويستمر معها، أما الأركان فهي التي تشتمل عليها العبادة من أقوال وأفعال.'),
 ('sorular',165,'كيف يصلي من عجز عن القيام لعذر بحسب المراجعة؟','يصلي حسب حاله قاعدًا أو على جنب.'),
 ('sorular',168,'ما معنى الطمأنينة في الصلاة وما مقدارها بحسب المراجعة؟','هي السكون وتكون على قدر القول الواجب في كل ركن'),
 ('sorular',168,'ماذا يقول المصلي عند التسليم عن يمينه وعن يساره بحسب المراجعة؟','عن يمينه: السلام عليكم ورحمة الله. وعن يساره: السلام عليكم ورحمة الله.'),
 ('file3',17,'اذكري المثالين الواردين في الملف لطلب الإنسان الحي ما يقدر عليه.','يا فلان أطعمني، يا فلان أسقني.'),
 ('file3',43,'عرّفي الغلو شرعًا بحسب الملف، وحددي المجالين المذكورين في التعريف.','الغلو هو مجاوزة حدود ما شرع الله لعباده سواء في العقيدة أو العبادة.'),
 ('file2',20,'ما الفرق بين الوحدة البسيطة الثنائية والثلاثية بحسب الملف؟ لا تذكري أمثلة الكلمات.','الثنائية: متحرك بعده ساكن مدي أو غير مدي لم يدغم فيما بعده.\nالثلاثية: متحرك بعده ساكنان، الأول مدي والثاني غير مدي ولم يدغم فيما بعده.'),
 ('file2',20,'ما تعريف الوحدة البسيطة المفردة بحسب الملف؟','كل حرف متحرك لم يأت بعده حرف ساكن أو مد أو مشدد.'),
]

def apply(bank):
    # Rebuild may be called repeatedly without re-importing sorular.
    bank[:] = [q for q in bank if not q.get('editorialRepair')]
    originals={(q['sourceId'],q['page']):q for q in bank if q['kind']=='verbatim'}
    for q in bank:
        reason=None
        if q['kind']=='generated':
            reason='استبعاد احترازي للتوليد الآلي السطري؛ لا يعاد للتدريب دون تحرير مستقل.'
        elif q['sourceId']=='file2' and q['kind']=='verbatim':
            reason='ملاحظة دراسية أصلية وليست سؤال امتحان؛ محفوظة في الأرشيف فقط.'
        elif set(q['sourceBlocks']) & BLOCKED.get(q['sourceId'],set()):
            reason='موضع أشار إليه تدقيق المحتوى أو نشاط مشتق منه؛ مستبعد لحين التحرير أو التوثيق.'
        if reason:
            q.update(reviewOnly=True,excludedReason=reason,qualityStatus='quarantined')
    for n,(sid,block,prompt,answer) in enumerate(REPAIRS,1):
        src=originals[sid,block]
        q=copy.deepcopy(src)
        for key in ['excludedReason','qualityStatus','accepted','correct','pairs','parts','passage','hints']:
            q.pop(key,None)
        q.update(id=4100000+n,kind='adapted' if sid=='sorular' else 'curated',variant='modified',originalFormat=None,
                 prompt=prompt,answer=answer,type='short',options=[],reviewOnly=False,nativeBlank=False,
                 editorialRepair=True,replacesId=src['id'],difficulty='متقدم',
                 conceptKey=f'{sid}-editorial-{n}',origin='صياغة محررة من المصدر؛ ليست توثيقًا مستقلًا للحكم',
                 warning='الإجابة بحسب الملف المرفوع؛ الإصلاح تحريري وليس فتوى أو تصحيحًا علميًا مستقلًا.',
                 evidence=[dict(block=block,lineStart=src['lineStart'],lineEnd=src['lineEnd'],quote=src['answer'])])
        bank.append(q)
    return bank
