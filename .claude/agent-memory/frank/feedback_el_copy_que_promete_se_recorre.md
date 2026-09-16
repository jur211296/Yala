---
name: el-copy-que-promete-se-recorre
description: Un copy que manda a un sitio («en Perfil puedes exportar tus datos») es una promesa verificable — recorre el camino ENTERO hasta el gate de plan antes de escribirlo, o descubres un paywall en el peor momento
metadata:
  type: feedback
---

**Cuando un copy ofrece una acción, recorre el camino hasta el final antes de escribirlo: que la
pantalla exista no basta — mira también el gate de plan.**

**Why.** El 15-sep, el aviso del attest personal decía «…y en Perfil puedes exportar tus datos».
Medí que la fila de exportar existe y que no está deshabilitada, y me quedé ahí. **El candado estaba
un nivel más adentro**: `DetailPeriod.isProExportPeriod` marca `.allTime`, `.thisYear`, `.lastYear` y
`.custom` como Pro, y el `onAppear` del wizard **rebaja** la selección de quien no lo es a
`.last30Days`. Como el Modo Nube es gratis para siempre por decisión escrita, la población que ve ese
aviso incluye no-Pros: el copy les descubría un paywall **justo al enterarse de que sus movimientos
no están subiendo**.

Y el remate: la exportación completa y **gratis** ya existía —`exportAllTransactionsBeforeLosingThem`,
sin asistente ni límite de plan, construida el mismo día para esta misma avería— y solo se alcanza
intentando cerrar sesión. O sea que el copy nombraba el camino de pago y dejaba mudo el bueno.

**How to apply.**

- **La prueba es: «¿qué ve exactamente quien siga esta frase, con el plan más pobre?»** No «¿existe
  la pantalla?». Un `isXEnabled` en la fila no dice nada del gate que hay dentro.
- **Busca si la acción que quieres ofrecer ya existe sin candado en otro sitio.** Aquí la había, y la
  diferencia entre las dos no se ve desde el ticket: una es el wizard y otra un one-shot de rescate.
- **Y pregunta si la acción corresponde a ESE momento.** La salida fue quitar la cláusula, no arreglarla:
  el aviso describe un estado —los datos están en el teléfono, no se pierden por esto— y la exportación
  ya se ofrece donde de verdad se pierden, que es el cierre de sesión. Ofrecerla en un aviso fijo añade
  urgencia que no existe. **Que el ticket nombre una salida no obliga a ponerla en el sitio equivocado.**
- Lo cazó una lente adversarial con la consigna de «verifica que la acción que promete el copy es
  alcanzable y gratis». Esa consigna merece estar en toda review que toque copy accionable.

Relacionado: [[feedback_el_predicado_del_ticket_no_es_el_criterio]] — misma familia: el ticket nombra
algo y la medición dice qué significa de verdad.
