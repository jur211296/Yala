---
name: decisiones-que-esperan-a-jurgen
description: Los tickets parados de Yala no esperan código sino cinco decisiones de Jürgen; medido el 2026-09-02
metadata:
  type: project
---

Al 2026-09-02, la mayoría de lo parado en `tickets/in-progress/` **no espera implementación:
espera una respuesta suya**. Llevaban desde el 6 y el 12–13 de agosto sin moverse, y
`docs/ESTADO.md` no mencionaba ninguno.

Las decisiones, tal como se las planteé:

1. **Los ajustes de personalización que suben a la nube y no bajan** — ¿viajan de verdad entre
   móviles, o dejamos de prometerlo? Es una decisión por ajuste. No hay nada que investigar.
2. **¿La puerta de Grupos hereda la señal de «restauración en curso»?** Sí o no. Es lo único
   que separa a `welcome-copy-blames-owner` de estar cerrado.
3. **¿Puede el servidor decir «te rechazaron» o «ese grupo ya no existe»?** Rompe a propósito
   el silencio que impide sondear grupos ajenos. Su sí desbloquea dos tickets a la vez.
4. **¿Qué se le ofrece a quien entra en un móvil prestado y elige «empezar de cero»?** Es la
   puerta que lleva al borrado que se lleva los grupos del dueño. No falta un guard: falta
   saber qué se propone en su lugar.
5. **¿Cuándo se borran las pantallas muertas del recorrido de invitado?** Ya decidió que se
   van; falta aceptar que el barrido toca `ContentView`.

**Why:** un ticket que espera una decisión y uno que espera trabajo se ven idénticos en el
tablero, y por eso estos llevaban tres semanas quietos sin que nadie lo notara. La distinción
no está escrita en ningún sitio del repo — se pierde en cuanto nadie la recuerda.

**How to apply:** cuando Jürgen pregunte qué hay pendiente, separa las dos pilas y pon ésta
primero: son minutos suyos, no horas mías. Verifica antes de citarlas — un ticket puede
haberse resuelto, y el bloqueo de `secondary-groups-off-wipes-owner` ya había **caducado**
(decía esperar a un ticket que ya estaba hecho). Ver [[el-tablero-antes-que-el-bug]].
