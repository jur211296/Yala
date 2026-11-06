---
name: gate-en-serie-tambien-contra-ti
description: Los pasos del gate que usan el simulador o el DerivedData van en serie también entre tus propias corridas; en paralelo se agota la cola o se bloquea el build.db
metadata:
  type: feedback
---

No lances `gate-ci-checks.sh` ni un `xcodebuild build` mientras tu propia corrida de tests tiene el simulador o compila
en el mismo DerivedData. El 2026-11-05 («Tu IA registra en Yala») el banco `sim-lock-test.sh` esperó 15 min a MI
XCUITest y salió 75 (rojo de cola, no de test), y dos builds chocaron con mi propio `test` («build.db is locked»).

**Why:** la cola del simulador y el build.db no distinguen dueños: el paralelismo que ahorra minutos en otras tareas
aquí cuesta repetir el paso entero.

**How to apply:** orden fijo — builds → `YalaTests` → XCUITest → `gate-ci-checks.sh`, uno tras otro. Mientras corre
uno, adelanta docs, tickets o el cuerpo del PR, no otro paso del gate. Relacionado: [[encargo-sin-simulador-y-el-gate]].
