---
id: unit-tests-write-group-amounts-into-the-real-app-group-mirror
status: backlog
priority: low
area: "testing, grupos"
created: 2026-09-26
updated: 2026-10-08
source: "`groups-drain-failure-reads-as-nothing-pending` (2026-09-26), medido en el simulador del gate"
---

# Los unit tests dejan entradas en el espejo real del App Group del simulador

## El problema

Medido el 2026-09-26 en el iPhone 17 Pro del gate (`9D0F6D32`): el directorio `GroupsSyncOutboxMirror/` del App Group
tenía **48 entradas**, todas de `userID = auth-uid-1` y `groupID = zone-1` — fixtures de `GroupsSyncClientTests` /
`GroupsSyncHardeningTests`. El `init` de `GroupsSyncClient` usa por defecto `GroupsOutboxMirror()` (el App Group real), y
unas 150 de sus 168 construcciones en los tests no lo sustituyen.

Consecuencia: cualquier código que lea el espejo real bajo tests depende de lo que otras suites dejaron. Desde
`groups-drain-failure-reads-as-nothing-pending`, «Empezar de cero» cuenta el espejo entero cuando no hay sesión, y sus
tests tuvieron que inyectar el testigo (`GroupsExitWitness`) para no leer esa basura. Un XCUITest que llegue al borrado de
«Empezar de cero» sin sesión en ese simulador la vería también (no medido si alguno llega hoy: el gate de
`groups-drain-failure-reads-as-nothing-pending` lo dirá para los de su área).

## Por dónde va

Que las construcciones de los tests inyecten un espejo temporal (o `nil`) por defecto —un helper de la suite—, y limpiar
el directorio del simulador una vez.

## Criterios de aceptación

- [ ] Una corrida completa de `YalaTests` no deja archivos en `GroupsSyncOutboxMirror/` del App Group.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsSyncClient.init` sigue con `outboxMirror: GroupsOutboxMirror? = GroupsOutboxMirror()` (`Groups/GroupsSyncClient.swift:358`).
- En `YalaTests/` hay unas 184 construcciones de `GroupsSyncClient(` y solo unas 27 pasan `outboxMirror:` en las diez líneas siguientes (conteo con grep, aproximado).

Triage 2026-10-08: abierto · low → low · sigue igual (el espejo real por defecto en casi todos los tests); es higiene de tests que ya obligó a inyectar un testigo, sin efecto en la app.
