---
id: secondary-groups-off-wipes-owner
status: in-progress
created: 2026-08-13
updated: 2026-08-26
source: YalaWiki/Bugs/secundaria-canal-apagado-la-visita-borra-los-grupos-del-dueno.md
---


# Con el canal de Grupos apagado, la visita monta el archivo del dueño — y puede borrarlo sin vuelta atrás

## El síntoma, en lenguaje de usuario

Presto mi móvil a alguien para que entre con su cuenta. Cuando me lo devuelve, **mis grupos ya no
están en este teléfono** — ni los gastos, ni quién debe qué. Están intactos en el servidor, pero mi
móvil no los vuelve a bajar. Reinstalar es lo único que los trae de vuelta.

## Dónde muerde

| Entorno | Estado |
|---|---|
| Producción | **DARK** — `SECONDARY_SESSION_ROLLOUT_PERCENT = 0`, el recorrido es inalcanzable |
| Staging / `Yala Dev` | Alcanzable, y **reproducible a voluntad** (ver §Cómo verlo) |

## La cadena, eslabón a eslabón (todo medido el 2026-08-13)

### 1 · El mount elige el archivo del DUEÑO

`SwiftDataConfiguration.GroupsStoreDecision.decide(flagOn:secondaryActive:)` es
`(flagOn && secondaryActive) ? .secondary : .primary`. Con el canal apagado el segundo término no
importa: monta el **primario**, el archivo del dueño.

**Y «backend al 100 %» no protege**, que es la confusión natural: eso describe dónde vive la VERDAD,
no dónde vive la COPIA. `YalaGroups` es un store SwiftData local con `cloudKitDatabase: .none` —nunca
fue CloudKit y no murió con el transporte— que el pull materializa y que la app lee para pintar. No
hay lecturas en vivo contra Supabase. Es un archivo real en el disco de cada teléfono.

### 2 · El detector del Welcome lo cuenta

`ContentView.checkHasExistingData` hace `FetchDescriptor<SplitGroup>()` **sin predicado** sobre el
contexto montado. En esa sesión: store personal de la invitada (vacío) + store de grupos del dueño
(con sus grupos) ⇒ **`hasExistingData` da `true` por los grupos de él**.

> Esto resuelve una aparente contradicción del ticket padre: su §2 dice que el alert «ni siquiera
> salta» y su §4 que salta con los grupos del dueño. Los dos son ciertos — depende de si el dueño
> tiene grupos.

### 3 · Ella tiene que llegar al Welcome (el filtro real)

En su entrada normal **no lo ve**: `performSecondaryEntryTasksIfNeeded` pone
`hasCompletedOnboarding = true` justo para eso. Dos formas de saltárselo, ambas escritas en el código:

- **la vía 5 del ticket padre**: ella toca «Vaciar mis datos» en su sesión ⇒ los flags caen, pero el
  marker `entryPurgeDone` está FUERA del barrido (`cloudSync.*` no se toca) ⇒ la curación ya está
  gastada y **nadie los repone**;
- un **kill del proceso** en la ventana descriptor→flags de la entrada, que el propio docblock nombra.

### 4 · Confirma el alert de «Es mi primera vez»

`wipeLocalGroupsDomain` borra las cinco tablas `Split*` del store montado — el del dueño.

### 5 · Y no vuelve

El wipe **conserva el cursor A PROPÓSITO** (`groupCursorsJSON` es la barrera que impide que el corpus
del anterior baje al device del siguiente — el bug `31dded30`). Con el cursor en su marca alta el
servidor solo manda deltas con `server_seq` mayor, y el único camino que resetea cursores es
`applyMember` en un re-join, que exige que el servidor mande algo primero.

⇒ **pérdida local permanente.** Volvería a medias: la siguiente edición ajena baja ese delta, pero el
histórico no. Recuperación real: reinstalar.

## Alcanzabilidad, sin adornos

La cadena es **larga**: canal apagado **y** una de las dos rutas al Welcome **y** confirmar un alert
destructivo. La probabilidad es baja.

**Pero el eslabón 1 depende del botón de emergencia.** Con el rollout al 100 %, la forma dominante de
que el canal esté apagado es **el kill switch remoto** — lo que activas cuando hay un incidente. Las
otras dos (snapshot ausente ⇒ `absentDefault` es `false` en producción; snapshot viejo hasta 6 h) son
transitorias y menos probables en un device que ya venía usando la app.

⇒ esta vía se abre **durante un incidente**, que es cuando menos falta hace un segundo problema. Es el
mismo patrón que ya está escrito para `purgeQueuedSplitGroupTombstones`: «bajar el percent es la
respuesta operativa a ESE incidente ⇒ el barrido estaría apagado precisamente en la cohorte donde el
veneno sobrevive».

