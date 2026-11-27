---
name: atribuir-bloqueos-del-iphone-por-dueno
description: Cómo medir y atribuir los bloqueos del hilo principal de Yala en el iPhone 14 (potential-hangs + muestras por dueño) y tres trampas de los guiones (perfilado DEBUG, zsh y args, AX tras la suite larga)
metadata:
  type: reference
---

Medido el 2026-11-26 (lote 4 de eficiencia, Max, iPhone 14 por cable):

- **Bloqueos por dueño**: `xcrun xctrace record --template 'Time Profiler' --device <udid> --time-limit 35s --launch -- com.jurgenschmidt.yala.dev -uitest -uitest-skip-onboarding`, exportar las tablas `potential-hangs` y `time-profile` (el backtrace viene como `tagged-backtrace`) y repartir cada bloqueo por la pila de sus muestras del hilo principal. Guiones en `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-4-recalculo-del-panel-sin-bloquear/scripts/` (`hangs.sh`, `dueno.py`). Separa lo del Panel de lo de la foto de widgets y Spotlight: sin eso, un «máx 1,4 s» se le carga al cambio equivocado.
- **Copia de perfilado**: el `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEV_BUILD $(inherited)"` de `Release-Dev` es único en el pbxproj; buscar por `name = "Release-Dev"` casa primero otro bloque (falló así).
- **zsh**: leer un fichero de argumentos con `${(z)…}` mete «;» por cada salto de línea y `xcodebuild` muere con «Unknown build action ';'» sin correr nada; con una línea por argumento, `${(f)…}`.
- Tras `YalaTests` entero, el primer XCUITest cayó con «Timed out waiting for AX loaded»: reiniciar el simulador y repetir (ya estaba en [[runner-ax-timeout-tras-suite-larga]]; volvió a pasar).
- Ceder el hilo en el cálculo del Panel **alarga en reloj** el arranque en frío (el resto del arranque corre en las pausas): mide CPU ocupada y bloqueos, no solo «Panel listo».
