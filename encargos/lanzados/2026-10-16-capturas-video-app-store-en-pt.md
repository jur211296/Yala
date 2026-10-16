# Capturas y video de App Store de la 2.1 en inglés (en-US/en-GB) y portugués (pt-BR), con un molde multilenguaje

## Contexto
Lo pidió Jürgen a través de Lola el 15-oct a las 18:14. Es obligatorio antes del lanzamiento de 2.1. Card del tablero: tablero-capturas-y-video-de-app-store-en-ingles-605d (proyecto yala, versión 2.1).
Objetivo: el set B de capturas (iPhone 6.9 y 6.5, iPad 13) y la vista previa (video) de la 2.1 en en-US y pt-BR. Todo tiene que quedar parametrizado por idioma, para que en 2.2 se puedan sumar de/fr/it/ja solo con un archivo de textos y una corrida. El set en es (inglés) sirve para en-US y en-GB.

Material que ya existe (fuera del repo):
- Capturas actuales en español: ~/Claude/propuestas/capturas-app-store-final-v2-2026-10-13/
  - _fuente/lamina.html, sets.js, lamina.css, render.sh, hojas.py
  - capturas crudas capturas/s-*.png (iPhone) e i-*.png (iPad); salidas 6.9/, 6.5/, ipad-13/, hojas de contacto hoja-iphone.jpg y hoja-ipad.jpg
  - scripts de captura en _trabajo/: lanzar.sh, cap.sh, lanzar-ipad.sh, cap-ipad.sh
  - el README todavía hace cd a v1: corrígelo
- Video: ~/Claude/propuestas/assets-asc-2.1-2026-10-13/_fuente/preview/. render.sh llama a tomas.py, que tiene los cortes fijos en español, y luego a HyperFrames (index.html, hyperframes.json) y a ffmpeg. La música es pop.mp3.
- Textos de Lola, listos desde el 15-oct 18:22: ~/Claude/lola-borradores/2.1/textos-capturas/ (es.js, en.js, pt-BR.js con TXT/OBJ/VIDEO y un LEEME.md). Se cargan con window.YALA_TEXTOS[lang] o con require. Los textos los escribe Lola: ya están adaptados, sin Yape/Plin, sin soles ni dólares y sin Cusco. No los reescribas. Si falta un texto, déjalo marcado y dilo en el cierre.

## Qué se pide
1. Semillas idénticas a los textos de Lola. Las cifras exactas están en OBJ:
   - en: grupo «Lisbon trip» con Ana y Ben, gastos de 120/180/190 USD, cuenta «Travel EUR» con €1,850.00.
   - pt-BR: grupo «Viagem ao Rio» con Ana y Beto, R$ 240/360/380,00, cuenta «Viagem USD» con US$ 3.615,00.
2. El recibo y el comprobante de lamina.html se leen de OBJ (cada monto trae su símbolo). Nada de «S/ » fijo.
3. La clave interna sigue siendo «yape», pero ningún texto visible lo menciona. pt-BR usa Pix. Si App Review objeta, la alternativa es «Registre suas transferências com um print».
4. En esta misma sesión, corrige el pt-BR de la app:
   - acentos: Orçamentos, Estatísticas, Poupança
   - formas de Portugal que se colaron en pt-BR: Devem-te, Podes
   - la bienvenida dice «48+ monedas» y la ficha dice «más de 50»: alinéalas con la ficha
5. Swift: pasa a L10n los textos demo que hoy están fijos en español (DevSeedGroups.swift, VoiceRecordingView.swift:662/669, ImageSelectionView.swift:1285, DemoIAPizzaUITests). La moneda del seed depende del idioma (USD en en, BRL en pt-BR) en vez de PEN fijo.
6. Molde: render.sh, sets.js, los scripts de captura, index.html y tomas.py reciben el idioma como parámetro. Hay un archivo de textos por idioma (es, en, pt-BR) y cortes de video por idioma.
7. Crea un simulador iPad Pro 13 y recaptura las 20 pantallas en en (en_US, USD) y pt-BR (pt_BR, BRL), con tema oscuro y una semilla realista.
8. Regraba las tres tomas de video (IA, foto, voz) por idioma; si se puede, con una toma real de Grupos. Mide los cortes y renderiza con música y sin música.
9. Entregables:
   - carpetas en/ y pt-BR/ con sus hojas de contacto
   - videos en y pt-BR
   - un PR a 2.1 con el Swift y el molde
   La subida a App Store Connect la hace Lola. Nada se manda a revisión.

## Cómo trabajar
- Pipeline serial con 1 simulador, como manda la norma de la Mini (16 GB):
  1. limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen
  2. build con `xcodebuild -jobs 2` sin ningún simulador encendido
  3. encender 1 simulador
  4. tests y capturas
  5. apagar ese simulador y borrarle los datos
  No compiles con un simulador encendido ni corras tests mientras compila. El iPhone y el iPad van uno detrás de otro, nunca a la vez.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados. No toques los de otra sesión viva.
