# Arreglos de Lola a las capturas y al video App Store 2.1 (en y pt-BR)

## Contexto
Lo pidió Jürgen el 16-oct a las 06:48. Lola revisó la entrega del PR #521 (~/Claude/propuestas/ficha-app-store-2.1/) y mandó correcciones. Esta sesión las HACE. No se pide ningún OK a Jürgen: la ruta final va a Lola, que revisa y sube a App Store Connect.
Card del tablero: tablero-sesion-dejar-listos-assets-y-capturas-ap-krdd («Sesión: arreglos de Lola a las capturas y video App Store 2.1 (en y pt-BR)», 2.1).

## Qué se pide (nota completa de la card)
Objetivo: HACER los arreglos de la revisión de Lola del 16-oct 06:40 al set de capturas y video App Store 2.1 en en (en-US/en-GB) y pt-BR, y dejar la ruta final a Lola para que revise y suba. Nada se sube a ASC: eso lo hace Lola.

Contexto y rutas:
- Entrega actual (PR #521, dirección B aplicada): ~/Claude/propuestas/ficha-app-store-2.1/ (en/, pt-BR/, es/, README para Lola). Videos ligeros en ~/Claude/entregas/2026-10-16-capturas-video-app-store-en-pt/. Molde ficha-app-store/ en el repo (PR #521).
- Textos de Lola: ~/Claude/lola-borradores/2.1/textos-capturas/ (es.js, en.js, pt-BR.js con TXT/OBJ/VIDEO + LEEME.md). Si un arreglo es de texto, se propone el cambio en su archivo y se avisa en el cierre; si es de maquetación, se hace en el molde.
- Semillas: en = «Lisbon trip» con Ana y Ben, 120/180/190 USD, cuenta «Travel EUR» €1,850.00; pt-BR = «Viagem ao Rio» con Ana y Beto, R$ 240/360/380,00, cuenta «Viagem USD» US$ 3.615,00 (cifras exactas en OBJ). Semilla de la app: «ficha».
- Recortes de cada problema (14): ~/Claude/propuestas/ficha-app-store-2.1/_revision-lola/crops/

Qué hacer:
0. La lámina 01 pt-BR final ya está bien. El error solo está en pt-BR/hoja-iphone.jpg (generada a las 02:00:38, antes del re-render de 01 y 06): regenerar esa hoja y generar también las hojas de 6,5".

Obligatorias:
1. Lámina 08 en en y pt-BR, todos los dispositivos: el titular y los chips dicen Cash/Card/Savings (Dinheiro/Cartão/Poupança), pero la sección de cuentas sale colapsada y el seed solo tiene 2 cuentas. Agregar cuentas de efectivo y tarjeta al seed y capturar con la sección expandida. En el iPad 08 el chip Cash/Dinheiro tapa el saldo: moverlo.
2. iPad 09 pt-BR: en la tarjeta flotante, «US$ 3.615,00» choca con «Poupança · USD · Saldo».
3. Grupos pt-BR (lámina 06 y video): el total dice «Te devem R$ 380,00», pero las filas dicen «Te emprestaram». Corregir el string de la app para que sea coherente. Es un cambio en la app: ticket en docs/TICKETS.md y card (2.2 si no es importante para el lanzamiento), o enlazar una existente.
4. Video en: «Pizza with friends 280» → 28. En pt-BR, revisar que el monto sea creíble en reales.
5. Lámina 04 pt-BR: cambiar Pix por el genérico «Registre suas transferências com um print» y el comprobante por «Transferência enviada» (guía 5.2, igual que se quitó Yape).
6. Lámina 07 pt-BR: «R$ 470 sobram em Comer fora, para 19 dias» → «R$ 470 para Comer fora nos próximos 19 dias».

Opcionales, si entran:
- en-US con fechas de EE. UU. («Oct 13», «Thursday, October 15, 2026») y montos sin espacio («$45.00»).
- Etiquetas del gráfico: «apr 26» pisa «oct 26», y la pastilla Today/Hoje tapa 100K.
- iPad 10: la fecha del pago no cuadra con la barra de estado, y en pt-BR falta «de» en «15 de outubro».
- En 07: «Friends' Outings». En 10: «Electricity».
- Pestaña «Distribuição» cortada en la 05 pt-BR.
- «Tributos aprox. (incl.)» ocupa 2 líneas en el recibo 02 pt-BR.

Después:
- Re-renderizar las capturas y los videos afectados (con y sin música), regenerar las hojas de contacto y verificar «50+» en todo.
- Los cambios de strings o seed de la app van por PR a 2.1: fetch y rebase sobre origin/2.1 antes del PR, pruebas en simulador con pipeline serial de 1 simulador (build sin sim → 1 sim → capturas/tests → apagar y borrar), DerivedData de la sesión borrado al cerrar.
- Dejar la ruta final en la card de Lola «Subir a App Store Connect las capturas y la vista previa 2.1 en inglés y portugués» (Yala/marketing) para que ella revise y suba.

Al cerrar: esta card a done con evidencia (PR, rutas, hojas de contacto). Solo si algo necesita iPhone real, in qa para jurgen con un guion corto.

## Toolchain
- Xcode 27.1 (27A9275, en /Applications/Xcode.app, el único instalado): se compila con el SDK iOS 27.1. Decisión de Jürgen del 16-oct: la release de 2.1 se compila con 27.1.
- Simuladores: el runtime iOS 27.1 (24A94425) que trae Xcode 27.1 SOLO admite el iPhone Duo. Un iPhone 17 Pro o un iPad no se pueden crear sobre él («Incompatible device»; Apple lo hace así y se confirmó en la Mini). Por eso los simuladores de stock se recrearon el 16-oct sobre el runtime iOS 27.0 (24A434):
  - «iPhone 17 Pro»: 386CA5C3-9CA1-4FBB-B780-606135DE7C2A
  - «iPad Pro 11-inch (M5)»: D15331E0-DEA7-45EB-9B6F-09DA0279DD41
  Los UDID 46287CFE / FE5FC26C que salen en encargos y tickets viejos ya no existen. Los destinos se eligen con `OS=27.0`, o por nombre y UDID.
- Si creas el iPad Pro 13 o un iPhone 6,9"/6,5" para las capturas, créalo sobre iOS 27.0 y bórralo al cerrar. El iPhone Duo NO va en esta sesión: es de 2.2.
- Si algún script del repo apunta a un runtime o a una versión que ya no cuadra, corrígelo en el PR. Revisado de antemano:
  - los scripts eligen el simulador por nombre;
  - las menciones a «iOS 27.0» del código son comentarios de medición y no se tocan;
  - qa/scripts/ci-simulador-test.sh tiene fixtures de runtime 26.4/26.5/27.0, que solo se cambian si un test lo pide;
  - ficha-app-store/comun.sh tiene un comentario medido en iOS 27.0 sobre la fecha del iPad, que afecta al opcional «iPad 10: la fecha del pago no cuadra con la barra de estado».
- DISCO APRETADO: unos 15 GB libres al lanzar. Antes de cada build o render, mira `df -h /System/Volumes/Data`. Borra en cuanto acabes cada fase el DerivedData de la sesión, los simuladores propios y los renders intermedios. No tengas más de un simulador propio a la vez. Si baja de 8 GB, para los renders y dilo en el cierre. No borres runtimes ni nada fuera de tu sesión.

## Ticket relacionado que puede entrar
ficha-mx-vida-rates-jump-on-the-last-day (card «Con la semilla ficha-mx-vida el saldo cae de golpe el último día», 2.2, baja): con la semilla ficha-mx-vida la curva del Saldo cae de golpe el último día, porque al arrancar se pide la tasa real de hoy y sustituye la sembrada. Arreglo posible: que la semilla ancle la serie a la tasa real de hoy, o que en -uitest no se pida la tasa del día. Si afea alguna captura que esta sesión re-renderiza y el arreglo es pequeño, inclúyelo en el PR y mueve esa card a versión 2.1 (done con evidencia). Si no afecta, déjala como está.

## Cómo trabajar
- Pipeline serial con 1 simulador, como manda la norma de la Mini (16 GB):
  1. limpiar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen
  2. build con `xcodebuild -jobs 2` sin ningún simulador encendido
  3. encender 1 simulador
  4. tests y capturas
  5. apagar ese simulador y borrarle los datos
  No compiles con un simulador encendido ni corras tests mientras compila. El iPhone y el iPad van uno detrás de otro, nunca a la vez.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees retirados. No toques los de otra sesión viva.
- Gate después del CI del PR anterior: la sesión arranca ya, sobre origin/2.1. El PR #523 (saldo y flujo de caja) puede seguir en auto-merge. Justo antes del gate, mira si sigue en CI: si sigue, espera a que entre y rebasa una sola vez con el simulador apagado. Si 2.1 no se movió, sigue de frente. Si ese CI falla, no esperes: rebasa con lo que haya y sigue. El build y el simulador van después de ese rebase, una sola vez.
- Pruébala tú misma todo lo que se pueda, con simulador, tests y capturas, según /barrido-qa. Solo lo que de verdad necesite un iPhone real pasa a «in qa» para jurgen, con un guion corto de 3 a 5 pasos. Lo demás va a «done» con evidencia: rutas, hojas de contacto, PR.
- Cada ticket nuevo que añadas a docs/TICKETS.md lleva su card en el tablero (incluido el de «Te emprestaram»): créala con `tablero crear --proyecto yala ... --agente frank`, o enlaza una que ya exista. Versión 2.1 si es de borrados, sync o datos del usuario, o si bloquea el lanzamiento; 2.2 si no es importante para el lanzamiento.
- Antes de cada PR: `git fetch origin && git rebase origin/2.1`. No esperes al CI para seguir.

## Qué NO hay que tocar
- En el árbol principal ~/Yala hay cambios sin commitear en «Cloudkit Schemas/yala_dev-development.ckdb», «Cloudkit Schemas/yala_dev-production.ckdb» y Yala.xcodeproj/xcshareddata/xcschemes/Yala.xcscheme. No los toques, no los commitees y no los descartes.
- Nada se sube a App Store Connect ni a revisión: eso lo hace Lola.
- Los textos de Lola en ~/Claude/lola-borradores/2.1/textos-capturas/: si un arreglo es de texto, propón el cambio en su archivo y dilo en el cierre.
- No toques sesiones tmux salud--*, sat-lab--* ni clinicas-dentales-bi--*.

## Cómo se sabe que está bien
- Las 6 correcciones obligatorias están hechas, y las opcionales que entraron, listadas.
- La hoja pt-BR/hoja-iphone.jpg está regenerada, y las hojas de 6,5" generadas.
- Capturas y videos afectados re-renderizados (con y sin música), con «50+» verificado.
- PR a 2.1 para los cambios de strings y seed, rebasado y con los tests en verde en local.
- La ruta final está en la card de Lola «Subir a App Store Connect las capturas y la vista previa 2.1 en inglés y portugués».
- Esta card en done con evidencia.
- Al terminar, ciérrate sola con /cerrar-total: simulador apagado y borrado, DerivedData de la sesión borrado y worktree retirado si el PR ya entró. Solo para si hace falta una validación URGENTE de Jürgen.

## Paso 0 (Frank, 16-oct, auto-contestado)

- **08 · cuentas**: la semilla `ficha` suma dos cuentas en la divisa principal, «Cash/Dinheiro» (efectivo, saldo
  positivo) y «Credit Card/Cartão de Crédito» (tarjeta con deuda, «a pagar»), con su saldo inicial en la fecha del de
  la cuenta principal: la curva del Saldo se desplaza entera, sin salto. Nombres = `account.type.*` ya traducidos (sin
  strings nuevas). El carrusel las pone primero (`-accountsSortOrderNames` en `lanzar.sh`, leído del `.strings`), y
  `conducir.sh panel` despliega «Tus finanzas» antes de capturar. `divisas` busca la tarjeta de la cuenta extranjera
  por su nombre, no por índice.
- **Chips del iPad 08 y tarjeta del iPad 09 pt-BR**: composición en `sets.js` (posición/ancho), no textos.
- **«Te emprestaram»**: `groups.expense.youOwe` pt-BR → «Você deve» (espejo de «You owe»), y su pareja
  `youAreOwed` «Emprestou» → «Você emprestou» (espejo de «You lent») para que la fila no cambie de sujeto. Ticket nuevo
  en `tickets/done/` + card 2.1 done: entra en este PR, que va a 2.1.
- **Pizza**: el importe de la respuesta fingida sale de la divisa (`DevSeedFicha.Cifras.pizza`): USD 28, BRL 90
  (la parte de una pizzería con amigos en São Paulo), el resto 280 (es-MX y es sin cambios).
- **04 y 07 pt-BR**: cambio de texto en el fichero de Lola (`lola-borradores/.../pt-BR.js`) y en su copia del molde.
- **Hojas 6,5"**: `hojas.py <idioma> iphone65` → `hoja-iphone-6.5.jpg`.
- **Opcionales** que entran si son composición o seed: «Tributos aprox. (incl.)» en una línea (ajuste de la boleta).
  Lo que es formato de la app (fechas y `$ 45.00` en en-US, etiquetas del eje, «de» en la fecha pt-BR, pestaña cortada)
  se mide y, si no es trivial, va a ticket 2.2.
- **ficha-mx-vida**: entra solo si la caída del último día se ve en las capturas en/pt-BR que se re-renderizan.
