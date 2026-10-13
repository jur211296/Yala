# Operación diaria — estudio de demos de Yala

Cómo sale un Reel desde que grabas la pantalla del iPhone hasta que hay un mp4.
Diez minutos si la toma está bien; si la toma está mal, se vuelve a grabar — **el
footage no se retoca aquí.**

---

## Dos formatos, un solo footage por función

| | `Presentation-16x9` | `FeatureDemo-9x16` |
|---|---|---|
| Qué es | **La pieza de presentación**, horizontal, por escenas | **Un clip por función**, vertical, con zoom |
| Dónde | YouTube, web, App Store preview, keynote | Reels, TikTok, Shorts |
| Cuántas | Una (o una por release) | Una por función del pack |
| El teléfono | Objeto 3D: se inclina, gira de canto, se acerca | Grande, con la cámara siguiendo el gesto |
| El texto | **Una línea por escena**, acompaña | 6–8 beats grandes, es el guion sin sonido |
| Referencia | Kelo (2026-09-11): fondo limpio, ritmo 2–3 s | Feed: lo que para el pulgar |

**El flujo, por función:** grabas UN clip de esa función (8–15 s) → ese clip es una **escena**
de la presentación y, a la vez, **su propio clip vertical**. Un footage, dos salidas. Hoy la
presentación demo trocea el mismo mp4 del piloto por escenas; cuando haya un clip por
función, cada escena apunta al suyo en `PRESENTATIONS[…].scenes[…].footage.src`.

## El bucle

### 1 · Graba la pantalla del iPhone

La app de verdad, con datos de ejemplo. **Nunca con datos reales de nadie.**

Checklist de toma, y cada punto está aquí porque ya falló una vez:

- [ ] **Tema Liquid Glass oscuro.** Light / Rosa / Teal / Minimalist son temas de la app,
      no el look del pack 2.1.
- [ ] **Status bar limpia.** Sin la píldora roja de grabación. Se consigue grabando
      desde QuickTime con el iPhone conectado, no con la grabadora del propio iPhone.
- [ ] **Datos de ejemplo.** Ojo con los chips de sugerencia de Yala IA: se generan
      con las categorías reales del usuario y **se leen en el vídeo**.
- [ ] **Un solo gesto por plano.** Si dudas dos segundos antes de tocar, se nota.
- [ ] **Sin notificaciones.** Modo avión o No molestar.

### 1 bis · O grábala desde el simulador, sin manos

Si la función tiene un XCUITest de demo (hoy: `DemoIAPizzaUITests`), la toma sale sola y
cumple la checklist de arriba por construcción: tema oscuro, barra a las 9:41, datos de la
semilla, sin notificaciones y el mismo recorrido cada vez.

```bash
./scripts/grabar-demo-sim.sh                         # DemoIAPizza, ~3 min
./scripts/grabar-demo-sim.sh --test YalaUITests/<Clase>/<método> --salida <carpeta>
```

Deja `demo.mp4` (H.264, 60 fps, recortado de «inicio» a «fin») y `marcas.json` con el
segundo de cada beat, que va directo a los `fromSec` de `copy.ts`. El test marca cada beat
con `print("DEMO-MARCA:<id> t=<epoch>")`. El script se niega a correr de 9:00 a 11:00 de
Lima, con carga ≥ 8 o con otro simulador encendido, y lo apaga al acabar.

### 2 · Copia el fichero

```bash
cp ~/ruta/a/la/toma.mp4 marketing/remotion/public/footage/<slug>.mp4
ffprobe -v error -show_entries stream=width,height -show_entries format=duration \
  -of default=noprint_wrappers=1 marketing/remotion/public/footage/<slug>.mp4
```

Apunta la duración y la resolución: van literales a `copy.ts`. **No se estiman.**

### 3 · Escribe el guion en `src/brand/copy.ts`

Ni una palabra de copy vive en el JSX. Una entrada nueva en `PIECES`:

