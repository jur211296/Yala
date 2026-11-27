Yala
# Actualizar todos los videos de tutoriales a los flujos de 2.3
---
toca: Yala/Resources/tutorial-createAccount-step0.mp4,Yala/Resources/tutorial-createAccount-step1.mp4,Yala/Resources/tutorial-createAccount-step2.mp4,Yala/Resources/tutorial-createBudgets-step0.mp4,Yala/Resources/tutorial-createBudgets-step1.mp4,Yala/Resources/tutorial-createBudgets-step2.mp4,Yala/Resources/tutorial-createBudgets-step3.mp4,Yala/Resources/tutorial-createCategories-step0.mp4,Yala/Resources/tutorial-createCategories-step1.mp4,Yala/Resources/tutorial-createCategories-step2.mp4,Yala/Resources/tutorial-createCategories-step3.mp4,Yala/Resources/tutorial-createFavorites-step0.mp4,Yala/Resources/tutorial-createFavorites-step1.mp4,Yala/Resources/tutorial-createRecord-step0.mp4,Yala/Resources/tutorial-createRecord-step1.mp4,Yala/Resources/tutorial-createRecord-step2.mp4,Yala/Resources/tutorial-createRecord-step3.mp4,Yala/Resources/tutorial-createScheduledPayments-step0.mp4,Yala/Resources/tutorial-createScheduledPayments-step1.mp4,Yala/Resources/tutorial-createScheduledPayments-step2.mp4,Yala/Resources/tutorial-createScheduledPayments-step3.mp4,Yala/Resources/tutorial-createScheduledPayments-step4.mp4,Yala/Resources/tutorial-createTags-step0.mp4,Yala/Resources/tutorial-createTags-step1.mp4,Yala/Resources/tutorial-editPanel-step0.mp4,Yala/Resources/tutorial-editPanel-step1.mp4,Yala/Resources/tutorial-editPanel-step2.mp4,Yala/Resources/tutorial-importData-step0.mp4,Yala/Resources/tutorial-importData-step1.mp4,Yala/Resources/tutorial-inboxApproval-step0.mp4,Yala/Resources/tutorial-inboxApproval-step1.mp4,Yala/Resources/tutorial-inboxApproval-step2.mp4,Yala/Resources/tutorial-inboxApproval-step3.mp4,Yala/Resources/tutorial-panelFiltering-step0.mp4,Yala/Resources/tutorial-panelFiltering-step1.mp4,Yala/Resources/tutorial-panelFiltering-step2.mp4,Yala/Resources/tutorial-panelFiltering-step3.mp4,Yala/Resources/tutorial-panelFiltering-step4.mp4,Yala/Resources/Assets.xcassets/tutorial-applePay-step0.imageset,Yala/Resources/Assets.xcassets/tutorial-applePay-step1.imageset,Yala/Resources/Assets.xcassets/tutorial-applePay-step2.imageset,Yala/Resources/Assets.xcassets/tutorial-applePay-step3.imageset,qa/scripts/tutorial-videos/record.sh,YalaUITests/Flows/TutorialVideoRecordingUITests.swift,Yala/App/Models/TutorialCatalog.swift,YalaTests/TutorialesVideos23,tickets/backlog/2026-11-26-actualizar-videos-tutoriales-2-3.md,tickets/done/2026-11-26-actualizar-videos-tutoriales-2-3.md
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/compartido-3-invitar-persona-y-entrada-sin-grupo
---

Decisión de Jürgen (26-nov, 17:55 Lima) sobre la primera pasada de hallazgos de cierres: «B. Ok a la cola · C. Ok encola. Todos los tutoriales podríamos actualizarlos · D. Ok». Espera al último lote de «Compartido» porque cambia el nombre de la sección y la entrada a Grupos, que salen en varios videos. Así se graban los flujos finales de 2.3.

## Contexto
- Card del tablero de Yala 2.3 (búscala por título con `tablero listar --proyecto Yala`): «Actualizar todos los videos de tutoriales a los flujos 2.3». Al terminar, muévela a done con su «hecha cuando» cumplido.

