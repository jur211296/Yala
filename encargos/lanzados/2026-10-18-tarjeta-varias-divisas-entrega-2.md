# Tarjeta con varias divisas, entrega 2: la tarjeta con sus líneas en el Panel, la ficha, Ajustes y el formulario

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` (o rebasa tu rama sobre origin/2.2) y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

## Contexto
Jürgen aprobó el 16-oct (22:38) la cola de cards de 2.2, y la tarjeta multidivisa va primero, en cuatro entregas en orden 1→2→3→4 (obligatoria en 2.2, decisión del 13-oct). La entrega 1 entró hoy en 2.2 (PR #547): el enlace «línea en otra divisa» ya existe en el modelo, en iCloud y en Modo Nube, sin pantallas. Esta es la entrega 2: la tarjeta se ve una vez con sus líneas en el Panel, la ficha y Ajustes, y el formulario permite añadir y vincular líneas.
- Card: `tablero-tarjeta-con-varias-divisas-entrega-2-la-17ec` (muévela a in progress al empezar y a done al cerrar, `--agente frank`; si deja algo para probar en el iPhone, a in qa asignada a `jurgen` con el guion en la nota).
- Ticket con el alcance completo y lo que dejó la entrega 1 (medido el 18-oct): `tickets/backlog/multi-currency-accounts-2-card-view.md` en origin/2.2. Decisiones de Jürgen: `tickets/backlog/multi-currency-accounts.md` y `docs/multi-currency-accounts-impact-2026-10.md`, secciones 3 (A) y 4-6.
- La entrega 1 dejó notas para esta en el ticket: Ajustes y `DowngradeResolutionSheet` hoy no enseñan una línea válida; reordenar en Ajustes manda las líneas al final; archivar la principal en el downgrade tiene que archivar también sus líneas. Las tres son de esta entrega.

## Qué se pide
Los puntos 1 a 7 del alcance del ticket (carrusel del Panel, ficha, Ajustes con líneas anidadas, formulario con «Añadir línea en otra divisa» y «Vincular cuenta existente» y desvincular, recordatorio y día de pago solo en la principal, archivado en cascada que alcance también a `DowngradeResolutionSheet`, y capturas), más los dos arreglos que dejó la review de la entrega 1 (posición de las líneas al reordenar en Ajustes, y la línea que no sale en Ajustes ni en el downgrade). Las pantallas preguntan a `AccountLineLogic` y `AccountLineService`; la vista no repite reglas.

## Qué NO hay que tocar
- Selectores, filtros, presupuestos y captura (entrega 3). Informes y exportación (entrega 4).
- Nada de despliegues a producción (ni CloudKit Production ni Supabase de producción ni el Worker de producción). Esta entrega no debería necesitar esquema nuevo; si lo necesita, déjalo listo, crea su card a `jurgen` (o a `lola` si es CloudKit) y sigue.
- En `~/Yala` (árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques tmux `salud--*`, `sat-lab--*`, `ruum--*`, `clinicas-dentales-bi--*`, ni `Yala--qa-guiado-2-1-tf17`.

## AUTONOMÍA (fin de semana)
Jürgen no está en el escritorio. Si sale una duda reversible, elige la opción recomendada, impleméntala y anótala en la card y en el PR («Decidido por la sesión: …, porque…»). Para el diseño visual sigue el sistema de diseño y los componentes que ya usa Yala y lo que dice el ticket; si dudas entre variantes, elige la más coherente con el Panel actual, y deja las capturas para que Jürgen la revise. Lo irreversible (esquema de producción, borrar datos, cobros) queda para Jürgen, sin parar la sesión.

## Reglas
- Sin esperar el CI de nadie; `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Pipeline serial en la Mini: limpiar, build con `xcodebuild -jobs 2` sin simulador encendido, encender 1 simulador, tests, apagarlo. Mira `df -h /` antes de compilar. Usa los simuladores iOS 27.0. Al cerrar, apaga y borra (erase) el simulador que usaste.
- Al lanzar y al cerrar borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen; no toques las de un worktree vivo.
- Texto nuevo de usuario en los 16 idiomas de la app (el ticket dice 7, pero hoy son 16), con `/l10n-check` en verde y sin nombrar a «OpenAI».
- Todo ticket nuevo lleva su card.
- Prueba según /barrido-qa lo que aplique: XCUITest del Panel y de Ajustes con el seed de tarjeta de dos líneas, test sobre el store de que vincular no cambia ningún movimiento, notificación única.
- Capturas de antes y después del Panel, la ficha, Ajustes y el formulario (con Dynamic Type grande y modo oscuro) en `capturas/` del worktree, copiadas también a `~/Claude/entregas/<sesión>/capturas/`, y con sus rutas en el resumen de cierre.
- Cierra con /cerrar-total.

