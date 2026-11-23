---
id: 2026-11-18-bandeja-aprobar-y-recurrente-choca-con-posible-duplicado
status: done
priority: low
area: qa
created: 2026-11-18
updated: 2026-11-22
source: gate del asistente de «Nuevo pago planificado» (2026-11-18)
---
# La prueba de «Aprobar y hacer recurrente» desde la Bandeja se para en «Posible duplicado»

`RecurrenteDesdeRegistroUITests.test_inbox_approveAndMakeRecurring_approvesAndOpensTheEditor` cayó el 18-nov a las
06:27 (Lima) en el iPhone 17 Pro, iOS 27.2, corriendo solo en el simulador (centinela: un runner).

## Qué se vio

- Medido: el último fotograma de la grabación del `.xcresult` enseña la hoja «Editar borrador» de «Taxi aeropuerto»
  (15 nov 2026) con el aviso «Posible duplicado · Ya existe un registro parecido. ¿Guardarlo de todas formas?». El
  formulario de pagos nunca llegó a abrirse; la aserción que cae es «No se abrió el editor de recurrentes».
- Inferido, sin bisecar: el aviso depende de lo que la semilla `minimal` tenga cerca de la fecha del borrador, que se
  mueve con el día. El cambio que corría el gate (el asistente de «Nuevo pago planificado») no toca la Bandeja ni el
  aviso de duplicados.

## Qué hacer

- Que la prueba conteste el aviso si sale («Guardar de todas formas» lleva al mismo sitio), o que el borrador de la
  semilla no tenga un parecido. Medirlo antes con la fecha fijada (`testing.md`, escenarios que pone la semilla del día).

## Cierre (2026-11-22, encargo «Bandeja: aprobar y hacer recurrente, y cierre»)

- La causa de este rojo (un transporte de −18 de la semilla en hoy−3, gemelo de «Taxi aeropuerto») ya la quitó
  57d54796a: los borradores de la semilla llevan céntimos.
- El camino con el aviso queda fijado con su propia semilla (`-uitest-inbox-duplicate-draft`), en
  `YalaUITests/BandejaRecurrenteCierre/BandejaRecurrenteDuplicadoUITests`: «Crear de todas formas» aprueba y abre el
  editor de recurrentes prellenado; «Cancelar» no guarda y el «Guardar» de después enseña la pantalla de éxito, no el
  editor. Los botones del aviso llevan id (`inbox_duplicate_cancel`, `inbox_duplicate_save_anyway`). Verdes 2 de 2; el
  segundo cae con el mutante que quita el desarme de «Guardar» (medido).