## El fix, en cuatro piezas

### 1 · El mount nunca elige el archivo del dueño en secundaria (raíz, una línea)

```swift
decide(flagOn:secondaryActive:) →  secondaryActive ? .secondary : .primary
```

El flag deja de decidir QUÉ archivo se monta y pasa a decidir solo SI el canal lo puebla. Con el canal
apagado la invitada monta un `YalaGroups-Secondary` **vacío** —no ve nada raro, su tab ya está cerrado
en esa configuración— y el archivo del dueño queda **inerte**, que es exactamente la garantía que el
docblock de `decide` ya promete para el flag encendido. Solo se extiende al caso apagado.

**Barato y acotado**: `decide` tiene **UN solo call-site** (`SwiftDataConfiguration.swift:1103`) y **ya
tiene tests de tabla** (`StorageModePersistenceTests.swift:174-186`).

*A medir antes*: que montar el secundario con el canal apagado no rompe el arranque. Es un archivo
nuevo creado al vuelo, igual que hoy con el flag encendido, así que no debería — pero el mount es la
pieza más delicada del boot y no se toca sin comprobarlo.

### 2 · Cinturón fail-closed en el wipe

`wipeLocalGroupsDomain` se niega a borrar si el store montado no es de esta sesión. **No es redundante
con la 1**: el daño es irreversible y equivocarse en la otra dirección solo cuesta una limpieza
pendiente. Cubre además al próximo que añada un tercer camino de borrado (hoy hay dos, y uno de ellos
—el alert de «oferta de restaurar»— resultó estar MUERTO).

Necesita un **testigo de la decisión de mount de grupos**. El patrón ya existe para el store personal
(`SwiftDataConfiguration` guarda qué decisión ejecutó realmente el proceso, porque lo persistido y lo
montado pueden diferir); replicarlo es coherente, no inventar.

### 3 · El detector NO se toca

Con la pieza 1, `checkHasExistingData` cuenta 0 grupos por sí solo. Menos superficie tocada, mejor.

### 4 · El comentario caducado del sello (gratis)

`wipeLocalGroupsDomain` cierra con «el reset de los tokens hace que el motor re-descargue el corpus de
grupos del Apple ID (deliberado)». Es lenguaje de la era CloudKit —«tokens», «Apple ID»— y en el canal
backend **no ocurre**: el cursor no se resetea y no hay re-descarga. Quien lea la función se queda con
que el borrado es recuperable, y no lo es. Misma familia que el docblock DARK de
`GroupBackendInviteService` (corregido en `cd87cf3a`).

## Cómo verlo (esto es raro y valioso en esta familia)

**Reproducible en simulador**, sin dos cuentas reales ni build de distribución:

1. `Yala Dev` (staging sirve la sesión secundaria al 100 %).
2. Entrar en sesión secundaria.
3. **Forzar el canal apagado** con el toggle «simular remoto OFF» de `CloudSyncDebugView`
   (`CloudSyncDebugView.swift:891` → `cloudSync.debug.remoteFlagsForceOff`, leído en
   `CloudRemoteConfig.swift:188`, solo bajo `DEV_BUILD`).
4. Llegar al Welcome por la vía 5 («Vaciar mis datos» en sesión) y tocar «Es mi primera vez».

Casi todos los bugs de esta familia exigen dos cuentas y TestFlight; este no.

## Criterio de hecho

- Tabla de `decide` ampliada: **con `secondaryActive == true` el resultado es `.secondary` para los DOS
  valores del flag**. Mutación a exit 65 al devolver el `&&`.
- Source-scan del único call-site (lo que decide es QUIÉN llama y con qué, molde `AttestWiringTests`).
- El cinturón del wipe con su propio test y su mutación.
- QA en simulador con la receta de arriba: el alert del Welcome ya no cuenta los grupos del dueño.

## Orden (decisión del owner, 2026-08-13)

**Va DESPUÉS de [[prefs-dominio-por-sesion-secundaria]].** Los dos ficheros principales de este fix
—`SwiftDataConfiguration.swift` y `DataWipeService.swift`— son los mismos donde aterriza el dominio de
preferencias por sesión (`performSecondaryEntryTasksIfNeeded`, `performSecondaryWipeIfArmed`,
`removeUserPreferenceKeys`). Atacarlos en paralelo es la receta conocida de dos sesiones que se
arrastran.

## Relacionados

- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — el ticket padre, con las ocho vías
- [[prefs-dominio-por-sesion-secundaria]] — va primero
- [[qa_welcome-empiezo-de-cero-borra-antes-de-preguntar-y-falla-mudo]] — el mismo alert, otro humano

migrated from YalaWiki Bugs/secundaria-canal-apagado-la-visita-borra-los-grupos-del-dueno.md @ 1934e8ad
