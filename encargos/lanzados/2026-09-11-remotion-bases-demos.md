# Scaffold Remotion en marketing/remotion: bases para demos diarios + 1 piloto Yala IA (Pizza 20 PEN)

## Contexto
Brief de dirección (2026-09-10/11): montar un estudio de demos con Remotion dentro del repo Yala, carpeta marketing/. No es un Reel suelto: es el sistema (plantilla + props + render diario).
Release marketing actual: 2.1 (Liquid Glass). Destino de esta sesión: marketing (agente lola). La rama del worktree ya nace de origin/2.1.
Footage piloto real ya está en la Mini (NO regenerar UI):
  /Users/jur/Claude/Artifacts/Yala-demo-IA-gasto-pizza/Yala-IA-gasto-pizza-16s.mp4
  (16.18s, 1170x2532, H.264, sin audio). Cópialo a marketing/remotion/public/footage/ia-gasto-pizza-16s.mp4.
ARRANCAS EN CONTEXTO LIMPIO: no ves la conversación previa. Lo que no esté aquí, se pierde.

## Que se pide
Ejecuta ENTERO el prompt operativo de abajo. No recortes restricciones ni links.

# /remotion-best-practices
# Repo: github.com/jur211296/Yala  |  base: origin/2.1
# Trabajas como el agente de marketing de Yala. Lee CLAUDE.md, docs/ESTADO.md y marketing/README.md antes de tocar nada.

### Misión
Crear las BASES de un estudio de demos dentro del repo, no un Reel aislado.

Resultado esperado al cerrar:
1. Proyecto Remotion nuevo en `marketing/remotion/` (NO en la raíz, NO dentro de `Yala/` iOS, NO dentro de `Web/`).
2. Skills oficiales Remotion + catálogo de planos (video-shotcraft / ai-product-video) + explainer TTS (anything2explainer) instalados para Claude Code y Codex.
3. Tokens de marca 2.1 versionados en código.
4. Plantilla de composition reutilizable: footage real de iPhone + overlay tipográfico estilo Apple.
5. Primera pieza piloto: "Yala IA · registra un gasto en lenguaje natural" (Pizza 20 PEN).
6. Scripts npm para studio + render 9:16 y 16:9.
7. README de operación diaria (cómo tirar un .MOV nuevo y sacar un Reel).
8. `.gitignore` que no suba `out/` ni .MOV enormes sin LFS / instrucciones claras.

NO hagas: publicar a App Store, tocar Swift, tocar gateway, generar UI falsa de Yala con IA, instalar Higgsfield, ni clonar toda la app en React. NO push a 2.1 sin que Mini lo pida; cierra con PR.

### Qué es Yala
App iOS de finanzas personales. Swift / SwiftUI / SwiftData. Target iOS 26+.
Sitio: https://yala-app.vercel.app
Repo: https://github.com/jur211296/Yala
Look 2.1 CONGELADO: Liquid Glass, fondo glass oscuro, montos grandes rounded, acento índigo, gasto en rosa.
Light / Rosa / Teal / Minimalist NO son el look de las piezas 2.1.

Hex oficiales:
- Índigo  #6366F1
- Pink gasto  #FF0080
- Teal  #00C2CB
- Fondo Liquid Glass  #060612

SSOT: tickets/, docs/ESTADO.md, CLAUDE.md. YalaWiki archivado.

Carpeta marketing ya existe (README, App Store/, screenshots-appstore/, .claude/). Añade Remotion como hermano, no como reemplazo del generador de screenshots.

### Principio creativo (no negociable)
CAPA A — VERDAD DEL PRODUCTO: screen recordings del iPhone real. La UI de Yala NUNCA se regenera con Imagine/Higgsfield/Kling/Sora ni Remotion-dibujando-un-iPhone.
CAPA B — MOTION GRAPHICS ESTILO APPLE: títulos SF-like, springs, fades, lower-thirds, end cards, device frame opcional, zoom al gesto. Copy corto. Nada de karaoke TikTok como default.
Imagine SOLO B-roll de atmósfera. CapCut no es el sistema.

### Instalación obligatoria (ejecuta, no solo documentes)
Node 18+. bun o npm según el entorno.

