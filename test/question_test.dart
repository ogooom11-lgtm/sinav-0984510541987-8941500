import 'package:flutter_test/flutter_test.dart';
import 'package:basira/main.dart';
void main() {
  test('Question preserves source and choices', () {
    final q = Question({'id': 1, 'page': 3, 'book': 'fiqh', 'type': 'boolean', 'prompt': 'سؤال', 'answer': 'صح', 'options': ['صح', 'خطأ']});
    expect(q.page, 3);
    expect(q.options, contains(q.answer));
    expect(q.book, 'fiqh');
  });
}
