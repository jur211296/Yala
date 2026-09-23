---
id: apply-overwrites-a-pending-local-write-without-its-guards
status: in-progress
priority: very-high
area: "modo-nube, sync"
created: 2026-09-22
updated: 2026-09-22
source: "barrido del patrón durante `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# Si la app no puede leer sus propias salvaguardas, lo que baja de la nube pisa un cambio tuyo sin subir

## El problema, en lenguaje de usuario

Cuando algo baja de la nube, la app comprueba antes si eso mismo lo has cambiado tú aquí y todavía no ha subido;
si es así, gana lo tuyo. Esa comprobación se construye leyendo la base local. **Si esa lectura falla, la app se
queda sin la comprobación y lo de fuera entra igual** — encima de un cambio tuyo que nadie había subido todavía.

## Por qué pasa (medido el 2026-09-22 en este árbol)

Es la familia «un default optimista convierte una avería en un permiso», la misma que cerró
`verify-reads-a-failed-local-fetch-as-an-empty-outbox` sobre el fetch de `SyncOutbox`. Aquí muerde en el apply,
que es donde se pierden datos.

1. **`SyncApplyEngine.buildPendingGuards:631`** — el `catch` devuelve el diccionario **PARCIAL** (`[:]` si lanza
   en la primera fila). Ese diccionario ES el guard LWW por unidad de coherencia: vacío, un remoto pisa una
   escritura local pendiente. Es el daño de verdad.
2. **`SyncApplyEngine.existingQuarantineSeqs:490`** — el `catch` devuelve un `Set` vacío, y ése es el set de
   DEDUPE que consume `:246` ⇒ una fila ya cuarentenada se re-inserta duplicada.
3. **`EntityApplyMap.deleteMatching:1021`** — el `catch` devuelve `0`, y los callers (`:988-1003`) contabilizan el
   tombstone como APLICADO con cero filas borradas: el borrado remoto se da por hecho sin haber borrado nada.

Los tres son mudos en producción (`print` bajo `#if DEBUG`).

## Qué habría que decidir antes de hacerlo

1. **Un guard parcial es peor que ninguno**, porque parece uno. El desenlace honesto es no aplicar la página y
   dejar que el ciclo reintente — pero hay que comprobar qué hace el cursor con una página no aplicada, que es
   justo el invariante de atomicidad D-5 (`_testThrowOnApplySave` existe para eso).
2. **`deleteMatching` devolviendo `0`**: ¿es «no había nada que borrar» un caso legítimo hoy? Si lo es, el `0` del
   `catch` no se puede distinguir sin cambiar el tipo de retorno.
3. Los tres están en el camino caliente del apply; conviene medir el coste de cualquier lectura extra.

## Criterios de aceptación

- [ ] Un `fetch` que lanza al construir los guards NO deja aplicar la página con el guard a medias.
- [ ] El cursor no avanza sobre una página que no se aplicó (atomicidad D-5 conservada).
- [ ] Una cuarentena que no se puede leer no produce duplicados.
- [ ] Un tombstone no se contabiliza aplicado cuando el borrado no se pudo hacer.
- [ ] Tests con el fetch lanzando + control positivo por cada uno de los tres.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el mismo patrón sobre el fetch de `SyncOutbox`, cerrado.
