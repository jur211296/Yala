---
id: pdf-statement-reads-only-the-first-page
status: backlog
priority: high
area: image, ai, gateway
created: 2026-10-07
updated: 2026-10-07
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
