---
id: 2026-11-27-trabas-flujo-proyeccion-y-convertir-a-compartido
status: done
priority: high
area: "cash-flow-plan, inbox-convert-to-group, image-capture-ocr-vision, voice-recording-capture"
created: 2026-11-27
updated: 2026-11-27
source: "encargo del 27-nov (Jürgen aprobó los tres lotes a las 06:18); cards «Flujo de caja: la app se traba unos segundos calculando la proyección inteligente · YALA-IOS-15» y «Bug: al convertir a gasto compartido un registro leído de imagen, no se marca como registrado»"
---

# Trabas: proyección inteligente del flujo de caja, convertir a compartido desde la foto y dos animaciones sin fin

## 1. La proyección inteligente ya no traba el flujo de caja (YALA-IOS-15)

**Qué pasaba.** Sentry (build 5 de 2.3, 20-nov, iPhone de Jürgen, pantalla de Registros) registró la app colgada entre 2
y varios segundos. La pila cae en `FlujoProyeccionInteligente.detectar`, dentro del `sorted` que ordena los grupos: el
orden de cada grupo se sacaba de `String(describing:)` de su `PersistentIdentifier`, que va por reflexión, **en cada
comparación**. Además, cada lectura del comercio de un movimiento pasaba la nota por dos expresiones regulares, varias
veces por movimiento.

**Medido con Time Profiler** (simulador, 16 mil movimientos en dos años, 84 grupos, 6 s de cada algoritmo en bucle):
en la detección de antes, convertir identificadores a texto era el 22 % del tiempo. Vueltas de la detección de los dos
lados en 6 s: **58 antes, 113 después** (detectar: 102 → 53 ms por cálculo en el simulador).

**Qué cambió** (`FlujoProyeccionInteligente.swift`, el resultado es el mismo):

- el orden de cada grupo se calcula una vez por grupo, no en cada comparación;
- el comercio se calcula una vez por nota distinta (`ComerciosPorNota`);
- los candidatos a aislado se ordenan comparando importes de un arreglo aparte (antes se copiaba el movimiento entero en
  cada comparación);
- un comercio que no aparece en tantos meses como pide un fijo se descarta antes de sumar;
- un solo recorrido separa los movimientos de la ventana y los del mes en curso.

No se movió el cálculo fuera del hilo principal: el motor del mes (`FlujoMotorMes`) y sus llamadores lo piden síncrono y
están fuera del alcance del encargo.

**Pruebas** (`YalaTests/TrabasFlujoYConvertir/`): paridad contra una copia congelada del algoritmo anterior
(`ProyeccionInteligenteAntes.swift`) con 16 mil movimientos —fijos por grupo y por comercio, fijos a futuro, aislados con
su devolución, sueldo que bajó y sueldo que dejó de llegar—, cinco semillas más y los bordes (sin historia, sin primer
mes, solo el mes en curso, dos y tres meses, sin notas, una sola nota, todo sin categoría). Compara fijos, fijos a futuro,
aislados, lo variable, el mes típico y lo que contestan `fijoQueReconoce`, `fijoAFuturo`, `fijo(de:)`,
`esAisladoEnMesProyectado` y `adelantado` sobre cada movimiento. Testigos deterministas: el orden se calcula como mucho
dos veces por grupo y el comercio una vez por nota (`_testOrdenes`, `_testComerciosCalculados`).

## 2. Convertir a compartido un registro leído de una foto: no se reproduce

Con el código de `origin/2.3`, en el simulador, con un leído y con dos, la fila convertida sale «Guardado» con el grupo
debajo («Viaje a Cusco») y, con dos, el otro sigue pendiente y la hoja no se cierra. La card ya estaba en el tablero el
20-nov a las 13:53 y el arreglo («lo convertido a gasto compartido queda marcado como guardado»,
`tickets/done/2026-11-20-captura-convertir-a-grupo-marca-registrado.md`) entró ese día a las 19:53, después de la build 5.
Sin cambio de código. Queda la prueba de interfaz del caso de dos leídos, que no estaba cubierto:
`YalaUITests/TrabasFlujoYConvertir/ConvertirFotoAGrupoUITests`.

## 3. Las dos animaciones sin fin de las hojas de captura

La línea que recorre la foto mientras se lee (`ImageSelectionView`, `ImageReadingPhoto`) y el punto rojo de «Escuchando»
(`VoiceLiveListeningViews`, `VoiceRecordingTimeLabel`) ya solo se animan con la hoja a la vista y la app activa
(`animaSoloVisible`, el molde del lote 2 de eficiencia), y con «Reducir movimiento» no se mueven. Salen de las
excepciones de `RepeatForeverConVisibilidadTests`, que ahora las vigila como al resto.

## Sigue

- **El mismo patrón en `FlujoMotorMes.orden`** (fuera del alcance de este encargo): el orden de las partidas de «otros»
  compara `(total, orden(base))` y `orden` vuelve a hacer `String(describing:)` en cada comparación. Con la detección ya
  arreglada es el **34 %** del motor del mes en la misma traza (13 meses, 16 mil movimientos: ~230 ms por cálculo en el
  simulador). El arreglo es el mismo: calcular el orden una vez por partida. Card en el tablero.
- Device-QA en el iPhone 14: abrir el flujo de caja con el almacén grande y comprobar que no se traba; foto con dos
  registros, convertir uno a gasto de grupo.
