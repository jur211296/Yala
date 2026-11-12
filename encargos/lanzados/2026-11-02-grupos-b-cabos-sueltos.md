---
esfuerzo: high
release: no
---
# Grupos B: cabos sueltos de las cards 2–8 (categoría por nombre, «por cobrar» fuera de Registros, receta que se pierde, editar la pata con receta, recarga suelta en Registros)

Cards: tablero-grupos-b-la-categoria-de-una-venta-viaja-10u2, tablero-grupos-b-lo-por-cobrar-fuera-de-registro-00xj, tablero-grupos-b-las-lineas-de-tu-parte-se-pierd-sbvw, tablero-grupos-b-editar-la-pata-que-lleva-la-rec-6u5f, tablero-grupos-b-la-entrada-de-una-recarga-de-tu-oibr

## Contexto
Salen de los PR #737 (puente), #739 (ventas por cobrar) y #740 (Partir en pantallas), rama 2.2. Diseño: `docs/disenos/grupos-tu-parte-en-lineas/README.md` («Versión final acordada») y `tickets/in-progress/grupos-tu-parte-en-lineas.md`. Tickets del repo: `tickets/backlog/group-split-lines-recipe-lost-on-payer-or-currency-change.md` y `tickets/backlog/group-split-line-entry-reads-as-a-loose-transfer-in-records.md`. Arranca después de grupos-b-cobros (cards 9–11): rebasa sobre 2.2 con ese PR dentro.

## Qué hacer
1. 10u2: la categoría de una venta viaja por NOMBRE; si una de ingreso y una de gasto se llaman igual, formulario y puente deben elegir la misma (sin tocar el servidor de Grupos).
2. 00xj: el detalle del registro, el widget «Últimos registros», la ficha de la cuenta «Grupos» y la pantalla de éxito dicen «por cobrar» / «venta» (16 idiomas).
3. sbvw: la receta sobrevive a un cambio de pagador o de divisa (recomendado: trasplantarla a la pata nueva en la misma pasada; si no cuadra, aviso de la Bandeja).
4. 6u5f: editar la pata con receta (editor y lote) abre «Partir» en vez de dejar que el puente pise el cambio (D8 del diseño).
5. oibr: la entrada de una recarga lleva la insignia del grupo en Registros y no queda sola con los grupos ocultos. No cambia cifras.

## Qué NO tocar
El servidor de Grupos. Las decisiones pendientes de Jürgen (aviso «no cuadra» sin «Partir», versión mínima): no las cambies.


## Card añadida (2-nov 07:00 Lima) · importante para 2.2
- `tablero ver tablero-registros-pagina-sigue-con-el-flotante-f-97gc` — Registros standalone idéntica a Registros dentro de Estadísticas, sin FAB nunca
  - Decisión de Jürgen (2-nov 06:54 Lima): la pantalla Registros propia (Más › Registros / pestaña) debe ser idéntica a Estadísticas › Registros y no mostrar nunca el FAB (ni fijo ni al bajar).
  - Medido en origin/2.2 (43285344a): Yala/App/Views/Records/RecordsStandaloneView.swift:269 monta FABStackView. Quitarlo y reutilizar la misma vista/cabecera que la subpestaña Registros de Estadísticas; capturas lado a lado como prueba.
  - Cierra sola al mergear.

## Hecha cuando
Unit + mutantes por card, XCUITest de las superficies de 00xj y 6u5f, capturas antes/después. Cards cierran solas. Termina con /cerrar-total.