1) cd marketing && bun create video remotion (Blank, Tailwind Yes, Install skills Yes). Si el wizard no es non-interactive, scaffold Blank + Tailwind a mano.
   Docs: https://www.remotion.dev/docs
   Blank + skills: https://derekkumo.com/claude-code/how-to-install-remotion-for-claude-code

2) Plugin + skills oficiales:
   npx skills add remotion-dev/skills
   claude plugin marketplace add remotion-dev/claude-code-plugin
   claude plugin install remotion@remotion
   Docs: https://www.remotion.dev/docs/ai/skills · https://github.com/remotion-dev/skills · https://www.remotion.dev/docs/ai/claude-code-plugin

   Skills oficiales: /remotion-best-practices /remotion-create /remotion-markup /remotion-studio /remotion-render /remotion-captions /remotion-docs /remotion-upgrade /remotion-interactivity

2b) Skills de plano + explainer — OBLIGATORIOS
   Capa 1 motor: remotion-dev/skills
   Capa 2 planos: video-shotcraft + ai-product-video
     npx skills add Vincentwei1021/video-shotcraft
     npx skills add dlazy-ai/ai-product-video
     (o clone + ln -s a .claude/skills y ~/.claude/skills y ~/.codex/skills)
     Repos: https://github.com/Vincentwei1021/video-shotcraft · https://github.com/dlazy-ai/ai-product-video
   Capa 3 explainer TTS: anything2explainer
     git clone https://github.com/Vincentwei1021/anything2explainer.git + ln -s
     Repo: https://github.com/Vincentwei1021/anything2explainer
   USO en Yala:
   - SÍ: 2–4 shot cards por pieza; timing/energía; anotar en SHOT-CONTRACT / SHOT-CARDS.md
   - NO: reconstruir la app con page captures; estética Ink Press; renderizar template Ink Press 36s como demo Yala
   - Remapea color a tokens Yala. Explainer: solo instalar + nota en OPERACION.md + slug reservado `explainer-que-es-yala-ia` SIN composition/render en esta sesión. NO ElevenLabs ahora.

3) Paquetes: remotion, @remotion/cli, @remotion/media, @remotion/transitions, @remotion/google-fonts (Inter/Geist), @remotion/captions opcional, @remotion/tailwind si aplica.
   OffthreadVideo OBLIGATORIO para footage: https://www.remotion.dev/docs/offthreadvideo
   NO instalar Remotion Recorder ahora.

4) Licencia: nota en marketing/remotion/LICENSE-NOTES.md. No bloquees el scaffold.
   https://www.remotion.dev/docs/license · https://www.remotion.dev/pricing

### Arquitectura (créala)
marketing/remotion/
  package.json, remotion.config.ts
  src/Root.tsx, index.ts
  src/brand/tokens.ts, copy.ts
  src/compositions/FeatureDemo.tsx, FeatureDemo916.tsx, FeatureDemo169.tsx, EndCard.tsx
  src/components/DeviceFrame.tsx, AppleTitle.tsx, Callout.tsx, SafeAreas.tsx
  src/lib/timing.ts
  public/footage/, stills/, audio/
  out/ (gitignore)
  docs/OPERACION.md, SHOT-CONTRACT.md, SHOT-CARDS.md
  scripts/render-reels.sh, render-all.sh

Actualiza marketing/README.md apuntando a remotion/. NO toques Yala.xcodeproj ni target iOS.

### tokens.ts (cópialos, no inventes)
export const yala = {
  color: { bg: "#060612", indigo: "#6366F1", pink: "#FF0080", teal: "#00C2CB", white: "#FFFFFF", textSecondary: "rgba(255,255,255,0.72)" },
  type: { family: "Inter", heroPx: 64, heroPx169: 72, calloutPx: 28 },
  motion: { fps: 30, springTitle: { damping: 14, mass: 0.4, stiffness: 120 }, fadeFrames: 10, titleIn: 8, titleHold: 50, titleOut: 12 },
  canvas: { reels: { w: 1080, h: 1920, id: "FeatureDemo-9x16" }, youtube: { w: 1920, h: 1080, id: "FeatureDemo-16x9" } },
} as const;
Plantilla con theme: "dark" | "light" para el marco; NO recolorear el footage. El piloto está en Light (deuda de toma).

