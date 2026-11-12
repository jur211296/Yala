---
id: records-list-search-by-amount
status: done
priority: medium
area: "records, search"
updated: 2026-11-11
created: 2026-11-11
source: "decisión 14 de la discusión del artefacto 2.3 (docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md), card tablero-2-3-buscar-dentro-de-registros-tambien-p-e7ss"
---
# Registros: buscar dentro de la lista, también por importe

**Qué pasaba.** En Registros no había dónde buscar: había que salir a la pestaña Buscar, que pierde el período y los
filtros y no entiende importes («45.90» no encontraba nada). El único camino era «Nota contiene» dentro de Filtros, que
solo mira la nota y filtra también el Panel y Estadísticas.

**Decidido (9-nov, B1, sin texto que lo compare con Buscar).** Campo «Buscar en Registros» arriba de la lista, que asoma
al tirar hacia abajo; busca también por importe y respeta el período y los filtros.

**Hecho.**
- El campo vive dentro del scroll, encima de la cabecera, y asoma al tirar de la lista hacia abajo estando arriba (no el
  cajón de la barra del sistema: en una pestaña salta al volver, `GroupsSearchDrawerWiringTests`). Con VoiceOver está
  siempre a la vista. La X lo vacía y lo esconde.
- Busca en nota, categoría, subcategoría, cuenta, etiquetas e importe, sin mayúsculas ni tildes. Importe sin signo y en la
  moneda del registro: con decimales al céntimo («45,90»), sin ellos toda la parte entera («45» = 45,00–45,99).
- Es de Registros, no de la sesión: busca dentro del período y los filtros puestos y no toca el Panel ni Estadísticas.
  La cabecera suma lo encontrado. Sin resultados, el vacío de Buscar.
- Estadísticas › Registros (misma lista) no lleva el campo. La pestaña Buscar no cambia.

**Pruebas.** `RecordsListSearchTests` (regla y pantalla: importe, período, filtro de cuenta, etiqueta, vacío) y
`RecordsListSearchUITests` (tirar → campo → «45,90» → una fila → sin resultados → X), con el fixture
`-uitest-seed-records-search`.
