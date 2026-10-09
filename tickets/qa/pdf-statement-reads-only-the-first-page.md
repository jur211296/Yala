---
id: pdf-statement-reads-only-the-first-page
status: qa
priority: high
area: image, ai, gateway
created: 2026-10-07
updated: 2026-10-08
source: pregunta de Jürgen en la sesión gpt-4-1-nano-shuts-down-on-october-23 (2026-10-07)
---

# Un estado de cuenta en PDF solo se lee por su primera página, y si tiene contraseña no se lee

> **Grupo: para Jürgen** (alcance y coste por PDF). Pedido por Jürgen el 2026-10-07: «deberíamos abrir ticket para
> que la carga funcione bien».

## Qué le pasa al usuario

Sube su estado de cuenta en PDF (**+** › Registrar con imagen › Archivo, o soltándolo en el iPad):

- **Solo se leen los movimientos de la página 1.** Un extracto de tres páginas pierde los de la 2 y la 3, y nada avisa
  de que faltan.
- **Si el PDF tiene contraseña** (muchos bancos peruanos los mandan así), la app lo da por ilegible: no hay dónde
  pedírsela.

## Lo medido (2026-10-07, en este árbol)

- `ReceiptDropHandler.firstPageJPEG(pdfData:)` (`Yala/App/Commands/RootCommandsModifier.swift`) renderiza **solo**
  `document.page(at: 0)`, a 2×, como JPEG. Lo reusan el selector de Archivo (`ImageSelectionView`, `fileImporter` con
  `[.image, .pdf]`) y el soltar en el iPad.
- `guard … !document.isLocked`: un PDF con contraseña devuelve `nil` → «ilegible».
- Fue una decisión acotada del rediseño (`image-entry-end-to-end-redesign`, en `qa`): «imagen o PDF, su primera
  página». Este ticket es el siguiente paso.

## Qué hay que decidir y hacer

1. **Todas las páginas.** Cada página es una «foto» más del flujo multi-foto que ya existe (una llamada `photo.read`
   por página, con su progreso «Procesando… 2/5»). Hay que decidir:
   - **El tope de páginas.** Coste: con `gpt-6-luna` ≈ 0,0005 USD por página a resolución original (banco del
     2026-10-07). Cuota free: hoy una página = un uso de foto.
   - **Cómo se quitan los duplicados** entre páginas: el saldo arrastrado y los subtotales no son movimientos.
   - **Si una página sin movimientos** (portada, condiciones) cuenta como fallo o se ignora en silencio.
2. **Contraseña.** Si `isLocked`, pedirla con un campo seguro y `document.unlock(withPassword:)`. Nunca se guarda ni
   viaja: el PDF se desbloquea en el teléfono y solo sube la imagen de cada página.
3. **El banco.** Añadir a `gateway/bench/cases/` extractos ficticios de varias páginas, con saldo arrastrado, y medirlos
   antes de elegir modelo y resolución para esta entrada. Un extracto de 20 filas a 1536 px se lee bien; uno de 40,
   no medido.

## Hecho cuando

- Un PDF de N páginas (hasta el tope) produce los movimientos de todas, sin duplicar saldos ni subtotales.
- Un PDF con contraseña pide la contraseña y se lee. Si falla, dice «contraseña incorrecta», no «ilegible».
- XCUITest con un PDF de 3 páginas sembrado, y casos multipágina en el banco.

## Decisión de Jürgen (2026-10-07)

Opción 1B: se leen **hasta 10 páginas por PDF**, y **cada página cuenta como una foto** en la cuota gratuita.

A qué parte corresponde: este ticket no nombra sus opciones con letras. «1B» es el punto 1 de «Qué hay que decidir y hacer»
(todas las páginas), en concreto **el tope de páginas** (10) y **la cuota** (una página = un uso de foto, como hoy). Lo que
la decisión no dice y sigue abierto para quien lo implemente, con el criterio del propio ticket:

- Cómo se quitan los duplicados entre páginas (saldo arrastrado, subtotales).
- Si una página sin movimientos cuenta como fallo o se ignora.
- Qué pasa con un PDF de más de 10 páginas: que el usuario lo sepa (no leerlo en silencio).
- El punto 2 (contraseña) y el 3 (casos multipágina en el banco) no cambian.

## Resuelto (2026-10-08)

Decisiones de Jürgen del 2026-10-08 (lo que la 1B dejaba abierto), las cuatro con la recomendada:

1. **Cupo a mitad**: se lee lo que cabe; debajo de lo leído, «Ya usaste tus fotos de prueba: quedaron N sin leer» con
   «Ver Yala Pro» en vez de «Reintentar». Las páginas que quedan no se piden a la pasarela.
2. **Página sin movimientos** (portada, condiciones): se ignora sin aviso. Solo si ninguna página trae movimientos,
   el fallo «sin importes» de siempre. Sí gasta su foto del cupo (la pasarela cuenta por llamada).
3. **Más de 10 páginas**: se leen las 10 primeras y en lo leído sale «Quedaron N páginas sin leer: se leen hasta 10
   por vez. Para leerlas, súbelas en otro PDF.»
