import 'package:flutter/material.dart';
import '../data/lesson_repository.dart';
import '../domain/lesson.dart';
import '../domain/lesson_controller.dart';
import 'lesson_widgets.dart';

class LessonsHome extends StatefulWidget {
  const LessonsHome({super.key});
  @override State<LessonsHome> createState()=>_LessonsHomeState();
}
class _LessonsHomeState extends State<LessonsHome> {
  late final LessonController controller;
  String source='sorular';Lesson? lesson;bool quiz=false;
  static const names={'sorular':'المراجعة الأساسية','file2':'الدروس الهجائية','file3':'العقيدة'};
  @override void initState(){super.initState();controller=LessonController(LessonRepository())..addListener(refresh)..load();}
  void refresh(){if(mounted)setState((){});}
  @override void dispose(){controller.removeListener(refresh);controller.dispose();super.dispose();}
  void begin(List<Lesson> scope,{bool errorsOnly=false}){controller.start(scope,errorsOnly:errorsOnly);setState(()=>quiz=true);}
  Widget button(String title,VoidCallback action)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:FilledButton(onPressed:action,child:Text(title)));
  @override Widget build(BuildContext context){
    final c=controller,scope=c.lessons.where((l)=>l.sourceId==source).toList();
    return Scaffold(appBar:AppBar(title:const Text('بصيرة · تعلّم ثم طبّق'),leading:lesson!=null||quiz?IconButton(icon:const Icon(Icons.arrow_back),onPressed:()=>setState((){quiz=false;lesson=null;})):null,actions:[TextButton(onPressed:()=>Navigator.pushNamed(context,'/legacy'),child:const Text('التدريبات السابقة',style:TextStyle(color:Colors.white)))]),body:SafeArea(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:900),child:ListView(padding:const EdgeInsets.all(24),children:[
      if(c.loading)const Center(child:CircularProgressIndicator())
      else if(c.error!=null)...[Text(c.error!),button('إعادة المحاولة',c.load)]
      else ...[
        if(c.saveError!=null)MaterialBanner(content:Text(c.saveError!),actions:[TextButton(onPressed:c.persist,child:const Text('إعادة الحفظ'))]),
        if(quiz)...quizBody()
        else if(lesson!=null)...[
          Text(lesson!.title,style:Theme.of(context).textTheme.headlineMedium),Text(lesson!.objective),
          const SizedBox(height:16),...lesson!.facts.map(FactCard.new),
          button(c.read.contains(lesson!.id)?'تمت قراءة الدرس ✓':'أنهيت قراءة الدرس',()=>c.markRead(lesson!)),
          button('طبّق الآن · ${lesson!.questions.length} أسئلة اختيار',()=>begin([lesson!])),
          const Text('القراءة لا تعني الإتقان. تتثبت الإجابة بإجابتين صحيحتين في جلستين مختلفتين.'),
        ] else ...[
          Text('خطوة للفهم، وخطوة للتثبيت',style:Theme.of(context).textTheme.headlineMedium),
          const Text('دروس قصيرة منتقاة من ملفاتك، ثم أسئلة اختيار. تظهر النتيجة والتوضيح فور اختيار الإجابة.',style:TextStyle(height:1.8)),
          const SizedBox(height:20),Wrap(spacing:8,children:names.entries.map((e)=>ChoiceChip(label:Text(e.value),selected:source==e.key,onSelected:(_)=>setState(()=>source=e.key))).toList()),
          const SizedBox(height:18),
          Text('${scope.length} دروس · ${scope.expand((l)=>l.questions).length} أسئلة اختيار · ${scope.where((l)=>c.read.contains(l.id)).length} تمت قراءتها'),
          if(c.current!=null)button('استئناف الجلسة المحفوظة',()=>setState(()=>quiz=true)),
          Wrap(spacing:12,children:[button('اختبار القسم · حتى 50 سؤالًا',()=>begin(scope)),button('راجع أخطاء هذا القسم',()=>begin(scope,errorsOnly:true))]),
          ...scope.map((l)=>Card(child:ListTile(contentPadding:const EdgeInsets.all(18),title:Text(l.title),subtitle:Text('${l.questions.length} أسئلة · ${l.questions.where((q)=>c.streak(q.id)>=2).length} مثبتة'),trailing:const Icon(Icons.chevron_left),onTap:()=>setState(()=>lesson=l)))),
          const SizedBox(height:20),const Text('المحتوى من الملفات المرفوعة فقط. هذه دروس منتقاة وليست تغطية كاملة للملفات أو توثيقًا مستقلًا للأحكام. التقدم والجلسة محفوظان محليًا على هذا الجهاز.'),
        ],
      ],
    ])))));
  }
  List<Widget> quizBody(){
    final c=controller,q=c.current;
    if(c.queue.isEmpty)return [const Text('لا توجد أسئلة مستحقة ضمن هذا الاختيار.'),button('العودة للدروس',()=>setState(()=>quiz=false))];
    if(c.finished)return [Text('أكملت المحاولة · ${c.score} / ${c.queue.length}',style:Theme.of(context).textTheme.headlineMedium),const Text('الإجابات الخاطئة محفوظة للمراجعة. الإتقان يحتاج نجاحًا في جلستين مختلفتين.'),button('العودة للدروس',()=>setState(()=>quiz=false))];
    final fact=c.lessons.expand((l)=>l.facts).firstWhere((f)=>f.id==q!.factId);
    return [Text('السؤال ${c.index+1} من ${c.queue.length}'),LinearProgressIndicator(value:c.index/c.queue.length),const SizedBox(height:20),
      Text(q!.prompt,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),
      ...c.options.map((v)=>AnswerOption(text:v,locked:c.selected!=null,correct:v==q.answer,chosen:v==c.selected,onTap:()=>c.answer(v))),
      if(c.selected!=null)...[
        Semantics(liveRegion:true,child:Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(c.selected==q.answer?'✓ إجابة صحيحة':'✗ إجابة غير صحيحة',style:Theme.of(context).textTheme.titleLarge),
          Text('الإجابة الصحيحة: ${q.answer}'),const SizedBox(height:12),Text(q.explanation),Text(fact.reference),
        ])))),button(c.index+1==c.queue.length?'عرض النتيجة':'السؤال التالي',c.next),
      ],
    ];
  }
}
