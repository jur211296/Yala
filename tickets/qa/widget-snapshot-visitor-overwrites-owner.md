---
id: widget-snapshot-visitor-overwrites-owner
status: qa
created: 2026-08-13
updated: 2026-08-26
source: YalaWiki/Bugs/qa_widget-snapshot-sin-sello-la-visita-pisa-los-datos-del-dueno.md
---


# El widget enseña los números de la visita, y se queda con ellos

## El síntoma, en lenguaje de usuario

Le prestas el móvil a alguien para que entre a Yala con su cuenta. Miras tu pantalla de inicio: **tu
widget está enseñando los saldos, los gastos y los presupuestos de esa persona.** Ella cierra sesión y
te devuelve el móvil, y el widget **sigue con sus números** hasta que abres Yala y algo vuelve a
escribir la caché.

Y en la otra dirección: quien está de visita ve, mientras usa la app, un widget con **los datos del
dueño** en la pantalla de inicio.

## Lo medido (2026-08-13, árbol `83c4e22c`)

**El widget no abre ningún store.** `grep ModelContainer YalaWidgets/` da **cero**: `WidgetDataService`
solo decodifica un JSON del App Group (`widget_data_cache`, `:161` / `:208`).

Quien escribe ese JSON es la app: `WidgetDataCache.updateCache(context:)`, y **no tiene un solo gate**
—ni de sesión secundaria ni de nada—:

```
Yala/Services/WidgetDataCache.swift
    static func updateCache(context: ModelContext) {
        let snapshot = buildSnapshot(context: context)
        saveSnapshot(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
```

El `context` es el del store **MONTADO**, que en sesión secundaria es el de la invitada
(`SwiftDataConfiguration`, mount por descriptor). Y el call-site dominante es el **paso 9 del
bootstrap** (`AppBootstrapper.swift:241`), incondicional, más ~12 ViewModels que lo re-lanzan al
guardar.

⇒ **la primera vez que la app arranca con la sesión de la invitada, el widget del dueño pasa a ser el
de ella.** No es un riesgo teórico de un camino raro: es el arranque.

**Y el snapshot no lleva identidad**: `struct WidgetDataSnapshot` (`:150`) tiene divisa, saldos,
transacciones, presupuestos y pagos — **ningún campo dice de quién son**. Sin sello, ni el widget ni
nadie puede saber que lo que tiene en la mano es de otra persona. Es exactamente el defecto que
`OwnerKeyValueStore` cerró para el iCloud KV (`25a36be2`) y que el consent de Grupos cerró con su
snapshot sellado (C1), por la tercera puerta.

## Por qué es un ticket propio y no parte de las prefs por sesión

Es **independiente**: el snapshot se pisa hoy, exista o no un dominio de `UserDefaults` por sesión. No
comparte mecanismo (WidgetKit + App Group vs. `UserDefaults` de la app) ni superficie de test. Decisión
del owner (2026-08-13) al acotar [[prefs-dominio-por-sesion-secundaria]].

## Decisión del owner (2026-08-13)

**Sello + servir los datos de la invitada.** El widget muestra los de quien tiene la sesión abierta
ahora, que es lo coherente con lo que la pantalla está enseñando.

Se descartaron: *congelar lo del dueño en silencio* (el widget seguiría mintiendo sobre quién está
usando la app, y además hoy ya no es el estado real) y *el estado vacío explicativo* (el copy que se
barajó hablaba de un choque iCloud-vs-nube, que es **otro** problema y no éste).

## Lo que hay que resolver al implementarlo

1. **El sello: qué identidad.** El molde es `GroupsConsentState` (snapshot con el `userID` dentro). Aquí
   el candidato es el `activeUserID` del `SecondarySessionStore`, con `nil` = sesión del dueño.
2. **La transición de salida es la mitad difícil, y es donde vive el síntoma peor.** Servir los de la
   invitada mientras dura la visita es fácil; lo que no puede quedarse a medias es el **regreso**: si la
   app no vuelve a correr tras cerrar la sesión, el snapshot de la invitada se queda puesto. Hay que
   decidir si la frontera de SALIDA reescribe el snapshot del dueño (y con qué contexto, porque su store
   puede no estar montado en ese instante) o si el widget, viendo un sello que no case con la sesión
   actual, se declara caducado por su cuenta. **Lo segundo es fail-closed y no depende de que nadie
   corra**, y probablemente es la respuesta.
