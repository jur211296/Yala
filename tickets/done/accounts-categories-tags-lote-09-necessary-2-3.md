---
id: accounts-categories-tags-lote-09-necessary-2-3
status: done
priority: medium
area: "ajustes, cuentas, categorias, etiquetas, divisas"
created: 2026-11-10
updated: 2026-11-10
source: lote 09 de la consolidación de mejoras necesarias 2.3 (docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md, zona 39), card tablero-mejoras-necesarias-2-3-cuentas-categoria-u8nd
---
# Cuentas, categorías, etiquetas y divisas: lo que aparece sin pedirlo

Cuatro defectos de la revisión de la zona 39 (`docs/ux/revision-vistas-2.3/39-cuentas-categorias/`). Los cuatro seguían
vivos en `origin/2.3` el 2026-11-10 y `git log origin/2.3..origin/2.2` no traía nada sobre sus vistas. No se eligió
ninguna alternativa de rediseño (F2 de monedas, G1 de «Usar al registrar», archivar, número de cuenta).

1. **Moneda › Tipo de cambio sin secundarias** enseñaba «1 USD» y «1 MXN»: las dos primeras del catálogo, que nadie
   eligió (`prefix(2)`). Ahora no enseña ninguna fila, solo «Ver todas» (`ExchangeRatesSectionLogic`). Seguir solas
   las monedas de las cuentas (F2) queda para Jürgen.
2. **Ajustes › Cuentas** escribía el saldo con el código («PEN 212.00») y el Panel y el formulario con el símbolo. La
   lista sigue ahora la preferencia «código / símbolo» de Personalización (por defecto, «S/ 212.00»).
3. **El «+» de Categorías** inserta la categoría vacía antes de escribir nada, y guardar su primera subcategoría guarda el
   contexto entero. **Reproducido** con un XCUITest: crear, guardar la subcategoría, cerrar la app y volver → una fila
   sin nombre en Categorías. Arreglo: `NewCategoryDraftMark` arma una marca en este teléfono al pulsar «+», guardar o
   descartar la retiran, y si sigue puesta al abrir Categorías o al arrancar (detrás de `awaitPersonalStoreReady`), el
   borrador sin nombre se borra con sus subcategorías. Lo que tenga registros, presupuestos o líneas del flujo de caja se
   queda.
4. **Formulario de etiqueta** (G3 de la zona 39, sin «Activa» en singular, que tiene su ticket
   [[single-item-active-toggle-uses-the-plural-filter-label]]): la X pregunta «¿Descartar cambios?» si hay cambios, y el
   gesto de cerrar también; el nombre avisa al acercarse a 20 («17 de 20») y al llegar («20 de 20: el resto no cabe»);
   el color se nombra («Seleccionado: Amarillo») y VoiceOver lo lee igual («Color Amarillo»). Un color propio es
   «Color propio». 18 textos nuevos en los 16 idiomas.

Tests: `CuentasCategoriasNecesariasLote09UITests` (un caso por punto, los cuatro rojos en la base y verdes con el
arreglo, con capturas) y `CuentasCategoriasNecesariasLote09Tests` (la lógica y el cableado de la marca del punto 3).

Nada pide la mano de Jürgen: el cierre a mitad del punto 3 lo hace el XCUITest (`terminate` + relanzar sin reset) y los
nombres de VoiceOver los lee el árbol de accesibilidad.
