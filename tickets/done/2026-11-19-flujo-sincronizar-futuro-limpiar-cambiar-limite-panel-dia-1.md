---
id: 2026-11-19-flujo-sincronizar-futuro-limpiar-cambiar-limite-panel-dia-1
status: done
priority: medium
area: "cash-flow, panel, prefs-sync"
created: 2026-11-19
updated: 2026-11-19
source: "decisión de Jürgen del 19-nov-2026, 14:04 (tres tareas en un lote)"
---

# Flujo de caja: «Considerar a futuro» sincronizado, adiós a «Cambiar límite» y el Panel parte del día 1

## Qué pidió Jürgen

1. Que apagar una partida en «Considerar a futuro» viaje entre teléfonos, sin perder lo ya apagado.
2. Retirar la hoja «Cambiar límite», que se quedó sin entrada (todo pasa por «Cálculo del monto»).
3. Que el Panel y el flujo de caja digan la misma cifra de inicio de mes. Antes: Panel «1 nov S/ 72,979 → −2.8 %»,
   flujo de caja «Empezaste con S/ 64,345».

## Qué se hizo

1. **Preferencia sincronizada `cashFlowFutureExcludedFixed`** (vía elegida por el bot de Frank frente a un campo en
   `CashFlowPlan`, que pedía CloudKit Production + columna en Supabase + Worker v7). Viaja por iCloud clave-valor o por la
   tabla de preferencias del Modo Nube; ninguno pide despliegue. Lista JSON; «» = todo encendido, y también viaja. La
   lista local de antes la une la lectura y la sube una pasada al arrancar. Al llegar de otro teléfono sube `dataVersion`.
2. **Hoja borrada** (`FlujoCambiarLimiteSheet` y su test de capturas). Se conservan en `CambiarLimite/` lo que usa
   «Cálculo del monto»: el alcance, `montoEscrito`, `escritura` y `CashFlowPlanViewModel.cambiarLimite`, y los textos
   `scope.only/from/all`, `invalid` y `save` (16 idiomas). `FlujoCambiarLimiteUITests` ya conducía «Cálculo del monto».
3. **El Panel parte del saldo antes del día 1**, con la pieza de «Empezaste con»
   (`PanelTrendSummaryLogic.periodStartBalance` → `FlujoMotorMesEntrada.FuenteSaldo.saldos(antesDe:)`). La causa: la
   fila tomaba el primer punto de la curva, que es el cierre del día 1 con el sueldo dentro. La curva no cambia; el widget
   y Tendencias no pintan esa cifra.

## Verificación

- Unit: `YalaTests/FlujoSyncYPanelDia1/` (sincronización entre dos almacenes por el codec y el merge del canal, migración,
  paridad Panel = flujo de caja con control de la curva, cableado).
- Sonda contra el Worker de staging con dos nodos de reloj sobre la misma cuenta: 4/4 (la lista va y vuelve, «» también).
- Simulador iPhone 17 Pro (seed realista): Panel «1 nov S/ 64,345.15 → hoy S/ 70,928.30 · +10.2 %» = «Empezaste con
  S/ 64,345.15», claro y oscuro. Antes: «1 nov S/ 72,979.01 · −2.8 %».
- iPhone 14 por Device MCP: Panel «1 nov S/ 61,748.00» = «Empezaste con S/ 61,748.00».
- Gate: build 2/2; YalaTests entero 15.207 tests en 1.804 suites; interfaz 25 tests en 12 clases; CI local 24/24.
- Antes y después: https://claude.ai/artifact/3fwmngxVC1DkQLrk6AkbSU

## Pendiente (device-QA, no frena el merge)

1. En dos iPhone con el mismo Apple ID y los datos en iCloud, abrir Flujo de caja › «Otros» del mes que viene y apagar
   una partida en «Considerar a futuro» del teléfono A.
2. En el teléfono B, cerrar y abrir Yala (o esperar a que llegue el cambio de iCloud).
3. Esperado: la partida sale apagada también en B, y la cifra del mes que viene es la misma en los dos.
