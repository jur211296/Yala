Yala
# Eficiencia 2: sin animaciones infinitas fuera de la vista (pulso de la tendencia y demás)
---
toca: Yala/App/Views/Panel/TrendChartView.swift,Yala/App/Views/Shared/SkeletonView.swift,Yala/App/Views/Shared/FABStackView.swift,Yala/App/Views/Shared/YalaSpark.swift,Yala/App/Views/Groups/Captura/GroupCaptureChrome.swift,Yala/App/Views/Chat/VoiceListeningPanel.swift,Yala/App/Logic/AnimacionesVisibles,YalaTests/EficienciaAnimacionesVisibles,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-2-animaciones-solo-visibles/,tickets/backlog/2026-11-26-eficiencia-2-animaciones-solo-visibles.md,tickets/done/2026-11-26-eficiencia-2-animaciones-solo-visibles.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/analisis-rendimiento-calentamiento-scroll-iphone14
---

Lote del plan de eficiencia que salió del análisis de calentamiento, batería y scroll en el iPhone 14. Sus archivos no se cruzan con el lote 1, así que puede correr en paralelo en la otra máquina. Solo espera a que cierre el análisis, para tener su informe en 2.3.

## Qué se pide
1. Pulso de la gráfica de tendencia: que dé un par de latidos y se detenga, o que solo anime con la gráfica visible (`TrendChartView.swift`, `onAppear` → `pulseAnimate` y el `.animation(... .repeatForever ...)` dentro del `.chartOverlay`); mantener «Reducir movimiento».
2. Detener toda animación `repeatForever` cuando su pestaña no se ve (`\.isRootPageShown`, que ya existe) o la app no está activa. Si hace falta un modificador compartido, va en `Yala/App/Logic/AnimacionesVisibles/`.
3. Barrido de las otras animaciones infinitas (`SkeletonView` sweep, `FABStackView`, `YalaSpark`, `GroupCaptureChrome`, `VoiceListeningPanel`): confirmar que se paran al ocultarse y arreglar las que no.
4. Sacar el resumen para VoiceOver (`spokenSummary`) y el mapeo de puntos del `body` que se repinta (precalcularlos).
5. Pin: test que prohíba `repeatForever` sin una condición de visibilidad.
- Lo que la persona ve tiene que seguir igual cuando la gráfica está a la vista (el pulso puede latir un par de veces y quedarse quieto).
- Pruebas nuevas en `YalaTests/EficienciaAnimacionesVisibles/`.

## Mejora esperada y cómo se mide
Reposo de 35-38 % a ~0,3 % de un núcleo. Medir con la pasada E del informe (30 s quieta en Panel, Registros y Más) → < 2 %, y Power Profiler en reposo contra el de antes.

## Qué NO hay que tocar
- Nada fuera de `toca:`; si necesitas otro archivo, anótalo en «Saltado o asumido sin preguntar» con el motivo.
- Lo de los otros lotes del plan (cada uno va en su sesión).

## Contexto común
- Informe de origen: `docs/qa/rendimiento-iphone14-2026-11-26/README.md` (sección «Lotes propuestos» y «Causas raíz, ordenadas por impacto medido»), con datos en `docs/qa/rendimiento-iphone14-2026-11-26/datos/` y los guiones de medición en `docs/qa/rendimiento-iphone14-2026-11-26/scripts/` (por ejemplo `scripts/pasada.sh`). Lo hizo la sesión «Análisis profundo de calentamiento, batería y scroll en iPhone 14» el 26-nov midiendo en el iPhone 14 de Jürgen con un almacén de 16.004 movimientos. Si al arrancar el informe todavía no está en `origin/2.3`, búscalo en la rama `encargo/2026-11-26-analisis-rendimiento-calentamiento-scroll-iphone14`.
- Pedido de Jürgen (26-nov, 10:44 Lima): «encola los 6 lotes de mejoras de eficiencia de la sesión del calor». Él siente que Yala calienta el teléfono al ir y volver de otra app y que el scroll al volver va lento.
- Las líneas citadas en el informe son de `origin/2.3` en `b5c6e98c5`; confírmalas en el código de hoy, porque otros lotes ya pueden haber cambiado esos archivos.

