---
id: cobertura-ui-diaria-cuelga-del-push
status: discarded
priority: medium
area: ci
created: 2026-09-08
updated: 2026-10-06
source: medido al cerrar `la-nocturna-de-ui-no-ha-disparado-ni-una-vez`
---

# La cobertura diaria de UI cuelga del ritmo de trabajo, no del calendario

## De dónde sale

`la-nocturna-de-ui-no-ha-disparado-ni-una-vez` (done) dejó medido que **el `schedule` de GitHub
Actions no sirve ventanas en este repositorio**: siete ventanas de un canario `*/5` en 37 minutos y
la de `qa.yml` con 7 h 53 min de margen, todas en cero, con control positivo (el canario lanzado a
mano corre en verde, así que falla el reloj y no el workflow).

La cobertura la sostiene `nocturna-vigilante.yml`, y lo hace de verdad — está verificado de punta a
punta en producción. Pero de sus dos relojes, **solo uno funciona**:

- `schedule` a las 11:43 UTC → es el mismo mecanismo que no dispara. Hoy no vale.
- `push` sobre la rama por defecto → **este es el que sostiene todo.**

## El hueco, medido

Un reloj de `push` no es un reloj diario. En los últimos 30 días hubo **8 sin ningún commit en
`2.1`**, con rachas de hasta **3 seguidos** (2026-08-19/20/21 y 2026-08-23/24/25).

```
git log origin/2.1 --since='30 days ago' --format='%cd' --date=format:'%F' | sort -u
```

En esos días no corre la suite de UI. El atenuante es real y hay que tenerlo delante antes de
gastar trabajo aquí: **un día sin commits tampoco trae código nuevo que probar**. Lo que se pierde
no es cobertura del código, es vigilancia del entorno — el tipo de rojo que aparece porque cambió
el runner, Xcode o el simulador, no porque cambiara Yala. Ese sí se detectaría tarde: el primer día
que alguien commitee, y mezclado con su propio cambio.

## La decisión (es de Jürgen)

1. **Montar un reloj que no dependa de GitHub.** Un `launchd` en la Mini que haga
   `gh workflow run qa.yml --ref 2.1` una vez al día. Es acceso suyo. Ventaja: cadencia real.
   Coste: una pieza más de infraestructura local, y depende de que la Mini esté encendida.
2. **Aceptar el hueco.** La cobertura de UI va atada al ritmo de trabajo. En un repo con esta
   cadencia es defendible, y no cuesta nada.
3. **Reintentar el `schedule` más adelante.** Si el cron vuelve a servir ventanas, el vigilante ya
   está preparado para usarlo: su `schedule` está escrito y en cuanto GitHub dispare, funciona sin
   tocar nada.

## Cómo saber si esto sigue vivo

Si el `schedule` vuelve a funcionar, este ticket se descarta solo:

```bash
gh api 'repos/jur211296/Yala/actions/runs?event=schedule&per_page=100' --jq .total_count
```

Deja de ser cero ⇒ el reloj de GitHub sirve, el vigilante lo usa y el hueco se cierra sin trabajo.

## Acceptance Criteria

- [ ] Decidido cuál de las tres, y escrito por qué.
- [ ] Si es la 1, el `launchd` existe y se ha verificado que su corrida aparece en Actions.


---

## Para decidir — preparado el 2026-09-08

> ⚠️ **La premisa de este ticket cambió de estado hoy, entre que se escribió y que se preparó la
> decisión.** Léelo antes de elegir.

### El `schedule` de GitHub **ya dispara** en este repositorio

El propio ticket define su criterio de descarte: «`gh api …runs?event=schedule…` deja de ser cero ⇒
el reloj de GitHub sirve». Lo corrí hoy y **ya no es cero: es 1**.

```
wf=QA · id=34228530861 · creado=2026-09-08T12:52:03Z · rama=2.1 · path=.github/workflows/qa.yml
```

Es la nocturna de `qa.yml`, sobre `2.1`, y estaba corriendo (`tests: in_progress`) mientras escribo
esto. Controles positivos en la misma tanda: `event=push` → 1103 runs, `workflow_dispatch` → 4. Así
que la consulta mide lo que dice medir.

**Pero un disparo no es un reloj fiable, y el retraso es el dato que importa:**

| | |
|---|---|
| cron declarado en `qa.yml:37` | `17 8 * * *` → **08:17 UTC** |
| nacimiento real del run | **12:52 UTC** |
| **retraso** | **4 h 35 min** |

El hueco de `push`, re-medido hoy sobre los últimos 30 días: **8 días sin ningún commit en `2.1`**,
racha máxima **3 seguidos** — idéntico a lo que decía el ticket.

### Y de camino salió un fallo que no es de este ticket

El vigilante comprueba a las **11:43 UTC** que la nocturna nació, con un margen declarado de 3 h 26
min sobre la ventana de las 08:17 (`nocturna-vigilante.yml:33-41`). **Hoy el retraso real fue mayor
que ese margen**: el vigilante habría mirado **1 h 09 min antes** de que la nocturna naciera, y
habría cantado un rojo falso. No ha pasado porque el vigilante **nunca ha disparado por `schedule`**
(medido: 0 runs); vive del `push`. El día que su cron despierte, empieza a mentir.

