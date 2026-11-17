---
id: 2026-11-17-verificacion-interfaz-de-lo-tocado
status: done
priority: high
area: "qa, xcuitest, ci"
created: 2026-11-17
updated: 2026-11-17
source: "propuesta P2 de la verificación del 17-nov (docs/verificacion/), aprobada por Jürgen: «Apliquemos todo lo recomendado»"
---

# Las pruebas de interfaz de lo tocado las elige un script en el gate local

Hasta hoy el gate elegía a mano qué clases de interfaz correr y el CI del PR no corría ninguna. Del 12 al 16-nov
llegaron 11 pruebas rotas a 2.3 en dos tandas. Ahora un script lee el diff y elige, y el gate lo usa en su paso 3.

**El job del PR que pedía la propuesta P2 NO se hizo: decisión de Jürgen del 17-nov.** El runner macOS se paga por
minuto y no hay presupuesto; con lo medido (abajo) eran ~59 min de macOS por PR con pantallas. El script queda solo
para el gate local, en la Mini o la Max.

## Qué se hizo

- `qa/scripts/interfaz-de-lo-tocado.py`: del diff (contra `origin/2.3` con el árbol de trabajo, o entre dos commits) a
  las clases de `YalaUITests`. Seis señales: la prueba tocada, el miembro de `Support/` tocado, el índice de cobertura
  (los globs que cubren más de un cuarto de la app pesan casi nada), los identificadores que declara lo tocado —con
  peso ×4 los que quedan **debajo** del cambio, que son los que un hueco nuevo empuja—, los textos de `es.lproj` que
  cambian y las vistas anfitrionas (hasta dos saltos). Cada identificador vale `1/n` de las clases que lo usan, con tope
  de 1 por fuente. Orden: puntos por raíz de minutos. Techo por minutos estimados con `qa/ci-ui-tiempos.json`
  (30 por defecto, 40 en el CI); lo de fuera sale nombrado con su motivo. `--arbol-de <commit>` lee el árbol de un
  commit sin extraerlo.
- `qa/scripts/interfaz-de-lo-tocado-test.sh`: 22 casos sintéticos (un repo git de mentira, uno por regla) y el caso real
  del PR de categorías a un toque, que el banco trae con `git fetch --depth=2` si falta y si no puede, falla. Corre en
  `coverage-index`. Mutantes: sin la zona de debajo caen 5 casos (el real incluido); sin la capa de textos, 1;
  contando variables locales como miembros de `Support/`, 4; ordenando sin mirar el coste, 4.
- `/gate` paso 3: usa el script, con guarda para la lista vacía (sin ella `xcodebuild test` correría la suite entera).
- `qa.yml`: solo el banco, en `coverage-index` (ubuntu). Los dos jobs del PR se escribieron y se retiraron antes del
  commit por la decisión de Jürgen.
- Reglas: `ci-qa.md` («La interfaz de lo tocado corre en el gate local, no en el CI del PR», con la decisión) y
  `testing.md` (identificadores literales en las pruebas).

## Medido

Sobre los 214 PRs mergeados a 2.3 del 3 al 17-nov, con el árbol de cada merge (`--arbol-de`):

| Dato | Valor |
|---|---|
| PRs que tocan pantallas (el plan trae clases) | 143 |
| Minutos de interfaz que pide sin techo | mediana ~495, p90 ~665 (casi la suite entera) |
| PRs que llenan el techo de 40 | 137 de 143 |
| macOS por PR con pantallas si hubiera job (techo 40, build ~20) | ~59 min; ~10 h/día |
| Con techo 30 / 20 | ~49 / ~40 min por PR; ~8,4 / ~6,7 h/día |

## Qué devuelve para los rojos de noviembre

Atribución de cada rojo a su PR por el contenido del ticket (`2026-11-14-qa-ui-tandas-rojas`,
`2026-11-16-ui-tests-rojos-tandas`); el puesto es el de la clase rota en el plan sin techo de ese PR.

| Rojo | PR causante (inferido) | Puesto | ¿Dentro con techo 40? (30 es el del gate) |
|---|---|---|---|
| `SplitCalculatorUITests` (16-nov) | categorías a un toque (#920) | 3 | sí |
| `AccountCardPickersUITests` (16-nov) | categorías a un toque (#920) | 16 | sí (el greedy salta la de 27 min) |
| `TransactionFormDecided02UITests` (12-14-nov) | favoritos por tipo (#921) | 27 | no |
| `LargeTextSecondaryScreensUITests` | filas de Ajustes, decisión 48 (#950) | 31 | no: usó una clave nueva, la capa de textos no la ve |
| `StatisticsHeroLikePanelUITests` | «Buscar en Registros» (#917) | 39 | no |
| `PanelQuickActionsLargeTextUITests` | gráfica de saldo del Panel (#902) | 115 | no |
| `FormClarity23UITests` (v3) | gráfica de saldo del Panel (#902) | 65 | no |
| `FormClarity23UITests` (m1) | barra sobre el teclado (#918) | 6 | no (llena antes con clases más baratas) |
| `IPhoneLandscapeUITests` | chips rápidos de Registros (#919) | 30 | no |
| `PersonalToGroupConversionUITests` (16-nov) | no es de #920 (desplazamiento de Registros) | 2 en #920 | sí, por el índice |

Lectura honesta: el script **une** bien lo tocado con las pruebas que pasan por ahí, pero en este repo casi todo PR
toca pantallas por las que pasan cientos de minutos de pruebas, y 40 min solo cubren una parte. Atrapa el caso que lo
motivó; de los siete del 12 al 14-nov, ninguno con el techo actual.

## Qué queda sin red

La interfaz no corre en el PR. Lo que el gate local no corra (por techo o porque el gate se saltó) solo aparece en la
nocturna, ya dentro de 2.3. Volver a proponer un job de interfaz por PR exige un presupuesto de macOS aprobado.

## Huecos conocidos

- Un identificador que llega a la vista por variable se ve en el fichero que escribe el literal, no en el que lo pinta.
- Un texto que cambia de clave (decisión 48) o que vive solo en `L10n.swift` no entra en la capa de textos.
- La señal «debajo del cambio» sigue el orden del fichero dentro del miembro tocado y un nivel arriba; un layout que
  reordena con `ZStack`/`overlay` no lo respeta.
