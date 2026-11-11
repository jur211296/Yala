---
name: qa-del-panel-con-reloj-falso
description: Fijar el día del mes en el Panel del simulador sin seam de app — dylib del molde, -defaultPeriod y todas las secciones por argumentos
metadata:
  type: reference
---

Para ver el Panel un día concreto (día 1 del mes, 20 de noviembre) no hay seam `-uitest-*` de reloj: se usa el dylib de
`ficha-app-store/reloj/` (`compilar.sh` lo deja en `~/Library/Caches/Yala/ficha/reloj.dylib`) con
`SIMCTL_CHILD_DYLD_INSERT_LIBRARIES` y `SIMCTL_CHILD_YALA_RELOJ_DESFASE` (segundos hasta la fecha), igual que
`capturas/lanzar.sh`. Medido el 2026-11-11 en el lote 2.3 del Panel:

- **El período lo fija `-defaultPeriod thisMonth`** (o `allTime`…); la semilla `ficha` abre en «Todo el tiempo».
- **Todas las secciones**: `-panelPrefsMigratedV2 YES -panelSectionsHidden "" -panelTendenciasHidden ""
  -panelDistribucionHidden ""`. Sin eso sale el Panel de usuario nuevo, sin Distribución ni Necesidades.
- **«Tus finanzas» abre plegada** (cápsulas); `axe tap --id panel_panorama_header` la despliega.
- **El globo de la gráfica**: `axe touch -x … -y … --down`, captura, `--up`.
- **`axe swipe` tiene inercia**: para encuadrar, relanza y da UN arrastre medido desde arriba; corregir con un segundo
  arrastre se pasa.
- El «antes» con la build de la base (`git archive origin/<base>`, DerivedData aparte) se instala encima: los datos del
  contenedor se quedan y la comparación es con los mismos registros.

Relacionado: [[molde-ficha-app-store]], [[conducir-simulador-con-axe]], [[antes-del-iphone-con-git-archive]].
