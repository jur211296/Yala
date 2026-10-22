---
name: faro-solo-encamina
description: Paso 6 del rediseño de sesiones — el faro de iCloud-KV solo encamina: «Crear otra cuenta», mismatch con dos salidas y faro huérfano que se limpia con PRUEBA. Device-QA pendiente en su mitad de sign-in real; `restore-beacon-outlives-account-deletion` NO se cerró.
metadata:
  type: project
---

**«Es mi primera vez» con faro ya no decide: encamina y ofrece «Crear otra cuenta» (el chooser entero); el
mismatch tiene dos salidas; y el faro huérfano se apaga cuando [I] lo PRUEBA.** Paso 6 de la cola del
rediseño de sesiones, PR #135 (2026-09-10); el ticket vive en `tickets/qa/` con su guion de device-QA.

**Why:** ADR 2026-09-09 §10 más las decisiones de Jürgen del 9-sep: chooser entero, privado incluido; el
faro huérfano se cubre aquí; el copy nombra el proveedor y nada más.

**How to apply:**

- **Device-QA pendiente**: tres recorridos en el ticket. Lo que ocurre ANTES de firmar lo cubre un XCUITest
  con el seam `-uitest-fake-beacon`; lo de después —limpiar el huérfano, el mismatch, crear la segunda
  cuenta— necesita un iPhone y va contra producción (crea cuentas reales).
- **La regla del huérfano es de PRUEBA**: mismo hash, o faro de Apple + sesión de Apple. La literal «mismo
  hash» no disparaba nunca tras el fresh start (el uuid cambia). Con Google y otro hash NO se limpia. La
  convención vive en `.claude/rules/swiftdata-cloudkit.md`, con sus dos residuales.
- **`restore-beacon-outlives-account-deletion` NO se cerró**, aunque la decisión lo anticipaba: su §1 ocurre
  bajo el kill-switch, donde no corre [I], y su §2 y §3 siguen intactos. Si Jürgen lo pregunta, es eso.
- **Tres tickets nuevos**: `welcome-cloud-back-leaves-chooser-marked-seen` (el mismo flag del chooser en el
  `onBack` de todas las entradas, anterior al paso 6) y dos de copy que son decisión suya:
  `welcome-beacon-origin-contradicts-not-found-copy` y `born-cloud-signup-lands-on-existing-account-silently`.
- Calibración: 4 lentes, ningún grave, y 19/19 mutantes unitarios con su rojo propio. Ver
  [[review-adversarial-caza-lo-mio]] y [[la-premisa-del-encargo-tambien-se-mide]].
