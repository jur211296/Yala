---
esfuerzo: high
release: no
---
# Dos formularios dejan de leer su modelo después de borrarlo, al cerrarse

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`.
Slug: `formularios-modelo-borrado` · Sesión cola **S31** · al cerrar → **S32** (`eliminar-cuenta-icloud-privado`).

## Contexto
Hallado al arreglar el crash de Bandeja (PR #687, mismo patrón): `GroupExpenseFormView` (el título del diálogo lee `expenseToEdit` tras borrarlo) y `NewTransactionView.deleteTransaction` borran su modelo y siguen presentados durante el cierre. En iOS 27.x leer un modelo borrado aborta; es riesgo, no crash visto. Ticket: `tickets/backlog/forms-read-their-deleted-model-while-closing.md`.

Cards:
- `tablero ver tablero-dos-formularios-se-leen-a-si-mismos-tras-1w89`

## Qué se pide
1. Lee cómo lo resolvió el PR #687 y aplica el mismo patrón (copia previa de lo que se muestra, o guarda `isDeleted`/`modelContext`) en los dos formularios.
2. Busca con grep si otro formulario borra su modelo y sigue presentado; arréglalo igual o anótalo en el PR.
3. Test que cubra borrar y cerrar cada formulario sin leer el modelo borrado. Mueve el ticket a hecho según la convención del repo.
Al abrir el PR, cards a «in qa» de Jürgen si hay algo que mirar en dispositivo, o a «done» si no (con `--agente` de la sesión).

Haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.

Pipeline serial de la Mini: limpiar, build con `xcodebuild -jobs 2` sin sim booteado, boot de 1 sim, tests, apagar y borrar el sim. Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen. No toques las de un worktree vivo.

## Qué NO hay que tocar
La lógica de Bandeja ya arreglada en #687. Nada de funcionalidad nueva. No lances otras sesiones Yala; ningún otro PR ni rama.

## Cómo se sabe que está bien
Lo de «Qué se pide» hecho, tests verdes, review adversarial del diff, PR a 2.2 con auto-merge y capturas antes/después en `capturas/` si el cambio se ve.

## Cierre autónomo
Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en la card y en el PR, y sigue. Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico): no lo hagas; crea una card `cierra-sola` asignada a jurgen con la decisión pendiente, termina el resto y cierra.
Al cerrar, Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

Termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

1. **Patrón por formulario.** Formulario de gasto de grupo: el único sitio del `body` que lee el gasto es el título del
   diálogo de borrado → **copia previa** del nombre al tocar la papelera (cero cambio visual). Editor de registro: el
   `body` lee el registro en 7 sitios y además su ViewModel lo lee en `amountCurrencyCode` (lo pinta el importe) →
   **accesor guardado** (`isDeleted || modelContext == nil`) para las lecturas del `body`, **copia previa** del texto de la
   alerta al abrirla, y **el ViewModel suelta el registro** tras borrarlo conservando la divisa que se enseñaba (como ya
   hace «Duplicar»). Descartado: vaciar el `body` entero si el modelo está borrado — la hoja bajaría en blanco (cambio
   visible) para tapar algo que se arregla en origen.
2. **El fallo de `save()` tras `delete()`** (rama `catch` de `deleteTransaction`) se queda como estaba: el ViewModel solo
   suelta el registro si el guardado fue bien, para no convertir «Guardar» en un alta duplicada.
3. **Otros formularios:** se revisan los candidatos del grep; los que tengan el mismo riesgo y el arreglo sea igual de
   acotado, se arreglan; el resto se anota en el PR.
4. **Tests:** el simulador 27.0 no aborta al leer un modelo borrado, así que el crash no se puede ver en XCUITest. Red:
   unit del mecanismo del ViewModel (con el mutante), source-scan del cableado (molde `DeletedModelRowGuardWiringTests`)
   y XCUITest que recorre borrar → confirmar → cerrar en el editor de registro (el de grupo ya existe en
   `GroupsSmokeUITests`).
5. **Cards:** el cambio no se ve; el riesgo solo se mide en iOS 27.x de un iPhone → la card va a «in qa» con guion corto.
   Sin capturas (no hay cambio visible).
