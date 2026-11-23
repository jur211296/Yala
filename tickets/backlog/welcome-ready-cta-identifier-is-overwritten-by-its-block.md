---
id: welcome-ready-cta-identifier-is-overwritten-by-its-block
status: backlog
priority: low
area: "bienvenida, pruebas"
created: 2026-11-22
updated: 2026-11-22
source: "sesión de `welcome-returns-after-the-account-is-ready` (2026-11-22), medido en el árbol de XCUITest"
---

# El botón de las pantallas de «cuenta lista» no lleva el identificador que declara

**Lo medido (iPhone 17 Pro, iOS 27.2):** `WelcomeCloudSignInView.readyContent` pone `\(id)_cta` al botón y `id` al
bloque que lo contiene. En el árbol de accesibilidad el botón sale como `welcome_born_cloud_ready` (y
`welcome_reentry_ready`), igual que el título y el cuerpo: el id del bloque pisa al del botón
(`.claude/rules/testing.md`). `welcome_reentry_ready_cta`, `welcome_born_cloud_ready_cta` y
`welcome_signup_existing_account_ready_cta` no existen en ninguna pantalla.

**Por qué importa:** el docblock de `readyContent` dice que el device-QA distingue las terminales por esos ids. Hoy un
XCUITest o un guion que busque `…_cta` no encuentra nada; `WelcomeTrasCuentaListaUITests` usa el del bloque.

**Arreglo propuesto:** mover el `accessibilityIdentifier(id)` del `VStack` al título (o a un `accessibilityElement`
propio), comprobar en el árbol que el botón sale con `…_cta` y cambiar la prueba a ese id. No cambia nada visible.
