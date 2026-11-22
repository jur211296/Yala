---
id: widget-staged-snapshot-tests-fail-only-in-the-full-suite
status: backlog
priority: medium
area: "tests, widgets"
created: 2026-11-20
updated: 2026-11-22
source: "gate del encargo 2026-11-20-captura-cuenta-automatica-parte-1-implementar"
---

# La foto del widget por etapas falla en `YalaTests` entero y pasa sola

Medido el 2026-11-20 en la Max (iOS 27.2, `Yala Dev`, base `d3759645e` + el cambio de la cuenta sola al leer, que no
toca el widget): en la corrida de `YalaTests` entero (15 448 casos) cayeron tres casos de
`YalaTests/CuelguesHeroWidget/FotoWidgetPorEtapasTests.swift` con 7 expectativas
(`laFotoPedida_cedeElHiloEntreEtapasYQuedaPublicada`, `unCambioDelEspejoAMitad_tiraLaFotoYPideOtra`,
`unGuardadoAMitad_tiraLaFotoYPideOtra`; líneas 81, 84, 87, 103, 110, 126 y 130). Repetida sola, la suite pasa (20/20,
con `SharedStateIsolationTests`).

Las líneas que caen esperan a que la foto arranque y miden el hilo principal (`waitUntilStagedBuildStarts`,
`CuelguesFixture.measureMainThread`, `debugIsStagedBuildRunning`): depende del estado compartido de `WidgetDataCache` o
de la carga de la máquina, sin aislar.

Qué hacer: reproducir con la suite completa (o con las suites que corren antes), mirar qué deja `WidgetDataCache` a
medias, y aislarlo o pasar la prueba a la cuarentena con dueño. Hermano conocido:
`groups-no-session-loss-exit-test-fails-in-the-full-suite` (cayó en la misma corrida).

**Otra vez el 2026-11-22 en la Mini** (gate del encargo del chip de grupo, que no toca el widget): `YalaTests` entero
(15 765 casos) cayó solo en `laFotoPedida_cedeElHiloEntreEtapasYQuedaPublicada` (línea 84, `measured.turns >= 8`). Sola,
la suite pasó 2 de 2.
