---
id: 2026-11-20-flujo-limites-pagos-planificados-y-moneda
status: done
priority: medium
area: "cashflow, planificacion, currency, fx, sync"
created: 2026-11-20
updated: 2026-11-21
source: "encargo 2026-11-20-flujo-de-caja-limites-por-pagos-planificados-y-moneda-maquetas"
---

# Límites de Flujo de caja atados a pagos planificados y en otra moneda

## Hecho (2026-11-21)

Implementado con las ocho recomendadas que eligió Jürgen el 20-nov (17:06). Lo que quedó distinto o fuera:

- **Crear el plan** sigue con un pago por línea; la tarjeta de varios pagos y el extra salen en una línea ya creada.
- **Pago borrado**: lo resuelve el borrado deliberado (`EntityDeletionService` → `FlujoPagosDeLineaLogica.alBorrarPago`).
  Un pago que no se encuentra al leer (borrado en otro teléfono, o aún sin llegar por iCloud) suma 0, y sin nada más la
  línea cae a su `manualAmount` (el límite guardado la última vez); leer nunca escribe. El aviso de una vez es local.
- **Selector de moneda**: el de siempre (`CurrencySelectorView`: la de tu región, USD, EUR y GBP primero), no «las de tus
  cuentas primero».
- **En la fila** la moneda se escribe con su código («500.00 USD»), no con su nombre: el plural no cabe bien en 16 idiomas.
- **Despliegues pendientes** (no se podían hacer desde la Max): schema de iCloud en Development y Production
  (`docs/despliegue-cloudkit-2-2.md`, sección del 2026-11-21), migración `qa/cloud/g33_01_*` y Worker v8 en staging y
  producción. Hasta el Worker v8 la app no manda las cuatro columnas (declara v7) y las reemite al subir.
- **Device-QA en el iPhone 14: sin hacer** (lo usaba otra sesión). Guion abajo.

### Device-QA pendiente (iPhone 14, Yala Dev)

1. Planificación → Pagos planificados: crea «Renta» de 500 USD mensual y «Netflix», «Spotify» e «iCloud+» en soles.
2. Reportes → Flujo de caja → crea el plan si no hay. Abre una línea de gasto → «Cambiar» → «Monto fijo» → toca «S/ ▾» →
   USD → 500 → Guardar. Esperado: bajo el límite, la cápsula «500.00 USD · promedio de nov. X»; tócala: «Cómo se
   convierte» con cerrados, en curso y estimados (≈). En la lista del mes, bajo el nombre, «⇄ 500.00 USD», y al final la
   nota «Incluye 1 límite en USD…».
3. Otra línea → «Cambiar» → «Pagos planificados» → marca Netflix, Spotify e iCloud+ → Listo → «Sumar un monto extra» 30 →
   Guardar. Esperado: el límite es la suma de los que caen este mes + 30, y la fila dice «3 pagos + extra».
4. Edita el importe de Netflix en Pagos planificados. Esperado: el límite de la línea cambia sin tocar la línea.
5. Borra Spotify. Esperado: al abrir la línea, una vez, «Se borró el pago Spotify. Ya no suma en esta línea.»; si borras
   todos y no hay extra, la línea pasa a «Monto fijo» con su último límite y lo dice una vez.

Jürgen (20-nov), resumido: (1) «esta línea depende de este pago planificado», o de varios a la vez (Suscripciones =
un pago por suscripción, elegidos de una lista), con la opción de sumar «algo más» fijo; el límite se recalcula solo
cuando cambia un pago. «Mucho más fino que un monto fijo que quizá varíe». (2) Poner el límite en otra moneda (la renta
son 500 USD; un mes equivalen a 2.000 soles y otro a 1.500): que la app lo convierta a la moneda del flujo con un tipo
de cambio («el promedio del mes, o algo así»), que se vea el original y cuánto vale ese mes, y que avise con claridad
que se convierte y con qué tasa.

