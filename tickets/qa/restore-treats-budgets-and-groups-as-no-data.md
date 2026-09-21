---
id: restore-treats-budgets-and-groups-as-no-data
status: qa
priority: medium
area: "welcome, icloud, restore"
created: 2026-09-20
updated: 2026-09-21
source: "medición durante `restore-says-no-data-when-the-icloud-import-never-settled` (2026-09-20): al buscar la población de `.notFound` concluyente apareció que es EXACTAMENTE ésta"
---

# «No encontramos tus datos» a quien solo tiene presupuestos o grupos en iCloud

## El problema, en lenguaje de usuario

Tengo presupuestos —o grupos compartidos— guardados en iCloud, pero ninguna cuenta, ningún
movimiento y ninguna categoría propia. Reinstalo Yala, toco «Restaurar desde iCloud», y la app me
dice **«No encontramos tus datos. No hay datos asociados a tu cuenta de iCloud»** con mis
presupuestos ahí.

## Medido (2026-09-20)

- `ICloudAccountSummary.hasAnyData` cuenta **tres** cifras y deja fuera las otras dos que él mismo
  transporta: `accountsCount > 0 || transactionsCount > 0 || categoriesCount > 0`
  (`Yala/Services/iCloudSyncService.swift:773-775`). El struct trae además `budgetsCount` y
  `groupsCount`, y `RestoreProgressView` los pinta en vivo mientras bajan
  (`RestoreProgressView.swift`, `liveCounts`) — o sea que la pantalla los enseña subir y luego
  niega que existan.
- `WelcomeRestoreView` decide con ese predicado: `if summary.hasAnyData { state = .found(summary) }`
  y si no, sigue al camino de búsqueda vacía.
- La segunda copia del criterio, `ICloudPersonalCorpusProbe.hasAnyData`
  (`Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift:75-77`), tiene el mismo hueco —
  `truncated || transactions > 0 || accounts > 0 || categories > 0` — y solo lo tapa **por
  accidente**, vía `truncated`, cuando el corpus es tan grande que agota el tope de la sonda. Un
  corpus pequeño de solo presupuestos no lo agota y cae por el mismo sitio. Su propio docblock
  declara que sigue «el mismo criterio» que el otro, así que las dos se mueven juntas.

## Por qué aparece ahora

Al cerrar `restore-says-no-data-when-the-icloud-import-never-settled` había que decidir en qué
casos «Empezar desde cero» pregunta antes, y el término era si la búsqueda había concluido
(`settled`). Buscando quién alcanza `.notFound` **con** la búsqueda concluida salió que
`settled == true` exige un `.importEvent` exitoso —o sea, que CloudKit trajera algo—, y que si
trajo algo y aun así `hasAnyData` es `false`, lo que trajo son presupuestos o grupos. **Ésa es la
única población de ese camino**, y es esta.

Por eso aquel ticket dejó `.notFound` confirmando SIEMPRE: mientras este hueco siga abierto, la
rama que llamaba directo le hacía daño justo a la gente que sí tiene datos.

## Criterios de aceptación

- [ ] Un corpus de iCloud que solo tenga presupuestos (o solo grupos) NO produce el mensaje que
      niega los datos.
- [ ] Las dos copias del criterio quedan alineadas, o se reduce a una sola.
- [ ] Al ampliar el predicado, revisar los OTROS consumidores: `.found` enseña las cifras con
      `visibleCountItems`, y `WelcomePrivateICloudGateLogic` decide `.foundData` / `.ask` /
      `.standDown` con el mismo criterio — ampliarlo cambia también a quién se le pregunta antes
      de borrar, que es el lado bueno, pero hay que medirlo antes de darlo por gratis.

## Relación con otros tickets

- `restore-says-no-data-when-the-icloud-import-never-settled` — de donde sale.
- `restore-beacon-outlives-account-deletion` — también razona sobre qué cuenta `hasAnyData`.

## Paso 0 · Decisiones (2026-09-21)

Ocho, resueltas midiendo. Las dos primeras corrigen la premisa del propio ticket.

**D1 · `ICloudAccountSummary.hasAnyData` cuenta CUATRO cifras: se le suman los presupuestos, NO los
grupos.**

> **D1 se escribió primero al revés —las cinco cifras, grupos incluidos— y la review adversarial lo
> refutó.** La versión descartada queda abajo con su medición, porque es lo que el ticket pedía y
> hace falta saber por qué no se hizo.

