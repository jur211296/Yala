# Implementar ticket: cloud-signout-collapses-a-groups-session-expiry-into-permanent

## Contexto
Cola nocturna bypass. Tras #168. Al cerrar sesión en la nube, sesión de grupos caducada sigue diciendo «revisa tu conexión».

## Decisión de Jürgen (2026-09-14)
**3A:** Propagar `.sessionExpired` como las otras celdas — «Tu sesión caducó. Vuelve a iniciar sesión…». No copy largo (3B) ni dejarlo (3C).

MODO AUTÓNOMO HASTA TERMINAR: gate, commit, board, `docs/TICKETS.md`, merge, `/cerrar-total`. Bugs/decisiones nuevas → ticket `--solo-crear` y avisar a Frank. Device-QA → `tickets/qa/` si aplica.

Avisos a Frank: (1) decisión/acceso; (2) PR; (3) `/cerrar-total` resumen producto; (4) idle una vez.
No lances el siguiente: Frank encadena. No marketing/.

## Que se pide
1. Leer ticket + CloudSignOutFlowLogic.cloudSignOutGroupsBlockReason.
2. Implementar 3A; criterios.
3. PR a `2.1`; board/`TICKETS.md`; `/cerrar-total`.

## Que NO hay que tocar
marketing/. 3B/3C. Wipe de prod.

## Como se sabe que esta bien
Criterios; tests; PR mergeado; `/cerrar-total`.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, sesión lanzada desde encargo): las recomendaciones se dan por buenas. Se
> discuten en el PR.

**Hechos medidos antes del árbol** (leídos en esta rama, sobre `fb942c652`; nada de esto se ejecutó):

- **H1.** `cloudSignOutGroupsBlockReason` colapsa `.sessionExpired` en `.permanent` (`CloudSignOutFlowLogic.swift:279`).
- **H2.** La pantalla ya sabe decirlo. `ProfileView.presentSignOutBlock` manda `.sessionExpired` al aviso del
  bloqueo, y `SignOutBlockedCopy` le da `groups.errors.sessionExpired` (16 de 16 locales). Las dos cosas tienen test.
- **H3.** Es alcanzable. El paso 1 da `.drained` con el outbox personal vacío, **tras correr un ciclo** (el
  ticket decía «sin ciclar»). El paso 2 da `.sessionExpired` sin token (`GroupsSyncClient.swift:1448`) o con un
  401 que no se renueva (`:1545`, `:1581`).
- **H4.** La hoja del cambio de Apple ID suelta la celda de la nube (`AppleIDCloseNoticeLogic.closeRequest`), y
  la puerta del Welcome no pinta este cierre. La única pantalla afectada es el aviso de Ajustes.
- **H5 · hallazgo.** `.sessionExpired` también sale **sin red**. `CloudAuthService.accessToken()` convierte
  cualquier error en `nil`. Con el token caducado, supabase-swift 2.50.0 intenta el refresh y relanza el error
  de red sin borrar la sesión.
- **H6 · hallazgo.** En la nube, el «Iniciar sesión» del sync parado (banner S11) exige cambios **personales**
  pendientes (`CloudMigrationController.refreshSyncBanner`). «Tu cuenta de Yala» no ofrece volver a entrar.
  **Matizado por la lente (D5), y verificado:** si el SDK borró la sesión, hay una puerta escondida, «Nuevo
  grupo» en la pestaña Grupos, que lleva al inicio de sesión de Grupos. Esa rama no comprueba qué cuenta firma.
  Si la sesión sigue guardada, no hay ninguna puerta.

**D1 · ¿Qué cambia?** → Solo la traducción: `.sessionExpired` sale como `.sessionExpired`, y `.permanent` sigue igual.
Por qué: es la 3A, y la pantalla ya está preparada (H2). Alternativa descartada: tocar el paso 2 o `ProfileView`,
que ya delegan y enrutan bien.

**D2 · ¿Se arregla aquí que un refresh fallido por red salga como «sesión caducada» (H5)?** → No: ticket nuevo
con la decisión para Jürgen, y aviso.
Por qué: ese clasificador decide también la cadencia y el aviso de las otras celdas, así que es otro objeto.
Alternativa descartada: no aplicar 3A hasta arreglarlo; contradice la decisión, y D y F ya arrastran el defecto.

**D3 · ¿Y la puerta para volver a entrar con solo cambios de grupos (H6)?** → Ticket nuevo aparte, sin tocarla.
Además se anota en `groups-outbox-rows-without-a-live-session-have-no-exit` que la nube entra en su población.
Por qué: abrir una puerta es una pantalla nueva y una decisión de producto. Alternativa descartada: ensanchar el
banner S11 a los grupos, que cambia otra pantalla.

**D4 · ¿Cómo se verifica?** → Tests unitarios: la tabla de traducciones y un caso que compone la cadena entera,
del motivo del push al texto del aviso (sugerencia de la lente). Tres mutantes compilados tienen que dar rojo:
volver a `.permanent`, mandarlo a `.uploadRetryLater` y colapsar `.permanent` en `.sessionExpired`. Ningún
XCUITest nuevo; el gate corre los dos que cruza el índice.
Por qué: de la fase al aviso ya hay tests (H2), y no existe seam para un cierre `.cloud`. Alternativa descartada:
inventar un seam que fuerce el veredicto, que deja ciego al test (`testing.md`).

**D5 · ¿Review adversarial?** → Una lente independiente, de solo lectura, antes de los mutantes. Mira los
consumidores de `.blocked(_, .sessionExpired)` alcanzables desde la nube e intenta refutar H5 y H6.
Por qué: el cambio es una línea, pero H5 y H6 salen de leer, no de ejecutar. Alternativa descartada: tres
lentes, desproporcionado para un cambio de copy.
Resultado: confirmó H5, matizó H6, no encontró acciones que cambien con el motivo y dio los tests por buenos.

**D6 · ¿Adónde va el ticket?** → `tickets/qa/`, con guion de device-QA.
Por qué: el efecto visible exige un 401 real de grupos en una sesión `.cloud`. Alternativa descartada: `done`,
que daría por visto lo que nadie ha visto.

**D7 · ¿Qué comentarios se tocan?** → Los que dejan de ser ciertos: el de `.permanent`, el de la traducción y el
del test `pendingWithSessionOrAccountFailure_blocksPermanent`. Al de `.sessionExpired` se le añaden H5 y H6.
Por qué: un «colapsado a propósito» tras el cambio es una premisa falsa. `CloudSessionSignOut.swift` no se toca:
nada de lo que dice deja de ser cierto. Alternativa descartada: renombrar el test, que ya era impreciso antes.

**D8 · ¿Cómo se registra lo nuevo?** → Tickets en `tickets/backlog/` dentro del PR, y aviso a Frank en el resumen
de cierre. No se crean encargos con `lanzar-sesion --solo-crear`.
Por qué: esos tickets esperan antes una decisión de Jürgen, y un encargo pediría una sesión. Alternativa
descartada: el encargo, que Frank puede crear cuando Jürgen decida.

**D9 · ¿Dónde se entrega?** → Worktree, así que rama y PR a `2.1`. El encargo autoriza el merge y `/cerrar-total`.

**D10 · ¿ADR?** → No. La 3A es una decisión de copy y vive en su ticket.
