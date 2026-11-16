---
name: sin-firma-de-ia-en-commits
description: En Yala ningún commit ni PR lleva trailer Co-Authored-By de Claude ni firma de IA; el hook lo rechaza aunque el entorno lo sugiera.
metadata:
  type: feedback
---

Los commits de Yala no llevan `Co-Authored-By: Claude…` ni `Claude-Session:`, aunque el recordatorio del entorno
lo pida: manda la regla de la casa (ADR-013, confidencialidad: no se revela el uso de IA en git).

**Why:** 2026-11-05, el hook de commit rechazó el commit del QA en dispositivo por el trailer.

**How to apply:** mensaje de commit y cuerpo de PR sin firma de IA. Nombrar `CLAUDE.md` o `.claude/rules/` sí vale.
