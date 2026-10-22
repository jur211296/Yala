---
id: dangling-ref-repair-is-lost-when-its-row-cannot-be-read
status: done
priority: very-high
area: "modo-nube, sync"
created: 2026-09-22
updated: 2026-09-23
source: "review adversarial de `apply-overwrites-a-pending-local-write-without-its-guards` (2026-09-22), lente de instancias gemelas"
---

# Si la app no puede leer un movimiento al final de la sincronización, pierde para siempre a qué categoría o cuenta apuntaba

## El problema, en lenguaje de usuario

A veces un movimiento baja de la nube antes que su categoría o su cuenta. La app lo guarda sin ella y apunta
aparte «esto va con tal categoría» para completarlo en cuanto llegue. Si al completarlo no consigue leer el
movimiento, **tira esa nota**: el movimiento se queda sin categoría (o sin cuenta) en este teléfono, los informes
y saldos salen mal, y nada lo repara solo.

## Por qué pasa (leído el 2026-09-22 en el árbol del PR del apply; no ejecutado)

Misma familia «un default optimista convierte una avería en un permiso». `apply-overwrites-…` la cerró en
`applyPage`; esto vive en el pase final `reresolveDanglingRefs`, que corre FUERA de `applyPage` y no tiene
ninguna lectura estricta delante.

1. **`EntityApplyMap.reresolveDangler` (`:809-906` aprox.)** — lee la fila origen con los `fetch*` tolerantes
   (`lenient` ⇒ `nil` si el fetch lanza). `nil` ⇒ `.rowGone` ⇒ `SyncApplyEngine.reresolveDanglingRefs` hace
   `context.delete(dangler)` y guarda. El dangler era el único sitio con el UUID destino (las refs singulares no
   tienen espejo CSV). Si falla la base entera, se borran TODOS a la vez. El lado del destino es seguro
   (`.targetMissing` conserva el dangler).
2. **`clearDangler` / `registerDangler` (`:752-791`)** — un fetch de `SyncDanglingRef` que lanza deja vivo un
   dangler viejo (luego pisa una ref buena al llegar su destino) o inserta un duplicado.
3. **`resolveRef` (`:720-748`)** — un fetch del destino que lanza pisa una ref local buena con `nil` y registra
   dangler. Se cura solo con el pase final… salvo que se combine con 1 o 2.
4. **`fetchTags`/`fetchAccounts`/`fetchSubcategories`** — un fallo vacía la M2M; el CSV la salva, riesgo bajo.

## Qué habría que decidir

- En el pase final, fila ilegible ⇒ conservar el dangler (tercer desenlace, no `.rowGone`). Probablemente
  `reresolveDangler` pasa a usar los `find*` y a devolver un `.unreadable` que no borra.
- En los appliers, ¿un destino ilegible debe tirar la página (como las búsquedas de fila) o basta con no pisar
  la ref? Tirar la página es lo coherente con `applyPage`; medir si algún applier corre fuera de él.

## Criterios de aceptación

- [x] Un dangler cuya fila no se puede leer sigue existiendo tras el pase final.
- [x] Un fallo de lectura de `SyncDanglingRef` no deja un dangler viejo ni un duplicado.
- [x] Un destino ilegible no pisa una ref local buena con `nil`.
- [x] Tests con el fetch lanzando + control positivo (seam `EntityApplyMap._testThrowOnFetchOf`).

## Relacionado

- `apply-overwrites-a-pending-local-write-without-its-guards` — el mismo patrón dentro de `applyPage`, cerrado.

## Resolución (2026-09-23)

**Para el usuario:** si el teléfono no consigue leer un movimiento (o la categoría, la cuenta o las etiquetas a las
que apunta) mientras sincroniza, ya no pierde a qué apuntaba ni lo deja vacío: espera y lo completa en la siguiente
sincronización, cuando la lectura vuelve.

**Decisión (Paso 0 del encargo, medida antes):** en los appliers, **tirar la página**, no «basta con no pisar la
ref». Los appliers solo corren dentro de `applyPage` y `drainQuarantineOnce`, los dos con rollback, así que es la
misma salida que #216; «no pisar» a secas avanzaba el cursor con el valor del wire sin aplicar ni apuntar.

- **Pase final**: `DanglerOutcome.unreadable` (lecturas `find*` de fila y destino) conserva el dangler; los demás del
  pase siguen, y se reintenta cada ciclo. Breadcrumb propio `danglersUnreadable(count:)`, no `pageFailed`.
- **Appliers**: `ColumnApplier.apply` es `throws`; `resolveRef`, `clearDangler`/`registerDangler` (`findDangler`) y las
  lecturas M2M (`findTags`/`findAccounts`/`findSubcategories`, punto 4) lanzan.
- **Premisa corregida**: `registerDangler` NO insertaba un duplicado con el fetch lanzando (el `catch` se saltaba el
  insert); perdía la nota nueva o dejaba la vieja con el destino viejo. El duplicado sería el mutante de un `nil`
  tolerante, y está muerto.

**Verificación:** tests con el seam y control positivo en `SyncApplyEngineTests` (pase final: fila y destino ilegibles,
uno ilegible entre dos legibles, las 18 ramas una a una con scan de la zona; registro: alta, reapuntado, NULL y
resolución en caliente; destino: ref buena intacta y los 25 appliers que leen, uno a uno, con scan),
`CloudSyncWiredEntitiesTests` (tags, cuentas y subcategorías de un presupuesto) y `SyncQuarantineDrainTests` (un
applier que lanza en el drenaje). Mutantes y gate: en el PR.

**Review adversarial (3 lentes):** sin defectos altos ni medios en lo cambiado. Entró: el breadcrumb propio, la
cobertura de las 18 ramas y los 25 appliers, el drenaje de cuarentena y los controles positivos que escriben. A ticket:
`dangling-ref-pass-overwrites-a-pending-local-edit`, `post-pull-reconcilers-read-an-unreadable-table-as-nothing-to-repair`,
`a-malformed-ref-leaves-a-stale-dangler`, y una nota en `a-local-read-failure-in-the-migration-apply-reads-as-network`.

**Intercambio aceptado** (el mismo de #216): una tabla que NUNCA se deja leer deja el pull en `.transient` con backoff
(tope 300 s) en vez de avanzar degradado. Antes, con los tags, el CSV salvaba casi todo; ahora esa página espera.
