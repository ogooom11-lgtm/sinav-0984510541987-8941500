class LessonFact {
  final String id, title, text, sourceFile;
  final int block, start, end;
  LessonFact(Map<String, dynamic> j)
      : id=j['id'], title=j['title'], text=j['text'], sourceFile=j['sourceFile'],
        block=j['sourceBlock'], start=j['lineStart'], end=j['lineEnd'];
  String get reference => '$sourceFile · المقطع $block · الأسطر $start–$end';
}
class LessonQuestion {
  final String id, factId, prompt, answer, explanation;
  final List<String> options;
  LessonQuestion(Map<String, dynamic> j)
      : id=j['id'], factId=j['factId'], prompt=j['prompt'], answer=j['answer'],
        explanation=j['explanation'], options=List<String>.from(j['options']);
}
class Lesson {
  final String id, sourceId, title, objective;
  final List<LessonFact> facts;
  final List<LessonQuestion> questions;
  Lesson(Map<String, dynamic> j)
      : id=j['id'], sourceId=j['sourceId'], title=j['title'], objective=j['objective'],
        facts=(j['facts'] as List).map((v)=>LessonFact(Map<String,dynamic>.from(v))).toList(),
        questions=(j['questions'] as List).map((v)=>LessonQuestion(Map<String,dynamic>.from(v))).toList();
}
