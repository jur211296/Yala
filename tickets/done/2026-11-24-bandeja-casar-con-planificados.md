---
id: 2026-11-24-bandeja-casar-con-planificados
status: done
area: "bandeja, pagos planificados, apple pay, correo del banco, aviso del banco, yala web, conector de IA"
created: 2026-11-24
updated: 2026-11-25
source: "Jürgen, 24-nov (14:30 y 14:32 Lima): «vamos con todo lo recomendado» de docs/propuestas/bandeja-sin-duplicados/README.md (opción B). Lote 4 del plan, en 2.3"
---

# Bandeja: lo que casa con un pago planificado no crea pendiente y el estimado toma el monto real (lote 4)

## Qué se pidió
Lo que casa con un pago planificado (nombre o comercio aprendido, importe dentro de tolerancia o planificado estimado,
±5 días del vencimiento) no crea pendiente: completa el borrador del planificado, o lo adelanta si aún no venció. Si era
estimado, le pone el monto real con «Antes S/ 120 estimado». Monto fijo con cargo distinto: pregunta. La primera vez
que un comercio casa con un planificado se pregunta y se aprende el alias. Grupos fuera.

## Qué cambia para la persona
- El correo de Luz del Sur, el Apple Pay de Netflix o el aviso del banco de un pago que ya tienes planificado ya no
  aparecen como un pendiente aparte: completan el borrador de ese pago planificado, que toma el importe que cobró el
  banco y la fecha del cargo. La nota, la cuenta y la categoría siguen siendo las del pago planificado.
- Si el pago aún no vencía (cobro adelantado), su borrador aparece ya con el cargo dentro; el día que vence no sale otro.
- Si el pago era **estimado**, la fila dice el monto real y debajo «Antes S/ 120.00 estimado».
- **La primera vez** que un comercio casa con un pago planificado, o si un pago de **monto fijo** cobró otro importe, la
  Bandeja pregunta en una tarjeta «¿Es tu pago «Luz del Sur»?» con **Sí, es ese pago** (los junta y aprende el comercio:
  la próxima vez lo hace sola) y **No es ese pago** (quedan aparte y no vuelve a preguntar en este teléfono).
- «Separar» en el borrador lo deshace: el cargo vuelve como pendiente propio y, si el borrador del planificado solo
  existía por ese cargo, se va.
- El pago planificado no cambia: ni su importe ni su próxima fecha, que avanza al guardar como siempre.

## Decisiones (Paso 0 del encargo, auto-contestado en nocturno)
- Regla: alias aprendido = fuerte; solo el nombre del planificado = dudoso (se pregunta). Estimado: fuerte entre la mitad
  y el doble. Fijo: fuerte al céntimo, dudoso hasta ±25 %. Otra cuenta, otra moneda o moneda sin decir: como mucho
  dudoso. ±5 días de calendario. Una fuente por borrador (uno a uno).
- El alias se aprende sin campo nuevo: son los comercios de lo ya unido a los borradores (pendientes y aprobados) de ese
  planificado, que viajan en `joinRecordRaw`. Sin migración, sin `.ckdb` y sin columna en la nube.
- «No es ese pago» se recuerda solo en este teléfono, como «Son distintos».
- Un borrador de planificado con algo unido entra en el emparejador entre fuentes: el correo que llega después del
  Apple Pay ya unido se suma al mismo borrador.

## Qué se tocó
- `BandejaPlanificadoMatchLogic` (pura): la regla, elegir el mejor y las preguntas uno a uno.
- `InboxPlannedJoin` (nuevo) e `InboxArrivalJoin`: casar al llegar, adelantar, «Sí, es ese pago» y «Separar».
- `InboxJoinRecord`: `holderCreatedByJoin`, `holderIsEstimate` (opcionales) y la nota del planificado que no se pisa.
- `InboxMatchLogic`: la fuente `planned`, la última en importe, hora y comercio.
- `InboxViewModel` (`plannedQuestions`, `InboxPlannedDistinct`), `InboxView`, `InboxPlannedQuestionCard`, la línea
  «Antes … estimado» en la fila, «Separar» en el editor.
- Textos en `BandejaUnir.strings` (16 idiomas); semilla `-uitest-inbox-planned-match`; clave retirada por el borrado.

## Pruebas
- `YalaTests/BandejaCasarConPlanificados/`: la regla pura (identidad, estimado, fijo, moneda, signo, ±5 días, cuenta,
  uno a uno, preguntas) y por el código real de cada fuente: E7 la primera vez (pregunta, «Sí» toma el monto real),
  E7 aprendido (se une solo), aprobar avanza el pago, adelantar y «Separar», fijo con otro importe, segunda fuente,
  grupo fuera, «No es ese pago» y fuera de los ±5 días.
- `YalaUITests/BandejaCasarConPlanificados/`: Sedapal adelantado con «Antes … estimado», la tarjeta de Luz del Sur y
  «Sí», y Netflix con su Apple Pay dentro.
- Las suites de la Bandeja (67 pruebas) pasan también con `TEST_RUNNER_TZ` en `Etc/GMT-12` y `Pacific/Kiritimati`.
- De paso: `BandejaFilaConFuentesUITests` (lote 3) dependía de la hora (antes del mediodía la fila que esperaba quedaba
  bajo el pliegue). Ahora espera el filtro y desplaza antes de afirmar: 2 de 3 casos verdes medidos; el tercero quedó
  sin correr por el tope de 30 min de interfaz.
- Queda para el iPhone: «Separar» sobre un borrador adelantado lo borra con la hoja abierta (mismo molde que «Eliminar
  para siempre»); el simulador no reproduce ese cierre.
