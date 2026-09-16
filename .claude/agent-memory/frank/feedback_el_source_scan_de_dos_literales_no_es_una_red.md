---
name: el-source-scan-de-dos-literales-no-es-una-red
description: Cuando un test de fuente es la ÚNICA red posible (código en un target inalcanzable), grepear dos literales no basta: hay que fijar el cuerpo entero normalizado, paso a paso y con el orden.
metadata:
  type: feedback
---

Si un source-scan sustituye a un test de comportamiento **porque el código está en un target que la
suite no compila**, el scan tiene que fijar el **algoritmo entero**, no dos constantes.

**Why:** el 9-sep repliqué `ApproximateMarkThreshold` en el target del widget (no se puede importar:
solo tres ficheros de `Yala/` están en su membership exception) y escribí una «paridad» que grepeaba
`let fraction = 0.05` y comparaba el original contra **una tercera copia escrita en el propio test**.
La review adversarial lo tumbó: invertir los dos guards, cambiar `>=` por `>` o quitar la tolerancia
relativa dejaba las dos suites en verde. El docblock del test prometía «compara las dos
implementaciones» y no comparaba la del widget con nada. Verificado con el mutante: guards
invertidos → verde antes, rojo después de reescribirlo.

**How to apply:** normaliza el cuerpo (líneas trimmeadas, sin comentarios, unidas por espacio) y
afirma **cada paso literal en una lista**, más el ORDEN de lo que sea sensible al orden (`#require`
de los dos rangos y compara `lowerBound`). Y comprueba si la suite alcanza el target antes de
escribir «lo fija X»: `project.pbxproj` → `fileSystemSynchronizedGroups`. Es la familia de
[[mi-docblock-tambien-es-una-premisa]], aplicada a la cobertura entre targets.

**Tres hermanos del mismo día, y los tres pasaban en verde:**

- **La pasarela que nadie vigila.** Un componente intermedio (`WidgetKPI`, `PanelSmallBarRow`) que
  solo reenvía un parámetro: todos los tests miran los CALLSITES, aguas arriba, y borrar la línea de
  reenvío apaga la feature aguas abajo sin un rojo. Si un cambio pasa por un cuello de botella, ese
  fichero necesita su propia aserción.
- **El `contains` suelto no caza un SWAP.** Afirmar que el scope contiene `incomeAmountsAreApproximate`
  y `expenseAmountsAreApproximate` pasa con los dos casos del `switch` intercambiados. Fija el
  emparejamiento entero (`case .income: return summary.income…`), no la presencia.
- **El escenario que no recorre la rama que dice.** Mi caso del «régimen cerrado» tenía la
  transacción fuera del intervalo, así que salía por «sin datos» — otra rama que devuelve el mismo
  literal. Añade el control del escenario (`#expect(cerrado.hasDataInPeriod)`) o el test se sostiene
  por casualidad.

**Y un detalle que este repo ya había resuelto y yo no reusé:** los scans que CUENTAN ocurrencias
deben filtrar comentarios (`codeOnly`, en `WidgetSessionSealTests`). Sin él, documentar el invariante
que el test cuenta lo pone en rojo sin que producción cambie — la forma más tonta de que una red deje
de usarse.

**El reverso, medido el 10-sep: un cambio de SOLO COMENTARIOS puede tumbar un source-scan.** Si el
scan no filtra comentarios, tu docblock nuevo entra en lo que cuenta. Así que cuando edites
comentarios de un fichero de `Yala/`, la pregunta no es «¿compila?» sino **«¿quién lee este fichero
del disco?»**:

    grep -rln '<Fichero>.swift' YalaTests/ YalaUITests/

Ese día salieron **siete suites-fichero** que ningún mapeo por convención (`<Clase>Tests.swift`)
habría encontrado —`WelcomeHeroReentryTests`, `WelcomeSecondaryNoticeTests`,
`BornCloudSignUpFlowTests`, `GroupsOrganizerBranchTests`, `WelcomeNewChooserOrderTests`,
`GroupCreateRoutingLogicTests`, `OnboardingGroupsPurposeGateLogicTests`— con 17 suites y 91 tests
detrás. Salieron verdes, pero el gate no lo sabía: nadie las había corrido.

**Y al revés, medido el 11-sep: tu literal lo lee el escáner de OTRO test.** Un source-scan nuevo buscaba
el texto `"try DataWipeService.wipeAllUserData("` dentro de `UserDataResetView`, y `SharedStateIsolationTests`
—que busca `wipeAllUserData(` en el código de los tests para exigir un trait— contó mi STRING como una
llamada y tumbó la suite. Los escáneres del repo filtran comentarios, no literales. ⇒ al escribir el
marcador de un scan, quítale lo que otro escáner caza (aquí bastó el paréntesis) y deja escrito por qué.

**Reincidí el 16-sep con una variante que no parece un literal suelto: el `contains` del ARGUMENTO sin su coma final.**
El scan del gate del Welcome buscaba `"isAttestSupported: UITestHooks.fakeAttestSupport || AppAttestClient.canObtainSessionToken"`.
Cualquier término pegado detrás —`… canObtainSessionToken && SwiftDataConfiguration.isUITesting,`— lo cumplía, y ese
mutante dejaba **a todo iPhone sin la nube con la suite entera en verde**: en el host de test la capacidad vale `false`,
así que ni la tabla ni los XCUITest podían verlo. Lo cazó una lente adversarial, no yo. ⇒ **cuando el lado bueno de un
término es inalcanzable en el host de test, el scan es la única red y va con igualdad del cuerpo entero normalizado; y lo
que dependa del orden, con `hasPrefix`.** Verificado con el mutante antes y después.

**Y la tercera forma, horas después y en el ticket hermano: medir POSICIÓN no prueba que la puerta sea la ÚNICA condición.**
Mis scans exigían que cada `switchToSignUp(` cayera dentro de `if WelcomeNewOptionsGate.offersCloudSignUp {`, y maté 10
mutantes: quitar, invertir, ampliar, mover la puerta al closure… Todos los que se me ocurrieron **abrían** la puerta. La
lente pensó en **restringirla** —un `if` exterior o interior, un `#if DEBUG` alrededor— y los tres dejaban a un iPhone con
App Attest sin «Crear mi cuenta» con la suite en verde: el fallo caro, otra vez. ⇒ **el catálogo de mutantes de una
puerta incluye cerrarla de más**, y la red que lo cubre es la de siempre: el cuerpo entero de la pantalla, normalizado y
buscado sobre el código sin comentarios (un docblock que cite el cuerpo bueno tapa uno malo).

**Y la cuarta forma, el mismo 16-sep en Ajustes: el `contains` encuentra lo bueno, no lo que SOBRA.** Mis scans fijaban
el término entero y el `case .idle` entero, y aun así la lente de tests encontró dos cierres de más en verde: una segunda
lectura de la capacidad (`isDisabled: … || AppAttestClient.canObtainSessionToken`) y una copia de la declaración bajo
`#if DEBUG … #else`, que satisface el `contains` con la copia de Debug —la que compilan los tests—. ⇒ **contar lecturas y
declaraciones (`== 1`)**, además de fijar la buena. Verificado con 13 mutantes, cada uno rojo solo en su test.
