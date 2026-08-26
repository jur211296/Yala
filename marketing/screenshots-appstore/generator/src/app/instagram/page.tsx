"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

/* ============================================================
   Yala — Generador de posts para Instagram (1080×1080)
   Mismo lenguaje visual del set App Store (tema Liquid Glass),
   logo blanco + spark cyan + línea rosa, composiciones variadas.
   ============================================================ */

const IG = 1080;                 // ancho
const IG_H = 1350;               // alto (formato 4:5 vertical de Instagram)
const VSHIFT = (IG_H - IG) / 2;  // centra el contenido (diseñado a 1080) en el lienzo alto
const SS = "/screenshots/es";       // screenshots de la app (tema Liquid Glass)
const LOGO = "/yala-spark.png";     // wordmark blanco + spark cyan + línea rosa (Header DARK)

const C = {
  bg: "#0F172A", bgDeep: "#0B1122", pink: "#FF2D78", cyan: "#3BD6F0",
  indigo: "#6164EB", violet: "#8B5CF6", white: "#FFFFFF", muted: "rgba(255,255,255,0.72)",
};
const SPK = "M50 0 C54 36 64 46 100 50 C64 54 54 64 50 100 C46 64 36 54 0 50 C36 46 46 36 50 0 Z";
// geometría de la pantalla dentro de mockup.png (1022×2082)
const SC = { l: 5.09, t: 2.21, w: 89.82, h: 95.58, rx: 13.7, ry: 6.33 };

type Seg = { t: string; kw?: boolean; color?: string };
const k = (t: string, color: string): Seg => ({ t, kw: true, color });

/* ---------- primitivas ---------- */
function Sparkle({ x, y, size, color, rotate = 0, opacity = 1 }: {
  x: number; y: number; size: number; color: string; rotate?: number; opacity?: number;
}) {
  return (
    <svg viewBox="0 0 100 100" style={{
      position: "absolute", left: x, top: y, width: size, height: size, opacity,
      transform: `rotate(${rotate}deg)`, filter: `drop-shadow(0 0 ${size * 0.18}px ${color})`,
    }}>
      <path d={SPK} fill={color} />
    </svg>
  );
}
function Glow({ x, y, size, color, opacity = 0.5 }: {
  x: number; y: number; size: number; color: string; opacity?: number;
}) {
  return <div style={{
    position: "absolute", left: x, top: y, width: size, height: size, opacity,
    borderRadius: "50%", background: `radial-gradient(circle, ${color} 0%, transparent 70%)`, pointerEvents: "none",
  }} />;
}
function Blob({ x, y, size, color, opacity = 0.5 }: {
  x: number; y: number; size: number; color: string; opacity?: number;
}) {
  return <div style={{ position: "absolute", left: x, top: y, width: size, height: size, borderRadius: "50%", background: color, opacity }} />;
}
function Deco() {
  const s = [
    { x: 62, y: 300, size: 60, color: C.indigo, rotate: 12 },
    { x: 958, y: 210, size: 82, color: C.pink, rotate: -8 },
    { x: 1002, y: 770, size: 58, color: C.cyan, rotate: 6, opacity: 0.9 },
    { x: 74, y: 850, size: 72, color: C.cyan, rotate: -15, opacity: 0.85 },
    { x: 930, y: 965, size: 66, color: C.indigo, rotate: 18, opacity: 0.8 },
  ];
  return <>{s.map((p, i) => <Sparkle key={i} {...p} />)}</>;
}

function Caption({ lines, top, size, left = 78, right = 78, align = "center" }: {
  lines: Seg[][]; top: number; size: number; left?: number; right?: number; align?: "center" | "left";
}) {
  return (
    <div style={{ position: "absolute", left, right, top, textAlign: align, zIndex: 5 }}>
      {lines.map((segs, i) => (
        <div key={i} style={{ fontWeight: 850, lineHeight: 1.14, letterSpacing: "-1px", color: "#fff", fontSize: size }}>
          {segs.map((s, j) =>
            s.kw ? (
              <span key={j} style={{ position: "relative", whiteSpace: "pre", color: s.color }}>
                {s.t}
                <span style={{ position: "absolute", left: 1, right: 1, bottom: "-.02em", height: ".105em", borderRadius: 6, background: s.color }} />
              </span>
            ) : (
              <span key={j} style={{ whiteSpace: "pre" }}>{s.t}</span>
            )
          )}
        </div>
      ))}
    </div>
  );
}
function Sub({ text, top, size = 44, left = 110, right = 110, color = C.muted }: {
  text: string; top: number; size?: number; left?: number; right?: number; color?: string;
}) {
  return <div style={{ position: "absolute", left, right, top, textAlign: "center", fontSize: size, fontWeight: 600, color, lineHeight: 1.34, zIndex: 5 }}>{text}</div>;
}

