---
id: cloud-signout-collapses-every-groups-transient-into-permanent
status: backlog
priority: high
area: "modo-nube, groups, sesión"
created: 2026-09-14
source: "review adversarial de `groups-sync-treats-an-infra-403-as-an-account-verdict`, lente de sync"
---

# Cerrar sesión en la nube culpa a tu conexión de cualquier fallo de grupos

## El problema, en lenguaje de usuario

Tengo una cuenta en la nube con grupos y cambios de grupos sin subir. Pulso «Cerrar sesión». Falla algo
del lado del servidor —un corte de red, un 5xx, un cortafuegos que devuelve 403— y la app me dice
siempre lo mismo: **«Hay cambios sin subir a la nube. Revisa tu conexión e inténtalo de nuevo.»**

Cuando el problema es mi conexión, el aviso acierta. Cuando no lo es —que es la mayoría de las veces que
esto se ve—, me manda a buscar un fallo que no existe, y no me dice lo único cierto: que espere y lo
vuelva a intentar.

## Lo medido (2026-09-14)

`Yala/Services/CloudSync/CloudSessionSignOut.swift:779-784`, paso 2 de `performCloudSecureSignOut`:

```swift
case .blocked(let pending, let reason):
    phase = .blocked(pendingCount: pending,
                     reason: reason == .channelPaused ? .channelPaused : .permanent)
```

**Todo lo que no sea `.channelPaused` se convierte en `.permanent`**, incluido `.transient`. El comentario
de encima lo dice y lo justifica: la excepción del kill-switch se abrió el 2026-09-13 «y los otros motivos
se quedan porque su alert en este camino es una decisión propia y nadie ha pedido cambiarla».

Consecuencias en cadena, todas medidas:

- `.permanent` → `ProfileView.swift:153` → `showSignOutBlockedAlert` con
  `L10n.Settings.signOutBlockedMessage` («revisa tu conexión»).
- **El reintento interno se pierde.** `GroupsSignOutRetryDecision.decide` devuelve `.surfacePermanent`
  para `.permanent`, así que el presupuesto de 45 s que existe justo para los transitorios no se gasta:
  el gesto se rinde a la primera sobre algo que sí se cura esperando.
- La celda hermana **sí** lo hace bien: el cierre de la sesión SOLO-GRUPOS
  (`attemptGroupsOnlyClose`) propaga el motivo tal cual, así que ahí un transitorio se anuncia como
  transitorio y se reintenta.

## Por qué no se arregló de paso

Salió midiendo el cierre de `groups-sync-treats-an-infra-403-as-an-account-verdict`, que llevó el 403 de
infraestructura de `.accountUnavailable` a `.transient`. Ese arreglo cierra el sellado del canal y la
celda solo-grupos, pero **aquí no llega**: el 403 de infra entra en este ternario como `.transient`
indistinguible de una red caída, y sale como `.permanent` igual que antes.

Cambiar el ternario no es tocar el 403: es cambiar el aviso de **todos** los transitorios de este camino
—red caída, 5xx, decode fallido, tope de iteraciones—, que es otro objeto y una decisión de producto.

## Lo que hay que decidir

1. **Propagar `.transient` tal cual**, como ya hace la celda solo-grupos. El aviso pasa a «un momento
   más» y el gesto reintenta 45 s. Coste: ~22 peticiones contra un servidor que quizá esté bloqueando, y
   45 s de espera antes de decir nada.
2. **Propagarlo pero sin reintentar**, con su propio motivo: aviso inmediato y honesto («no pudimos
   subir tus cambios ahora, inténtalo en un rato») sin gastar el presupuesto.
3. **Dejarlo como está** y documentar que en este camino el aviso es deliberadamente conservador.

La 2 es la que más se parece a lo que se decidió para `.channelPaused` el 2026-09-13, y por eso va
primera; pero es una decisión de Jürgen, no una tarea.

## Relación con otros tickets

- `groups-sync-treats-an-infra-403-as-an-account-verdict` — el arreglo que dejó esta celda al descubierto.
- `groups-killswitch-403-blocks-detach-forever` — el que abrió la única excepción que hoy existe aquí.
