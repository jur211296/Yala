---
id: completed-mode-escalates-a-second-groups-only-device
status: discarded
priority: medium
area: "groups, onboarding, sync"
created: 2026-09-11
updated: 2026-10-08
source: "review adversarial del paso 8 del rediseño de sesiones (`full-mode-activation-must-ask-where-personal-data-lives`)"
---

Why: Discarded 2026-10-08. La pieza ya no existe: 2511d0fb9 y 783a4ec9b retiraron OnboardingMode; la shell sale de PrivateSessionMark, que es local y no viaja por el iCloud-KV.

# Activar Yala completo en un dispositivo sube de nivel al otro, que sigue en solo-grupos, y lo deja sin espejo

## El síntoma, en lenguaje de usuario

Tengo Yala en el iPhone y en el iPad, los dos solo para grupos y con el mismo Apple ID. En el iPhone activo
Yala completo → privado. Al rato, el iPad aparece también en Yala completo sin que yo haya tocado nada:
Panel, cuentas y presupuestos vacíos. Y lo que registre en el iPad no llega nunca al iPhone, ni al revés.

## Por qué pasa

Medido en este árbol (2026-09-11):

- `FullModeActivationView.completeFullActivation` escribe `onboardingMode = .completed` por
  `PreferenceSyncService`. En una sesión privada (`.icloud`) eso viaja al iCloud-KV del Apple ID, y el merge
  del modo es never-downgrade: `.completed` (rank 2) gana al `.groupInvite` (rank 1) del iPad.
- El iPad sigue con el neutro solo-grupos armado, y `SwiftDataConfiguration.shouldMountNeutralDurable`
  monta neutro con `groupsOnlySessionArmed && persistedMode == .icloud && !mirrorOffArmed`, **sin mirar el
  modo de onboarding** ⇒ shell completa sobre un store sin espejo, en cada arranque.

Inferido y no medido en device: que el `.completed` llegue al iPad por el iCloud-KV con la app abierta. No lo
introdujo el paso 8 —la escritura de `.completed` ya estaba y el neutro es del paso 5—, pero con el paso 8 la
activación pasa a ser un recorrido de producto.

## Alcance

Una decisión de Jürgen, con dos caminos:

- **No escalar**: el modo de un dispositivo solo-grupos no sube por el iCloud-KV mientras lo personal no se
  haya elegido en ESE dispositivo.
- **Escalar preguntando**: el dispositivo que recibe `.completed` abre la activación (chooser y puerta de
  iCloud) en vez de montar la shell completa a ciegas.

En los dos casos, el neutro solo-grupos no puede sobrevivir a un modo completo.

## Criterios de aceptación

- [ ] Dos dispositivos solo-grupos con el mismo Apple ID; uno activa Yala completo → el otro no queda en una
      shell completa sin espejo.
- [ ] Un test fija la combinación «neutro solo-grupos armado + modo completo» en la tabla de mounts.

## Medido en 2.1 (triage 2026-10-08)

- `OnboardingMode` tiene cero ocurrencias en `Yala/`; `completeFullActivation` (`FullModeActivationView.swift:573`) ya no escribe `.completed`, sino `sessionState.hasPrivateSession = true`.
- `PrivateSessionMark.swift:19-24`: la marca vive en `UserDefaults` con prefijo `cloudSync.`, «Nunca al iCloud-KV». Lo dice porque el flag anterior viajaba con never-downgrade y recortaba la shell de otro dispositivo, que es este bug.
- Sin escalado por el KV, el iPad sigue sin sesión privada: su shell es solo-grupos y el neutro sin espejo es lo que le corresponde (`ShellModeLogic.effective(hasPrivateSession:)`).

Triage 2026-10-08: descartado · medium → — · la pieza ya no existe: 2511d0fb9 y 783a4ec9b retiraron `OnboardingMode` y la shell sale de `PrivateSessionMark`, que es local y no viaja por el iCloud-KV.
