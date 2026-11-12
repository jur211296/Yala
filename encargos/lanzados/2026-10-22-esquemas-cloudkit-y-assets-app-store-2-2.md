# Subir los esquemas de CloudKit nuevos al repo y rehacer la primera pieza de App Store 2.2 (iPhone y iPad) con el video de vista previa en tamaños de iPad

## Contexto
- Pedido de Jürgen vía Lola (22-oct 10:17). Yala 2.1 ya está publicada; todo el trabajo va a la rama 2.2.
- Lola exportó el 22-oct los esquemas de CloudKit a `~/Yala/Cloudkit Schemas/` (checkout de Jürgen, sin commitear): `yala-development.ckdb` y `yala-production.ckdb` ya traen `CD_parentAccountID` y `CD_amountChangesRaw`. En origin/2.2 esos archivos existen en `Cloudkit Schemas/` con la versión vieja. Jürgen pidió que se suban al repo con un PR a 2.2.
- La ficha de App Store vive en `ficha-app-store/` (generador de capturas: `capturas/`, `sets.js`, `textos/`, `render.sh`) y los encargos anteriores están en `encargos/lanzados/` (por ejemplo `2026-10-16-capturas-video-app-store-en-pt.md`, `2026-10-20-vista-previa-app-store-lanzamiento.md`, `2026-10-21-asc-version-final-2-1.md`). Léelos para reutilizar el flujo, no lo reinventes.
- Referencias de iPad de Jürgen (capturas reales): `~/Claude/tmp-frank/asc-2.2/ipad-busqueda.png` y `~/Claude/tmp-frank/asc-2.2/ipad-encabezado.png`.

## Qué se pide
1. **Esquemas de CloudKit:** copia `yala-development.ckdb` y `yala-production.ckdb` desde `~/Yala/Cloudkit Schemas/` a `Cloudkit Schemas/` de tu worktree (solo copiar y leer el origen; en `~/Yala` no se toca, descarta ni sobrescribe nada). Revisa el diff contra origin/2.2 (que aparezcan `CD_parentAccountID` y `CD_amountChangesRaw` y que no desaparezca ningún campo ni tipo de registro que exista hoy) y commitéalos. Si algo desaparece, no lo subas y dilo en el cierre.
2. **Primera pieza de App Store, sets iPhone y iPad:** rehacer la primera captura (la portada) con el texto más grande y los mockups llenando el cuadro. En el set de iPad, la pieza usa mockups de iPad (no de iPhone), tomando como referencia las capturas de Jürgen de arriba. Capturas reales del simulador, en los idiomas que ya tiene la ficha.
3. **Video de vista previa en tamaños de iPad:** exportar el video de vista previa actual en las medidas que App Store Connect acepta para iPad, sin cambiar su contenido.
4. Dejar todo listo para subir a la versión 2.2 de App Store Connect (no subir nada) y escribir en el cierre la ruta exacta de cada archivo, para que Lola lo suba.

## Alcance y forma de trabajar
- La rama sale de origin/2.2 y el PR va contra 2.2. Sin esperar el CI de ningún PR; `git fetch` y rebase sobre origin/2.2 solo justo antes de abrir el PR. Los binarios pesados (PNG finales y videos) van donde los dejaron los encargos anteriores de la ficha, no dentro del repo si ahí no se versionan.
- Nunca «OpenAI» en ningún texto.
- Pipeline serial en la Mini: limpiar (sims muertos, DerivedData y cachés de XcodeBuildMCP de worktrees cerrados) sin preguntar, build con `xcodebuild -jobs 2` sin sim booteado, bootear 1 sim, capturar, apagar y borrar ese sim. Nunca más de un simulador encendido. Disco de la Mini apretado: corre `limpiar-mac` antes de empezar. Al cerrar borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar.

## Qué NO hay que tocar
- Nada del checkout `~/Yala` de Jürgen (sus `.ckdb` sin commitear se quedan como están). El código de la app (solo seeds de marketing si hacen falta). La rama 1.0. App Store Connect (no subir nada). Otras sesiones tmux. El PR #588 y el #595.

## Cómo se sabe que está bien
- PR a 2.2 con los dos `.ckdb` nuevos y el diff revisado.
- Portada nueva en los sets iPhone e iPad con las medidas exactas que pide App Store Connect (verificadas con `sips`), texto más grande, mockups llenando el cuadro y de iPad en el set de iPad.
- Video de vista previa exportado en tamaños de iPad válidos para App Store Connect.
- Capturas de antes y después de la portada en `capturas/` (`antes.png`, `despues.png`, y las de iPad) para el digest.
- El resumen de cierre lista las rutas de todo y dice que Lola recibe una línea con ellas.