/* ---------- logo ---------- */
function LogoCorner() {
  return <div style={{ position: "absolute", left: 64, bottom: 60, zIndex: 6 }}>
    <img src={LOGO} alt="yala" style={{ width: 190, display: "block" }} draggable={false} />
  </div>;
}
function LogoHero({ top = 400, w = 560 }: { top?: number; w?: number }) {
  return <div style={{ position: "absolute", left: "50%", top, transform: "translateX(-50%)", zIndex: 6, textAlign: "center" }}>
    <img src={LOGO} alt="yala" style={{ width: w, display: "block" }} draggable={false} />
  </div>;
}

/* ---------- teléfonos ---------- */
function PhoneInner({ src, w }: { src: string; w: number }) {
  return (
    <div style={{ width: w, aspectRatio: "1022 / 2082", position: "relative" }}>
      <img src="/mockup.png" alt="" style={{ width: "100%", display: "block", filter: "saturate(0.18) brightness(0.78)" }} draggable={false} />
      <div style={{
        position: "absolute", overflow: "hidden", left: `${SC.l}%`, top: `${SC.t}%`,
        width: `${SC.w}%`, height: `${SC.h}%`, borderRadius: `${SC.rx}% / ${SC.ry}%`,
      }}>
        <img src={src} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: "top", display: "block" }} draggable={false} />
      </div>
    </div>
  );
}
function PhoneFull({ src, w = 372, top = 440, rotate = 0 }: { src: string; w?: number; top?: number; rotate?: number }) {
  return <div style={{ position: "absolute", left: "50%", top, transform: `translateX(-50%) rotate(${rotate}deg)`, zIndex: 3, filter: "drop-shadow(0 26px 55px rgba(0,0,0,0.55))" }}>
    <PhoneInner src={src} w={w} />
  </div>;
}
function PhoneTilted({ src, w = 600, left, right, top = 500, rotate = -5 }: {
  src: string; w?: number; left?: number; right?: number; top?: number; rotate?: number;
}) {
  const pos: React.CSSProperties = { position: "absolute", top, zIndex: 3, transform: `rotate(${rotate}deg)`, filter: "drop-shadow(0 30px 60px rgba(0,0,0,0.55))" };
  if (left != null) pos.left = left;
  if (right != null) pos.right = right;
  return <div style={pos}><PhoneInner src={src} w={w} /></div>;
}
type DuoItem = { src: string; w: number; left?: number; right?: number; top: number; rotate?: number; opacity?: number; z?: number };
function PhoneDuo({ items }: { items: DuoItem[] }) {
  return <>{items.map((it, i) => {
    const pos: React.CSSProperties = { position: "absolute", top: it.top, zIndex: it.z ?? 3, opacity: it.opacity ?? 1, transform: `rotate(${it.rotate ?? 0}deg)`, filter: "drop-shadow(0 24px 50px rgba(0,0,0,0.5))" };
    if (it.left != null) pos.left = it.left;
    if (it.right != null) pos.right = it.right;
    return <div key={i} style={pos}><PhoneInner src={it.src} w={it.w} /></div>;
  })}</>;
}

/* ---------- base (lienzo 4:5; el contenido 1080 se centra vertical) ---------- */
function Base({ deep = false, children }: { deep?: boolean; children: React.ReactNode }) {
  return <div style={{
    width: IG, height: IG_H, position: "relative", overflow: "hidden",
    background: deep ? `linear-gradient(180deg, ${C.bg} 0%, ${C.bgDeep} 100%)` : C.bg,
    fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif',
  }}>
    <Sparkle x={150} y={64} size={52} color={C.pink} rotate={-10} opacity={0.7} />
    <Sparkle x={902} y={96} size={60} color={C.cyan} rotate={8} opacity={0.65} />
    <Sparkle x={120} y={1236} size={58} color={C.indigo} rotate={14} opacity={0.7} />
    <Sparkle x={928} y={1262} size={54} color={C.pink} rotate={-12} opacity={0.65} />
    <div style={{ position: "absolute", left: 0, top: VSHIFT, width: IG, height: IG, zIndex: 1 }}>{children}</div>
  </div>;
}

/* ---------- lista de features (Gratis vs Pro) ---------- */
function FeatureList({ items, color, top, mark = "✓", strike = false }: {
  items: string[]; color: string; top: number; mark?: string; strike?: boolean;
}) {
  return (
    <div style={{ position: "absolute", left: 130, right: 130, top, zIndex: 5, display: "flex", flexDirection: "column", gap: 28 }}>
      {items.map((t, i) => (
        <div key={i} style={{ display: "flex", alignItems: "center", gap: 24, fontSize: 46, fontWeight: 700, color: strike ? "rgba(255,255,255,0.5)" : "#fff" }}>
          <span style={{ color, fontSize: 42, fontWeight: 900, flex: "0 0 auto" }}>{mark}</span>
          <span style={strike ? { textDecoration: "line-through", textDecorationColor: color } : undefined}>{t}</span>
        </div>
      ))}
    </div>
  );
}

