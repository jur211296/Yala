import { escapeHtml as e } from "./format";
import type { Bar, Card, PanelView, Seg } from "./view";

/**
 * La página. Estilo de la maqueta aprobada (`docs/telemetria/maqueta-panel.html`): una columna, secciones con su frase
 * arriba y tarjetas debajo, claro y oscuro. Sin JavaScript y sin nada de fuera salvo las fuentes de Google.
 * Todo texto que viene de datos pasa por `escapeHtml`.
 */
const CSS = `
:root{--bg:#f5f5fa;--surface:#fff;--ink:#17172a;--muted:#5d5f78;--line:#e2e2ee;--accent:#6063f1;--accent-soft:#ececfe;--ok:#1f8a5b;--warn:#b26a00;--bad:#c2384a;--pending:#7c4ddb;--pending-soft:#f2ecfe;
--f-display:"Bricolage Grotesque","Avenir Next",system-ui,sans-serif;--f-body:"Instrument Sans",-apple-system,"Segoe UI",sans-serif;--f-data:"JetBrains Mono",ui-monospace,"SF Mono",monospace}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#11121b;--surface:#1a1b28;--ink:#ececf6;--muted:#a3a5bf;--line:#2b2c3d;--accent:#8b8dff;--accent-soft:#24254a;--ok:#4cc58d;--warn:#e6a23c;--bad:#ff6b7d;--pending:#b79bff;--pending-soft:#2a2140;color-scheme:dark}}
:root[data-theme="dark"]{--bg:#11121b;--surface:#1a1b28;--ink:#ececf6;--muted:#a3a5bf;--line:#2b2c3d;--accent:#8b8dff;--accent-soft:#24254a;--ok:#4cc58d;--warn:#e6a23c;--bad:#ff6b7d;--pending:#b79bff;--pending-soft:#2a2140;color-scheme:dark}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--f-body);font-size:15px;line-height:1.5;padding:0 max(16px,env(safe-area-inset-right,0px)) 48px max(16px,env(safe-area-inset-left,0px))}
.wrap{max-width:920px;margin:0 auto;display:grid;gap:40px}
h1,h2{font-family:var(--f-display);text-wrap:balance;margin:0;letter-spacing:-.01em}
h1{font-size:clamp(28px,6vw,40px);font-weight:700}h2{font-size:24px;font-weight:700}
p{margin:0;max-width:66ch}
.eyebrow{font-family:var(--f-data);font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted)}
header.top{padding-top:28px;display:grid;gap:10px}
nav.sec{position:sticky;top:0;z-index:5;background:var(--bg);padding-block:10px;display:flex;gap:6px;overflow-x:auto;border-bottom:1px solid var(--line);scrollbar-width:none}
nav.sec a{text-decoration:none;color:var(--ink);font-weight:500;font-size:14px;padding:6px 12px;border-radius:999px;white-space:nowrap}
nav.sec a:hover,nav.sec a:focus-visible{background:var(--accent-soft);color:var(--accent);outline:none}
section.s{display:grid;gap:16px;scroll-margin-top:64px}
.lead{font-family:var(--f-display);font-size:clamp(19px,3.6vw,23px);line-height:1.3;font-weight:500;max-width:40ch}
.lead b{color:var(--accent);font-weight:700}
.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:12px}
.card{background:var(--surface);border:1px solid var(--line);border-radius:14px;padding:16px;display:grid;gap:8px;align-content:start;min-width:0}
.card.pending{border-style:dashed}
.row{display:flex;justify-content:space-between;align-items:baseline;gap:8px;flex-wrap:wrap}
.k{font-size:13px;color:var(--muted);font-weight:500}
.chip{font-family:var(--f-data);font-size:11px;padding:3px 8px;border-radius:999px;white-space:nowrap;border:1px solid transparent}
.chip.medido{background:var(--accent-soft);color:var(--accent)}.chip.servidor{color:var(--muted);border-color:var(--line)}.chip.pending{background:var(--pending-soft);color:var(--pending)}
.num{font-family:var(--f-data);font-size:30px;font-weight:600;font-variant-numeric:tabular-nums;line-height:1.1}
.num small{font-size:14px;color:var(--muted);font-weight:400}
.delta{font-family:var(--f-data);font-size:12px}.up{color:var(--ok)}.down{color:var(--bad)}.flat{color:var(--muted)}
.say{font-size:14px}.note{font-size:13px;color:var(--muted)}
.spark{width:100%;height:44px;display:block}
.bars{display:grid;gap:6px}
.bar{display:grid;grid-template-columns:minmax(0,10em) 1fr 3.5em;gap:8px;align-items:center;font-size:13px}
.bar span{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--muted)}
.bar i{display:block;height:8px;border-radius:4px;background:var(--accent);min-width:2px}
.bar.warn i{background:var(--warn)}.bar.bad i{background:var(--bad)}.bar.ok i{background:var(--ok)}
.bar b{font-family:var(--f-data);font-weight:600;text-align:right;font-variant-numeric:tabular-nums}
footer{border-top:1px solid var(--line);padding-top:16px;display:grid;gap:6px;font-size:13px;color:var(--muted)}
.empty{padding:28px 0;display:grid;gap:10px}
`;

