---
name: corrida-pegada-sale-busy
description: Un test-without-building lanzado justo tras otra corrida del mismo simulador muere con RequestDenied «Busy (Application failed preflight checks)» — no es veredicto; deja 60 s.
metadata:
  type: feedback
---

Dos corridas de `xcodebuild test-without-building` seguidas sobre el mismo simulador (incluso con `sim-lock.sh`,
que ya garantiza turno) hacen que la SEGUNDA muera al lanzar: `Simulator device failed to launch …
RequestDenied … Busy ("Application failed preflight checks")`, exit 65, cero casos, y ~10 min colgado en el
teardown. Me pasó dos veces el 2026-09-26 (golden del conector); con 60 s de pausa entre corridas, verde.

**Why:** el exit 65 se lee como rojo de test y un mutante «muerto» por esto no mide nada.

**How to apply:** antes de leer un 65, busca `Test run with`; si no está y sí `failed to launch`, es
infraestructura. Encadenando corridas (escritura → verificación → mutante), mete `sleep 60` entre ellas en el
comando de fondo. Relacionado: [[suite-completa-sin-memoria]], [[dos-corridas-un-simulador]].
