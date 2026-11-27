Yala
# Trabas: proyección inteligente de Flujo de caja, convertir a gasto compartido un registro leído de imagen y las dos animaciones de las hojas de captura
---
toca: Yala/App/Logic/FlujoProyeccionInteligente,Yala/App/Views/Image/ImageSelectionView.swift,Yala/App/Views/Inbox/DraftGroupConversionFlow.swift,Yala/App/Views/Voice/VoiceLiveListeningViews.swift,Yala/App/Views/Groups/GroupExpenseFormView.swift,Yala/App/ViewModels/GroupExpenseViewModel.swift,YalaTests/EficienciaAnimacionesVisibles/RepeatForeverConVisibilidadTests.swift,YalaTests/TrabasFlujoYConvertir,YalaUITests/TrabasFlujoYConvertir,tickets/backlog/2026-11-27-trabas-flujo-proyeccion-y-convertir-a-compartido.md,tickets/done/2026-11-27-trabas-flujo-proyeccion-y-convertir-a-compartido.md
modelo: opus
esfuerzo: high
cierre: cierra-sola
release: no
pruebas-ui: si
---

Decisión de Jürgen (27-nov, 06:17 Lima): aprobó encolar tal cual los tres lotes propuestos a partir de los hallazgos de los cierres del 26-nov y de los pendientes de 2.3. Corre en paralelo con «Eficiencia 7» (otra máquina): sus `toca:` no se cruzan.

## Contexto
- Cards del tablero de Yala 2.3 (búscalas por título con `tablero listar --proyecto Yala`): «Flujo de caja: la app se traba unos segundos calculando la proyección inteligente · YALA-IOS-15»; «Bug: al convertir a gasto compartido un registro leído de imagen, no se marca como registrado». Al terminar, muévelas a «in qa» con una nota del PR.

## Qué se pide
1. **Traba de la proyección inteligente de Flujo de caja (Sentry YALA-IOS-15).** App Hang no total en la build 5 de 2.3: el culpable es una clausura dentro de `FlujoProyeccionInteligente.detectar` en el hilo principal. El PR «Flujo de caja sin trabas» (20-nov) y el de duplicados (27-nov) no la arreglaron. Reprodúcela con el almacén grande de 16 mil movimientos (el de `docs/qa/rendimiento-iphone14-2026-11-26/`) y mide con Time Profiler. Que `detectar` no bloquee: un solo recorrido, por tramos que cedan el hilo o fuera del hilo principal sobre valores copiados (no sobre `@Model`). Prueba de paridad: mismo resultado antes y después con datos grandes y con casos de borde.
2. **Convertir a gasto compartido un registro leído de imagen no lo marca como registrado.** En la lista de lo leído de una foto, al convertir uno a gasto de grupo, la fila no queda como registrada (por voz sí funciona: `VoiceRecordingView` usa el mismo `DraftRegisteredInGroup`; compáralo con `ImageSelectionView` y `DraftGroupConversionFlow`). Primero reprodúcelo y confirma la causa, después corrígelo con su prueba (unitaria y de interfaz). `GroupExpenseFormView` / `GroupExpenseViewModel` solo si la causa está ahí.
3. **Las dos animaciones sin fin que quedaron fuera del lote 2 de eficiencia** (las dos están en las mismas hojas de captura, por eso van aquí y no en «Eficiencia 7»): la foto leyéndose en `ImageSelectionView.swift` y la escucha del registro por voz en `VoiceLiveListeningViews.swift`. Que se detengan cuando la hoja no se ve o la app no está activa, respetando «Reducir movimiento», y quítalas de las excepciones de `RepeatForeverConVisibilidadTests`.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio de código con su prueba en la carpeta de pruebas de este encargo.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Puedes usar un segundo simulador en la Max; en la Mini, uno solo. Apaga lo que enciendas.
- **iPhone 14** («iPhone de JURGEN», conectado a la Max) por DeviceMCP: tiene candado (ADR-132 de casa, hook `candado_dispositivo.py`). Si al usarlo te dice que está ocupado por otra sesión, **no reintentes en bucle**: sigue con el simulador o con otra parte del trabajo y vuelve a probar una sola vez más tarde; si sigue ocupado, anótalo en «Saltado o asumido sin preguntar». Antes, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que no esté bloqueado. No borres datos del iPhone.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Sin cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Nada fuera de `toca:`. Este lote corre en paralelo con otros que tienen archivos vecinos: si necesitas otro archivo, no lo toques; anótalo en «Saltado o asumido sin preguntar» con el motivo.

## Cierre
- Capturas antes/después (claro y oscuro) del registro convertido en la lista, y la medición antes/después de la proyección, en un **artifact visual de Claude** enlazado en el cierre (ADR-130 de casa).
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: ninguna es de producto)

1. **Proyección: arreglar la causa medida, no mover el cálculo de hilo.** Sentry (YALA-IOS-15, build 5) cae en el `sorted`
   de los grupos dentro de `detectar` (línea 249): cada comparación convertía dos `PersistentIdentifier` en texto por
   reflexión. Time Profiler en el simulador con 16 mil movimientos lo confirma (22 % de la detección vieja). Se calcula el
   orden una vez por grupo, el comercio una vez por nota, los candidatos se ordenan sin copiar movimientos y no se suma
   un comercio que no llega a los meses requeridos. Mismo resultado: paridad contra una copia congelada del algoritmo
   viejo. Sacarlo del hilo principal exige tocar `FlujoMotorMes` y sus llamadores, fuera de `toca:`.
2. **Convertir a compartido desde la foto: no se reproduce.** Con uno y con dos leídos, en la base, la fila convertida
   sale «Guardado» con su grupo. La card estaba en el tablero el 20-nov a las 13:53 y el arreglo («lo convertido a gasto
   compartido queda marcado como guardado») entró ese día a las 19:53. Sin cambio de código; queda una prueba de
   interfaz nueva para el caso de dos leídos, que no estaba cubierto.
3. **Animaciones**: el molde de `GroupCaptureReadingPhoto` y del dictado de Yala IA (`animaSoloVisible`), y se quitan de
   las excepciones del barrido.
4. **`FlujoMotorMes` no se toca** aunque tiene el mismo patrón de orden (línea 489): fuera de `toca:`; va a «Saltado» con
   ticket.
