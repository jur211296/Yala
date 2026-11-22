---
name: project-cuenta-sola-al-leer-parte-2-espera
description: Reglas de captura (parte 2 de la cuenta sola al leer) hechas el 21-nov; qué falta fuera del código y por qué viven en la cuenta
metadata:
  type: project
---

Parte 2 implementada el 2026-11-21; la sesión se paró por el límite semanal y la continuación del 2026-11-22 la llevó
al PR (encargo `2026-11-22-cuenta-sola-al-leer-parte-2-continuacion`). Jürgen
decidió ese día que los nombres y las reglas viajen también en iCloud privado con el permiso de voz y foto versionado.

Falta, fuera de la sesión:
- **CloudKit `CD_captureRulesRaw`** (Dan, Development → Production, dos contenedores) antes de subir NINGÚN build.
- **Supabase producción `g34_01` + Worker v9**: producción corre manifest v8 con los campos de IA ya desplegados.
- **Device-QA**: qué texto da «Tarjeta» de Wallet. Si es genérico, «Paga con Apple Pay» se retira.

**Why:** las reglas viven en `Account.captureRulesRaw` y no en un `@Model` porque el canal de la Nube solo versiona
columnas; una entidad nueva habría exigido versión por tabla en Worker, Merkle y cliente con los iPhone de 2.2 delante.
**How to apply:** si alguien propone pasar las reglas a un modelo propio, ese es el coste; y no subas un build con
reglas sin confirmar el campo de CloudKit en Production.

Relacionado: [[feedback-cuando-la-app-pregunta-al-usuario]].
