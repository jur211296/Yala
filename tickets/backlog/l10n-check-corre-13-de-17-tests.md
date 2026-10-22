---
id: l10n-check-corre-13-de-17-tests
status: backlog
priority: low
area: qa, l10n
created: 2026-09-12
updated: 2026-10-08
source: lente adversarial de la sesión de la cola del simulador (2026-09-12)
---

# `/l10n-check` dice que corre 15 tests, corre 13 de 17, y no puede darse cuenta

## Lo medido (2026-09-12)

El comando afirma, en su primera línea, que la verdad sobre la localización «vive en
`YalaTests/LocalizationParityTests.swift` (**15 tests**)» y que «este comando **los** corre». Las dos
mitades de la frase son falsas, cada una por su lado:

| | Medido |
|---|---|
| Suites en `LocalizationParityTests.swift` | **tres**, no una: `LocalizationParityTests` (11 `@Test`), `BundleLocaleDriftTests` (1), `StringsdictParityTests` (3) |
| Lo que el comando pide | `-only-testing:YalaTests/LocalizationParityTests` + `…/WidgetLocalizationParityTests` (2) |
| Lo que se ejecuta | **13 de 17** |

Los cuatro que se quedan fuera, en silencio:

- `bundleLocales_matchSupportedLocaleEnum`
- `baseLocalesWithStringsdict_haveSameKeys`
- `pluralRule_pl_hasOneFewManyOther`
- `variants_doNotCreateOwnStringsdict`

Esto es exactamente el mecanismo de `.claude/rules/testing.md` («`-only-testing` filtra por el TIPO,
no por el FICHERO — y varios ficheros de este repo declaran DOS `@Suite`… y no se nota: el conteo
cuadra con las suites PEDIDAS»), aplicado a la batería que decide si una traducción está sana.

**Y el repo ya sabe hacerlo bien en otro sitio**: `qa/prompts/README.md` y los cuatro
`qa/prompts/translate-*.md` listan las tres suites por su nombre.

## Y no puede darse cuenta, que es la otra mitad

El bloque lleva `-quiet` y grepea `(Test Case|Executed|passed|failed|error:)`. El paso 2 del `/gate`
—cuatro líneas de comando más allá— explica por qué eso es un sello de goma: **`-quiet` suprime la
línea `Test run with N tests in M suites`**, que es la única que Swift Testing emite con el conteo, y
los marcadores `Test Suite`/`Test Case` son de XCTest, que este repo no usa. O sea que el modo de
fallo «cero casos con exit 0 y `TEST SUCCEEDED`» es **indetectable** en `/l10n-check`.

## Qué hacer

1. Pedir las tres suites por su nombre (`grep -n "@Suite" <fichero>` para resolverlos, no el nombre
   del fichero), más la del widget.
2. Quitar `-quiet` y verificar el conteo contra `Test run with`, como hace el gate.
3. Corregir el «(15 tests)» de la cabecera por lo que de verdad se corra.

## Relacionados

- [[only-testing-filters-may-be-silently-empty]] — el mecanismo general, ya en backlog desde el
  3-sep. Esto es su instancia medida en la batería de l10n.
- `.claude/rules/testing.md` — la regla del filtro por tipo, y la de `-quiet`

Triage 2026-10-08: abierto · medium → low · `.claude/commands/l10n-check.md` sigue diciendo «(15 tests)», sigue con `-quiet` y solo pide `LocalizationParityTests` y la del widget; el fichero declara tres suites (`LocalizationParityTests.swift:15`, `:264`, `:277`).
