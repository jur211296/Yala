---
name: el-guard-va-dentro-del-escritor
description: Un guard repetido en varios call-sites de vistas SwiftUI solo se puede probar con un source-scan de un literal, y ese scan no distingue un guard invertido de uno correcto. Súbelo al escritor y gana tabla.
metadata:
  type: feedback
---

Si el mismo guard (`if !SecondarySessionStore.isActive()`, `if !isUITesting`, …) se repite en tres
call-sites y dos de ellos son vistas SwiftUI, **su única red posible es un `contains` de fichero — y ese
scan no ve la diferencia entre el guard puesto, borrado o invertido**, porque el literal de la llamada no
cambia. Súbelo DENTRO del escritor, con la condición como parámetro (`…IfPrimary(defaults:isSecondary:)`),
y pasa a tener tabla.

**Why:** el 2026-09-10 puse el guard de sesión secundaria en tres sitios a mano. Una lente midió que
borrarlo de dos de ellos —o invertirlo— dejaba las cuatro suites en verde, con el daño saliendo a
producción: desarmar en secundaria le devuelve el espejo de iCloud al dueño del teléfono desde la sesión
de otra persona. Y a mí se me había olvidado ponerlo en un cuarto sitio, cosa que ningún test podía
delatar. Al moverlo al escritor, dos tests de tabla cubren los cuatro call-sites y el mutante invertido
cae.

**How to apply:**

- La pregunta que decide: **¿puedo escribir un test que distinga el guard invertido del correcto?** Si la
  respuesta es «solo con un grep», el guard está en el sitio equivocado.
- El molde ya existe en el repo: `GroupsOrganizerOnboarding.writePreferences` recibe `isSecondarySession`
  por parámetro exactamente por esto.
- El source-scan **sigue haciendo falta** para el cableado (que el call-site llame a la variante con
  guard y no a la de abajo), pero deja de ser la única red. Ancla el scan al nombre de la función, no a
  los paréntesis: `armX(` deja de casar en cuanto añades un parámetro.
- Corolario que me mordió el mismo día: **al renombrar la función, los scans que la nombraban se caen** —
  y eso es la red funcionando, no un estorbo.

Relacionado: [[el-source-scan-de-dos-literales-no-es-una-red]], [[la-asercion-que-no-puede-fallar]].
