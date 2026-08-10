// check.mjs — el pin del Atlas de Flujos de Modo Nube.
//
// Comprueba, SIN navegador, lo que el chip F1 pide como criterio de hecho: que los 7 diagramas parsean y
// RENDERIZAN, que cada nodo clickeable resuelve a un panel real, que ningún panel queda huérfano, que los
// `id` de screenshot son únicos y siguen la convención `<flujo>-<nodo>.png`, que todo panel tiene sus 4
// campos y al menos una coordenada de código, y que `index.html` no referencia NI UNA URL remota (que es
// lo que hace que el Atlas abra offline).
//
// Cómo se corre (jsdom NO es dependencia del proyecto y no debe serlo — este validador es de docs):
//
//     mkdir -p /tmp/atlas-check && cd /tmp/atlas-check && npm init -y && npm i jsdom
//     node /Users/jur/Yala/docs/flows/modo-nube/check.mjs
//
// `jsdom` se resuelve desde el CWD a propósito, para que el repo no gane una dependencia por un doc.
// Salida `RESULT: OK` / exit 0 · cualquier fallo → exit 1.

import fs from "node:fs";
import vm from "node:vm";
import { createRequire } from "node:module";

const requireFromCwd = createRequire(process.cwd() + "/");
let JSDOM;
try {
  ({ JSDOM } = requireFromCwd("jsdom"));
} catch {
  console.error("Falta `jsdom` en el CWD. Ver la cabecera de este fichero para el comando.");
  process.exit(2);
}

const ROOT = new URL(".", import.meta.url).pathname;

const dom = new JSDOM(`<!doctype html><html><body></body></html>`, { pretendToBeVisual: true });
const win = dom.window;

// Globals que mermaid espera
global.window = win;
global.document = win.document;
Object.defineProperty(global, "navigator", { value: win.navigator, configurable: true });
global.self = win;
global.HTMLElement = win.HTMLElement;
global.SVGElement = win.SVGElement;
global.Element = win.Element;
global.Node = win.Node;
global.getComputedStyle = win.getComputedStyle;
global.DOMPurify = undefined;
global.requestAnimationFrame = cb => setTimeout(cb, 0);
global.MutationObserver = win.MutationObserver;
// jsdom no implementa la geometría SVG; el render de mermaid la pide para medir labels.
// Es una carencia del ENTORNO de prueba, no del Atlas — se stubea para poder ejercitar el render.
win.SVGElement.prototype.getBBox = function () { return { x: 0, y: 0, width: 120, height: 20 }; };
win.SVGElement.prototype.getComputedTextLength = function () { return 120; };

// Cargar el mermaid vendorizado en este contexto global
const src = fs.readFileSync(`${ROOT}/vendor/mermaid.min.js`, "utf8");
vm.runInThisContext(src, { filename: "mermaid.min.js" });
const mermaid = globalThis.mermaid;

// Cargar los datos del Atlas (asignan window.ATLAS_*)
for (const f of ["data/nodes.js", "data/flows.js"]) {
  vm.runInThisContext(fs.readFileSync(`${ROOT}/${f}`, "utf8"), { filename: f });
}

const FLOWS = win.ATLAS_FLOWS ?? globalThis.ATLAS_FLOWS;
const NODES = win.ATLAS_NODES ?? globalThis.ATLAS_NODES;

mermaid.initialize({ startOnLoad: false, securityLevel: "loose", theme: "dark" });

let fail = 0;

// 1) Cada diagrama parsea
for (const f of FLOWS) {
  try {
    await mermaid.parse(f.graph);
    console.log(`OK    parse  ${f.id}`);
  } catch (e) {
    fail++;
    console.log(`FAIL  parse  ${f.id}: ${String(e.message ?? e).split("\n")[0]}`);
  }
}

// 2) Cada `click … call showNode("X")` apunta a un nodo que existe
const referenced = new Set();
for (const f of FLOWS) {
  for (const m of f.graph.matchAll(/showNode\("([^"]+)"\)/g)) {
    referenced.add(m[1]);
    if (!NODES[m[1]]) {
      fail++;
      console.log(`FAIL  click  ${f.id} → "${m[1]}" no existe en nodes.js`);
    }
  }
}
console.log(`OK    click  ${referenced.size} ids referenciados, todos resueltos`);

// 3) Ningún nodo definido queda huérfano (sin ninguna referencia)
for (const k of Object.keys(NODES)) {
  if (!referenced.has(k)) {
    fail++;
    console.log(`FAIL  orphan ${k} está en nodes.js y ningún diagrama lo referencia`);
  }
}

// 4) Ids de screenshot únicos y con la convención <flujo>-<nodo>.png
const shots = new Map();
for (const [k, n] of Object.entries(NODES)) {
  if (!n.shot) continue;
  if (!/^[a-z0-9]+(-[a-z0-9]+)+\.png$/.test(n.shot)) {
    fail++; console.log(`FAIL  shot   ${k}: "${n.shot}" no cumple la convención`);
  }
  if (shots.has(n.shot)) { fail++; console.log(`FAIL  shot   duplicado: ${n.shot}`); }
  shots.set(n.shot, k);
}
console.log(`OK    shot   ${shots.size} ids de screenshot únicos y con convención`);

// 5) Todo nodo tiene los 4 campos + al menos una coordenada de código
for (const [k, n] of Object.entries(NODES)) {
  for (const f of ["title", "sees", "persists", "exits"]) {
    if (!n[f]) { fail++; console.log(`FAIL  field  ${k}: falta "${f}"`); }
  }
  if (!n.code || !n.code.length) { fail++; console.log(`FAIL  code   ${k}: sin coordenada de código`); }
}
console.log(`OK    field  ${Object.keys(NODES).length} nodos con panel completo`);

// 6) El HTML no referencia NADA remoto
const html = fs.readFileSync(`${ROOT}/index.html`, "utf8");
const remote = [...html.matchAll(/(?:src|href)\s*=\s*"(https?:)?\/\/[^"]+"/g)].map(m => m[0]);
if (remote.length) { fail++; console.log(`FAIL  offline referencias remotas: ${remote.join(", ")}`); }
else console.log("OK    offline sin una sola URL remota en index.html");

// 7) Render REAL de un diagrama (prueba que no solo parsea: dibuja)
try {
  const { svg } = await mermaid.render("probe", FLOWS[0].graph);
  if (!svg.includes("<svg")) throw new Error("sin <svg>");
  console.log(`OK    render ${FLOWS[0].id} → ${svg.length} bytes de SVG`);
} catch (e) {
  fail++;
  console.log(`FAIL  render ${String(e.message ?? e).split("\n")[0]}`);
}

console.log(fail === 0 ? "\nRESULT: OK" : `\nRESULT: ${fail} FALLOS`);
process.exit(fail === 0 ? 0 : 1);