## Qué se pide
Jürgen pidió actualizar **todos** los tutoriales. Varios cierres anotaron que hay videos viejos: «Crear presupuestos», «Crear una cuenta» y favoritos muestran el formulario y no el asistente actual.
1. **Inventario:** para cada tutorial de Ajustes › Tutoriales (`TutorialCatalog.swift`), compara cada paso con el flujo real de 2.3. Hoy son 38 clips: `Yala/Resources/tutorial-<tutorial>-step<N>.mp4` de createAccount, createBudgets, createCategories, createFavorites, createRecord, createScheduledPayments, createTags, editPanel, importData, inboxApproval y panelFiltering; más las 4 imágenes de Apple Pay en `Assets.xcassets`. Deja una tabla con lo vigente y lo viejo, y el porqué.
2. **Regrabar todo lo viejo** con el flujo actual. Usa la herramienta que ya existe: casos en `YalaUITests/Flows/TutorialVideoRecordingUITests.swift` y `qa/scripts/tutorial-videos/record.sh`, que graba con apretón de manos. Ajusta los casos a los flujos nuevos, por ejemplo el asistente en lugar del formulario. Mismo formato, resolución, marco y nombres de archivo, para que la app no cambie.
3. Si un tutorial necesita **pasos nuevos o distintos** (más o menos clips, textos de los pasos), ajusta `TutorialCatalog.swift`. Si hacen falta textos nuevos, es pregunta para Jürgen antes de inventarlos, porque esta sesión no toca tablas de textos. Si el flujo de un tutorial ya no existe, propón qué hacer y no lo borres.
4. Graba en simulador con datos de demostración limpios (sin datos reales). Si algo solo se ve bien en dispositivo, puedes usar el iPhone 14 por DeviceMCP. Revisa cada clip antes de copiarlo a `Yala/Resources`: sin teclados raros, sin avisos del sistema y sin cortes.
5. Cuida el peso del paquete: que el total de los videos no crezca mucho respecto de hoy. Anota el antes y el después en MB.
- Una prueba en `YalaTests/TutorialesVideos23/` que confirme que cada paso del catálogo tiene su clip en el paquete y que no queda ningún clip huérfano.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio de código con su prueba en la carpeta de pruebas de este encargo.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Puedes usar un segundo simulador en la Max o el iPhone 14 («iPhone de JURGEN», conectado a la Max) por DeviceMCP; en la Mini, un solo simulador. Si usas el iPhone, comprueba antes que no esté bloqueado; si lo está, sigue con el simulador y anótalo. Apaga lo que enciendas. No borres datos del iPhone.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Nada fuera de `toca:`; si necesitas otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.

## Cierre
- Entrega: **artifact visual de Claude** con cada tutorial antes y después (fotogramas clave de cada clip viejo y nuevo, y qué cambió), enlazado en el cierre. No Markdown, PDF ni documento de puro texto.
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, nocturno): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué clips se regraban?** → Los 38. Las 4 imágenes de Apple Pay se quedan.
Por qué: los 38 muestran pantallas de 2.2 (Panel, Ajustes, hoja vieja de Nuevo registro, formularios en vez de asistentes); los 5 de «Filtrar el Panel» son de la 1.1. Apple Pay son capturas de la app Atajos de iOS 27 (21-oct) y las acciones de Yala que enseñan siguen con el mismo nombre. Alternativa descartada: regrabar solo los tres que citaron los cierres (el inventario dijo que no había ninguno vigente).

**D2 · Pasos cuyo texto ya no casa con 2.3 (favoritos «debajo del monto», pago planificado «En Más opciones»)** → No se tocan textos; el clip enseña el flujo real y el desajuste va a una card para Jürgen.
Por qué: el encargo prohíbe tocar tablas de textos sin preguntar, y en nocturno no se espera respuesta; un texto algo desfasado no bloquea. Alternativa descartada: checkpoint nocturno (no es una decisión vital).

**D3 · Mismo número de pasos por tutorial** → Sí; `TutorialCatalog.swift` no cambia.
Por qué: más o menos pasos exigiría textos nuevos (pregunta a Jürgen). Cada paso actual tiene un flujo real que enseñar.

**D4 · Asistente o formulario** → El asistente, que es lo que abre el «+» en 2.3. «Usar formulario» no se enseña.
**D5 · «Mostrar en el widget» de presupuestos no está en el asistente** → El clip lo enseña editando un presupuesto que ya existe.
**D6 · «Filtrar el Panel» no tiene casos de grabación** → Se escriben 5 casos nuevos con el Panel y Estadísticas de 2.3.
**D7 · Datos y aspecto** → Semilla `realista`, Pro, tema oscuro de fábrica y es-PE, como la tanda del 22-oct. Simulador iPhone 17 Pro de la Max; el iPhone 14 no hace falta.
**D8 · Formato** → El mismo `record.sh` (1080×1080, marco, H.264 crf 26). Se le añade un modo por lotes (una corrida de `xcodebuild` para varios casos) para no pagar el arranque 38 veces.
**D9 · Presupuesto de 30 min de pruebas de interfaz** → Las corridas de grabación son la entrega, no pruebas; se miden aparte y se anotan. Las pruebas de verdad (unit de catálogo, gate) sí cuentan.
