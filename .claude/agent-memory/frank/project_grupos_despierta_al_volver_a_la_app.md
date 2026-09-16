---
name: grupos-despierta-al-volver-a-la-app
description: PR #179 — volver a Yala corta el backoff del loop de Grupos; deja un ticket nuevo del piggyback con el motor personal parado y un mutante declarado sin test.
metadata:
  type: project
---

**PR #179 (2026-09-16): volver a primer plano despierta el loop de Grupos en vez de dejarle el backoff
entero** (hasta 5 min). Cierra `groups-loop-in-backoff-ignores-the-return-to-foreground` en `done`, sin
device-QA: reproducirlo pide cortar la red con cambios sin subir y no hay seam de simulador que lo monte.

**Why:** decisión de Jürgen del 2026-09-15, opción 1 — copiar el molde del runtime personal, que corta su
sueño en `handleBecameActive`. El canal de Grupos **está encendido en producción** (`groupsBackendCompiledDefault
= true` desde el 2026-07-30; el flag remoto solo puede matarlo), así que el bug afectaba a gente real.

**How to apply:**

- **Lo que queda abierto y es del mismo hilo:** `groups-has-no-cadence-when-the-personal-runtime-is-stopped`
  (backlog, low). Con el runtime personal en `.stoppedUntilRelaunch`, Grupos se abstiene de su loop porque
  `canRunDomain()` no mira el estado del runtime — ahí no hay loop que despertar y el foreground no lo salva.
- **Un mutante SOBREVIVE y está declarado** en el ticket y en `qa/coverage-index.json`: publicar el `napTask`
  sin comprobar la generación. Si alguien lo toca, el escenario es «el loop nuevo duerme antes que el viejo».
- **Residuales aceptados**, para no re-litigarlos: el wake corta también la cadencia sana de 60 s (paridad con
  el personal) y sin red cada vuelta a la app suma un escalón de backoff.
- El rastro en campo es `GroupsSync loopWoken trigger=foreground sleeping=<bool>`; el bit `sleeping` separa
  «le quité cinco minutos» de «empujé un loop que no esperaba».

Relacionado: [[lo-que-saco-a-una-tarea-aparte-pierde-garantias]] (el defecto serio que cazó la review) y
[[la-asercion-que-no-puede-fallar]] (décimo eslabón, nacido en este PR).
