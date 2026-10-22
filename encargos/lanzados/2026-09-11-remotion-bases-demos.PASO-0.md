# Paso 0 — árbol de decisiones resuelto

Encargo: `2026-09-11-remotion-bases-demos`. Sesión: worktree `encargo/2026-09-11-remotion-bases-demos`,
agente **lola**, base `origin/2.1`. Auto-contestado (nadie delante), viaja al cuerpo del PR.

---

## D1 · Gestor: bun, no npm

`bun 1.3.11` está en la Mac y `bun create video` es la vía que pide el encargo. El scaffold deja
`bun.lock` y los scripts usan `remotionb` (el binario bun de Remotion, que el propio scaffold pone).
**Los `scripts/*.sh` usan `bunx remotion` con caída a `npx remotion`** para que la Mini pueda renderizar
sin bun si algún día hace falta.

## D2 · Wizard no interactivo

`bun create video --yes --blank remotion` sí es no interactivo (flags `--yes` + `--blank`). No hizo falta
el scaffold a mano. **Tailwind entra por defecto** (`@remotion/tailwind-v4` ya cableado en
`remotion.config.ts`), que es lo que pedía el encargo.

## D3 · Tailwind sí, pero la marca vive en `tokens.ts`

Tailwind queda instalado y habilitado, **pero ningún color de marca se escribe como clase**. Los
componentes leen `yala.color.*` de `src/brand/tokens.ts`.
**Por qué:** si el índigo vive en dos sitios, en tres meses hay dos índigos. Tailwind sirve para
maquetar rápido; la marca tiene una sola fuente.

## D4 · fps: footage a 60, composition a 30

El mp4 real es **60 fps, 16.183 s, 1170×2532** (medido con `ffprobe`, no heredado del brief).
`tokens.motion.fps = 30` manda, `OffthreadVideo` remapea solo. 16.183 s × 30 = 485.5 → **486 frames**
de cuerpo + **30 frames** de end card = **516 frames** (17.2 s) la pieza 9:16.

## D5 · El footage NO se centra a pantalla completa: se encaja sobre las safe areas de Reels

Medido sobre frames extraídos con `ffmpeg`, no supuesto:

| Momento | Dónde cae en la pantalla del iPhone |
|---|---|
| Chips de sugerencia (0–1.4 s) | 30 %–53 % de alto |
| Card de confirmación (5.8–8.0 s) | 27 %–73 % ← **el plano estrella** |
| Fila de éxito «Pizza · PEN 20.00 · Registrado» (11.3–13.9 s) | 32 %–40 % |
| Banda vacía en el momento de éxito | 52 %–80 % ← **ahí va el callout** |
| Barra de escritura (1.4–3.7 s) | 82 %–89 % |

Con eso, el marco 9:16 queda: **device 700×1439 en x=190, y=170**. La barra de escritura cae en
y≈1337–1442 del lienzo, **por encima de los 1520 px donde Instagram tapa con el caption**. Si el device
fuera a sangre, el tipeo —que es medio relato— quedaría debajo de la UI de Reels.

`SafeAreas.tsx` es una **guía de Studio**, no un recorte: dibuja las bandas de Reels en punteado y está
apagada en render (`showSafeAreas`, default `false`).

## D6 · El status bar se recorta: la píldora roja de ReplayKit

El footage lleva **la píldora roja de grabación visible los 16 s**. No es publicable así.
`DeviceFrame` acepta `cropTop`/`cropBottom` (fracción del origen) y el piloto usa **`cropTop: 0.05`**,
que se lleva el status bar entero sin tocar la cabecera «Yala IA» (empieza en 6.5 %).
**Es un parche, no la solución**: la toma limpia va anotada en `OPERACION.md`.

## D7 · Tipografía: Inter, y se dice que es un sustituto

La referencia es SF Pro Rounded y **no se puede empaquetar**. Se usa **Inter** vía
`@remotion/google-fonts/Inter`, que es lo que dicen los tokens del encargo. Anotado en `SHOT-CONTRACT.md`
para que nadie lo lea como «así se ve Yala».

## D8 · Las skills de terceros NO se vendorizan en el repo

Instaladas en `~/.claude/skills/` (reales) y espejadas en `~/.codex/skills/` (symlinks). **Nada de
`marketing/.claude/skills/`.**
**Por qué:** son dependencias externas que se actualizan solas y meterlas al git de Yala son miles de
ficheros de terceros que nadie va a revisar en un PR. El comando de reinstalación queda en `OPERACION.md`,
que es lo que hace falta en una Mac nueva.

## D9 · El mp4 del piloto sí se commitea; los .MOV crudos no

2.3 MB. Por debajo del umbral donde LFS aporta algo. El `.gitignore` bloquea `*.mov/*.MOV`,
`public/footage/raw/` y `out/`, y **dice el umbral en una línea** (≥ 25 MB → LFS o fuera del repo) en vez
de dejarlo al criterio del día.

## D10 · Cierra con PR, no con commit directo a `2.1`

`CLAUDE.md` de Yala permite commit directo a `2.1` cuando el diff cae entero en `marketing/` — **y este
cae entero ahí**. Pero el encargo dice literal «NO push a 2.1 sin que Mini lo pida; cierra con PR», y
ADR-008 dice que un worktree cierra con PR. **Gana la instrucción explícita del encargo.**

## D11 · El marco va oscuro aunque el footage sea claro

`theme: "dark" | "light"` controla **el marco** (fondo, glow, glass), nunca el footage. El piloto va
`dark`: es el look 2.1 congelado, y una pantalla clara sobre `#060612` destaca más que sobre un marco
claro. El bisel lleva un borde tenue para que la pantalla clara no flote.

## D12 · Explainer: instalado, reservado, sin renderizar

`anything2explainer` queda instalado y el slug **`explainer-que-es-yala-ia` reservado en `copy.ts` con
`composition: null`**. Sin composition y sin render en esta sesión, como pide el encargo. Sin ElevenLabs.

---

## Lo que NO decidí yo, y va a Jürgen

**El footage del piloto enseña datos que parecen reales.** En los chips de sugerencia se lee
«¿Qué porcentaje del presupuesto de **Maia** 🐕 he usado en cuidado personal?», y la lista final trae
saldo **PEN 8175.00**, «Cuidado personal», «Uber», «Supermercado», una fila marcada «Compartido».

No sé si es data sembrada de demo o la cuenta real de Jürgen, y **no es mío decidirlo**: la regla de la
casa es que no se publican capturas con datos reales de nadie. El scaffold queda listo y el piloto
renderiza, pero **antes de que esto salga a Instagram hace falta un sí explícito** sobre esos tres
elementos, o una toma nueva con seed de demo.
