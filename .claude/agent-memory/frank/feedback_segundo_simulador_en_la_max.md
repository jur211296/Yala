---
name: segundo-simulador-en-la-max
description: En la Max, si otra sesión (de otro proyecto) ocupa el simulador, se puede abrir un segundo (tope 2) o usar el iPhone 14 por Device MCP; en la Mini, tope 1
metadata:
  type: feedback
---

En la **Max**, si otra sesión de otro proyecto ya usa un simulador, abre un segundo (tope 2 en esa máquina) o usa el
iPhone 14 conectado por Device MCP. No te quedes esperando el simulador ajeno. En la **Mini** el tope sigue siendo 1.

**Why:** Jürgen, 2026-11-06: las sesiones se bloqueaban esperando el simulador de otra.

**How to apply:** antes de hacer cola en `sim-lock.sh` en la Max, mira quién lo ocupa; si es otro proyecto y la espera
es larga, segundo simulador (por `id=` en `-destination`, nunca más de 2 arrancados). Matiza [[carril-espera-a-cola-a]]
y [[simulador-ajeno-parado-se-pregunta]] solo en la Max.