3. **`reloadAllTimelines()` en cada frontera**, o el sello correcto tarda hasta la siguiente refresco.
4. **La extensión de compartir** (`YalaShare`) no se ha medido en este barrido. Hay que mirarla con el
   mismo instrumento antes de declarar la frontera cerrada.

## Criterio de hecho

- El snapshot lleva sello, y un test de comportamiento con dos identidades: escribir con la de la
  invitada y leer con la del dueño **no devuelve datos**.
- **Mutación obligatoria**: quitar el sello, o quitar la comprobación del lector, tiene que dar exit 65.
- Un source-scan del CONTEO de escritores del snapshot: hoy son ~13 call-sites de `updateCache` y
  cualquiera de ellos puede correr en secundaria; el gate tiene que vivir en la puerta, no en los 13.
- E2E en staging (percent al 100): entrar de visita, mirar el widget, cerrar sesión, **no abrir la app**,
  y comprobar que el widget no se quedó con los datos de la visita.

## Relacionados

- [[prefs-dominio-por-sesion-secundaria]] — el item del que sale, misma frontera y otro almacén
- [[secundaria-la-visita-escribe-en-el-dominio-del-dueno]] — las ocho vías del mismo recorrido

---

## Re-medición e implementación (2026-08-14, árbol `9abdbbe2`)

**Tres afirmaciones del ticket se confirman**, una con matiz: `updateCache` seguía sin gate; el snapshot
seguía sin identidad — pero son **DOS structs**, no una (`WidgetDataCache.swift:150` y
`WidgetDataService.swift:125`), y **divergentes** (la del lector tiene dos campos opcionales por compat);
y `ModelContainer` en `YalaWidgets/` sigue dando cero.

**El punto 4 queda cerrado con medición: `YalaShare` está FUERA de esta frontera.** Es un solo fichero
(`ShareViewController.swift`): escribe una imagen en `PendingImages/` y no toca ni el snapshot ni
`UserDefaults` del App Group.

### Lo refutado, que es lo que cambió el trabajo

1. **El conteo son 48 call-sites en 18 ficheros, no ~13.** El ticket contó el bootstrap y los ViewModels;
   faltaban `TransactionService` (9), `DraftService` (6), `GroupTransactionBridge` (6), cinco Views y los
   dos del `BackgroundTaskManager`. El argumento «el gate va en la puerta» sale reforzado.
2. **El síntoma central de la SALIDA ya estaba cubierto.** `CloudSessionSignOut.performSecondaryCloudSignOut`
   llama `clearLocalSurfacesForArmedWipe()` in-session justo tras armar el wipe, y eso hace
   `WidgetDataCache.clearCache()` + `reloadAllTimelines()`. Su docblock nombra literalmente el escenario del
   ticket («o no vuelve a abrir la app nunca»). Y es la ÚNICA salida: la precedencia de
   `CloudSignOutFlowLogic` es congelada y el borrado de cuenta está bloqueado en secundaria.
3. **La ventana post-clear no es alcanzable por BGTask** (hipótesis propia, refutada midiendo):
   `RelaunchNetLogic.shouldExitOnBackground` mata el proceso al ir a background en `.awaitingRelaunch`.

### El hueco que sí estaba vivo

**La ENTRADA no limpiaba in-session.** `confirmSecondaryEntry` activaba el descriptor y pasaba a
`.relaunchSecondary`; la purga de entrada es un hook PRE-MOUNT, o sea que solo corría en el arranque
siguiente. En esa ventana el teléfono lo tiene la invitada y el widget de la pantalla de inicio seguía con
los saldos del DUEÑO. Asimetría exacta con la salida.

### Lo implementado

- **`WidgetSessionSeal`** (`Yala/App/Logic/Helpers/`), añadido al target del widget por el exception set del
  `.pbxproj` — molde `WidgetAmountSplitter`. Sin eso el criterio de hecho no era expresable: `YalaTests` no
  alcanza a `WidgetDataService`, y una réplica no prueba nada del código que corre en el teléfono.
