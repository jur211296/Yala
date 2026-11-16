---
name: borrar-en-disco-lo-hace-el-bot
description: Si el sandbox niega `rm` y hace falta espacio, pídele al bot de Frank que borre la ruta exacta; solo lo tuyo de esa sesión.
metadata:
  type: feedback
---

Cuando el sandbox niega un `rm` (pasa con `rm -rf` de DerivedData, aunque sea el que creó la propia sesión) y hace falta
espacio, **pídele al bot de Frank que lo borre él con `rm`, dándole la ruta exacta**. No pelees el permiso por otra vía.

**Why:** Jürgen, 2026-11-06, en la construcción de la telemetría propia: «si necesitas más espacio, pide a Frank bot que
elimine con rm lo que digas». Ese día el disco bajó a 6,9 GB, el runner de XCUITest no arrancaba («Timed out waiting
for AX loaded notification», 0 tests) y el `rm` del DerivedData propio (5,9 GB) salía denegado dos veces. Lo autorizó
para ese caso y lo dejó como forma de trabajar.

**How to apply:**
- Solo lo de la sesión: tu DerivedData con `-derivedDataPath` propio, tus `.xcresult`, tu scratchpad. Nunca
  scratchpads ni DerivedData de otras sesiones vivas.
- Mide antes con `du -sh` y di la cifra en el mensaje al bot (`preguntar-bot` o `avisar_grok.py --avisar consulta-bot`).
- Con el disco liberado, reinicia y calienta el simulador (`qa/scripts/ci-calentar-simulador.sh` bajo `sim-lock.sh`)
  antes de repetir el XCUITest: es lo que lo dejó correr. Ver [[ax-loaded-timeout-se-cura-reiniciando]].
- Mejor aún: no crear un DerivedData nuevo para un build suelto; usar el de siempre (`/Volumes/ExtDev/DerivedData`).
