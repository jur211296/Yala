# Revisión por vistas 2.3 · Bandeja, Yala IA, correo del banco, Apple Pay y Siri (zona 38)

Revisión de UX y eficiencia de lo que Yala apunta por ti y cómo lo revisas, con el caso de Lucía: 8 borradores en la Bandeja
(uno dudoso y uno de grupo), una pregunta a Yala IA, y configurar el correo del banco y el atajo de Apple Pay; también sin
conexión y sin Pro. No implementa nada y no elige: cada problema prioritario trae de tres a cuatro alternativas maquetadas y
una recomendación. Decide Jürgen.

- **Abrir:** `index.html` (se abre en el móvil y en la Mac; capturas y estilo van al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-bandeja-ia.pdf` (66 páginas, ~8 MB).
- **Regenerar:** `cd fuente && python3 build.py` (con `--todo <ruta>` deja la página única para imprimir el PDF).

## Vistas cubiertas

InboxView, InboxDraftRowView, InboxApproveSuccessView, InboxBulkApproveSuccessView, GroupDraftLinkCandidatesView,
ChatSheetView, ChatAttachmentsView, BankEmailForwardingView, ApplePayAutomationGuideView y SiriShortcutsView. 57 capturas del
simulador (de 116 tomadas; iPhone 17 Pro e iPad Pro 13, iOS 27.2) con datos ficticios, incluidas texto grande (AX3) e iPad.
Para tener el caso se añadió a la semilla de prueba, solo en local, seis borradores (correo del banco, Apple Pay, Siri, pago
planificado, el dudoso y la cena de grupo con su candidato) y dos variantes del correo (prueba agotada y sin conexión):
`fuente/semilla-bandeja-8.patch` y el conductor de capturas `fuente/Revision38CapturasUITests.swift.txt`; ninguno va en la app.

Siri por voz y Apple Pay real no se conducen en el simulador: se revisan sus pantallas y sus borradores. «Sin conexión» del
chat sale del simulador sin servidor; el modo avión de verdad sigue el mismo camino según el código, sin medir en un iPhone.

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | Lo que se apunta solo vive en tres sitios (dos filas de Ajustes tras «Temas» y una guía en Ayuda › Tutoriales); con iCloud la fila del correo no existe; ninguna pantalla dice si funciona (el último aviso del banco llega del servidor y no se pinta) | A2: una pantalla «Lo que se apunta solo» con el estado de cada entrada (+ los textos de A4) |
| 2 · alta | Revisar 8: «Guardar los 6 listos» va bien, pero la selección lleva a «Editar» que guarda, deslizar a la derecha guarda sin pista, y el dudoso y la cena quedan mezclados por fecha | B1: «Necesitan algo» arriba y «Listos» con su botón; «Deshacer» en vez de la alerta (+ nombres de B4) |
| 3 · alta | El dudoso enseña «55 %» sin explicar; «Posible duplicado» sale tras 4 pasos y no dice cuál; el lote y deslizar guardan sin mirar duplicados | C1: nombrar el posible duplicado en la fila y en el borrador, con «Es el mismo / Es otro» (+ C3, el lote no lo guarda) |
| 4 · media-alta | El gasto de grupo pide «Elige la cuenta» y «Finalizar» cuando la respuesta es «¿Ya lo apuntaste?»; no dice que tu parte es S/ 40 | D1: la pregunta primero, con el reparto en una línea |
| 5 · media-alta | Yala IA sin servidor dice «no disponible… en unos minutos» y apaga la caja; sin Pro y sin conexión, muro sin precios y botón apagado | F1: decir «sin conexión» al abrir y ofrecer apuntar a mano (+ F3 para el muro, aparte) |
| 6 · media-alta | Correo del banco: cinco pasos (tres en Gmail web) y nunca se sabe si funcionó; sin conexión todo apagado | E1: estado vivo «Funcionando / Aún no llega» (+ E4, la fila se ve con iCloud y explica por qué) |
| 7 · media | Con texto grande se parten los botones que deciden («Edi-tar», «Gua rdar», «S/ 120.0 0»); el pie de las guías tapa ¼ de pantalla; «Bandeja de En…» | G1: apilar las barras de botones (+ G2 y G3, baratos) |

Eficiencia, medido (Debug, simulador, 8-10 borradores): abrir la Bandeja tarda **162 ms de mediana** (155-589, 19 aperturas,
marca `PERF bandeja`); las cuatro lentas son la primera tras arrancar. Hipótesis leídas en el código, con cómo medirlas: cada
pintado recorre la lista unas diez veces; la lista lee como mucho los 500 borradores más recientes, archivados incluidos (un
pendiente antiguo podría quedar fuera); tres lecturas por cada cambio de datos. Falta una semilla con historial largo.

Hallazgo secundario de severidad alta: la pantalla de Siri dice «Requiere Yala Pro» aunque «Anota un gasto en Yala» funciona
sin Pro en el teléfono con el modelo de Apple listo (`SiriShortcutsView.swift:106,121` frente a `SiriOnDeviceEntry.swift:30-33`).

## Decisiones para Jürgen

1. Problema 1: ¿una pantalla «Lo que se apunta solo» en Ajustes (A2) o conectar desde la Bandeja (A1)? ¿Apple Pay sale de Tutoriales? ¿Con iCloud la fila del correo se enseña explicando por qué? ¿Se pinta ya el último aviso del banco?
2. Problema 2: ¿la Bandeja se agrupa en «Necesitan algo / Listos» (B1)? ¿«Deshacer» sustituye la alerta del lote? ¿Se queda deslizar a la derecha para guardar?
3. Problema 3: ¿se busca el duplicado al llegar el borrador (C1)? ¿El lote y deslizar saltan los posibles duplicados (C3)? ¿Se guarda el texto del aviso del banco (C2)? Hoy la pantalla promete que no.
4. Problema 4: ¿la hoja del gasto de grupo abre con «¿Ya lo apuntaste?» (D1)? ¿«Finalizar» pasa a «Guardar»?
5. Problema 5: ¿el chat distingue «sin conexión» al abrir (F1)? ¿El muro de Pro sin conexión ofrece lo gratis (F3)?
6. Problema 6: ¿estado vivo del correo (E1) y fila visible con iCloud (E4)? ¿Elegir banco primero (E2), con la lista de remitentes a mantener? ¿Qué pasa con los avisos «que llegaron sin leerse» al pasar a Pro?
7. Problema 7: ¿lote de texto grande G1 + G2 + G3? ¿«Bandeja de Entrada» pasa a «Bandeja» en toda la app? ¿Qué patrón tiene la Bandeja en el iPad (hoy, hoja centrada de ~400 pt)?
8. Secundario: ¿se corrige ya «Requiere Yala Pro» en la pantalla de Siri para teléfonos con el modelo de Apple?
