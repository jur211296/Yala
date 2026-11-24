---
name: medir-cambio-de-chip-con-sample
description: Cómo medir en el simulador qué come el hilo principal al cambiar de chip o hacer scroll (sample + axe), y qué descontar para no leer mal la muestra
metadata:
  type: reference
---

Medido el 2026-11-24 en la Max (encargo de fluidez de Estadísticas, semilla `pesado`):

- Lanzar con `-uitest -uitest-skip-onboarding -uitest-seed pesado -uitest-deeplink statistics`; la semilla deja
  «Todo el tiempo» como período (el caso más pesado). Relanzar sin reset no vuelve a sembrar.
- `sample <pid> N 1 -mayDie` en segundo plano mientras `axe tap --id …` toca los chips; los ids con tilde
  (`detail_chip_categorías`) funcionan. El pid sale de `simctl spawn <udid> launchctl list`.
- **Descuenta `mshMIGPerform` (AXRuntime)**: son las consultas de accesibilidad del propio `axe`, ~300-430 ms en 10 s.
  Sin restarlas, el «después» parece peor de lo que es.
- Contar inclusivo por función de Yala, sin doble conteo por rama (script en
  `~/Claude/entregas/estadisticas-fluidez-scroll-y-chips/evidencia/sample_top.py`). Un nombre que no sale en la
  muestra puede ser que no corrió (pasó con `calculateData` de Distribución): no lo des por barato sin otra muestra.
- El scroll del simulador no mide lo que siente un iPhone 14: el hilo principal queda al 15-20 %. Para el scroll, el
  teléfono.

Relacionado: [[medir-un-cuelgue-de-tipos-con-sample]], [[medir-release-en-el-iphone-con-semilla]].
