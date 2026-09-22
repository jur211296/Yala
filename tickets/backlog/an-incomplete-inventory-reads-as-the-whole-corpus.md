---
id: an-incomplete-inventory-reads-as-the-whole-corpus
status: backlog
priority: high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "barrido del patrón durante `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# Si al subir tus datos una tabla no se deja leer, la app da esa tabla por subida y sigue

## El problema, en lenguaje de usuario

Al pasar los datos a la nube —o al entrar en una cuenta que ya existe— la app recorre tus tablas y sube lo que
falta. Si una de esas lecturas falla, no lo dice ni lo reintenta: **cuenta esa tabla como si no tuviera nada**,
la da por subida y pasa a la siguiente. Los movimientos de esa tabla se quedan fuera de la nube, y como cada
paso es de una sola pasada, no vuelve a intentarlo nunca.

## Por qué pasa (medido el 2026-09-22 en este árbol)

Es la familia «un inventario incompleto se lee como el corpus entero». `verify-reads-a-failed-local-fetch-as-an-empty-outbox`
cerró el fetch de `SyncOutbox` en los tres sitios donde vivía; estos son sus vecinos, y los dejó fuera porque el
dato que leen es otro.

| Sitio | Qué devuelve el `catch` | Qué decide con eso |
|---|---|---|
| `MigrationSnapshotUploader.makeSpec:298` | `([], nil, false)` | `hasMore = false` ⇒ **el snapshot de esa entidad se da por subido** |
| `MigrationWorkExecutor.collectIdentityPairs:369` | `[]` | `CKIdentityCapture` sobre 0 pares; el breadcrumb reporta `captured: 0` como si no hubiera nada |
| `MigrationWorkExecutor.addPairs:475` | salta la entidad | mismo efecto, por entidad |
| `MigrationWorkExecutor.collectAdoptInventory:1536` | salta la entidad | ver abajo |
| `MigrationWorkExecutor.buildOrphanRowInputs:1579` | salta la entidad | las huérfanas de esa tabla no se suben |
| `MigrationWorkExecutor.addReverseUploadPairs:456` | salta la entidad | la muestra del techo de la vuelta cuenta MENOS filas vivas ⇒ «avance» falso |

El de `collectAdoptInventory` tiene dos daños distintos y conviene decirlos por separado:

1. **Desactiva el guard anti-fusión.** `:1307-1312` aborta con `.abortedEmptyBackend` si el backend está vacío y
   el plan tiene algo que subir; un inventario que se saltó filas puede dar `uploadCount == 0` y **apagar
   justo el guard que existe para no fusionar dos corpus**.
2. **Cierra el adopt en falso.** `:1324` hace `guard !plan.orphans.isEmpty else { return .completed(uploaded: 0) }`:
   sin huérfanas, el adopt se declara completo y **no vuelve a pasar por ahí**.

**Y un cuarto, que apaga un canario en vez de decidir mal** (lo cazó una lente de la review del 2026-09-22 y no
estaba en ningún ticket): `CloudSyncEngine.rehydrateOutboxFromMirror:2571-2580` sale con un `return` mudo si su
fetch lanza. No es «lee vacío», pero **silencia `cloudSyncOutboxMirrorDivergence`**, que por su propio docblock es
«el modo de fallo que ni el Merkle ve». Un fetch que falla apaga justo el canario que existe para verlo.

El de `addReverseUploadPairs` ya tiene ticket propio para su mitad
(`reverse-upload-sample-reads-unreadable-rows-as-drained`); se nombra aquí para que al arreglar la familia no se
haga dos veces ni se olvide.

## Qué habría que decidir antes de hacerlo

1. **¿Un inventario parcial corta o reintenta?** El snapshot tiene `.transient` y el adopt también; el
   `collectIdentityPairs` no tiene desenlace ninguno (su caller no puede fallar). Hay que elegir qué hace cada uno.
2. **¿Se unifica el helper?** Son seis funciones con la misma forma (`addX<M>` sobre 16 entidades, `catch` mudo).
   Un solo seam para las seis abarata el test, pero acopla seis caminos con desenlaces distintos.
3. `makeSpec` es el más grave y el más barato: su `false` es un `hasMore`, y cambiarlo a `true` con un desenlace
   de corte no toca a nadie más.

## Criterios de aceptación

- [ ] Un `fetch` que lanza en el barrido del snapshot NO deja la entidad marcada como subida.
- [ ] Un inventario incompleto del adopt no apaga el guard anti-fusión ni cierra el adopt con `uploaded: 0`.
- [ ] Rastro en producción de la avería (hoy es un `print` de `#if DEBUG` en los seis).
- [ ] Tests con el fetch lanzando + control positivo por cada desenlace tocado.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el mismo patrón sobre el fetch de `SyncOutbox`, cerrado.
- `reverse-upload-sample-reads-unreadable-rows-as-drained` — la mitad del muestreo de la vuelta.

## Nota del 2026-09-22 (`snapshot-upload-has-no-ceiling-and-no-way-out`)

La fila de `MigrationSnapshotUploader.makeSpec` tiene desde ese ticket un desenlace listo para usar:
`SnapshotStepOutcome.blocked(.localFailure)`, que elige el techo CORTO de la subida (15 min acumulados) y sale a la
tarjeta de fallo con el texto «este dispositivo no pudo preparar tus datos». Antes, cortar ahí habría dejado la barra
al 55 % para siempre; ahora cortar es seguro. Lo que sigue abierto es que el `catch` de `makeSpec` todavía no corta:
salta la tabla.