/* ---------- iconos de privacidad (candado + nube con glow) ---------- */
function PrivacyIcons() {
  const Badge = ({ kind, left }: { kind: "lock" | "cloud"; left: number }) => (
    <div style={{
      position: "absolute", left, top: 430, width: 280, height: 280, borderRadius: "50%",
      background: "rgba(59,214,240,0.12)", display: "flex", alignItems: "center", justifyContent: "center",
      boxShadow: "0 0 70px rgba(59,214,240,0.45)", zIndex: 4,
    }}>
      <svg viewBox="0 0 24 24" width={130} height={130} fill="none" stroke={C.cyan} strokeWidth={1.5}>
        {kind === "lock" ? (
          <>
            <rect x="5" y="10.5" width="14" height="9.5" rx="2.4" />
            <path d="M8 10.5V7.8a4 4 0 0 1 8 0v2.7" />
            <circle cx="12" cy="15.2" r="1.4" fill={C.cyan} stroke="none" />
          </>
        ) : (
          <path d="M18.4 10.1a6 6 0 0 0-11.5-1.6A4.8 4.8 0 0 0 7 18h11a4 4 0 0 0 .4-7.9Z" fill={C.cyan} stroke="none" />
        )}
      </svg>
    </div>
  );
  return <><Badge kind="lock" left={210} /><Badge kind="cloud" left={590} /></>;
}

/* ---------- cierre reutilizable ---------- */
function Cierre() {
  const sp = [
    { x: 760, y: 300, size: 80, color: C.pink, rotate: -8 }, { x: 330, y: 380, size: 88, color: C.violet, rotate: 10 },
    { x: 610, y: 470, size: 64, color: C.cyan }, { x: 230, y: 760, size: 70, color: C.cyan, rotate: -12, opacity: 0.85 },
    { x: 880, y: 720, size: 90, color: C.pink, rotate: 20, opacity: 0.8 }, { x: 350, y: 980, size: 60, color: C.pink, opacity: 0.8 },
  ];
  return <Base deep>
    <Glow x={250} y={250} size={1500} color={C.indigo} opacity={0.34} />
    {sp.map((p, i) => <Sparkle key={i} {...p} />)}
    <LogoHero top={400} w={560} />
    <Sub text="Finanzas resueltas." top={640} size={56} color="#fff" />
    <Sub text="Descárgala gratis · App Store" top={740} size={34} />
  </Base>;
}

/* ============================================================
   SLIDES
   ============================================================ */
type Slide = { key: string; group: string; title: string; render: () => React.ReactNode };