## Decisión de Jürgen (2-nov) · pagos entre divisas en Grupos
- Card: `tablero ver tablero-grupos-b-una-venta-en-otra-divisa-no-se-ansc`
- «Cuando un pago en la moneda del grupo cubre una venta en otra divisa, se usa el tipo de cambio del día del pago y queda fijo, sin recalcular.» (opción A)
- Aplica a todo cálculo de «cobrado / por cobrar» que toques aquí: no recalcules con el tipo del día.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.
> Medido sobre `origin/2.2` en `1f5f93554` (#742 ya mergeado: se arranca encima, sin esperar).

**D1 · 10u2: con dos subcategorías homónimas, ¿cuál elige el gasto de grupo?** → Una sola regla para formulario, puente y
«Partir» (`GroupSubcategoryMatchLogic`): nombre exacto sin mayúsculas; entre homónimas, la de usuario antes que la de
sistema, la visible antes que la oculta (añadido tras la review), la de **gasto** antes que la de ingreso y, a igualdad, el menor `shortcutID`; el «contiene» de reserva sigue el
mismo orden. El formulario normaliza la elegida a la que leerá el puente (al elegir y al abrir una edición).
Por qué: lo único que viaja es el nombre (el servidor no se toca), el gasto es el tipo por defecto del formulario y en el
aparato de otro miembro una de ingreso no clasifica su parte. Alternativa descartada: preferir la de ingreso pagando tú;
convertiría en venta (sin dinero que sale) un gasto que la persona quería apuntar.
Consecuencia asumida: elegir «Otros» de ingreso con un «Otros» de gasto deja el gasto (pide cuenta). Se ve en el acto.

**D2 · 00xj: qué dice cada superficie.** → Detalle del registro: «Tipo: Ingreso • Por cobrar» (la misma regla que la
fila, `RecordRowPresentationLogic.categoryCaption`). Widget de inicio «Últimos registros»: importe en gris y «Por cobrar»
en el subtítulo, con un campo opcional `isReceivable: Bool?` en las dos copias del DTO (uno no opcional apagaría todos los
widgets). Ficha de la cuenta «Grupos»: «Por cobrar» en la línea de debajo y el importe en gris. Pantalla de éxito: «¡Venta
agregada!» / «¡Venta actualizada!». 16 idiomas (app y widget). Las patas de préstamo y las transferencias en el widget no
se tocan: no las pide la card.

**D3 · sbvw: cómo sobrevive la receta a un cambio de pagador.** → Se trasplanta en la misma pasada cuando la pata nueva
nace en ella: pagaste tú → pagó otro (con el puente activo) y pagó otro → pagaste tú con cuenta (la edición local). La
puerta de divisa mira la divisa de la pata de la que sale la receta. Las recargas se conservan (`keep`) en vez de borrarse
y recrearse. El cambio de divisa en el Caso B ya la llevaba (y la Bandeja avisa de que no cuadra).
**Residual con ticket nuevo:** cuando la pata nueva no nace en la pasada —el pagador pasa a ti desde otro aparato (sin
cuenta: borrador que la pide) y el cambio de divisa en el Caso A (borrador «la moneda cambió»)— la receta se pierde; esos
dos borradores ya están en la Bandeja y ofrecen «Partir» (card 5). Guardarla en el borrador pide un campo nuevo de
CloudKit y del Modo Nube.

**D4 · 6u5f: qué abre «Partir».** → En el editor, la pastilla de categoría de la pata que lleva la receta abre la hoja
«Tu parte» en vez del selector (solo con la receta activa: `GroupSplitLinesService.target(...).offersSplit`); cuenta y
etiquetas siguen como estaban (el puente no las pisa). Guardar «Tu parte» desde ahí cierra también el editor (tras la
review: guardar después con lo que cargó al abrir pisaba el importe de la pata y, con una recarga de ancla, su par). En el lote, «Categoría» se bloquea entero si alguno lleva la
receta, con un motivo que manda a «Partir tu parte» en su detalle; el menú contextual deja de ofrecer «Cambiar
categoría» para esa pata. Las patas derivadas siguen bloqueadas con «se edita desde el grupo».
Por qué: el puente solo pisa categoría de esa pata; un lote no puede abrir una hoja por registro.

**D5 · oibr: cómo sabe la entrada de una recarga de qué grupo es.** → Por su salida: el mismo `transferPairID` en la pata
de «Grupos», que lleva el puntero. El proveedor de nombres de grupo de Registros publica también zona por par, la fila
pinta la insignia, y con «Incluir movimientos de grupos» apagado la entrada se oculta con su salida. Sin cambio de
cifras ni de modelo (D4 del diseño se queda).

**D6 · 97gc: Registros (página).** → La misma fila de acciones bajo la cabecera que Estadísticas › Registros
(`StatsQuickActionsSlot`, con las mismas puertas: Pro, permiso de IA, lo que falta para registrar) y sin flotante nunca,
tampoco al bajar. Estadísticas › Registros no cambia.

**D7 · El tipo de cambio de los cobros entre divisas (ansc).** → No aplica: ninguna card de aquí calcula «cobrado / por
cobrar».

**D8 · Verificación.** → Unit y mutantes por card; XCUITest de 00xj (detalle y pantalla de éxito de una venta) y de 6u5f
(la pastilla abre «Tu parte»); review adversarial con lentes independientes en 10u2 y sbvw (tocan el puente). Capturas
antes/después de Registros (página), detalle, éxito, editor y fila de la recarga. El widget, con test del snapshot (su
captura pide la galería de widgets y queda fuera si el disco no da: 23 GB libres al empezar).

**D9 · Lo que la review adversarial cambió (dos lentes, 2-nov).** Arreglado: el editor se cierra al guardar «Tu parte»
(dos altos: importe y par de la recarga pisados); en el Caso A con trasplante la divisa ya no cierra la puerta (pagador y
divisa en la misma edición dejaban la receta sin aviso); las etiquetas y la necesidad de tu parte viajan con la receta;
una homónima oculta no gana a la visible. Residuales con ticket: el orden de llegada entre dos aparatos
(`group-split-lines-recipe-lost-when-the-new-leg-is-not-born-in-the-pass`), el lote y el menú que bloquean la categoría de
una pata con receta también con el puente apagado (mismo ticket), la entrada de una recarga que queda huérfana si tu parte
pasa a 0 (`group-share-to-zero-leaves-the-recharge-entry-orphaned`, previo al cambio) y la cápsula del grupo que falta en
Buscar y en el detalle de una celda del flujo de caja (`group-badge-missing-outside-records`, previo).
