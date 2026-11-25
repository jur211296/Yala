---
id: 2026-11-25-observar-iphone14-en-vivo
status: done
priority: medium
area: "qa, rendimiento, cuenta"
created: 2026-11-25
updated: 2026-11-25
source: "pedido de Jürgen, 25-nov 17:07 Lima"
---

# Observar en vivo el iPhone 14 mientras Jürgen usa Yala Dev

Sesión de solo mirada sobre el iPhone 14 de pruebas (Yala Dev 2.3 build 10, base dev limpia): tiempos de arranque,
bienvenida → Panel, esqueleto → datos, nube, hojas y guardado; y lo que no debería pasar. Sin tocar el teléfono ni el código.

Bitácora y evidencia: `docs/qa/observacion-iphone14-2026-11-25/`.

## Hecho cuando

Bitácora con tiempos en hora de Lima, cada hallazgo con evidencia, cada reporte de Jürgen contestado, una card de bug 2.3
por hallazgo real y lotes de arreglo propuestos sin encolar.

## Resolución (2026-11-25)

Observación de 17:10 a 17:58 (Lima). Doce hallazgos reales con evidencia, cada uno con su card de 2.3 en el tablero, y tres
lotes de arreglo propuestos sin encolar. Tiempos medidos: todo bajo 3 s salvo «Verificando tu cuenta…» con Google (3-6 s),
eliminar la cuenta (4-8 s) y cargar los datos al volver a entrar (5-11 s). Sin crashes ni avisos de memoria. El detalle está
en `docs/qa/observacion-iphone14-2026-11-25/bitacora.md`.
