Encargo: «Tras salir de la nube, «Borrar todo y continuar» con cambios de grupos acaba en «No pudimos borrar todo»»
Card del tablero: tablero-tras-salir-de-la-nube-borrar-todo-y-cont-8xt4 (Yala, versión 2.1, prioridad alta, cierra sola).

CONTEXTO (de la card)
- Visto en el barrido de QA 2.1 (15-oct) en el simulador. Con cambios de grupos sin subir, tras salir de la nube, «Borrar todo y continuar» debería enseñar la oferta de perderlos con su cifra (decisión A de la card 069g, «Decidir: tras cancelar la entrada con la nube, «Borrar todo y continuar» se niega en bucle con cambios de grupos (A/B/C)», implementada en PR #372). En cambio sale la puerta privada con «No pudimos borrar todo». Sin el cambio de grupos pendiente, llega al onboarding.
- Ticket: tickets/backlog/fresh-start-after-adopt-exit-with-group-changes-ends-in-device-wipe-failed.md
- Repro: -uitest -uitest-reset -uitest-seed minimal -uitest-welcome-after-adopt-exit -uitest-groups-outbox-pending → «Es mi primera vez» → «Borrar todo y continuar».
- Capturas del bug en ~/Claude/worktrees/_capturas/2026-10-15-barrido-qa-2-1/c5-*
- Mientras no se aclare, C5 sale de la tanda de Jürgen (docs/qa/tanda-qa-jurgen-2.1.md). Si lo arreglas, deja anotado en la card 069g que C5 puede volver a la tanda (guion fresh-start-shell-alert-after-an-adopt-exit-has-no-way-out-for-group-changes).
- Hecha cuando: la oferta de perder los cambios de grupos sale con su cifra en ese camino, con XCUITest; o se demuestra que es del seam (-uitest-groups-outbox-pending) y se arregla el seam.

RAMA
- Base: origin/2.1. Antes de abrir el PR: git fetch + rebase sobre origin/2.1. No esperes al CI del PR anterior; #517 («Volver a iCloud» avisa si el iCloud ya tiene datos de Yala) puede estar aún en cola de merge: rebasa sobre lo que haya en origin/2.1 en ese momento.

PIPELINE DE SIMULADOR (serial, 1 simulador a la vez en esta Mac)
1. Limpia simuladores muertos/sobrantes (xcrun simctl shutdown/delete), dejando de serie solo «iPhone 17 Pro» y «iPad Pro 11-inch (M5)» apagados.
2. xcodebuild con -jobs 2 SIN ningún simulador iniciado.
3. Inicia 1 solo simulador, prueba.
4. Al terminar, apágalo y límpialo.
No toques nada de la sesión tmux Yala--qa-guiado-2-1-tanda-2 (es de Jürgen) ni nada de salud / clinicas-dentales-bi.

PRUEBAS
- Pruébalo sola al máximo con simulador: XCUITest del camino, tests unitarios, y capturas antes/después siguiendo el criterio de /barrido-qa.
- Solo lo que sí o sí pida un iPhone real (p. ej. salida real de adopt con sign-in Apple/Google) queda para Jürgen con un guion corto: en ese caso la card pasa a «in qa» asignada a jurgen. Si no, la card pasa a «done» con la evidencia (PR, tests, capturas).

TICKETS Y TABLERO
- Todo ticket nuevo debe tener card en el tablero (1:1, o una card que lo cubra y con cuyo cierre se cierre el ticket). Usa tablero con --agente frank al crear.

CIERRE
- CIERRA SOLA con /cerrar-total sin esperar a Jürgen (no requiere validación urgente). No le escribas a nadie.

## Paso 0 (Frank, 2026-10-15 — auto-contestado, modo autónomo)

1. **¿Seam o producto?** No se decide leyendo: se instrumenta `performDeviceCorpusWipe` y la subida previa con `NSLog`
   temporal y se mide en el simulador con el repro de la card. El control «sin grupos» no sirve de descarte: sin cambios
   de grupos el alert borra en el sitio y nunca pasa por la puerta.
2. **Alcance del arreglo**: el que salga de la medición. Producto → arreglo mínimo en el camino de la puerta + XCUITest
   del camino. Seam → arreglar el seam + XCUITest. Sin tocar copy ni otras pantallas.
3. **Entrega**: worktree → rama + PR, `/gate` antes del commit, auto-merge en cola (ADR-054).
4. **Card**: a `done` si todo se prueba en simulador; nota en la 069g de que C5 puede volver a la tanda.
5. **Device-QA**: solo si el arreglo depende de algo que el simulador no tiene (sign-in real).
