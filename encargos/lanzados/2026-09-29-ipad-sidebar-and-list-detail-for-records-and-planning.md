# iPad · fase 1: barra lateral y lista-detalle en Registros y Planificación (carril adaptativo, paso 5/13)

---
ticket: ipad-sidebar-and-list-detail-for-records-and-planning
modo: autonomo
cola: adaptativo
---

## Contexto
Carril adaptativo Yala, turno alternado tras el cierre limpio de Cola A PR #298 (mergeado a 2.1). Plan vigente: `docs/exploracion/adaptativo-ipad-duo.md` §7 fila 5 (fase 1). Ticket: `tickets/backlog/ipad-sidebar-and-list-detail-for-records-and-planning.md`. Pasos 1–4 ya cerrados (multiventana, texto grande, pantallas pequeñas, hojas por ventana). El cimiento de hojas (#297) ya está.

Jürgen ordenó (2026-09-28 16:31): una sola sesión Yala a la vez, alternando Cola A y carril adaptativo. Esta es el carril adaptativo. §5.1 aprobada: `sidebarAdaptable` + lista-detalle por size class / ancho de ventana, no por aparato (ADR 27-sep). Frank y Claude deciden el detalle Apple-recommended sin preguntarle.

MODO AUTÓNOMO (madrugada Lima): elige las opciones recomendadas / robustas sin preguntar a Jürgen salvo device físico, secretos o irreversible. Mergea a `2.1` cuando el gate esté verde.

## Que se pide
Cierra el ticket `tickets/backlog/ipad-sidebar-and-list-detail-for-records-and-planning.md`.

1. Leer el ticket, el plan §5.1 / §6 / §7, y el ADR «Yala se adapta por espacio, no por dispositivo».
2. En iPad (y Duo abierto / ancho regular): barra lateral con las secciones (incluidas las de Más); en Registros y Planificación, lista y detalle a la vez; ancho legible. En iPhone compact la navegación de siempre no se rompe.
3. Implementación: `TabView` con `.tabViewStyle(.sidebarAdaptable)` y `TabSection`; **un único** `NavigationSplitView` de dos columnas que en compact se pliega solo (no `if` por size class con dos árboles). Lo abierto/seleccionado sobrevive al redimensionar. El detalle de registro deja de ser hoja en ancho regular (cuidado con el encadenado del editor en `DetailContainerView`).
4. Evidencia en simuladores del carril por UDID (iOS 27.0), DerivedData del worktree (`-derivedDataPath .ddp`):
   - `YalaLane-Adapt-iPad-mini` → `8BBAB498-9F59-40D6-9101-5CF4C0CCC7F3`
   - `YalaLane-Adapt-iPad-Pro-13` → `AE7C6D3F-6C1F-4F7E-8120-990D526A6C10`
   - `YalaLane-Adapt-iPhone-SE` → `8803FA85-BBAA-489A-8806-DA045587D151`
   - `YalaLane-Adapt-iPhone-ProMax` → `CDA87FB8-1261-431E-B85B-62786395C8F9`
   Capturas antes/después vertical y horizontal en los iPad; en SE y ProMax a tamaño por defecto y AX5 la navegación de siempre. Si puedes redimensionar el iPad (Device Hub / Apps en ventanas) con un registro abierto, demuéstralo; si no, deja el guion explícito en el ticket para Jürgen.
5. XCUITest de navegación en iPad-Pro-13 y iPhone-ProMax por UDID. Instruments en Registros con semilla `pesado` si cabe en el tiempo. Gate verde. PR a `2.1`, `/cerrar-total`.

## Que NO hay que tocar
- Simuladores sin prefijo `YalaLane-Adapt-`. Siempre `-destination id=<UDID>`, nunca por nombre genérico ni `booted`. Prohibido `simctl shutdown all`, `erase all`, `killall Simulator`.
- No instalar Xcode 27.1 ni crear/tocar fase Duo (`YalaLane-Adapt-iPhone-Duo`) salvo que ya exista.
- No arrancar Cola A / sync / nube ni Cola B (rediseño UI).
- No abrir otra sesión Yala en paralelo.
- No preguntar a Jürgen por decisiones de producto reversibles.

## Como se sabe que esta bien
- Criterios «Hecho cuando» del ticket cumplidos (o residuales explícitos en backlog / qa con guion).
- En iPhone compact no se rompe la navegación; en iPad hay barra lateral + lista-detalle en Registros/Planificación.
- Gate verde, PR mergeado a `2.1`, cierre limpio.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**Hechos medidos antes de decidir.** El orden de las pestañas lo elige el usuario y se puede reordenar
(`TabBarConfigView.swift:248`, `activeTabs.move`). Perfil ya se abre desde la barra de cada pantalla
(`ProfileToolbarItem` en Registros, Planificación, Estadísticas, Reportes, Grupos y Panel). El detalle de registro
es una hoja que al pulsar Editar se cierra y encadena el editor (`RecordsStandaloneView.swift:443-458`). El detalle de
presupuesto y el de pago programado se empujan con `navigationDestination` (`BudgetsListView.swift:82`,
`ScheduledPaymentsView.swift:86`).