- Gate después del CI del PR anterior: la sesión arranca ya, sobre origin/2.1. El PR #520 (movimientos sin cuenta) puede seguir en auto-merge. Justo antes del gate, mira si sigue en CI: si sigue, espera a que entre y rebasa una sola vez con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
- Pruébala tú misma todo lo que se pueda, con simulador, tests y capturas, según /barrido-qa. Solo lo que de verdad necesite un iPhone real pasa a «in qa» para jurgen, con un guion corto de 3 a 5 pasos. Lo demás va a «done» con evidencia: rutas de capturas, hojas de contacto y videos.
- Cada ticket nuevo que añadas a docs/TICKETS.md lleva su card en el tablero: créala con `tablero crear --proyecto yala ... --agente frank`, o enlaza una que ya exista. Versión 2.1 si es de borrados, sync o datos del usuario, o si bloquea el lanzamiento; 2.2 si no es importante para el lanzamiento.
- Antes de cada PR: `git fetch origin && git rebase origin/2.1`. No esperes al CI para seguir.
- Deja las capturas de antes y después en _capturas/ con las rutas listadas en el resumen.

## Qué NO hay que tocar
- En el árbol principal ~/Yala hay cambios sin commitear en «Cloudkit Schemas/yala_dev-development.ckdb», «Cloudkit Schemas/yala_dev-production.ckdb» y Yala.xcodeproj/xcshareddata/xcschemes/Yala.xcscheme. No los toques, no los commitees y no los descartes.
- Los textos de Lola: solo se leen. Las correcciones de pt-BR del punto 4 son en los Localizable de la app.
- Nada se sube a App Store Connect ni a revisión.
- No toques sesiones tmux salud--* ni sat-lab--*.

## Cómo se sabe que está bien
- Están las carpetas en/ y pt-BR/ con las 20 pantallas por idioma (iPhone 6.9, iPhone 6.5 e iPad 13) y sus hojas de contacto. En ninguna pantalla hay español, soles, Yape ni Cusco, y las cifras coinciden con OBJ.
- Están los videos en y pt-BR, con música y sin música, con cortes medidos por idioma.
- El molde corre con un solo parámetro de idioma, y sumar un idioma es solo un archivo de textos más una corrida.
- El pt-BR de la app está corregido y la bienvenida dice lo mismo que la ficha.
- Hay un PR a 2.1 con el Swift y el molde, con tests en verde en local y rebasado sobre origin/2.1.
- Cards del tablero al día: esta card en done (o en «in qa» solo por lo que necesite iPhone real), y los tickets nuevos con su card.
- Al terminar, ciérrate sola con /cerrar-total: simulador apagado y borrado, DerivedData de la sesión borrado y worktree retirado si el PR ya entró. Solo para si hace falta una validación URGENTE de Jürgen.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, 16-oct de madrugada): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Entra Frank en capturas de la App Store?** → Sí: el encargo se lo asigna (Jürgen vía Lola). Levanto ese default de mi ficha sin tocar `marketing/`: el molde va en `ficha-app-store/` (raíz del repo) y las salidas, fuera del repo.
Por qué: compilar, sembrar y conducir el simulador es de Frank, y el PR lo pide. Alternativa descartada: meter el molde en `marketing/` (territorio de Lola, que no lo ha pedido ahí).

**D2 · ¿Cómo cuadran las cifras que dependen del día (S/ 4,686 del mes, 470 y 74 %, «19 días», «en 2 días», «en 5 días»)?** → Reloj desplazado al 13-oct-2026 09:41 solo para la app del simulador: un dylib (`ficha-app-store/reloj/`) que se inyecta con `SIMCTL_CHILD_DYLD_INSERT_LIBRARIES`. No toca código de la app.
Por qué: medido con la app del 15-oct, la semilla `realista` con el reloj en el 13-oct da exactamente 1,330 de 1,800, 74 % y «19 días restantes», como el set en español; así el molde da las mismas cifras se corra el día que se corra. Alternativas descartadas: anclar solo la semilla (los «19 días» y los «en N días» seguirían el reloj real) y un hook DEBUG de reloj en la app (toca producción por marketing).

**D3 · ¿Qué semilla?** → Perfil nuevo `ficha`: la vida personal de `realista` + los grupos de la ficha, en la divisa preferida de la app (`-defaultCurrencyCode`, que el molde fija por idioma: en→USD, pt-BR→BRL, es→PEN). Lo que cambia por divisa (factor del grupo, cuenta en divisa extranjera y su saldo, Teléfono y Spotify) vive en una tabla DEBUG; los nombres, en L10n. `realista`, `grupos` y `ficha-mx*` no cambian.
Por qué: los XCUITest usan esos perfiles en español; cambiarles la divisa cambiaría el sujeto de tests verdes. Alternativa descartada: que `realista` siga al idioma.

