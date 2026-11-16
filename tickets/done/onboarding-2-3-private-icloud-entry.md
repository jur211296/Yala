---
id: onboarding-2-3-private-icloud-entry
status: done
priority: high
area: "bienvenida 2.3"
created: 2026-11-12
updated: 2026-11-12
source: "docs/onboarding-2-3/SPEC.md, card Y23-03 · lote 02 de la bienvenida 2.3"
qa-status: passed
qa-date: 2026-11-12
qa-notes: sin datos sigue a la conversacion y con datos ofrece Traer mis datos, vistos en el simulador y en XCUITest
---

# Entrar con iCloud privado, encajado en la bienvenida nueva

«Entrar con mi iCloud» abre la puerta de iCloud de siempre, ahora sobre el fondo F2. Sin datos sigue a la conversación;
con datos ofrece «Traer mis datos». Con iCloud no hay Grupos en la bienvenida. El reinicio de iCloud privado no se tocó
(cambio técnico aparte). «Volver» desde esta puerta vuelve a la vitrina.

Seam nuevo para probarlo: `-uitest-private-gate-icloud-has-data`.
