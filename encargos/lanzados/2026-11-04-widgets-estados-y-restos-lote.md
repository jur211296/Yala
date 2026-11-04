# Widgets: estados con pocos datos + hoja huérfana de la Comparativa + borrador de Nuevo registro
toca: Yala/Widgets (WidgetKit), Estadísticas/Comparativa (hoja de ayuda), Nuevo registro (persistencia del borrador)

Rama base: 2.2. Un solo PR contra 2.2, un solo cierre.

Lote de tres cards del tablero de Yala:

1. «Widgets: mapear y diseñar los estados con pocos datos (Resumen del mes XL se ve con huecos)». Captura de Jürgen: ~/Claude/propuestas/widget-resumen-mes-xl-huecos-2026-11-04.png (está en la Mini; si estás en la Max, pídela con preguntar-bot o cópiala con scp mini). Mapear todos los widgets y todos sus tamaños en estos estados: sin datos, pocos datos (1 presupuesto, 1 o 2 categorías), sin un bloque (sin ingresos, sin presupuestos, sin categorías) y datos completos. Armar una matriz con capturas antes y después, en claro y oscuro, y ajustar los layouts para que nunca queden huecos ni desorden.
2. «Retirar la hoja de ayuda huérfana de la Comparativa»: es código muerto, quitarlo con sus tests y strings.
3. «Nuevo registro: conservar el borrador si iOS cierra Yala»: hoy el borrador vive solo en memoria. Persistirlo para que sobreviva a que iOS cierre la app, y probarlo.

Mueve las cards con `tablero` (ya funciona en la Max): en curso al empezar e in qa al cerrar, con guion de prueba para el iPhone.
Si algo bloquea o cambia el resultado, pregunta con `preguntar-bot`; no asumas.
El cierre trae la sección «Saltado o asumido sin preguntar».
Termina con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR. La D7 se preguntó al bot
> dueño (`preguntar-bot`, 16:2x) y se aplica lo que conteste.

**D1 · ¿Cómo se producen los estados con pocos datos para la matriz?** → Un generador (`qa/widget-render/estados.py`)
que deriva de la foto congelada `realista` seis fotos: completo, vacío, pocos (1 cuenta, 2 categorías, 1 presupuesto,
1 pago, 2 movimientos), sin ingresos, sin presupuestos y sin gastos (= «sin categorías»: el día 1 con el sueldo).
Por qué: el banco de `qa/widget-render/` ya pinta todos los widgets y tamaños con una foto; variar la foto es
reproducible. Alternativa descartada: sembrar cada estado en Yala Dev y exportar (seis siembras, no reproducible).

**D2 · ¿Qué cuenta como «hueco»?** → Un `Spacer` que reparte el alto sobrante entre bloques de contenido y deja franjas
vacías mayores que el aire entre secciones (`xxl`), o un bloque a media altura sin nada debajo. Se mide en las capturas
del banco, en claro y oscuro.

**D3 · ¿Cómo se rellena el alto en el extragrande vertical con pocos datos?** → Las secciones van arriba con aire fijo
y el bloque de categorías crece (aro más grande) con el alto que sobra; los presupuestos pueden mostrar más filas si
las hay. Nunca Spacers entre bloques. Por qué: es lo que se ve con huecos en la captura de Jürgen. Alternativa
descartada: dejar el hueco abajo (sigue siendo un hueco).

**D4 · ¿Qué se hace con un bloque sin datos (sin presupuestos, sin gastos)?** → Línea de estado vacío útil corta (ya
existen «Sin gastos» / «Sin presupuestos»), y el alto pasa a los bloques que sí tienen datos. No se ocultan los
bloques: el widget dice siempre lo mismo y en el mismo orden.

**D5 · Alcance de los widgets** → Todos los de la pantalla de inicio en todos sus tamaños (los de la pantalla bloqueada
se miran, pero son una línea y no tienen huecos que repartir). Solo se tocan los layouts que salgan con huecos; los
demás quedan en la matriz como «sin cambio».

**D6 · Hoja de la Comparativa** → Se retira el caso `periodComparison` de la hoja de ayuda con sus siete textos en los
16 idiomas. No hay tests propios que la nombren (medido). Se tacha su mención en el ticket de pt-BR.

**D7 · Borrador de Nuevo registro: cómo vuelve** → **Decidido por Jürgen (opción A, 2026-11-04 17:0x):** al volver a abrir Nuevo
registro, sale relleno con lo que tenía + una línea «Recuperamos lo que estabas escribiendo» y «Empezar de cero»;
caduca a las 24 h; solo registros nuevos (no la edición de uno guardado).

**D8 · Dónde se guarda el borrador** → `UserDefaults` de la app (no SwiftData ni la Bandeja), con ids de cuenta,
subcategoría y etiquetas como `PersistentIdentifier` codificado; si algo ya no existe al restaurar, ese campo se queda
vacío. Se escribe al pasar a segundo plano y se borra al guardar, al descartar y al cerrar sin cambios.

**D9 · Una lista corta (1-2 filas en un widget de 3 o 7)** → Las filas conservan el ritmo de la lista llena, arriba, y
lo que sobra queda debajo como fin de lista. Ni se estiran ni se reparten (eso era el «desorden»: la segunda fila
pegada al fondo). No se añade un pie con acción nueva: obligaría a copy nuevo en 16 idiomas que nadie pidió.

**D10 · Un bloque de gráfica sin datos** → Se pinta la forma vacía (el aro gris con «Sin gastos» dentro; la línea de
cero con «Sin datos suficientes») en vez de un texto suelto en medio de un hueco.

**D11 · Pagos planificados extragrande vertical** → Sin pagos, el calendario del mes se queda y la invitación a crear
el primero va debajo. Con la lista llena, «Te falta pagar este mes» sigue anclado al fondo; con menos pagos va justo después de la lista.

**D12 · Convivencia con el borrador en memoria que entró en la base a la vez** → La base trajo `NewRecordDraft` (otra
sesión): lo escrito sobrevive a que la hoja se rehaga con Yala viva, «solo en memoria». Lo de esta card es el cierre
por iOS, en disco con 24 h (decisión A). Conviven: el tipo de disco se llama `SavedNewRecordDraft`, la marca de quién
posee el borrador en disco vive en `NewRecordDraft` (sobrevive al rehecho) y se borra en su `discard()`, en el
`onDismiss` de la hoja. El comentario de `NewRecordDraft` se actualizó para no contradecir la decisión A.
