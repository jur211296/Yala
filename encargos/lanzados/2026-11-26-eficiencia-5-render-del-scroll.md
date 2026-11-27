Yala
# Eficiencia 5: scroll más liviano (cristal, sombras y recortes del Panel y de Registros)
---
toca: Yala/App/Views/Panel,Yala/App/Theme/ViewModifiers.swift,Yala/App/Views/Records/Components,Yala/App/Views/Shared/FABStackView.swift,YalaTests/EficienciaRenderScroll,docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-5-render-del-scroll/,tickets/backlog/2026-11-26-eficiencia-5-render-del-scroll.md,tickets/done/2026-11-26-eficiencia-5-render-del-scroll.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: no
depende: Yala/eficiencia-4-recalculo-del-panel-sin-bloquear, Yala/eficiencia-2-animaciones-solo-visibles
---

Lote del plan de eficiencia que salió del análisis de calentamiento, batería y scroll en el iPhone 14. Espera a los lotes 4 y 2 porque toca la carpeta del Panel y `FABStackView.swift`.

## Qué se pide
1. Medir por tarjeta del Panel cuántas pasadas fuera de pantalla añade (Hitches › renders) y quitar las sombras sin `shadowPath` equivalente.
2. Agrupar el cristal de cada barra en un `GlassEffectContainer` y evitar cristal dentro de filas que se desplazan.
3. Filas de Registros: la sombra propia de `ListRowCardModifier` (en `Theme/ViewModifiers.swift`) en cada fila es una pasada por fila.
4. `compositingGroup` / `drawingGroup` donde el contenido es estático.
5. Objetivo: mediana < 20 pasadas fuera de pantalla por fotograma.
- Lo que se ve tiene que quedar igual o casi: capturas antes/después en claro y oscuro, iPhone 14, de cada pantalla tocada.
- Pruebas nuevas en `YalaTests/EficienciaRenderScroll/`.

## Mejora esperada y cómo se mide
Menos de 0,5 tirones por segundo de scroll (hoy 2,8). Medir con la pasada D del informe (3 rondas por pantalla) con Hitches: mediana y máximo de pasadas fuera de pantalla.

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

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar)

1. **Base y dependencias.** El lote 2 ya está en `origin/2.3`; el lote 4 sigue en cola de auto-merge y solo toca
   `PanelViewModel` y lógica, ningún fichero de este lote. Se trabaja sobre `origin/2.3` sin esperarlo y se rebasa antes
   del PR.
2. **El «antes» se mide hoy, no se toma del informe.** En la traza D del informe el hilo principal estaba al 100 % y el
   Panel casi no pintaba (mediana de 1 pasada): con los lotes 1-3 ya mezclados, la cifra comparable sale de una copia de
   perfilado de `origin/2.3` de hoy. Mismo método: Release-Dev con `DEBUG`, almacén de 16 k, pasada D con Hitches.
3. **Atribución con interruptores temporales.** Para el punto 1 del encargo (medir por pieza) cada cambio lleva un
   interruptor por argumento de lanzamiento en la copia de perfilado, como los del informe; se retiran antes del PR.
4. **Solo se queda lo que mide.** Si un cambio no mueve las pasadas en el iPhone, se revierte: menos riesgo visual y un
   diff que se puede revisar. Lo descartado y su cifra van en el informe del lote.
5. **El aspecto no cambia.** Las sombras se mueven al relleno de la forma con los mismos valores; el cristal de los
   botones flotantes no se quita, se agrupa. Nada se cambia de color ni de tamaño.
6. **Objetivo de tirones.** El objetivo de < 0,5 tirones/s se compara separando los tirones «de render» (los de este
   lote) de los de «actualización de la app» (hilo principal, de otros lotes).
