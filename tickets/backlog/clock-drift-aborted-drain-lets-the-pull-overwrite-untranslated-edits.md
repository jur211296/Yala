---
id: clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-23
updated: 2026-09-23
source: "`drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23), al fijar qué es «un drain que terminó»"
---

# Con el reloj del teléfono muy desajustado, un cambio tuyo puede pisarse al bajar cambios de otro dispositivo

## El problema, en lenguaje de usuario

Si el reloj del teléfono va muy desajustado, la app deja de capturar tus cambios hasta que se corrige. Mientras
tanto sigue bajando los de tus otros dispositivos, y uno de ellos puede pisar un cambio tuyo que aún no se capturó.

## Por qué pasa (leído el 2026-09-23; inferido, no ejecutado)

- Cuando `clock.send` lanza (deriva u overflow), el drain corta la traducción en la frontera de esa transacción
  (`translationAborted`), persiste lo anterior y devuelve `true`: la vuelta «terminó».
- El pull aplica entonces la página con el guard D-1 construido desde el outbox, que no tiene los cambios no
  traducidos. Es el mismo laundering que `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` cerró para el drain que ABORTA.
- No se trató igual a propósito: con el reloj desajustado días, parar el pull dejaría el teléfono sin recibir nada.

## Qué habría que decidir

- ¿Parar el pull mientras dure la deriva, o aplicar la página saltándose solo las filas con cambios sin traducir?

## Criterios de aceptación

- [ ] Con la traducción cortada, una edición no traducida no la pisa una página remota.
