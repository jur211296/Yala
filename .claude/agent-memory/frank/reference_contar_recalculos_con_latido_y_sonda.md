---
name: reference-contar-recalculos-con-latido-y-sonda
description: Cómo contar recálculos del Panel y medir el bloqueo del hilo principal en un unit test (latido de 5 ms + sonda de pila), y qué engañó al medir YALA-IOS-A
metadata:
  type: reference
---

Medido el 21-nov (encargo del congelamiento tras guardar con la nube). Molde en
`YalaTests/NubeCongelamiento/MedicionGuardadoConNubeTests.swift` (solo con `TEST_RUNNER_YALA_MEDIR_CONGELAMIENTO=1`).

- **Bloqueo del hilo principal**: una `Task { @MainActor }` que duerme 5 ms en bucle y apunta cada hueco > 5 ms. Da el
  bloque más largo y el total sin Instruments, y con `mark()` en la línea de tiempo dice QUÉ cae dentro de cada hueco.
- **Contar recálculos**: `PanelViewModel.debugRecalculationWindowsOpened`. Si salen más que subidas de `dataVersion`, una
  sonda temporal en `scheduleRecalculation` con `Thread.callStackSymbols` nombra al que pide (así salió
  `calculateHeroWidget` cortado por `StoreRemoteChangeCounter`). Restaurar con copia, nunca con `git checkout`: me
  borró el arreglo del runtime una vez.
- **`sample <pid> 12`** del proceso de test mientras corre, filtrando el hilo principal y los frames de `Yala.debug.dylib`:
  el perfil SIN nube no mostraba el bloque de 2,9 s; solo el escenario real (tras ciclos de la nube) lo enseñó.
- **Separar escenarios** antes de concluir: el ciclo de la nube corre cada 60 s, no al guardar. «Ciclo tras el
  recálculo» y «ciclo a mitad» dan resultados distintos con historiales grandes.

Relacionado: [[reference-medir-un-cuelgue-de-tipos-con-sample]], [[feedback-un-timeout-tapa-el-rojo-de-detras]].
