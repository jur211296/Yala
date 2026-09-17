---
id: cloud-hydration-spinner-keeps-spinning-with-the-engine-stopped
status: backlog
priority: low
area: "modo-nube, sync, copy"
created: 2026-09-17
source: "Paso 0 (D9) y review adversarial de `cloud-hydration-spinner-never-gives-up-without-attest` (2026-09-17)"
---

# «Descargando tus datos…» sigue girando cuando el motor de la nube ya se ha parado

## El problema, en lenguaje de usuario

Tengo mis datos en la nube, entro en un teléfono y la app me dice «Descargando tus datos…» con una ruedecita. La
ruedecita no para, pero la app ya no está intentando bajar nada: se paró hace rato por otro motivo y no me lo dice.

## Lo medido (árbol `2.1` @ `3eed0fb50` más el cambio del ticket de origen)

El banner decide con `CloudHydrationLogic.showBanner` (`Yala/App/Views/Shared/CloudHydrationBanner.swift:56`):
primer pull sin cerrar, `storageMode == .cloud`, la app vacía y, desde el 2026-09-17, el veredicto de App Attest
**no** terminal. **Ningún término mira el estado del motor** (`CloudSyncRuntime.state`). Así que, con el store vacío,
el spinner gira mientras el motor está parado por algo que no es el veredicto:

- **Parado por el presupuesto de la puerta de attest, las primeras 24 h.** Un `.unavailable` tras tres fallos seguidos en
  el mismo proceso es `.terminal` (`AttestSyncGate.swift:63-64`), `performCycle` devuelve `.accountUnavailable`
  (`CloudSyncRuntime.swift:548-551`) y el loop queda en `stoppedUntilRelaunch` (`:487-490`). El veredicto de la racha
  necesita 24 h y 3 rechazos contados de hora en hora, así que durante ese día el spinner gira con el motor parado.
  Relanzar da otros cuatro intentos y vuelve a parar.
- **Parado por un 403.** `SyncCadencePolicy.nextAction` convierte `.accountUnavailable` en `stopUntilRelaunch`
  (`SyncCadencePolicy.swift:103-104`), y el cliente lee así un 403 (`SyncPullClient.swift:208`). **Hoy el gateway no
  emite 403 en `/sync/*`** (ningún `403` en `gateway/src/sync/routes.ts`), así que este camino no se alcanza.
- **Sin sesión.** `start(context:)` deja el motor en `idleSignedOut` sin `currentUserID` (`CloudSyncRuntime.swift:365-368`).
  Con `storageMode == .cloud` y la app vacía, el spinner gira sin nadie que pueda bajar nada.
- **Parado hasta volver a entrar** (`stoppedUntilSignIn`, `SyncCadencePolicy.swift:101-102`). Exige cambios pendientes, así
  que la app casi nunca está vacía. Pero `storeLooksEmpty` llega congelado al montar
  (`cloud-hydration-banner-does-not-see-data-that-arrives-after-mount`).

**Población, inferida:** pequeña. Un iPhone real atesta, así que el primer caso es casi siempre el simulador. El 403 no
se emite, y quedarse sin sesión en `.cloud` con la app vacía es raro.

## Lo que hay que decidir (Jürgen)

1. **El spinner mira el motor.** Solo gira con el motor corriendo (`.running`). Es honesto, pero `CloudSyncRuntime` no es
   `@Observable` (`CloudSyncRuntime.swift:84`) y habría que leer su `state` en el mismo tick. Cuando se para, la pantalla se queda vacía y sin
   explicación, igual que con el veredicto terminal fuera del Panel.
2. **El spinner cambia de cara cuando el motor se para**, con un «No pudimos descargar tus datos» genérico. Es copy nuevo
   en 16 idiomas y hay que decidir qué ofrece (¿relanzar? ¿entrar?).
3. **Dejarlo.** La población es pequeña y el caso gordo, el teléfono sin App Attest, ya lo cierra el veredicto a las
   24 h.

## Relación con otros tickets

- `cloud-hydration-spinner-never-gives-up-without-attest` (done) — de donde sale: cerró el caso del veredicto terminal y
  dejó este fuera a propósito.
- `cloud-hydration-banner-does-not-see-data-that-arrives-after-mount` — el otro término del banner que no se re-evalúa.
- `groups-has-no-cadence-when-the-personal-runtime-is-stopped` — el mismo motor parado, visto desde Grupos.
