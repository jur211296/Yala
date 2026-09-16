---
id: cloud-hydration-spinner-never-gives-up-without-attest
status: backlog
priority: medium
area: "modo-nube, attest, copy"
created: 2026-09-15
updated: 2026-09-15
source: "review adversarial de `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` (2026-09-15)"
---

# «Descargando tus datos…» gira para siempre en un teléfono que no consigue App Attest

## El problema, en lenguaje de usuario

Estreno teléfono, entro en mi cuenta de la nube y la app me dice «Descargando tus datos…» con una ruedecita. No
baja nada nunca, y la ruedecita no para. Desde ayer, además, encima sale un aviso que dice que este teléfono no
puede sincronizar — o sea, la app me está diciendo las dos cosas a la vez.

## Lo medido (leído en el código, sin ejecutar)

`CloudHydrationLogic.showBanner` tiene tres términos y **ninguno mira el attest**
(`Yala/App/Views/Shared/CloudHydrationBanner.swift:36-44`):

```swift
guard !firstPullCompleted else { return false }
return cloudEngineActive && storeLooksEmpty
```

Con el veredicto de attest terminal, los tres se quedan fijos:

- `CloudSyncRuntime.performCycle` devuelve `.accountUnavailable` y el loop pone `state = .stoppedUntilRelaunch`
  (`CloudSyncRuntime.swift:477`), que está **pegado a propósito** (sin loop) hasta relanzar.
- Así que el primer pull no completa nunca ⇒ `firstPullCompleted` sigue `false`. Y es de sesión de proceso: renace
  `false` en cada arranque, así que relanzar tampoco lo cura mientras el attest siga roto.
- El store sigue vacío ⇒ `storeLooksEmpty` sigue `true`.

El banner es un `.overlay(alignment: .top)` sobre el `TabView` (`ContentView.swift:2968-2970`), así que sale en
**todas** las pestañas, Panel incluido.

**La co-aparición con el aviso de attest está inferida de las cuatro condiciones, no ejecutada.** Las dos se cumplen
a la vez en la misma población: teléfono nuevo o recién adoptado, en `.cloud`, con sesión y sin conseguir attest. A
las 24 h el Panel enseña «Descargando tus datos…» girando y, debajo, «Este teléfono no puede sincronizar tus datos».

**El spinner eterno es PREEXISTENTE** —vive desde que existe el banner de hidratación— y no lo introdujo el aviso;
lo que el aviso hace es volverlo contradictorio a la vista. Antes la persona solo veía la ruedecita y no sabía por
qué; ahora ve la ruedecita y, al lado, la explicación de que no va a pasar nada.

## Lo que hay que decidir (Jürgen)

1. **El spinner se rinde**: `CloudHydrationLogic` gana un cuarto término (el veredicto terminal) y el banner
   desaparece, dejando solo el aviso de attest, que ya explica el estado. Es la opción más simple y la que deja una
   sola voz.
2. **El spinner cambia de cara**: en vez de desaparecer, dice que la descarga está parada y por qué. Cuesta copy
   nuevo en 16 idiomas y solapa con el aviso de attest, que ya lo dice.
3. **Dejarlo**: la población es estrecha (teléfono nuevo + attest roto más de un día). Pero es justo la persona a la
   que el aviso le dice «usa otro teléfono» — acaba de estrenar uno.

## Relación con otros tickets

- `cloud-tab-does-not-say-this-phone-cannot-sync-personal-data` — de donde sale, y el otro lado de la contradicción.
- `groups-phone-that-never-attests-is-told-to-retry-forever` — de donde sale el veredicto terminal.
