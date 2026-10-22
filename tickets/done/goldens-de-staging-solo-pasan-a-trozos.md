---
id: goldens-de-staging-solo-pasan-a-trozos
status: done
priority: medium
area: "backend, testing"
created: 2026-09-08
updated: 2026-09-08
source: medido al aplicar las tres migraciones de staging (2026-09-08)
---

# Los 25 goldens de staging daban 15/25 — dos rojos reales y un margen que se estrecha solo

## Resultado

**25/25 verde**, medido dos veces el 2026-09-08 por la tarde: el fichero solo (311 s) y dentro de la
suite entera del gateway (313 s, 331 tests). Los dos rojos que había eran **de aserción**, no de
tiempo, y estaban donde el planteamiento original decía que no había nada que mirar.

## Los dos rojos reales

`bb90564a` (2026-09-07, el tope de gasto del grupo) subió el `canon_version` del manifest de Grupos
de `c1` a `c2` —correctamente, y el commit lo razona: una columna nueva cambia el root de todas las
filas—. Actualizó el manifest y el cliente Swift (`GroupsSyncClient.swift:3029` ya esperaba `"c2"`),
pero **no** los dos `expect(...canon_version).toBe("c1")` de los goldens 6 y 8.

Estuvo 24 h invisible por dos cosas que se suman:

1. **El CI no corre ni un test del gateway** (`ci-no-corre-la-suite-del-gateway`, ya abierto desde el
   4-sep; se le añadió este caso como su primer coste real).
2. **`gateway/group_capability_manifest.json` es una copia generada y está en `.gitignore`.** Sólo se
   refresca en `pretest`, así que quien lanzaba los goldens con `npx vitest` —que es lo natural para
   filtrar por nombre— seguía midiendo con la copia vieja en `c1`, **y el assert pasaba**.

Arreglado: los dos asserts a `c2`, con el racional escrito al lado (el valor va a mano a propósito —
leerlo del manifest lo volvería tautológico, porque es de ahí de donde el server lo sirve). Y la
trampa del manifest stale queda cerrada por `gateway/test/manifest.sync.test.ts`, un test **offline**
que compara la copia con la SSOT de la raíz y, si divergen, dice `corre 'npm run sync:manifest'`.
Verificado con dos mutantes: canon divergente y divergencia que no toca el canon.

## Lo que sí explica los timeouts, medido y no supuesto

Se instrumentó `fetch` para contar y cronometrar cada petición. **Una corrida de los 25 goldens hace
32 793 peticiones HTTP**, y el 99,7 % salen de los cinco tests que hacen un pull completo. La razón:

    coste de un pull = 1 + 5 × (grupos de los que el usuario es miembro)

y ese fan-out ocurre **haya o no algo que traer** — el cursor no decide qué grupos se visitan. Con
`i5-user-b` en 678 grupos, un solo pull son **3 391 peticiones**. La aritmética se verificó por
predicción antes de medirla: para el golden 7 se predijeron ~156 s y dieron 130 s.

**La latencia no degrada ni se satura**: mediana 199-253 ms y p95 241-305 ms, planas de principio a
fin de la corrida, con hasta 30 peticiones en vuelo. Lo que cuesta es el número de viajes.

De ahí salen los dos tickets hijos: `groups-pull-cuesta-cinco-viajes-por-grupo` (el coste, que en
producción choca con el cap de subrequests de Workers) y
`corpus-de-test-de-staging-crece-sin-limite` (el corpus, con la decisión del owner).

## Lo que NO se pudo reproducir, dicho como es

**Los 10 timeouts de la mañana no se reproducen.** Ni el fichero solo ni la suite entera dieron uno.
Sin ellos delante no se puede nombrar su causa, así que lo que queda es el margen —que sí está
medido— y dos candidatas que no se pueden separar a posteriori:

- **La latencia del día.** El golden más ajustado consume el 55 % de su timeout, así que basta con
  que el tiempo se multiplique por 1,8 para que caiga. La medición de latencia que se hizo por la
  mañana (~130 ms) fue en **serie**, con `curl`; el régimen que importa es el del fan-out con 30
  conexiones abiertas, que no se midió.
- **Otra corrida solapada.** La corrida 1 tenía 5 procesos `vitest` a la vez; se dieron por muertos
  para la corrida 2, pero eso no cubre una sesión distinta atacando los mismos dos usuarios.

Se comprobó y se descarta una tercera: **el paralelismo entre ficheros no degrada nada.** Los cuatro
ficheros que hablan con staging corren a la vez en `npm test` y los goldens de Grupos tardaron
313 s, contra 311 s corriendo solos. Los otros tres terminan en los primeros 35 s.

## Correcciones al planteamiento original

Se dejan escritas porque tres de ellas dirigieron el trabajo hacia el sitio equivocado:

- **«Cero aserciones fallidas — ni una en ninguna corrida»**: falso para la corrida 3. Al sincronizar
  el manifest a `c2` aparecieron precisamente los dos fallos de aserción de arriba. Se leyeron como
  «ligeramente peor» y eran la respuesta.
- **«`jwtA` tiene 677 grupos, `jwtB` 511»**: al revés y con otros números. Medido contra la misma
  query que usa el pull: **A = 530, B = 678**. Importa porque la hipótesis apuntaba al usuario A y
  el test que más sufre (`G2 · 2`) pullea al B.
- **«El sospechoso es el corpus»**: el mecanismo es correcto, pero el propio ticket traía el dato que
  lo refutaba como causa de los 10 fallos — cinco de esos tests **no hacen ningún pull** y hoy tardan
  entre 1,4 y 4,1 s.
- **«~69 s por test de media, un factor 70x»**: era el promedio de repartir 1 706 s entre 25 tests,
  no un tiempo por test. Los tests no se parecen entre sí: hoy van de 0,0 s a 130 s.

## Lo que queda, y dónde

- `groups-pull-cuesta-cinco-viajes-por-grupo` — el coste O(grupos) del pull, y el cap de subrequests
  de Workers que rompe en producción a partir de ~200 grupos. Residual documentado desde julio.
- `corpus-de-test-de-staging-crece-sin-limite` — **decisión del owner**: limpiar es destructivo. Con
  el ritmo actual (+15 grupos a B por corrida) el golden más ajustado cae en ~35 corridas.
- `ci-no-corre-la-suite-del-gateway` — ya existía; se le añadió este caso como su primer coste real.

## Acceptance Criteria

- [x] Medido dónde se va el tiempo (round-trips y latencia por petición), no supuesto.
- [x] La suite entera da verde — 25/25, dos veces.
- [x] Si la causa es el corpus acumulado, decisión del owner sobre limpiarlo → el corpus no era la
      causa de los rojos, pero sí es la fragilidad: la decisión vive en
      `corpus-de-test-de-staging-crece-sin-limite` con los cuatro caminos y su coste.
