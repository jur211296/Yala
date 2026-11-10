# Tanda de QA de Jürgen — 2.2, barrido final del 2026-11-05

Último barrido antes de subir la 2.2 a la App Store. Dos partes:

1. **Recorrido de pantallas** de la lista de los barridos A (30-oct), B y C (3-nov) en iPhone, iPad y Duo, con tema
   claro, tema oscuro y el texto al máximo (AX5), sobre `origin/2.2` en `baf461772` (#809) más los arreglos de este PR.
2. **Filtro doble de `/barrido-qa`** sobre lo que entró en «in qa» desde el barrido C (#766 en adelante).

Los ids van sin el prefijo `tablero-`. Capturas en `~/Claude/worktrees/_capturas/barrido-qa-2-2-final/<aparato>/<variante>/`.

## Resumen

- **Recorrido:** 41 pantallas por corrida (Panel y «Tus finanzas», Registros y su detalle, Estadísticas en sus cuatro
  pestañas, Planificación, presupuesto, Pagos planificados y su detalle, Grupos, grupo, saldos y nuevo gasto, Nuevo
  registro, voz con uno y con varios registros, Yala IA, Bandeja, Categorías, Perfil y Ajustes, Cuentas y su edición,
  Más, Flujo de caja, oferta Pro, Bienvenida y onboarding).
  - iPhone 17 Pro: claro, oscuro y oscuro con AX5. iPhone 17e (el más pequeño): oscuro con AX5.
  - iPad Pro 13" (M5): claro, oscuro y oscuro con AX5.
  - iPhone Duo cerrado (pantalla exterior): claro, oscuro y oscuro con AX5.
  - iPhone Duo abierto (pantalla interior): claro, oscuro y oscuro con AX5, 15 pantallas por variante (ver «Duo abierto»).
  - Matriz decidida por Jürgen (opción A): el texto al máximo en un solo tema, porque el layout no cambia con el tema.
- **Arreglado en este PR: 3.**
  1. **El Panel del iPad se quedaba cargando al abrir Yala** (regresión de 2.2; la 2.1 publicada no lo tiene). Decisión
     de Jürgen: entra en este PR (opción A).
  2. **Onboarding con el tema Claro:** el texto de ejemplo de los campos («Tu nombre», nombre de la cuenta, saldo) salía
     casi invisible sobre el fondo oscuro fijo.
  3. **Ajustes › Cuentas con el texto al máximo:** el nombre de la cuenta desaparecía y la cifra se cortaba.
- **Cards de bug nuevas (2.2, alta, cierre autónomo): 2**, cada una con su ticket en `tickets/backlog/`.
- **Lo cosmético con el texto al máximo** va al ticket que ya existía (`large-text-leftovers-outside-the-main-iphone-screens`,
  puntos 10 a 15).
- **Cards revisadas en «in qa»: 15 nuevas desde el barrido C.** Pasan a done 12; se quedan 3 (una pregunta de visto
  bueno y dos que cierran solas fuera del iPhone).
- **Para tu iPhone: 0 nuevas.** La tanda sigue siendo la del 30-oct: 8 cards en 4 montajes, unos 50 min (abajo).
- **Preguntas de visto bueno: 1 nueva** (el ícono de cristal) y las 5 que quedan del barrido B.

## Qué bloquea 2.2

Lo mismo que el 30-oct: `046l` (ver el grupo antes de crear cuenta al unirse), montaje A. El Panel del iPad, que habría
bloqueado, queda arreglado en este PR.

## Arreglos de este PR

| Qué | Antes | Después | Verificación |
|---|---|---|---|
| Panel del iPad al abrir Yala con datos | Esqueleto de carga más de 35 s; solo cargaba al salir de Yala y volver | Carga a los 6 s, como la 2.1 | Misma receta en el simulador del iPad: sin arreglo, con arreglo y con la 2.1 publicada. `PanelColdLaunchActivationTests` (6 casos) y su mutante (quitar la línea que recuerda la petición) en rojo |
| Onboarding, tema Claro | «Tu nombre» casi invisible | Gris claro, como la ayuda | Capturas antes y después en el iPhone 17 Pro; en oscuro, 0,1 % de píxeles distintos (antialias) |
| Ajustes › Cuentas, AX5 | Solo «USD 33,615.0(», sin nombre | Nombre, tipo, moneda y la cifra entera debajo | Capturas antes y después en el iPhone 17e; a tamaño normal, igual (solo cambia la hora de la barra) |

La causa del Panel: la carga se pedía al aparecer y al pasar a activa, y en el arranque del iPad las dos peticiones
llegaban antes de que UIKit marcara la app como activa; el freno del recálculo las descartaba y nadie volvía a pedirla.
Ahora el freno apunta lo descartado y lo repite al activarse la app. La regla queda en `.claude/rules/swiftui-ds.md`.

Evidencia: `~/Claude/entregas/2026-11-05-barrido-qa-2-2-final/evidencia/`.

## Bugs nuevos, a card

| Card | Qué pasa | Dónde |
|---|---|---|
| `con-el-texto-al-maximo-la-zona-fija-de-g-3nos` | La zona fija de «Guardar»/«Siguiente» pisa el formulario: los textos se leen uno encima del otro. En el Duo cerrado pasa en el onboarding **también con el texto normal** | Nuevo registro, Nuevo gasto de Grupos, onboarding |
| `con-el-texto-al-maximo-cifras-cortadas-o-vd5r` | Cifras que no se leen enteras con AX5: «S/54,5….64», «S/ / 25.0 / 0», «S/ 67,3…», «-S/ 60…» y botones «Ya lo… / Salta…» | Tendencias, voz, Resumen, Pagos planificados |

## Duo abierto

Postura «abierto» puesta en Device Hub con la pantalla de la Max libre (Jürgen dio a Terminal Grabación de pantalla y
Accesibilidad). Con el Duo abierto, XCTest captura la pantalla interior en negro, así que esas 15 pantallas por variante
se abrieron por argumento de arranque o enlace profundo y se capturaron con `simctl io --display` (sin toques): Panel,
«Tus finanzas», Registros, Estadísticas, Planificación, Presupuestos, Pagos planificados, Grupos, grupo, Nuevo
registro, Bandeja, Categorías, oferta Pro, Bienvenida y onboarding. Capturas en `duo-abierto-interior/`.

- **Claro y oscuro, texto normal: limpio.** Lista y detalle en dos columnas, barra vertical a la derecha, el Panel carga
  (binario con el arreglo de este PR) y el texto de ejemplo del onboarding se lee en claro.
- **Oscuro con AX5:** la página pasa a una columna (por diseño) y salen los mismos fallos ya registrados: la zona de
  «Guardar» y el «Siguiente» del onboarding pisan el texto (`3nos`) y la pestaña «Pagos planificados» pasa por debajo
  de la barra vertical (ticket de restos de texto grande, punto 10).

## Las pruebas del iPhone

Sin cambios desde el 30-oct. Con el **TestFlight siguiente** al 2.2 (7), que ya traerá este PR:

- **A · Dos aparatos contra staging, unirse a un grupo (unos 20 min) — bloquea** (`046l`, `7xnd`, `ywm1`). Guion: montaje
  A, apartados 1 a 4, de `docs/qa/tanda-qa-jurgen-2.2-lote14-grupos-invitar.md`.
- **B · Tu iCloud real (unos 25 min)**: activar la nube sin quedarse esperando (`ppxk`), iCloud Drive apagado (`n5zw`) y
  cerrar sesión perdiendo cambios (`7e60`). Guion: `docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md`, montaje B.
- **C · Barra de abajo personalizada (unos 2 min)** (`fozu`). Mismo documento, montaje C.
- **D · Compra en sandbox (unos 5 min)** (`7c97`). Mismo documento, montaje D.

## Preguntas de visto bueno pendientes para Frank

| # | Cards | Qué se pregunta | Carpeta |
|---|---|---|---|
| 7 | `7ygb` | El ícono nuevo de cristal (Icon Composer) en sus modos claro, oscuro, tintado y transparente: ¿te vale? | `~/Claude/worktrees/_capturas/barrido-qa-2-2-final/preguntas/p7-icono-liquid-glass-7ygb/` |

Siguen las 5 del barrido B (`bvpn`/`jmgh` con `e7by`, `k2up`, `i00g`; `g1uw`; `n7cl`; `c0nl`; `3zva`), con sus
capturas en `~/Claude/worktrees/_capturas/barrido-qa-2-2-b/`. Las pantallas de hoy de Grupos, Flujo de caja, Welcome y
el pago planificado están en las carpetas del recorrido, por si Frank quiere mandar la versión actual.

## Lo que pasó a done

| Card | Motivo y evidencia |
|---|---|
| `eb9i` · saldo del Panel con texto grande | accesibilidad/tamaños; `PanelHeroLargeTextUITests` (#779) y la captura AX5 del 17 Pro. |
| `fb1j` · icono del chip de cuenta | accesibilidad/tamaños; arreglo de #771 visto con AX5. |
| `48ri` · hoja de varios registros con texto grande | accesibilidad/tamaños; `MultiDraftReviewUITests` (#771). |
| `ysol` · neto de Grupos con texto grande | accesibilidad/tamaños; arreglo de #771 visto con AX5. |
| `bj9n` · barra naranja al 80 % | decisión de Jürgen del 5-nov; `BudgetStatusCounterTests` (#779). |
| `rtyu` · flotantes de Registros | test del flujo: `TopPrimaryActionUITests` (#779). |
| `hihp` · hoja de ayuda huérfana | retirada (#780); nada que probar. |
| `dz6c` · widgets con pocos datos | capturas antes y después por estado en `qa/evidencia-widgets-estados-20261104/` (#780). |
| `77j1` · borrador que sobrevive al cierre | test del flujo: `NewRecordDraftSurvivesCloseUITests` (#780). |
| `5xj4` · formulario a medias al volver desde fuera | test del flujo: `ExternalEntryForeignSheetUITests` (#776). |
| `f3v2` · subir 2.2 (7) | operación hecha (#767). |
| `4y42` · unslop en Registros, Grupos y Presupuestos | decisión de Jürgen implementada (#768); en el simulador, claro y oscuro: fecha que encabeza su día, etiquetas tranquilas, títulos de grupo, «Activos · N días», «Te quedan» una vez, importes con decimales. |

Tickets cerrados (`tickets/qa` → `tickets/done`): `account-chip-icon-overflows-at-the-largest-text-size`,
`groups-header-net-smaller-than-sides-at-the-largest-text-size`, `multi-draft-review-sheet-cramped-at-the-largest-text-size`
y `half-filled-form-loses-its-amount-after-an-external-entry-on-ci`.

## Lo que se queda y qué lo retiene

| Card | Qué lo retiene |
|---|---|
| `7ygb` · ícono de cristal | §2.6, visto bueno de identidad (pregunta 7). |
| `cjof` · token de Sentry y dSYM | se comprueba en la próxima subida (sin iPhone): el `.log` del archivado y los dSYM en Sentry. |
| `de19` · tandas de UI del QA programado | cierra sola con dos corridas programadas seguidas en verde; la de hoy seguía en curso. |
| `046l`, `7xnd`, `ywm1` | §4: dos aparatos, inicio de sesión real y push real (montaje A). |
| `ppxk`, `n5zw`, `7e60` | §4: iCloud real (montaje B). |
| `fozu` | §4: la pantalla negra no sale en el simulador (montaje C). |
| `7c97` | §4: solo el sandbox de Apple da la causa (montaje D). |
| `laik` | §2.8: decisión pendiente (Siri gratis con el modelo del iPhone). |
| Las 5 preguntas del barrido B | §2.6, visto bueno visual. |

Las de Lola y las de marketing o App Store Connect (`m6sa`, `bil3`, `qn8j`, `gtfd`, `vfsf`) y las de la versión 2.3 no
entran en este barrido.
