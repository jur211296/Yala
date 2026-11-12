---
id: onboarding-2-3-showcase-and-access-buttons
status: done
priority: high
area: "bienvenida 2.3"
created: 2026-11-12
updated: 2026-11-12
source: "docs/onboarding-2-3/SPEC.md, card Y23-01 · lote 02 de la bienvenida 2.3"
qa-status: passed
qa-date: 2026-11-12
qa-notes: vitrina, puerta de Grupos y texto AX5 vistos en el simulador iPhone 17 Pro; XCUITest Bienvenida23AltaUITests
---

# Bienvenida con vitrina y tres accesos

La bienvenida es una vitrina que rota sola con seis funciones reales (foto y voz con PRO, Grupos dentro con «Dividir
gastos con amigos»), se pausa al tocar, se desliza entre funciones y se queda quieta con Reducir movimiento o VoiceOver.
Debajo, «Entrar con Google», «Entrar con Apple» y «Entrar con mi iCloud» (decisión 51: sin «privado»). Fondo F2, solo
oscuro; la mascota tiene su espacio reservado. Sin «Empezar» ni «Ya tengo una cuenta».

Pruebas: `YalaTests/Bienvenida23AltaTests.swift` (`Bienvenida23ShowcaseTests`) y
`YalaUITests/Flows/Bienvenida23AltaUITests.swift`. Capturas en `capturas/` del PR.
