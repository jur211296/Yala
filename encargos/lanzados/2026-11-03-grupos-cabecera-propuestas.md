# Grupos: rediseñar la parte de arriba con lo que debes, lo que te deben y el neto en tu moneda, a partir de propuestas que elige Jürgen

Base: origin/2.2 en jur211296/Yala. Una sola sesión a la vez.

## Qué pidió Jürgen (2026-11-03)
- De los botones «Nuevo gasto» y «Nuevo grupo» hacia abajo todo está bien. No se toca.
- La parte de arriba de la pestaña Grupos no le convence: los textos Debes y Te deben, y el banner morado con el neto. La quiere más dinámica y MUY CLARA en tres datos: cuánto debes, cuánto te deben y el neto de deuda en tu moneda principal, sumando todo Yala.
- Una gráfica podría servir, y quiere propuestas.
- Si al final se mantiene el banner con el texto, que sea Liquid Glass sin tint, como los chips glass del Panel.
- Capturas: `~/Claude/tmp-frank/adjuntos/grupos-arriba-actual.png` es la pantalla actual. `~/Claude/tmp-frank/adjuntos/grupos-arriba-referencia.jpg` es solo una idea de lo que busca (anillos con lo que vuelve y lo que pagas); no es para copiarla tal cual.
- Respeta el README de marca: nada de degradados ni glows.

## Cómo trabajar
1. Prepara de 3 a 4 propuestas distintas: por ejemplo, anillo o donut con el neto al centro, barra comparativa, números grandes con chips glass, o un mini gráfico de evolución. Haz cada una en claro y en oscuro, y saca capturas reales del simulador.
2. Antes de implementar, pregúntale a Jürgen con AskUserQuestion cuál quiere, adjuntando las capturas. Esta es una decisión de diseño de Jürgen: espera su respuesta.
3. Implementa solo la propuesta que elija, con tests y video en el PR.

## Cierre
Esta sesión NO cierra sola antes de que Jürgen elija. Después de que elija y quede implementado, termina con /cerrar-total.

## Paso 0 — decisiones (resueltas en autónomo; la de diseño la toma Jürgen)

1. **Cómo se enseñan las propuestas:** vistas SwiftUI reales dentro de la app, solo en DEBUG y tras
   `-groupsHeaderVariant N`, con datos fijos (`-groupsHeaderMock`: debes S/ 11,913.52, te deben $ 2,995.65). Así se
   ven con el fondo, la barra y el tema de verdad. Se capturan con un XCUITest conductor en Claro (tema 1) y en su tema
   Liquid Glass oscuro (tema 8). Ese fichero provisional se borra al implementar la elegida.
2. **Las cuatro:** (1) anillo con el neto al centro; (2) neto grande + barra comparativa; (3) neto grande + chips de
   cristal como los del Panel; (4) dos tarjetas de cristal + neto en cristal SIN tinte (la salida «si se mantiene el banner»).
3. **Proporciones del anillo y la barra:** cada lado convertido a la moneda principal con la misma lógica del neto
   (`GroupsListBalanceLogic.net`). Sin degradados ni brillos: rellenos sólidos con los tokens de deuda de la lista.
4. **Yala gratis (solo grupos):** no hay moneda principal ni neto. Asumido: la variante elegida cae a «Debes / Te deben»
   sin neto; se decide el detalle al implementar.
5. **Fuera de alcance:** de «Nuevo gasto / Nuevo grupo» hacia abajo no se toca.
6. **Decisión de Jürgen:** cuál de las cuatro (AskUserQuestion con las capturas delante). Hasta entonces no se implementa.

### Decidido por Jürgen (2026-11-03)
- **Propuesta 2** (neto grande + barra), tras verla en 7 escenarios junto a la 3.
- **Tope de 3 líneas por lado**: con 4+ divisas, las 2 mayores (en la moneda principal) y «y N más».
- **Paleta B**: «Debes» en el rosa de marca (#C80066 claro / #FF4DA6 oscuro), «Te deben» en verde. Cambia también las
  filas de las tarjetas y el widget de Grupos (paridad fijada por test).
