---
esfuerzo: high
---
# S11e · Solo grupos: pausar pagos de grupo + callar Apple Pay/Siri

## Qué hay que hacer
Aplicar las dos decisiones de Jürgen (27-oct) sobre el modo Solo grupos elegido desde Ajustes.

## Contexto
PR #649 ya mergeó el cambio de modo. Quedaron dos deltas de producto:
1. En Solo grupos se **suspenden** también los pagos programados de **grupo**. Al volver a Yala completo **no** deben aparecer de golpe: siguen suspendidos hasta el ciclo normal.
2. Apple Pay y Siri en Solo grupos **no se permiten**. La acción debe quedar en algo como «No tienes Yala completo, actívalo para usar esta funcionalidad.» (no banners a la Bandeja).

Tickets repo: `groups-only-by-choice-holds-group-scheduled-payments`, `groups-only-by-choice-still-shows-apple-pay-and-siri-banners`.
Cards: pausar pagos de grupo; callar Apple Pay y Siri.

## Qué se pide
- Implementar ambas en la app (copy en los 16 idiomas donde aplique).
- Tests que fijen el comportamiento.
- La sesión **termina con `/cerrar-total`**.

## Qué NO hay que tocar
- El comportamiento del iPad con dos ventanas (Jürgen aceptó dejarlo como está).
- CloudKit / Worker / deploys.

## Cómo se sabe que está bien
- En Solo grupos no se crean borradores de pagos programados de grupo; al volver no se drenan de golpe.
- En Solo grupos no salen banners de Apple Pay/Siri; al invocar se ve el aviso de activar Yala completo.
- Unit/UI tests verdes en lo tocado.

Cards: `tablero-en-solo-grupos-pausar-no-soltar-de-golpe-mao4`, `tablero-en-solo-grupos-callar-apple-pay-y-siri-c-6mb6`. Versión 2.2. Base `origin/2.2`. Al cerrar, cards a in qa asignadas a jurgen con guion de iPhone si hace falta QA manual; si no, a done.
Cierre: cierra sola con `/cerrar-total` salvo decisión vital (fuerza mayor, seguridad o diseño crítico).

## Pie pipeline
- Una sesión Yala a la vez. Rebase único antes del PR (gate después del CI del PR anterior).
- Pipeline serial Yala: (1) limpiar sims muertos, DerivedData y cachés XcodeBuildMCP de worktrees cerrados; (2) build `xcodebuild -jobs 2` sin sim booteado; (3) bootear 1 sim; (4) tests; (5) apagar y limpiar.
- Al lanzar y al cerrar, borra sin preguntar el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen.
- Al cerrar: Frank publica digest y lanza la siguiente según `~/Claude/tmp-frank/siguiente-activo.txt` y `~/Claude/tmp-frank/cola-2-2-orden-activo.txt`.

## Paso 0

Decisiones de Jürgen (AskUserQuestion, 27-oct, las tres con la recomendada):
- **Personales igual que los de grupo.** Al volver de Solo grupos, lo que venció durante la pausa no aparece: cada pago
  recurrente vuelve en su próxima fecha. Los de pago único sí salen al volver (no tienen próxima fecha).
- **Siri entera.** Anotar y preguntar (gasto, saldo) dan el mismo aviso.
- **También sin haber activado nunca Yala completo**, con «Activa…» en vez de «Vuelve…».

Medido antes de decidir:
- La pausa de los borradores ya existía (PR #649, `processDuePayments` con `PersonalRemindersPause`). Lo que faltaba es
  la vuelta: `UsageModeService.returnToFull` llamaba a `processDuePayments` y sacaba el vencido más antiguo de cada pago.
- Los atajos que ABREN la app (nuevo registro, voz, foto) ya ofrecen activar en la shell de solo grupos
  (`AppBootstrapper.executeAction`). El hueco es de los que corren en segundo plano: Apple Pay y Siri.
- El enlace `activate-full` ya hace la vuelta con sesión privada (`ContentView`, `.presentFullModeActivation`).

Asumido (técnico, mío):
- Se salta una ocurrencia si cae entre el día en que empezó la pausa y AYER; la de hoy es ciclo normal. La fecha de
  inicio se apunta con la marca (`GroupsOnlyViewMark`); sin ella (marca puesta por un build anterior), todo lo de antes
  de hoy.
- Un borrador ya pendiente se queda y lo de la pausa que venía detrás se salta; un vencimiento de antes de la pausa
  que nunca salió, sale al volver (corregido tras la review adversarial: la primera versión no tocaba esos pagos y lo
  de la pausa salía detrás, uno a uno). Sin marca de pausa, la vuelta no salta nada.
- Saltar = avanzar `nextDueDate`, no marcar fechas saltadas: `skippedDates` viaja y archivaría borradores que el iPad
  creó en Yala completo durante la pausa.
- Apple Pay en segundo plano no puede mostrar nada: el aviso es la notificación, y su toque abre la vuelta/activación.
  El pago no se encola.
- Siri «anotar» dice el aviso y abre Yala en la vuelta/activación (mismo molde que la hoja de Pro). Las preguntas solo
  dicen el aviso.
- Copy sin «solo grupos» fuera de Ajustes (regla l10n): «Ahora ves solo tus grupos…».
