---
id: debt-simplification-nondeterministic-ties
status: backlog
priority: low
area: groups
created: 2026-09-07
updated: 2026-10-08
source: review adversarial de groups-shareable-summary (2026-09-07)
---

# La simplificación de deudas elige distinto ante un empate, y eso ya no queda solo en pantalla

## Qué pasa

`DebtSimplificationService.simplifyForCurrency` empareja al mayor acreedor con el mayor deudor
usando `netBalance.max(by:)` / `netBalance.min(by:)` sobre un `Dictionary<String, Double>`. Ante un
**empate exacto** de saldos, ambos conservan el primero que encuentran — y el orden de iteración de
un `Dictionary` de Swift depende de la semilla de hash del proceso, así que **no es estable entre
ejecuciones**.

Caso concreto, cuatro miembros y una moneda:

- Ana paga 200, repartido a partes iguales entre los cuatro (50 cada uno).
- Beto paga 100, con partes solo para Carla (50) y Dani (50).

Netos exactos, sin decimales de por medio: Ana **+150**, Beto **+50**, Carla **−100**, Dani **−100**.
En la primera vuelta el acreedor máximo es Ana, pero el deudor mínimo es un empate entre Carla y Dani:

- una ejecución da `[Carla→Ana 100, Dani→Ana 50, Dani→Beto 50]`
- otra da `[Dani→Ana 100, Carla→Ana 50, Carla→Beto 50]`

Las dos son correctas y suman lo mismo. Son conjuntos distintos.

## Por qué ahora importa más

Hasta ahora esto vivía solo en la pestaña Balances, donde el usuario vuelve a mirar la pantalla y ve
una sola verdad. Desde el resumen compartible (`groups-shareable-summary`, 2026-09-07) el resultado
**se congela en una imagen que se manda al chat del grupo**: Ana genera el resumen y sale que Carla
paga 100 de una vez; Beto lo genera cinco minutos después y sale que Carla hace dos pagos de 50.
Las dos imágenes circulan a la vez y no se pueden corregir.

Lo comparten hoy tres consumidores: `GroupDetailViewModel` (Balances), `GroupBalanceService.globalSummary`
(la banda de «te deben / debes») y `GroupSettlementReminderService`. El ordenado del resumen
(`GroupShareableSummaryLogic`) es total y estable, pero **ordena el conjunto que recibe**: no puede
reconciliar dos conjuntos distintos.

## Arreglo propuesto

Desempatar por `memberID` antes de elegir: ordenar los candidatos con saldo máximo/mínimo y quedarse
con el menor id. Es determinista, no cambia ningún importe y no toca el número de transferencias.

## Acceptance Criteria

- [ ] `DebtSimplificationService.simplify` devuelve el MISMO conjunto de transferencias en ejecuciones
      distintas del proceso para los mismos datos de entrada, incluidos los empates exactos.
- [ ] Test con el caso de cuatro miembros de arriba, verificado por mutación (quitar el desempate
      tiene que ponerlo rojo). Ojo: un test que solo compare una corrida consigo misma NO sirve —
      hay que fijar el conjunto esperado.
- [ ] Sin cambios en los importes ni en la cantidad de pagos de ningún caso ya cubierto por
      `GroupBalanceServiceTests`.

## Medido en 2.1 (triage 2026-10-08)

- `DebtSimplificationService.simplifyForCurrency` sigue eligiendo con `netBalance.max(by:)` / `netBalance.min(by:)` sobre el `Dictionary`, sin desempate por `memberID`. Sin commits en el fichero desde el 2026-09-07.

Triage 2026-10-08: abierto · low → low · sigue sin desempate determinista; los importes son correctos y solo cambia el reparto entre dos imágenes compartidas.