Maquetas, medidas y preguntas: artifact «Límites con pagos y monedas» y su copia en
`docs/maquetas/flujo-limites-pagos-y-moneda/index.html`. La sesión de diseño:
`tickets/done/2026-11-20-flujo-limites-pagos-planificados-y-moneda-maquetas.md`. **Jürgen contesta en la base del
artifact (colección `decisiones`, un documento por pregunta: `metodo`, `seleccion`, `borrado`, `mezcla`, `fijo`,
`tasa`, `fila`, `sync`, cada uno con `valor` y `nota`).** Este ticket describe las recomendadas; si elige otra, cambia
su sección y los criterios que no la toquen siguen valiendo.

## Lo que ya hay (medido el 20-nov en 2.3)

- `CashFlowLine.scheduledPayment` (a-uno) y el método `.scheduled` («Pago planificado»): una línea se ata a un pago.
- `ScheduledPaymentAmountConversion` convierte el pago a la moneda del flujo con la **última tasa** y marca «≈».
- `FlujoMotorMes.Dueños.porPago`: una línea con pago recibe solo los movimientos de su pago; el mismo pago en dos
  líneas deja la segunda repetida.
- Pago borrado → relación `.nullify` → la línea `.scheduled` cae a `manualAmount ?? 0` sin avisar.
- Tasas diarias guardadas (`ExchangeRateService`); `CurrencyConverting.rateFactors` las pide en bloque.

## Diseño recomendado

### 1 · «Pagos planificados» en «Cálculo del monto» (pregunta `metodo`, opción A)

- El método «Pago planificado» pasa a llamarse **«Pagos planificados»** y admite uno o varios. Sale en la lista de
  métodos si la persona tiene al menos un pago planificado activo del mismo lado (gasto o ingreso).
- Elegido, aparece la tarjeta **«Pagos de esta línea»**: una fila por pago (logo o icono, nombre, frecuencia y próxima
  fecha, importe en su moneda; si es otra, debajo «≈ S/ 74»), con quitar por deslizamiento o menú, y una fila
  **«Agregar pago»**.
- Debajo, **«Sumar un monto extra»** (interruptor + campo en la moneda del flujo): para «pagos planificados y algo
  más». La cifra grande de arriba es pagos del mes + extra, y su explicación: «Suma de 4 pagos + S/ 30 extra. Se
  actualiza solo cuando cambias un pago.»
- Un pago con monto variable suma su monto de referencia y su fila dice «Variable».
- Un pago que no cae en ese mes (anual, trimestral) suma 0 ese mes: es lo que ya hace `estimateScheduled` contando sus
  fechas en el mes.

### 2 · Elegir varios pagos (pregunta `seleccion`, opción B)

- Hoja «Elige los pagos» con casillas, buscador desde 8 pagos, solo los pagos del lado de la línea, activos primero.
- Un pago que ya está en otra línea sale con «En Renta». Marcarlo lo trae aquí y lo quita de la otra, con una línea
  de aviso en la hoja antes de guardar («Se moverá de Renta a esta línea»). Nunca queda en dos líneas.

### 3 · Pago borrado, pausado o terminado (pregunta `borrado`, opción A)

- **Borrado:** sale de la línea. Si quedan otros pagos o el extra, la línea sigue. Si no queda nada, pasa a
  **monto fijo** con el último límite que tuvo, y el detalle de la línea lo dice una vez: «Se borró el pago Renta.
  El límite quedó fijo en S/ 1.850.»
- **Pausado** (`isActive == false`): no suma mientras esté pausado; su fila dice «Pausado · no suma».
- **Terminado** (`endDate` pasada): suma solo en los meses en que tiene fecha; después, «Terminó en marzo».

### 4 · Pagos en otra moneda (pregunta `mezcla`, opción A)

