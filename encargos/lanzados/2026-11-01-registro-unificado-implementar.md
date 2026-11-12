---
esfuerzo: high
release: no
---
# Aplicar el registro unificado en Nuevo registro, la aprobación de la Bandeja y Nuevo gasto de Grupos

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `registro-unificado-implementar` · Sesión cola **S35k** · al cerrar → **S35g** (`grupo-detalle-tras-salir`).

## Contexto
En PR #719 (solo docs), `nuevo-gasto-grupos-propuestas` dejó tres propuestas, A, B y C, en `docs/disenos/registro-unificado-2-2/`. También dejó una card de decisión para Jürgen.

Jürgen (31-oct 16:46) pidió que el registro sea «muy parecido» en las tres pantallas. Hoy la aprobación pone todo en una fila, y la línea de moneda no usada parece un campo pendiente. En Grupos la moneda va en el signo del monto, pero cuenta y categoría deben verse iguales a Nuevo registro.

Cards:
- `tablero ver tablero-registro-unificado-aplicar-la-opcion-ele-3aqr` (esta implementación)
- `tablero ver tablero-registro-unificado-elige-a-b-o-c-para-nu-hq02` (decisión de Jürgen: A, ya en done)

## Qué se pide
1. **Opción A, decidida por Jürgen** (31-oct 19:03 Lima, «Va la A»): la aprobación copia a Nuevo registro (Cuenta + Línea en una fila, Categoría + Etiqueta en otra) y Grupos se adapta. No hace falta esperar otra respuesta.
2. Lee el README y las capturas de `docs/disenos/registro-unificado-2-2/` (PR #719).
3. Implementa en las tres pantallas:
   - Nuevo registro;
   - la aprobación de la Bandeja / Yala IA;
   - Nuevo gasto de Grupos (moneda en el signo del monto; cuenta y categoría con el mismo diseño).

      - **Igualar también (Jürgen, 31-oct 19:04):**
     - **Color del monto** igual en las tres: rosa para gasto y teal para ingreso, con los tokens semánticos del design system (es la recomendación de Frank; si Jürgen pide blanco, se cambia). Hoy Nuevo registro lo muestra rosa, la aprobación blanco y Grupos más oscuro.
     - **Chips bajo el monto:** el mismo componente, tamaño y posición en Nuevo registro y Bandeja (hoy el de la Bandeja es más chico).
     - **Descripción:** el mismo tamaño tipográfico y la misma posición en las tres.
     - **Fecha:** la misma posición y el mismo tamaño de selector y calendario en las tres.
     - **Grupos:** como no tiene segmented control, el selector de grupo va encima de la fecha, en ese espacio; la moneda sigue en el signo del monto.
     - **Principio:** que las tres pantallas sean muy parecidas, cada una con sus particularidades.
   - **Editor de favoritos y hojas de la Bandeja que completan un borrador de grupo:** Jürgen aún no respondió si entran. Por defecto, inclúyelos si comparten el mismo componente de selectores (si no, déjalos fuera), y anota en el digest y en el PR cuál aplicaste.

   Reutiliza componentes compartidos en vez de copiar código. Mantén las hojas de vidrio de PR #717.
4. Agrega tests unitarios y XCUITest de los selectores en las tres pantallas, incluida una cuenta de doble línea. Deja capturas antes y después de las tres pantallas (oscuro, claro y degradado) en `capturas/` y en el digest.
5. En el PR, deja escrito que se aplicó la opción A por decisión de Jürgen.

Si sale algo que no cabe aquí, crea cards en 2.2, «ready to launch», `cierra-sola`, asignadas a frank (nada a backlog). Lista sus títulos en el PR y en el cierre para que Frank las encole antes del barrido.

Al abrir el PR, pasa las cards a «in qa» de Jürgen (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
- La lógica de guardado, la sincronización y el servidor.
- marketing/ ni Web/.
- No lances otras sesiones Yala.
- Ningún otro PR ni rama.

## Cómo se sabe que está bien
- Las tres pantallas registran muy parecido según la opción usada.
- La línea de moneda ya no parece un campo pendiente en la aprobación.
- Los tests están verdes.
- Se hizo una review adversarial del diff.
- El PR va a 2.2 con auto-merge y capturas.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue.

Lo que de verdad necesite a Jürgen, no lo hagas: crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.

Al cerrar, Frank publica el digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0

Decisiones tomadas antes de escribir código (auto-contestadas: MODO AUTÓNOMO, cierra-sola).

1. **Opción A**, por decisión de Jürgen (31-oct 19:03 Lima, «Va la A»). Nuevo registro es la referencia.
2. **Color del monto**: un token nuevo, `Color.recordFormAmount(isIncome:)`: gasto `hotPink`, ingreso `incomeAmount`
   (turquesa adaptativo, ya medido AA). Lo usan las tres pantallas. Cambia el ingreso de Nuevo registro (era índigo)
   y la aprobación (era blanco en gasto). El «0.00» de ejemplo sigue gris. La transferencia no cambia.
   `TransactionType.color` no se toca: lo usan la pantalla de éxito y otros sitios.
3. **Chips bajo el monto** (categoría + necesidad): un componente compartido para Nuevo registro y la aprobación, con
   el aspecto de Nuevo registro (necesidad rellena). Grupos no los tiene y no los gana.
4. **Descripción**: `DS.Typography.title`, ancho 280, justo debajo de la fecha, en las tres.
5. **Fecha**: una pastilla compartida (`RecordPillButton`), primer elemento del bloque central, y la misma hoja
   `DatePickerSheet` en las tres.
6. **Grupos**: el selector de grupo va arriba, en el sitio del control segmentado, con la misma pastilla. Debajo, el
   bloque central con fecha, descripción y monto (moneda en el signo). El alto se reparte con el molde de Nuevo
   registro (`GeometryReader` + `minHeight` + `Spacer`s).
7. **Selectores de abajo**: un contenedor compartido (`RecordSelectorChips`) que fluye en filas como Nuevo registro y
   salta de fila antes de la categoría cuando la cuenta enseña sus líneas: Cuenta + Línea en una fila, Categoría +
   Etiqueta en otra. Sin líneas, fluye como hoy en Nuevo registro.
8. **Pastillas rellenas en todas**: `SelectionChip.fillsWhenSelected` pasa a `true` por defecto. La etiqueta puesta usa
   un componente compartido (`SelectedTagChip`) relleno con su color; la aprobación conserva su marca «Nueva».
9. **Grupos, cuenta**: sale de la tarjeta de «Pagado por» y pasa a pastilla junto a la subcategoría, encima de
   «Guardar». Conserva `group_expense_account_row`. La marca de «falta la cuenta» es la de las pastillas
   (`isMissing`, borde de acento): una sola marca en toda la app.
10. **Grupos, línea útil**: «Salen S/ 240.00 de tu cuenta y te deben S/ 160.00», solo cuando pagas tú (cuando se pide
    la cuenta) y el reparto cuadra. Si nadie te debe, «Salen S/ X de tu cuenta». Lógica pura con test. 16 idiomas.
11. **Editor de favoritos y hojas de la Bandeja que completan un borrador de grupo**: **entran**, porque comparten
    `SelectionChip`. Reciben las pastillas rellenas y el contenedor que fluye en filas (adiós al scroll lateral y a la
    fila fija). Nada más de esas pantallas cambia.
12. **Fixture**: `-uitest-seed-registro-unificado`, aditivo, siembra un borrador pendiente en la tarjeta «Visa QA»
    con la etiqueta «Trabajo», para capturas y XCUITest. Las capturas: temas 2 (oscuro), 1 (claro) y 8 (Liquid Glass,
    el degradado), como en PR #719.
13. Lo que no cabe aquí va a cards de 2.2, «ready to launch», `cierra-sola`, asignadas a frank.

### Ajustes tras la review adversarial (2026-11-01)

- La línea de Grupos usa tu parte **guardada** (`calculatedShares`, redondeada): con S/ 100 entre tres decía 66.67 y el
  puente apunta 66.66. No sale al editar (el puente no mueve el registro existente a otra cuenta: card
  `tablero-grupos-al-editar-un-gasto-que-pagaste-ca-8933`) ni sin participantes.
- `RecordSelectorChips` ajusta al ancho de la fila una pastilla más ancha que ella (trunca en vez de salirse) y centra
  las filas en las hojas de borrador de grupo.
- Grupos: con la cuenta como pastilla de abajo, si falta al tocar «Guardar» el formulario baja hasta ella; con el
  teclado puesto el contenido pierde el alto mínimo para poder desplazarse; el «0.00» es un ejemplo gris; el grupo de
  solo lectura va sin cápsula.
- El editor de favoritos pasa al molde del scroll con alto mínimo, como la aprobación.
- La hoja de fecha con atajos se queda fuera de Grupos (su nota enlaza a Pagos planificados).
- Card aparte: fr y de mezclan tú y usted en Grupos (`tablero-frances-y-aleman-nuevo-gasto-de-grupos-m-truj`).
