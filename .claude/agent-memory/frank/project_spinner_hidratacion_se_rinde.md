---
name: spinner-hidratacion-se-rinde
description: PR #189 (encargo de noche del 17-sep) — «Descargando tus datos…» se esconde con el veredicto de App Attest terminal; en done sin device-QA, con un residual del reloj y dos tickets low de decisión
metadata:
  type: project
---

`cloud-hydration-spinner-never-gives-up-without-attest` queda en `done` (PR #189, 2026-09-17), sin
device-QA, igual que el #177: la población (teléfono en la nube sin App Attest un día entero) no se
monta en ningún dispositivo.

**Why:** el caso de verdad es inalcanzable fuera de producción, así que lo cubren la tabla, dos
source-scans y 8 mutantes. Lo que queda abierto no es un olvido:

- **Residual del reloj**, escrito en `.claude/rules/gateway-attest.md`: si las 24 h se cumplen con la
  app delante, un rato sin spinner ni aviso ([[apagar-una-voz-destapa-el-residual-de-la-otra]]).
- **Dos decisiones `low` de Jürgen:** `cloud-hydration-spinner-keeps-spinning-with-the-engine-stopped`
  (el spinner no mira el motor) y `cloud-hydration-banner-does-not-see-data-that-arrives-after-mount`
  (el `.task` se queda con el `storeLooksEmpty` de montar; cambiarlo mueve cuándo desaparece la píldora
  en una hidratación normal).

**How to apply:** si alguien propone gatear el banner por `CloudAttestNotice.isShowing` o por
`.cloudAttestVerdictWatcher`, las dos cosas ya se descartaron con motivo: la primera deja el spinner
sin sesión, y la segunda hace que el spinner y el aviso salgan a la vez. Está en el Paso 0 del encargo.

Relacionado: [[aviso-attest-personal-en-dos-superficies]].
