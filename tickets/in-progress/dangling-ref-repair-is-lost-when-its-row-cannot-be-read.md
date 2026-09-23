---
id: dangling-ref-repair-is-lost-when-its-row-cannot-be-read
status: in-progress
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

- [ ] Un dangler cuya fila no se puede leer sigue existiendo tras el pase final.
- [ ] Un fallo de lectura de `SyncDanglingRef` no deja un dangler viejo ni un duplicado.
- [ ] Un destino ilegible no pisa una ref local buena con `nil`.
- [ ] Tests con el fetch lanzando + control positivo (seam `EntityApplyMap._testThrowOnFetchOf`).

## Relacionado

- `apply-overwrites-a-pending-local-write-without-its-guards` — el mismo patrón dentro de `applyPage`, cerrado.
