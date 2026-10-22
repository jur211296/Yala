---
id: vigilante-calla-si-no-puede-comprobar-la-nocturna
status: done
priority: medium
area: "ci, observabilidad"
created: 2026-09-09
updated: 2026-10-06
source: leído al migrar los avisadores a la action compartida (PR #123)
---

# El vigilante de la nocturna calla justo cuando no puede comprobar nada

## Qué pasa

`nocturna-vigilante.yml` decide todo a partir de un solo output:

```bash
set -euo pipefail
...
recientes=0
for EV in schedule workflow_dispatch; do
  n=$(gh api "repos/$REPO/actions/workflows/qa.yml/runs?event=$EV&branch=$RAMA&per_page=100" ...)
  recientes=$(( recientes + n ))
done
echo "corridas_ui=$recientes" >> "$GITHUB_OUTPUT"
```

y **cuatro** pasos posteriores cuelgan de `steps.comprobar.outputs.corridas_ui == '0'`: lanzar la
nocturna, comprobar que nació, componer el aviso y entregarlo.

Con `set -e`, si `gh api` falla —API caída, rate limit, token sin permiso— el paso muere antes del
`echo`, el output queda **vacío**, y `'' == '0'` es `false`. Resultado: **ni se lanza la nocturna
ni sale ningún aviso**, exactamente en el escenario en que no sabemos si hay cobertura.

Es la forma clásica del fallo abierto: una lista vacía **por error** se lee igual que «no hay nada
que hacer». El repo ya tiene el patrón contrario escrito y funcionando al lado — el job `changes`
de `qa.yml` es deny-by-default a propósito («si `changes` peta, su output llega vacío y `''` !=
`'false'`, así que la suite corre igual»).

**Matiz que evita exagerar el ticket:** el paso no lleva `continue-on-error`, así que el job sí
termina en ROJO y el check se ve en la lista de Actions. Lo que no sale es el **aviso**, que es lo
único que llega al móvil. No es silencio total; es un rojo que nadie mira, que en este repo ya se
ha demostrado que es casi lo mismo (el avisador de push encadenó 37 rojos en día y medio).

## Lo que hay que hacer

- [ ] Que la incertidumbre se lea como «no hay cobertura», no como «ya está cubierta»: capturar el
      fallo de `gh api` y salir con `corridas_ui=0` más un motivo, en vez de morir. Lanzar una
      nocturna de más cuesta runner; no lanzarla el día que hacía falta cuesta la cobertura.
- [ ] Distinguir en el aviso «no había corrido» de «no he podido comprobar si corrió»: son dos
      noticias distintas y la segunda apunta a otro sitio.
- [ ] Comprobarlo de verdad, no por inspección: el workflow ya admite `horas` como input **para
      poder ejercitar el camino** — el mismo criterio sirve aquí (un `REPO` inexistente fuerza el
      fallo de `gh api` sin tocar nada más).

---

## Cierre — 2026-10-06

Se cerró al reescribir ese mismo paso (encargo `2026-10-06-ci-full-ui-suite-on-2-1-misses-its-schedule`):

- [x] La incertidumbre ya no es «cubierta»: cada fuente que falla se cuenta como ilegible, el paso no
      muere, y si ninguna responde la decisión es `sin_lectura`, que pasado el plazo **lanza**.
- [x] El aviso distingue «no había corrido» de «no he podido comprobar si corrió», y hay un tercer
      aviso si el vigilante falla antes de decidir (`steps.decidir.outcome == 'failure'`).
- [x] Comprobado en el banco (`qa/scripts/ci-vigilante-nocturna-test.sh`, en el job
      `coverage-index`) con un `gh` falso que devuelve errores, JSON roto y listas vacías — y con un
      mutante que trata una página vacía como lectura válida, que el banco mata. No se forzó contra
      GitHub: `REPO` sale de `github.repository` y no es un input.
