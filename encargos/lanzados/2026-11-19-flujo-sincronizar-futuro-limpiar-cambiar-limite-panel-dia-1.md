Yala
# Flujo de caja: «Considerar a futuro» sincronizado, adiós a la hoja «Cambiar límite» y el Panel parte del saldo del día 1
---
toca: Yala/Models/CashFlowPlan.swift,Yala/Services/CloudSync/EntityApplyMap.swift,Yala/Services/CloudSync/EntityEmissionMap.swift,Yala/App/Logic/FlujoProyeccionInteligente/FlujoFijosAFuturo.swift,Yala/App/Views/Reports/CashFlow/CambiarLimite/,Yala/App/Views/Panel/,YalaTests/FlujoCambiarLimite/,YalaTests/FlujoSyncYPanelDia1/,tickets/backlog/2026-11-19-flujo-sincronizar-futuro-limpiar-cambiar-limite-panel-dia-1.md,tickets/done/2026-11-19-flujo-sincronizar-futuro-limpiar-cambiar-limite-panel-dia-1.md
esfuerzo: high
cierre: cierra-sola
depende:
---

Rama base: 2.3. Antes de empezar, confirma que el PR del Flujo de caja nuevo (rama `encargo/2026-11-19-flujo-aislados-promedio-y-detalle-mes`) ya está MERGED en 2.3. Si no, espera hasta 30 minutos revisando cada 5. Si sigue sin entrar, sale como `BLOQUEANTE:`.

## Qué decidió Jürgen (19-nov, 14:04 Lima), tres tareas en un lote
1. **«Considerar a futuro» se sincroniza entre teléfonos.** Hoy apagar una partida a futuro (`FlujoFijosAFuturo.swift`) se guarda solo como preferencia local. Pásalo al plan de Flujo de caja (`CashFlowPlan`), para que viaje por iCloud y por el Modo Nube con el mismo motor de sincronización que el resto del plan. Migra lo que ya está guardado localmente, sin perder lo que la persona apagó. Si el campo nuevo necesita esquema en CloudKit producción o una migración en Supabase producción, prepáralo y pruébalo en desarrollo, pero el despliegue a producción es una decisión vital: pregunta antes de desplegar, según el modo. Si el Modo Nube guarda el plan sin columnas por campo (como JSON), mejor, porque así no hace falta migración: anótalo.
2. **Retirar la hoja «Cambiar límite».** Quedó sin entrada, porque todo pasa por «Cálculo del monto». Borra la hoja y el código que solo usaba ella (`Yala/App/Views/Reports/CashFlow/CambiarLimite/`), con sus textos y tests (`YalaTests/FlujoCambiarLimite/`). Antes, verifica que nada más la usa. Si «Cálculo del monto» reutiliza alguna pieza de lógica, consérvala donde esté y anota qué quedó.
3. **El Panel parte del saldo al empezar el día 1**, igual que Flujo de caja, para que las dos pantallas muestren la misma cifra de inicio de mes. Hoy el Panel muestra por ejemplo «1 nov S/ 72,979 → −2.8 %» y Flujo de caja «Empezaste con S/ 64,345». Usa la misma fuente de cálculo de Flujo de caja (`CashFlowMonthSummaryLogic` o la que corresponda) y no dupliques la lógica. Revisa también que el widget y Tendencias, si muestran esa cifra, queden iguales.

## Cómo entregar
- Tests nuevos en `YalaTests/FlujoSyncYPanelDia1/`: la sincronización y la migración de «Considerar a futuro», y que el inicio de mes del Panel y el de Flujo de caja sean iguales. Presupuesto de UI tests acotado. Textos nuevos en una tabla propia, nunca en Localizable.strings. Nunca un botón debajo de otro.
- Probar con el iPhone 14 por DeviceMCP y en un simulador, en claro y oscuro. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Si necesitas tocar otro archivo fuera del toca, que sea lo mínimo y anótalo en «Decidido sin consultar».
- Entregable visual: un artifact de Claude con el antes y el después del Panel junto a Flujo de caja, y la prueba de la sincronización entre dos dispositivos o simuladores. Nunca Markdown ni PDF.

## Reglas
- Commits y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay un conflicto o el CI falla, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión», sin mergear ni desplegar lo incompleto.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (modo semi; las vitales, preguntadas)

1. **Dónde viaja «Considerar a futuro».** Medido: el Modo Nube guarda `cashflow_plans` con una columna por campo, no en
   JSON. Un campo en `CashFlowPlan` pedía cuatro despliegues a producción (CloudKit Production, columna en Supabase,
   Worker con manifiesto v7, en ese orden). Preguntado al bot (vital): eligió la **preferencia sincronizada**
   `cashFlowFutureExcludedFixed` (iCloud clave-valor en iCloud; tabla `user_preferences`, clave/valor de texto sin lista
   de claves en el servidor, en Modo Nube). Cero despliegues.
2. **Formato:** lista JSON ordenada de claves estables; `""` = todo encendido (familia «vacío válido», viaja).
3. **Migración:** la lectura une la lista local vieja (`cashFlow.futureExcludedFixed`) mientras exista; al arrancar, tras
   el primer import, una pasada de un solo uso la sube al canal (unida a lo que ya llegó) y la retira.
4. **Refresco al llegar de otro teléfono:** señal nueva del merge que sube `dataVersion`.
5. **«Cambiar límite»:** se borra la hoja (sin entrada desde el 19-nov) y su test de capturas. «Cálculo del monto»
   reutiliza el alcance, `montoEscrito`, `escritura` y `cambiarLimite` del ViewModel, y tres textos: se conservan en su
   carpeta, recortados a lo que se usa; sus tests se recortan igual. `FlujoCambiarLimiteUITests` ya conduce «Cálculo del
   monto» (ids `cashflow_method_*`): se queda.
6. **Panel día 1:** la fila «1 nov S/ … → hoy» del gráfico de saldo parte del saldo ANTES del primer instante del
   período, con `FlujoMotorMesEntrada.FuenteSaldo.saldos(antesDe:)` (la de «Empezaste con»). La curva no cambia. Vale para
   todo período («al empezar el período»). Widget y Tendencias no pintan esa cifra (único llamador de la fila: el Panel).
7. **Sesión vieja en `Views/Panel/`** (prueba-unslop-design, 3-nov): sin PR ni worktree vivos; se da por inactiva.
