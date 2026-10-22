---
name: decisiones-que-esperan-a-jurgen
description: Dos tandas de decisiones contestadas (2026-09-02 y 2026-09-06) y el método que funcionó; quedan sin preguntar las dos de Grupos del ESTADO
metadata:
  type: project
---

**Las decisiones que bloqueaban `tickets/in-progress/` desde el 6 y el 12–13 de agosto están
contestadas: Jürgen las respondió todas la noche del 2026-09-02.** Lo que decidió vive en cada
ticket, que es su sitio; aquí sólo queda por qué se destrabaron y qué funcionó.

**Why:** llevaban tres semanas quietas porque nadie se las había puesto delante como decisiones.
Un ticket que espera una respuesta y uno que espera trabajo se ven idénticos en el tablero.

**How to apply — lo que funcionó y conviene repetir:**

- **Se destrabaron todas en una sentada** porque fueron con opciones concretas, consecuencia
  escrita por opción, y una recomendación marcada. No en abstracto y no de una en una.
- **Agrúpalas por lo que comparten, no por ticket.** Dos tickets distintos pedían lo mismo al
  servidor (romper el no-oráculo de `join_group`); presentados juntos, fue una sola respuesta.
- **La recomendación no es un trámite: se apartó de ella en 3 de 8.** Pidió arreglar los ocho
  rojos ANTES de tocar tickets, eligió la opción cara en el móvil prestado, y mandó commitear
  un fichero que yo proponía dejar quieto. Márcala igual —le ahorra tiempo— pero no des por
  hecho que la toma.
- **Verifica el bloqueo antes de citarlo.** Al medirlo, tres de los ocho «bloqueados» no
  esperaban decisión ninguna, una de las cinco ni siquiera estaba en `in-progress`, y faltaba
  una que nadie había listado (la custodia del consent legacy, RGPD). El `ESTADO.md` decía
  «cinco decisiones bloquean 8 tickets»; eran cuatro y bloqueaban cinco.

**Segunda tanda, 2026-09-06 (PR #79):** seis decisiones en dos preguntas agrupadas (4 + 2 extra),
mismo formato —opción, coste, recomendada primero— y **tomó la recomendada en las seis**. No es
señal de que la recomendación sea un trámite (el 2-sep se apartó en 3 de 8): es que las seis
tenían una salida barata y coherente con algo que él ya había decidido antes (el 26-ago, el 2-sep,
el 3-sep). **Cuando la opción recomendada se apoya en una decisión SUYA anterior, la toma sin
pensarlo; cítala.** Un ticket de dos decisiones dentro (kill-switch) se parte en dos preguntas.

**Y una tercera tanda el mismo día, que enseña lo importante:** tras las seis, Jürgen preguntó
«¿estamos seguros de que ya ninguna necesita decisión mía?». Mi «sí» habría salido del encargo
(acotado a 3+2) y de un grep de «decisión». **Leer los 94 tickets vivos enteros destapó 13 más** —seis
de ellas frenaban bugs— repartidas en `backlog/` Y en `qa/` (tickets ya implementados que dejaban un
residual «decisión aparte» sin ticket propio). Las contestó todas (13/13 la recomendada). ⇒ **«¿queda
alguna?» se responde leyendo, con lectores en paralelo y control positivo de las citas; y el
residual de un ticket de `qa/` que dice «decisión aparte» es una decisión huérfana: sácala a ticket.**
Quedan como abiertas del ESTADO solo las dos de la web (legal de Grupos, Vercel `1.0`/`2.1`).

Relacionado: [[el-tablero-antes-que-el-bug]] · [[jurgen-levanta-sus-reglas]]

## Alta del 2026-09-06 (tarde): `groups-archived-still-accepts-changes`

Salió de **cumplir un AC al pie de la letra**, no de buscar trabajo: el ticket
`groups-archived-group-rejects-join` pedía «revisar que el cuerpo del copy siga siendo verdad palabra
por palabra», y no lo era. La app promete que un grupo archivado «ya no acepta cambios» y en realidad
acepta todos: gastos, ediciones, liquidaciones, ajustes, invitaciones.

**Why:** es una decisión de producto de las que no puede tomar quien implementa —«archivar» puede
significar congelar (opción 1) o solo apartar de las listas (opción 2)— y las dos son razonables. El
encargo además prohibía expresamente inventar otra semántica de archivado, así que salió a ticket con
las tres opciones y su coste, en el formato que funciona.

**How to apply:** va en la próxima tanda que se le ponga delante. Y la lección que se repite: **un AC
que dice «revisa que X siga siendo verdad» es una tarea de medición real, no una fórmula** — éste
destapó un desajuste que llevaba meses en 16 idiomas.



## Tercera tanda, 2026-09-08 (PR #100) — cinco preparadas, dos avisos

Sesión de desbloqueo entera: **no se implementó nada de producto**, solo se dejaron las cinco
decisiones escritas con opciones, coste medido y recomendación. Los tickets:
`groups-owner-debt-no-heir-dead-end`, `groups-settlement-reminder-discoverability`,
`approximate-mark-ors-over-whole-period`, `cobertura-ui-diaria-cuelga-del-push`,
`dmarc-sube-la-politica-tras-observar`.

**Lo que cambió mi forma de prepararlas, y conviene repetir:**

- **Medir el coste de cada opción antes de recomendar cambió dos recomendaciones de sitio.** No
  «esta parece mejor», sino «(c) son 2 ficheros porque la funcionalidad ya existe y (b) son 5 más una
  métrica nueva». Con el número delante, la recomendación se defiende sola y él decide en una línea.
- **Tres premisas de los propios tickets eran falsas**, y las tres se cazaron con un grep:
  un calculador dado por «no afectado» que acumulaba con el mismo OR; una opción cuya mecánica no
  funcionaba (netos que suman cero, así que filtrar por activos sigue bloqueando); y un criterio de
  descarte que **se había cumplido esa misma mañana**. ⇒ un ticket que lleva días escrito es un
  documento, y aquí los documentos envejecen: **mide el ticket antes de preguntar sobre él**.
- **Dos avisos de 600 caracteres, agrupados por naturaleza** (tres de producto / dos de infra), con
  la letra de la opción recomendada en cada uno para que conteste «1c, 2 sí, 3b…» sin abrir nada.

**Lo que queda por saber:** si contesta. Se cerró sin respuesta, con los cinco tickets en `backlog`
y la decisión marcada como pendiente — board honesto, que es lo que pidió el encargo.
