(function (root) {
  "use strict";
  class LessonEngine {
    constructor(lessons, raw = {}, save = () => {}, rng = Math.random) {
      this.lessons = lessons;
      this.save = save;
      this.rng = rng;
      this.error = "";
      this.questions = new Map(
        lessons.flatMap((l) =>
          l.questions.map((q) => [q.id, { ...q, sourceId: l.sourceId }]),
        ),
      );
      this.progress = {};
      this.read = new Set();
      this.orders = {};
      this.session = null;
      if (raw && typeof raw === "object") {
        for (const [id, p] of Object.entries(raw.progress || {}))
          if (
            this.questions.has(id) &&
            p &&
            Number.isInteger(p.streak) &&
            p.streak >= 0 &&
            p.streak <= 2 &&
            typeof p.wrong === "boolean" &&
            typeof p.lastSession === "string"
          )
            this.progress[id] = { ...p };
        if (Array.isArray(raw.read))
          this.read = new Set(
            raw.read.filter((id) => lessons.some((l) => l.id === id)),
          );
        if (raw.orders && typeof raw.orders === "object")
          for (const [id, opts] of Object.entries(raw.orders))
            if (this.permutation(opts, this.questions.get(id)?.options))
              this.orders[id] = opts;
        if (this.valid(raw.session)) this.session = raw.session;
      }
    }
    permutation(a, b) {
      return (
        Array.isArray(a) &&
        Array.isArray(b) &&
        a.length === b.length &&
        new Set(a).size === a.length &&
        a.every((v) => b.includes(v))
      );
    }
    valid(s) {
      if (
        !s ||
        typeof s.id !== "string" ||
        !Array.isArray(s.ids) ||
        !s.ids.length ||
        new Set(s.ids).size !== s.ids.length ||
        !s.ids.every((id) => this.questions.has(id)) ||
        new Set(s.ids.map((id) => this.questions.get(id).sourceId)).size !==
          1 ||
        !Number.isInteger(s.index) ||
        s.index < 0 ||
        s.index >= s.ids.length ||
        !Number.isInteger(s.score) ||
        s.score < 0 ||
        s.score > s.index + (s.selected !== null ? 1 : 0)
      )
        return false;
      const q = this.questions.get(s.ids[s.index]);
      return (
        this.permutation(s.options, q.options) &&
        (s.selected === null || q.options.includes(s.selected))
      );
    }
    persist() {
      try {
        this.save({
          progress: this.progress,
          read: [...this.read],
          orders: this.orders,
          session: this.session,
        });
        this.error = "";
      } catch (_) {
        this.error = "تعذّر الحفظ المحلي. التقدم مؤقت حتى تنجح إعادة الحفظ.";
      }
    }
    pending(id) {
      return (
        this.progress[id]?.wrong === true &&
        (this.progress[id]?.streak || 0) < 2
      );
    }
    shuffle(a) {
      a = [...a];
      for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(this.rng() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
      }
      return a;
    }
    start(scope, { errorsOnly = false, count = 50 } = {}) {
      if (new Set(scope.map((l) => l.sourceId)).size > 1)
        throw Error("Mixed source session");
      const candidates = this.shuffle(
        scope
          .flatMap((l) => l.questions)
          .filter((q) => !errorsOnly || this.pending(q.id)),
      );
      candidates.sort(
        (a, b) => Number(this.pending(b.id)) - Number(this.pending(a.id)),
      );
      this.session = {
        id: root.crypto?.randomUUID?.() || Date.now() + "-" + Math.random(),
        ids: candidates.slice(0, count).map((q) => q.id),
        index: 0,
        score: 0,
        selected: null,
        options: [],
      };
      this.prepare();
      this.persist();
    }
    current() {
      return (
        this.session && this.questions.get(this.session.ids[this.session.index])
      );
    }
    prepare() {
      const q = this.current();
      if (!q) return;
      const s = this.session;
      s.selected = null;
      s.options = this.shuffle(q.options);
      if (this.orders[q.id]?.indexOf(q.answer) === s.options.indexOf(q.answer))
        s.options.push(s.options.shift());
      this.orders[q.id] = [...s.options];
    }
    answer(value) {
      const q = this.current(),
        s = this.session;
      if (!q || s.selected !== null || !s.options.includes(value)) return false;
      s.selected = value;
      const correct = value === q.answer;
      if (correct) s.score++;
      const p = this.progress[q.id] || {
        streak: 0,
        wrong: false,
        lastSession: "",
      };
      this.progress[q.id] = {
        streak: correct
          ? p.lastSession === s.id
            ? p.streak
            : Math.min(2, p.streak + 1)
          : 0,
        wrong: correct ? p.wrong : true,
        lastSession: s.id,
      };
      this.persist();
      return true;
    }
    next() {
      if (!this.current() || this.session.selected === null) return;
      this.session.index++;
      this.prepare();
      this.persist();
    }
    markRead(id) {
      if (this.lessons.some((l) => l.id === id)) {
        this.read.add(id);
        this.persist();
      }
    }
  }
  root.LessonEngine = LessonEngine;
  if (typeof module !== "undefined") module.exports = LessonEngine;
})(typeof window === "undefined" ? globalThis : window);
