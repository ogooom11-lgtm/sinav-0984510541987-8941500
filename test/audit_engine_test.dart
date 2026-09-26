import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:basira/learning_engine.dart';
import 'package:basira/question.dart';

void main(){
  final bank=(jsonDecode(File('assets/data/questions.json').readAsStringSync()) as List).map((q)=>Question(q)).toList();
  final map={for(final q in bank)q.id:q};
  final engine=LearningEngine(Random(7));
  test('Review respects batch size; unselected mistakes remain pending',(){
    final memory=<String,dynamic>{};
    final questions=bank.where((q)=>q.sourceId=='file3'&&q.variant=='modified').toList();
    for(final q in questions){engine.record(memory,q.id,false,'old',now:q.id);}
    final list=engine.plan(bank,memory,review:true,count:10,source:'file3',variant:'modified');
    expect(list.length,10);expect(engine.pending(memory).length,80);
    expect(engine.plan(bank,memory,review:true,count:0),isEmpty);
  });
  test('Unseen questions take priority within shuffled concept diversity',(){
    final questions=bank.where((q)=>q.sourceId=='file3'&&q.variant=='original'&&!q.reviewOnly).take(3).toList();
    final memory=<String,dynamic>{};
    engine.record(memory,questions[0].id,true,'first');engine.record(memory,questions[0].id,true,'second');
    engine.record(memory,questions[1].id,true,'first');
    expect(engine.plan(questions,memory,count:1).single.id,questions[2].id);
    final groups=engine.sourceProgress(bank,memory);
    expect(groups.length,6);
    final g=groups.firstWhere((g)=>g['source']=='file3'&&g['variant']=='original');
    expect(g['mastered'],1);expect(g['tried'],2);expect(g['total'],60);
  });
  test('Draft validator rejects impossible indexes and changed options',(){
    final q=bank.firstWhere((q)=>q.type=='choice'&&!q.reviewOnly);
    final draft=<String,dynamic>{'id':'draft','ids':[q.id],'index':0,'exam':true,'answers':[],'selected':'','options':q.options,'hints':0,'revealed':false};
    expect(engine.validSession(draft,map),isTrue);
    expect(engine.validSession({...draft,'index':-1},map),isFalse);
    expect(engine.validSession({...draft,'options':[]},map),isFalse);
    expect(engine.validSession({...draft,'ids':[q.id,q.id]},map),isFalse);
    expect(engine.validSession({...draft,'index':1,'answers':[{'id':q.id,'correct':true}]},map),isTrue);
    expect(engine.validSession({...draft,'index':1,'answers':[{'id':q.id,'correct':null}]},map),isFalse);
  });
  test('Partial damaged storage does not erase valid history or memory',(){
    final q=bank.firstWhere((q)=>!q.reviewOnly);
    final raw=<String,dynamic>{'saved':[q.id,q.id,-1],'memory':{'${q.id}':{'wrong':1,'streak':0,'last':1},'bad':null},'settings':{'goal':0,'motion':false},'orders':null,'attempts':[null,{'date':'','answers':[{'id':q.id,'correct':true},null]}],'active':{'ids':[q.id],'index':-1}};
    final clean=engine.sanitizeState(raw,bank,[]);
    expect(clean['saved'],[q.id]);expect(clean['memory']['${q.id}']['wrong'],1);
    expect(clean['settings']['goal'],10);expect(clean['settings']['motion'],isFalse);
    expect(clean['attempts'].length,1);expect(clean['attempts'][0]['answers'].length,1);
    expect(clean['active'],isNull);expect(clean['orders'],isEmpty);
  });
  test('Stored totals are typed numbers, with safe invalid-value fallbacks',(){
    final q=bank.firstWhere((q)=>!q.reviewOnly);
    final cases=<Object?,num>{null:1,'4':1,-3:0,0:0,4:4,2.5:2.5,double.infinity:1,double.nan:1};
    for(final entry in cases.entries){
      final clean=engine.sanitizeState({
        'memory':{'${q.id}':{'wrong':1,'streak':0,'last':1,'total':entry.key}}
      },bank,[]);
      expect(clean['memory']['${q.id}']['total'],entry.value);
      expect(clean['memory']['${q.id}']['total'],isA<num>());
    }
  });

}
