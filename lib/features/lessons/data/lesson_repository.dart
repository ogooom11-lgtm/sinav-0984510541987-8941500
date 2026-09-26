import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/lesson.dart';
import '../domain/lesson_store.dart';

class LessonRepository implements LessonStore {
  static const storageKey='basira-lessons-v1';
  @override
  Future<List<Lesson>> load() async {
    final json=jsonDecode(await rootBundle.loadString('assets/data/lessons.json')) as Map;
    return (json['lessons'] as List).map((v)=>Lesson(Map<String,dynamic>.from(v))).toList();
  }
  @override
  Future<Map<String,dynamic>> restore() async {
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(storageKey);
    if(raw==null)return {};
    try { return Map<String,dynamic>.from(jsonDecode(raw) as Map); }
    catch (_) {
      // Keep the malformed payload for recovery, not an endless load failure.
      await prefs.setString('$storageKey.recovery',raw);
      return {};
    }
  }
  @override
  Future<void> save(Map<String,dynamic> data) async {
    final ok=await (await SharedPreferences.getInstance()).setString(storageKey,jsonEncode(data));
    if(!ok)throw StateError('Local storage failed');
  }
}