- Cada pago se convierte por separado a la moneda del flujo y se suman.
- Si **todos** los pagos de la línea están en la misma moneda extranjera y no hay extra, la línea enseña su original
  («500 USD»). Con mezcla, solo la cifra convertida y el desglose en el detalle.

### 5 · Monto fijo en otra moneda (pregunta `fijo`, opción A)

- En «Monto fijo», el símbolo delante del campo es un botón (`S/ ▾`) que abre el selector de moneda (las de las
  cuentas de la persona primero). En otra moneda, debajo del campo: «≈ S/ 1.850 en noviembre · tipo de cambio
  promedio 3,70».
- **En otra moneda el monto vale para todos los meses**: la tarjeta «Qué meses cambian» no sale y una línea lo
  explica. Cambiar de moneda retira los cambios «desde» y los ajustes de un mes (como el alcance «todos» de hoy).

### 6 · Tipo de cambio: promedio del mes (pregunta `tasa`, opción A)

- **Mes cerrado:** promedio de las tasas diarias de ese mes. No cambia más.
- **Mes en curso:** promedio de los días que van. Se mueve un poco cada día.
- **Meses futuros:** la última tasa conocida, con «≈».
- Días sin tasa: se promedian los que haya; sin ninguno, la regla de hoy (`RateQuality`, «≈»).
- Una función pura nueva, p. ej. `FlujoTasaDelMes.promedio(mes:de:a:hoy:factores:)`, con los factores de
  `rateFactors`. El pago y el monto fijo usan la misma.

### 7 · Cómo se ve (pregunta `fila`, opción A)

- **Fila de la línea en el mes:** la cifra en soles, como hoy, y debajo del nombre «500 USD» con el icono de cambio.
- **Detalle de la línea:** bajo «Límite de noviembre», una cápsula «500 USD · promedio de nov. 3,70» que abre la hoja
  **«Cómo se convierte»**: el original, la tasa de cada mes de los seis del gráfico (cerrado, en curso, estimado) y de
  dónde salen las tasas.
- **Lo que llevas, en la moneda del límite:** si lo registrado en la línea está en la misma moneda que el límite (la
  renta pagada en dólares), se compara en esa moneda. 500 USD pagados a 3,724 contra un límite de 500 USD al promedio
  3,70 son S/ 12 de diferencia: se explica («Pagaste 500 USD: justo el límite. Los S/ 12 de más son del tipo de cambio
  del día del pago») y no sale «Te pasaste».
- **Gráfico de seis meses:** la línea del límite sube y baja con la tasa; el globo de cada mes dice su tasa.
- **Resumen del mes:** bajo los totales, «Incluye 2 límites en dólares convertidos al promedio de noviembre (3,70).»
- Lectura de VoiceOver de la fila: «Renta, límite 1.850 soles, 500 dólares convertidos».

### 8 · Datos y sincronización (pregunta `sync`, opción A)

Cuatro propiedades nuevas en `CashFlowLine`:

| Propiedad | Tipo | Qué guarda |
|---|---|---|
| `scheduledPaymentIDsRaw` | `String?` | ids de los pagos, separados por coma, en orden |
| `limitExtraAmount` | `Double?` | el extra, en la moneda del flujo |
| `limitCurrencyCode` | `String?` | moneda del monto fijo; `nil` = la del flujo |
| `limitForeignAmount` | `Double?` | el monto fijo en esa moneda |

- **Versiones viejas:** `scheduledPayment` sigue guardando el primer pago (una versión anterior ve una línea de un
  pago) y `manualAmount` guarda el convertido al guardar (ve el monto fijo en soles, del orden correcto).
- **iCloud:** cuatro campos nuevos (`CD_scheduledPaymentIDsRaw` STRING, `CD_limitExtraAmount` DOUBLE,
  `CD_limitCurrencyCode` STRING, `CD_limitForeignAmount` DOUBLE) en los cuatro `Cloudkit Schemas/yala*.ckdb` del mismo
  PR (`PersonalCloudKitSchemaParityTests`) y **desplegados a Production antes de subir el build** (regla de
  `swiftdata-cloudkit.md`).