4. **Varios ficheros a la vez** (Archivo): 10 páginas por tanda sumando todos; lo que no entra, con el aviso del punto 3.

Lo que hace la app ahora:

- **Todas las páginas.** `PDFPageImport` pinta cada página a 2× y la mete en el flujo multi-foto de siempre, con su
  progreso «Página 2 de 3». Una página = una llamada a `photo.read` = un uso de foto: la cuota la cuenta **solo la
  pasarela** (`gateway/src/policy.ts`: free 5 fotos en total, Pro 50 al día y 15 por minuto), sin cambios ahí.
- **Contraseña.** Un PDF bloqueado abre la fase «Este PDF tiene contraseña» en la misma hoja: campo seguro, «Abrir» y
  «Cancelar». La contraseña vive en un `@State` y se borra al usarla o al cerrar; se desbloquea con
  `PDFDocument.unlock(withPassword:)` y solo sube la imagen de cada página. Si no abre: «Contraseña incorrecta», nunca
  «No pude abrir este archivo». Cancelar salta ese PDF y sigue con el resto de lo elegido.
- **Soltar en el iPad.** El PDF se guarda entero (`drop-<uuid>.pdf` en `PendingImages/`) y la hoja lo trocea; antes se
  guardaba solo la página 1 como JPEG. `pendingImageURLs()` reconoce `.pdf`, así que la recuperación del arranque y la
  purga del App Group también lo ven.
- **En la práctica guiada** el tope es 1 página, como su selector de una foto.
- **Texto que caducaba**: «No pude abrir este archivo» ya no dice «protegido con contraseña» (16 idiomas).

**Duplicados entre páginas: no hizo falta código.** Medido en el banco (`gateway/bench/results/2026-10-08-multipagina/`,
12 páginas ficticias con saldo arrastrado, subtotales, una tarjeta con todo en la misma columna, una página de
condiciones y otra de 40 filas): con la fila de producción (`gpt-6-luna`, 1536 px), **0 saldos o subtotales leídos como
movimiento en 66 lecturas**, las páginas sin movimientos vuelven vacías 10 de 10 y la de 40 filas sale entera. Una
regla en el prompt no tenía nada medible que mejorar, así que no se puso. Detrás queda la red de siempre,
`DraftDeduplicationService`, que junta dentro de la tanda dos borradores con mismo importe, día y nota parecida.
Coste del banco: 0,041 USD. **Modelo y resolución de `photo.read`: sin cambios.**

Tests: `YalaTests/PDFPageImportTests` (1, 3, 10 y 11 páginas; tope por tanda; contraseña buena, mala y saltada; páginas
vacías; cupo a mitad) y `ReceiptDropHandlerTests`; XCUITest `ReceiptDropUITests` con un PDF de 3 páginas sembrado
(`-uitest-receipt-drop pdf3|pdf3-locked`, `-uitest-image-result pages|pages-trial`). Con el código de antes, el de tres
páginas da 1 registro en vez de 3 y el bloqueado no pide contraseña (medido).

## Device-QA (Jürgen, iPhone)

Montaje: Yala de TestFlight o del build de `2.1` tras el merge, con Pro (o con el plan gratis para el paso 5). Hace falta
un PDF de 3 páginas o más (cualquier estado de cuenta) en la app Archivos, y otro protegido con contraseña.

1. **+** › Registrar con imagen › **Archivo** › elige el PDF de 3 páginas. Mientras lee, el paso dice «Página 1 de 3»,
   «Página 2 de 3»… Al acabar, salen los movimientos de **las tres** páginas, sin el saldo anterior ni subtotales.
2. Repite con el PDF protegido. Antes de leer sale «Este PDF tiene contraseña». Escribe una mal y toca **Abrir**: dice
   «Contraseña incorrecta». Escribe la buena: lee todas sus páginas.
3. En el paso 2, toca **Cancelar** en vez de escribirla: vuelve a elegir, sin error.
4. Si tienes un PDF de más de 10 páginas: lee 10 y, bajo lo leído, dice cuántas quedaron sin leer.
5. (Opcional, plan gratis con pocas fotos de prueba) Un PDF con más páginas que fotos que te quedan: se ve lo leído y
   debajo «Ya usaste tus fotos de prueba: quedaron N sin leer» con **Ver Yala Pro**.
6. (iPad) Arrastra el PDF desde Archivos sobre Yala: lo mismo que el paso 1 (y el 2, si tiene contraseña).

## Encontrado y no tocado

- **Una página que no escribe la divisa vuelve sin divisa** (banco, `stmt-us`: el «$» solo está en la página 1). Ese
  borrador no casa con ninguna cuenta y se elige a mano. Ticket `pdf-statement-pages-without-currency-pick-no-account`.
- **Una página densa (40 filas) tarda 11–15 s** en leerse, frente a 4–7 s de una normal; el SDK corta a 20 s. Hay margen;
  si algún extracto real lo pasa, sale como «sin leer» con Reintentar.
