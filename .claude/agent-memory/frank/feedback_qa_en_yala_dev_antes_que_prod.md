---
name: qa-en-yala-dev-antes-que-prod
description: En el QA guiado, todo lo que se pueda probar en Yala Dev contra staging va ahí; el TestFlight contra producción solo para lo que exige producción.
metadata:
  type: feedback
---

Al montar una tanda de QA, cada prueba va en **Yala Dev contra staging** salvo que de verdad necesite producción.

**Why:** Jürgen, 2026-10-20: «todo lo que se pueda probar en Yala Dev, mejor, para no contaminar prod». El 19-oct la tanda
del TestFlight 18 dejó cuentas, grupos y movimientos de prueba en producción y hubo que vaciarla a mano.

**How to apply:** solo van al TestFlight las pruebas que dependen de algo que staging no reproduce: actualizar desde la
versión de la App Store (mismo bundle), App Attest en `enforce` (staging va en `observe`), StoreKit de producción o el
contenedor de iCloud de producción. Lo demás (sync, Grupos, iCloud, voz, invitaciones) en Yala Dev instalado con
`devicectl`. Si una card dice «en TestFlight» sin necesitarlo, adáptala. Relacionado:
[[el-guion-se-adapta-al-estado-del-telefono]].