⇒ Queda en ticket propio: `vigilante-margen-menor-que-el-retraso-real-del-cron`.

### Las opciones, revisadas con lo de hoy

**(1) `launchd` en la Mini** — un reloj que no depende de GitHub. Cadencia real y garantizada.
Coste: una pieza de infraestructura local, y depende de que la Mini esté encendida. **Es acceso
tuyo.** Con el cron despertando, es la opción que compra menos de lo que costaba ayer.

**(2) Aceptar el hueco.** Coste cero. Lo que se pierde no es cobertura del código —un día sin
commits no trae código nuevo que probar— sino vigilancia del entorno: el rojo que aparece porque
cambió el runner, Xcode o el simulador. Ese llega tarde y mezclado con el commit de otro.

**(3) Dejar que el `schedule` haga su trabajo.** Ya no es «reintentar más adelante»: es «ya está
pasando». El vigilante está escrito y listo; no hay que tocar nada.

### Mi recomendación: **(3), y volver a mirar el 2026-09-22**

Porque el trabajo de la (1) se justificaba con un mecanismo muerto, y el mecanismo respiró hoy.
Montar un `launchd` ahora es construir un reloj de repuesto sin saber todavía si el bueno anda.

Lo que sí hace falta es **no dar por bueno un solo disparo**. Dos semanas dan una muestra que
distingue «funciona con retraso» de «funcionó una vez»:

```bash
gh api 'repos/jur211296/Yala/actions/runs?event=schedule&per_page=100' \
  --jq '[.workflow_runs[] | select(.path==".github/workflows/qa.yml")] | length'
```

- **≥ 10 de 14 días** ⇒ el reloj sirve. Este ticket se cierra como `discarded` y el hueco se cerró
  solo.
- **≤ 3 de 14** ⇒ fue un accidente. Entonces la (1) se gana su coste y se monta el `launchd`.
- **En medio** ⇒ sirve a ratos; decides tú si un día de cada dos es suficiente.

Y en cualquiera de los tres casos, el fallo del margen del vigilante hay que arreglarlo — porque
justo si el cron empieza a servir, es cuando su falso rojo aparece.

### Si eliges (1), el AC es

- [ ] El `launchd` existe en la Mini y su corrida **aparece en Actions** (verificado, no supuesto).
- [ ] Corre `gh workflow run qa.yml --ref 2.1` y no duplica la nocturna los días en que el
      `schedule` sí dispara.

### Si eliges (3), el AC es

- [ ] Fecha de re-comprobación anotada: **2026-09-22**, con el comando de arriba.
- [ ] El ticket del margen del vigilante queda enlazado y no se cierra con este.

### Decisión de Jürgen

**(3) Dejar que el `schedule` trabaje, y re-mirar el 2026-09-22.** Contestada el 2026-09-08.

No se monta el `launchd`: el trabajo se justificaba con un mecanismo muerto, y el mecanismo respiró
el mismo día en que se preparó esta decisión. Montar un reloj de repuesto sin saber si el bueno anda
es gastar el trabajo antes de tener el dato.

**Qué se mide el 22-sep**, con dos semanas de muestra:

```bash
gh api 'repos/jur211296/Yala/actions/runs?event=schedule&per_page=100' \
  --jq '[.workflow_runs[] | select(.path==".github/workflows/qa.yml")] | length'
```

- **≥10 de 14** ⇒ el reloj sirve; este ticket se cierra como `discarded` y el hueco se cerró solo.
- **≤3 de 14** ⇒ fue un accidente; la opción (1) se gana su coste y se monta el `launchd`.
- En medio ⇒ sirve a ratos, y decide él si un día de cada dos basta.

**Este ticket NO cierra el del vigilante.** `vigilante-margen-menor-que-el-retraso-real-del-cron` se
arregla pase lo que pase: si el cron sirve, su falso rojo aparece; si no sirve, el vigilante sigue
colgando del push.

---

## Cierre — 2026-10-06: `discarded` por su propio criterio

La re-medida que pedía la decisión (prevista para el 22-sep) se hizo el 6-oct, con más muestra:
**la nocturna de `qa.yml` nació por `schedule` los 29 días del 8-sep al 6-oct** (≥10/14 ⇒ el reloj
sirve). El hueco que describía este ticket se cerró solo.

```bash
gh api 'repos/jur211296/Yala/actions/workflows/286940687/runs?event=schedule&per_page=100' \
  --jq '.workflow_runs[] | .created_at'
```

Dos matices medidos el mismo día, que cambian cómo se lee ese comando:

- **El reloj sirve, pero tarde**: entre 3,9 y 8,9 h después de las 08:17 UTC (07:10–12:10 en Lima).
- **La consulta de arriba miente a ratos**: el endpoint filtrado por evento devolvió `total_count:
  0` y, un minuto después, 29. Por eso el vigilante lanzó 22 nocturnas de más en ese tiempo. Si
  vuelves a medir esto, repite la consulta y usa el id del workflow, no te fíes de una sola lectura.

El arreglo del vigilante va en el encargo `2026-10-06-ci-full-ui-suite-on-2-1-misses-its-schedule`
(ver [[vigilante-margen-menor-que-el-retraso-real-del-cron]]).