/cerrar-total

## Paso 0 — decisiones (Frank, 22-oct, autónomo)

- **Esquemas de CloudKit: no hay nada que subir.** Medido: los 8 `.ckdb` de `~/Yala/Cloudkit Schemas/` son idénticos
  byte a byte a los de origin/2.2, y `git status` de `~/Yala` no los da como cambiados. `CD_parentAccountID` y
  `CD_amountChangesRaw` ya están versionados (commits `968335ddb` y `d4c6b6ef2`). La premisa del encargo («en origin/2.2
  está la versión vieja») era de antes de esos commits.
- **«La primera pieza» es el recurso universal 16:9 (5244×2950, PNG sin alfa)**, el de las dos referencias de Jürgen:
  Apple lo usa a la vez de encabezado y de resultado de búsqueda. Sale de `assets-asc-2.1-2026-10-13`, donde todo cabía
  en la zona segura de 1402×962 y por eso los teléfonos se veían pequeños.
- **Dos variantes:** iPhone (dos iPhone 17 Pro) e iPad (dos iPad Pro 13"), las dos a 5244×2950. El texto y los equipos
  llenan el lienzo. Riesgo anotado: si Apple recorta el universal en el iPhone hacia la zona segura, se verá más justo;
  se entregan copias con la zona marcada en `_revision/` y Lola lo mira en la vista previa de ASC antes de enviar.
- **Idiomas: es, en y pt-BR**, los del molde de la ficha. Lema y bajada de los textos ya aprobados (cierre del set B en
  es/en; en pt-BR, el de `textos/pt-BR.js` si existe).
- **Pantallas recapturadas con la app de 2.2** con el molde (`conducir.sh <idioma> iphone|ipad ia/foto`), un simulador a
  la vez. La fuente de la composición va al repo en `ficha-app-store/portada/`; los PNG, fuera, en
  `~/Claude/propuestas/ficha-app-store-2.2/portada/`.
- **Vídeo de iPad:** la vista previa set B actual (`~/Claude/marketing/biblioteca/asc/vista-previa/`, es y en) se
  re-renderiza con la misma toma, frases y tiempos a **1200×1600 y 1600×1200** (los tamaños de iPad 13" que publica
  Apple; 11", 12,9" y 10,5" usan esos mismos o el escalado). Dos formatos nuevos en la plantilla `reel-setb.mjs`; los
  existentes no cambian (se comprueba que su `index.html` sale idéntico).

## Resultado

- **Esquemas de CloudKit:** sin commit. Los `.ckdb` de `~/Yala` ya estaban en origin/2.2, idénticos, con
  `CD_parentAccountID` y `CD_amountChangesRaw` (2 apariciones en `yala-development` y `yala-production`). No falta nada.
- **Portada (recurso universal 5244×2950, PNG sin alfa, `sips`):** sets iPhone e iPad en es, en y pt-BR, en
  `~/Claude/propuestas/ficha-app-store-2.2/<idioma>/portada/`; con la zona segura marcada en `_revision/`; hoja en
  `hoja-portada.jpg`. Pantallas recapturadas con la app de 2.2 (build Debug de esta rama), iPhone 17 Pro e iPad Pro 13"
  (M5), iOS 27.0, un simulador a la vez; los dos se borraron al acabar.
- **Vista previa de iPad:** `~/Claude/marketing/biblioteca/asc/vista-previa/<es|en>/yala-vista-previa-ipad-13-<vertical|horizontal>.mp4`,
  1200×1600 y 1600×1200, 29,13 s, 30 fps, H.264 High@4.0 a ~11 Mbps, AAC estéreo 48 kHz en silencio (ffprobe). Formatos
  `ipad` e `ipad-horizontal` en `reel-setb.mjs`; los `index.html` de los formatos viejos salen idénticos byte a byte.
- Nota para Lola: `~/Claude/propuestas/ficha-app-store-2.2/PARA-LOLA-portada-y-video-ipad.md`.
- **Encontrado:** en 2.2 la hoja «Esto leí» enseña el gasto con signo («S/ -251.81», «$ -105.31»); en 2.1 salía sin
  él. Sale así en la portada nueva. En inglés el Panel dice $84,548.54 frente a S/ 84,524.30 en español.
