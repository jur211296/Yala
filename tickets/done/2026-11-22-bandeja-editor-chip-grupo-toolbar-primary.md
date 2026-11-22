---
id: 2026-11-22-bandeja-editor-chip-grupo-toolbar-primary
status: done
priority: medium
area: "inbox, design-system"
created: 2026-11-22
updated: 2026-11-22
source: "pedidos de Jürgen del 22-nov-2026 (decisiones t1875u y t1876u)"
---

# Editor de la Bandeja con chip de grupo y recurrente en el menú; texto de los botones de la barra en primary

## Qué se pidió

1. En «Editar gasto» de la Bandeja, quitar los dos enlaces de debajo de «Dejar para después» y «Guardar»:
   «Guardar y hacer recurrente» al menú «…» y «Convertir a gasto compartido» como chip de grupo en la fila de chips.
2. El texto de los botones de texto de la barra en primary (no índigo), en toda la app, con una red que lo fije.

## Qué se hizo

- **Chip de grupo** (`InboxDraftEditSheet`, `InboxDraftGroupChipLogic`): un menú con los grupos donde se puede apuntar el
  gasto y «Sin grupo» cuando ya hay uno. Elegido, el chip dice el nombre del grupo y «Guardar» sigue el flujo de
  convertir de siempre con ese grupo (form de gasto de grupo prellenado); solo pide el monto. Sale donde salía el enlace,
  sin esperar al monto. Sin grupo, si «Grupo» no cabe, solo el ícono; con grupo, el nombre encoge junto a la cuenta.
- **«Guardar y hacer recurrente»** en el menú «…», apagado si falta algo y oculto con un grupo elegido.
- **`YalaToolbarTextButton`** (junto a `YalaToolbarButton`): botón de texto de barra con tinte primary. Migrados los 37
  botones de texto de barra de la app (Editar, Cancelar, Listo, Aplicar, Borrar filtros, Seleccionar todo…), más
  «Seleccionar» de Registros con texto. Los de solo ícono no cambian.
- Pruebas: `YalaTests/BandejaChipGrupoToolbar/` (lógica, cableado, textos en 16 idiomas y el source-scan de la barra,
  que cae con un `Button` de texto crudo dentro de un `ToolbarItem`, medido con mutante). XCUITest de conversión y del
  recurrente migrados al chip y al menú. Regla en `.claude/rules/swiftui-ds.md`.

## Quedó fuera

- Nuevo registro al editar conserva «Convertir a gasto compartido» bajo las acciones (con sus estados apagados y la
  explicación); el recurrente ya estaba en «···». Las aprobaciones de gasto de grupo no tienen ninguno de los dos enlaces.
- «Dejar para después» con un grupo elegido guarda lo editado, no el grupo: el borrador sigue como gasto personal.
- iPad: mismo componente, sin captura (la Mini no tiene simulador de iPad).