### SHOT-CONTRACT / props
FeatureDemo lee props (slug, footage, durationFrames, hooks/callouts ES/EN, frames, locale). No hardcodees copy en el JSX.

### Pieza piloto
Flujo: "Registra un gasto de 20 soles en restaurantes con concepto Pizza" → card confirmación → cuenta Gastos Soles · PEN → Guardar → Pizza · PEN 20.00 · Registrado → lista Registros.
Copia el mp4 desde /Users/jur/Claude/Artifacts/Yala-demo-IA-gasto-pizza/Yala-IA-gasto-pizza-16s.mp4 a public/footage/ia-gasto-pizza-16s.mp4.
Timing: 0–1.4 chips; 1.4–3.7 tipeo; 3.7–5.8 burbuja; 5.8–8.0 card; 8.0–9.8 picker; 9.8–11.3 cuenta; 11.3–13.9 éxito ← CALL OUT; 13.9–16.2 lista.
9:16: footage sobre #060612 + safe areas + hook ~0.2s + callout en éxito + end card ~1s.
16:9: mismo footage, margen glass.

### Qué NO hacer con el footage
No Imagine Edit / video-to-video. No animar screenshots. No inventar montos/chips/cuentas. No usar Light como look de pack 2.1 (nota en OPERACION.md para próxima toma: Liquid Glass, status bar limpia, sin píldora ReplayKit).

### Textos Apple
AppleTitle: máx 6 palabras, spring, white, no tapar PEN 20.
Callout: pill glass, gasto = rosa #FF0080, aparece cuando el producto ya mostró el resultado.
EndCard: #060612 + wordmark Yala + línea corta. locale es|en.

### Scripts
"studio": "remotion studio"
"render:reels": remotion render FeatureDemo-9x16 ...
"render:wide": remotion render FeatureDemo-16x9 ...
OPERACION.md loop diario: grabar → copiar footage → copy.ts → studio → render. Imagine solo si hace falta 2s de mesa.

### Pack 2.1
8 héroes + 2 apoyos. Deja slugs vacíos en copy.ts para los 8 héroes si briefs/xlsx están en workspace; no regeneres esos docs. Piloto = Yala IA.

### Definition of done
[ ] marketing/remotion/ + install OK
[ ] bun run studio abre FeatureDemo-9x16 sin crash
[ ] tokens.ts con 4 hex
[ ] FeatureDemo por props
[ ] OffthreadVideo → ia-gasto-pizza-16s.mp4
[ ] AppleTitle + Callout + EndCard con springs
[ ] Safe area 9:16
[ ] Scripts render reels/wide
[ ] marketing/README.md enlaza
[ ] OPERACION.md en español
[ ] .gitignore: node_modules, out/, .DS_Store, *.log
[ ] Sin tocar Swift/Web salvo README marketing
[ ] Skills: remotion-dev/skills + video-shotcraft y/o ai-product-video + anything2explainer
[ ] SHOT-CARDS.md 2–4 planos del piloto
[ ] OPERACION distingue FeatureDemo vs shotcraft vs explainer
[ ] copy.ts reserva explainer-que-es-yala-ia
[ ] Commit message propuesto: "chore(marketing): scaffold Remotion studio for daily product demos"

### Orden
1. Leer CLAUDE.md + marketing/README.md
2. Instalar plugin + skills (3 capas)
3. Scaffold marketing/remotion
4. tokens + components
5. FeatureDemo + piloto (copiar mp4)
6. OPERACION.md + README
7. Probar studio
8. Resume: qué renderó / qué falta / comando de render

Empieza por leer el repo. No preguntes permiso para scaffold en marketing/remotion/. Pregunta solo si algo exige tocar target iOS o publicar commit a 2.1.

## Que NO hay que tocar
- Código Swift / Yala.xcodeproj / Web/ / gateway
- Publicar App Store / TestFlight
- Regenerar UI con IA / Higgsfield
- daily-post/ (sistema cancelado)
- Push directo a 2.1; ElevenLabs; Remotion Recorder
- Datos clinicas-dentales-bi

## Como se sabe que esta bien
Checklist DoD arriba. Studio abre sin crash. Piloto usa OffthreadVideo del mp4 real. PR con el scaffold + docs. Resumen en lenguaje de usuario al cerrar.
