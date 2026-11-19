Yala
# Flujo de caja: cambiar el límite de una línea en una hoja que pregunta el alcance antes de escribir
---
toca: Yala/App/Views/Reports/CashFlow/CashFlowLineConfigSheet.swift,Yala/App/Views/Reports/CashFlow/CambiarLimite/,Yala/App/Logic/CashFlowAmountChangeLogic.swift,Yala/Resources/de.lproj/FlujoCambiarLimite.strings,Yala/Resources/en-GB.lproj/FlujoCambiarLimite.strings,Yala/Resources/en.lproj/FlujoCambiarLimite.strings,Yala/Resources/es-419.lproj/FlujoCambiarLimite.strings,Yala/Resources/es-AR.lproj/FlujoCambiarLimite.strings,Yala/Resources/es-ES.lproj/FlujoCambiarLimite.strings,Yala/Resources/es.lproj/FlujoCambiarLimite.strings,Yala/Resources/fr.lproj/FlujoCambiarLimite.strings,Yala/Resources/it.lproj/FlujoCambiarLimite.strings,Yala/Resources/ja.lproj/FlujoCambiarLimite.strings,Yala/Resources/nl.lproj/FlujoCambiarLimite.strings,Yala/Resources/pl.lproj/FlujoCambiarLimite.strings,Yala/Resources/pt-BR.lproj/FlujoCambiarLimite.strings,Yala/Resources/pt-PT.lproj/FlujoCambiarLimite.strings,Yala/Resources/pt.lproj/FlujoCambiarLimite.strings,Yala/Resources/zh-Hans.lproj/FlujoCambiarLimite.strings,YalaTests/FlujoCambiarLimite/,YalaUITests/FlujoCambiarLimite/,tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/flujo-detalle-del-mes
---

Decisiones de Jürgen del 18-nov (06:26 Lima), registradas: aceptó todo lo recomendado del análisis «Flujo de caja: replanteo» (ticket `tickets/backlog/2026-11-17-flujo-de-caja-replanteo.md`, evidencia en `docs/analisis/2026-11-17-flujo-de-caja-replanteo/`):
- P1 modelo A: mes real + lo que falta.
- P2 línea excedida: cuenta lo real y no proyecta más.
- P3 al cambiar un límite, por defecto «desde este mes en adelante».
- P4 el límite es un monto fijo, sembrado con tu promedio al crear.
- P5 se retira el saldo inicial manual: se parte del saldo de tus cuentas.
- P6 lo que no tiene línea en meses futuros: gastos por la mediana de 6 meses; los ingresos no se proyectan.
- AJUSTE OBLIGATORIO: el nivel de detalle siempre llega a SUBCATEGORÍA, que es el id base. La categoría se deriva de sus subcategorías (suma) y se muestra como agrupador, puede ser colapsable. Nunca una línea solo a nivel categoría que pierda el detalle de subcategoría.

Sesión S4 del plan del ticket (va antes que el detalle de línea).

## Qué hacer
- Hoja única con el alcance ANTES de escribir el monto: solo este mes / desde este mes en adelante (por defecto) / todos los meses. Dice qué meses cambian.
- Admite 0. Funciona también en meses pasados si el modelo lo permite; si no, explícalo.
- Retira `CashFlowLineConfigSheet` (inalcanzable, nadie pone `showLineConfig = true`).
- La hoja la abre el detalle de línea en la sesión siguiente; deja un punto de entrada claro y, mientras tanto, conecta el «Ajustar monto» actual a la hoja nueva sin tocar archivos fuera del toca (si no se puede, anótalo para la sesión siguiente). Actualiza el ticket marcando S4.

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (semi; resueltas por Frank salvo la marcada)

1. **Conectar «Ajustar monto» tocando `CashFlowCellDetailSheet.swift` (fuera del `toca`).** Consultado al bot: opción A
   — se toca solo ese botón, que abre la hoja nueva, y se retiran el campo y la alerta viejos.
2. **Retirar `CashFlowLineConfigSheet` exige tocar lo mínimo fuera del `toca`**: el `.sheet` de `CashFlowTableView`,
   `showLineConfig`/`selectedLine` del ViewModel y los dos tests que leían el fichero borrado. Imprescindible: sin eso no compila.
3. **Qué escribe cada alcance**, con la precedencia del cálculo (ajuste de un mes › cambio «desde» › método):
   solo este mes = ajuste de un mes; desde este mes = cambio «desde» (los meses siguientes con ajuste propio lo
   conservan, y la hoja los nombra); todos = monto fijo, sin cambios «desde» ni ajustes de un mes.
4. **Meses pasados: se puede.** En el motor un mes cerrado es lo real; el límite solo cambia con qué se compara. La hoja lo dice.
5. **Admite 0.** Negativo no.
6. **Sin campo de nota.** La nota de un ajuste solo se pintaba en la hoja que se retira: no la ve nadie.
7. **Las escrituras viven en `CambiarLimite/`** (extensión del ViewModel), no en `CashFlowPlanViewModel.swift`.
8. **Título por lado:** «Cambiar límite» en gastos, «Cambiar monto esperado» en ingresos.