Los presupuestos entran sin discusión: viven en `personalSchema`, el espejo los baja, y
`RestoreProgressView.liveCounts` los pinta subiendo mientras la pantalla siguiente negaba que
existieran.

**Los grupos NO entran, por tres medidas:**

1. **No vienen de iCloud** (la medición de D2, abajo). Este predicado contesta «¿trajo algo el
   espejo?»; un conteo que el espejo no puede mover solo puede mentir.
2. **Contarlos TAPA cuatro estados legítimos.** `WelcomeRestoreView:111` decide con un
   `if summary.hasAnyData` que **cortocircuita antes de leer el veredicto del import**, así que con
   un solo grupo local dejarían de alcanzarse `.importIncomplete` —que es el ticket
   `restore-says-no-data-when-the-icloud-import-never-settled`, cerrado anteayer—, `.cloudPaused`,
   `.cloudUnverified` y `.notFound`. Y en `FullModeActivationView:201`, que monta esa misma pantalla
   y a la que **solo se llega desde una sesión solo-grupos**, serían inalcanzables POR CONSTRUCCIÓN:
   el docblock de su «Empezar desde cero» dice explícitamente que cuenta con que ese `.notFound`
   ocurra («también contesta cuando el `.notFound` de aquí es falso porque el import no terminó»).
   ⇒ el arreglo habría desactivado dos tickets recién cerrados y habría enseñado «Encontramos tus
   datos en iCloud: 3 grupos» a alguien con el iCloud vacío.
3. **La protección que motivaba incluirlos YA EXISTE, y el D1 original la ignoró.** El argumento era
   que `.notFound` ofrece «Empezar desde cero» de primario y ese camino purga el dominio de Grupos
   (`ContentView.performICloudCorpusWipe`, scope `.handover`, `ContentView.swift:1883-1887`).
   Cierto — **pero no borra sin avisar**: pasa por la puerta del paso 4, cuyo `deviceHasData` sale
   de `ContentView.checkHasExistingData()`, que cuenta `SplitGroup` **sin predicado**
   (`ContentView.swift:1350`) ⇒ quien solo tiene grupos cae en `.foundDeviceData` y recibe el aviso
   con doble confirmación. El daño real era el MENSAJE, no la pérdida.

⇒ **son dos preguntas y cada una ya tiene su predicado**: «¿hay algo que restaurar de iCloud?» es
`hasAnyData`; «¿hay datos que perder en este teléfono?» es `checkHasExistingData()`. El D1 original
las colapsaba en una, y eso produce el error en las dos direcciones.

**D2 · Grupos tampoco van en la sonda, y ahí es estructural.** El ticket dice
«un corpus de iCloud que solo tenga … grupos», y eso no existe por esa vía. Medido:
`SplitGroup` vive en `groupsSchema` (`SwiftDataConfiguration.swift:118-126`), cuyo store monta
`cloudKitDatabase: .none` (`:1060`); sus filas llegan por el backend de Yala
(`GroupsSyncClient.applyGroupMeta` inserta el born-remote) y **no hay ningún record type
`CD_SplitGroup` en el contenedor personal** que la sonda enumera. El contenedor de Grupos es otro
y el docblock de la sonda ya dice que no se toca.

⇒ la sonda añade **presupuestos** (`CD_Budget`, que sí está en `personalSchema`) y no grupos — que
con D1 corregido ya no es una asimetría con el hermano, sino la misma decisión medida dos veces.

**Matiz que cazó la review y que no se pierde:** «no hay `CD_SplitGroup` en el contenedor personal»
es cierto **por diseño, no por observación**. Hasta el 2026-06-14 `groupsConfiguration` omitía su
`cloudKitDatabase: .none` y llegó a subir `CD_Split*` a ese contenedor (`docs/DECISIONS.md`,
confirmado entonces en el Dashboard); el arreglo fue una línea y no borró lo ya subido
(`MODO-NUBE-AUDITORIA-ESCENARIOS.md`, INV-04, «estado server-side NO VERIFICADO»). Esos residuos
caen en el `default` de `classify` y no encienden ninguna cifra, pero **sí suman a `scanned`** y
acercan el `truncated`. Queda escrito en el docblock para que quien mañana quiera detectarlos o
limpiarlos no lea una prohibición donde solo hay un «no los contamos como datos del usuario».

