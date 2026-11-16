---
id: yala-web-lote-2
status: done
priority: high
area: web
created: 2026-11-14
updated: 2026-11-14
source: encargo 2026-11-14-yala-web-lote-2 (card tablero-yala-web-lote-2-segun-el-plan-aprobado-7yhc)
---
# Yala web, lote 2: estadísticas, pagos planificados y entrar con el iPhone (QR)

Tercer lote de Yala web (plan en `docs/web-app/index.html`), sobre la beta (lote 1). El 14-nov Jürgen pidió los lotes 2
y 3 ya en 2.3 (cambia D10). Las 13 decisiones del artifact siguen con la recomendada: la colección `decisiones` de su db
seguía vacía (lote 1, medido con `ArtifactData`).

## Alcance (el del encargo, tomado del plan)

1. **Estadísticas** en la web, en lectura: **Resumen**, **Distribución** y **Tendencias**, con las mismas cifras que el
   iPhone.
2. **Pagos planificados** en lectura: **próximos cobros** y **suscripciones**.
3. **Vincular con el iPhone por QR**: la web enseña un código; en el iPhone, Ajustes › Tu cuenta de Yala › Navegadores
   conectados › «Vincular un navegador», se escanea (o se escribe) y se confirma con Face ID.
4. Pruebas de paridad de cada cálculo nuevo contra el código de producción de la app.

**Fuera, del mismo lote 2 del plan** (el encargo no los pide; van al siguiente encargo): Presupuestos, Grupos en
lectura, buscar en todo (⌘K) y exportar a CSV, y los 16 idiomas. La web sigue en español e inglés.

## Paso 0 — decisiones

Medido antes de decidir (14-nov, rama de la beta, que entra en 2.3 con auto-merge):

- `shared-core` ya trae `resumen_periodo` (ingresos, gastos, neto, top) con paridad contra el contexto del chat
  (`FullFinancialContextBuilder`) en `mcp/test/golden.test.ts`, y `listar_recurrentes` (equivalente mensual).
- La app NO detecta suscripciones: «suscripción» es el tipo de un pago planificado (`payment_category = subscription`).
  `SubscriptionBrandCatalog` solo pone el logo.
- Estadísticas del iPhone: Resumen = `InsightsCalculator` (sobre `CashFlowCalculator`), Distribución =
  `TopSpendingCategoriesCalculator` (porcentaje sobre el gasto NETO con signo, «Sin categoría» como trozo, sin «Otros»),
  Tendencias › Entradas y salidas = `CashFlowCalculator` por meses.
- Los períodos en curso cierran hoy a las 23:59:59 (`DetailPeriod.dateInterval`): lo fechado mañana no cuenta, como en
  `shared-core`.
- Próximos cobros del iPhone: `ScheduledPaymentDateCalculator.paymentDatesInMonth`. Todas sus entradas
  (`day_of_month`, `selected_weekdays`, `yearly_month`, `yearly_day`, `created_at`, `skipped_dates_raw`) están en
  `scheduled_payments` de la nube, y `yala_mcp_reader` puede leer la tabla entera.
- La app no tiene `NSFaceIDUsageDescription` (se quitó en 2.1 porque no se usaba) ni lector de QR. Tiene permiso de
  cámara (texto de recibos).
- Las configuraciones Debug-Dev y Release-Dev generan su Info.plist con claves `INFOPLIST_KEY_*` propias.

