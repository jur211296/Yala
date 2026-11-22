---
name: ia-ampliada-100-y-conector-espera-a-dan
description: 22-nov: Yala IA ampliada al 100 % en producción (medición de 2 semanas hasta ~6-dic); conector MCP de producción preparado en mcp.yala-app.pe, espera a Dan
metadata:
  type: project
---

- **IA ampliada** (`AI_CLOUD_EXPLORE_ROLLOUT_PERCENT`) al 100 % en producción desde el 22-nov, 05:12 Lima. Su card
  («Encender Yala IA ampliada…») solo se cierra tras dos semanas de medición de cuota y coste (decisión 3A): revisar
  `chat.explore` en `yala_ai_usage` hacia el 2026-12-06. Marcha atrás en `gateway/RUNBOOK.md`.
- **Conector MCP de producción**: `mcp.yala-app.pe` libre y reservado; el de pruebas en `mcp-staging.yala-app.pe`;
  KV creado. Falta todo lo de Supabase de producción y el despliegue: lo hace Dan (decisión 64). No lo intentes desde una
  sesión de Frank sin que el encargo autorice tocar Supabase de producción.
- **Navegadores conectados** llegan a usuarios con la 2.3; device-QA con TestFlight de producción y cuenta real.

**Why:** tres decisiones de la auditoría del 21-nov que esperaban a la 2.2 publicada.
**How to apply:** si un encargo vuelve a pedir el conector «en producción», mide primero si Dan ya desplegó
(`curl https://mcp.yala-app.pe/`) antes de repetir nada.
