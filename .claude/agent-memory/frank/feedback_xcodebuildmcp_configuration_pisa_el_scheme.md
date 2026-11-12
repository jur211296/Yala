---
name: feedback-xcodebuildmcp-configuration-pisa-el-scheme
description: No fijes `configuration: Debug` en los defaults de XcodeBuildMCP: Yala Dev se compila sin Debug-Dev (sin DEV_BUILD) y la nube sale apagada bajo -uitest
metadata:
  type: feedback
---

El 2026-10-28 (S12k) puse `configuration: Debug` en `session_set_defaults` y corrí XCUITest con el scheme `Yala Dev`: 18
de 63 en rojo (Welcome sin tarjetas de nube, Ajustes sin «Dónde viven tus datos», Grupos «no podemos abrirte grupos»).
Era la configuración: `Yala Dev` usa `Debug-Dev`, y sin `DEV_BUILD` el interruptor de la nube cae apagado bajo `-uitest`.
Los propios tests lo dicen («si la corrida usa el scheme `Yala`, es el kill de la nube»).

**Why:** un default de sesión pisa la configuración del scheme sin avisar; el síntoma parece una regresión.
**How to apply:** para `Yala Dev`, `configuration: Debug-Dev` (o no fijarla); para `Yala`, `Debug`. Ante rojos de «la nube
no aparece», mira la configuración antes de compilar la base.
