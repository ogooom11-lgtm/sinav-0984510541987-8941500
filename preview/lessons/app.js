"use strict";
const key = "basira-lessons-v1",
  app = document.querySelector("#app");
const names = {
  sorular: "المراجعة الأساسية",
  file2: "الدروس الهجائية",
  file3: "العقيدة",
};
let engine,
  source = "sorular",
  lesson = null,
  quiz = false,
  notice = "";
const esc = (v) =>
  String(v).replace(
    /[&<>"']/g,
    (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[
        c
      ],
  );
const ref = (f) =>
  `${f.sourceFile} · المقطع ${f.sourceBlock} · الأسطر ${f.lineStart}–${f.lineEnd}`;
const button = (label, action, cls = "primary") =>
  `<button class="${cls}" data-action="${action}">${label}</button>`;
function begin(scope, errorsOnly = false) {
  engine.start(scope, { errorsOnly });
  quiz = true;
  render();
}
function render() {
  app.setAttribute("aria-busy", "false");
  const scope = engine.lessons.filter((l) => l.sourceId === source);
  let html = engine.error
    ? `<div class="error" role="alert">${esc(engine.error)} ${button("إعادة الحفظ", "save")}</div>`
    : "";
  if (quiz) {
    const s = engine.session,
      q = engine.current();
    if (!s.ids.length)
      html += `<h1>لا توجد أسئلة مستحقة الآن</h1><p>لا نملأ جلسة المراجعة بأسئلة لم تخطئ فيها.</p>${button("العودة للدروس", "home")}`;
    else if (!q)
      html += `<h1>أكملت المحاولة</h1><p class="score">${s.score} / ${s.ids.length}</p><p>الأخطاء محفوظة. يحتاج تثبيت السؤال نجاحًا في جلستين مختلفتين.</p>${button("العودة للدروس", "home")}`;
    else {
      const fact = engine.lessons
          .flatMap((l) => l.facts)
          .find((f) => f.id === q.factId),
        locked = s.selected !== null;
      html += `<section class="quiz"><p>${esc(names[q.sourceId])} · السؤال ${s.index + 1} من ${s.ids.length}</p><progress value="${s.index}" max="${s.ids.length}" aria-label="تقدم الجلسة"></progress><h2>${esc(q.prompt)}</h2>${s.options.map((o, i) => `<button class="option ${locked && o === q.answer ? "correct" : locked && o === s.selected ? "wrong" : ""}" data-option="${i}" ${locked ? "disabled" : ""}>${locked && o === q.answer ? "✓ " : locked && o === s.selected ? "✗ " : ""}${esc(o)}</button>`).join("")}`;
      if (locked)
        html += `<div class="feedback" role="status" aria-live="polite"><h2>${s.selected === q.answer ? "✓ إجابة صحيحة" : "✗ إجابة غير صحيحة"}</h2><p>الإجابة الصحيحة: ${esc(q.answer)}</p><p>${esc(q.explanation)}</p><small>${esc(ref(fact))}</small></div>${button(s.index + 1 === s.ids.length ? "عرض النتيجة" : "السؤال التالي", "next")}`;
      html += "</section>";
    }
  } else if (lesson) {
    html += `<span class="pill">${esc(names[lesson.sourceId])}</span><h1>${esc(lesson.title)}</h1><p>${esc(lesson.objective)}</p>${lesson.facts.map((f) => `<article class="fact"><h2>${esc(f.title)}</h2><p>${esc(f.text)}</p><small>${esc(ref(f))}</small></article>`).join("")}<div class="actions">${button(engine.read.has(lesson.id) ? "تمت القراءة ✓" : "أنهيت قراءة الدرس", "read", "")}${button("طبّق الآن · " + lesson.questions.length + " أسئلة", "practice")}</div><p class="notice">القراءة ليست إتقانًا. التثبيت يعتمد على الإجابات، لا على فتح الصفحة.</p>`;
  } else {
    html += `<span class="pill">من ملفاتك · دون معلومات خارجية</span><h1>افهم الفكرة.<br>ثم اختبر فهمك.</h1><p>درس قصير، اختيار واضح، ونتيجة فورية مع توضيح الجواب.</p><div class="tabs">${Object.entries(
      names,
    )
      .map(
        ([id, title]) =>
          `<button data-source="${id}" class="${source === id ? "selected" : ""}" aria-pressed="${source === id}">${title}</button>`,
      )
      .join(
        "",
      )}</div><p>${scope.length} دروس · ${scope.flatMap((l) => l.questions).length} أسئلة اختيار · ${scope.filter((l) => engine.read.has(l.id)).length} تمت قراءتها</p><div class="actions">${button("اختبار القسم · حتى 50 سؤالًا", "exam")}${button("راجع أخطاء هذا القسم", "review", "")}${engine.current() ? button("استئناف الجلسة المحفوظة", "resume", "") : ""}</div><div class="grid">${scope.map((l, i) => `<article class="card"><span class="pill">درس ${i + 1}</span><h2>${esc(l.title)}</h2><p>${l.questions.length} أسئلة · ${l.questions.filter((q) => engine.progress[q.id]?.streak >= 2).length} مثبتة</p>${button(engine.read.has(l.id) ? "راجع الدرس" : "ابدأ الدرس", "lesson:" + l.id)}</article>`).join("")}</div><p class="notice">${esc(notice)} التقدم محفوظ على هذا الجهاز فقط. التدريب الجديد قائم على الاختيار؛ تبقى التدريبات السابقة متاحة بشكل منفصل.</p>`;
  }
  app.innerHTML = html;
}
document.addEventListener("click", (event) => {
  if (!engine) return;
  const b = event.target.closest("button");
  if (!b) return;
  if (b.id === "home" || b.dataset.action === "home") {
    lesson = null;
    quiz = false;
    render();
    return;
  }
  if (b.dataset.source) {
    source = b.dataset.source;
    lesson = null;
    render();
    return;
  }
  if (b.dataset.option !== undefined) {
    engine.answer(engine.session.options[Number(b.dataset.option)]);
    render();
    return;
  }
  const a = b.dataset.action;
  if (!a) return;
  if (a.startsWith("lesson:")) {
    lesson = engine.lessons.find((l) => l.id === a.slice(7));
    quiz = false;
  }
  if (a === "read") engine.markRead(lesson.id);
  if (a === "practice") {
    begin([lesson]);
    return;
  }
  if (a === "exam" || a === "review") {
    begin(
      engine.lessons.filter((l) => l.sourceId === source),
      a === "review",
    );
    return;
  }
  if (a === "resume") quiz = true;
  if (a === "next") engine.next();
  if (a === "save") engine.persist();
  render();
});
async function load() {
  try {
    const response = await fetch("/assets/data/lessons.json");
    if (!response.ok) throw Error("load");
    const data = await response.json();
    notice = data.notice;
    let raw = {};
    try {
      const stored = localStorage.getItem(key);
      if (stored)
        try {
          raw = JSON.parse(stored);
        } catch (_) {
          localStorage.setItem(key + ".recovery", stored);
        }
    } catch (_) {}
    engine = new LessonEngine(data.lessons, raw, (state) =>
      localStorage.setItem(key, JSON.stringify(state)),
    );
    render();
  } catch (_) {
    app.innerHTML =
      '<h1>تعذّر تحميل الدروس</h1><button id="retry">إعادة المحاولة</button>';
    document.querySelector("#retry").onclick = load;
  }
}
load();
