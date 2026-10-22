---
name: el-predicado-del-ticket-no-es-el-criterio
description: Cuando un ticket nombra el predicado exacto del arreglo, mide qué predicado usa de verdad la superficie que estás arreglando — si divergen, el arreglo deja el bug vivo para una parte de la gente
metadata:
  type: feedback
---

**Un ticket que te da el predicado escrito (`X.shared.hasY`) te está dando la INTENCIÓN, no el criterio.
Antes de cablearlo, mide con qué predicado decide la superficie que quieres desbloquear.**

**Why:** el 2026-09-11, el ticket del kill-switch pedía abrir la fila de Ajustes «si hay una cuenta de
grupos asociada (`GroupsAccountAssociation.shared.hasAssociation`)». Lo cableé literal y pasó el gate.
Dos lentes adversariales independientes cazaron la misma celda: la sección que hay detrás ofrece el botón
«Desasociar» por **otro** predicado —en sesión privada le basta una sesión viva, sin mirar el registro—,
así que con el literal del ticket toda esa población seguía sin puerta. **El arreglo habría dejado vivo
el bug que arreglaba**, y en verde. La otra mitad de la divergencia era simétrica: el registro viaja por
el iCloud-KV del Apple ID, así que abría la fila en dispositivos donde la sección no aplica — una puerta
a una pantalla vacía.

**How to apply:**

1. **Enuncia el criterio en lenguaje de producto** («hay algo que soltar detrás de esta puerta»), no en
   nombres de propiedades. Casi siempre existe ya una función que lo contesta: la que decide si el botón
   se dibuja. Pásale ESA.
2. **Si la puerta y el contenido leen por separado, júntalos en una lectura.** No basta con copiar la
   derivación al call-site nuevo: eso crea la tercera copia y el mismo bug dentro de dos meses. Un
   resolver con los dos consumidores + un source-scan que prohíba derivarlo por tu cuenta.
3. **La divergencia se busca activamente**: lista los ejes que mira el gate y los que mira el contenido,
   en dos columnas. Las celdas donde solo una columna dice «sí» son los bugs.

Apartarse del literal del ticket **no** es ampliar el alcance: es el mismo objeto, medido. Se escribe en
el Paso 0 y en el PR, con el escenario que lo justifica. Ver [[feedback_alcance_minimo_salvo_incoherencia]]
y [[feedback_la_premisa_del_encargo_tambien_se_mide]].
