---
id: invite-aasa-requires-s-param
status: backlog
area: groups
priority: low
created: 2026-09-05
updated: 2026-09-05
source: invite-link-five-causes-one-message (pieza 3)
---

# El AASA sigue exigiendo `s`, así que el enlace mínimo lo abre Safari

## Qué pasa

Un enlace de invitación de la forma mínima —`https://yala-app.pe/invite?g=..&t=..`, sin el
parámetro `s`— **no abre la app**: abre la web. No es un fallo mudo (la persona ve la página), pero
se salta el camino nativo que ya funciona.

## Lo medido (2026-09-05, este árbol)

`Web/public/.well-known/apple-app-site-association` declara un único component:

```json
{ "/": "/invite", "?": { "s": "*" }, "comment": "Group invite universal links" }
```

⇒ iOS solo entrega a la app los universal links que llevan `s`.

La pieza 3 de `invite-link-five-causes-one-message` ensanchó la puerta del **cliente**
(`InviteLinkService.isInviteLink` acepta `g`+`t` sin `s`, igual que el parser), lo que cubre las
otras dos vías de entrada:

- **custom scheme** (`yala://invite?g=..&t=..`) — antes moría en el `default` del `switch url.host`
  de `handleIncomingURL`, sin una línea de UI. Ya no.
- **paste manual** en `InviteRecoveryView` — no pasa por el AASA en absoluto.

Queda solo el universal link. **Hoy es inocuo**: `buildBackendInviteURL` emite siempre `s`, así que
ningún enlace real de producción tiene esta forma. Deja de serlo el día que alguien emita el mínimo.

## El fix

Añadir un segundo component al AASA que acepte `g`+`t`. No sustituye al de `s` — lo acompaña:

```json
{ "/": "/invite", "?": { "g": "*", "t": "*" }, "comment": "Backend invite, minimal form" }
```

## Por qué NO se hizo en la misma pasada

Toca `Web/`, o sea **despliegue**, y ahí hay una decisión abierta de Jürgen: la rama de producción
de Vercel es `1.0`, así que un cambio mergeado a `2.1` no se publica solo (§9 de
`Web/REVISION-WEB-UX-A11Y-2026-09-03.md`). Editarlo sin resolver eso deja el fichero cambiado en el
repo y el AASA vivo igual que estaba — la peor de las dos situaciones, porque parece hecho.

**Ojo al verificar**: iOS cachea el AASA. Tras desplegar, comprobar contra el fichero servido
(`curl https://yala-app.pe/.well-known/apple-app-site-association`), no contra el del repo.