**D1 · Qué va en la barra lateral** → las seis páginas (Panel, Estadísticas, Planificación, Registros, Reportes,
Grupos) y Buscar, **en lista plana, sin `TabSection`**. Más desaparece en ancho regular.
Por qué: una `TabSection` que solo existe en regular cambia el árbol en cada redimensionado y se lleva lo abierto
(punto 5 del ADR del 27-sep); una que existe siempre reordena la barra de pestañas del iPhone, que el usuario ordena a
mano. Las sub-secciones de Más (Resumen, Tendencias…) siguen en los chips de cada página. Alternativa descartada: una
entrada de barra lateral por sub-sección, que monta tres copias de Estadísticas y desincroniza la selección.

**D2 · Cómo cambia la raíz** → un solo `TabView(.sidebarAdaptable)` con **todas** las pestañas siempre montadas y
`.hidden(_:)` por pestaña. En compact se ven las mismas de hoy (configuración + temporal + Más + Buscar), en el orden
del usuario; en regular, todas menos Más. El orden es el del usuario y luego el resto: el mismo en los dos tamaños, así
que redimensionar no reordena. En la shell de solo grupos, regular se comporta como hoy.
Por qué: identidad estable de cada pestaña al redimensionar. Alternativa descartada: `ForEach` con listas distintas
por tamaño, que desmonta pestañas.

**D3 · Registros** → `NavigationSplitView` de dos columnas dentro de `RecordsStandaloneView`. En regular, tocar un
registro lo abre en la columna de detalle; en compact, la hoja de siempre. Lo abierto vive en `RecordsViewModel`
(fuera del contenedor). Si la ventana pasa a compact con un registro abierto, el split se pliega y lo enseña empujado
(`preferredCompactColumn`). En la columna, Editar abre el editor directo (sin encadenado) y el registro sigue abierto
al volver; si se borra, la columna vuelve al vacío.
Por qué: el iPhone no cambia de hoja a empuje (§6.1: solo cómo se coloca). Alternativa descartada: empujar también en
iPhone.

**D4 · Planificación** → `NavigationSplitView` de dos columnas en `PlanningView`, con la lista (chips, guía, lista) en
la primera. Se mide primero si los `navigationDestination` de la columna de lista ya presentan en la de detalle; si sí,
presupuestos y pagos programados lo heredan sin tocar sus filas; si no, selección explícita como en Registros.
Por qué: es lo que el sistema da gratis y deja el iPhone con el mismo empuje.

**D5 · Columna vacía** → `ContentUnavailableView` con copy nuevo en los 7 idiomas. Columna de lista con ancho
320–480 pt, sin botón propio de plegar (el de la barra lateral de la app basta), estilo `.balanced`.

**D6 · Ancho legible** → en esta fase, solo en las dos columnas de detalle nuevas (tope ~700 pt). El resto de
pantallas va a su fase (Panel y Estadísticas en 2b, Grupos y Ajustes en 2) o a un ticket si no tiene ninguna.
Por qué: tocar todas las pantallas multiplica el riesgo en iPhone y no lo pide la lista-detalle.

**D7 · Fuera de alcance** → el sub-chip Registros de Estadísticas (`DetailContainerView.swift:768`) sigue en hoja;
resaltar la fila abierta en la lista, tampoco. Ticket para cada uno si no existe.

**D8 · Pruebas** → XCUITest nuevo de navegación que en iPad comprueba barra lateral y lista+detalle a la vez, y en
iPhone la barra de pestañas y la hoja; se corre por UDID en Pro-13 y ProMax. Capturas en
`qa/evidencia-adaptativo-20260929/<ticket>/` con un XCUITest temporal que se borra antes del commit. Redimensionado con
«Apps en ventanas» y arrastre desde XCUITest (memoria del 29-sep). Instruments si queda tiempo.

**D9 · Estado final del ticket** → `done` si el redimensionado con registro abierto se ve en el simulador; si no,
`qa` con guion.

**D2 · corregida tras medir (2026-09-29, gate).** El `.hidden(_:)` por pestaña tumba la app cuando la pestaña
oculta es la seleccionada (UIKit aborta en `_UITabModel _setSelectedItem`), y eso pasa en la entrada por invitación
(shell de solo grupos con la selección en Panel). Ahora las pestañas que no tocan se QUITAN, como antes de esta fase,
y la página seleccionada sigue montada al estrechar para no perder lo abierto.