- **Modo Nube:** cuatro columnas en `cashflow_lines` con `since: 8` en `capability_manifest.json`, su migración de
  Supabase y su emisión/aplicación, con el molde de `amount_changes_raw` (`CashFlowAmountChangeSyncTests`).
- **Motor:** `FlujoMotorMes.Linea.pagoID` pasa a un conjunto de ids; `Dueños.porPago` apunta cada id a su línea y
  `pagoDe` devuelve el conjunto («Ya programado» suma los pendientes de todos).
- Riesgo conocido del molde: dos teléfonos que cambian la lista de pagos a la vez se quedan con la última escritura,
  igual que `amountChangesRaw` (ticket `cashflow-amount-changes-from-two-phones-overwrite-each-other`).

## Criterios de aceptación

- [ ] Una línea puede tener 1 o más pagos planificados; su límite del mes es la suma de los pagos que caen en ese mes,
      convertidos, más el extra.
- [ ] Cambiar el importe de un pago cambia el límite de la línea sin tocar la línea.
- [ ] Un pago no puede estar en dos líneas: elegirlo en otra lo mueve, avisando.
- [ ] Pago borrado: sale; línea sin nada → monto fijo con su último límite y aviso una vez. Pausado: no suma.
      Terminado: no suma después de su fin.
- [ ] El movimiento registrado de cualquiera de los pagos cuenta en la línea (motor del mes).
- [ ] «Monto fijo» acepta otra moneda; se ve el original y su conversión con la tasa del mes.
- [ ] Tasa: mes cerrado = promedio de sus días; en curso = promedio de lo que va; futuro = última conocida con «≈».
- [ ] Fila, detalle («Cómo se convierte») y resumen del mes enseñan el original y la tasa, con lectura de VoiceOver.
- [ ] Pagar en la moneda del límite exactamente el límite no da «Te pasaste» por la diferencia de tipo de cambio.
- [ ] Una versión anterior abre el plan sin perder la línea: ve el primer pago y el monto fijo convertido.
- [ ] Los cuatro campos viajan por iCloud y por el Modo Nube; schema de Production desplegado antes del build.
- [ ] Textos nuevos en su tabla (`FlujoDetalleLinea.strings` / `FlujoCambiarLimite.strings`), los 16 idiomas.
- [ ] Claro y oscuro; texto grande hasta AX5 sin cortes.

## Pruebas previstas

- **Unit (Swift Testing):** suma de varios pagos con monedas mezcladas y extra; pago anual que cae y no cae en el mes;
  pausado; terminado; borrado → monto fijo con el último límite; promedio de la tasa (cerrado, en curso, futuro, días
  sin tasa) con control rojo (una tasa ≠ 1 que distinga promedio de última); motor con dos pagos en una línea
  (los movimientos de los dos cuentan, ninguno en «Otros»); mover un pago de línea.
- **Sync:** emisión y aplicación de las cuatro columnas `since: 8` y su ausencia en `v7`
  (molde `CashFlowAmountChangeSyncTests`); paridad de los `.ckdb`.
- **XCUITest:** elegir dos pagos y un extra en «Cálculo del monto» y ver la cifra; monto fijo en USD y ver «≈ S/» en
  la fila y en el detalle; abrir «Cómo se convierte».
- **Device-QA (iPhone 14):** una línea Renta con un pago de 500 USD y otra Suscripciones con tres pagos; cambiar un
  pago y ver el límite; borrar un pago y ver el aviso.

## Fuera de alcance

- Un tipo de cambio escrito a mano por la persona.
- «Solo este mes / desde este mes» para un monto fijo en otra moneda (primera versión: todos los meses).
- El extra en una moneda distinta de la del flujo.
- Pagos de grupo (`groupZoneID`) dentro de una línea: siguen el camino de hoy.
