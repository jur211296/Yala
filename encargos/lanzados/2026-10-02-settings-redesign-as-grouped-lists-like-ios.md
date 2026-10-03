# Rediseñar Ajustes como listas agrupadas al estilo de iOS, empezando por Personalización

## Contexto
Cola B (rediseño de UI/UX). Primer ticket natural de esa cola, el primero de la tabla «Encaje con Cola B» en `docs/exploracion/ipad-nativo.md` §7, y el de ajustes del pack del 15-sep. Ticket: `tickets/backlog/settings-redesign-as-grouped-lists-like-ios.md`.
No es Cola A (riesgo de nube), no es Cola C (post-2.1) y no es el carril adaptativo.
Base: `origin/2.1` fresco. Quién recibe arranca en contexto limpio.
Día (Lima): si hace falta una decisión de producto que el ticket no haya cerrado, pregunta; si no, decide en autónomo.

## Qué se pide
1. Lee el ticket entero y las dos referencias en `docs/design/referencias/`: `2026-09-15-ajustes-yala-personalizacion.png` y `2026-09-15-ajustes-ios-texto-flotante.png`. Mide el código actual; no te quedes con los números de línea del 15-sep.
2. El patrón de Ajustes pasa a listas agrupadas del sistema (`List` agrupada), no a tarjetas propias por fila: un bloque blanco por sección, separador fino, cabecera gris y chica, ayuda solo cuando dice algo que la fila no dice, interruptor maestro solo arriba. El valor a la derecha en gris con chevron se queda. Fondo no blanco y bloques blancos se quedan: eso es identidad (`feedback_tarjetas_blancas_identidad`). La comparación del 15-sep ya decidió la forma (un bloque por sección, no una tarjeta por fila). No pares a repreguntar esa forma.
3. El componente vive en el design system. Se aplica primero a Personalización (`PersonalizationSettingsView`). Después, en esta misma sesión, migra las demás pantallas de `Yala/App/Views/Settings/` que usan el mismo patrón de fila y sección, cada una en su propio commit. No cambies el comportamiento: solo la presentación.
4. Ancho: cuando la ventana es ancha, la lista tiene tope legible (~700 pt) centrado y usa el margen adaptativo que ya exista. Nada decide por tipo de aparato ni por orientación. No implementes la barra lateral ni el lista-detalle de iPad: eso es otro ticket.
5. Tests del contenedor y de Personalización (lo que se puede afirmar sin un segundo simulador). Pipeline de un solo simulador, abajo.
6. Mueve el ticket a `qa` o a `done` según si queda algo que Jürgen tenga que ver en un iPhone. PR a `2.1` en cola de auto-merge.

## Pipeline Mini (obligatorio, serial, 1 sim)
1. Limpiar simuladores muertos y basura previa.
2. `xcodebuild -jobs 2` sin ningún simulador encendido.
3. Arrancar 1 solo simulador.
4. Tests.
5. Apagarlo y borrar los datos del device.
Prohibido solapar swift-frontend + SpringBoard + app + UITests. Una sesión Yala, un simulador.

## Qué NO hay que tocar
- El chat de Yala IA, el onboarding, los flujos por pasos, Más, el Panel, las cuentas y los widgets: son otros tickets de Cola B.
- El carril adaptativo (texto grande, iPhone SE, columna estrecha, fases de iPad, widgets grandes).
- Cola A: nube, sesiones, migración, grupos, CloudKit, schema.
- `marketing/`, clínicas, CI de GitHub salvo que un test de este ticket lo exija (no lo exige).
- La identidad de tarjetas blancas sobre fondo no blanco: no las quites ni las dejes desnudas sobre blanco.
- Los 7 encargos sin commitear del árbol principal (están en `encargos/lanzados/`). No son tuyos: no los commitees ni los reviertas.

