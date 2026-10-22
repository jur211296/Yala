---
name: bloque-identidad-nube-rutea
description: Paso 3 del rediseño de sesiones — todo sign-in en la nube ya descubre el tipo de cuenta y rutea. El Worker NO está desplegado con `kind`, así que tres de los cuatro device-QA no se pueden distinguir hasta que Jürgen lo despliegue.
metadata:
  type: project
---

El **bloque [I]** del ADR 2026-09-09 §7: toda puerta de sesión en la nube pregunta al backend qué hay
detrás de la cuenta y rutea con una tabla pura de 15 celdas. Cerró los dos daños del ticket —«Ya tengo
cuenta» adoptaba a quien solo tenía grupos, y «Vengo por un grupo» trataba como solo-grupos a quien tenía
años de finanzas— más el callejón del `.notFound` y el bloqueo de asociar una cuenta completa.

**Why:** es el paso del que dependen el 8, el 9 y el 10 del runbook. Sin él ninguna puerta sabe rutear.

**How to apply:**

- **El bloqueante que hay que decir cada vez que se hable de device-QA de esta familia:** medido el
  2026-09-10, **ni staging ni producción sirven `kind`** (staging último deploy `2026-08-12`; producción
  `2026-09-10T06:12Z`, anterior al commit del campo). Por eso `kind` ausente rutea **al comportamiento de
  hoy en cada puerta** — sin el dato nuevo, el sistema se comporta como antes, y eso hizo el PR seguro de
  mergear antes del deploy. También significa que **tres de los cuatro recorridos del device-QA no se
  pueden distinguir** hasta que Jürgen despliegue el Worker (`npm run deploy:*` desde `gateway/`, nunca
  `wrangler` a pelo). El orden es: Worker → recrear grupos de prueba → recorridos.
- **La puerta de Ajustes «migrar a la nube» quedó con tabla y sin cableado**, y de paso se midió que hoy
  **adopta en silencio** tras dos confirmaciones destructivas (el claim contesta `existing_stable` y la
  máquina se aparta a `adoptBackendAccount`, que no sube el corpus local). Ticket propio; su celda de
  «promover mi asociada» necesita el paso 10, que es quien persiste la identidad de la asociada.
- **La cuenta que entra por grupos ya nace del tipo correcto sola**: `profiles.kind` es
  `default 'groups_only'` y la fila la crean `create_group`/`join_group`. Cero backend en este paso, y
  `CloudAccountClient.claim` sigue sin parámetro `kind`.
- **`AccountKindService.handleSignIn()` se retiró**: el paso 2 lo dejó preparado y llegó aquí con cero
  call-sites. El descubrimiento en las puertas lo hace `CloudIdentityDiscovery`, que además necesita saber
  si la cuenta EXISTE — algo que `refresh()` descarta por dentro.
- **Lo que se decidió y no se repregunta**: la adopción desde grupos es SILENCIOSA (sin banner y sin
  preguntar), el `.notFound` va al consentimiento con el proveedor ya elegido, Grupos cambia de motor y no
  de aspecto, y los tests son las 15 celdas más los bordes del eje. Todo en la sección «Decisiones de
  Jürgen» del ticket.

**Lo que la review adversarial cambió, porque es el dato de calibración:** nueve defectos míos, dos
graves —el bloqueo se deshacía solo porque tres de sus cuatro salidas no cerraban la sesión rechazada, y
el eje era un `Bool` que confundía tres estados distintos del dispositivo— más cinco afirmaciones falsas
en mis propios comentarios. Ver [[review-adversarial-caza-lo-mio]] y
[[mi-docblock-tambien-es-una-premisa]].
