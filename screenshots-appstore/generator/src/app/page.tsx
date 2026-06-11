"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { toPng } from "html-to-image";

/* ============================================================
   Yala — App Store screenshot generator (set final aprobado)
   Locales: es / en · Devices: iPhone (1320×2868) / iPad (2064×2752)
   ============================================================ */

const IPHONE_W = 1320, IPHONE_H = 2868;
const IPAD_W = 2064, IPAD_H = 2752;

const IPHONE_SIZES = [
  { label: '6.9"', w: 1320, h: 2868 },
  { label: '6.5"', w: 1284, h: 2778 },
  { label: '6.3"', w: 1206, h: 2622 },
  { label: '6.1"', w: 1125, h: 2436 },
] as const;
const IPAD_SIZES = [
  { label: '13"', w: 2064, h: 2752 },
  { label: '12.9"', w: 2048, h: 2732 },
] as const;

const LOCALES = ["es", "en"] as const;
type Locale = (typeof LOCALES)[number];
type Device = "iphone" | "ipad";

// Paleta (sampleada del set 1.0 + marca Yala)
const C = {
  bg: "#0F172A",
  bgDeep: "#0B1122",
  white: "#FFFFFF",
  pink: "#FF2D78",
  cyan: "#3BD6F0",
  indigo: "#6164EB",
  violet: "#8B5CF6",
  muted: "rgba(255,255,255,0.72)",
};

/* ---------- Copy por locale ---------- */
type Seg = { t: string; color?: string; underline?: string };
type SlideCopy = { lines: Seg[][]; sub?: string; lines2?: Seg[][] };

const COPY: Record<Locale, Record<string, SlideCopy>> = {
  es: {
    hero: { lines: [[{ t: "Tus " }, { t: "finanzas", color: C.cyan, underline: C.cyan }, { t: "," }], [{ t: "claras con IA." }]] },
    ia: { lines: [[{ t: "Te presento a " }], [{ t: "Yala IA", color: C.pink, underline: C.pink }, { t: "." }]], sub: "Pregunta, registra y entiende tu mes." },
    grupos: { lines: [[{ t: "¿Quién debe a quién?" }], [{ t: "Yala lo sabe", color: C.cyan, underline: C.cyan }, { t: "." }]], sub: "Comparte gastos sin enredos. Vía tu iCloud." },
    registro: { lines: [[{ t: "Registra en " }, { t: "segundos", color: C.pink, underline: C.pink }, { t: "." }], [{ t: "Voz, foto o teclado." }]] },
    score: { lines: [[{ t: "Tu salud financiera," }], [{ t: "en un número", color: C.violet, underline: C.violet }, { t: "." }]] },
    presupuestos: { lines: [[{ t: "Presupuestos" }], [{ t: "que " }, { t: "sí funcionan", color: C.pink, underline: C.pink }, { t: "." }]] },
    flujo: { lines: [[{ t: "Conoce tu saldo" }], [{ t: "del " }, { t: "futuro", color: C.cyan, underline: C.cyan }, { t: "." }]], sub: "Yala proyecta tus próximos meses." },
    distribucion: { lines: [[{ t: "Descubre en qué" }], [{ t: "se va", color: C.cyan, underline: C.cyan }, { t: " tu dinero." }]] },
    temas: { lines: [[{ t: "Hazla " }, { t: "tuya", color: C.pink, underline: C.pink }, { t: "." }]], sub: "Temas y estilos para cada quien." },
    privacidad: {
      lines: [[{ t: "Cifrado", color: C.cyan, underline: C.cyan }, { t: " en" }], [{ t: "tu dispositivo." }]],
      lines2: [[{ t: "Respaldo solo" }], [{ t: "en " }, { t: "tu nube", color: C.pink, underline: C.pink }, { t: "." }]],
    },
  },
  en: {
    hero: { lines: [[{ t: "Your " }, { t: "finances", color: C.cyan, underline: C.cyan }, { t: "," }], [{ t: "clear with AI." }]] },
    ia: { lines: [[{ t: "Say hello to " }], [{ t: "Yala AI", color: C.pink, underline: C.pink }, { t: "." }]], sub: "Ask, log, and understand your month." },
    grupos: { lines: [[{ t: "Who owes whom?" }], [{ t: "Yala knows", color: C.cyan, underline: C.cyan }, { t: "." }]], sub: "Share expenses without the mess. Via your iCloud." },
    registro: { lines: [[{ t: "Log it in " }, { t: "seconds", color: C.pink, underline: C.pink }, { t: "." }], [{ t: "Voice, photo, or keyboard." }]] },
    score: { lines: [[{ t: "Your financial health," }], [{ t: "in one number", color: C.violet, underline: C.violet }, { t: "." }]] },
    presupuestos: { lines: [[{ t: "Budgets that" }], [{ t: "actually work", color: C.pink, underline: C.pink }, { t: "." }]] },
    flujo: { lines: [[{ t: "Know your " }, { t: "future", color: C.cyan, underline: C.cyan }], [{ t: "balance." }]], sub: "Yala projects your months ahead." },
    distribucion: { lines: [[{ t: "See where your" }], [{ t: "money goes", color: C.cyan, underline: C.cyan }, { t: "." }]] },
    temas: { lines: [[{ t: "Make it " }, { t: "yours", color: C.pink, underline: C.pink }, { t: "." }]], sub: "Themes and styles for everyone." },
    privacidad: {
      lines: [[{ t: "Encrypted", color: C.cyan, underline: C.cyan }, { t: " on" }], [{ t: "your device." }]],
      lines2: [[{ t: "Backed up only" }], [{ t: "in " }, { t: "your cloud", color: C.pink, underline: C.pink }, { t: "." }]],
    },
  },
};

