---
id: 2026-11-17-verificacion-checklist-curada
status: done
priority: medium
area: "qa, verificacion"
created: 2026-11-17
updated: 2026-11-17
source: "propuesta de verificación del 17-nov (P4, primera parte: curar la checklist), aprobada por Jürgen"
---

# Las lecciones caras vivían en reglas de prosa que nadie elige por diff

`swiftdata-cloudkit.md` tiene 2.097 líneas y 263 entradas, y `testing.md` tiene 305 líneas. Se cargan enteras según la
ruta, y ninguna dice qué comprobar cuando un diff concreto toca algo caro. El PR de categorías a un toque rompió cuatro
pruebas de interfaz el 16-nov. Su gate corrió seis clases y ninguna era de las que rompió.

## Hecho cuando

- Existe `qa/checklist-confiabilidad.yaml` con 30 a 40 ítems, y cada uno trae cinco campos: disparador visible en un
  diff, comprobación concreta, al menos dos incidentes o PRs de origen, regla de la que sale y `ultimo_disparo` vacío.
- Un banco valida la forma y que todo lo nombrado existe.
- Un revisor adversarial refutó la lista antes de cerrar.
- El mapa regla → ítem queda escrito, y las reglas no se tocan.

## Resolución

- **Checklist:** `qa/checklist-confiabilidad.yaml`, con 30 ítems: nube 9, dinero 9, migración 4, pruebas 4, fechas 2 y
  formulario 2. La cabecera explica el contrato del disparador y el criterio de entrada.
- **Banco:** `qa/scripts/checklist-confiabilidad-test.sh`. Tiene 29 casos de mentira y cada caso que cae exige su
  mensaje de error.
  - Valida el fichero real contra el árbol: globs, símbolos, pruebas (por tipo o por fichero), líneas de regla y
    tickets.
  - Lee el YAML con PyYAML si lo hay y, si no, con el YAML de la librería estándar de Ruby.
- **Documento:** `docs/verificacion/checklist-confiabilidad.md`, con la medición, lo que cambió la refutación, el mapa
  regla → ítem y qué queda en observar.
- **Proceso:**
  - Cuatro lectores extrajeron 46 candidatos de las reglas de nube, pruebas, divisas, saldo y formulario y de los
    tickets de rojos del 14 y el 16-nov. La curación los dejó en 40.
  - El revisor adversarial abrió en git los orígenes de los 40 y propuso tumbar 18. Tras verificar sus hechos quedaron
    30: se cayeron 12, dos parejas se fusionaron y entraron 4 ítems nuevos (frontera de persona, dos del puente de
    Grupos y uno de widgets).

## Medición

Se midió sobre `origin/2.3` en `9f0e7d8e1`.

- Los 30 disparadores se encienden en el diff de al menos uno de sus orígenes: 82 de 87 orígenes.
- Sobre los 215 PRs mergeados a 2.3 desde el 3-nov:
  - 113 no reciben ningún ítem, 90 reciben de 1 a 3, 12 reciben de 4 a 10 y el máximo es 6.
  - El PR de categorías a un toque habría recibido el ítem que manda correr las dos clases que rompió.

## Fuera de alcance

- El script selector y el revisor en el gate, que son la segunda parte de P4.
- Enganchar el banco al job `coverage-index`, porque toca `.github/workflows/qa.yml`.
- Podar las reglas, que es trabajo de P5.
