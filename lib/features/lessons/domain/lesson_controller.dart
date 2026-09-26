import 'dart:math';
import 'package:flutter/foundation.dart';
import 'lesson_store.dart';
import 'lesson.dart';

class LessonController extends ChangeNotifier {
  final LessonStore repository;
  final Random random;
  LessonController(this.repository,{Random? random}):random=random??Random();
  List<Lesson> lessons=[];
  final Map<String,Map<String,dynamic>> progress={};
  final Set<String> read={};
  final Map<String,List<String>> previousOptions={};
  List<LessonQuestion> queue=[];
  List<String> options=[];
  int index=0, score=0;
  String? selected, error, saveError;
  String sessionId='', sourceId='';
  bool loading=true, disposed=false;
  Future<void> writes=Future.value();
  LessonQuestion? get current=>index<queue.length?queue[index]:null;
  bool get finished=>queue.isNotEmpty&&index>=queue.length;
  int streak(String id)=>(progress[id]?['streak'] as int?)??0;
  bool pending(String id)=>(progress[id]?['wrong']==true)&&streak(id)<2;
  @override void notifyListeners(){if(!disposed)super.notifyListeners();}
  @override void dispose(){disposed=true;super.dispose();}
  Future<void> load() async {
    loading=true;error=null;notifyListeners();
    try {
      lessons=await repository.load();
      final data=await repository.restore();
      final ids=lessons.expand((l)=>l.questions).map((q)=>q.id).toSet();
      final raw=data['progress'];
      if(raw is Map){for(final e in raw.entries){
        final v=e.value;
        if(ids.contains(e.key)&&v is Map&&v['streak'] is int&&v['streak']>=0&&v['streak']<=2&&v['wrong'] is bool&&v['lastSession'] is String){progress[e.key.toString()]=Map<String,dynamic>.from(v);}
      }}
      if(data['read'] is List)read.addAll((data['read'] as List).whereType<String>().where((id)=>lessons.any((l)=>l.id==id)));
      final all={for(final l in lessons) for(final q in l.questions) q.id:q};
      final storedOrders=data['orders'];
      if(storedOrders is Map){for(final entry in storedOrders.entries){
        final opts=entry.value, question=all[entry.key];
        if(question!=null && opts is List && opts.length==question.options.length && opts.toSet().length==opts.length && opts.every(question.options.contains)){
          previousOptions[entry.key.toString()]=List<String>.from(opts);
        }
      }}
      final saved=data['session'];
      if(saved is Map && saved['ids'] is List && saved['index'] is int && saved['score'] is int && saved['id'] is String && saved['options'] is List){
        final ids=List<Object?>.from(saved['ids']);
        final position=saved['index'] as int;
        if(ids.isNotEmpty && ids.toSet().length==ids.length && ids.every(all.containsKey) && position>=0 && position<ids.length){
          final candidate=all[ids[position]]!;
          final opts=List<Object?>.from(saved['options']);
          final choice=saved['selected'];
          final sources=lessons.where((l)=>l.questions.any((q)=>ids.contains(q.id))).map((l)=>l.sourceId).toSet();
          if(sources.length==1 && opts.length==candidate.options.length && opts.toSet().length==opts.length && opts.every(candidate.options.contains) && (choice==null||candidate.options.contains(choice)) && saved['score']>=0 && saved['score']<=position+(choice==null?0:1)){
            queue=ids.map((id)=>all[id]!).toList();index=position;score=saved['score'];selected=choice as String?;options=opts.cast<String>();sessionId=saved['id'];sourceId=sources.first;
            previousOptions[candidate.id]=List.of(options);
          }
        }
      }

    } catch(_){error='تعذّر تحميل الدروس أو التقدم. حاول مجددًا.';}
    loading=false;notifyListeners();
  }
  void persist(){
    // Snapshot at the event, then serialize writes so fast taps cannot roll back progress.
    final snapshot=<String,dynamic>{'progress':progress.map((k,v)=>MapEntry(k,Map<String,dynamic>.from(v))),'read':read.toList(),'orders':previousOptions.map((k,v)=>MapEntry(k,List<String>.of(v))),'session':current==null?null:{'id':sessionId,'ids':queue.map((q)=>q.id).toList(),'index':index,'score':score,'selected':selected,'options':List.of(options)}};
    writes=writes.then((_)=>repository.save(snapshot)).then((_) {saveError=null;notifyListeners();}).catchError((Object e){saveError='تعذّر حفظ التقدم على الجهاز. يمكنك إعادة المحاولة.';notifyListeners();});
  }
  void markRead(Lesson lesson){read.add(lesson.id);persist();notifyListeners();}
  void start(List<Lesson> scope,{bool errorsOnly=false,int count=50}){
    if(scope.map((l)=>l.sourceId).toSet().length>1){throw ArgumentError('A session must stay in one source');}
    sourceId=scope.isEmpty?'':scope.first.sourceId;
    final candidates=scope.expand((l)=>l.questions).where((q)=>!errorsOnly||pending(q.id)).toList()..shuffle(random);
    candidates.sort((a,b)=>(pending(a.id)?0:1).compareTo(pending(b.id)?0:1));
    queue=candidates.take(count).toList();index=0;score=0;
    sessionId=DateTime.now().microsecondsSinceEpoch.toString();prepare();persist();notifyListeners();
  }
  void prepare(){
    selected=null;final q=current;if(q==null){options=[];return;}
    options=List.of(q.options)..shuffle(random);
    final old=previousOptions[q.id];
    if(old!=null&&old.indexOf(q.answer)==options.indexOf(q.answer)){options.add(options.removeAt(0));}
    previousOptions[q.id]=List.of(options);
  }
  void answer(String value){
    final q=current;if(q==null||selected!=null||!options.contains(value))return;
    selected=value;final correct=value==q.answer;if(correct)score++;
    final old=progress[q.id]??<String,dynamic>{'streak':0,'wrong':false,'lastSession':''};
    final previous=streak(q.id);
    progress[q.id]={'streak':correct?(old['lastSession']==sessionId?previous:min(2,previous+1)):0,
      'wrong':correct?old['wrong']:true,'lastSession':sessionId};
    persist();notifyListeners();
  }
  void next(){if(selected==null||current==null)return;index++;prepare();persist();notifyListeners();}
}
