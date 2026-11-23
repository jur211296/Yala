---
id: foto-widget-por-etapas-test-falls-under-load
status: backlog
priority: low
area: "widgets, pruebas"
created: 2026-11-22
updated: 2026-11-22
source: "gate de `welcome-returns-after-the-account-is-ready` (2026-11-22, Mini)"
---

# `FotoWidgetPorEtapasTests` cae con la máquina cargada

**Lo medido:** en la corrida entera de `YalaTests` (15 790 tests) cayó
`laFotoPedida_cedeElHiloEntreEtapasYQuedaPublicada()` en `FotoWidgetPorEtapasTests.swift:84`:
`Expectation failed: measured.turns >= 8`. En paralelo corría `gate-ci-checks.sh` (bancos de scripts), que carga la
máquina. Sola, con `-test-iterations 3`: 3/3 en verde.

**Inferido, sin medir:** la prueba cuenta vueltas del hilo principal durante la foto del widget, y con la CPU ocupada
caben menos vueltas en el mismo tiempo. Si el CI la tumba, es candidata a la cuarentena o a contar etapas en vez de
vueltas.
