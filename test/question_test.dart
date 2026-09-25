import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:basira/question.dart';
import 'package:basira/question_types.dart';

void main() {
  final questions = (jsonDecode(File('assets/data/questions.json').readAsStringSync()) as List)
      .map((q) => Question(q)).toList();
  test('All 24 types are sorular-only; no retired question IDs', () {
    expect(kinds.length, 24);
    expect(questions.map((q) => q.type).toSet(), kinds.keys.toSet());
    for (final q in questions) {
      expect(q.page, greaterThan(0));
      expect(q.book, 'sorular');
      expect(q.id, greaterThan(100000));
      expect(q.lineStart, greaterThan(0));
      expect(q.lineEnd, greaterThanOrEqualTo(q.lineStart));
      expect(q.sourceBlocks, contains(q.page));
    }
  });
  for (final q in questions) {
    test('Grading: ${q.id} / ${q.type}', () {
      Object? correct;
      Object? wrong = 'إجابة غير صحيحة';
      switch (q.mode) {
        case 'single': correct = q.answer;
        case 'text': correct = q.accepted.first;
        case 'multi':
        case 'order':
          correct = q.correct;
          wrong = q.correct.take(q.correct.length - 1).toList();
        case 'match':
          correct = q.pairs.map((p) => p['right']).toList();
          wrong = List.filled(q.pairs.length, 'خطأ');
        case 'group':
          correct = q.parts.map((p) => p['answer']).toList();
          wrong = List.filled(q.parts.length, 'خطأ');
        default:
          expect(q.selfGraded, isTrue);
          expect(evaluateAnswer(q, q.answer), isFalse, reason: 'Self-assessment must not be marked automatically');
          return;
      }
      expect(evaluateAnswer(q, correct), isTrue);
      expect(evaluateAnswer(q, wrong), isFalse);
      expect(evaluateAnswer(q, null), isFalse);
    });
  }
  test('Multiple choice rejects extra options and incomplete answers', () {
    final q = questions.firstWhere((q) => q.type == 'multiple');
    expect(evaluateAnswer(q, [...q.correct, q.options.firstWhere((o) => !q.correct.contains(o))]), isFalse);
    expect(evaluateAnswer(q, q.correct.take(1).toList()), isFalse);
    expect(evaluateAnswer(q, q.correct.reversed.toList()), isTrue);
  });
  test('Text normalization does not guess synonyms', () {
    expect(acceptsAnswer(' الْخَوْفُ  ', ['الخوف']), isTrue);
    expect(acceptsAnswer('خوف', ['الخوف']), isFalse);
    expect(acceptsAnswer('إيمان', ['ايمان']), isTrue);
  });
  test('Array answers retain order in result formatting', () {
    expect(formatAnswer(['الأول', 'الثاني']), '1. الأول | 2. الثاني');
  });
}
