---
id: invite-recovery-relaunches-for-a-mirror-it-never-uses
status: backlog
priority: medium
area: "modo-nube, groups"
created: 2026-09-11
updated: 2026-10-08
source: "medido de camino en la mitad 2 de `groups-entry-on-a-mirrored-store-still-blocks-the-owner` (2026-09-11)"
---

# «Tengo una invitación» cobra un relanzamiento para encender un espejo que su camino no usa

## El síntoma, en lenguaje de usuario

Instalo Yala porque alguien me invitó a un grupo. Toco «Vengo por un grupo → Tengo una invitación» y la
app me dice **«Un último paso: reabre Yala»**. Cierro, abro, y sigo. La otra card del mismo paso —«Crear
mi primer grupo»— no me pide nada.

## Lo medido (2026-09-11)

`WelcomeMirrorRelaunchLogic.requiresMirror` devuelve `true` para `.inviteRecovery`, y el docblock declara
por qué:

> `inviteRecovery` no necesita el mirror para su propio trabajo —el CKShare va por el container de
> Grupos— pero su destino es usar la app con datos personales, así que cae del mismo lado que el
> onboarding privado. Sesgo deliberado.

**Esa premisa la invalidó el paso 5 del rediseño de sesiones.** Un invitado que entra por el Welcome hoy
monta una sesión **solo grupos**, que por definición no crea corpus personal: es la misma razón por la
que su hermana `.groupsOrganizer` está en la lista de `false`, y las dos cards salen del mismo step.

## El doble coste

1. **Una pantalla de más** en el alta de un usuario nuevo, que es la puerta de captación.
2. **Y el espejo queda adjunto**: tras reabrir, el store personal monta con CloudKit, así que los gastos
   de grupo que el invitado registre se exportan al iCloud del Apple ID de ese teléfono. Es la otra mitad
   del daño que describe `groups-invite-on-a-mirrored-store-crosses-data` — aquí llega por la vía
   contraria, desde un teléfono que estaba limpio.

## Criterios de aceptación

- [ ] `requiresMirror(.inviteRecovery)` pasa a `false` y su fila queda documentada con la premisa nueva.
- [ ] Un invitado en instalación fresca no ve ninguna pantalla de «reabre Yala».
- [ ] No-regresión: quien llega a `.inviteRecovery` desde una sesión que SÍ tiene datos personales
      (el caso del docblock viejo) sigue funcionando — comprobar quién más produce ese destino.
- [ ] `NeutralMountRelaunchZeroTests` (que pinnea la tabla) se actualiza con la razón, no solo con el valor.

## Cómo se prueba

- Unit: la tabla de `requiresMirror` y sus consumidores.
- XCUITest: la card de unirse desde una instalación fresca no monta el step `.mirrorRelaunch`.
- Device-QA: que el store del invitado no espeje (panel DEBUG, `personalStoreMountedDecision`).

Triage 2026-10-08: abierto · medium → medium · `requiresMirror` sigue devolviendo `true` para `.inviteRecovery` con el docblock viejo (`WelcomeMirrorRelaunchLogic.swift:98`); el único cambio posterior es `5bb3b4ea5`, del mismo 11-sep.
