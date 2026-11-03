# Arreglar el rojo de tests del PR de la cabecera de Grupos (#757): textos en francés de Grupos deben tutear

Base: la rama del PR, `encargo/2026-11-03-grupos-cabecera-propuestas`, en jur211296/Yala (PR https://github.com/jur211296/Yala/pull/757). Una sola sesión a la vez.

## Qué pasa
- El PR #757 (cabecera de Grupos con neto grande, barra debes/te deben y rosa de marca) está abierto con auto-merge, pero no entra porque el job `tests` está en rojo desde las 10:52 Lima.
- El único fallo, repetido en los 3 intentos: `frenchGroupsStringsUseTu()` en `GroupsInformalRegisterTests.swift:68` (suite «Grupos · fr y de tutean»): `Expectation failed: offenders.isEmpty`. Corrida: https://github.com/jur211296/Yala/actions/runs/41659638172
- Sospecha (verificar): algún texto nuevo de la cabecera («Debes en total», «Te deben en total», «y N más», etc.) quedó en francés con «vous» en lugar de «tu». Revisa también el alemán (du, no Sie) por si acaso.

## Qué hacer
1. Reproduce el test en local y mira qué cadenas son las culpables.
2. Corrige las traducciones fr (y de si aplica) para que tuteen, sin tocar el diseño ya elegido por Jürgen.
3. Corre la suite de Grupos y el test en cuestión; empuja a la misma rama y confirma que el CI del PR queda en verde y que el auto-merge lo mete en 2.2.
4. Si en el mismo PR hay otro rojo distinto, arréglalo también y explícalo en el PR.

## Cierre
Tarea chica, cierre autónomo: termina con /cerrar-total.

## Paso 0

- **Culpable medido:** una sola cadena, `fr groups.hero.netEven` = «Vous êtes quittes · en %@». Alemán limpio: sus «Sie» son las excepciones de tercera persona ya registradas. El CI tenía 1 issue sobre 12 590 tests: no hay otro rojo.
- **Traducción:** «Tu es quitte · en %@», singular como el español «Estás a mano». Asumido: es el neto de la persona con todos sus grupos, no un «estáis» plural.
- **Fuera:** nl, pl, it y pt usan plural informal («Jullie», «Jesteście», «Siete», «Vocês»). No es usted y el test solo mira fr/de; no se toca.
- **Entrega:** commit en la rama del PR #757, sin PR nuevo; el auto-merge ya está en cola.