/* ---------- iPhone mockup (pre-medido por el skill) ---------- */
const MK_W = 1022, MK_H = 2082;
const SC_L = (52 / MK_W) * 100, SC_T = (46 / MK_H) * 100;
const SC_W = (918 / MK_W) * 100, SC_H = (1990 / MK_H) * 100;
const SC_RX = (126 / 918) * 100, SC_RY = (126 / 1990) * 100;

function Phone({ src, alt, style, className = "" }: {
  src: string; alt: string; style?: React.CSSProperties; className?: string;
}) {
  return (
    <div className={`absolute ${className}`} style={{ aspectRatio: `${MK_W}/${MK_H}`, ...style }}>
      <img src="/mockup.png" alt="" className="block w-full h-full" draggable={false}
        style={{ filter: "saturate(0.15) brightness(0.75)" }} />
      <div className="absolute z-10 overflow-hidden" style={{
        left: `${SC_L}%`, top: `${SC_T}%`, width: `${SC_W}%`, height: `${SC_H}%`,
        borderRadius: `${SC_RX}% / ${SC_RY}%`,
      }}>
        <img src={src} alt={alt} className="block w-full h-full object-cover object-top" draggable={false} />
      </div>
    </div>
  );
}

/* ---------- iPad mockup (CSS-only, skill spec) ---------- */
function IPad({ src, alt, style, className = "" }: {
  src: string; alt: string; style?: React.CSSProperties; className?: string;
}) {
  return (
    <div className={`absolute ${className}`} style={{ aspectRatio: "770/1000", ...style }}>
      <div style={{
        width: "100%", height: "100%", borderRadius: "5% / 3.6%",
        background: "linear-gradient(180deg, #2C2C2E 0%, #1C1C1E 100%)",
        position: "relative", overflow: "hidden",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.1), 0 8px 40px rgba(0,0,0,0.6)",
      }}>
        <div style={{
          position: "absolute", top: "1.2%", left: "50%", transform: "translateX(-50%)",
          width: "0.9%", height: "0.65%", borderRadius: "50%", background: "#111113",
          border: "1px solid rgba(255,255,255,0.08)", zIndex: 20,
        }} />
        <div style={{
          position: "absolute", inset: 0, borderRadius: "5% / 3.6%",
          border: "1px solid rgba(255,255,255,0.06)", pointerEvents: "none", zIndex: 15,
        }} />
        <div style={{
          position: "absolute", left: "4%", top: "2.8%", width: "92%", height: "94.4%",
          borderRadius: "2.2% / 1.6%", overflow: "hidden", background: "#000",
        }}>
          <img src={src} alt={alt} draggable={false}
            style={{ display: "block", width: "100%", height: "100%", objectFit: "cover", objectPosition: "top" }} />
        </div>
      </div>
    </div>
  );
}

/* ---------- Decoración ---------- */
function Sparkle({ x, y, size, color, rotate = 0, opacity = 1 }: {
  x: number; y: number; size: number; color: string; rotate?: number; opacity?: number;
}) {
  return (
    <svg viewBox="0 0 100 100" className="absolute" style={{
      left: x, top: y, width: size, height: size, opacity,
      transform: `rotate(${rotate}deg)`, filter: `drop-shadow(0 0 ${size * 0.18}px ${color})`,
    }}>
      <path d="M50 0 C54 36 64 46 100 50 C64 54 54 64 50 100 C46 64 36 54 0 50 C36 46 46 36 50 0 Z" fill={color} />
    </svg>
  );
}

function Glow({ x, y, size, color, opacity = 0.55 }: {
  x: number; y: number; size: number; color: string; opacity?: number;
}) {
  return (
    <div className="absolute rounded-full" style={{
      left: x, top: y, width: size, height: size, opacity,
      background: `radial-gradient(circle, ${color} 0%, transparent 70%)`,
    }} />
  );
}