```ts
{
  slug: "voz-gasto-hablado",
  title: "Registra hablando",
  footage: "footage/voz-gasto-hablado.mp4",
  footageSec: 12.4,                    // lo que dijo ffprobe
  source: { w: 1170, h: 2532 },        // lo que dijo ffprobe
  crop: { top: 0.05, bottom: 0.035 },  // status bar y pie de página fuera
  theme: "dark",

  // 6–8 beats. Si hay dos segundos sin texto, el pulgar sigue bajando.
  beats: [
    { fromSec: 0, toSec: 2.1, style: "hero", place: "top",
      text: { es: "Sin teclear.", en: "No typing." } },
    { fromSec: 2.2, toSec: 4.0, style: "line", place: "top",
      text: { es: "Se lo dices y ya", en: "Just say it" } },
    // …
  ],

  // La cámara va donde está el gesto. `focusY` se MIDE, no se estima:
  //   focusY = (fracciónEnElOriginal − cropTop) / (1 − cropTop − cropBottom)
  // La ventana visible es 0,505 / scale; por encima de ~1,25 corta por los lados.
  shots: [
    { atSec: 0, focusY: 0.40, scale: 1.02 },
    { atSec: 2.4, focusY: 0.72, scale: 1.18 },
    // …
  ],

  endCard: END_CARD,
}
```

**Cómo se mide un `focusY`** — es un comando, no un ojímetro:

```bash
ffmpeg -ss 8.4 -i public/footage/<slug>.mp4 -frames:v 1 /tmp/f.png
# abre /tmp/f.png, mide a qué altura está el elemento (px / alto total)
# y aplica la fórmula de arriba
```

El copy sigue la voz de `marketing/screenshots-appstore/captions.md`: **cercana, sin
regañar**. La gente no deja de llevar sus cuentas por falta de disciplina, sino por
fricción. Si una línea suena a reproche, está mal aunque convierta.

### 4 · Míralo en Studio

```bash
cd marketing/remotion && bun run studio
```

Abre `FeatureDemo-9x16`. En el panel de props, `showSafeAreas: true` dibuja en rosa
las bandas que Instagram tapa con su UI. **Si algo importante cae dentro, se mueve el
encuadre, no se publica y ya.**

### 5 · Renderiza

```bash
bun run render:reels                    # clip piloto, es, 9:16
bash scripts/render-reels.sh <slug> es  # un clip, 9:16
bash scripts/render-reels.sh <slug> en --aspect 16x9
bun run render:presentation             # la presentación horizontal
bash scripts/render-reels.sh <slug-presentación> en --presentation
bun run render:pack                     # todos los clips CON toma, los dos lienzos
```

Sale a `out/<slug>-<locale>-<aspect>.mp4`, que **no se commitea**.

### 6 · Comprueba antes de publicar

Los scripts ya comprueban que el fichero existe, que pesa algo y cuánto dura — pero eso
solo dice que hay vídeo, no que el vídeo esté bien. Antes de que salga:

- [ ] Míralo entero, con sonido apagado, en un teléfono.
- [ ] **Los siete idiomas de la ficha se tocan juntos o no se tocan** (esto vale para la
      App Store, no para un Reel, pero el reflejo es el mismo: nada a medias).
- [ ] Publicar es hacia fuera y no se deshace. **Espera el visto bueno de Jürgen.**

---

## Tres herramientas, tres trabajos distintos

Se confunden con facilidad y hacen cosas que no se parecen en nada.

| | Qué es | Cuándo | Qué NO es |
|---|---|---|---|
| **`FeatureDemo`** (esta plantilla) | El motor del pack 2.1: footage real + rótulos | **El default.** Toda demo de una función de Yala | No dibuja UI. Si no hay toma, no hay pieza |
| **`video-shotcraft` / `ai-product-video`** (skills) | Catálogo de planos: timing, energía, tipos de movimiento | Para **decidir** 2–4 planos antes de grabar, y anotarlos en `SHOT-CARDS.md` | **NO se usa su pipeline.** Reconstruye la app con capturas de página y trae la estética Ink Press. Ni una ni otra son Yala. Su template de 36 s **no se renderiza como demo de Yala** |
| **`anything2explainer`** (skill) | Explainer con voz en off, fondo negro, capítulos | Nada todavía | Slug **`explainer-que-es-yala-ia` reservado en `copy.ts`, sin composition y sin render**. Cuando toque, se decide primero la voz. **Sin ElevenLabs por ahora** |

De las dos skills de planos, **`video-shotcraft` y `ai-product-video` son el mismo
contenido con dos nombres** (misma descripción, mismo template). Están las dos instaladas
porque el encargo las pedía; usa una.

Y el color de cualquier plano que salga de ahí **se remapea a los tokens de Yala**
(`src/brand/tokens.ts`) antes de tocar una composition.

