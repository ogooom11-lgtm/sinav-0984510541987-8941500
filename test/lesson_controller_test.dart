import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:basira/features/lessons/data/lesson_repository.dart';
import 'package:basira/features/lessons/domain/lesson.dart';
import 'package:basira/features/lessons/domain/lesson_controller.dart';

class MemoryRepository extends LessonRepository {
  Map<String,dynamic> data={};
  bool fail=false;
  @override Future<List<Lesson>> load() async {
    final payload=jsonDecode(File('assets/data/lessons.json').readAsStringSync()) as Map;
    return (payload['lessons'] as List).map((v)=>Lesson(Map<String,dynamic>.from(v))).toList();
  }
  @override Future<Map<String,dynamic>> restore() async=>data;
  @override Future<void> save(Map<String,dynamic> value) async {
    if(fail)throw StateError('quota');
    data=Map<String,dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
  }
}
void main(){
 test('immediate grading is once-only and saved drafts remain locked',() async {
  final repo=MemoryRepository();
  final engine=LessonController(repo,random:Random(1));await engine.load();
  engine.start([engine.lessons.first]);final q=engine.current!;
  engine.answer(q.options.firstWhere((v)=>v!=q.answer));engine.answer(q.answer);
  expect(engine.score,0);expect(engine.pending(q.id),isTrue);await engine.writes;
  final restored=LessonController(repo);await restored.load();
  expect(restored.current!.id,q.id);expect(restored.selected,isNotNull);
  expect(restored.options,engine.options);restored.answer(q.answer);expect(restored.score,0);
  restored.start([restored.lessons.first],errorsOnly:true);restored.answer(q.answer);
  expect(restored.pending(q.id),isTrue);restored.next();
  restored.start([restored.lessons.first],errorsOnly:true);restored.answer(q.answer);
  expect(restored.pending(q.id),isFalse);await restored.writes;
  repo.fail=true;restored.persist();await restored.writes;expect(restored.saveError,isNotNull);
  engine.dispose();restored.dispose();
 });
}
