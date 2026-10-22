# Cerrar sesión en la nube no debe borrar un cambio personal que no llegó a capturarse

## Contexto
Cola A de Yala (solo tickets cloud/sync con riesgo real de pérdida de datos). El ticket es
`tickets/backlog/personal-sign-out-reads-an-unfinished-drain-as-nothing-pending.md`: léelo entero, trae el diagnóstico
(push-all del cierre personal en `CloudMigrationController.pushAllForSignOut` decide `.drained` con el outbox vivo a 0,
pero un drain que ABORTA hace rollback y deja el cambio fuera del outbox). Es el gemelo personal de
`groups-drain-failure-reads-as-nothing-pending` (ya cerrado): mira cómo se resolvió en Grupos y sigue el mismo patrón.
PR #260 (personal-clock-rollback) acaba de mergearse a 2.1; parte de ahí.

En paralelo corre otra sesión aislada (`Yala--plugin-claude-mcp-fase0-spike`, un servidor MCP fuera de la app). No
comparte ficheros contigo; no la toques.

## Que se pide
Cerrar el ticket con la opción más robusta (norma de Jürgen: nunca la más simple): tras un `.drained` del bucle con
motor, comprobar `runtime.hasUncapturedPersonalChanges(context:)`; `true` o `nil` bloquea el cierre sin descartar nada,
con el motivo que ya usa el push-all. Tests que cubran el drain que aborta y el caso sin nada pendiente. Si al buscar
aparecen otras instancias del mismo patrón, ticket propio en `tickets/` por cada una.

## Que NO hay que tocar
Nada de marketing/. Nada de prod de Supabase. No cambies copy visible salvo que sea imprescindible, y entonces reutiliza
el motivo existente. No toques el spike del plugin MCP.

## Como se sabe que esta bien
Los dos criterios de aceptación del ticket cumplidos con tests en verde, build OK, PR mergeado a 2.1, guion de
device-QA dentro del ticket movido a `tickets/qa/`, y `docs/TICKETS.md` al día con los conteos correctos.

## MODO AUTÓNOMO
Queda suspendida la regla del repo de esperar aprobación con más de 3 ficheros y el «¿Sigo?» tras el plan: implementa
de punta a punta (gate, PR, merge) sin pedir permiso para continuar. Es de día en Lima (06:00–21:00): puedes usar
AskUserQuestion solo para una decisión real de producto o de acceso; las técnicas las decides tú eligiendo la opción
robusta. Cierra con `/cerrar-total`, dejando el board al día en `tickets/` y `docs/TICKETS.md`.

## Paso 0 — decisiones (resueltas en autónomo (bypass))

1. **Dónde.** En `CloudMigrationController.pushAllForSignOut`, rama con motor: tras un `.drained` del bucle se lee
   `runtime.hasUncapturedPersonalChanges(context:)`. `false` ⇒ `.drained` como hoy; `true` o `nil` ⇒
   `.blocked(pendingCount: Int.max, reason: .transient)`. La decisión vive en una función pura nueva de
   `CloudSignOutFlowLogic` (molde `groupsCaptureVerdict`), para fijarla en tabla.
2. **Bloquear al momento, no dar otra vuelta.** Lo pide el encargo y es lo limpio: la sonda no distingue «el drain
   abortó» de «alguien escribió después del drain», y una vuelta más no cura el primero (un `save` que falla vuelve a
   fallar) y con el segundo el aviso ya dice lo cierto. Asumido.
3. **Motivo `.transient`** («Un momento más… espera unos segundos y vuelve a intentarlo»): es el que el push-all ya usa
   para el guardado que se asienta, y lo que falla aquí es un guardado de este teléfono, no la subida. Grupos eligió
   `.uploadRetryLater` por el corte del reloj, que ya no se da. Sin copy nuevo.
4. **El bloqueo por App Attest también se re-lee** (molde `attestBlockAfterRecapture` de Grupos). Es el único bloqueo
   que el paso 1 deja seguir perdiendo las filas aceptadas; con una edición fuera del outbox la persona aceptaría perder
   lo que el aviso no le enseñó. Con la sonda en `true`/`nil` sale `.transient` (sin salida de pérdida). Es parte de
   «seguir el patrón de Grupos», no otra instancia.
5. **Otra instancia, a ticket:** el paso 4 del cierre en la nube (re-verificación tras el teardown) solo cuenta el
   outbox, y su comentario ya documenta el residual «writes que queden solo en History mueren con el wipe».
6. **Tests:** drain que aborta (save del outbox que lanza) y traducción cortada ⇒ bloquea sin escribir en el outbox;
   edición real drenada y subida ⇒ `.drained` sin ciclos ni red extra; tabla de la función pura; attest con edición sin
   capturar. Mutantes sobre los dos términos. **Review adversarial sí** (sync, borra datos).

### Paso 0 · revisado tras medir (misma sesión)

7. **La 2 cambia: otra vuelta, con el tope del bucle.** La review (lente del cierre) midió escritores legítimos
   posteriores al drain del ciclo —reconciliadores del pull, puente de Grupos del paso 5.6, un ciclo que coalesce— que el
   ciclo siguiente cura. Bloquear al momento les daba un «un momento más» evitable; el drain que aborta siempre sigue
   llegando al tope y bloqueando igual.
8. **La purga del History entra en el alcance.** Medido con el primer test: en el ciclo real, la purga del final
   (`purgeHistoryOnce`, corte en `now`) borraba la edición del drain abortado y la sonda decía «nada pendiente». Sin
   tocarla el criterio 1 no se cumple, y el mismo corte perdía para la nube toda edición guardada tras el último drain de
   un ciclo. Corte nuevo: menor de `now`, ancla del drain y lo más viejo sin consumir por token.
9. **La sonda lee la ventana del drain** (respaldo de token roto y paso 3-bis): con la purga vieja el token caducaba en
   cada ciclo y la sonda habría bloqueado todos los cierres (medido: `historyTokenExpired` tras un ciclo sano).
10. **Otra instancia más, a ticket:** el drain que aborta siempre deja «un momento más» para siempre, también al teléfono
    sin App Attest. Precio aceptado y documentado: el ancla avanza con la siguiente fila personal (a diario, el tipo de
    cambio), así que el History de Grupos crece como mucho ese intervalo.
