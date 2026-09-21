---
name: el-predicado-que-amplio-cortocircuita
description: Ampliar un predicado no solo añade población — si quien lo lee cortocircuita, TAPA los estados que venían detrás; mide qué se vuelve inalcanzable
metadata:
  type: feedback
---

**Antes de añadir un término a un predicado, mira el `if` que lo consume: si cortocircuita, el
término nuevo no amplía una rama — APAGA las que venían después. Cuenta qué se vuelve inalcanzable,
no solo a quién alcanzas.**

**Why:** el 2026-09-21, en `restore-treats-budgets-and-groups-as-no-data`, el ticket pedía sumar
presupuestos y grupos a `ICloudAccountSummary.hasAnyData`. Lo implementé, con sus mutantes muertos y
su Paso 0 razonado. La review adversarial midió el consumidor:

```swift
if summary.hasAnyData { state = .found(summary) }      // ← cortocircuita
else if !settlement.consultsRemoteConfig { … }         // .importIncomplete
else { await resolveEmptyState(settlement) }           // .cloudPaused / .cloudUnverified / .notFound
```

Con **un solo grupo local** —y los grupos no vienen de iCloud: viven en un store
`cloudKitDatabase: .none`— ese `if` se cumple siempre, así que `.importIncomplete`, `.cloudPaused`,
`.cloudUnverified` y `.notFound` dejaban de alcanzarse. Es decir: mi arreglo **desactivaba el ticket
cerrado dos días antes**. Y en `FullModeActivationView`, que monta esa misma pantalla y a la que
solo se llega desde una sesión solo-grupos, eran inalcanzables **por construcción** — con el
agravante de que el docblock de esa pantalla dice explícitamente que cuenta con que ese `.notFound`
ocurra.

La segunda mitad del error fue de justificación: escribí que sin el término nuevo «se le ofrece de
primera el gesto que se los lleva». Cierto que se le ofrece — **falso que se los lleve sin avisar**:
`ContentView.checkHasExistingData()` ya cuenta `SplitGroup` y es quien alimenta el aviso con doble
confirmación de la puerta siguiente. **La protección que yo venía a construir ya existía**, en un
predicado hermano que no miré porque no aparecía en el ticket.

**How to apply:**

- Al ampliar un predicado, abre el consumidor y **escribe qué ramas quedan detrás del `if`**. Si hay
  un `else if`/`else` con estados propios, el término nuevo se los come para toda su población.
  Pregunta: «¿qué deja de poder ocurrir?», antes que «¿a quién alcanzo ahora?».
- **Busca el predicado HERMANO antes de justificar el tuyo con un daño.** Si el argumento es «sin
  esto se le borra algo», el repo suele tener ya un gate en ese camino: grepea el modelo
  (`FetchDescriptor<X>`) y mira quién más lo cuenta. Aquí había tres predicados sobre «¿tiene
  grupos?» y ninguno estaba en el ticket.
- **Dos preguntas distintas quieren dos predicados distintos.** «¿Trajo algo el espejo de iCloud?» y
  «¿hay datos que perder en este teléfono?» no son la misma, y colapsarlas produce el error en las
  dos direcciones: o niegas datos que existen, o afirmas un origen que no es.
- Corolario de proceso: el Paso 0 puede estar entero, razonado y con mutantes verdes **y seguir
  apoyado en una premisa del ticket que nadie midió**. Lo cazó la lente de CONSUMIDORES, que es la
  que hay que lanzar siempre que el cambio toque un predicado compartido.
- Hermanas: [[la-premisa-del-encargo-tambien-se-mide]], [[mi-arreglo-rompe-la-premisa-de-otro-guard]],
  [[el-prefiltro-tapa-al-criterio]], [[review-adversarial-caza-lo-mio]].
