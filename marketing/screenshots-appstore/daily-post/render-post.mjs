// Renderiza un post de Yala a PNG 1080x1350 (4:5 vertical, Chrome headless).
// El contenido (diseñado a 1080) se centra verticalmente en el lienzo alto.
// Soporta formatos vía `screenshot`: sin screenshot = gráfico; con screenshot = funcionalidad.
// Uso: node render-post.mjs <índice>  → imprime JSON { index, id, kind, png, caption, total }
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { execSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = dirname(fileURLToPath(import.meta.url));
const PUB = join(DIR, "..", "generator", "public");
const SS = join(PUB, "screenshots", "es");
const OUT = join(DIR, "out");
mkdirSync(OUT, { recursive: true });

const IG_W = 1080, IG_H = 1350, VSHIFT = (IG_H - IG_W) / 2; // 135
const COLORS = { cyan: "#3BD6F0", pink: "#FF2D78", indigo: "#6164EB", violet: "#8B5CF6" };
const SPK = "M50 0 C54 36 64 46 100 50 C64 54 54 64 50 100 C46 64 36 54 0 50 C36 46 46 36 50 0 Z";
const SC = { l: 5.09, t: 2.21, w: 89.82, h: 95.58, rx: 13.7, ry: 6.33 };
const b64 = (p) => readFileSync(p).toString("base64");
const dataURI = (p, mime) => `data:${mime};base64,${b64(p)}`;
const spk = (p) => `<svg viewBox="0 0 100 100" style="position:absolute;left:${p.x}px;top:${p.y}px;width:${p.s}px;height:${p.s}px;opacity:${p.o};transform:rotate(${p.r}deg);filter:drop-shadow(0 0 ${p.s * 0.18}px ${p.c})"><path d="${SPK}" fill="${p.c}"/></svg>`;

const items = JSON.parse(readFileSync(join(DIR, "content.json"), "utf8"));
const idx = ((parseInt(process.argv[2] ?? "0", 10) % items.length) + items.length) % items.length;
const t = items[idx];
const accent = COLORS[t.accent] || COLORS.cyan;
const logo = dataURI(join(PUB, "yala-spark.png"), "image/png");
const hasShot = !!t.screenshot;

// sparkles dentro del contenido (coords 1080) + relleno en las bandas del lienzo alto
const inner = [
  { x: 62, y: 300, s: 60, c: "#6164EB", r: 12, o: 1 }, { x: 958, y: 210, s: 82, c: "#FF2D78", r: -8, o: 1 },
  { x: 1002, y: 770, s: 58, c: "#3BD6F0", r: 6, o: 0.9 }, { x: 74, y: 850, s: 72, c: "#3BD6F0", r: -15, o: 0.85 },
  { x: 930, y: 965, s: 66, c: "#6164EB", r: 18, o: 0.8 },
].map(spk).join("");
const filler = [
  { x: 150, y: 64, s: 52, c: "#FF2D78", r: -10, o: 0.7 }, { x: 902, y: 96, s: 60, c: "#3BD6F0", r: 8, o: 0.65 },
  { x: 120, y: 1236, s: 58, c: "#6164EB", r: 14, o: 0.7 }, { x: 928, y: 1262, s: 54, c: "#FF2D78", r: -12, o: 0.65 },
].map(spk).join("");

let phone = "";
if (hasShot) {
  const mk = dataURI(join(PUB, "mockup.png"), "image/png");
  const shot = dataURI(join(SS, `${t.screenshot}.png`), "image/png");
  const ph = `<img src="${mk}" style="width:100%;display:block;filter:saturate(.18) brightness(.78)"/>` +
    `<div style="position:absolute;overflow:hidden;left:${SC.l}%;top:${SC.t}%;width:${SC.w}%;height:${SC.h}%;border-radius:${SC.rx}% / ${SC.ry}%"><img src="${shot}" style="width:100%;height:100%;object-fit:cover;object-position:top;display:block"/></div>`;
  phone = t.shot === "full"
    ? `<div style="position:absolute;left:50%;top:460px;transform:translateX(-50%);width:392px;aspect-ratio:1022/2082;z-index:3;filter:drop-shadow(0 26px 55px rgba(0,0,0,.55))">${ph}</div>`
    : `<div style="position:absolute;right:65px;top:520px;width:580px;aspect-ratio:1022/2082;z-index:3;transform:rotate(-5deg);filter:drop-shadow(0 30px 60px rgba(0,0,0,.55))">${ph}</div>`;
}

const tbStyle = hasShot
  ? "position:absolute;left:78px;right:78px;top:150px;text-align:center;z-index:5"
  : "position:absolute;left:78px;right:78px;top:50%;transform:translateY(-50%);text-align:center;z-index:5";
const titleSize = hasShot ? 72 : 80;
const subTop = hasShot ? 28 : 46;

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
*{margin:0;box-sizing:border-box}
body{width:${IG_W}px;height:${IG_H}px;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif}
.slide{width:${IG_W}px;height:${IG_H}px;position:relative;overflow:hidden;background:linear-gradient(180deg,#0F172A 0%,#0B1122 100%)}
.stage{position:absolute;left:0;top:${VSHIFT}px;width:${IG_W}px;height:${IG_W}px}
.glow{position:absolute;left:250px;top:280px;width:1400px;height:1400px;opacity:.3;border-radius:50%;pointer-events:none;background:radial-gradient(circle,${accent} 0%,transparent 70%)}
.badge{position:absolute;top:${hasShot ? 70 : 160}px;left:0;right:0;text-align:center;z-index:5}
.badge span{display:inline-block;font-size:30px;font-weight:800;letter-spacing:2px;text-transform:uppercase;color:${accent};background:${accent}26;padding:13px 28px;border-radius:32px}
.title{font-size:${titleSize}px;font-weight:850;color:#fff;line-height:1.16;letter-spacing:-1px}
.hl{font-size:${titleSize}px;font-weight:850;line-height:1.16;letter-spacing:-1px;margin-top:6px}
.hl .w{position:relative;color:${accent};white-space:pre}
.hl .bar{position:absolute;left:2px;right:2px;bottom:-6px;height:10px;border-radius:6px;background:${accent}}
.sub{font-size:44px;font-weight:600;color:rgba(255,255,255,.72);line-height:1.34}
.logo{position:absolute;left:64px;bottom:60px;z-index:6}
.logo img{width:190px;display:block}
</style></head><body><div class="slide">
${filler}
<div class="stage">
<div class="glow"></div>
${inner}
<div class="badge"><span>${t.emoji ? t.emoji + " " : ""}${t.tag}</span></div>
<div style="${tbStyle}">
  <div class="title">${t.title}</div>
  <div class="hl"><span class="w">${t.highlight}<span class="bar"></span></span></div>
  ${t.sub ? `<div class="sub" style="margin-top:${subTop}px">${t.sub}</div>` : ""}
</div>
${phone}
<div class="logo"><img src="${logo}" alt="yala"/></div>
</div>
</div></body></html>`;

const htmlPath = join(OUT, "post.html");
const pngPath = join(OUT, `post-${t.id}.png`);
writeFileSync(htmlPath, html);

const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
execSync(`"${CHROME}" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 --virtual-time-budget=3000 --window-size=${IG_W},${IG_H} --screenshot=${JSON.stringify(pngPath)} ${JSON.stringify("file://" + htmlPath)}`, { stdio: "ignore" });

console.log(JSON.stringify({ index: idx, id: t.id, kind: t.kind, png: pngPath, caption: t.caption, total: items.length }));
