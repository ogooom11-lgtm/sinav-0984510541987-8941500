import 'lesson.dart';

/// Boundary for lesson assets and local progress. The controller does not know
/// whether these live in SharedPreferences, files, or an in-memory test double.
abstract class LessonStore {
  Future<List<Lesson>> load();
  Future<Map<String,dynamic>> restore();
  Future<void> save(Map<String,dynamic> data);
}
