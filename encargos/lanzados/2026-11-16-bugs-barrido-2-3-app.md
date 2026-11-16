Yala
# Bugs del barrido final de 2.3 en la app: Panel vacío tras la entrada, cancelar la entrada y Vaciar mis datos
---
toca: Yala/App/Logic/AccountEntryLandingLogic.swift, Yala/App/Logic/CloudWelcomeSignInFlow.swift, Yala/App/Logic/WelcomeAdoptInFlight.swift, Yala/App/Logic/DestructiveScopeLogic.swift, Yala/App/Views/Onboarding/, Yala/App/Views/Panel/, Yala/App/Views/Settings/UserDataResetView.swift, Yala/Utils/DataWipeService.swift, Yala/Utils/L10n.swift, YalaTests/BarridoFinal23/, tickets/backlog/, tickets/done/
esfuerzo: high
cierre: cierra-sola
---

## Contexto
El barrido QA final de 2.3 (PR 985, `docs/qa/barrido-2-3-final/`, informe https://claude.ai/artifact/NcBeAxfFcFwg4i3aiuZf1a) dejó un fallo y bugs nuevos de la app. Jürgen pidió el 15-nov encolar todos. Lote de bugs (3 a 5 en una sesión, un PR):

1. Fallo (alta, Jürgen lo llamó grave el 13-nov): tras «¡Tu cuenta está lista!», el Panel muestra 10 a 18 s «S/ 0 · Aún no tienes registros · Crear categorías» y luego el saldo real (4 de 4 entradas). Debe mostrar un estado de carga honesto o los datos, nunca el vacío.
2. Bug alto: cancelar la entrada a una cuenta deja en el teléfono un gasto del grupo de esa cuenta (medido en el almacén, 12 s después) y la entrada siguiente acaba en el flujo de Grupos. Card «Cancelar la entrada a una cuenta deja en el teléfono gastos de su grupo…».
3. Bug alto: tocar el centro de «Vaciar mis datos» abre Exportar (3 de 3); con 0 registros no hay forma de vaciar así.
4. Bajo: la card «Detalles menores del barrido final de 2.3 (vuelta a iCloud, pasar a la nube, Yala IA en Grupos)».

Las cards exactas están en el tablero y en `docs/qa/barrido-2-3-final/lista.md`. Si `toca` se queda corto para un arreglo, amplíalo solo con el archivo puntual y anótalo.

## Qué se pide
- Reproduce cada uno en el iPhone 14 por DeviceMCP (Yala Dev de `origin/2.3`), arregla y prueba de punta a punta en el iPhone. Tests nuevos en `YalaTests/BarridoFinal23/`.
- Un solo PR a 2.3, mergeado si CI está verde. Cards a QA con evidencia.

## Entregable
Artifact visual corto de Claude: antes y después de cada bug con capturas del iPhone.

## Reglas
- Commits y PR sin firma de IA. No imprimas secretos. No toques CloudKit ni Supabase Production.
- Puedes usar un segundo simulador o el iPhone 14 por DeviceMCP.
- Lo menor y reversible se decide y se anota en «Decidido sin consultar».
- /cerrar-total al terminar.

## Paso 0 (Frank, 2026-11-16 04:10, nocturno)

Ficheros: los de `toca:` más, si el arreglo lo pide, `Yala/App/ContentView.swift` (salida del cancelar y entrada a la
cuenta), `Yala/App/ViewModels/PanelViewModel.swift` (espera del Panel), `Yala/App/Views/Groups/GroupReceiptSplitView.swift`
y `Yala/App/Logic/ReceiptSplitLogic*.swift` (descripción de Yala IA en Grupos), los `.strings` del aviso de Yala IA y
`qa/coverage-index.json`. Se anota en el PR.

Decisiones (default sensato, sin consulta: nocturno y todas reversibles):
1. **Panel tras «Empezar»**: se mide antes en el iPhone 14 por qué el Panel enseña S/ 0 con los datos ya en el teléfono.
   El arreglo cumple la regla de Jürgen del 13-nov: esqueleto o datos, nunca el vacío. Sin pantalla nueva ni copy nuevo.
2. **Cancelar la entrada**: al aterrizar la cancelación, lo que esa cuenta dejó en el teléfono se va (sesión de Grupos
   parada y filas del puente fuera). Nada se borra en el servidor ni en CloudKit.
3. **Vaciar mis datos**: cada botón recibe solo su toque; sin cambio visual.
4. **Detalles menores**: (3) Yala IA en Grupos rellena la descripción con el comercio o, sin él, con lo leído; (4) el aviso
   de Yala IA nombra también escribir. (1) y (2) se arreglan si caben sin tocar el servidor; si no, ticket con su motivo.
5. Un solo PR a 2.3, en cola de auto-merge. Device-QA que no quepa en el presupuesto queda en la card con su guion.
