Yala
# Nuevo registro: que la pantalla de éxito aparezca siempre al guardar
---
toca: Yala/App/Views/Transactions/NewTransactionView.swift, Yala/App/Views/Transactions/TransactionSuccessView.swift, Yala/App/Views/Transactions/Components/NuevoRegistroB1Pieces.swift, Yala/App/Logic/NuevoRegistroB1Logic.swift, Yala/App/ContentView.swift, YalaTests/NuevoRegistroExitoSiempre/, YalaUITests/NuevoRegistroExitoSiempre/, tickets/backlog/nuevo-registro-exito-no-aparece.md, tickets/done/nuevo-registro-exito-no-aparece.md
esfuerzo: medium
cierre: cierra-sola
---

## Qué pasa
Jürgen (2026-11-23, 7:28 Lima), en su iPhone con la build de TestFlight de 2.3: al guardar registros nuevos ya no aparece la pantalla de éxito. Decisión registrada: **la pantalla de éxito aparece siempre** al guardar un registro nuevo, sin excepciones. Card del tablero: «Nuevo registro: la pantalla de éxito no aparece al guardar» (prioridad alta).

## Qué hacer
1. Reproduce el bug en el simulador o en el iPhone 14 por DeviceMCP. Antes de usar el simulador, verifica si el iPhone está libre; no lo des por ocupado sin comprobarlo. Si chocas con otra sesión, puedes usar un segundo simulador.
2. Encuentra la causa. Sospecha principal: el rediseño B1 con éxito minimalista (PR 1081, 20-nov), o una regla vieja que la omite (p. ej. con «Agregar otro», después del N-ésimo registro, por el aviso de notificaciones, por el modo de teclado). Revisa también el historial (`git log -S`) de las condiciones que deciden presentar `TransactionSuccessView`.
3. Quita toda condición que la salte. «Agregar otro» es otro flujo; no lo rompas, pero si hoy omite el éxito, anótalo en el cierre en vez de cambiarlo.
4. Prueba unitaria en `YalaTests/NuevoRegistroExitoSiempre/` y prueba de interfaz en `YalaUITests/NuevoRegistroExitoSiempre/` para gasto, ingreso y transferencia.
5. Captura de la pantalla de éxito apareciendo, en el PR.

## Hecho cuando
Al guardar cualquier registro nuevo (gasto, ingreso o transferencia), la pantalla de éxito aparece siempre, con pruebas que lo cubren, el PR mergeado en 2.3 y la card en hecho.

## Reglas
- PR contra 2.3; commits y PR sin firma de IA.
- Espera el merge real del PR antes de `/cerrar-total`. Si a los ~45 min el CI sigue rojo por algo que no es tuyo, cierra y anótalo.
- Lo menor y reversible lo decides tú y lo anotas en «Decidido sin consultar». Si algo es vital, pregunta según el modo de la sesión; no inventes.
- El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».
- Al terminar: `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (sesión semi, sin Jürgen delante): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hecho medido · causa.** `TransactionSaveFeedbackLogic.feedback` solo daba pantalla completa con `transactionsSavedCount <= 3`; desde el cuarto registro, `NewTransactionView.finishSave` cerraba el formulario con el aviso breve «Gasto guardado · Deshacer» (UX 2.2 · L2-5, decisión del 14/21-oct, commit del lote decidido 2.2 · 02). No es el rediseño B1: la regla vieja.

**D1 · ¿Qué ve quien guarda un registro nuevo con «Guardar»?** → La pantalla de éxito, siempre, en gasto, ingreso y transferencia. La edición sigue con «Cambios guardados».
Por qué: decisión de Jürgen del 23-nov («sin excepciones»), que supersede L2-5 en el guardado normal. Alternativa descartada: subir el umbral (no es lo decidido).

**D2 · ¿Se conserva el caso `savedNotice` de la lógica?** → Se retira de `TransactionSaveFeedbackLogic` (con el umbral `fullScreenRecords`). `SavedRecordNotice.message(for:formattedAmount:)` y sus tres textos («Gasto guardado · …») quedan sin usos pero se conservan.
Por qué: un caso sin productor en la lógica es código muerto; los textos están traducidos a 16 idiomas y retirarlos agranda el diff y hace caro volver atrás si Jürgen quiere el aviso en otro sitio. Se anota en «Encontrado».

**D3 · «Agregar otro» y «Hacer recurrente».** → No se tocan. «Agregar otro» deja la hoja abierta con un toast (otro flujo, el encargo lo excluye). «Hacer recurrente» guarda y cierra con «Guardado · se repetirá cada mes»: es un gesto distinto de «Guardar» y su aviso dice algo que la pantalla de éxito no dice. Se anota en el cierre para que Jürgen decida si también debe llevar éxito.
Por qué: cambiarlo multiplica alcance (hoja del editor completo encima, permiso de notificaciones de pago planificado). Alternativa descartada: forzar éxito también ahí sin preguntar.

**D4 · Pruebas de interfaz que dependían del aviso tras el cuarto registro.** → Las que prueban el aviso (Deshacer, Editar, posición, el «+» con el aviso) pasan a provocarlo por «Hacer recurrente», que sigue enseñándolo; la de «los tres primeros» se queda.
Por qué: conservan la cobertura del aviso sin depender de un camino que ya no existe.

**D5 · ¿ADR?** → No. La decisión vive en el ticket y en la regla del código (`TransactionSaveFeedbackLogic`), y se registra con `decisiones.py incorporar-lote`.
