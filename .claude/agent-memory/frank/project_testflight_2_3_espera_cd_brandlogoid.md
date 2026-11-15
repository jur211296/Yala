---
name: testflight-2-3-espera-cd-brandlogoid
description: La primera subida de 2.3 a TestFlight (15-nov) quedó parada porque CD_brandLogoID no consta desplegado a Production de CloudKit
metadata:
  type: project
---

La subida de 2.3 (1) a TestFlight quedó en checkpoint nocturno el 2026-11-15: versión puesta y gate verde, sin archivar ni subir.

**Why:** 2.3 añade `CD_brandLogoID` (String, `CD_ScheduledPayment`, logos de suscripción). No hay registro de que esté en Production (Dan solo desplegó `CD_systemRoleRaw` el 14-nov), en la Max no hay token de `cktool` y la consola pide el login de Apple. TestFlight usa Production: sin el campo, iCloud puede rechazar esos pagos. El encargo lo marcaba como decisión de Jürgen.

**How to apply:** al retomar, confirma primero en la consola (o con Jürgen/Dan) que el campo está en Production de `iCloud.com.jurgenschmidt.yala`; los `.ckdb` del repo NO lo prueban (se editan a mano en el mismo commit del feature). Luego archivar y subir dentro del tmux. Relacionado: [[feedback_upload_ok_no_es_build_aceptado]].