function Logo({ scale = 1 }: { scale?: number }) {
  return (
    <div className="absolute" style={{ left: 90 * scale, bottom: 88 * scale, zIndex: 40 }}>
      <img src="/yala-logo.png" alt="yala" style={{ height: 110 * scale, filter: "brightness(0) invert(1)" }} draggable={false} />
      <div style={{ width: 86 * scale, height: 9 * scale, background: C.pink, borderRadius: 5, marginTop: 6, marginLeft: 4 }} />
    </div>
  );
}

function Caption({ lines, top, size = 105 }: { lines: Seg[][]; top: number; size?: number }) {
  return (
    <div className="absolute z-30" style={{ top, left: 80, right: 80, textAlign: "center" }}>
      {lines.map((segs, i) => (
        <div key={i} style={{ fontSize: size, fontWeight: 800, lineHeight: 1.22, color: C.white, letterSpacing: -1 }}>
          {segs.map((s, j) => (
            <span key={j} style={{ position: "relative", color: s.color ?? C.white, whiteSpace: "pre" }}>
              {s.t}
              {s.underline && (
                <span style={{
                  position: "absolute", left: 2, right: 2, bottom: -4, height: Math.max(8, size * 0.09),
                  background: s.underline, borderRadius: 6,
                }} />
              )}
            </span>
          ))}
        </div>
      ))}
    </div>
  );
}

function Sub({ text, top, size = 64 }: { text: string; top: number; size?: number }) {
  return (
    <div className="absolute z-30" style={{ top, left: 110, right: 110, textAlign: "center", fontSize: size, fontWeight: 600, color: C.muted, lineHeight: 1.3 }}>
      {text}
    </div>
  );
}

function Base({ children, deep = false, w, h }: { children: React.ReactNode; deep?: boolean; w: number; h: number }) {
  return (
    <div className="relative overflow-hidden" style={{
      width: w, height: h,
      background: deep ? `linear-gradient(180deg, ${C.bg} 0%, ${C.bgDeep} 100%)` : C.bg,
    }}>
      {children}
    </div>
  );
}

/* ============================================================
   SLIDES iPhone — set final aprobado (10)
   ============================================================ */
type SlideProps = { t: Record<string, SlideCopy>; base: string };

function PhHero({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H}>
      <Sparkle x={150} y={520} size={64} color={C.indigo} rotate={12} />
      <Sparkle x={1080} y={420} size={88} color={C.pink} rotate={-8} />
      <Sparkle x={210} y={1180} size={120} color={C.indigo} opacity={0.9} />
      <Sparkle x={1130} y={1320} size={72} color={C.cyan} />
      <Sparkle x={1180} y={2280} size={96} color={C.pink} rotate={20} opacity={0.8} />
      <Sparkle x={120} y={2380} size={70} color={C.cyan} rotate={-15} opacity={0.85} />
      <Caption top={300} size={112} lines={t.hero.lines} />
      <Phone src={`${base}/panel-hero.png`} alt="Panel" style={{ width: 920, left: "50%", transform: "translateX(-50%)", top: 760 }} />
      <Logo />
    </Base>
  );
}

function PhIA({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H} deep>
      <Glow x={-350} y={1750} size={1700} color={C.indigo} opacity={0.5} />
      <Sparkle x={140} y={460} size={70} color={C.cyan} rotate={10} />
      <Sparkle x={1110} y={560} size={92} color={C.pink} rotate={-12} />
      <Sparkle x={1150} y={1500} size={64} color={C.indigo} opacity={0.9} />
      <Sparkle x={90} y={2300} size={84} color={C.pink} rotate={18} opacity={0.85} />
      <Caption top={260} size={112} lines={t.ia.lines} />
      <Sub top={580} text={t.ia.sub!} />
      <Phone src={`${base}/chat-analisis.png`} alt="Yala AI" style={{ width: 900, left: "50%", transform: "translateX(-50%)", top: 800 }} />
      <Logo />
    </Base>
  );
}

function PhGrupos({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H}>
      <Sparkle x={1140} y={420} size={80} color={C.cyan} rotate={-10} />
      <Sparkle x={100} y={1280} size={66} color={C.pink} rotate={14} />
      <Sparkle x={1170} y={2350} size={92} color={C.indigo} opacity={0.85} />
      <Glow x={550} y={2000} size={1500} color={C.violet} opacity={0.4} />
      <Caption top={250} size={108} lines={t.grupos.lines} />
      <Sub top={560} text={t.grupos.sub!} />
      <Phone src={`${base}/grupos-lista.png`} alt="Groups" style={{ width: 700, left: -120, top: 1010, transform: "rotate(-5deg)", opacity: 0.6 }} />
      <Phone src={`${base}/grupo-balances.png`} alt="Balances" style={{ width: 830, right: -60, top: 830 }} />
      <Logo />
    </Base>
  );
}