const TAG_TEXT: Record<Card["tag"], string> = { medido: "medido", servidor: "del servidor", "sin datos": "sin datos aún" };

function segs(lead: Seg[]): string {
  return lead.map((s) => (s.b ? `<b>${e(s.t)}</b>` : e(s.t))).join("");
}

function spark(values: number[]): string {
  if (values.length < 2) return "";
  const max = Math.max(1, ...values);
  const w = 300;
  const h = 44;
  const pts = values.map((v, i) => `${((i / (values.length - 1)) * w).toFixed(1)},${(h - 4 - (v / max) * (h - 8)).toFixed(1)}`).join(" ");
  return `<svg class="spark" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" aria-hidden="true"><polyline points="${pts}" fill="none" stroke="var(--accent)" stroke-width="2" vector-effect="non-scaling-stroke"/></svg>`;
}

function barsHtml(list: Bar[]): string {
  if (!list.length) return "";
  const max = Math.max(1, ...list.map((b) => b.value));
  return `<div class="bars">${list
    .map((b) => {
      const w = Math.max(1, Math.round((b.value / max) * 100));
      return `<div class="bar${b.level && b.level !== "info" ? ` ${b.level}` : ""}"><span title="${e(b.label)}">${e(b.label)}</span><i style="width:${w}%"></i><b>${e(b.display)}</b></div>`;
    })
    .join("")}</div>`;
}

function card(c: Card): string {
  const pending = c.tag === "sin datos";
  return `<div class="card${pending ? " pending" : ""}">
<div class="row"><span class="k">${e(c.title)}</span><span class="chip ${pending ? "pending" : c.tag}">${TAG_TEXT[c.tag]}</span></div>
${c.big !== undefined ? `<div class="row"><span class="num">${e(c.big)}${c.bigSmall ? ` <small>${e(c.bigSmall)}</small>` : ""}</span>${c.delta ? `<span class="delta ${c.delta.dir}">${e(c.delta.text)}</span>` : ""}</div>` : ""}
${c.spark ? spark(c.spark) : ""}${c.bars ? barsHtml(c.bars) : ""}
${c.say ? `<p class="say">${e(c.say)}</p>` : ""}${c.note ? `<p class="note">${e(c.note)}</p>` : ""}
</div>`;
}

export function renderPage(view: PanelView, footer: { throughDay: string | null; lastRun: string; generatedAt: string }): string {
  const head = `<!doctype html><html lang="es"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Panel de Yala</title><meta name="robots" content="noindex">
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:wght@500;700&family=Instrument+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;600&display=swap">
<style>${CSS}</style></head><body><div class="wrap">`;
  const foot = `<footer><p>Al día hasta el ${e(footer.throughDay ?? "—")} (UTC). ${e(footer.lastRun)}</p>
<p>Nada que identifique a nadie: ni correo, ni cuenta, ni montos, ni textos. Un corte con menos de 3 aparatos se pinta «menos de 3».</p>
<p>Generado ${e(footer.generatedAt)}.</p></footer></div></body></html>`;

  if (!view.hasData) {
    return `${head}<header class="top"><span class="eyebrow">Panel de Yala</span><h1>Panel de Yala</h1></header>
<div class="empty"><p class="lead">Todavía no hay ningún día resumido.</p><p class="note">El resumen corre cada madrugada (06:00 UTC). La primera corrida rellena los últimos 85 días.</p></div>${foot}`;
  }
  const nav = view.sections.map((s) => `<a href="#${s.id}">${e(s.title)}</a>`).join("");
  const body = view.sections
    .map((s) => `<section class="s" id="${s.id}"><h2>${e(s.title)}</h2><p class="lead">${segs(s.lead)}</p><div class="cards">${s.cards.map(card).join("")}</div></section>`)
    .join("");
  return `${head}<header class="top"><span class="eyebrow">Semana ${e(view.week.label)}</span><h1>Panel de Yala</h1>
<p>Cada número va con una frase que se entiende sin saber de métricas. «Medido» sale de lo que mandan la app y el servidor; «del servidor», de contar en la base o en los avisos de Apple.</p></header>
<nav class="sec" aria-label="Secciones">${nav}</nav>${body}${foot}`;
}
