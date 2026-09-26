import 'question_types.dart';

class Question {
  final int id, page, lineStart, lineEnd;
  final List<int> sourceBlocks;
  final String kind, section, origin, warning, conceptKey, explanation;
  final bool reviewOnly;
  final String book, type, prompt, answer, sourceId, sourceFile, variant, originalFormat;
  final List<String> options, accepted, correct, hints;
  final List<Map<String, dynamic>> pairs, parts;
  final String? passage;
  final List<Map<String,dynamic>> evidence;
  Question(Map<String, dynamic> j)
      : id = j['id'], page = j['page'], book = j['book'], type = j['type'],
        sourceId=j['sourceId']??j['book'], sourceFile=j['sourceFile']??'sorular.txt', variant=j['variant']??(j['kind']=='verbatim'?'original':'modified'), originalFormat=j['originalFormat']??'',
        lineStart = j['lineStart'] ?? 0, lineEnd = j['lineEnd'] ?? 0,
        sourceBlocks = List<int>.from(j['sourceBlocks'] ?? [j['page']]),
        conceptKey = j['conceptKey'] ?? 'block-${j['page']}',
        explanation = j['explanation'] ?? '',
        kind = j['kind'] ?? '', section = j['section'] ?? '', origin = j['origin'] ?? '',
        warning = j['warning'] ?? '', reviewOnly = j['reviewOnly'] ?? false,
        prompt = j['prompt'], answer = j['answer'],
        options = List<String>.from(j['options']),
        accepted = List<String>.from(j['accepted'] ?? []),
        correct = List<String>.from(j['correct'] ?? []),
        hints = List<String>.from(j['hints'] ?? []),
        pairs = List<Map<String, dynamic>>.from(j['pairs'] ?? []),
        parts = List<Map<String, dynamic>>.from(j['parts'] ?? []),
        evidence=j['evidence'] is List?List<Map<String,dynamic>>.from(j['evidence']):[],
        passage = j['passage'];
  String get reference => '$sourceFile · الأسطر ${evidence.isEmpty?"$lineStart–$lineEnd":evidence.map((e)=>"${e['lineStart']}–${e['lineEnd']}").join('، ')}';
  String get provenance => kind == 'verbatim' ? (originalFormat=='notes'?'نص أصلي مطابق — ليس سؤالًا أصليًا':'سؤال أصلي مطابق') : 'سؤال معدّل من المصدر';
  String get mode => questionModes[type]!;
  bool get selfGraded => mode == 'self';
}

// Only normalize spelling presentation. Open explanations are never auto-graded.
String normalizeAnswer(String value) => value
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670ـ]'), '')
    .replaceAll(RegExp('[أإآ]'), 'ا')
    .replaceAll(RegExp(r'[.,،؛؟!]'), '')
    .replaceAll(RegExp(r'\s+'), ' ').trim();
bool acceptsAnswer(String value, List<String> accepted) =>
    accepted.any((answer) => normalizeAnswer(answer) == normalizeAnswer(value));

bool evaluateAnswer(Question q, Object? value) {
  switch (q.mode) {
    case 'single': return value == q.answer;
    case 'text': return value is String && acceptsAnswer(value, q.accepted);
    case 'multi':
      return value is List && value.length == q.correct.length &&
          value.toSet().length == value.length && q.correct.every(value.contains);
    case 'order':
      return value is List && value.length == q.correct.length &&
          List.generate(q.correct.length, (i) => i).every((i) => value[i] == q.correct[i]);
    case 'match':
      return value is List && value.length == q.pairs.length &&
          List.generate(q.pairs.length, (i) => i).every((i) => value[i] == q.pairs[i]['right']);
    case 'group':
      return value is List && value.length == q.parts.length &&
          List.generate(q.parts.length, (i) => i).every((i) =>
              acceptsAnswer(value[i].toString(), List<String>.from(q.parts[i]['accepted'])));
    default: return false; // Self-assessment is an explicit user action.
  }
}

String formatAnswer(Object? value) => value is List
    ? value.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join(' | ')
    : (value ?? '').toString();