function PhRegistro({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H} deep>
      <Sparkle x={150} y={470} size={76} color={C.pink} rotate={8} />
      <Sparkle x={1120} y={1240} size={68} color={C.cyan} rotate={-14} />
      <Sparkle x={170} y={2330} size={88} color={C.indigo} opacity={0.9} />
      <Caption top={270} size={112} lines={t.registro.lines} />
      <Phone src={`${base}/nuevo-registro.png`} alt="New record" style={{ width: 940, left: "50%", transform: "translateX(-50%) rotate(3deg)", top: 800 }} />
      <Logo />
    </Base>
  );
}

function PhScore({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H}>
      <Glow x={300} y={-500} size={1600} color={C.indigo} opacity={0.45} />
      <Sparkle x={130} y={560} size={72} color={C.cyan} rotate={-8} />
      <Sparkle x={1130} y={460} size={86} color={C.violet} rotate={12} />
      <Sparkle x={1160} y={1450} size={60} color={C.pink} />
      <Sparkle x={110} y={2340} size={78} color={C.pink} rotate={-18} opacity={0.85} />
      <Caption top={280} size={112} lines={t.score.lines} />
      <Phone src={`${base}/stats-resumen.png`} alt="Financial health" style={{ width: 920, left: "50%", transform: "translateX(-50%)", top: 740 }} />
      <Logo />
    </Base>
  );
}

function PhPresupuestos({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H} deep>
      <Sparkle x={1110} y={500} size={92} color={C.pink} rotate={-10} />
      <Sparkle x={150} y={1300} size={64} color={C.cyan} rotate={16} />
      <Sparkle x={1150} y={2280} size={76} color={C.indigo} opacity={0.9} />
      <Caption top={270} size={112} lines={t.presupuestos.lines} />
      <Phone src={`${base}/planificacion-presupuestos.png`} alt="Budgets" style={{ width: 940, left: "50%", transform: "translateX(-50%) rotate(-3deg)", top: 800 }} />
      <Logo />
    </Base>
  );
}

function PhFlujo({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H}>
      <Glow x={350} y={-450} size={1500} color={C.cyan} opacity={0.22} />
      <Sparkle x={140} y={470} size={78} color={C.cyan} rotate={-8} />
      <Sparkle x={1120} y={560} size={66} color={C.indigo} rotate={14} />
      <Sparkle x={1150} y={2320} size={88} color={C.pink} opacity={0.85} />
      <Caption top={250} size={112} lines={t.flujo.lines} />
      <Sub top={570} text={t.flujo.sub!} />
      <Phone src={`${base}/flujo-caja.png`} alt="Cash flow" style={{ width: 920, left: "50%", transform: "translateX(-50%)", top: 800 }} />
      <Logo />
    </Base>
  );
}

function PhDistribucion({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H}>
      <Sparkle x={140} y={450} size={84} color={C.indigo} rotate={10} />
      <Sparkle x={1140} y={1180} size={70} color={C.pink} rotate={-12} />
      <Sparkle x={180} y={2300} size={64} color={C.cyan} opacity={0.9} />
      <Glow x={500} y={1900} size={1400} color={C.indigo} opacity={0.35} />
      <Caption top={280} size={112} lines={t.distribucion.lines} />
      <Phone src={`${base}/panel-distribucion.png`} alt="Distribution" style={{ width: 920, left: "50%", transform: "translateX(-50%)", top: 760 }} />
      <Logo />
    </Base>
  );
}

function PhTemas({ t, base }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H} deep>
      <Glow x={-300} y={1500} size={1600} color={C.pink} opacity={0.3} />
      <Sparkle x={150} y={500} size={84} color={C.pink} rotate={10} />
      <Sparkle x={1130} y={440} size={68} color={C.cyan} rotate={-12} />
      <Sparkle x={1150} y={1350} size={72} color={C.violet} opacity={0.9} />
      <Caption top={270} size={120} lines={t.temas.lines} />
      <Sub top={460} text={t.temas.sub!} />
      <Phone src={`${base}/panel-tema-claro.png`} alt="Light theme" style={{ width: 620, left: -100, top: 1000, transform: "rotate(-7deg)", opacity: 0.92 }} />
      <Phone src={`${base}/panel-tema-rosa.png`} alt="Pink theme" style={{ width: 620, right: -100, top: 1000, transform: "rotate(7deg)", opacity: 0.92 }} />
      <Phone src={`${base}/panel-hero.png`} alt="Indigo theme" style={{ width: 700, left: "50%", transform: "translateX(-50%)", top: 880 }} />
      <Logo />
    </Base>
  );
}

