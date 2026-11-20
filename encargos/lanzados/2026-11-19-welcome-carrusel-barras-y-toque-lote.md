Yala
# Welcome: barras del carrusel como historias y toque para avanzar, más dos arreglos chicos del Welcome
---
toca: Yala/App/Views/Onboarding/,Yala/App/Logic/WelcomeShowcaseLogic.swift,YalaTests/WelcomeCarruselBarrasYToque/,tickets/backlog/2026-11-19-welcome-carrusel-barras-y-toque.md,tickets/done/2026-11-19-welcome-carrusel-barras-y-toque.md,tickets/backlog/welcome-destructive-buttons-are-plain-text-taps.md,tickets/done/welcome-destructive-buttons-are-plain-text-taps.md,tickets/backlog/welcome-fresh-start-failed-copy-says-data-is-still-here-after-partial-wipe.md,tickets/done/welcome-fresh-start-failed-copy-says-data-is-still-here-after-partial-wipe.md,docs/TICKETS.md
esfuerzo: medium
cierre: cierra-sola
depende:
---

Rama base: 2.3. Lote chico del Welcome, en un solo PR y un solo cierre.

## 1. Principal: barras del carrusel y toque para avanzar
Jürgen, 19-nov 21:21, en la build 2.3 (5): en el carrusel del Welcome (el principal y el de Grupos, «Cuentas claras con tus amigos»), al deslizar a la segunda tarjeta, las dos barras de progreso siguen avanzando a la vez. Captura en la Mini: `~/Claude/flota/borradores/welcome-carrusel/grupos-dos-barras-avanzan.png` (si corres en la Max, cópiala con `scp`). Archivos: `Yala/App/Logic/WelcomeShowcaseLogic.swift`, `Yala/App/Views/Onboarding/WelcomeShowcaseView.swift`, `WelcomeShowcaseDemoView.swift`.
- Las barras se comportan como historias: las anteriores quedan llenas, la actual avanza y las siguientes quedan vacías. Esto vale al deslizar adelante o atrás, al avanzar solo y con pausa.
- Tocar la mitad derecha de la caja pasa a la siguiente tarjeta. Recomendado: tocar la mitad izquierda vuelve a la anterior, como en historias; si choca con algo, decídelo y anótalo. El botón de pausa sigue funcionando y no dispara el toque.
- En los dos carruseles. Cuida VoiceOver (acciones para siguiente y anterior) y respeta Reducir movimiento.
- Test en `YalaTests/WelcomeCarruselBarrasYToque/`. Ticket nuevo `tickets/backlog/2026-11-19-welcome-carrusel-barras-y-toque.md`, que pasa a done al cerrar. Card del tablero: «Welcome: al deslizar a la siguiente tarjeta la anterior no queda llena, y tocar la mitad derecha no avanza».

## 2–3. Tickets ya en backlog (léelos enteros y verifica en 2.3 si siguen vigentes; si ya están resueltos, ciérralos con la evidencia)
- `welcome-destructive-buttons-are-plain-text-taps.md`
- `welcome-fresh-start-failed-copy-says-data-is-still-here-after-partial-wipe.md`

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Si necesitas tocar un archivo fuera de `toca:`, anótalo en «Decidido sin consultar» y mantenlo mínimo.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude con video o capturas del antes y después, nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.
