Yala
# Pagos planificados: el logo del comercio en la lista, la línea de tiempo y el calendario
---
toca: Yala/App/Views/Planning/ScheduledPaymentsListView.swift,Yala/App/Views/Planning/ScheduledPaymentRowView.swift,Yala/App/Views/Planning/LogoComercio/,YalaTests/PagosLogoComercio/,tickets/backlog/records-and-panel-merchant-logos.md,tickets/done/records-and-panel-merchant-logos.md
esfuerzo: medium
cierre: cierra-sola
depende: Yala/asistente-nuevo-pago-planificado
---

Decisión de Jürgen del 18-nov (06:26 Lima), registrada, sobre la card «Registros y Panel: el logo del comercio en cada movimiento» (`tickets/backlog/records-and-panel-merchant-logos.md`): el logo va SOLO en Pagos planificados, en sus tres vistas (lista, línea de tiempo y calendario). No en Registros ni en el Panel.

## Qué hacer
- Usa el catálogo existente (`Yala/App/Logic/MerchantLogos/`, sin modificarlo) para mostrar el logo donde case el nombre del pago; donde no case, queda el icono actual.
- Ya existe `timelineBrandBadge` en la línea de tiempo: unifica el criterio en las tres vistas con una pieza en `Planning/LogoComercio/`.
- Mide el casado sobre la semilla `realista` y revisa una muestra; sin coste visible al desplazar.
- No hacen falta textos nuevos. Mueve el ticket a done con lo decidido (alcance solo Pagos planificados).

## Cómo entregar
- Base 2.3, un PR. Toca solo lo declarado; si algo imprescindible queda fuera, ponlo en una carpeta nueva dentro de lo declarado y anótalo.
- Tests de lo nuevo. Capturas antes y después (iPhone 17 y SE, también con letra grande, claro y oscuro, y iPad) cuando haya UI.
- Puedes usar un segundo simulador en la Max además del de otra sesión, o el iPhone 14 por DeviceMCP. En la Mini, solo uno.
- Entregable visual: artifact de Claude con antes y después y lo decidido.
- Commits y PR sin firma de IA. Textos nuevos solo en la tabla de strings declarada de cada `.lproj`, nunca en `Localizable.strings`. Nunca un botón debajo del otro.
- Lo vital, según el modo fijado al arrancar (semi: pregunta y espera viva; nocturno: checkpoint recuperable y card «Espera decisión», sin mergear lo incompleto). Lo menor, con la opción recomendada, en «Decidido sin consultar».
- Cierre: completo y CI verde, `/cerrar-total` con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0

Medido en la base (2.3 al 18-nov, tras el asistente de nuevo pago): **las tres vistas ya pintan el logo**, cada una por su
cuenta. La lista con `SubscriptionBrandBadge`, la línea de tiempo con `timelineBrandBadge` y el calendario con
`PaymentLogoCalendarMark`. Cada una llama a `ScheduledPayment.paymentLogo`, que recorre el índice del banco (~2.000 formas,
dos pasadas) en cada pintado; el calendario lo llama dos veces por pago y celda. Y la fila de la lista, con letra de
accesibilidad, pinta el icono de la subcategoría aunque el pago tenga logo.

| Decisión | Tomada | Por qué |
|---|---|---|
| Qué es «unificar» | Una pieza en `Planning/LogoComercio/` que decide logo o icono para las tres vistas | Hoy hay tres `if let` iguales y uno discrepa (fila con letra grande) |
| Coste al desplazar | Caché en memoria por (logo guardado, nombre) delante de `PaymentLogoResolver`, sin tocar el catálogo | El banco es estático; la clave cambia sola al renombrar o al elegir otro logo |
| Fila con letra grande | Pinta el logo también | Es el mismo pago; perderlo con letra grande era la discrepancia |
| Línea de tiempo sin logo | Sigue sin distintivo | Su «icono actual» es el círculo del día; el encargo dice que donde no case queda lo de hoy |
| Calendario | Mismas marcas, por la pieza común y la caché | Sin cambio visual |
| Medición del casado | Unit test que siembra `realista` en memoria y pasa sus nombres de pago por el casado, más los 16 idiomas de los nombres sembrados; y una muestra de descripciones de movimientos como control de falsos positivos | El encargo lo pide; deja la cifra fijada |
| Fuera de `toca:` | `qa/coverage-index.json` (el gate lo exige al tocar `Yala/`) y `docs/TICKETS.md` (índice del ticket movido) | Imprescindibles; anotados en el PR |
| Textos | Ninguno nuevo | El logo es decorativo junto al nombre |
