---
name: el-otro-control-va-al-mismo-sitio
description: Al darle un efecto durable a un botón, cuenta los OTROS controles de esa pantalla que salen al mismo destino; el chevron de la barra es el que se olvida
metadata:
  type: feedback
---

Cuando le añadas a un botón un efecto durable —retirar un arm, escribir un testigo, limpiar una key—,
**enumera los demás controles que salen de esa pantalla al mismo destino** y decide si tienen que hacer
lo mismo. Dos controles con el mismo destino y efectos distintos es como un estado sobrevive a una salida
deliberada.

**Why:** el 14-sep escribí `returnWithoutClaimingAWipe()` = retirar el arm + `onBack()`, con un docblock
que argumentaba que **no** retirarlo deja que el arranque siguiente reanude un borrado a ciegas con scope
`.handover`. A dos centímetros, el chevron de la barra (`welcomeBackButton` → `leaveGate`) hacía el mismo
`onBack()` **sin retirar nada**: su condición estaba escrita para cuando la única salida de esas fases
era la que sí limpiaba. El propio docblock nuevo describía el daño y dejaba el botón que lo causa al
lado. Lo cazaron dos lentes independientes; ninguna lectura mía lo vio.

**How to apply:** en SwiftUI los candidatos son pocos y siempre los mismos — el chevron o `welcomeBackButton`
de la barra, el swipe-to-dismiss (`interactiveDismissDisabled`), el `onDismiss` del contenedor, y el botón
de la fase de error. Grepea el `onBack`/`onCancel` de la vista y mira **cuántos** call-sites tiene. Si el
efecto es correcto para uno, casi siempre lo es para todos los que salen igual — y si no, el que difiere
necesita su frase explicando por qué.

Vecina de [[feedback_el_guard_va_dentro_del_escritor]]: ahí el remedio era meter el guard en el embudo;
aquí el embudo no existe porque los dos controles son de capas distintas (la barra y el contenido), así
que lo que hay es un predicado compartido — y su test.
