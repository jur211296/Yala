Yala
# Nuevo registro: quitar las categorías sugeridas debajo del monto
---
toca: Yala/App/Views/Transactions/NewTransactionView.swift,YalaTests/NuevoRegistroSinSugerencias/,YalaUITests/NuevoRegistroSinSugerencias/,tickets/done/2026-11-17-nuevo-registro-sin-sugerencias-categoria.md
esfuerzo: medium
cierre: cierra-sola
---

Arreglo de UI que pidió Jürgen el 17-nov (18:04 Lima), con captura suya del iPhone. Base 2.3, un PR. Sesión enfocada solo en esta vista (Jürgen: no mezclar vistas en una sesión).

## 1. Quitar las categorías sugeridas debajo del monto en Nuevo registro
- En `NewTransactionView.swift`, las tres píldoras de categoría sugerida y el «Más…» que salen debajo del monto (en la captura: «Supermercados y bodegas», «Suscripciones de utilidad», «Comisiones y cargos», «Más…») se quitan. Jürgen: ocupan demasiado espacio y se ven mal; prefirió quitarlas.
- Elegir categoría sigue funcionando por su vía normal (la fila o chip de categoría ya existente, con el sugerido automático si existía en esa fila). Si la lógica de sugerencia solo alimentaba esas píldoras, la dejas sin usar o la quitas si es trivial; anótalo.
- Comprueba que el formulario no salta de alto ni deja un hueco, en iPhone SE y con letra grande.

## Cómo entregar
- Compila y pasa los tests afectados. Capturas antes y después de: Nuevo registro (iPhone 17 y SE, también con letra grande).
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después lado a lado.
- Commits y PR sin firma de IA. Toca solo lo declarado; lo menor, con la opción recomendada, anotado en «Decidido sin consultar». Textos nuevos, si hiciera falta alguno, en una tabla propia (`NuevoRegistroSinSugerencias.strings`), nunca en `Localizable.strings`.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto).
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Qué se quita.** La fila `CategoryQuickPickRow` bajo el importe (decisión 21 de 2.3, C2) deja de pintarse en Nuevo registro: se borra su bloque y `showsQuickCategoryRow` en `NewTransactionView.swift`. El chip «Categoría» y la hoja con buscador («café» → Restaurantes, C3) se quedan igual.
2. **La lógica que la alimentaba** (`CategoryQuickPickRow`, `NewTransactionViewModel.quickPickSubcategories`, `CategoryQuickPickLogic`) se queda **sin usar, sin borrar**: vive en ficheros fuera de `toca:` y borrarla no cambia nada para el usuario. Queda anotado para una limpieza aparte.
3. **El test que fijaba la fila** (`YalaUITests/Flows/CategoryQuickPick23UITests.swift`) se pondría rojo. Sus dos casos dependían de la fila: se borra el fichero y el caso del buscador («café» → Restaurantes) pasa al test nuevo, entrando por el chip. Toca un fichero fuera de `toca:`, a la fuerza: dejarlo rojo no es opción. Igual con `qa/coverage-index.json`, que el contrato QA obliga a actualizar.
4. **SE:** en iOS 27.2 sí existe el iPhone SE (3.ª gen.) de simulador; se crea uno y se usa en lugar del 17 Pro (Mini: un simulador a la vez).
5. **Letra grande = AX3** (`AccessibilityXL`), el mismo tamaño de la revisión 2.3.
6. **Textos nuevos:** ninguno, así que no hace falta `NuevoRegistroSinSugerencias.strings`.