**D4 · Cifras por idioma (de OBJ de Lola).** → en: «Lisbon trip» (USD; Ana y Ben; Groceries 120, Seafood dinner 180, te deben 190) más los gastos de la parte en EUR (es Lisboa); «Travel EUR» €1,850.00; Phone $65.00 y Spotify $11.99. pt-BR: «Viagem ao Rio» todo en BRL (×2: 240, 360, te devem 380), sin segunda divisa; «Viagem USD» US$ 3.615,00; Telefone R$ 59,90 y Spotify R$ 21,90. es: igual que hoy (Cusco, 33,615, S/ 60 y S/ 18). La cuenta extranjera reescala su historia para clavar el saldo.
Por qué: el encargo pide las cifras de OBJ; en Río no se paga en dólares y en Lisboa sí en euros. Alternativa descartada: inventar cifras nuevas.

**D5 · Textos demo a L10n.** → Chat de `-uitest-chat-draft` (frase y notas) y sugerencias, transcripción y notas de voz, comercio y total del recibo de foto, grupos de la ficha. Claves nuevas en las 16 variantes, con el valor de hoy en español (los XCUITest en español no cambian). El total del recibo va como cadena por idioma (251.81 / 105.31 / 332.20) para casar con la boleta de cada idioma. `DemoIAPizzaUITests` toma el idioma de `TEST_RUNNER_YALA_DEMO_IDIOMA` (por defecto, es-MX como hoy).
Por qué: es lo que se ve en las capturas y en el vídeo. Alternativa descartada: una tabla Swift por idioma para los textos.

**D6 · ¿Cuánto pt-BR se corrige?** → Todas las instancias de los dos patrones que nombra el encargo: acentos que faltan y formas de Portugal (`tens`, `podes`, `Devem-te`, `registar`, `Definições`…), en `pt-BR.lproj`. Se excluyen las claves de categorías y subcategorías, porque se guardan por nombre y cambiarlas duplicaría las de quien ya las tiene. «48+» → «50+» en los 16 idiomas: es la misma frase de bienvenida y la ficha dice «más de 50».
Por qué: corregir tres palabras dejaría el mismo fallo en el resto de pantallas (se midieron ~174 cadenas sin acentos y ~180 en pt-PT). Alternativa descartada: solo los ejemplos citados.

**D7 · Molde.** → `ficha-app-store/` con `textos/` (copia literal de los tres ficheros de Lola), `capturas/`, `video/` (cortes en `video/cortes/<idioma>.json`), `reloj/` e `idiomas.json` (idioma → `AppleLanguages`, `AppleLocale`, divisa). Todo recibe un solo parámetro de idioma. Salidas en `~/Claude/propuestas/ficha-app-store-2.1/<idioma>/`.
Por qué: sumar de/fr/it/ja es un fichero de textos, una línea en `idiomas.json` (y la fila de su divisa en la tabla de la semilla) y una corrida.

**D8 · Simuladores.** → iPhone 17 Pro existente para el iPhone; un iPad Pro 13" (M5) nuevo para el iPad. Uno detrás de otro; cada uno se apaga y se borra al acabar.

**D9 · Vídeo.** → Las cuatro escenas (IA, foto, voz y Grupos, esta vez con toma real) se graban por idioma con `simctl io recordVideo`; los cortes se miden fotograma a fotograma y se guardan por idioma. La foto del recibo que se «lee» es la boleta de OBJ, renderizada por idioma y metida en Fotos.

**D10 · Entrega.** → PR a 2.1 con el Swift y el molde, en cola de auto-merge (sesión en bypass = modo cola). Nada a App Store Connect.

### Decisiones tomadas por el camino

**D11 · pt-PT hereda las faltas de acento del pt-BR viejo** (su bloque de respaldo es copia de pt-BR) → se le aplican solo las 241 correcciones que son únicamente de acento; no se regenera el bloque desde el pt-BR nuevo. Por qué: los acentos valen igual en Portugal, el «você» no. Lo demás, a ticket (`pt-pt-needs-a-native-review-after-the-pt-br-sweep`).

**D12 · La barra de estado del iPad** → solo la hora (9:41) y la fecha real en el idioma del sistema del simulador, que el molde pone al de la ficha. Por qué: una fecha ISO en `simctl status_bar` la escribe siempre en inglés y, tras relanzar, con el día de la semana de hoy («Fri Oct 13»). La fecha real bien escrita es mejor que la del reloj mal escrita.

**D13 · El Panel al relanzar** → el molde fija el Panel de usuario nuevo por argumentos de arranque. Por qué: sin `-uitest-reset`, la app a veces enseñaba todas las secciones (3 de 5 en inglés). No se toca la app; queda ticket `uitest-relaunch-without-reset-can-lose-the-new-user-panel`.

**D14 · Cuenta extranjera y total** → los ingresos freelance pasan a la principal con su valor, y cada transferencia y el saldo inicial compensan en la principal lo que cambia la extranjera. Por qué: con la cuenta extranjera pequeña, «Tus finanzas» salía en negativo y con la tendencia bajando; así el total de cada día es el de la ficha en soles.

**D15 · Nota demo pt-BR «Mercado»** (no «Compras do mercado») → la tarjeta de la captura 01 cortaba el texto.
