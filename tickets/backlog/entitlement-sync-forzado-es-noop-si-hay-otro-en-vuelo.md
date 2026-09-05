---
id: entitlement-sync-forzado-es-noop-si-hay-otro-en-vuelo
status: backlog
priority: medium
area: pro
created: 2026-09-05
updated: 2026-09-05
---

# El Pro de tu cuenta puede no aparecer al entrar, si el arranque estaba mirándolo

## Qué le pasa al usuario

Entro con mi cuenta de Yala en un teléfono donde el Apple ID es otro. Tengo Pro pagado en esa cuenta.
Termino de entrar y **la app me sigue tratando como si no lo tuviera** hasta que la mando a segundo
plano y vuelvo.

Es exactamente el caso que el código dice existir para evitar: «Sesión nueva: el derecho de esa cuenta
debe aparecer **YA**, no en el próximo foreground» (docblock de `handleSignIn`).

## Por qué pasa

**El mismo patrón que `invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo`** (arreglado el 2026-09-05
en `CloudRemoteConfig`): un `force` que promete saltar el min-interval, pero que se rinde ante un
trabajo que ya está en curso — y el call-site lee el resultado justo después.

Medido en `Yala/Services/CloudSync/AccountEntitlementService.swift`:

```swift
85   guard !isWorking else {
86       if force { forceRequestedWhileWorking = true }
87       return false                                    // ← el force se rinde, y devuelve false
88   }
```

Y el call-site (`:147`):

```swift
147  guard await sync(force: true) else { return }       // ← corta aquí
148  await StoreKitManager.shared.updateSubscriptionStatus()
```

⇒ con un `sync` en vuelo, `handleSignIn` **no llega nunca a `updateSubscriptionStatus()`**, que es lo
único que hace que el Pro se vea.

**Y el reintento no lo salva.** Este servicio sí tiene red —`forceRequestedWhileWorking` y el `Task`
del `defer` (`:94-99`)— así que el sync se re-encola y el snapshot acaba correcto. Pero ese reintento
**descarta su `Bool`** (`:97`, `Task { await self.sync(force: true) }`) y nadie llama a
`updateSubscriptionStatus()` detrás. El dato queda bien en disco y la UI no se entera.

### Quién colisiona con quién (medido, los tres alcanzables)

| Quién arranca el `sync` | Coordenada |
|---|---|
| Boot / foreground, sin `force` | `AppBootstrapper.swift:2329` |
| Post-compra, con `force` | `StoreKitManager.swift:208` |
| **Post-sign-in, con `force`** | `CloudAuthService.swift:316` → `handleSignIn` |

La ventana es la de siempre: el arranque dispara el suyo y el sign-in cae encima. **No medí** con qué
frecuencia coinciden en la práctica — lo que sí está medido es que las tres rutas existen y que las
tres pasan por el mismo `guard`.

## Arreglo propuesto

**No copiar el arreglo del remote-config sin pensarlo.** Ahí la solución fue esperar al fetch en vuelo
porque no había reintento; aquí SÍ lo hay, y encadenar esperas sobre un servicio que ya se re-encola
puede ser peor. Dos formas más baratas, por orden:

1. **Que el reintento del `defer` cierre el círculo**: si el `sync` re-encolado cambia el snapshot, que
   llame a `updateSubscriptionStatus()` él mismo. Es donde vive hoy el `Bool` que se tira.
2. **Que `handleSignIn` no dependa del `Bool`**: llamar a `updateSubscriptionStatus()` siempre que la
   sesión sea nueva. Re-derivar de más es barato; no re-derivar es el bug.

## De dónde salió

Review adversarial del arreglo de `invite-refresh-forzado-es-noop-si-hay-otro-en-vuelo` (2026-09-05),
buscando **todas** las instancias del patrón. Las demás que se miraron y **no** son este bug, para que
nadie las vuelva a perseguir:

- `GroupsViewModel` y `GroupDetailViewModel` (`_ = force`, luego `loadData()`): datos rancios un
  instante, los repara el `onChange(dataVersion)`.
- `CloudSessionSignOut`: trata `.coalesced` explícitamente, con reloop de 250 ms. No es hit.
- `GroupsSyncClient.syncNowFromPush`: reporta `.noData` de más al sistema; nadie lee después.