function PrivacyScreens({ w1, w2, l, r, t1, t2 }: { w1: number; w2: number; l: number; r: number; t1: number; t2: number }) {
  return (
    <>
      <div className="absolute" style={{ left: l, top: t1, width: w1, aspectRatio: `${MK_W}/${MK_H}`, transform: "rotate(-4deg)" }}>
        <img src="/mockup.png" alt="" className="block w-full h-full" draggable={false} style={{ filter: "saturate(0.15) brightness(0.75)" }} />
        <div className="absolute z-10 flex items-center justify-center" style={{
          left: `${SC_L}%`, top: `${SC_T}%`, width: `${SC_W}%`, height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`, background: "#05070D",
        }}>
          <svg viewBox="0 0 24 24" width={w1 * 0.34} height={w1 * 0.34} fill="none" stroke={C.cyan} strokeWidth="1.6"
            style={{ filter: `drop-shadow(0 0 28px ${C.cyan})` }}>
            <rect x="5" y="10.5" width="14" height="9.5" rx="2.4" />
            <path d="M8 10.5V7.8a4 4 0 0 1 8 0v2.7" />
            <circle cx="12" cy="15.2" r="1.5" fill={C.cyan} stroke="none" />
          </svg>
        </div>
      </div>
      <div className="absolute" style={{ right: r, top: t2, width: w2, aspectRatio: `${MK_W}/${MK_H}`, transform: "rotate(4deg)" }}>
        <img src="/mockup.png" alt="" className="block w-full h-full" draggable={false} style={{ filter: "saturate(0.15) brightness(0.75)" }} />
        <div className="absolute z-10 flex items-center justify-center" style={{
          left: `${SC_L}%`, top: `${SC_T}%`, width: `${SC_W}%`, height: `${SC_H}%`,
          borderRadius: `${SC_RX}% / ${SC_RY}%`, background: "#05070D",
        }}>
          <svg viewBox="0 0 24 24" width={w2 * 0.38} height={w2 * 0.38} fill={C.cyan} style={{ filter: `drop-shadow(0 0 30px ${C.cyan})` }}>
            <path d="M18.4 10.1a6 6 0 0 0-11.5-1.6A4.8 4.8 0 0 0 7 18h11a4 4 0 0 0 .4-7.9Z" />
          </svg>
        </div>
      </div>
    </>
  );
}

function PrivacyPad({ w, icon, style }: { w: number; icon: "lock" | "cloud"; style?: React.CSSProperties }) {
  return (
    <div className="absolute" style={{ width: w, aspectRatio: "770/1000", ...style }}>
      <div style={{
        width: "100%", height: "100%", borderRadius: "5% / 3.6%",
        background: "linear-gradient(180deg, #2C2C2E 0%, #1C1C1E 100%)",
        position: "relative", overflow: "hidden",
        boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.1), 0 8px 40px rgba(0,0,0,0.6)",
      }}>
        <div style={{
          position: "absolute", inset: 0, borderRadius: "5% / 3.6%",
          border: "1px solid rgba(255,255,255,0.06)", pointerEvents: "none", zIndex: 15,
        }} />
        <div className="flex items-center justify-center" style={{
          position: "absolute", left: "4%", top: "2.8%", width: "92%", height: "94.4%",
          borderRadius: "2.2% / 1.6%", overflow: "hidden", background: "#05070D",
        }}>
          {icon === "lock" ? (
            <svg viewBox="0 0 24 24" width={w * 0.3} height={w * 0.3} fill="none" stroke={C.cyan} strokeWidth="1.6"
              style={{ filter: `drop-shadow(0 0 28px ${C.cyan})` }}>
              <rect x="5" y="10.5" width="14" height="9.5" rx="2.4" />
              <path d="M8 10.5V7.8a4 4 0 0 1 8 0v2.7" />
              <circle cx="12" cy="15.2" r="1.5" fill={C.cyan} stroke="none" />
            </svg>
          ) : (
            <svg viewBox="0 0 24 24" width={w * 0.34} height={w * 0.34} fill={C.cyan} style={{ filter: `drop-shadow(0 0 30px ${C.cyan})` }}>
              <path d="M18.4 10.1a6 6 0 0 0-11.5-1.6A4.8 4.8 0 0 0 7 18h11a4 4 0 0 0 .4-7.9Z" />
            </svg>
          )}
        </div>
      </div>
    </div>
  );
}

function PhPrivacidad({ t }: SlideProps) {
  return (
    <Base w={IPHONE_W} h={IPHONE_H} deep>
      <Glow x={250} y={900} size={1800} color={C.indigo} opacity={0.35} />
      <Sparkle x={160} y={520} size={68} color={C.cyan} rotate={12} />
      <Sparkle x={1120} y={480} size={84} color={C.pink} rotate={-8} />
      <Sparkle x={1150} y={2200} size={72} color={C.indigo} />
      <Sparkle x={130} y={2280} size={88} color={C.pink} rotate={20} opacity={0.85} />
      <Caption top={260} size={108} lines={t.privacidad.lines} />
      <PrivacyScreens w1={520} w2={520} l={130} r={130} t1={800} t2={980} />
      <Caption top={2280} size={108} lines={t.privacidad.lines2!} />
      <Logo />
    </Base>
  );
}

/* ============================================================
   SLIDES iPad — mismos 10, canvas 2064×2752 (3:4)
   ============================================================ */
const PD = { cap: 150, sub: 82, capTop: 210, subTop: 640 };

function PadSimple({ t, base, copyKey, shot, deep = false, rotate = 0, glow }: SlideProps & {
  copyKey: string; shot: string; deep?: boolean; rotate?: number; glow?: { x: number; y: number; color: string; opacity?: number };
}) {
  const c = t[copyKey];
  return (
    <Base w={IPAD_W} h={IPAD_H} deep={deep}>
      {glow && <Glow x={glow.x} y={glow.y} size={2200} color={glow.color} opacity={glow.opacity ?? 0.35} />}
      <Sparkle x={230} y={640} size={100} color={C.pink} rotate={10} />
      <Sparkle x={1780} y={560} size={120} color={C.cyan} rotate={-12} />
      <Sparkle x={1840} y={2300} size={104} color={C.indigo} opacity={0.85} />
      <Sparkle x={190} y={2200} size={88} color={C.pink} rotate={18} opacity={0.8} />
      <Caption top={PD.capTop} size={PD.cap} lines={c.lines} />
      {c.sub && <Sub top={PD.subTop} text={c.sub} size={PD.sub} />}
      <IPad src={`${base}/${shot}`} alt={copyKey}
        style={{ width: 1240, left: "50%", transform: `translateX(-50%) rotate(${rotate}deg)`, top: c.sub ? 800 : 740 }} />
      <Logo scale={1.4} />
    </Base>
  );
}

function PadGrupos({ t, base }: SlideProps) {
  const c = t.grupos;
  return (
    <Base w={IPAD_W} h={IPAD_H}>
      <Glow x={900} y={1900} size={2000} color={C.violet} opacity={0.35} />
      <Sparkle x={1800} y={540} size={110} color={C.cyan} rotate={-10} />
      <Sparkle x={200} y={1500} size={92} color={C.pink} rotate={14} />
      <Caption top={PD.capTop} size={PD.cap} lines={c.lines} />
      <Sub top={PD.subTop} text={c.sub!} size={PD.sub} />
      <IPad src={`${base}/grupos-lista.png`} alt="Groups" style={{ width: 1280, left: -420, top: 900, transform: "rotate(-5deg)", opacity: 0.78 }} />
      <IPad src={`${base}/grupo-balances.png`} alt="Balances" style={{ width: 1180, right: -120, top: 840 }} />
      <Logo scale={1.4} />
    </Base>
  );
}

function PadTemas({ t, base }: SlideProps) {
  const c = t.temas;
  return (
    <Base w={IPAD_W} h={IPAD_H} deep>
      <Glow x={-400} y={1400} size={2000} color={C.pink} opacity={0.28} />
      <Sparkle x={230} y={560} size={110} color={C.pink} rotate={10} />
      <Sparkle x={1790} y={500} size={92} color={C.cyan} rotate={-12} />
      <Caption top={PD.capTop} size={160} lines={c.lines} />
      <Sub top={500} text={c.sub!} size={PD.sub} />
      <IPad src={`${base}/panel-tema-claro.png`} alt="Light" style={{ width: 880, left: -120, top: 900, transform: "rotate(-7deg)", opacity: 0.92 }} />
      <IPad src={`${base}/panel-tema-rosa.png`} alt="Pink" style={{ width: 880, right: -120, top: 900, transform: "rotate(7deg)", opacity: 0.92 }} />
      <IPad src={`${base}/panel-hero.png`} alt="Indigo" style={{ width: 980, left: "50%", transform: "translateX(-50%)", top: 780 }} />
      <Logo scale={1.4} />
    </Base>
  );
}

function PadPrivacidad({ t }: SlideProps) {
  const c = t.privacidad;
  return (
    <Base w={IPAD_W} h={IPAD_H} deep>
      <Glow x={500} y={800} size={2200} color={C.indigo} opacity={0.32} />
      <Sparkle x={240} y={600} size={92} color={C.cyan} rotate={12} />
      <Sparkle x={1780} y={560} size={110} color={C.pink} rotate={-8} />
      <Sparkle x={1820} y={2150} size={96} color={C.indigo} />
      <Caption top={240} size={140} lines={c.lines} />
      <PrivacyPad w={880} icon="lock" style={{ left: 120, top: 880, transform: "rotate(-4deg)" }} />
      <PrivacyPad w={880} icon="cloud" style={{ right: 120, top: 1040, transform: "rotate(4deg)" }} />
      <Caption top={2200} size={140} lines={c.lines2!} />
      <Logo scale={1.4} />
    </Base>
  );
}

/* ============================================================
   Registries — set final (10) por device
   ============================================================ */
type SlideDef = { key: string; title: string; render: (p: SlideProps) => React.ReactNode };

const IPHONE_SLIDES: SlideDef[] = [
  { key: "01-hero", title: "1 · Hero", render: (p) => <PhHero {...p} /> },
  { key: "02-yala-ia", title: "2 · Yala IA", render: (p) => <PhIA {...p} /> },
  { key: "03-grupos", title: "3 · Grupos", render: (p) => <PhGrupos {...p} /> },
  { key: "04-registro", title: "4 · Registro", render: (p) => <PhRegistro {...p} /> },
  { key: "05-score", title: "5 · Score", render: (p) => <PhScore {...p} /> },
  { key: "06-presupuestos", title: "6 · Presupuestos", render: (p) => <PhPresupuestos {...p} /> },
  { key: "07-flujo-caja", title: "7 · Flujo de caja", render: (p) => <PhFlujo {...p} /> },
  { key: "08-distribucion", title: "8 · Distribución", render: (p) => <PhDistribucion {...p} /> },
  { key: "09-temas", title: "9 · Temas", render: (p) => <PhTemas {...p} /> },
  { key: "10-privacidad", title: "10 · Privacidad", render: (p) => <PhPrivacidad {...p} /> },
];

const IPAD_SLIDES: SlideDef[] = [
  { key: "01-hero", title: "1 · Hero", render: (p) => <PadSimple {...p} copyKey="hero" shot="panel-hero.png" glow={{ x: -500, y: -300, color: C.indigo, opacity: 0.4 }} /> },
  { key: "02-yala-ia", title: "2 · Yala IA", render: (p) => <PadSimple {...p} copyKey="ia" shot="chat-analisis.png" deep glow={{ x: -500, y: 1500, color: C.indigo, opacity: 0.4 }} /> },
  { key: "03-grupos", title: "3 · Grupos", render: (p) => <PadGrupos {...p} /> },
  { key: "04-registro", title: "4 · Registro", render: (p) => <PadSimple {...p} copyKey="registro" shot="nuevo-registro.png" deep rotate={2} /> },
  { key: "05-score", title: "5 · Score", render: (p) => <PadSimple {...p} copyKey="score" shot="stats-resumen.png" glow={{ x: 400, y: -400, color: C.indigo, opacity: 0.4 }} /> },
  { key: "06-presupuestos", title: "6 · Presupuestos", render: (p) => <PadSimple {...p} copyKey="presupuestos" shot="planificacion-presupuestos.png" deep rotate={-2} /> },
  { key: "07-flujo-caja", title: "7 · Flujo de caja", render: (p) => <PadSimple {...p} copyKey="flujo" shot="flujo-caja.png" glow={{ x: 500, y: -400, color: C.cyan, opacity: 0.2 }} /> },
  { key: "08-distribucion", title: "8 · Distribución", render: (p) => <PadSimple {...p} copyKey="distribucion" shot="panel-distribucion.png" glow={{ x: 300, y: 1700, color: C.indigo, opacity: 0.3 }} /> },
  { key: "09-temas", title: "9 · Temas", render: (p) => <PadTemas {...p} /> },
  { key: "10-privacidad", title: "10 · Privacidad", render: (p) => <PadPrivacidad {...p} /> },
];

/* ============================================================
   Página
   ============================================================ */
function ScreenshotPreview({ slide, index, device, props }: {
  slide: SlideDef; index: number; device: Device; props: SlideProps;
}) {
  const boxRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(0.1);
  const W = device === "iphone" ? IPHONE_W : IPAD_W;
  const H = device === "iphone" ? IPHONE_H : IPAD_H;

  useEffect(() => {
    const el = boxRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => setScale(el.clientWidth / W));
    ro.observe(el);
    return () => ro.disconnect();
  }, [W]);

  return (
    <div className="flex flex-col gap-2">
      <div className="text-sm font-semibold text-white/80">{slide.title}</div>
      <div ref={boxRef} id={`preview-${index}`} className="relative w-full overflow-hidden rounded-xl border border-white/10"
        style={{ aspectRatio: `${W}/${H}` }}>
        <div style={{ width: W, height: H, transform: `scale(${scale})`, transformOrigin: "top left" }}>
          {slide.render(props)}
        </div>
      </div>
    </div>
  );
}

export default function ScreenshotsPage() {
  const [locale, setLocale] = useState<Locale>("es");
  const [device, setDevice] = useState<Device>("iphone");
  const [exporting, setExporting] = useState<string | null>(null);
  const exportRefs = useRef<(HTMLDivElement | null)[]>([]);

  const slides = device === "iphone" ? IPHONE_SLIDES : IPAD_SLIDES;
  const sizes = device === "iphone" ? IPHONE_SIZES : IPAD_SIZES;
  const W = device === "iphone" ? IPHONE_W : IPAD_W;
  const H = device === "iphone" ? IPHONE_H : IPAD_H;
  const base = device === "iphone" ? `/screenshots/${locale}` : `/screenshots-ipad/${locale}`;
  const props: SlideProps = { t: COPY[locale], base };

  // Captura el slide una vez y lo reescala a todos los tamaños del device
  const exportSlide = useCallback(async (index: number) => {
    const el = exportRefs.current[index];
    if (!el) return;
    setExporting(`${slides[index].key} (${locale}/${device})`);
    el.style.left = "0px";
    el.style.zIndex = "-1";
    const opts = { width: W, height: H, pixelRatio: 1, cacheBust: true };
    try {
      await toPng(el, opts); // warm-up
      const dataUrl = await toPng(el, opts);
      const img = document.createElement("img");
      await new Promise<void>((res) => { img.onload = () => res(); img.src = dataUrl; });
      for (const size of sizes) {
        const canvas = document.createElement("canvas");
        canvas.width = size.w; canvas.height = size.h;
        canvas.getContext("2d")!.drawImage(img, 0, 0, size.w, size.h);
        await fetch("/api/save", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            dir: `${device}-${locale}/${size.w}x${size.h}`,
            name: `${slides[index].key}-${locale}-${size.w}x${size.h}.png`,
            dataUrl: canvas.toDataURL("image/png"),
          }),
        });
      }
    } finally {
      el.style.left = "-99999px";
      el.style.zIndex = "";
      setExporting(null);
    }
  }, [slides, sizes, locale, device, W, H]);

  const exportAll = useCallback(async () => {
    for (let i = 0; i < slides.length; i++) {
      await exportSlide(i);
      await new Promise((r) => setTimeout(r, 250));
    }
    document.title = `DONE-${device}-${locale}`;
  }, [slides, exportSlide, device, locale]);

  return (
    <div className="min-h-screen bg-[#0B0F1D] p-8">
      <div className="mx-auto max-w-7xl">
        <div className="mb-6 flex flex-wrap items-center gap-3">
          <h1 className="text-2xl font-extrabold text-white">Yala · App Store</h1>
          {LOCALES.map((l) => (
            <button key={l} id={`locale-${l}`} onClick={() => setLocale(l)}
              className={`rounded-full px-3 py-1 text-sm font-bold ${l === locale ? "bg-white text-black" : "bg-white/10 text-white/70"}`}>
              {l.toUpperCase()}
            </button>
          ))}
          <span className="text-white/30">·</span>
          {(["iphone", "ipad"] as Device[]).map((d) => (
            <button key={d} id={`device-${d}`} onClick={() => setDevice(d)}
              className={`rounded-full px-3 py-1 text-sm font-bold ${d === device ? "bg-white text-black" : "bg-white/10 text-white/70"}`}>
              {d === "iphone" ? "iPhone" : "iPad"}
            </button>
          ))}
          <button id="export-set" onClick={exportAll}
            className="rounded-full bg-cyan-600 px-4 py-1.5 text-sm font-bold text-white hover:bg-cyan-500">
            {exporting ? `Exportando ${exporting}…` : `Exportar set ${device}-${locale} (todos los tamaños)`}
          </button>
        </div>

        <div className="grid grid-cols-2 gap-6 md:grid-cols-3 lg:grid-cols-5">
          {slides.map((slide, i) => (
            <ScreenshotPreview key={`${device}-${locale}-${slide.key}`} slide={slide} index={i} device={device} props={props} />
          ))}
        </div>
      </div>

      {/* offscreen a tamaño real */}
      {slides.map((slide, i) => (
        <div key={`x-${device}-${locale}-${slide.key}`} ref={(el) => { exportRefs.current[i] = el; }}
          className="absolute top-0" style={{ left: "-99999px", width: W, height: H }}>
          {slide.render(props)}
        </div>
      ))}
    </div>
  );
}
