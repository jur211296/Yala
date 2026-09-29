# Cimiento adaptativo (paso 4/13): las hojas se dimensionan por el espacio de la ventana, no por el aparato

## Contexto
Carril adaptativo Yala, tras cerrar Cola A PR #296. Plan vigente: `docs/exploracion/adaptativo-ipad-duo.md` §7 fila 4. Ticket: `tickets/backlog/sheet-size-follows-the-device-not-the-window.md`. Pasos 1–3 ya cerrados (multiventana apagada, texto grande, pantallas pequeñas). Este cimiento es previo obligatorio a la fase 1 (`ipad-sidebar-and-list-detail-for-records-and-planning`).

Hoy `DS.Adaptive.usesLargeSheets` decide con `UIDevice.current.userInterfaceIdiom == .pad` (y Mac). Eso falla en iPhone Duo abierto (iPhone con ancho regular) y en iPad en ventana estrecha / Split View. Es la única decisión de layout por tipo de dispositivo en `Yala/`.

MODO AUTÓNOMO (noche Lima): elige tú las opciones recomendadas / robustas sin preguntar a Jürgen salvo device físico, secretos o irreversible. Mergea a `2.1` cuando el gate esté verde.

## Que se pide
1. Leer el ticket y el plan §3 / §6.2 / §7.
2. Que el tamaño de hoja dependa del size class (o ancho) de la ventana que la presenta, no de `userInterfaceIdiom`. Mantener el comportamiento Mac (`isiOSAppOnMac`).
3. Cubrir las ~62 llamadas en ~37 ficheros (directas o vía `DS.Adaptive.sheetDetents`).
4. Evidencia en simuladores del carril por UDID:
   - `YalaLane-Adapt-iPhone-ProMax`: tres hojas con detent medio (antes/después). Sin diferencias en iPhone.
   - `YalaLane-Adapt-iPad-Pro-13` a pantalla completa: mismas tres hojas, grandes como hoy.
   - Si puedes redimensionar el iPad a ventana estrecha con Device Hub, capturar detents de iPhone; si no, deja el guion explícito en el ticket para Jürgen.
5. Test unitario de la función que decide, con los dos size classes. Gate verde. PR a `2.1`, `/cerrar-total`.

## Que NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- No instalar Xcode 27.1 ni tocar fase Duo.
- No arrancar fase 1 ni tickets de Cola B.
- No tocar Cola A / sync / nube salvo lo inevitable del cambio de hojas.
- No preguntar a Jürgen por decisiones de producto reversibles.

## Como se sabe que esta bien
- Criterios «Hecho cuando» del ticket cumplidos (o residuales explícitos en backlog).
- Gate verde, PR mergeado a `2.1`, cierre limpio.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿De dónde sale el size class?** → Del de la **ventana**, leído en la raíz (`YalaApp.rootView`) y bajado como
valor de entorno `\.usesLargeSheets`. Por qué: `presentationDetents` se aplica DENTRO del contenido de la hoja, y ahí
el `horizontalSizeClass` lo fija la presentación y no tiene por qué ser el de la ventana; los valores propios del
entorno sí viajan intactos a las hojas (medido: el iPad a pantalla completa sigue con hojas grandes). Alternativa descartada: leer `horizontalSizeClass` en cada hoja (depende de cómo la
presente el sistema) o un `static` sobre la escena activa (no reacciona al redimensionar).

**D2 · ¿Size class o ancho en puntos?** → Size class horizontal `.regular`. Por qué: es lo que pide el ADR del
27-sep y el HIG; el ancho exacto no añade nada para esta decisión binaria. Descartado: un umbral de puntos propio.

**D3 · ¿Qué API?** → Se retira el `static var usesLargeSheets` y queda una función pura
`DS.Adaptive.usesLargeSheets(windowHorizontalSizeClass:isiOSAppOnMac:)` (la que se testea) y
`sheetDetents(_:usesLargeSheets:)`. Por qué: al retirar el `static`, el compilador encuentra las 62 llamadas; ninguna
se queda decidiendo por aparato. Descartado: dejar el `static` como atajo.

**D4 · Valor por defecto sin raíz** (previews, vistas fuera de la jerarquía) → el de un size class desconocido: grande
solo en Mac. Por qué: es el comportamiento de iPhone, el mayoritario, y Mac sigue igual.

**D5 · Mac** → `isiOSAppOnMac` sigue forzando hojas grandes, sea cual sea el size class.

**D6 · Fuera de alcance** → el `selection: .medium` de `DatePickerSheet` y `TransactionAssociationSheet` con un
conjunto `[.large]` en iPad es preexistente; no se toca. Sin ADR nuevo: manda el ADR «Yala se adapta por espacio, no
por dispositivo» (27-sep); la convención va a `.claude/rules/swiftui-ds.md`.
