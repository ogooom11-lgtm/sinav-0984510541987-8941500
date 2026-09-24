import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const green = Color(0xff185847);
const muted = Color(0xff829087);
const kinds = {'choice': 'اختيار من متعدد', 'boolean': 'صح أم خطأ', 'short': 'إجابة قصيرة'};
void main() => runApp(const BasiraApp());

class Question {
  final int id, page;
  final String book, type, prompt, answer;
  final List<String> options;
  Question(Map<String, dynamic> j)
      : id = j['id'], page = j['page'], book = j['book'], type = j['type'],
        prompt = j['prompt'], answer = j['answer'], options = List<String>.from(j['options']);
}

class BasiraApp extends StatelessWidget {
  const BasiraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'بصيرة', debugShowCheckedModeBanner: false,
    locale: const Locale('ar'), supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: const Color(0xfff6f8f5),
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.white),
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: green, padding: const EdgeInsets.all(20)))),
    home: const Dashboard(),
  );
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});
  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  List<Map<String, dynamic>> books = [];
  List<Question> questions = [];
  List<int> saved = [];
  List<Map<String, dynamic>> attempts = [];
  SharedPreferences? prefs;
  bool loading = true;
  String? error;
  int tab = 0;
  String search = '', bookFilter = '', typeFilter = '';
  final labels = ['الرئيسية', 'مكتبة الكتب', 'بنك الأسئلة', 'الاختبارات', 'تقدّمي وإنجازاتي', 'أسئلتي المحفوظة'];
  final icons = [Icons.home_outlined, Icons.menu_book_outlined, Icons.quiz_outlined, Icons.assignment_outlined, Icons.insights_outlined, Icons.bookmark_outline];
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/books.json');
      final bank = await rootBundle.loadString('assets/data/questions.json');
      prefs = await SharedPreferences.getInstance();
      books = List<Map<String, dynamic>>.from(jsonDecode(raw));
      questions = (jsonDecode(bank) as List).map((q) => Question(q)).toList();
      try {
        saved = List<int>.from(jsonDecode(prefs!.getString('saved') ?? '[]'));
        attempts = List<Map<String, dynamic>>.from(jsonDecode(prefs!.getString('attempts') ?? '[]'));
      } catch (_) { saved = []; attempts = []; }
    } catch (_) { error = 'تعذّر تحميل المحتوى. حاول إعادة فتح التطبيق.'; }
    if (mounted) setState(() => loading = false);
  }
  Map<String, dynamic> book(String id) => books.firstWhere((b) => b['id'] == id);
  Future<void> toggle(int id) async {
    setState(() => saved.contains(id) ? saved.remove(id) : saved.add(id));
    await prefs?.setString('saved', jsonEncode(saved));
  }
  List<dynamic> get answers => attempts.expand((a) => a['answers'] as List).toList();
  int get accuracy => answers.isEmpty ? 0 : (answers.where((a) => a['correct'] == true).length / answers.length * 100).round();
  void go(int i) => setState(() { tab = i; search = ''; bookFilter = ''; typeFilter = ''; });
  Future<void> start({String bookId = '', String type = '', bool exam = false, int count = 5, List<int>? ids}) async {
    final pool = questions.where((q) => (bookId.isEmpty || q.book == bookId) && (type.isEmpty || q.type == type) && (!exam || q.type != 'short') && (ids == null || ids.contains(q.id))).toList()..shuffle(Random());
    if (pool.isEmpty) return;
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => QuizPage(
      questions: pool.take(count).toList(), exam: exam, books: books, saved: saved, onSave: toggle,
    )));
    if (result != null && mounted) {
      setState(() { attempts.add(result); tab = 4; });
      await prefs?.setString('attempts', jsonEncode(attempts));
    }
  }
  Widget nav() => Container(width: 230, color: Colors.white, padding: const EdgeInsets.all(18), child: Column(children: [
    const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.auto_awesome, color: green, size: 34), SizedBox(width: 12), Text('بصيرة', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: green))])),
    const Text('رحلتك إلى معرفة أعمق', style: TextStyle(color: muted)), const SizedBox(height: 35),
    for (int i = 0; i < labels.length; i++) Padding(padding: const EdgeInsets.only(bottom: 7), child: ListTile(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), selectedTileColor: const Color(0xffeaf2ed), selected: tab == i, leading: Icon(icons[i]), title: Text(labels[i], style: const TextStyle(fontSize: 13)), onTap: () { go(i); if (MediaQuery.sizeOf(context).width < 950) Navigator.pop(context); })),
    const Spacer(), const Text('قليلٌ دائم، خيرٌ من كثيرٍ منقطع', style: TextStyle(color: muted)), const SizedBox(height: 30),
  ]));
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 950;
    return Scaffold(appBar: AppBar(title: Text('بصيرة  /  ${labels[tab]}', style: const TextStyle(fontSize: 17))),
      drawer: wide ? null : Drawer(child: SafeArea(child: nav())),
      body: Row(children: [if (wide) nav(), Expanded(child: loading ? const Center(child: CircularProgressIndicator()) : error != null ? Center(child: Text(error!)) : SingleChildScrollView(padding: EdgeInsets.all(wide ? 36 : 18), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: content()))))]));
  }
  Widget box(Widget child, {Color color = Colors.white}) => Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xffe5eae5))), child: child);
  Widget heading(String title, String sub) => Padding(padding: const EdgeInsets.only(bottom: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)), const SizedBox(height: 8), Text(sub, style: const TextStyle(color: muted))]));
  Widget library() => LayoutBuilder(builder: (context, c) => Wrap(spacing: 18, runSpacing: 18, children: books.asMap().entries.map((entry) {
    final b = entry.value;
    final colors = [const Color(0xffedf2e9), const Color(0xfff3eee3), const Color(0xffedf0f4)];
    return SizedBox(width: c.maxWidth > 700 ? (c.maxWidth - 36) / 3 : c.maxWidth, child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 110, width: double.infinity, decoration: BoxDecoration(color: colors[entry.key], borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.menu_book_rounded, size: 65, color: green)),
      const SizedBox(height: 18), Text(b['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
      Text(b['subtitle'], style: const TextStyle(color: muted)), const SizedBox(height: 14),
      Text('${(b['pages'] as List).length} صفحة  ·  ${questions.where((q) => q.book == b['id']).length} سؤالًا', style: const TextStyle(color: muted, fontSize: 12)),
      const Divider(height: 30), Wrap(spacing: 8, children: [FilledButton(onPressed: () => start(bookId: b['id']), child: const Text('ابدأ التعلّم')), TextButton(onPressed: () => sourceDialog(context, b, 1), child: const Text('تصفّح الكتاب'))]),
    ])));
  }).toList()));
  Widget stats() => Padding(padding: const EdgeInsets.symmetric(vertical: 22), child: Wrap(spacing: 14, runSpacing: 14, children: [
    for (final s in [['3', 'كتب في مكتبتك'], ['${questions.length}', 'سؤالًا لاختبار معرفتك'], ['${attempts.length}', 'تدريبات مكتملة'], ['$accuracy٪', 'الإجابات الصحيحة']]) SizedBox(width: 180, child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s[0], style: const TextStyle(fontSize: 28, color: green)), Text(s[1], style: const TextStyle(fontSize: 12, color: muted))])))
  ]));
  Widget content() {
    if (tab == 0) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      heading('أهلًا بك في بصيرة ✧', 'كل يوم فرصة لتعرف أكثر. ماذا سنتعلّم اليوم؟'),
      box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('مِن صفحات الكتب، إلى رسوخ المعرفة', style: TextStyle(color: Color(0xffd1dcbf))), const SizedBox(height: 12),
        const Text('لا تكتفِ بالقراءة… اختبر فهمك.', style: TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12), const Text('أسئلة من كتبك، وتدريبات متنوعة، وتقييم يساعدك على التقدّم.', style: TextStyle(color: Color(0xffc4d6cd))), const SizedBox(height: 24),
        Wrap(spacing: 14, children: [FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xffeee2bf), foregroundColor: green), onPressed: () => start(), child: const Text('ابدأ التدريب الآن ←')), OutlinedButton(onPressed: () => go(1), child: const Text('استكشف المكتبة', style: TextStyle(color: Colors.white)))])
      ]), color: green), stats(), heading('مكتبتك، بداية رحلتك', 'اختر كتابًا، وابدأ ببناء معرفة راسخة'), library(), const SizedBox(height: 28),
      box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('تعلّم بالطريقة التي تناسبك', style: TextStyle(fontSize: 21)), const SizedBox(height: 20), Wrap(spacing: 12, runSpacing: 12, children: [for (final e in kinds.entries) OutlinedButton(onPressed: () => start(type: e.key), child: Text(e.value)), FilledButton(onPressed: () => start(exam: true), child: const Text('تحدّي خمس أسئلة'))])]))
    ]);
    if (tab == 1) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('مكتبة الكتب', '110 صفحات من المصادر الأصلية'), library(), const SizedBox(height: 24), box(const Text('هذه نسخة أولية تضم 30 سؤالًا بصياغة تدريبية من المصادر، وليست تحويلًا كاملًا للكتب. النص المستخرج آليًا قد يحتوي على أخطاء عرض. الإجابات تمثل محتوى المراجعات وليست فتاوى مستقلة.'))]);
    if (tab == 2 || tab == 5) {
      final filtered = questions.where((q) => (tab != 5 || saved.contains(q.id)) && q.prompt.contains(search) && (bookFilter.isEmpty || q.book == bookFilter) && (typeFilter.isEmpty || q.type == typeFilter));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading(labels[tab], 'إجابات مرجعية ومصدر لكل سؤال'), TextField(decoration: const InputDecoration(hintText: 'ابحث عن سؤال…', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => search = v)), const SizedBox(height: 15), Wrap(spacing: 18, children: [
        DropdownButton<String>(value: bookFilter, items: [const DropdownMenuItem(value: '', child: Text('كل الكتب')), ...books.map((b) => DropdownMenuItem(value: b['id'] as String, child: Text(b['title'])))], onChanged: (v) => setState(() => bookFilter = v!)),
        DropdownButton<String>(value: typeFilter, items: [const DropdownMenuItem(value: '', child: Text('كل الأنواع')), ...kinds.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))], onChanged: (v) => setState(() => typeFilter = v!))]),
        if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Text('لا توجد أسئلة مطابقة. غيّر البحث أو احفظ سؤالًا أولًا.')),
        ...filtered.map((q) => Padding(padding: const EdgeInsets.only(top: 14), child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${book(q.book)['title']} · ${kinds[q.type]} · ص ${q.page}', style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 12), Text(q.prompt, style: const TextStyle(fontSize: 19)), const SizedBox(height: 12), Wrap(spacing: 10, children: [FilledButton(onPressed: () => start(ids: [q.id]), child: const Text('حل السؤال')), IconButton(tooltip: 'حفظ السؤال', onPressed: () => toggle(q.id), icon: Icon(saved.contains(q.id) ? Icons.bookmark : Icons.bookmark_outline)), TextButton(onPressed: () => sourceDialog(context, book(q.book), q.page), child: const Text('عرض المصدر'))])]))))
      ]);
    }
    if (tab == 3) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('اختبر معرفتك', 'تظهر الإجابات بعد إنهاء الاختبار'), box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('اختبار مختلط من الكتب الثلاثة', style: TextStyle(fontSize: 22)), const SizedBox(height: 12), const Text('اختيار من متعدد وصح أم خطأ، بتصحيح تلقائي.\nالإجابات القصيرة متاحة في التدريب بتقييم ذاتي.'), const SizedBox(height: 24), Wrap(spacing: 12, runSpacing: 12, children: [for (final n in [5, 10, 20]) FilledButton(onPressed: () => start(exam: true, count: n), child: Text('اختبار $n أسئلة'))])]))]);
    final wrong = answers.where((a) => a['correct'] == false).map((a) => a['id'] as int).toSet().toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [heading('تقدّمي وإنجازاتي', 'تقدّمك محفوظ محليًا على هذا الجهاز'), stats(), if (wrong.isNotEmpty) FilledButton(onPressed: () => start(ids: wrong, count: wrong.length), child: const Text('مراجعة أسئلة أخطأت فيها')), const SizedBox(height: 24), if (attempts.isEmpty) box(const Text('أكمل أول تدريب ليظهر تقدّمك هنا.')), ...attempts.reversed.map((a) { final list = a['answers'] as List; return Padding(padding: const EdgeInsets.only(bottom: 14), child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${a['exam'] == true ? 'اختبار المعرفة' : 'تدريب على مهل'}   ${list.where((x) => x['correct'] == true).length} / ${list.length}', style: const TextStyle(fontSize: 19)), Text(a['date'].toString().substring(0, 16), style: const TextStyle(color: muted)), if (list.any((x) => x['self'] == true)) const Text('يتضمن تقييمًا ذاتيًا للإجابات القصيرة', style: TextStyle(fontSize: 12, color: muted))]))); })]);
  }
}

Future<void> sourceDialog(BuildContext context, Map<String, dynamic> book, int initial) async {
  int page = initial;
  final pages = book['pages'] as List;
  await showDialog<void>(context: context, builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
    title: Text('${book['title']} · صفحة $page'),
    content: SizedBox(width: 650, child: SingleChildScrollView(child: SelectableText((pages[page - 1]['text'] as String).trim().isEmpty ? 'هذه الصفحة بلا نص قابل للاستخراج.' : pages[page - 1]['text'], style: const TextStyle(height: 1.9)))),
    actions: [TextButton(onPressed: page > 1 ? () => update(() => page--) : null, child: const Text('السابقة')), TextButton(onPressed: page < pages.length ? () => update(() => page++) : null, child: const Text('التالية')), TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
  )));
}

class QuizPage extends StatefulWidget {
  final List<Question> questions;
  final List<Map<String, dynamic>> books;
  final List<int> saved;
  final Future<void> Function(int) onSave;
  final bool exam;
  const QuizPage({super.key, required this.questions, required this.exam, required this.books, required this.saved, required this.onSave});
  @override
  State<QuizPage> createState() => _QuizPageState();
}
class _QuizPageState extends State<QuizPage> {
  int index = 0;
  String? selected;
  bool revealed = false, finished = false;
  final answers = <Map<String, dynamic>>[];
  final controller = TextEditingController();
  @override
  void dispose() { controller.dispose(); super.dispose(); }
  Question get q => widget.questions[index];
  void check() {
    if (q.type == 'short') selected = controller.text.trim();
    if (selected == null || selected!.isEmpty) return;
    if (widget.exam) { next(selected == q.answer); } else { setState(() => revealed = true); }
  }
  void next(bool correct) {
    answers.add({'id': q.id, 'selected': selected, 'correct': correct, 'self': q.type == 'short'});
    setState(() {
      if (index == widget.questions.length - 1) { finished = true; }
      else { index++; selected = null; revealed = false; controller.clear(); }
    });
  }
  Future<bool> confirmExit() async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('إنهاء التدريب؟'), content: const Text('لن تُحفظ نتيجة التدريب غير المكتمل.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('متابعة')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('إنهاء'))])) ?? false;
  void finish() => Navigator.pop(context, {'date': DateTime.now().toIso8601String(), 'exam': widget.exam, 'answers': answers});
  @override
  Widget build(BuildContext context) => PopScope(canPop: false, onPopInvokedWithResult: (didPop, result) async { if (didPop) return; if (finished) { finish(); } else if (await confirmExit() && context.mounted) { Navigator.pop(context); } }, child: Scaffold(
    appBar: AppBar(title: Text(widget.exam ? 'اختبار المعرفة' : 'تدريب على مهل')),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: Container(padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: finished ? resultView() : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${kinds[q.type]}  ·  السؤال ${index + 1} من ${widget.questions.length}', style: const TextStyle(color: muted)), const SizedBox(height: 18), LinearProgressIndicator(value: index / widget.questions.length), const SizedBox(height: 26), Text(q.prompt, style: const TextStyle(fontSize: 25, height: 1.7)), const SizedBox(height: 25),
      if (q.type == 'short') TextField(controller: controller, enabled: !revealed, maxLines: 4, decoration: const InputDecoration(hintText: 'اكتب إجابتك ثم قارنها بالإجابة المرجعية')) else ...q.options.map((o) => Padding(padding: const EdgeInsets.only(bottom: 12), child: OutlinedButton(style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(20), backgroundColor: selected == o ? const Color(0xffeaf2ed) : null), onPressed: revealed ? null : () => setState(() => selected = o), child: Align(alignment: Alignment.centerRight, child: Text(o))))),
      if (revealed) Container(margin: const EdgeInsets.symmetric(vertical: 18), padding: const EdgeInsets.all(18), color: const Color(0xffedf4ee), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(q.type == 'short' ? 'قارن إجابتك بالمرجع، ثم قيّم نفسك.' : selected == q.answer ? '✓ أحسنت، إجابتك صحيحة.' : 'تحتاج هذه المعلومة إلى مراجعة.'), Text('الإجابة المرجعية: ${q.answer}', style: const TextStyle(fontSize: 19)), TextButton(onPressed: () => sourceDialog(context, widget.books.firstWhere((b) => b['id'] == q.book), q.page), child: Text('صياغة تدريبية من المصدر · صفحة ${q.page}'))])),
      const SizedBox(height: 20), Wrap(spacing: 10, runSpacing: 10, children: [if (!revealed) FilledButton(onPressed: q.type != 'short' && selected == null ? null : check, child: Text(widget.exam ? 'تثبيت الإجابة والمتابعة' : 'تحقّق من الإجابة')) else if (q.type == 'short') ...[FilledButton(onPressed: () => next(true), child: const Text('إجابتي صحيحة')), OutlinedButton(onPressed: () => next(false), child: const Text('أحتاج مراجعة'))] else FilledButton(onPressed: () => next(selected == q.answer), child: const Text('متابعة ←')), IconButton(tooltip: 'حفظ السؤال', onPressed: () async { await widget.onSave(q.id); if (mounted) setState(() {}); }, icon: Icon(widget.saved.contains(q.id) ? Icons.bookmark : Icons.bookmark_outline))])
    ]))))),
  ));
  Widget resultView() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('خطوة جديدة تستحق التقدير', textAlign: TextAlign.center, style: TextStyle(fontSize: 26)), const SizedBox(height: 20), Text('${(answers.where((a) => a['correct'] == true).length / answers.length * 100).round()}٪', textAlign: TextAlign.center, style: const TextStyle(fontSize: 64, color: green)),
    if (answers.any((a) => a['self'] == true)) const Text('تتضمن النتيجة تقييمك الذاتي للإجابات القصيرة.', textAlign: TextAlign.center),
    ...answers.map((a) { final item = widget.questions.firstWhere((q) => q.id == a['id']); return ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 10), leading: Icon(a['correct'] == true ? Icons.check_circle_outline : Icons.refresh, color: green), title: Text(item.prompt), subtitle: Text('إجابتك: ${a['selected']}\nالإجابة المرجعية: ${item.answer}\nصفحة ${item.page}'), onTap: () => sourceDialog(context, widget.books.firstWhere((b) => b['id'] == item.book), item.page)); }),
    const SizedBox(height: 20), FilledButton(onPressed: finish, child: const Text('حفظ النتيجة وعرض تقدّمي'))
  ]);
}