| # | Pregunta | Decisión | Por qué |
|---|---|---|---|
| P1 | ¿Qué períodos ofrece Estadísticas? | Este mes, mes pasado y este año. | Los de la maqueta y los que el núcleo ya calcula con paridad. Semanas y rango libre dependen del primer día de la semana del teléfono, que el servidor no conoce. |
| P2 | ¿Qué trae Resumen? | Ingresos, gastos y neto con su variación frente al período anterior (alineado como el iPhone: el mes en curso contra los mismos días del anterior), gasto medio diario, las 5 categorías con más gasto y el gasto más alto. | Lo central de la pestaña del iPhone que se puede calcular sin datos del teléfono. Gastos hormiga, día más caro y observaciones quedan fuera (más cálculos que portar). |
| P3 | ¿Cómo reparte Distribución? | Por categoría, solo gasto, con signo; el porcentaje sobre el gasto neto; «Sin categoría» como un trozo más; todas las categorías, sin «Otros». | Es `TopSpendingCategoriesCalculator`, la lista de la pestaña. |
| P4 | ¿Qué enseña Tendencias? | Entradas, salidas y neto de los últimos 6 meses (el actual hasta hoy). | La barra de la maqueta. Cada mes es `CashFlowCalculator` sobre ese mes. Las curvas de saldo del iPhone quedan fuera. |
| P5 | ¿Qué son los «próximos cobros»? | Las fechas de cobro de los próximos 30 días (desde hoy), de los pagos activos, sin las fechas saltadas, con el día de cobro del iPhone. Arriba, lo que suman los gastos de esa lista. | Es el calendario del iPhone (`paymentDatesInMonth`). Lo «ya pagado» del iPhone sale de enlazar movimientos con cada cobro: queda fuera, así que la lista empieza hoy. |
| P6 | ¿Qué son las «suscripciones»? | Los pagos planificados de tipo suscripción, activos, con importe, frecuencia y próximo cobro; arriba, su equivalente al mes. | No hay detección en la app. El equivalente mensual ya tiene paridad (`listar_recurrentes`, el que usa Yala IA). |
| P7 | ¿Cómo funciona el QR? | La web pide un código (Turnstile) y queda ligada a él por una cookie propia. El código dura 60 s y se renueva solo. El iPhone lo lee o lo escribe, ve navegador y ciudad, confirma con Face ID y aprueba con su sesión; el servidor pide el permiso de solo lectura de siempre y guarda solo el código de autorización, que sin la cookie de ese navegador (PKCE) no sirve. La web lo canjea y entra. | Es el flujo de la maqueta. Nadie puede entrar con un código ajeno: hace falta la cookie del navegador que lo pidió. Contra el código que un tercero enseña a la víctima (phishing por QR), el iPhone enseña navegador y ciudad antes de Face ID. |
| P8 | ¿Dónde se guarda un código pendiente? | En un Durable Object por código (`QrPairing`), con caducidad. | El KV es eventual (la beta lo midió con la lista de sesiones): la aprobación del iPhone tiene que verse en el acto. |
| P9 | ¿Face ID sin clave en el Info.plist de producción? | `NSFaceIDUsageDescription` solo en Debug-Dev y Release-Dev (`INFOPLIST_KEY_*`), con textos en los 16 idiomas. Se pide «Face ID o el código del iPhone» (`deviceOwnerAuthentication`). | La pantalla solo existe en Yala Dev. Producción no gana una clave que no usa (la quitó el ticket de 2.1). |
| P10 | ¿Cómo lee el iPhone el QR? | `DataScannerViewController` (VisionKit) y, al lado, un campo para escribir el código. | Sin dependencias. El simulador no tiene cámara: el campo lo cubre, y la maqueta ya enseña el código escrito. |
| P11 | ¿Qué paridad se prueba? | Se amplía el golden que escribe la app (`YalaTests/MCP/MCPAppParityGoldenTests.swift` → `mcp/test/golden/app-parity.json`) con `estadisticas` (CashFlow por meses, período anterior alineado, días del promedio, distribución) y `pagos` (fechas de cobro de dos meses), calculados con el código de producción de la app. | Cada cálculo nuevo se escribe dos veces y se prueba contra Swift (decisión R1). |
| P12 | ¿Qué zona horaria usa la web? | La que la app subió a `user_preferences` y, si no, Lima (como el conector). | El iPhone usa la del teléfono; es la misma en el caso normal. |

## Fuera de este lote

- Lo de arriba del lote 2 del plan que el encargo no pide.
- «Ya pagado» en los próximos cobros.
- El texto del permiso de cámara de producción (habla de recibos): la pantalla solo existe en Yala Dev; antes de llevarla
  a producción, el texto tiene que nombrar también el QR.

## Resultado (14-nov)

