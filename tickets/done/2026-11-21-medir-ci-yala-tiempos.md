---
id: 2026-11-21-medir-ci-yala-tiempos
status: done
priority: medium
area: platform
created: 2026-11-21
updated: 2026-11-21
source: "pedido de Jürgen, 2026-11-21 06:11 (prompt de X sobre CI rápido sin mentir)"
---

# Medir cuánto tarda el CI de Yala y proponer cómo bajarlo

## Qué se pidió

Medir los últimos 150 runs de PR, separar espera, preparación y ejecución con p50 y p95, ver cuánto
esperan las sesiones y proponer mejoras con ahorro y costo. Sin cambiar nada del CI.

## Qué salió

- Informe: `docs/auditorias/2026-11-21-ci-tiempos.md` y artifact
  https://claude.ai/artifact/7WNMaTYGyeDUkAbUXve2oM
- Hoy un PR que compila tarda 66 min p50 y 101 min p95; uno de docs, 3,5 y 4,3. Las sesiones
  esperaron 96 h en 4,7 días.
- Siete propuestas, ninguna encolada. Proyección con las cuatro primeras: ~27 min p50, ~40 p95.

## Lo que queda en Jürgen

- Mirar en Settings → Billing si el runner macOS se cobra (la regla `ci-qa.md` dice que sí; la
  documentación de GitHub y el volumen apuntan a que no).
- Elegir qué propuestas pasan a encargo.
