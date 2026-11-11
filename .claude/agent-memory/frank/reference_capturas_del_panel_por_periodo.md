---
name: capturas-del-panel-por-periodo
description: El menú de período, las píldoras del hero y los chips de Estadísticas no aceptan toques de axe; el período se fija con -defaultPeriod y tras conducir con axe el XCUITest puede no arrancar
metadata:
  type: reference
---

Medido el 2026-11-11 en el iPhone 17 Pro (iOS 27.2), capturando el antes y el después del vocabulario del Panel:

- **El menú de período del Panel no responde a `axe tap`** (ni por etiqueta ni por coordenadas: se abre y no elige).
  El período se fija al lanzar: `-defaultPeriod thisMonth` / `lastMonth` (raw de `DetailPeriod`), junto a
  `-uitest -uitest-skip-onboarding -uitest-seed realista -AppleLanguages "(es)" -AppleLocale es_PE`. Relanzar sin
  `-uitest-reset` no duplica la semilla.
- **Las píldoras ↑/↓ del hero tampoco**: el filtro de gastos se prueba por XCUITest, no por captura con axe.
- **Los chips de Estadísticas responden a coordenadas del centro de su marco**, no siempre a `--label`, y su orden
  cambia al elegir uno (el elegido se ensancha): lee el marco con `axe describe-ui` justo antes de tocar.
- **Tras conducir con axe, el XCUITest puede morir con «Timed out waiting for AX loaded notification»** (cero casos,
  exit 65). Dos reintentos seguidos no lo curaron; `simctl shutdown` + `boot` + `bootstatus -b` sí.

Relacionado: [[forzar-una-preferencia-en-un-lanzamiento]], [[conducir-simulador-con-axe]].