- **Web** (`webapp/`), desplegada en <https://yala-web-staging.misty-surf-6866.workers.dev>: «Estadísticas» (Resumen,
  Distribución y Tendencias; este mes, mes pasado y este año) y «Pagos planificados» (próximos cobros de 30 días y
  suscripciones) en la barra lateral y en «Más» del móvil. En la pantalla de entrar, «Entrar con tu iPhone» enseña el QR,
  el código escrito (cambia cada 60 s) y entra sola cuando el iPhone aprueba. Español e inglés; claro y oscuro.
- **Núcleo compartido**: `shared-core/src/logic/stats.ts` (Resumen, Distribución, Tendencias) y
  `shared-core/src/logic/schedule.ts` (calendario de cobros), con su entrada `webCore.ts` fuera de `TOOL_CORES` (el
  conector no cambia: su foto byte a byte sigue igual).
- **La paridad cazó una diferencia real**: Estadísticas del iPhone deja fuera los movimientos sin cuenta
  (`FilterService.filterForTrends`) y el núcleo del chat los cuenta. La web sigue al iPhone (`onScreen`).
- **QR**: Durable Object `QrPairing` por código (migración `v2-qr`) y límite `RL_QR`. El servidor guarda solo el código
  de autorización; sin la cookie del navegador que lo pidió (PKCE) no sirve.
- **iPhone (Yala Dev)**: «Vincular un navegador» en «Navegadores conectados»: escáner de VisionKit, campo para escribir
  el código (acepta cualquier separador), confirmación con navegador y ciudad, Face ID (o el código del iPhone) y la
  lista se refresca. `NSFaceIDUsageDescription` solo en Debug-Dev y Release-Dev. Textos en los 16 idiomas.
  En el recorrido del simulador salió un fallo y se arregló: `dismissKeyboardOnTap()` sobre la `List` se comía los
  toques de «Continuar» y «Confirmar» (la regla ya estaba escrita en `GroupSettingsView`).
- **Pruebas**: golden de paridad con la app ampliado (`estadisticas` y `pagos`, calculados por `InsightsCalculator`,
  `TopSpendingCategoriesCalculator`, `CashFlowCalculator` y `ScheduledPaymentDateCalculator`): conector 250/250. Web
  84/84 unitarias (14 nuevas del lote 2; dos mutantes de la seguridad del QR caen). Swift: `LinkBrowserModelTests` (6) y
  `ConnectedBrowsersClientTests`. Staging: e2e del lote 0 (9) y del lote 2 (3) en verde, con el QR real (A aprueba y
  entra; B no puede aprobar el código que leyó A; otro navegador no recibe la aprobación).

## Guion de prueba en el iPhone 14 (device-QA)

Lo que no se automatiza: la cámara real y Face ID, con una cuenta en la nube en Yala Dev.

1. En el iPhone 14, abre **Yala Dev** (con esta versión) y entra con tu cuenta en la nube de staging.
2. En el Mac, abre <https://yala-web-staging.misty-surf-6866.workers.dev> y toca **«Entrar con tu iPhone»**. Sale un QR
   y un código de 8 caracteres que cambia cada minuto.
3. En el iPhone: Ajustes › Tu cuenta de Yala › Navegadores conectados › **Vincular un navegador**. La primera vez pide
   permiso de cámara: acéptalo. Apunta al QR de la pantalla.
4. Tiene que salir «¿Abrir Yala en este navegador?» con **tu navegador y tu ciudad**. Toca «Confirmar con Face ID».
5. En segundos, la web entra sola en tu Panel. Abre **Estadísticas** y compara Resumen y Distribución de «Este mes» con
   Estadísticas del iPhone (mismo período): las cifras tienen que coincidir. Abre **Pagos planificados** y compara los
   próximos cobros con los del iPhone.
6. Vuelve a «Navegadores conectados» en el iPhone: sale el navegador nuevo. Ciérralo; la web vuelve a la pantalla de
   entrar en menos de un minuto.
7. Prueba también escribir el código a mano (sin cámara) en otro intento, y un código viejo: tiene que decir que caducó.