- **El sello cuelga del DESCRIPTOR, no del snapshot.** Publicarlo junto al snapshot habría movido las dos
  mitades a la vez y el sello no protegería de nada. Retirado detrás de `SecondarySessionStore.clear` ⇒ un
  snapshot de la invitada que sobreviva deja de servirse **corra o no corra el `clearCache()`**.
- **La puerta** en `updateCache`, con el predicado **idéntico** al gemelo `NotificationService.isPersonalWipeArmed`
  (cubre también el cierre `.cloud` del dueño).
- **La limpieza in-session de la entrada**, simétrica con la que la salida ya tenía.
- Hash SHA-256 truncado, no el `sub` en claro (decisión del owner): el App Group persiste en el disco del
  dueño y el lector solo compara igualdad.

### Verificación

`YalaTests` completo: **5900/5900**. `WidgetSessionSealTests`: 20 tests en 3 suites.
**6 mutantes a exit 65** — lector, sellado, orden del republish, puerta, limpieza de entrada, default del
seam. El del sellado **sobrevivía** a la primera versión de la suite (18 verdes con el escritor roto): un
sello tiene tres patas y cubrir dos pasa en verde. El del seam cae **solo en el escáner**, con los cinco de
comportamiento en verde.

### Lo que NO está verificado y es del owner

El e2e en device: entrar de visita, mirar el widget, cerrar sesión, **no abrir la app**, y comprobar que el
widget no se quedó con los datos de la visita. Desde el repo no se puede declarar.

### Commit

`f05cc26a` — *fix(widget): el sello que impide que los números de la visita sobrevivan a la visita*

| Archivo | Qué cambia |
|---|---|
| `Yala/App/Logic/Helpers/WidgetSessionSeal.swift` | NUEVO. La lógica pura del sello, compartida con el target del widget vía el exception set del `.pbxproj` |
| `Yala/Services/WidgetDataCache.swift` | El snapshot lleva sello; `updateCache` gana la puerta; `republishActiveSeal` publica desde el descriptor |
| `YalaWidgets/Services/WidgetDataService.swift` | El lector compara el sello y trata lo que no case como «sin datos» |
| `Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift` | La entrada limpia el widget in-session (el hueco vivo) y publica el sello tras activar el descriptor |
| `Yala/Utils/SwiftDataConfiguration.swift` | Los dos hooks de frontera republican; el de salida, DETRÁS del `clear` |
| `YalaTests/WidgetSessionSealTests.swift` | NUEVO. 20 tests en 3 suites |
| `YalaTests/TestProcessGuard*.swift` | La key del sello entra en la protección de proceso del App Group |

### Decisiones, con su porqué

1. **El sello cuelga del descriptor y no del snapshot.** Es lo único que separa fallar cerrado de fallar
   abierto: si lo publicara `updateCache`, las dos mitades se moverían juntas y un snapshot superviviente
   traería su sello válido al lado.
2. **Hash SHA-256 truncado, no el `sub` en claro** (owner). El App Group persiste en el disco del dueño y
   el lector solo compara igualdad — no hay motivo para dejarle ahí el identificador de la invitada.
3. **La puerta usa el predicado literal del gemelo de notificaciones**, así que cubre también el cierre
   `.cloud` del dueño. Dos respuestas para la misma pregunta es el anti-patrón que el repo persigue.
4. **La lógica pura vive en `Yala/` y compila en el widget.** Sin eso el criterio de hecho no era
   expresable: el test habría probado una réplica, no el código del teléfono.

### Qué tiene que mirar el QA en device

Entrar de visita con otra cuenta, mirar el widget (debe enseñar los datos de ELLA), cerrar su sesión,
**no abrir la app**, y comprobar que el widget no se quedó con sus números. Y la mitad nueva: al confirmar
la ENTRADA, antes de reabrir, el widget ya no debe enseñar los saldos del dueño.

migrated from YalaWiki Bugs/qa_widget-snapshot-sin-sello-la-visita-pisa-los-datos-del-dueno.md @ 1934e8ad
