// lib/graph.js — parser + medición + layout del MAPA del Atlas (chip F4).
//
// Este fichero es COMPARTIDO entre `index.html` (que pinta) y `check.mjs` (que mide): las cajas que el
// pin de solapes comprueba en Node son EXACTAMENTE las que el navegador pinta, porque el wrap de texto,
// los tamaños de nodo y el grafo ELK salen de estas mismas funciones. Si la página y el validador
// midieran distinto, el pin sería decorativo.
//
// La SSOT del grafo sigue siendo `data/flows.js` (sintaxis mermaid, intacta desde F1/F3): aquí solo se
// PARSEA. Una línea que este parser no entienda es un error duro, no un skip — así un cambio de sintaxis
// en flows.js no puede degradar el mapa en silencio.
//
// UMD mínimo: `window.AtlasGraph` en el navegador, `module.exports` en Node.
(function (root, factory) {
  if (typeof module === "object" && module.exports) { module.exports = factory(); }
  else { root.AtlasGraph = factory(); }
})(typeof self !== "undefined" ? self : globalThis, function () {
  "use strict";

  // ── Medición de texto determinista ─────────────────────────────────────────
  // Estimación por clase de carácter (fracción del font-size, fuente del sistema).
  // Generosa a propósito: un hueco de más es aire; un hueco de menos es un solape
  // que el pin no vería. Calibrada contra el render real en Chrome (F4).
  const NARROW = new Set("iíìIjltf.,:;'’·|!()[]   ".split(""));
  const WIDE = new Set("mwMW—«»…∧⇒→©®%".split(""));
  const CAPS = /[A-ZÁÉÍÓÚÑÜ0-9@#&]/;

  function charW(ch) {
    if (NARROW.has(ch)) return 0.34;
    if (WIDE.has(ch)) return 0.95;
    if (ch === " ") return 0.31;
    if (CAPS.test(ch)) return 0.68;
    if (ch.codePointAt(0) > 0x2000) return 1.0; // símbolos, emoji, flechas
    return 0.545;
  }

  function textWidth(str, fontSize) {
    let w = 0;
    for (const ch of String(str)) w += charW(ch);
    return Math.ceil(w * fontSize * 1.06);
  }

  // Greedy wrap por palabras. Respeta los saltos ya presentes (`\n`, que vienen de `<br/>`).
  function wrap(str, maxPx, fontSize) {
    const out = [];
    for (const hard of String(str).split("\n")) {
      const words = hard.split(/\s+/).filter(Boolean);
      if (!words.length) { continue; }
      let line = words[0];
      for (const w of words.slice(1)) {
        if (textWidth(line + " " + w, fontSize) <= maxPx) line += " " + w;
        else { out.push(line); line = w; }
      }
      out.push(line);
    }
    return out.length ? out : [""];
  }

  // ── Parser del subconjunto mermaid que usa flows.js ────────────────────────
  // Formas: ID["rect"] · ID{"decisión"} · ID(["terminal"]) · ID{{"nota"}}
  // Aristas: A --> B · A -->|label| B · A -.-> B · A -.->|label| B
  // Directivas: flowchart TD · click ID call showNode("panel") · classDef … · class A,B cls

  const SHAPES = [
    { open: '(["', close: '"])', shape: "terminal" },
    { open: '{{"', close: '"}}', shape: "note" },
    { open: '{"', close: '"}', shape: "decision" },
    { open: '["', close: '"]', shape: "rect" }
  ];

  function parseNodeToken(s) {
    // Devuelve { id, label|null, shape|null, rest } o null si no arranca con un id.
    const m = /^([A-Za-z][A-Za-z0-9_]*)/.exec(s);
    if (!m) return null;
    const id = m[1];
    let rest = s.slice(id.length);
    for (const { open, close, shape } of SHAPES) {
      if (rest.startsWith(open)) {
        const end = rest.indexOf(close, open.length);
        if (end === -1) throw new Error(`def de nodo sin cierre en: ${s.slice(0, 60)}`);
        const label = rest.slice(open.length, end);
        return { id, label, shape, rest: rest.slice(end + close.length) };
      }
    }
    return { id, label: null, shape: null, rest };
  }

  function cleanLabel(raw) {
    return String(raw).replace(/<br\s*\/?>/g, "\n").trim();
  }

  function parseFlow(graphText) {
    const nodes = new Map(); // id → { id, label, shape, cls: [], panel: null }
    const edges = [];
    const clicks = new Map();

    function ensure(tok) {
      let n = nodes.get(tok.id);
      if (!n) { n = { id: tok.id, label: null, shape: null, cls: [] }; nodes.set(tok.id, n); }
      if (tok.label !== null) { n.label = cleanLabel(tok.label); n.shape = tok.shape; }
      return n;
    }

    const lines = graphText.split("\n").map(l => l.trim()).filter(Boolean);
    for (const line of lines) {
      if (/^flowchart\s/.test(line) || /^classDef\s/.test(line)) continue;
      const mClass = /^class\s+([A-Za-z0-9_,\s]+?)\s+([A-Za-z0-9_]+)$/.exec(line);
      if (mClass) {
        for (const id of mClass[1].split(",").map(s => s.trim())) {
          const n = nodes.get(id);
          if (!n) throw new Error(`class sobre nodo desconocido: ${id}`);
          n.cls.push(mClass[2]);
        }
        continue;
      }
      const mClick = /^click\s+([A-Za-z0-9_]+)\s+call\s+showNode\("([^"]+)"\)$/.exec(line);
      if (mClick) { clicks.set(mClick[1], mClick[2]); continue; }

      // Nodo suelto o arista(s)
      const first = parseNodeToken(line);
      if (!first) throw new Error(`línea no reconocida: ${line.slice(0, 80)}`);
      let src = ensure(first);
      let rest = first.rest.trim();
      while (rest.length) {
        const mEdge = /^(-{2,3}>|-\.->)\s*(?:\|("?)([\s\S]*?)\2\|)?\s*/.exec(rest);
        if (!mEdge) throw new Error(`arista no reconocida tras ${src.id}: ${rest.slice(0, 60)}`);
        rest = rest.slice(mEdge[0].length);
        const tgtTok = parseNodeToken(rest);
        if (!tgtTok) throw new Error(`destino de arista ilegible tras ${src.id}: ${rest.slice(0, 60)}`);
        const tgt = ensure(tgtTok);
        edges.push({
          from: src.id,
          to: tgt.id,
          label: mEdge[3] ? cleanLabel(mEdge[3]) : null,
          dashed: mEdge[1] === "-.->"
        });
        src = tgt;
        rest = tgtTok.rest.trim();
      }
    }

    for (const [id, panel] of clicks) {
      const n = nodes.get(id);
      if (!n) throw new Error(`click sobre nodo desconocido: ${id}`);
      n.panel = panel;
    }
    for (const n of nodes.values()) {
      if (n.label === null) throw new Error(`nodo ${n.id} referenciado pero nunca definido`);
    }
    return { nodes: [...nodes.values()], edges };
  }

  // ── Visual de cada nodo del mapa ───────────────────────────────────────────
  // kind: "screen" (captura real) · "gap" (device-only) · "decision" · "terminal" · "note"
  // El color con significado y el trato del hueco los pone el CSS por kind; aquí solo GEOMETRÍA.

  const THUMB = { w: 52, h: 112 };
  const F = { node: 12.5, small: 11.5, edge: 11 };
  const LH = { node: 16, small: 15, edge: 14 };

  function nodeVisual(n, panels, deviceOnly) {
    const panel = n.panel ? panels[n.panel] : null;
    const isUnreachable = n.cls.includes("unreachable");
    let kind;
    if (n.shape === "decision") kind = "decision";
    else if (n.shape === "note") kind = "note";
    else if (n.shape === "terminal") kind = "terminal";
    else {
      // rect: pantalla si su panel tiene captura; hueco si es device-only; estado sin captura si no.
      if (panel && panel.shot && deviceOnly && deviceOnly[n.panel]) kind = "gap";
      else if (panel && panel.shot) kind = "screen";
      else kind = "state";
    }

    if (kind === "screen" || kind === "gap") {
      const lines = wrap(n.label, 148, F.node);
      const textW = Math.max(...lines.map(l => textWidth(l, F.node)));
      return {
        kind, lines, unreachable: isUnreachable,
        fontSize: F.node, lineHeight: LH.node, thumb: kind === "screen" ? THUMB : { ...THUMB },
        width: 10 + THUMB.w + 9 + Math.min(textW, 150) + 12,
        height: Math.max(THUMB.h + 18, lines.length * LH.node + 22)
      };
    }
    if (kind === "decision") {
      const lines = wrap(n.label, 190, F.small);
      const textW = Math.max(...lines.map(l => textWidth(l, F.small)));
      return {
        kind, lines, unreachable: isUnreachable,
        fontSize: F.small, lineHeight: LH.small,
        width: textW + 30, height: lines.length * LH.small + 18
      };
    }
    // terminal · note · state
    const lines = wrap(n.label, 170, F.small);
    const textW = Math.max(...lines.map(l => textWidth(l, F.small)));
    return {
      kind, lines, unreachable: isUnreachable,
      fontSize: F.small, lineHeight: LH.small,
      width: textW + 26, height: lines.length * LH.small + 18
    };
  }

  function edgeLabelVisual(label) {
    const lines = wrap(label, 150, F.edge);
    const textW = Math.max(...lines.map(l => textWidth(l, F.edge)));
    return { lines, fontSize: F.edge, lineHeight: LH.edge, width: textW + 14, height: lines.length * LH.edge + 6 };
  }

  // ── Grafo ELK ──────────────────────────────────────────────────────────────

  const LAYOUT_OPTIONS = {
    "elk.algorithm": "layered",
    "elk.direction": "DOWN",
    "elk.edgeRouting": "ORTHOGONAL",
    "elk.layered.spacing.nodeNodeBetweenLayers": "40",
    "elk.spacing.nodeNode": "22",
    "elk.spacing.edgeNode": "16",
    "elk.spacing.edgeEdge": "12",
    "elk.layered.spacing.edgeNodeBetweenLayers": "14",
    "elk.edgeLabels.inline": "true",
    "elk.spacing.edgeLabel": "6",
    "elk.separateConnectedComponents": "true",
    "elk.spacing.componentComponent": "48",
    "elk.layered.considerModelOrder.strategy": "NODES_AND_EDGES",
    "elk.layered.nodePlacement.strategy": "NETWORK_SIMPLEX",
    "elk.layered.thoroughness": "10",
    "elk.padding": "[top=8,left=8,bottom=8,right=8]"
  };

  function buildElk(parsed, panels, deviceOnly) {
    const visuals = new Map();
    for (const n of parsed.nodes) visuals.set(n.id, nodeVisual(n, panels, deviceOnly));
    const children = parsed.nodes.map(n => ({
      id: n.id,
      width: visuals.get(n.id).width,
      height: visuals.get(n.id).height
    }));
    const edges = parsed.edges.map((e, i) => {
      const edge = { id: "e" + i, sources: [e.from], targets: [e.to] };
      if (e.label) {
        const lv = edgeLabelVisual(e.label);
        edge.labels = [{ text: e.label, width: lv.width, height: lv.height }];
      }
      return edge;
    });
    return { graph: { id: "root", layoutOptions: LAYOUT_OPTIONS, children, edges }, visuals };
  }

  // ── Cajas resultantes para el pin de solapes ───────────────────────────────
  // Las cajas que se comprueban son las VISUALES (lo que la página pinta de verdad: `nodeVisual` /
  // `edgeLabelVisual`) colocadas en las posiciones que devolvió ELK — NO los tamaños declarados al
  // layouter. Si alguien declara a ELK un tamaño menor que el render real, el pin lo caza en vez de
  // darle la razón. ELK con `separateConnectedComponents` entrega coordenadas absolutas en la raíz.

  function boxesFromLayout(laidOut, visuals) {
    const nodeBoxes = laidOut.children.map(c => {
      const v = visuals ? visuals.get(c.id) : null;
      return { id: c.id, x: c.x, y: c.y, w: v ? v.width : c.width, h: v ? v.height : c.height, type: "node" };
    });
    const labelBoxes = [];
    for (const e of laidOut.edges ?? []) {
      for (const l of e.labels ?? []) {
        const lv = edgeLabelVisual(l.text);
        labelBoxes.push({ id: e.id + "·label", x: l.x, y: l.y, w: lv.width, h: lv.height, type: "label", text: l.text });
      }
    }
    return { nodeBoxes, labelBoxes };
  }

  function intersects(a, b, slack) {
    const s = slack ?? 0;
    return a.x + s < b.x + b.w && b.x + s < a.x + a.w && a.y + s < b.y + b.h && b.y + s < a.y + a.h;
  }

  // Solapes que el chip declara fallo: nodo-nodo, etiqueta-nodo, etiqueta-etiqueta.
  // `slack` 1px para no fallar por aritmética de floats en fronteras compartidas.
  function findOverlaps(laidOut, visuals) {
    const { nodeBoxes, labelBoxes } = boxesFromLayout(laidOut, visuals);
    const bad = [];
    for (let i = 0; i < nodeBoxes.length; i++)
      for (let j = i + 1; j < nodeBoxes.length; j++)
        if (intersects(nodeBoxes[i], nodeBoxes[j], 1)) bad.push([nodeBoxes[i].id, nodeBoxes[j].id]);
    for (const l of labelBoxes) {
      for (const n of nodeBoxes) if (intersects(l, n, 1)) bad.push([l.id, n.id]);
      for (const m of labelBoxes) if (m !== l && m.id > l.id && intersects(l, m, 1)) bad.push([l.id, m.id]);
    }
    return bad;
  }

  return {
    parseFlow, textWidth, wrap, nodeVisual, edgeLabelVisual,
    buildElk, boxesFromLayout, findOverlaps,
    THUMB, LAYOUT_OPTIONS
  };
});