---

## Grok Imagine: solo atmósfera, y no corre aquí

Imagine sirve para **B-roll de ambiente** —dos segundos de una mesa, una mano, una calle—
y para nada más. **La UI de Yala jamás se genera con IA**: ni Imagine, ni Higgsfield, ni
Kling, ni Sora, ni Remotion dibujando un iPhone.

Imagine **no está en Claude Code**. Lo tira Jürgen o el bot de Lola en Grok. Desde aquí se
prepara el prompt y se dice; no se finge que se puede generar.

---

## Reinstalar las skills en una Mac nueva

No están vendorizadas en el repo a propósito: son dependencias externas que se actualizan
solas y meterlas al git de Yala son miles de ficheros de terceros sin revisar.

```bash
npx skills add remotion-dev/skills -g -a '*' -y
npx skills add Vincentwei1021/video-shotcraft -g -a claude-code -y
npx skills add dlazy-ai/ai-product-video -g -a claude-code -y
npx skills add Vincentwei1021/anything2explainer -g -a claude-code -y

# Espejo para Codex
mkdir -p ~/.codex/skills
for s in ~/.claude/skills/remotion-* ~/.claude/skills/video-shotcraft \
         ~/.claude/skills/ai-product-video ~/.claude/skills/anything2explainer; do
  ln -sfn "$s" ~/.codex/skills/"$(basename "$s")"
done

# Plugin oficial. `claude plugin install` clona por SSH y falla sin clave de GitHub;
# esto lo fuerza a HTTPS solo para ese comando, sin tocar la config global de git.
claude plugin marketplace add remotion-dev/claude-code-plugin
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.https://github.com/.insteadOf" \
  GIT_CONFIG_VALUE_0="git@github.com:" claude plugin install remotion@remotion
```

---

## Trampas medidas (2026-09-11)

**rspack deja el bundle sin JS, y el error no lo menciona.** El scaffold oficial trae
`Config.setRspack(true)`. Con Remotion 4.0.523 + bun 1.3.11 en macOS arm64 eso produce un
bundle **sin `bundle.js`** —solo `index.html`, `favicon.ico` y `public/`— y el render muere
con `ENOENT … bundle.js` desde `getSourceMapFromLocalFile`, que suena a problema de source
maps. Pasa con y sin el override de Tailwind. `remotion.config.ts` lo deja apagado con la
nota. Para comprobar si ya se arregló: `bunx remotionb bundle --out-dir=/tmp/x` y mirar si
existe `/tmp/x/bundle.js`.

**El footage va a 60 fps y la composition a 30.** `OffthreadVideo` remapea solo, pero es la
razón por la que `<Video>` no vale aquí: `OffthreadVideo` muestrea el frame exacto al
renderizar. No lo cambies.

**`scripts/*.sh` están escritos para bash 3.2**, que es el que trae macOS. Sin `mapfile` y
sin expandir arrays vacíos bajo `set -u`: las dos cosas revientan ahí.

**El vídeo de `simctl io recordVideo` se lee con `-fflags +igndts`** (2026-10-13). Su H.264
trae DTS que no casan con los PTS, y ffmpeg 8.1 los usa: sin la opción, `-ss`, `fps` y
`select` caen hasta 4 s antes de su sitio y enseñan otra pantalla. ffprobe lee bien los PTS.
Y la marca de un XCUITest llega 0,4–2,3 s después de que el estado se vea: por eso
`anclar-marcas.py` busca el primer fotograma visible de cada estado.

---

## Deuda de la toma piloto

`ia-gasto-pizza-16s.mp4` entra al repo porque el sistema tenía que probarse con footage de
verdad. Le quedan **dos** cosas por arreglar en la siguiente toma:

1. **Tema Light.** El pack 2.1 es Liquid Glass oscuro. El marco de la pieza sí va oscuro,
   pero la pantalla no.
2. **Píldora roja de grabación** los 16 s. Tapada con `crop: { top: 0.05 }`, que se lleva
   la status bar entera. Es un parche: una toma sin píldora deja recuperar esos 5 %.

**Los datos de la pantalla son seed de demo**, confirmado por Jürgen el 2026-09-11. Aun así
el reflejo se queda: los chips de sugerencia de Yala IA se generan con las **categorías
reales de quien graba**, así que en cualquier toma futura hay que leerlos antes de dar la
grabación por buena.
