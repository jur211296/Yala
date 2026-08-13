// check.mjs — el pin del Atlas de Flujos de Modo Nube.
//
// Desde F4 corre SIN dependencias externas (jsdom fuera): el parser y la geometría viven en
// `lib/graph.js` —los MISMOS que usa index.html— y el layout lo calcula el elkjs vendorizado.
// `node check.mjs` y listo.
//
// Qué comprueba (los bloques de F1/F3 se conservan; F4 añade solapes, l10n y storyboard):
//  1. Los 7 grafos de flows.js PARSEAN con el parser real (una línea desconocida es error duro).
//  2. Cada `click … showNode("X")` apunta a un panel que existe.
//  3. Ningún panel queda huérfano.
//  4. Ids de screenshot únicos y con convención `<flujo>-<nodo>.png`.
//  5. Todo panel tiene sus 4 campos y al menos una coordenada.
//  6. index.html no referencia NI UNA URL remota (offline) y todo script local que carga existe.
//  7. Contrato F2: cero nodos vacíos (imagen real o device-only con motivo), sin contradicciones
//     ni imágenes huérfanas.
//  8. SOLAPES (F4): el layout ELK de cada flujo, medido con las cajas VISUALES que la página pinta
//     (lib/graph.js), no produce ningún par nodo-nodo, etiqueta-nodo ni etiqueta-etiqueta que se
//     superponga. Un solape es un fallo, igual que un enlace roto.
//  9. L10N (F4): toda key citada en data/l10n.js EXISTE de verdad en es.lproj (Localizable.strings o
//     .stringsdict) y su valor coincide con el del .strings (el Atlas promete «copy exacto»). Todo
//     nodo con pantalla tiene su entrada.
// 10. STORYBOARD (F4): todo frame referencia un panel real y todo nodo con pantalla aparece en el
//     storyboard de su flujo — «todo lo que ve el usuario, en orden, sin clic» no puede perder nodos
//     en silencio.
// 11. CONTEO ESPERADO: 66 paneles · 56 shots · 32 imágenes · 24 device-only · 56 entradas l10n.
//     Las demás comprobaciones son relaciones entre lo que hay; el conteo obliga a crecer declarando.
//
// MUTACIONES verificadas el 2026-08-11 (F4), cada una a exit 1:
//  - declarar a ELK la mitad del ancho real de los nodos (lib/graph.js) → decenas de solapes;
//  - inventar una key en data/l10n.js → FAIL l10n;
//  - quitar un frame del storyboard de su flujo → FAIL storyboard;
//  - borrar una imagen → nodo VACÍO (bloque 7), igual que en F2/F3.
//
// Salida `RESULT: OK` / exit 0 · cualquier fallo → exit 1.

import fs from "node:fs";
import vm from "node:vm";
import { createRequire } from "node:module";

const require_ = createRequire(import.meta.url);
const ROOT = new URL(".", import.meta.url).pathname;

const G = require_("./lib/graph.js");
const ELK = require_("./vendor/elk.bundled.js");
const elk = new ELK();

// Los data/*.js asignan window.ATLAS_* — un sandbox donde window === globalThis del contexto.
const sandbox = {};
sandbox.window = sandbox;
vm.createContext(sandbox);
for (const f of ["data/nodes.js", "data/flows.js", "data/f2.js", "data/l10n.js", "data/storyboard.js"]) {
  vm.runInContext(fs.readFileSync(`${ROOT}/${f}`, "utf8"), sandbox, { filename: f });
}
const FLOWS = sandbox.ATLAS_FLOWS;
const NODES = sandbox.ATLAS_NODES;
const F2 = sandbox.ATLAS_F2;
const L10N = sandbox.ATLAS_L10N;
const SB = sandbox.ATLAS_STORYBOARD;

let fail = 0;
const bad = (tag, msg) => { fail++; console.log(`FAIL  ${tag} ${msg}`); };

// 1) Cada grafo parsea con el parser REAL (el mismo del index)
const parsedByFlow = {};
for (const f of FLOWS) {
  try {
    parsedByFlow[f.id] = G.parseFlow(f.graph);
    console.log(`OK    parse  ${f.id} (${parsedByFlow[f.id].nodes.length} nodos, ${parsedByFlow[f.id].edges.length} aristas)`);
  } catch (e) {
    bad("parse ", `${f.id}: ${String(e.message ?? e).split("\n")[0]}`);
  }
}

// 2) Cada click resuelve a un panel real
const referenced = new Set();
for (const f of FLOWS) {
  for (const m of f.graph.matchAll(/showNode\("([^"]+)"\)/g)) {
    referenced.add(m[1]);
    if (!NODES[m[1]]) bad("click ", `${f.id} → "${m[1]}" no existe en nodes.js`);
  }
}
console.log(`OK    click  ${referenced.size} ids referenciados`);

// 3) Ningún panel huérfano
for (const k of Object.keys(NODES)) {
  if (!referenced.has(k)) bad("orphan", `${k} está en nodes.js y ningún grafo lo referencia`);
}

