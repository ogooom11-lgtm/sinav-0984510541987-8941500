import 'dart:math';
import 'question.dart';

class LearningEngine {
  final Random random;
  LearningEngine([Random? random]) : random = random ?? Random();
  List<T> shuffled<T>(Iterable<T> items) => items.toList()..shuffle(random);
  List<String> varied(List<String> items, List<String> previous) {
    final result = shuffled(items);
    if (result.length > 1 && result.length == previous.length && List.generate(result.length, (i) => i).every((i) => result[i] == previous[i])) {
      result.add(result.removeAt(0));
    }
    return result;
  }
  List<int> pending(Map<String, dynamic> memory) {
    final entries = memory.entries.where((e) => e.value['wrong'] > 0 && e.value['streak'] < 2).toList();
    entries.sort((a,b) => (a.value['last'] as num).compareTo(b.value['last'] as num));
    return entries.map((e) => int.parse(e.key)).toList();
  }
  void record(Map<String, dynamic> memory, int id, bool correct, String sessionId, {int? now}) {
    final old = memory['$id'] ?? {'wrong':0, 'streak':0, 'total':0, 'last':0};
    final streak = correct ? (old['lastSession'] == sessionId ? old['streak'] : old['streak'] + 1) : 0;
    final timestamp = now ?? DateTime.now().millisecondsSinceEpoch;
    memory['$id'] = {'wrong': old['wrong'] + (correct ? 0 : 1), 'streak': streak, 'total':old['total']+1, 'last':timestamp, 'lastSession':sessionId, 'due':timestamp + (correct ? (streak >= 2 ? 7 : 1) : 0)*86400000};
  }
  List<Question> plan(List<Question> bank, Map<String,dynamic> memory, {int count=10, String section='', String type='', bool exam=false, bool review=false, List<int>? ids}) {
    final eligible=bank.where((q)=>!q.reviewOnly).toList();
    final map={for(final q in eligible) q.id:q};
    final due=(exam || review) ? pending(memory).where(map.containsKey).map((id)=>map[id]!).toList() : <Question>[];
    if(review) return due;
    final pool=shuffled(eligible.where((q)=>(section.isEmpty || q.section==section)&&(type.isEmpty || q.type==type)&&(ids==null || ids.contains(q.id))));
    final result=[...due], seen=due.map((q)=>q.id).toSet(), concepts=due.map((q)=>q.conceptKey).toSet();
    final target=max(count,due.length);
    for(final q in pool) { if(result.length>=target) break; if(!seen.contains(q.id)&&!concepts.contains(q.conceptKey)){result.add(q);seen.add(q.id);concepts.add(q.conceptKey);} }
    for(final q in pool) { if(result.length>=target) break; if(seen.add(q.id))result.add(q); }
    return result;
  }
}
