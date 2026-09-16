---
name: autonomo-hasta-el-final
description: Jürgen decide en bloque por adelantado y luego suelta la ejecución entera; «autónomo» significa que también los rojos y el entorno son míos hasta el final — PERO de 6:00 a 21:00 (Lima) las decisiones de producto y de acceso se le preguntan con AskUserQuestion
metadata:
  type: feedback
---

> **Excepción que manda sobre todo lo de abajo: la sesión DIURNA pregunta** (norma de Jürgen, 2026-09-15). De 6:00
> a 21:00, hora de Lima (`TZ=America/Lima date +%H`), Jürgen está disponible. Aunque el encargo diga «MODO AUTÓNOMO»
> y venga en bypass, las decisiones de producto —qué texto ve la persona, qué entra en el alcance, si hace falta un
> mecanismo nuevo— y las de acceso se le ponen con `AskUserQuestion`: «No inventes decisiones grandes sin preguntar».
> Lo técnico sigue siendo mío, y se escribe en el Paso 0 con lo medido.
>
> **Why:** me lo dijo a mitad del Paso 0 de `groups-push-reads-an-offline-token-refresh-as-a-session-expiry`, cuando
> iba a auto-contestar el árbol como pide `grill-encargo` en autónomo. Contestó las tres preguntas en un solo gesto, y
> las tres con la recomendada.
>
> **How to apply:** cierra los hechos primero, agrupa lo suyo en UNA ronda de hasta cuatro preguntas con la
> recomendada delante, y sigue con lo técnico sin parar. De noche vale lo de abajo.
>
> **Y vale cuando una sesión nocturna cruza las 6:00** (2026-09-16): el Paso 0 se auto-contestó a las 5:36, la review
> destapó a las 6:0x que la opción elegida dejaba un callejón, y esa decisión de diseño se le preguntó —una pregunta, la
> recomendada delante, lo técnico ya hecho—. Contestó en minutos con la recomendada.

Su forma de delegar tiene dos tiempos muy marcados. **Primero decide en bloque**: le llevé siete
decisiones en dos tandas —cuatro antes de escribir el ticket, tres antes de implementar— y las
contestó en dos mensajes, algunas con una sola palabra. **Después suelta la ejecución entera**: «GO,
ve validando todo por tu cuenta hasta llegar al final. Autónomo».

**Why:** lo que quiere revisar es el *criterio*, no el *avance*. Interrumpirle a mitad de una
implementación aprobada para enseñarle un rojo o pedirle que elija entre dos formas de arreglarlo es
devolverle trabajo que ya delegó.

**How to apply:** cuando diga autónomo, «hasta el final» incluye lo que no es código:
- Un test en rojo se **clasifica** (código mío / preexistente / entorno) con una medición, no se
  reporta a medias. En la sesión del 2026-09-04, seis XCUITest cayeron por crash del runner y la
  respuesta correcta no era avisar: era repetirlos con el simulador caliente y demostrar que eran
  entorno.
- El **entorno es parte del encargo**. El disco cayó de 36 a 20 GB por artefactos de mis propias
  corridas y empezó a dar errores de I/O; liberarlo es mi trabajo, no una interrupción.
- Los hallazgos de una review adversarial se **arreglan**, no se presentan como opciones — salvo que
  toquen una decisión suya de las de la primera tanda.

Lo que sí sube antes de terminar: algo que contradiga una decisión que ya tomó, o un hallazgo que
cambie el alcance. Ver [[alcance-minimo-salvo-incoherencia]] y [[jurgen-levanta-sus-reglas]].
