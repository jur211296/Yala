---
id: flows-atlas-predates-session-redesign
status: backlog
priority: low
area: "docs, modo-nube, onboarding"
created: 2026-09-10
updated: 2026-09-13
source: "review adversarial del paso 7 del rediseño de sesiones (`onboarding-purpose-drops-groups-card`)"
---

# El Atlas de flujos de Modo Nube describe pantallas que el rediseño de sesiones ya retiró

## Qué pasa

`docs/flows/modo-nube/` (el Atlas: storyboard por persona, `index.html` + `data/*.js` + `check.mjs`)
está anclado a **HEAD `5bbb5690` del 2026-08-12**, y su README lo dice: si el código se mueve, lo que
caduca es el Atlas. El rediseño de sesiones (ADR 2026-09-09 «Sesiones — dos ejes») lo está moviendo
paso a paso, y el Atlas sigue contando lo de antes.

Medido el 2026-09-10, con el paso 7 aplicado:

- **`node docs/flows/modo-nube/check.mjs` pasa de 4 a 13 fallos.** Los 9 nuevos son la comprobación de
  l10n: `data/l10n.js` cita 7 keys que el paso 7 borró de los 16 `.strings` (la card «Dividir gastos con
  amigos», sus textos de moneda y resumen, y el aviso de iCloud de la card), en los nodos
  `onboarding-purpose`, `onboarding-muro`, `onboarding-groupsonly` y `visita-privado-onboarding`. Los 4
  anteriores (valores que ya no casan) venían de antes.
- **Tres paneles describen una card que ya no existe** (`onboarding-muro`, `onboarding-groupsonly` y la
  card del panel `onboarding-purpose`), y el recorrido **R4 «Solo quiero grupos»** los incluye.
  `data/nodes.js`, `flows.js` y `f2.js` los citan con `OnboardingGroupsOnlyGuardUITests` y
  `OnboardingGroupsPurposeGateLogic`, que tampoco existen ya.
- Y lo que viene detrás es más grande: los recorridos **R10 «Estoy de visita»** y **R11 «El dueño
  recupera su móvil»** son la sesión secundaria (M1), que el mismo ADR retira en el ticket 12.

## Lo que pasó el 2026-09-13: eso que «venía detrás» ya llegó

El PR-B del paso 12 retiró M1 entera, y con ella las 12 claves de copy de esos dos recorridos. Medido
con el árbol base al lado, que es como se separa lo mío de lo que ya estaba:

| | fallos de `check.mjs` |
|---|---|
| árbol base (`70a949ed`) | **45** |
| tras el PR-B | **55** |

Los **10 nuevos son todos de la misma familia**: nodos que citan claves de pantallas retiradas —
`alta-groupsgate-blocked`, `reentry-secondary`, `visita-crear-grupo`, `visita-shell`, `vuelta-hoja`. El
11.º y el 12.º **sí se arreglaron en ese PR** y no por generosidad: el banner de hidratación sobrevivió
al barrido con la clave renombrada (`welcome.cloud.hydrationBanner`), así que ahí el nodo seguía siendo
verdad y solo había que corregir el nombre. De paso se le quitó el `unreachable`, que ya era falso: ese
banner hoy alcanza a quien cambia de móvil y entra con su cuenta.

**Lo que NO se hizo en el PR-B, y es deliberado:** retirar los 30 paneles de los dos recorridos. Son dos
flujos enteros de los siete del Atlas, repartidos en cinco ficheros con conteos declarados (`154 paneles
· 111 shots · 113 entradas l10n`), su storyboard y sus imágenes. Es una cirugía propia, y hacerla dentro
de un PR de código habría mezclado dos objetos — con el agravante de que el Atlas ya estaba rojo antes
de tocarlo, así que no había un verde que proteger.

`check.mjs` no lo corre ni el CI ni el gate, así que nada bloquea. Pero el Atlas se consulta creyendo que
cuenta la app de hoy.

## Por qué no se arregló en el paso 7

Editar a mano cuatro nodos dejaría el Atlas mitad anclado a `5bbb5690` y mitad al 2026-09-10, que es
peor que un Atlas entero y fechado. Y el paso 7 es uno de trece: re-anclarlo ahora obligaría a
re-anclarlo otra vez tras el 8, el 9, el 10 y el 12.

## Lo que hay que decidir (Jürgen)

**El disparador que este ticket esperaba ya ocurrió**: el paso 12 está en `2.1`, así que el rediseño de
sesiones terminó y la decisión deja de poder aplazarse por «vendrán más pasos».

- **Re-anclarlo entero ahora que el rediseño terminó**, con capturas nuevas; o
- **Retirarlo** si el storyboard ya no se usa, y quedarse con la matriz del rediseño
  (`docs/sessions/2026-09-09-matriz-escenarios-sesiones.md`) como mapa de escenarios.

## Criterio de aceptación

- [ ] Decisión tomada y escrita aquí.
- [ ] Si se re-ancla: `node docs/flows/modo-nube/check.mjs` en `RESULT: OK` contra el árbol del
      re-anclaje, y la cabecera del Atlas con la fecha nueva.