**D3 · No se reducen a una sola copia.** Miden fuentes distintas —filas de un `ModelContext` vs.
registros de CloudKit sin espejo— y tienen campos distintos por D2. Se alinean y cada una dice qué
término le falta al otro y por qué.

**D4 · `countsLine` (puerta privada) pinta los presupuestos.** No es adyacente: es el MISMO defecto
que ya se cerró ahí para las categorías el 2026-09-10
(`tickets/qa/welcome-private-fresh-start-skips-icloud-check.md:269`) — una cifra que dispara el
aviso y no se pinta deja un aviso de borrado irreversible con la línea en blanco. La clave
`welcome.restore.foundBudgets` ya existe en los 16 locales: cero l10n nuevo.

**D5 · `visibleCountItems` (pantalla `.found`) pinta las categorías.** Es el criterio 3 del ticket
—«revisar los OTROS consumidores»— y la revisión mide un hueco VIVO hoy, anterior a este trabajo:
`hasAnyData` ya es `true` con solo categorías, `visibleCountItems` no las pinta, y `countCards` con
cero items cae en el `default` → «Encontramos tus datos en iCloud:» sobre un grid vacío. Es el
único de los tres sitios que cuentan cifras que no las enseña (`liveCounts` sí, `countsLine` sí
desde el 10-sep). Clave `welcome.privateICloud.foundCategories`, ya en los 16 locales.

**D6 · El copy NO se toca.** `welcome.restore.foundBody` dice «Encontramos tus datos **en
iCloud**:» y la pantalla puede pintar una card de grupos, que no vienen de ahí. **Con D1 corregido
el caso PURO solo-grupos ya no alcanza `.found`**, así que lo que queda es una card de grupos junto
a cifras que sí son de iCloud: la frase es cierta para el hallazgo y engloba una cifra que no lo
es. Residual menor, con ticket propio
(`restore-found-copy-says-icloud-for-groups-that-never-were`, `low`).

**D7 · La decisión de `.notFound` («pregunta SIEMPRE antes de empezar de cero») NO se revierte, y
con D1 corregido ni siquiera pierde su razón.** El argumento que la sostenía —esa rama tiene una
sola población y es gente con datos— se queda con la mitad de grupos intacta, porque los grupos
siguen sin contar. Se reescriben igual los docblocks que citaban el hueco
(`WelcomeRestoreView.notFoundView`, `RestoreImportSettlement.settledEmpty`,
`RestoreStartFreshGateTests`, `RestoreImportSettlementTests`) para que digan la mitad que cambió y
la que no: una premisa a medio caducar invita a desandar el gesto que sostiene.

**D8 · Se anota el colateral en el hermano.** `restore-beacon-outlives-account-deletion` §3 razona
sobre quién cae en `.found` con datos rancios post-migración; ampliar el predicado le añade
población (el migrado cuya copia congelada solo tenga presupuestos). El delta es casi nulo —migrar
exige tener datos— pero se mide y se escribe allí, no se corta por motivo.

**D9 · Lo que la review dejó abierto y NO se arregla aquí, cada uno con su motivo.** Cuatro
observaciones que las dos lentes midieron y que no son de este ticket:

- **`hasPrefill` es un `!= nil`, no «el resumen tiene contenido».** Quien llegue a `.found` con solo
  presupuestos entra al onboarding con `prefilledOnboardingData` puesto, y `OnboardingStepPlan`
  **salta el paso de divisa siempre** (`primaryCurrencyCode` nunca es `nil`: el constructor lo llena
  con las preferencias). Antes esa persona pasaba por `.notFound` → «Empezar desde cero», que pone
  el prefill a `nil` y sí le preguntaba. Población nueva y pequeña; el valor que se le fija es el de
  sus propias preferencias. **Ticket:** `restore-prefill-skips-currency-for-an-empty-summary`.
- **`.found` es el único estado del restore sin breadcrumb.** El bug de este flujo reproduce en
  CloudKit Production, donde el log es la única ventana. **Ticket:**
  `restore-found-state-leaves-no-breadcrumb`.
