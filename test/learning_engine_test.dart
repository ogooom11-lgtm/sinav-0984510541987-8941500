import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:basira/learning_engine.dart';
import 'package:basira/question.dart';
void main(){
  final bank=(jsonDecode(File('assets/data/questions.json').readAsStringSync()) as List).map((v)=>Question(v)).toList();
  test('All pending errors, including self-assessment, enter next exam',(){
    final engine=LearningEngine(Random(17));final memory=<String,dynamic>{};
    final a=bank.firstWhere((q)=>q.type=='choice'),b=bank.firstWhere((q)=>q.type=='short');
    engine.record(memory,a.id,false,'first',now:1);engine.record(memory,b.id,false,'first',now:2);
    expect(engine.plan(bank,memory,exam:true,count:1,section:'different topic'),isEmpty);
    final list=engine.plan(bank,memory,exam:true,count:2);
    expect(list.map((q)=>q.id).toSet(),{a.id,b.id});
    expect(list.length,2);
  });
  test('Two different successful sessions resolve an error; relapse restores it',(){
    final e=LearningEngine(),m=<String,dynamic>{};final id=bank.first.id;
    e.record(m,id,false,'one');e.record(m,id,true,'two');e.record(m,id,true,'two');
    expect(e.pending(m),contains(id));e.record(m,id,true,'three');expect(e.pending(m),isEmpty);
    e.record(m,id,false,'four');expect(e.pending(m),contains(id));
  });
  test('Source and variant isolation with fifty questions',(){
    final e=LearningEngine();
    for(final source in ['file2','file3']){for(final variant in ['original','modified']){
      final list=e.plan(bank,{},exam:true,count:50,source:source,variant:variant);
      expect(list.length,source=='file2'&&variant=='original'?38:50);
      expect(list.every((q)=>q.sourceId==source&&q.variant==variant),isTrue);
      expect(list.map((q)=>q.id).toSet().length,list.length);
    }}
  });
  test('Shuffling preserves identities and varies identical permutations',(){
    final e=LearningEngine(Random(5));final options=['أ','ب','ج','د'];
    var previous=options;
    for(var i=0;i<20;i++){final next=e.varied(options,previous);expect(next.toSet(),options.toSet());expect(next, isNot(equals(previous)));previous=next;}
  });
  test('Review-only source material never enters a scored session',(){
    final e=LearningEngine();final id=bank.firstWhere((q)=>q.reviewOnly).id,m=<String,dynamic>{};
    e.record(m,id,false,'one');expect(e.plan(bank,m,exam:true,count:10).any((q)=>q.reviewOnly),isFalse);
  });
}