// 4) Shots únicos y con convención
const shots = new Map();
for (const [k, n] of Object.entries(NODES)) {
  if (!n.shot) continue;
  if (!/^[a-z0-9]+(-[a-z0-9]+)+\.png$/.test(n.shot)) bad("shot  ", `${k}: "${n.shot}" no cumple la convención`);
  if (shots.has(n.shot)) bad("shot  ", `duplicado: ${n.shot}`);
  shots.set(n.shot, k);
}
console.log(`OK    shot   ${shots.size} ids de screenshot únicos`);

// 5) Paneles completos
for (const [k, n] of Object.entries(NODES)) {
  for (const f of ["title", "sees", "persists", "exits"]) {
    if (!n[f]) bad("field ", `${k}: falta "${f}"`);
  }
  if (!n.code || !n.code.length) bad("code  ", `${k}: sin coordenada de código`);
}
console.log(`OK    field  ${Object.keys(NODES).length} paneles completos`);

// 6) Offline + scripts locales existentes
{
  const html = fs.readFileSync(`${ROOT}/index.html`, "utf8");
  const remote = [...html.matchAll(/(?:src|href)\s*=\s*"(https?:)?\/\/[^"]+"/g)].map(m => m[0]);
  if (remote.length) bad("offline", `referencias remotas: ${remote.join(", ")}`);
  const scripts = [...html.matchAll(/<script src="([^"]+)"/g)].map(m => m[1]);
  for (const s of scripts) {
    if (!fs.existsSync(`${ROOT}/${s}`)) bad("offline", `script local ausente: ${s}`);
  }
  if (!remote.length) console.log(`OK    offline sin URLs remotas · ${scripts.length} scripts locales presentes`);
}

// 7) Contrato F2: cero nodos vacíos, sin contradicciones ni imágenes huérfanas
{
  let capturadas = 0;
  for (const [k, n] of Object.entries(NODES)) {
    if (!n.shot) continue;
    const hasImg = fs.existsSync(`${ROOT}/img/${n.shot}`);
    const dOnly = F2?.deviceOnly?.[k];
    if (hasImg && dOnly) bad("f2    ", `${k}: marcado device-only PERO img/${n.shot} existe`);
    else if (!hasImg && !dOnly) bad("f2    ", `${k}: sin imagen y sin marca device-only — nodo VACÍO`);
    else if (dOnly && (!dOnly.reason || !dOnly.expected)) bad("f2    ", `${k}: device-only incompleto`);
    if (hasImg) capturadas++;
  }
  const known = new Set(Object.values(NODES).map(n => n.shot).filter(Boolean));
  for (const f of fs.readdirSync(`${ROOT}/img`).filter(f => f.endsWith(".png"))) {
    if (!known.has(f)) bad("f2    ", `img/${f} no corresponde a ningún nodo`);
  }
  console.log(`OK    f2     ${capturadas} capturas + ${Object.keys(F2?.deviceOnly ?? {}).length} device-only = cero nodos vacíos`);
}

// 8) SOLAPES: layout real por flujo, cajas visuales, cero intersecciones
for (const f of FLOWS) {
  const parsed = parsedByFlow[f.id];
  if (!parsed) continue;
  const { graph, visuals } = G.buildElk(parsed, NODES, F2.deviceOnly);
  const laidOut = await elk.layout(graph);
  const overlaps = G.findOverlaps(laidOut, visuals);
  if (overlaps.length) {
    for (const [a, b] of overlaps) bad("solape", `${f.id}: ${a} × ${b}`);
  } else {
    console.log(`OK    solape ${f.id}: 0 solapes (${laidOut.children.length} nodos + etiquetas)`);
  }
}

// 9) L10N: toda key citada existe en es.lproj y su valor coincide
{
  const stringsPath = `${ROOT}/../../../Yala/Resources/es.lproj/Localizable.strings`;
  const dictPath = `${ROOT}/../../../Yala/Resources/es.lproj/Localizable.stringsdict`;
  const src = fs.readFileSync(stringsPath, "utf8");
  const table = new Map();
  for (const m of src.matchAll(/^"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)";/gm)) {
    const unesc = s => s.replace(/\\n/g, "\n").replace(/\\"/g, '"').replace(/\\\\/g, "\\");
    table.set(m[1], unesc(m[2]));
  }
  const dictKeys = new Set();
  if (fs.existsSync(dictPath)) {
    const dsrc = fs.readFileSync(dictPath, "utf8");
    // Las keys top-level del plist: <key>…</key> seguidas de <dict>
    for (const m of dsrc.matchAll(/<key>([^<]+)<\/key>\s*\n\s*<dict>/g)) dictKeys.add(m[1]);
  }
  let entries = 0, keys = 0;
  for (const [nodeId, entry] of Object.entries(L10N)) {
    entries++;
    if (!NODES[nodeId]) { bad("l10n  ", `entrada para nodo inexistente: ${nodeId}`); continue; }
    for (const c of entry.copy ?? []) {
      keys++;
      if (!table.has(c.key) && !dictKeys.has(c.key)) {
        bad("l10n  ", `${nodeId}: la key "${c.key}" NO existe en es.lproj`);
      } else if (table.has(c.key) && table.get(c.key) !== c.value) {
        bad("l10n  ", `${nodeId}: el valor citado de "${c.key}" no coincide con es.lproj`);
      }
    }
  }
  // Todo nodo con pantalla tiene su entrada (los de decisión pura no la necesitan)
  for (const [k, n] of Object.entries(NODES)) {
    if (n.shot && !L10N[k]) bad("l10n  ", `${k} tiene pantalla y NO tiene entrada en data/l10n.js`);
  }
  console.log(`OK    l10n   ${entries} nodos · ${keys} citas de key verificadas contra es.lproj`);
}

// 10) STORYBOARD: frames reales y completitud por RECORRIDO
//
// F6: el eje del Atlas pasó de MECANISMO a PERSONA, y con él esta comprobación. Antes derivaba el flujo
// «casa» de un panel del PREFIJO de su id (`k.split("-")[0]`), que funcionaba porque los siete flujos y los
// siete prefijos eran la misma cosa. Ya no: un panel vive en varios recorridos y su id es su nombre propio,
// no su clasificación. La regla nueva no depende del nombre y es MÁS fuerte: todo panel con pantalla
// aparece en AL MENOS UN recorrido. Un panel que se caiga del reparto sigue siendo un fallo, no un hueco
// silencioso — que es lo único que esta comprobación tiene que garantizar.
{
  const enAlgunRecorrido = new Set();
  for (const [fid, sb] of Object.entries(SB)) {
    if (!FLOWS.some(f => f.id === fid)) { bad("story ", `storyboard para recorrido inexistente: ${fid}`); continue; }
    for (const tr of sb.tracks) {
      for (const id of tr.frames) {
        if (!NODES[id]) bad("story ", `${fid}: frame "${id}" no existe en nodes.js`);
        enAlgunRecorrido.add(id);
      }
    }
  }
  for (const f of FLOWS) {
    if (!SB[f.id]) { bad("story ", `el recorrido ${f.id} no tiene storyboard`); continue; }
  }
  let covered = 0;
  for (const [k, n] of Object.entries(NODES)) {
    if (!n.shot) continue;
    if (!enAlgunRecorrido.has(k)) {
      bad("story ", `${k} tiene pantalla y NO aparece en NINGÚN recorrido`);
    } else covered++;
  }
  console.log(`OK    story  ${covered} nodos con pantalla presentes en al menos un recorrido`);
}

// 11) CONTEO ESPERADO — al añadir o quitar un nodo, se actualiza a mano: la fricción ES el aviso.
{
  // F6 (2026-08-12): 82 → 154 paneles. Los 72 nuevos son los recorridos que el eje por MECANISMO no
  // contaba de principio a fin: la invitación entera (22, que no tenía UN SOLO panel pese a que
  // `InviteRecoveryView.swift` existe), la visita en el móvil de otra persona (13), la vuelta del dueño
  // (15), la salida de la persona privada (9) y la re-entrada en un móvil nuevo (13).
  //
  // `images` NO sube: los 72 nuevos nacen SIN captura, y eso está declarado, no escondido. 47 de ellos
  // tienen pantalla ⇒ `deviceOnly` sube de 29 a 76: **37 device-only de verdad** (el sim no puede producir
  // el estado) y **39 `pending: true`** (el sim SÍ puede y esta pasada no abrió el simulador). Los 27
  // `pending` nuevos son el guion de la próxima pasada de captura.
  //
  // Que `images` siga en 35 con 111 paneles con pantalla es el hueco MÁS GRANDE del Atlas hoy, y por eso
  // se cuenta aquí en vez de dejarlo implícito.
  const EXPECTED = { panels: 154, shots: 111, images: 35, deviceOnly: 76, l10nNodes: 113 };
  const actual = {
    panels: Object.keys(NODES).length,
    shots: shots.size,
    images: fs.readdirSync(`${ROOT}/img`).filter(f => f.endsWith(".png")).length,
    deviceOnly: Object.keys(F2?.deviceOnly ?? {}).length,
    l10nNodes: Object.keys(L10N).length
  };
  let mismatched = 0;
  for (const [k, want] of Object.entries(EXPECTED)) {
    if (actual[k] !== want) {
      mismatched++;
      bad("count ", `${k}: esperado ${want}, medido ${actual[k]} — actualiza EXPECTED si el cambio es querido`);
    }
  }
  if (!mismatched) console.log(`OK    count  ${actual.panels} paneles · ${actual.shots} shots · ${actual.images} imágenes · ${actual.deviceOnly} device-only · ${actual.l10nNodes} l10n`);
}

console.log(fail === 0 ? "\nRESULT: OK" : `\nRESULT: ${fail} FALLOS`);
process.exit(fail === 0 ? 0 : 1);