## Cómo se sabe que está bien
El criterio de hecho del ticket cumplido (una tarjeta con dos saldos y total «≈» en el Panel, líneas anidadas en Ajustes, añadir y vincular líneas con rechazo explicado, recordatorio solo en la principal, copy en los 16 idiomas, capturas, `/gate` en verde), la suite de `YalaTests` en verde, y el PR contra 2.2 explicando en lenguaje de usuario qué ve ahora y qué queda para la entrega 3.

## Paso 0

Decisiones resueltas por la sesión (Jürgen fuera, todas reversibles):

1. **Dónde vive la regla.** Pura en `AccountCardLogic` (nuevo, junto a `AccountLineLogic`): agrupar cuentas en tarjetas, orden guardado con las líneas detrás de su principal, qué líneas archiva la cascada, divisas que se pueden añadir, candidatas a vincular con su motivo de rechazo, total convertido. Las vistas preguntan ahí.
2. **Panel.** Una tarjeta por principal o cuenta suelta; dentro, una fila por línea (divisa y saldo, «Por pagar» por línea) y el total «≈» en la divisa preferida. En «solo gastos», lo gastado por línea y el mismo total. Los chips de la sección plegada enseñan el total de la tarjeta. Filtrar desde la tarjeta sigue filtrando la principal: incluir las líneas es la entrega 3.
3. **Ficha.** Cabecera agregada (líneas y total) y un selector de línea; la cuenta del período, la curva y los movimientos son de la línea elegida (cálculo de siempre, una divisa). «Editar» abre la línea elegida.
4. **Ajustes.** La tarjeta es una fila con sus líneas anidadas dentro; reordenar mueve la tarjeta entera y guarda las líneas justo detrás de su principal (arregla que se fueran al final).
5. **Formulario.** En tarjetas de crédito, sección «Otras divisas» a la vista tras la divisa; en el resto de tipos, las dos acciones dentro de «Acciones». Solo al editar (una línea necesita su principal guardada). Añadir línea = divisa + saldo inicial opcional; la línea hereda tipo, color e icono y se llama «Nombre · ISO». Vincular lista todas las cuentas y explica bajo cada una por qué no se puede. Una línea enseña de qué tarjeta es y «Desvincular»; su divisa queda fija. Una principal no puede pasar a la divisa de una de sus líneas.
6. **Recordatorio.** La sección de tarjeta de crédito no sale en una línea, y el servicio de notificaciones salta las líneas (sin reescribir su ajuste: al desvincular vuelve el suyo).
7. **Archivar.** Archivar una principal con líneas vivas pregunta: archivarlas también o dejarlas como cuentas sueltas. La cascada del formulario las excluye de estadísticas como archivar cada una; la del downgrade solo archiva (regla de `session-filters.md`). Desarchivar la principal no desarchiva sus líneas.
8. **Downgrade.** La fila de la tarjeta dice sus divisas y archivarla archiva sus líneas.
9. **Seed** `-uitest-seed tarjeta-dos-lineas`: «Visa QA» (crédito, PEN) con línea USD, «Ahorros QA» (PEN) y «Dólares QA» (USD, con movimientos, para vincular).

Fuera: borrar una principal deja sus líneas sueltas (comportamiento de la entrega 1); selectores, filtros y captura (entrega 3).
