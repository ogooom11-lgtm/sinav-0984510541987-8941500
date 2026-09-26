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
  List<Question> plan(List<Question> bank, Map<String,dynamic> memory, {int count=10, String section='', String type='', String source='', String variant='', bool exam=false, bool review=false, List<int>? ids}) {
    final eligible=bank.where((q)=>!q.reviewOnly&&(source.isEmpty||q.sourceId==source)&&(variant.isEmpty||q.variant==variant)&&(section.isEmpty||q.section==section)&&(type.isEmpty||q.type==type)&&(ids==null||ids.contains(q.id))).toList();
    final map={for(final q in eligible) q.id:q};
    final due=(exam || review) ? pending(memory).where(map.containsKey).map((id)=>map[id]!).toList() : <Question>[];
    count=max(0,count);
    if(review) return due.take(count).toList();
    final pool=shuffled(eligible.where((q)=>(section.isEmpty || q.section==section)&&(type.isEmpty || q.type==type)&&(ids==null || ids.contains(q.id))));
    int priority(Question q)=>!memory.containsKey('${q.id}')?0:memory['${q.id}']['streak']<2?1:2;
    // Dart sort is not stable; explicit shuffled rank preserves random ties.
    final ranks={for(var i=0;i<pool.length;i++) pool[i].id:i};
    pool.sort((a,b){final diff=priority(a).compareTo(priority(b));return diff!=0?diff:ranks[a.id]!.compareTo(ranks[b.id]!);});
    final result=due.take(max(0,count)).toList(), seen=due.take(max(0,count)).map((q)=>q.id).toSet(), concepts=due.take(max(0,count)).map((q)=>q.conceptKey).toSet();
    final target=max(0,count);
    for(final q in pool) { if(result.length>=target) break; if(!seen.contains(q.id)&&!concepts.contains(q.conceptKey)){result.add(q);seen.add(q.id);concepts.add(q.conceptKey);} }
    for(final q in pool) { if(result.length>=target) break; if(seen.add(q.id))result.add(q); }
    return result;
  }
  List<Map<String,dynamic>> sourceProgress(List<Question> bank,Map<String,dynamic> memory){
    final groups=<String,Map<String,dynamic>>{};
    for(final q in bank.where((q)=>!q.reviewOnly)){
      final g=groups.putIfAbsent('${q.sourceId}:${q.variant}',()=>{'source':q.sourceId,'variant':q.variant,'total':0,'tried':0,'mastered':0,'pending':0});
      g['total']++;final m=memory['${q.id}'];if(m==null)continue;
      if((m['total']??0)>0||(m['last']??0)>0)g['tried']++;
      if(m['streak']>=2)g['mastered']++;if(m['wrong']>0&&m['streak']<2)g['pending']++;
    }return groups.values.toList();
  }
  bool validSession(dynamic s,Map<int,Question> bank){
    if(s is! Map||s['id'] is! String||s['exam'] is! bool||s['ids'] is! List||s['index'] is! int||s['answers'] is! List)return false;
    final ids=s['ids'] as List,answers=s['answers'] as List,index=s['index'] as int;
    if(ids.isEmpty||ids.toSet().length!=ids.length||!ids.every((id)=>bank.containsKey(id)&&!bank[id]!.reviewOnly)||index<0||index>ids.length||answers.length!=index)return false;
    for(var i=0;i<answers.length;i++){final a=answers[i];if(a is! Map||a['id']!=ids[i]||!(a['correct'] is bool||(a['correct']==null&&s['exam']==true&&bank[a['id']]!.selfGraded)))return false;}
    if(index==ids.length)return true;
    final q=bank[ids[index]]!,m=q.mode;
    if(s.containsKey('currentRecorded')&&(s['currentRecorded'] is! bool||(s['currentRecorded']==true&&(s['revealed']!=true||s['exam']==true||m=='self'))))return false;
    bool perm(dynamic a,List<dynamic> b)=>a is List&&a.length==b.length&&a.toSet().length==a.length&&a.every(b.contains);
    if(s['options'] is! List||s['hints'] is! int||s['hints']<0||s['hints']>q.hints.length||s['revealed'] is! bool)return false;
    final selected=s['selected'];
    if(['single','multi'].contains(m)&&!perm(s['options'],q.options))return false;
    if(m=='single')return selected is String&&(selected.isEmpty||q.options.contains(selected));
    if(m=='multi')return selected is List&&selected.toSet().length==selected.length&&selected.every(q.options.contains);
    if(m=='order')return perm(selected,q.options);
    if(m=='match'||m=='group'){
      final length=m=='match'?q.pairs.length:q.parts.length;
      if(!perm(s[m=='match'?'pairOrder':'partOrder'],List.generate(length,(i)=>i))||selected is! List||selected.length!=length||!selected.every((v)=>v is String))return false;
      return m!='match'||perm(s['options'],q.pairs.map((p)=>p['right']).toList());
    }return selected is String;
  }
  Map<String,dynamic> sanitizeState(Map<String,dynamic> raw,List<Question> questions,List<dynamic> retired){
    final data=Map<String,dynamic>.from(raw),bank={for(final q in questions)q.id:q};
    bool eligible(dynamic id)=>bank.containsKey(id)&&!bank[id]!.reviewOnly;
    data['saved']=(data['saved'] is List?data['saved'] as List:[]).where(eligible).toSet().toList();
    final cleaned=<String,dynamic>{};
    if(data['memory'] is Map){for(final e in (data['memory'] as Map).entries){final v=e.value;if(eligible(int.tryParse(e.key.toString()))&&v is Map&&['wrong','streak','last'].every((k)=>v[k] is int&&v[k]>=0)){cleaned[e.key.toString()]={...v,'total':v['total'] is num?max(0,v['total']):1};}}}
    data['memory']=cleaned;
    data['orders']=data['orders'] is Map?Map<String,dynamic>.fromEntries((data['orders'] as Map).entries.where((e)=>eligible(int.tryParse(e.key.toString()))&&e.value is List&&(e.value as List).every((v)=>v is String)).map((e)=>MapEntry(e.key.toString(),e.value))):<String,dynamic>{};
    data['attempts']=(data['attempts'] is List?data['attempts'] as List:[]).where((a)=>a is Map&&a['answers'] is List).map((a)=>{...Map<String,dynamic>.from(a),'date':a['date'] is String?a['date']:'','answers':(a['answers'] as List).where((x)=>x is Map&&(bank.containsKey(x['id'])||retired.contains(x['id']))&&x['correct'] is bool).toList()}).where((a)=>(a['answers'] as List).isNotEmpty).toList();
    final st=data['settings'] is Map?data['settings'] as Map:{};
    data['settings']={'large':st['large']==true,'motion':st['motion']!=false,'focus':st['focus']==true,'goal':[5,10,15,20].contains(st['goal'])?st['goal']:10};
    if(!validSession(data['active'],bank))data['active']=null;
    data['schema']=2;return data;
  }

}
