---
esfuerzo: medium
---
# Corregir dos regresiones de las capturas App Store 2.1 (cuenta en foto y voz, iPad 04 pt-BR) y volver a renderizar lo afectado


## Contexto
El PR #524 («Arreglos de Lola a las capturas y al vídeo App Store 2.1 (en y pt-BR)») aplicó las correcciones de la revisión de Lola del 16-oct al set de capturas y al vídeo de la ficha 2.1. Lola revisó el resultado: sus 7 correcciones están bien, pero aparecieron dos regresiones que frenan la subida a App Store Connect.
- Card del tablero: tablero-sesion-regresiones-en-las-capturas-app-s-ad19 («Sesión: regresiones en las capturas App Store 2.1 (cuenta en foto y voz, iPad 04 pt-BR)», 2.1).
- Recortes de Lola: ~/Claude/propuestas/ficha-app-store-2.1/_revision-lola-2/
  - en-6.9-02.png: la lámina 02 en inglés de 6,9" con el chip «Select account».
  - pt-BR-ipad-04-subtitle.png: el titular del iPad 04 pt-BR tapado.
- Entrega actual: ~/Claude/propuestas/ficha-app-store-2.1/ (en/, pt-BR/, es/ y README para Lola). El molde está en ficha-app-store/ del repo (PRs #521 y #524). Los textos de Lola están en ~/Claude/lola-borradores/2.1/textos-capturas/.
- Primero lee el diff y el cuerpo del PR #524: ahí está qué cambió en el seed («ficha», que pasó a 4 cuentas: efectivo, tarjeta y las demás) y en el molde.

## Qué se pide
1. **Láminas 02 y 03 (foto y voz)**, en en y pt-BR, en 6,9", 6,5" e iPad 13".
   - Qué pasa: la tarjeta de resultado muestra el chip naranja «Select account» / «Selecionar conta» con Save/Salvar deshabilitado. Antes salía «Main Account» con Guardar activo.
   - Causa probable: el seed nuevo tiene 4 cuentas y ninguna por defecto. Confírmala antes de arreglar.
   - Arreglo: que la demo de foto use Main Account y la de voz use Card (el texto dice «on my card»), o poner una cuenta por defecto en el seed de capturas. Elige lo más robusto SIN cambiar el comportamiento real de la app para los usuarios: el cambio va en el seed o en la demo de -uitest, no en la lógica de selección de cuenta de la app real. Cubre el arreglo con un test (de lógica o UITest) que falle con el seed de 4 cuentas sin cuenta elegida.
2. **iPad 04 pt-BR**: el titular baja a 3 líneas y la tarjeta «Transferência enviada» tapa parte de «o estabelecimento». Baja la tarjeta o achica el titular SOLO donde haga falta (iPad, pt-BR). En 6,9" y 6,5" está bien: no los toques.
3. Vuelve a tomar y renderizar 02 y 03 en los dos idiomas y los tres tamaños, y el iPad 04 pt-BR. Regenera las hojas de contacto afectadas.
4. Revisa que no haya más regresiones en el resto de láminas: compara cada una con la entrega de #524 y con las correcciones de Lola. Lista lo que miraste en el cierre.
5. Si cambia el seed, la demo o el molde del repo: PR a 2.1. Si solo cambian salidas fuera del repo, dilo en el cierre.
6. Deja la ruta final en la card de Lola «Subir a App Store Connect las capturas y la vista previa 2.1 en inglés y portugués» (id tablero-subir-a-app-store-connect-las-capturas-y-tv8t, proyecto Yala/marketing), con `tablero editar ... --agente frank`, conservando su nota. Ella revisa y sube.

## Cómo trabajar
- Base: origin/2.1 recién traído (con #524 dentro). Antes de cada PR, `git fetch origin && git rebase origin/2.1`. No esperes al CI para seguir.
- Si al arrancar #524 todavía no está en 2.1, espera a que entre y rebasa una sola vez con el simulador apagado. No partas de la rama de #524.
- Simuladores: runtime iOS 27.0, «iPhone 17 Pro» e «iPad Pro 11-inch (M5)», o los que use el pipeline de capturas de ficha-app-store/ (iPad Pro 13, iPhone 6,9"/6,5"). Los propios se crean sobre iOS 27.0 y se borran al cerrar. Nada de iPhone Duo ni del runtime iOS 27.1, que no está instalado y es de 2.2. Xcode 27.1 compila con el SDK 27.1.
- Pipeline serial con 1 simulador, como manda la norma de la Mini:
  1. limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen
  2. build con `xcodebuild -jobs 2` sin ningún simulador encendido
  3. encender 1 simulador
  4. tests y capturas
  5. apagar ese simulador y borrarle los datos
  Nunca dos simuladores a la vez: el iPhone y el iPad van uno detrás de otro.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados. No toques los de otra sesión viva.
- Disco apretado (~20 GB libres): antes de cada build o render, mira `df -h /System/Volumes/Data` y borra por fases lo tuyo.
- Pruébala tú misma todo lo que se pueda, con simulador, tests y capturas, según /barrido-qa. Solo lo que de verdad necesite un iPhone real pasa a «in qa» para jurgen, con un guion corto de 3 a 5 pasos. Lo demás va a «done» con evidencia.
- Capturas de antes y después en capturas/ del worktree (antes-*.png / despues-*.png), con las rutas listadas en el cierre.
- Cada ticket nuevo que añadas a docs/TICKETS.md lleva su card en el tablero: créala con `tablero crear --proyecto yala ... --agente frank`, o enlaza una que ya exista. Versión 2.1 si bloquea el lanzamiento o es de datos del usuario; 2.2 si no.

## Qué NO hay que tocar
- En el árbol principal ~/Yala hay cambios sin commitear en «Cloudkit Schemas/yala_dev-development.ckdb», «Cloudkit Schemas/yala_dev-production.ckdb» y Yala.xcodeproj/xcshareddata/xcschemes/Yala.xcscheme. No los toques, no los commitees y no los descartes.
- No entres en marketing/ salvo en los assets de capturas que ya tocaba la sesión de #524.
- Los textos de Lola: solo se leen. Si hiciera falta cambiar uno, propón el cambio en su archivo y dilo en el cierre.
- No cambies el comportamiento real de la app para los usuarios (selección de cuenta, cuenta por defecto fuera de -uitest).
- Nada se sube a App Store Connect ni a revisión: lo hace Lola.
- No toques sesiones tmux salud--*, sat-lab--* ni clinicas-dentales-bi--*.

## Cómo se sabe que está bien
- Las láminas 02 y 03 muestran la cuenta elegida (Main Account en foto, Card en voz, o la cuenta por defecto del seed) con Save/Salvar activo, en en y pt-BR, en 6,9", 6,5" e iPad 13".
- En el iPad 04 pt-BR, el titular y la tarjeta «Transferência enviada» no se solapan; 6,9" y 6,5" siguen iguales.
- Hojas de contacto regeneradas y sin más regresiones en el resto de láminas, con la lista de lo revisado en el cierre.
- PR a 2.1 si cambió el seed, la demo o el molde: rebasado y con los tests en verde en local.
- La ruta final está en la card de Lola, y la card tablero-sesion-regresiones-en-las-capturas-app-s-ad19 está en done con evidencia.
- Mini limpia al cerrar: simuladores propios apagados y borrados, solo «iPhone 17 Pro» e «iPad Pro 11-inch (M5)» apagados, DerivedData de la sesión borrado y worktree retirado si el PR ya entró.
- Al terminar, ciérrate sola con /cerrar-total. Solo para si hace falta una validación URGENTE de Jürgen.

## Paso 0

- **Causa medida (no inferida):** foto y voz eligen cuenta solo si hay UNA cuenta activa en la divisa del
  movimiento (`DraftBuilder.findAccount(byCurrency:)` y `VoiceRecordingView.findAccount`). El seed `ficha` de #524
  tiene tres en la divisa principal (principal, efectivo, tarjeta) ⇒ `nil` ⇒ chip «Select account» y Guardar apagado.
- **Dónde va el arreglo:** en los seams `-uitest-image-result` / `-uitest-voice-result` (solo DEBUG), no en el seed ni
  en la regla real: la app real hace bien en no adivinar entre tres cuentas. Lógica pura nueva
  `UITestDemoAccountLogic`: si hay una sola cuenta en la divisa, esa (lo de siempre); si hay varias, la foto toma la
  corriente y la voz la tarjeta de crédito («on my card»), y solo si hay exactamente una de ese tipo.
- **Test:** `UITestDemoAccountLogicTests` con el seed de la ficha adaptado a BRL: la regla real da `nil` (premisa) y
  la demo da Main Account / Credit Card.
- **iPad 04 pt-BR:** ajuste de composición en `capturas/sets.js → AJUSTES["pt-BR"]` solo para iPad; los textos no se tocan.
- **Asumido:** «Card» del encargo = la cuenta de tarjeta de crédito del seed («Credit Card» / «Cartão de crédito»).
- Ficheros: `Yala/App/Logic/UITestDemoAccountLogic.swift` (nuevo), `ImageSelectionView.swift`,
  `VoiceRecordingView.swift`, `YalaTests/UITestDemoAccountLogicTests.swift` (nuevo), `ficha-app-store/capturas/sets.js`,
  `qa/coverage-index.json`.
