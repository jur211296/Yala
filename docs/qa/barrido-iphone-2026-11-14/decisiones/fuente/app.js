// Selector de respuestas. Cada decisión es un documento en `respuestas/<id>` de la db del artifact:
// { opcion, nota, quien, cuando }. Sin db (vista previa, sesión cerrada) la página se lee igual y avisa.
(function () {
  const ids = window.DECISIONES;
  const nombres = window.NOMBRES;
  const recos = window.RECOS;
  const estado = {};
  let db = null;
  let quien = null;

  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));

  function aviso(texto, tipo) {
    const el = $("#guardado");
    el.textContent = texto;
    el.dataset.tipo = tipo || "";
  }

  function pintar() {
    let n = 0;
    ids.forEach((id) => {
      const r = estado[id];
      const op = r && r.opcion;
      if (op) n++;
      $$(`.op[data-dec="${id}"]`).forEach((art) => art.classList.toggle("elegida", art.dataset.op === op));
      $$(`.elegir[data-dec="${id}"]`).forEach((b) => {
        const on = b.dataset.op === op;
        b.setAttribute("aria-pressed", on ? "true" : "false");
        b.textContent = on ? `Elegida: ${b.dataset.op}` : `Elijo ${b.dataset.op}`;
      });
      const e = $(`[data-estado="${id}"]`);
      if (e) {
        e.textContent = op ? `Respondida: ${op}` : "Sin responder";
        e.classList.toggle("ok", !!op);
      }
      const t = $(`#nota-${id}`);
      if (t && document.activeElement !== t && r && typeof r.nota === "string") t.value = r.nota;
    });
    $("#contador").textContent = `${n} de ${ids.length} respondidas`;
    const ol = $("#lista-resumen");
    ol.textContent = "";
    ids.forEach((id) => {
      const li = document.createElement("li");
      const r = estado[id];
      const b = document.createElement("b");
      b.textContent = nombres[id] + ": ";
      li.appendChild(b);
      const s = document.createElement("span");
      s.textContent = r && r.opcion ? r.opcion + (r.opcion === recos[id] ? " (la recomendada)" : "") : "sin responder";
      if (!(r && r.opcion)) s.className = "pend";
      li.appendChild(s);
      if (r && r.nota) {
        const q = document.createElement("q");
        q.textContent = r.nota;
        li.appendChild(q);
      }
      ol.appendChild(li);
    });
  }

  async function guardar(id, cambios) {
    estado[id] = Object.assign({}, estado[id], cambios);
    pintar();
    if (!db) {
      aviso("No se puede guardar aquí: abre el enlace con tu sesión de Claude.", "error");
      return;
    }
    aviso("Guardando…");
    try {
      await db.doc(`respuestas/${id}`).set(Object.assign({}, estado[id], { quien: quien || "", cuando: new Date().toISOString() }));
      aviso("Guardado", "ok");
    } catch (e) {
      aviso(e && e.code === "not_granted" ? "Tu permiso es de solo lectura." : "No se guardó. Vuelve a intentarlo.", "error");
    }
  }

  document.addEventListener("click", (ev) => {
    const b = ev.target.closest(".elegir");
    if (b) {
      guardar(b.dataset.dec, { opcion: b.dataset.op });
      return;
    }
    if (ev.target.closest("#todas-reco")) {
      ids.forEach((id) => {
        if (!(estado[id] && estado[id].opcion)) guardar(id, { opcion: recos[id] });
      });
    }
  });

  const pendientes = {};
  document.addEventListener("input", (ev) => {
    const t = ev.target.closest(".nota-campo");
    if (!t) return;
    clearTimeout(pendientes[t.dataset.dec]);
    pendientes[t.dataset.dec] = setTimeout(() => guardar(t.dataset.dec, { nota: t.value.trim() }), 900);
  });

  pintar();

  (async function conectar() {
    if (!window.claude || !window.claude.use) {
      aviso("Vista sin guardado: abre el enlace del artifact con tu sesión.", "error");
      return;
    }
    const tope = setTimeout(() => aviso("No llegan las respuestas guardadas; puedes elegir igual.", "error"), 10000);
    try {
      db = await window.claude.use("db");
      const user = await window.claude.use("user");
      if (user && user.id) {
        try { quien = await user.id(); } catch (e) { quien = null; }
      }
    } catch (e) {
      db = null;
    }
    if (!db) {
      clearTimeout(tope);
      aviso("Vista sin guardado: abre el enlace con tu sesión de Claude.", "error");
      return;
    }
    db.collection("respuestas").onSnapshot(
      (snap) => {
        clearTimeout(tope);
        snap.docs.forEach((d) => {
          if (d.exists && ids.includes(d.id)) estado[d.id] = d.data();
        });
        pintar();
      },
      () => {
        clearTimeout(tope);
        aviso("No se pudieron leer las respuestas guardadas.", "error");
      }
    );
  })();
})();
