---
id: session-redesign-web-and-store-copy
status: backlog
priority: high
area: "web, marketing, legal"
created: 2026-09-09
source: "ADR 2026-09-09 «Sesiones — dos ejes» — consecuencias · partido de after-session-redesign-review-widgets-siri-applepay-and-web-copy por decisión de Jürgen (2026-09-09)"
---

# La web, la política y la ficha dicen que Grupos viaja por iCloud; con el rediseño Grupos es una cuenta en la nube

## Por qué existe este ticket aparte

Salió de la mitad «fuera del territorio de Frank» del ticket
`after-session-redesign-review-widgets-siri-applepay-and-web-copy`. **Es trabajo de Lola**
(`marketing/`, `Web/`): Frank no entra ahí. Se separa para que cada mitad se cierre por su cuenta y el
runbook del rediseño no quede esperando a otro territorio.

## Lo que cambia, en una frase

Hasta hoy Grupos sincronizaba **por CloudKit Sharing** —«por tu iCloud, no por servidores nuestros»—.
Con el ADR de sesiones, **Grupos es una mini-app que vive en el backend de Yala** y necesita una cuenta
Google/Apple. Lo personal es lo que puede seguir siendo privado (iCloud) o estar en la nube.

## Lo que hay que revisar

- [ ] **Política de privacidad** y **términos**: dicen que los datos de Grupos no pasan por servidores
      propios. Con el rediseño es falso.
- [ ] **La web** y la **FAQ**: misma afirmación. Referencia medida: revisión web del 2026-09-03, L2,
      `Web/REVISION-WEB-UX-A11Y-2026-09-03.md:95`.
- [ ] **Ficha de la App Store** en 7 idiomas y **capturas**: la elección privado / nube y Grupos como
      mini-app, tal y como queden al terminar el rediseño.
- [ ] **Etiquetas de privacidad** de App Store Connect: comprobar que declaran lo que recoge la cuenta en
      la nube (puede que ya lo hagan desde el Modo Nube; **medir**, no suponer).

## Decisión de Jürgen (2026-09-09): esto BLOQUEA la publicación

**La política de privacidad y los términos tienen que estar corregidos ANTES de que el rediseño llegue a
la App Store.** Es una afirmación sobre dónde viven los datos de la gente y no puede ser falsa ni un día.
La web comercial, la FAQ, la ficha y las capturas **no** bloquean: se ponen al día en cuanto se pueda.

## Cuándo

Los textos se pueden ir preparando en cuanto el rediseño esté cerrado en código
(`shell-derives-from-two-session-axes` en `2.1`); lo que no se puede es publicar la app antes de que
política y términos estén corregidos.

## Relacionado

- `after-session-redesign-review-widgets-siri-applepay-and-web-copy` — la mitad de Frank.
- ADR `docs/DECISIONS.md` → «[2026-09-09] Sesiones — dos ejes», sección «Fuera de este repo-territorio».
