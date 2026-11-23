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

**Ampliado el 2026-11-23** (encargo de la marca «≈» en Informes y tartas), recorridos con axe que funcionaron:

- **Distribución → Gráficas**: `-uitest-deeplink statistics`, toque en el chip de Distribución (≈ x 215, y 195),
  toque en «Gráficas» (`distribution_content_mode`, ≈ x 290, y 445) y un arrastre corto: el header de la tarta queda arriba.
- **Informes (Comparativa)**: no hay deeplink; recién lanzada la app, `axe tap --label "Más"`, un arrastre y
  `axe tap --id more_card_comparativa`. Tras un arrastre en el Panel la barra de abajo se encoge y «Más» ya no se
  alcanza con axe: relanza.
- **Oscuro = `-userTheme 2`** (1 claro, 0 sistema). La apariencia del simulador no cambia el tema.
- **Para el «antes»**: `git archive origin/2.3` en el scratchpad + `Secrets.xcconfig` + build con su propio
  `-derivedDataPath`; las dos builds en paralelo tardan ~15 min desde cero en la Max.
- **El semilla `realista` + `-uitest-seed-foreign-account JPY` no deja tasas dudosas en el cierre del mes pasado**: la
  marca del saldo de un período cerrado no se puede enseñar en captura con ese seed; se prueba por test.
- Un bucle `for t in "1 claro"; do set -- $t` en zsh NO parte `$t`: el tema llega como «1 claro» y la app cae al
  tema por defecto. Llamadas explícitas.