- **Tres predicados hermanos discrepan sobre qué `SplitGroup` cuenta.** `groupsCount` filtra
  `!isArchived`; `checkHasExistingData()` no filtra nada; y el resto del repo descuenta además
  `isHiddenForAll` (el soft-delete irreversible). Con D1 corregido `groupsCount` ya no decide, así
  que la discrepancia vuelve a ser inerte para el veredicto — pero **sigue decidiendo qué card se
  pinta**: un grupo `isHiddenForAll` se cuenta en «2 grupos compartidos». **Ticket:**
  `group-presence-predicates-disagree-on-archived-and-hidden`.
- **La pantalla `.found` puede pintar CINCO cards desde hoy** (las categorías entraron en D5) y
  `countCards` manda 4-o-más a un grid de dos columnas ⇒ la quinta queda sola en su fila. Es un grid
  impar, no un defecto, y moverlo sería UI que nadie pidió: **va al device-QA para mirarlo con los
  ojos**, y el docblock, que prometía «4 → grid 2×2», queda corregido.

## La población real, medida (y por qué NO es la que el ticket describe)

El ticket dice «tengo presupuestos guardados en iCloud, pero ninguna cuenta, ningún movimiento y
ninguna categoría propia». Al buscar a esa persona salió que **casi no existe por esa vía**, y el
motivo es una cifra que el ticket no mira:

- La semilla oficial de categorías crea sus `Subcategory` con `isDefaultSeed: true` y **sin tocar
  `isSystem`, cuyo default es `false`** (`Yala/Seed/CategorySeed.swift:446-455`,
  `Yala/Models/Subcategory.swift:42`). `categoriesCount` cuenta exactamente `Subcategory` con
  `!isSystem` ⇒ **quien pasó por el onboarding personal tiene decenas de categorías propias**, y con
  el espejo montado están en su iCloud. Para ese usuario `hasAnyData` ya era `true` antes de este
  ticket: nunca vio el mensaje.

⇒ las dos poblaciones que SÍ llegan, y las dos siguen justificando el cambio:

1. **El import a medias, que es el caso del ticket padre.** CloudKit entrega por lotes y sin orden
   garantizado: puede haber bajado `CD_Budget` y todavía no `CD_Subcategory`. Ahí `budgetsCount > 0`
   con las otras cuatro en cero es un estado real y observable — es literalmente lo que
   `RestoreProgressView.liveCounts` enseña subiendo.
2. **Quien tiene grupos y nada en iCloud.** El alta solo-grupos no pasa por el onboarding personal
   —la semilla la disparan `OnboardingView:1724`, `GroupInviteOnboardingView:558` y
   `SubcategorySelectorSheet:41`, no el arranque, pese a lo que dice el docblock de
   `CategorySeed.swift`— y su store personal es el neutro, que no espeja. Su iCloud está vacío de
   verdad y sus grupos son locales. **Es la población con pérdida**: `.notFound` le ofrece de
   primera «Empezar desde cero», y ese camino purga el dominio de Grupos.

**Y un efecto medido del cambio que conviene tener escrito**, porque no es gratis: con el import a
medias y un presupuesto ya bajado, la pantalla pasa de `.importIncomplete` («seguimos trayendo tus
datos») a `.found` con la cifra que haya llegado. **No es una clase nueva de problema** — con una
sola cuenta bajada ya ocurría exactamente igual desde siempre—, pero la puerta de entrada es un
poco más ancha. Se acepta: el desenlace de `.found` conserva los datos, y el de `.notFound` ofrece
borrarlos.


## Hecho (2026-09-21)

**Lo que cambia para quien usa la app:** si en iCloud tienes presupuestos y todavía no ha bajado
nada más, Restaurar deja de decirte que no hay nada tuyo — los cuenta, los enseña y te deja
continuar. Y la pantalla del hallazgo enseña también tus **categorías**, que hasta hoy contaban
para decidir y no se pintaban: quien restauraba solo categorías veía «Encontramos tus datos en
iCloud:» encima de un hueco.

**Lo que NO cambia, y es la corrección más importante de la sesión:** los grupos siguen sin contar
para «hay datos en iCloud». El ticket pedía incluirlos y la review adversarial lo refutó con tres
medidas (D1). A quien solo tiene grupos se le sigue avisando antes de borrar, pero en la puerta del
paso 4, que sí los cuenta.

### Ficheros