const SLIDES: Slide[] = [
  // ---- Campaña 1: ¿Te suena familiar? ----
  { key: "familiar-1", group: "Campaña · ¿Te suena familiar?", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={-260} y={300} size={1300} color={C.indigo} opacity={0.42} /><Deco />
      <Caption lines={[[{ t: "¿Te suena" }], [k("familiar", C.cyan), { t: "?" }]]} top={360} size={118} />
      <LogoCorner />
    </Base>
  ) },
  { key: "familiar-2", group: "Campaña · ¿Te suena familiar?", title: "2 · Dolor", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Abriste un Excel" }], [{ t: "con toda la " }, k("ilusión", C.violet), { t: "." }]]} top={300} size={92} />
      <Sub text="…y lo dejaste a la tercera semana." top={600} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "familiar-3", group: "Campaña · ¿Te suena familiar?", title: "3 · Validación", render: () => (
    <Base deep>
      <Glow x={-280} y={520} size={1300} color={C.violet} opacity={0.34} /><Deco />
      <Caption lines={[[{ t: "No era falta de" }], [k("disciplina", C.indigo), { t: "." }]]} top={280} size={98} />
      <Caption lines={[[{ t: "Era " }, k("fricción", C.pink), { t: "." }]]} top={540} size={104} />
      <Sub text="El esfuerzo te ganó. Es normal." top={740} size={44} />
      <LogoCorner />
    </Base>
  ) },
  { key: "familiar-4", group: "Campaña · ¿Te suena familiar?", title: "4 · Solución", render: () => (
    <Base deep>
      <Glow x={340} y={560} size={1150} color={C.indigo} opacity={0.4} /><Deco />
      <Caption lines={[[{ t: "Con Yala, registrar" }], [{ t: "toma " }, k("segundos", C.pink), { t: "." }]]} top={120} size={84} />
      <PhoneTilted src={`${SS}/chat-analisis.png`} w={580} right={65} top={510} rotate={-5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "familiar-5", group: "Campaña · ¿Te suena familiar?", title: "5 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 2: Regístralo en 3 formas ----
  { key: "registra-1", group: "Campaña · Regístralo en 3 formas", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={300} y={560} size={1200} color={C.indigo} opacity={0.4} /><Deco />
      <Caption lines={[[{ t: "Anota un gasto" }], [{ t: "en " }, k("segundos", C.pink), { t: "." }]]} top={340} size={102} />
      <Sub text="Tres formas. Tú eliges." top={650} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "registra-2", group: "Campaña · Regístralo en 3 formas", title: "2 · Voz", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "1 · " }, k("Háblale", C.cyan), { t: "." }]]} top={120} size={96} />
      <Sub text="«Gasté 30 soles en el almuerzo.»" top={300} size={42} />
      <PhoneTilted src={`${SS}/captura-voz.png`} w={580} right={70} top={500} rotate={-4} />
      <LogoCorner />
    </Base>
  ) },
  { key: "registra-3", group: "Campaña · Regístralo en 3 formas", title: "3 · Foto", render: () => (
    <Base deep>
      <Glow x={300} y={-260} size={1100} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "2 · " }, k("Foto", C.pink), { t: " al recibo." }]]} top={120} size={88} />
      <Sub text="Yala lee el monto por ti." top={300} size={42} />
      <PhoneFull src={`${SS}/captura-imagen.png`} w={372} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "registra-4", group: "Campaña · Regístralo en 3 formas", title: "4 · Teclado", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "3 · " }, k("Escríbelo", C.violet), { t: "." }]]} top={120} size={96} />
      <Sub text="Lo clásico, igual de rápido." top={300} size={42} />
      <PhoneTilted src={`${SS}/nuevo-registro.png`} w={580} left={70} top={500} rotate={5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "registra-5", group: "Campaña · Regístralo en 3 formas", title: "5 · La IA organiza", render: () => (
    <Base deep>
      <Glow x={-280} y={540} size={1300} color={C.indigo} opacity={0.36} /><Deco />
      <Caption lines={[[{ t: "La IA lo " }, k("organiza", C.cyan), { t: "." }]]} top={330} size={96} />
      <Sub text="Tú solo entiendes tu dinero." top={560} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "registra-6", group: "Campaña · Regístralo en 3 formas", title: "6 · Cierre", render: () => <Cierre /> },

  // ---- Posts únicos ----
  { key: "post-que-es", group: "Posts únicos", title: "¿Qué es?", render: () => (
    <Base deep>
      <Blob x={-260} y={-260} size={760} color={C.indigo} opacity={0.5} /><Deco />
      <Caption lines={[[{ t: "¿Qué es?" }]]} top={120} size={96} align="left" left={90} right={90} />
      <div style={{ position: "absolute", left: 86, top: 230, zIndex: 6 }}>
        <img src={LOGO} alt="yala" style={{ width: 430, display: "block" }} draggable={false} />
      </div>
      <PhoneTilted src={`${SS}/panel-hero.png`} w={600} right={55} top={500} rotate={-5} />
    </Base>
  ) },
  { key: "post-adivinar", group: "Posts únicos", title: "Deja de adivinar", render: () => (
    <Base><Deco />
      <Glow x={300} y={-280} size={1200} color={C.indigo} opacity={0.4} />
      <Caption lines={[[{ t: "Deja de" }], [k("adivinar", C.cyan), { t: "." }]]} top={96} size={104} />
      <Sub text="Mira a dónde se va tu dinero, de verdad." top={330} size={42} />
      <PhoneFull src={`${SS}/panel-distribucion.png`} w={392} top={430} />
      <LogoCorner />
    </Base>
  ) },
  { key: "post-otras-apps", group: "Posts únicos", title: "Otras apps vs Yala", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Otras apps " }, k("te piden", C.pink), { t: ":" }]]} top={120} size={80} />
      <div style={{ position: "absolute", left: 120, right: 120, top: 290, zIndex: 5, display: "flex", flexDirection: "column", gap: 26 }}>
        {["Escribir cada gasto", "Categorizar todo", "Recordarlo siempre"].map((t, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 22, fontSize: 50, fontWeight: 700, color: "rgba(255,255,255,0.55)" }}>
            <span style={{ color: C.pink, fontSize: 46, fontWeight: 900, flex: "0 0 auto" }}>✕</span>
            <span style={{ textDecoration: "line-through", textDecorationColor: "rgba(255,45,120,0.7)" }}>{t}</span>
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 120, right: 120, top: 600, height: 2, background: "rgba(255,255,255,0.12)", zIndex: 5 }} />
      <Caption lines={[[{ t: "Con " }, k("Yala", C.cyan), { t: ":" }]]} top={650} size={80} align="left" left={120} right={120} />
      <div style={{ position: "absolute", left: 120, right: 120, top: 770, zIndex: 5, display: "flex", alignItems: "center", gap: 22, fontSize: 56, fontWeight: 850, color: "#fff", letterSpacing: "-.5px" }}>
        <span style={{ color: C.cyan, fontSize: 50, fontWeight: 900 }}>✓</span>
        <span>Foto, voz o importación. <span style={{ color: C.pink }}>¡Listo!</span></span>
      </div>
      <LogoCorner />
    </Base>
  ) },

  // ---- Campaña 3: Tu dinero es privado (privacidad) ----
  { key: "priv-1", group: "Campaña · Tu dinero es privado", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={250} y={300} size={1400} color={C.indigo} opacity={0.36} /><Deco />
      <Caption lines={[[{ t: "Tu dinero" }], [k("es privado", C.cyan), { t: "." }]]} top={360} size={112} />
      <LogoCorner />
    </Base>
  ) },
  { key: "priv-2", group: "Campaña · Tu dinero es privado", title: "2 · Sin bancos", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Sin bancos" }], [k("conectados", C.pink), { t: "." }]]} top={300} size={96} />
      <Sub text="Y sin vender tus datos. Nunca." top={600} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "priv-3", group: "Campaña · Tu dinero es privado", title: "3 · Cifrado", render: () => (
    <Base deep>
      <Glow x={250} y={250} size={1300} color={C.indigo} opacity={0.3} /><Deco />
      <Caption lines={[[k("Cifrado", C.cyan), { t: " en" }], [{ t: "tu dispositivo." }]]} top={120} size={88} />
      <PrivacyIcons />
      <Caption lines={[[{ t: "Respaldo solo en " }], [k("tu nube", C.pink), { t: "." }]]} top={800} size={80} />
      <LogoCorner />
    </Base>
  ) },
  { key: "priv-4", group: "Campaña · Tu dinero es privado", title: "4 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 4: Gratis vs Pro ----
  { key: "gvp-1", group: "Campaña · Gratis vs Pro", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={250} y={300} size={1300} color={C.violet} opacity={0.34} /><Deco />
      <Caption lines={[[k("Gratis", C.cyan), { t: " vs " }, k("Pro", C.pink)]]} top={370} size={104} />
      <Sub text="¿Qué plan va contigo?" top={560} size={48} />
      <LogoCorner />
    </Base>
  ) },
  { key: "gvp-2", group: "Campaña · Gratis vs Pro", title: "2 · Gratis", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Empieza " }, k("gratis", C.cyan), { t: "." }]]} top={130} size={92} />
      <Sub text="Todo lo esencial:" top={310} size={44} />
      <FeatureList color={C.cyan} top={430} items={["Presupuestos inteligentes", "Pagos planificados", "Personalización total", "2 cuentas y más"]} />
      <LogoCorner />
    </Base>
  ) },
  { key: "gvp-3", group: "Campaña · Gratis vs Pro", title: "3 · Pro", render: () => (
    <Base deep>
      <Glow x={300} y={-260} size={1100} color={C.pink} opacity={0.22} /><Deco />
      <Caption lines={[[{ t: "Hazte " }, k("Pro", C.pink), { t: "." }]]} top={130} size={92} />
      <Sub text="El control total:" top={310} size={44} />
      <FeatureList color={C.pink} mark="✦" top={420} items={["Todo ilimitado", "Escanea recibos y fotos", "Dicta gastos por voz", "Reportes avanzados", "Acceso anticipado"]} />
      <LogoCorner />
    </Base>
  ) },
  { key: "gvp-4", group: "Campaña · Gratis vs Pro", title: "4 · CTA", render: () => (
    <Base deep>
      <Glow x={-280} y={540} size={1300} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "Empieza " }, k("gratis", C.cyan), { t: "." }]]} top={330} size={104} />
      <Sub text="Subes a Pro cuando quieras." top={560} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "gvp-5", group: "Campaña · Gratis vs Pro", title: "5 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 5: Deja de adivinar ----
  { key: "adiv-1", group: "Campaña · Deja de adivinar", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={300} y={560} size={1200} color={C.indigo} opacity={0.4} /><Deco />
      <Caption lines={[[{ t: "Deja de" }], [k("adivinar", C.cyan), { t: "." }]]} top={320} size={112} />
      <Sub text="¿A dónde se va tu dinero?" top={600} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "adiv-2", group: "Campaña · Deja de adivinar", title: "2 · Gastos hormiga", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Descubre tus" }], [k("gastos hormiga", C.pink), { t: "." }]]} top={120} size={82} />
      <PhoneFull src={`${SS}/panel-distribucion.png`} w={392} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "adiv-3", group: "Campaña · Deja de adivinar", title: "3 · Tendencias", render: () => (
    <Base deep>
      <Glow x={350} y={-260} size={1150} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "Ve " }, k("tendencias", C.cyan), { t: " reales." }]]} top={120} size={84} />
      <PhoneTilted src={`${SS}/stats-tendencias.png`} w={580} right={65} top={510} rotate={-5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "adiv-4", group: "Campaña · Deja de adivinar", title: "4 · Presupuestos", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Presupuestos que" }], [k("sí funcionan", C.pink), { t: "." }]]} top={120} size={80} />
      <PhoneTilted src={`${SS}/planificacion-presupuestos.png`} w={580} left={70} top={510} rotate={5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "adiv-5", group: "Campaña · Deja de adivinar", title: "5 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 6: ¿Qué es Yala? (overview) ----
  { key: "ques-1", group: "Campaña · ¿Qué es Yala?", title: "1 · Gancho", render: () => (
    <Base deep>
      <Blob x={-260} y={-260} size={760} color={C.indigo} opacity={0.5} /><Deco />
      <Caption lines={[[{ t: "¿Qué es?" }]]} top={120} size={96} align="left" left={90} right={90} />
      <div style={{ position: "absolute", left: 86, top: 230, zIndex: 6 }}>
        <img src={LOGO} alt="yala" style={{ width: 430, display: "block" }} draggable={false} />
      </div>
      <PhoneTilted src={`${SS}/panel-hero.png`} w={600} right={55} top={500} rotate={-5} />
    </Base>
  ) },
  { key: "ques-2", group: "Campaña · ¿Qué es Yala?", title: "2 · Te recuerda", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Yala te " }, k("recuerda", C.cyan), { t: "." }], [{ t: "Tú solo " }, k("registras", C.pink), { t: "." }]]} top={350} size={88} />
      <Sub text="Sin perseguir cada gasto." top={650} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "ques-3", group: "Campaña · ¿Qué es Yala?", title: "3 · Registra", render: () => (
    <Base deep>
      <Glow x={300} y={560} size={1150} color={C.indigo} opacity={0.4} /><Deco />
      <Caption lines={[[{ t: "Registra en " }, k("segundos", C.pink), { t: "." }]]} top={120} size={86} />
      <Sub text="Voz, foto o teclado. Tú eliges." top={300} size={42} />
      <PhoneFull src={`${SS}/fab-captura-expandido.png`} w={392} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "ques-4", group: "Campaña · ¿Qué es Yala?", title: "4 · La IA organiza", render: () => (
    <Base>
      <Glow x={350} y={-260} size={1150} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "La IA lo " }, k("organiza", C.cyan), { t: "." }]]} top={120} size={86} />
      <Sub text="Tú solo entiendes tu dinero." top={300} size={42} />
      <PhoneTilted src={`${SS}/panel-distribucion.png`} w={580} right={65} top={510} rotate={-5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "ques-5", group: "Campaña · ¿Qué es Yala?", title: "5 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 7: Yala hace el trabajo pesado (diferenciadores) ----
  { key: "dif-1", group: "Campaña · Yala hace el trabajo pesado", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={250} y={300} size={1300} color={C.indigo} opacity={0.36} /><Deco />
      <Caption lines={[[{ t: "Yala hace el" }], [k("trabajo pesado", C.pink), { t: "." }]]} top={330} size={92} />
      <Sub text="Tú solo vives." top={600} size={48} />
      <LogoCorner />
    </Base>
  ) },
  { key: "dif-2", group: "Campaña · Yala hace el trabajo pesado", title: "2 · Otras apps", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Otras apps " }, k("te piden", C.pink), { t: ":" }]]} top={150} size={80} />
      <FeatureList color={C.pink} mark="✕" strike top={360} items={["Escribir cada gasto", "Categorizar todo", "Recordarlo siempre"]} />
      <LogoCorner />
    </Base>
  ) },
  { key: "dif-3", group: "Campaña · Yala hace el trabajo pesado", title: "3 · Con Yala", render: () => (
    <Base deep>
      <Glow x={300} y={560} size={1150} color={C.indigo} opacity={0.4} /><Deco />
      <Caption lines={[[{ t: "Con Yala, " }, k("¡listo!", C.cyan)]]} top={120} size={86} />
      <Sub text="Foto, voz o importación." top={300} size={44} />
      <PhoneFull src={`${SS}/fab-captura-expandido.png`} w={392} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "dif-4", group: "Campaña · Yala hace el trabajo pesado", title: "4 · Menos fricción", render: () => (
    <Base>
      <Glow x={350} y={-260} size={1150} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "Menos fricción." }], [k("Más control", C.pink), { t: "." }]]} top={120} size={84} />
      <PhoneTilted src={`${SS}/panel-hero.png`} w={580} right={65} top={510} rotate={-5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "dif-5", group: "Campaña · Yala hace el trabajo pesado", title: "5 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 8: Grupos (gastos compartidos) ----
  { key: "grupos-1", group: "Campaña · Grupos", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={300} y={560} size={1300} color={C.violet} opacity={0.36} /><Deco />
      <Caption lines={[[{ t: "¿Quién debe" }], [{ t: "a quién?" }]]} top={300} size={106} />
      <Sub text="Yala lo sabe." top={600} size={52} color="#fff" />
      <LogoCorner />
    </Base>
  ) },
  { key: "grupos-2", group: "Campaña · Grupos", title: "2 · Sin enredos", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Comparte gastos" }], [k("sin enredos", C.pink), { t: "." }]]} top={120} size={84} />
      <PhoneTilted src={`${SS}/grupo-balances.png`} w={580} right={65} top={510} rotate={-5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "grupos-3", group: "Campaña · Grupos", title: "3 · Cada saldo", render: () => (
    <Base deep>
      <Glow x={300} y={-260} size={1100} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "Cada quien ve" }], [k("su saldo", C.cyan), { t: "." }]]} top={120} size={84} />
      <PhoneTilted src={`${SS}/grupos-lista.png`} w={580} left={70} top={510} rotate={5} />
      <LogoCorner />
    </Base>
  ) },
  { key: "grupos-4", group: "Campaña · Grupos", title: "4 · Sin dramas", render: () => (
    <Base deep>
      <Glow x={-280} y={540} size={1300} color={C.violet} opacity={0.3} /><Deco />
      <Caption lines={[[{ t: "Salda cuentas" }], [{ t: "sin " }, k("dramas", C.pink), { t: "." }]]} top={330} size={96} />
      <Sub text="Todo vía tu iCloud, privado." top={600} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "grupos-5", group: "Campaña · Grupos", title: "5 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 9: Hazla tuya (temas) ----
  { key: "temas-1", group: "Campaña · Hazla tuya", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={-280} y={400} size={1400} color={C.pink} opacity={0.3} /><Deco />
      <Caption lines={[[{ t: "Hazla " }, k("tuya", C.pink), { t: "." }]]} top={340} size={130} />
      <Sub text="Un estilo para cada quien." top={580} size={48} />
      <LogoCorner />
    </Base>
  ) },
  { key: "temas-2", group: "Campaña · Hazla tuya", title: "2 · Abanico", render: () => (
    <Base deep>
      <Glow x={250} y={250} size={1400} color={C.indigo} opacity={0.3} /><Deco />
      <Caption lines={[[{ t: "Tu Yala," }], [{ t: "tu " }, k("estilo", C.cyan), { t: "." }]]} top={110} size={84} />
      <PhoneDuo items={[
        { src: `${SS}/panel-tema-claro.png`, w: 440, left: -30, top: 560, rotate: -8, opacity: 0.95, z: 2 },
        { src: `${SS}/panel-tema-rosa.png`, w: 440, right: -30, top: 560, rotate: 8, opacity: 0.95, z: 2 },
        { src: `${SS}/panel-hero.png`, w: 480, left: 300, top: 480, z: 3 },
      ]} />
      <LogoCorner />
    </Base>
  ) },
  { key: "temas-3", group: "Campaña · Hazla tuya", title: "3 · Elige", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Elige el que" }], [k("va contigo", C.cyan), { t: "." }]]} top={120} size={84} />
      <PhoneFull src={`${SS}/temas-selector.png`} w={392} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "temas-4", group: "Campaña · Hazla tuya", title: "4 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 10: Tu saldo del futuro (flujo de caja) ----
  { key: "flujo-1", group: "Campaña · Tu saldo del futuro", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={300} y={-300} size={1300} color={C.cyan} opacity={0.22} /><Deco />
      <Caption lines={[[{ t: "Conoce tu saldo" }], [{ t: "del " }, k("futuro", C.cyan), { t: "." }]]} top={340} size={94} />
      <Sub text="Sin sorpresas a fin de mes." top={600} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "flujo-2", group: "Campaña · Tu saldo del futuro", title: "2 · Proyección", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Yala proyecta" }], [{ t: "tus " }, k("próximos meses", C.cyan), { t: "." }]]} top={120} size={78} />
      <PhoneFull src={`${SS}/flujo-caja.png`} w={392} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "flujo-3", group: "Campaña · Tu saldo del futuro", title: "3 · Sin sorpresas", render: () => (
    <Base deep>
      <Glow x={-280} y={540} size={1300} color={C.indigo} opacity={0.34} /><Deco />
      <Caption lines={[[{ t: "Planea sin" }], [k("sorpresas", C.pink), { t: "." }]]} top={330} size={100} />
      <Sub text="Sabes qué viene antes de que llegue." top={590} size={44} />
      <LogoCorner />
    </Base>
  ) },
  { key: "flujo-4", group: "Campaña · Tu saldo del futuro", title: "4 · Cierre", render: () => <Cierre /> },

  // ---- Campaña 11: Tu salud financiera (Score) ----
  { key: "score-1", group: "Campaña · Tu salud financiera", title: "1 · Gancho", render: () => (
    <Base deep>
      <Glow x={250} y={300} size={1300} color={C.indigo} opacity={0.36} /><Deco />
      <Caption lines={[[{ t: "Tu salud financiera," }], [{ t: "en un " }, k("número", C.violet), { t: "." }]]} top={350} size={80} />
      <LogoCorner />
    </Base>
  ) },
  { key: "score-2", group: "Campaña · Tu salud financiera", title: "2 · Yala la mide", render: () => (
    <Base><Deco />
      <Caption lines={[[{ t: "Yala la mide" }], [{ t: "por " }, k("ti", C.cyan), { t: "." }]]} top={120} size={88} />
      <PhoneFull src={`${SS}/stats-resumen.png`} w={392} top={440} />
      <LogoCorner />
    </Base>
  ) },
  { key: "score-3", group: "Campaña · Tu salud financiera", title: "3 · Súbela", render: () => (
    <Base deep>
      <Glow x={300} y={560} size={1200} color={C.cyan} opacity={0.2} /><Deco />
      <Caption lines={[[{ t: "Súbela " }, k("mes a mes", C.pink), { t: "." }]]} top={330} size={96} />
      <Sub text="Pequeños pasos, gran diferencia." top={580} size={46} />
      <LogoCorner />
    </Base>
  ) },
  { key: "score-4", group: "Campaña · Tu salud financiera", title: "4 · Cierre", render: () => <Cierre /> },
];

/* ============================================================
   Página
   ============================================================ */
function Preview({ slide }: { slide: Slide }) {
  const boxRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.1);
  useEffect(() => {
    const el = boxRef.current; if (!el) return;
    const ro = new ResizeObserver(() => setScale(el.clientWidth / IG));
    ro.observe(el); return () => ro.disconnect();
  }, []);
  return (
    <div className="flex flex-col gap-2">
      <div className="text-xs font-semibold text-white/70">{slide.title}</div>
      <div ref={boxRef} className="relative w-full overflow-hidden rounded-2xl border border-white/10" style={{ aspectRatio: "1080 / 1350" }}>
        <div style={{ width: IG, height: IG_H, transform: `scale(${scale})`, transformOrigin: "top left" }}>
          {slide.render()}
        </div>
      </div>
    </div>
  );
}