## Cómo medir
- **Antes y después en el iPhone 14 real** («iPhone de JURGEN», conectado por cable a la Max) con DeviceMCP, `devicectl` y `xcrun xctrace`, usando los mismos guiones y el mismo almacén de 16 k que el informe, para que las cifras sean comparables. Las cifras de rendimiento solo valen si salen del iPhone 14; el simulador sirve para desarrollar y para las pruebas, no como evidencia de rendimiento. En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los que enciendas.
- Al arrancar, comprueba con `xcrun devicectl device info lockState --device 00008110-001A35A6267A401E` que el iPhone no está bloqueado. Si está bloqueado o no responde: en semiautónomo, pídele a Jürgen que lo desbloquee (y que ponga Bloqueo automático en «Nunca» mientras dure la prueba) y espera con la sesión viva; en nocturno, termina lo que no necesite el teléfono, deja checkpoint y anota la medición pendiente como `BLOQUEANTE:` con el error exacto. Si el iPhone lo está usando otra sesión, espera en tramos cortos con aviso.
- Deja las mediciones de este lote en `docs/qa/rendimiento-iphone14-2026-11-26/despues-<slug-del-lote>/` (resumen numérico antes/después y extractos de trazas, nada pesado) y compáralas contra la «mejora esperada» del informe.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Cada cambio con su prueba en la carpeta de pruebas de este lote. Textos nuevos, si hiciera falta alguno, solo en una tabla de strings propia del lote en cada `.lproj`, nunca en `Localizable.strings`.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo; para medir, compilación de perfilado (Release con símbolos) instalada como Yala Dev en el iPhone 14. Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Antes de compilar en iOS mira la carga: si otra sesión compila en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Nada de cambios de esquema de SwiftData, CloudKit ni Supabase; si crees que hace falta uno, es pregunta vital para Jürgen. No cambies lo que la persona ve, salvo lo que diga el lote.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- No borres datos del iPhone ni la base de desarrollo.

## Cierre
- Un solo PR a `2.3`, sin firma de IA, con auto-merge activado; cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Entrega: artifact visual de Claude con antes/después medido en el iPhone 14 (cifras y gráficas), qué se cambió y qué quedó pendiente; enlázalo en el cierre. No Markdown, PDF ni documento de puro texto.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen. Español neutro latinoamericano.

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: ninguna es de producto)

1. **Pulso de la tendencia: dos latidos y quieto, y además solo con la gráfica a la vista.** `repeatCount(2)` en vez de
   `repeatForever`; vuelve a dar dos latidos cada vez que la página reaparece o la app vuelve a estar activa. El halo
   termina en su estado final (invisible), así que en reposo se ve el anillo y el centro, como entre latido y latido.
2. **Un solo modificador común** `animaSoloVisible(_:si:)` en `Yala/App/Logic/AnimacionesVisibles/`: enciende un
   `Bool` con la vista montada, `\.isRootPageShown` y `scenePhase == .active`; apagar va sin animación. Cada vista
   anima con `.animation(activa ? <sin fin> : nil, value: activa)`. Se descarta medir visibilidad con
   `onScrollVisibilityChange` (la regla de vistas ya documenta que miente en la primera pasada).
3. **Barrido de las cinco del encargo**: esqueleto, menú del botón flotante, chispa de Pro, foto leyéndose de Grupos y
   orbe de voz pasan todas por el modificador (las que viven en hojas también: así se paran con la app en segundo plano).
4. **Resumen de VoiceOver**: se precalcula en un `@State` con su clave (puntos, saldo vivo, agrupación, formato) y se
   recalcula solo cuando cambia; el `body` ya no recorre los puntos para decirlos.
5. **Pin**: test que lee `Yala/App` y exige que todo fichero con `repeatForever` use `animaSoloVisible`; las cuatro que
   quedan fuera del `toca:` (splash, demo del Welcome, foto leyéndose de la entrada por imagen y escucha de voz) van en
   una lista de excepciones con su motivo y quedan anotadas en el cierre. No se tocan: el encargo no las incluye.
6. **«Antes»**: la pasada E y el Power Profiler J1 del informe, medidos hoy en el mismo iPhone y el mismo almacén sobre
   `b5c6e98c5`, que no tiene ningún cambio en `Yala/App` respecto de la base de este lote. No se repite.
7. **«Después»**: copia de perfilado igual que la del informe (Release-Dev con `DEBUG`), la misma pasada E y una J
   de Power Profiler en reposo.