| Fichero | Qué cambia |
|---|---|
| `Yala/Services/iCloudSyncService.swift` | `hasAnyData` suma `budgetsCount`; el porqué de que los grupos no entren |
| `Yala/Services/CloudSync/ICloudPersonalCorpusProbe.swift` | `ICloudPersonalCorpus.budgets` + `case "CD_Budget"` en `classify` |
| `Yala/App/Views/Onboarding/WelcomePrivateICloudGateView.swift` | `countsLine` pinta los presupuestos |
| `Yala/App/Views/Onboarding/WelcomeRestoreView.swift` | `visibleCountItems` pinta las categorías; dos docblocks |
| `Yala/App/Logic/WelcomeAccountChoiceLogic.swift` | docblock de `.settledEmpty` (premisa a medio caducar) |
| `YalaTests/CloudSync/RestoreDataPresenceWiringTests.swift` | **nuevo**: la invariante «todo término del predicado tiene quien lo pinte» |
| `YalaTests/ICloudAccountSummaryTests.swift` | el test que fijaba el bug, invertido; los grupos fijados FUERA |
| `YalaTests/CloudSync/WelcomePrivateICloudGateTests.swift` | presupuestos en el helper, en la tabla y en `countsLine` |
| `YalaTests/CloudSync/RestoreImportSettlementTests.swift`, `RestoreStartFreshGateTests.swift` | premisas caducadas |

### Validación

- Build `Yala` y `Yala Dev` ✓, sin warnings nuevos en los ficheros tocados.
- **116 unit en 12 suites** (12 pedidas), verde.
- **Mutantes**: 10 en la primera tanda y 11 en la segunda, todos muertos. El primer intento del
  source-scan dejó uno VIVO (`if false, s.categoriesCount > 0 {` pasaba porque el scan solo miraba
  la condición): se endureció para exigir que la rama AÑADA su card, y se re-mató.
- **Review adversarial**: dos lentes + la rule de área (`swiftdata-cloudkit.md`, `testing.md`)
  leídas contra el diff. **15 hallazgos, y el primero cambió el diseño** — los grupos salieron del
  predicado. Cuatro salieron en ticket propio (D9), el resto se arregló aquí.
- `bash qa/validate-coverage.sh` ✓.

### Device-QA — 6 pasos en iPhone

El simulador no sirve para los pasos 1-3: **CloudKit no existe ahí**. Los pasos 4-6 sí.

1. **El caso principal.** En un iPhone con Yala y sesión privada, ten presupuestos y espera a que
   suban (Ajustes → el estado de sync en verde). Reinstala la app. Welcome → **«Restaurar desde
   iCloud»**. Mientras baja, mira la pantalla de progreso: la cifra de presupuestos (el icono del
   gráfico circular) tiene que **subir**. **DECIDE:** al terminar no puede salir «No encontramos tus
   datos» si esa cifra llegó a ser mayor que cero.
2. **La pantalla del hallazgo.** En la misma pasada, comprueba que la card de presupuestos aparece
   con su número, y que si hay categorías propias **también aparece la suya** (icono de etiqueta) —
   eso es nuevo hoy.
3. **Cinco cards.** Si tu corpus tiene las cinco cifras (cuentas, movimientos, categorías,
   presupuestos y grupos), mira cómo queda el grid: son **dos columnas y la quinta card se queda
   sola en su fila**. **No es un fallo, es una decisión** — dinos si se ve mal y se cambia.
4. **El control negativo.** Con un Apple ID sin nada de Yala en iCloud, Restaurar tiene que seguir
   diciendo «No encontramos tus datos». Si esto cambió, el arreglo se pasó de largo.
5. **El solo-grupos NO cambió, y hay que confirmarlo.** En un teléfono que entró por un grupo
   compartido y nada más, Restaurar debe seguir diciendo que no hay datos en iCloud (es cierto), y
   al tocar **«Empezar desde cero»** la puerta siguiente tiene que **avisarte de que hay datos en
   este teléfono** y pedirte una segunda confirmación. **DECIDE:** si esa puerta no avisa, el
   arreglo dejó a alguien expuesto y hay que volver a mirarlo.
6. **La puerta privada con presupuestos.** «Primera vez → Tu cuenta en tu iCloud privado» con un
   iCloud que tenga presupuestos: el aviso de borrado tiene que enseñar **«N presupuestos»** en su
   línea de cifras, nunca la línea en blanco.