## Cierre
Al terminar (PR listo o bloqueo real): `/cerrar-total` autónomo, sin esperar. Mini limpia: apagar el simulador de la sesión, borrar los datos del device y, si el PR ya mergeó, quitar el worktree y el `.ddp`. No dejes la sesión colgada ni simuladores apagados acumulados. Esta sesión no crea secretos de llavero.

## Cómo se sabe que está bien
- Personalización muestra cerca del doble de ajustes por pantalla que hoy, sin perder ninguno.
- Cada texto de ayuda que quede dice algo que la fila no dice.
- El patrón es una `List` agrupada del sistema (sirve luego como columna), con bloques blancos sobre fondo no blanco.
- Las demás pantallas de Ajustes migradas no cambian de comportamiento.
- Tests verdes en local con el pipeline de un simulador. PR a `2.1` en cola de auto-merge. Ticket fuera de backlog.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

Medido antes de decidir (2026-10-02, árbol `74637a1fe`):

- El ticket dice que «las otras 32 vistas siguen el mismo patrón». **Falso:** el patrón de tarjeta por
  fila + `YalaSectionHeader` + ayuda bajo cada fila solo existe entero en Personalización (21 `.thCard`,
  5 cabeceras). Otras 8 pantallas usan `SectionBox` (ya un bloque por sección, título en `headline`);
  el resto son listas de entidades o pantallas a medida.

1. **Componente.** `Yala/App/DesignSystem/SettingsList.swift`: `YalaSettingsList` (una `List`
   `.insetGrouped` con fondo oculto), `YalaSettingsSection` (bloque con cabecera opcional y footer),
   `YalaSettingsValueRow`, `YalaSettingsToggleRow` y `YalaSettingsRowLabel` (para `Menu`). Fondo de
   bloque `theme.card`, fondo de pantalla el de siempre. Sin borde ni sombra, como iOS.
2. **Ancho.** `DS.Adaptive.readableListMargin(containerWidth:sizeClass:)`: el margen adaptativo de
   siempre (`horizontalPadding`) o lo que sobre para no pasar de 700, lo mayor. Por ancho medido, no
   por aparato. Va con test.
3. **Hero de Personalización (icono + título + descripción): se queda**, como primera fila sin fondo.
   Lo comparten Tema, Icono, Divisa y Tutoriales; quitarlo es otra decisión. La densidad se mide en
   una pantalla ya desplazada, que es la que enseña la captura del 15-sep.
4. **Ayudas de Personalización.** Se quedan las que dicen algo que la fila no dice: Solo gastos (qué
   se oculta y que no se borra), reiniciar al cambiar idioma, Pregúntale a Yala (que es el botón de
   chat), iconos desactivados por el tema (solo en ese caso), período predeterminado (se aplica al
   abrir), Textos de ayuda y Comparativas (el título no dice qué hacen), decimales (solo totales) y
   campo con enfoque (al crear un registro). Se van: resumen de IA, iconos coloridos en su caso
   normal, primer día de la semana, línea promedio y formato de moneda — repiten la fila o su valor.
   Sin copy nuevo: no hay strings que traducir.
5. **Una fila con ayuda va al final de su bloque, o sola en un bloque sin cabecera** (molde iOS de
   «Escritura flotante»). Puede cambiar el orden DENTRO de una sección; ninguna fila cambia de sección.
6. **Las otras pantallas.** Se migran las de forma «secciones de filas de ajuste» (las que salgan del
   inventario), una por commit, sin cambiar comportamiento ni copy. Las listas de entidades y las
   pantallas a medida no se tocan. Lo que no quepa en la sesión queda anotado en el ticket.
7. **Tests.** Unit del margen legible. XCUITest de Personalización: es una lista del sistema y todas
   sus filas siguen alcanzables. Los XCUITest existentes de Personalización siguen sin tocar ids.
8. **Ticket a `qa`**: el aspecto en un iPhone real (tema oscuro y traslúcido, sin borde de bloque) lo
   tiene que ver Jürgen.