export default function InstagramPage() {
  const [exporting, setExporting] = useState<string | null>(null);
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  const exportSlide = useCallback(async (index: number) => {
    const el = exportRefs.current[index]; if (!el) return;
    setExporting(SLIDES[index].key);
    el.style.left = "0px"; el.style.zIndex = "-1";
    const opts = { width: IG, height: IG_H, pixelRatio: 1, cacheBust: true };
    try {
      await toPng(el, opts); // warm-up (fuentes/imágenes)
      const dataUrl = await toPng(el, opts);
      await fetch("/api/save", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ dir: "instagram", name: `${SLIDES[index].key}.png`, dataUrl }),
      });
    } finally {
      el.style.left = "-99999px"; el.style.zIndex = ""; setExporting(null);
    }
  }, []);

  const exportAll = useCallback(async () => {
    for (let i = 0; i < SLIDES.length; i++) { await exportSlide(i); await new Promise((r) => setTimeout(r, 200)); }
    document.title = "DONE-instagram";
  }, [exportSlide]);

  const groups = Array.from(new Set(SLIDES.map((s) => s.group)));

  return (
    <div className="min-h-screen bg-[#0B0F1D] p-8">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 flex flex-wrap items-center gap-3">
          <h1 className="text-2xl font-extrabold text-white">Yala · Instagram <span className="text-white/40">1080×1350 · 4:5</span></h1>
          <button id="export-set" onClick={exportAll}
            className="rounded-full bg-pink-600 px-4 py-1.5 text-sm font-bold text-white hover:bg-pink-500">
            {exporting ? `Exportando ${exporting}…` : `Exportar todo (${SLIDES.length}) → export/instagram/`}
          </button>
        </div>

        {groups.map((g) => (
          <div key={g} className="mb-10">
            <div className="mb-3 text-sm font-bold text-white/80">{g}</div>
            <div className="grid grid-cols-2 gap-5 md:grid-cols-3 lg:grid-cols-5">
              {SLIDES.filter((s) => s.group === g).map((slide) => (
                <Preview key={slide.key} slide={slide} />
              ))}
            </div>
          </div>
        ))}
      </div>

      {/* offscreen a tamaño real para exportar */}
      {SLIDES.map((slide, i) => (
        <div key={`x-${slide.key}`} ref={(el) => { exportRefs.current[i] = el; }}
          className="absolute top-0" style={{ left: "-99999px", width: IG, height: IG_H }}>
          {slide.render()}
        </div>
      ))}
    </div>
  );
}
