---
id: 2026-11-16-ui-tests-rojos-tandas
status: done
priority: high
area: "testing, qa"
created: 2026-11-16
updated: 2026-11-17
source: "nocturna del CI del 16-nov (run 43929672868): tandas 1, 8 y 9 en rojo en los tres intentos"
---

# Las tres pruebas de UI en rojo de la nocturna del 16-nov

Las tres eran **pruebas desactualizadas**, no bugs de la app: la interfaz cambió y la prueba tocaba donde ya no estaba lo
que buscaba. Ninguna se borró ni se marcó como fallo esperado; cada una prueba lo mismo que antes.

Cuándo empezaron: verdes en la nocturna del 15-nov (`11b1ea364`) y rojas 3/3 en la del 16-nov (`984cbb86e`). Entre las
dos entraron ~20 merges a `2.3`; el causante se identificó por lo que muestra el vídeo del fallo.

## Tanda 8 · `SplitCalculatorUITests` (los dos casos, línea 43)

- **Causa:** la fila de categorías a un toque bajo el importe (PR de «Nuevo registro: categorías a un toque y un buscador
  que entiende «café»», decisión 21 de 2.3) baja las acciones del formulario. Con el teclado numérico abierto, «Mi parte»
  queda **debajo del teclado**: XCUITest la encuentra (existe) pero el toque cae en el teclado y la calculadora no se
  abre. Visto en el vídeo del `.xcresult` local; reproducido 2/2 en el iPhone 17 Pro con iOS 27.2.
- **Arreglo:** la prueba cierra el teclado tocando la pregunta del monto antes de tocar «Mi parte» (molde de
  `TransactionFormDecided02UITests.dismissKeyboard`). Absorbe `split-calculator-uitests-sheet-does-not-mount`, que
  sospechaba del reposo de «Nuevo registro»: no era eso.
- **Producto:** sin cambio. Quien usa la app cierra el teclado o desplaza; el botón no es inalcanzable.

## Tanda 9 · `AccountCardPickersUITests.test_selector_fromTheUSDLine_choosingTheCardGoesBackToThePrincipal` (línea 92)

- **Causa:** al elegir la pastilla de dólares sale la fila «Tipo de cambio de hoy», que con la fila de categorías a un
  toque empuja la pastilla de cuenta hasta **debajo de la barra de «Guardar»**; el toque directo caía en la barra y el
  selector no se abría. Reproducido en local (1/1) y visto en el vídeo. El rojo de la línea 88 en un intento del CI es la
  misma familia (toque tras un cambio de layout).
- **Arreglo:** la prueba reabre el selector con `openSelectorFirstRow`, que ya desplaza la pastilla a la vista si la
  barra la tapa.

## Tanda 1 · `PersonalToGroupConversionUITests.test_convertingTheBus_toAGroup` (línea 129)

- **Causa (inferida, no reproducida en local):** en el CI (iOS 27.0) el «Bus» de hoy queda más abajo en Registros y la
  prueba desplaza para alcanzarlo. Tras pasarlo al grupo, la lista conserva el desplazamiento; el ayudante solo
  desplazaba hacia abajo, así que alejaba el «Bus» de hoy, la lista perezosa lo soltaba y `firstMatch` pasaba a otro
  «Bus» más viejo, que no es del grupo. En el log del CI se ven los 4 desplazamientos de la segunda apertura; en local
  (iOS 27.2; la Mini no tiene el runtime 27.0) el «Bus» está a la vista y pasa, también con la hora corrida a la tarde
  (`TEST_RUNNER_TZ=Etc/GMT-6`), así que no es la hora.
- **Arreglo:** antes de reabrir, la lista vuelve arriba, y el ayudante desplaza hacia arriba o hacia abajo según dónde
  esté el «Bus». Lo confirma la nocturna sobre 2.3.

## Verificación

- Local, iPhone 17 Pro, iOS 27.2, scheme Yala Dev: las tres clases en verde (los dos casos de la calculadora, el de
  dólares y los dos de conversión), con la hora real y con la hora corrida a la tarde.

## Suma del 17-nov · `IPhoneLandscapeUITests.test_shortHeight_recordsHeaderLeavesTheFirstRowInView`

Llevaba un `XCTExpectFailure` desde el 14-nov a la espera de decidir qué hacer con los chips rápidos de Registros con el
iPhone girado. Jürgen eligió la opción B (17-nov, 06:07): los chips se quedan y en horizontal la primera fila puede empezar
bajo la barra de pestañas; se llega deslizando. El caso afirma eso: con la misma fila de antes de girar, unos arrastres
cortos la dejan entera por encima de la barra y se puede tocar. Sin `XCTExpectFailure` ni el salto del iPhone SE (la
decisión vale para todos). Local, iPhone 17 Pro: verde, y el log muestra que la fila empezaba bajo la barra y bastó un
arrastre. Ya no queda ningún `XCTExpectFailure` en `YalaUITests`.

## Suma del 17-nov (tarde) · `TransactionsCrudUITests.test_recordSelectorsOpenAtMediumDetent`

Salió rojo 3/3 en la batería de UI sobre 2.3 de esta sesión (tanda 5) y se reprodujo en local. El selector sí se cerraba:
la prueba elegía «Ahorros USD» (la primera fila), salía el tipo de cambio y la pastilla de cuenta bajaba bajo la barra de
«Guardar», así que «la pastilla es tocable» daba falso. Misma familia que el caso de dólares de la tanda 9. Ahora se
comprueba que la fila del selector desapareció; la pastilla siguiente la desplaza a la vista `openSelectorFirstRow`.
Local: la clase entera en verde (3/3).

## Cómo evitar que se repita

El PR de categorías a un toque cambió la altura del formulario de «Nuevo registro» y su gate solo corrió las pruebas de
su área (`CategoryQuickPick23UITests`). Un cambio de **layout** de «Nuevo registro» tiene que correr en su gate todas las
clases que tocan algo bajo el importe tras escribir: `SplitCalculatorUITests`, `AccountCardPickersUITests`,
`TransactionFormDecided02UITests` y `EdgeCasesUITests` como mínimo.
