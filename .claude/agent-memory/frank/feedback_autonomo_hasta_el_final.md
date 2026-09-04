---
name: autonomo-hasta-el-final
description: Jürgen decide en bloque por adelantado y luego suelta la ejecución entera; «autónomo» significa que también los rojos y el entorno son míos hasta el final
metadata:
  type: feedback
---

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
