---
id: cancel-reverse-wipes-the-alert-that-just-appeared
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-21
updated: 2026-09-21
source: "review adversarial de `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` (2026-09-21), lente del aviso"
---

# Un «Cancelar» tocado en el momento justo borra el aviso que acababa de salir

## El problema, en lenguaje de usuario

Llevo un rato mirando la barra parada. Toco «Cancelar y seguir en la nube» y confirmo. La vuelta desaparece, sí — pero
mi «Cancelar» no parece haber hecho nada: no hay confirmación, y en la tarjeta queda una nota que dice que **no se
pudo terminar**, no que lo cancelé yo.

## Por qué pasa (medido en el código el 2026-09-21; la carrera es inferida de la lectura, no reproducida)

`CloudMigrationController.cancelReverse()` apunta el gesto, **espera** a que baje `isWorking`, y al despertar lo primero
que hace es `lastError = nil`.

Si el re-kick de 30 s de la pantalla estaba corriendo justo entonces y esa pasada cruza el techo, `resume` publica el
aviso de la salida — y el `lastError = nil` del «Cancelar» lo borra en menos de 200 ms. Cuando `runner.cancelReverse()`
llega, ya no hay nada que cancelar: la fase está en su origen, así que es un no-op y no deja su propia huella. La nota
de la tarjeta queda con el motivo del techo, no con `cancelled`.

La ventana es la duración de una pasada de red cada 30 s — y es justo el momento en que alguien harto de esperar toca
Cancelar.

**El `lastError = nil` no distingue** «limpio mi error anterior» de «borro un aviso que acaba de nacer mientras yo
esperaba». Antes del 2026-09-21 la ventana existía igual pero casi no había qué borrar: el techo no publicaba aviso.

## Qué habría que decidir

1. **Si el «Cancelar» que llega tarde debe reconocerlo**: «la vuelta ya había terminado sola» es más verdad que el
   silencio, y más que la nota del techo.
2. **O si basta con no borrar un aviso más nuevo que el gesto** — lo que pide una marca de tiempo o una secuencia en
   `lastError`, que hoy es un `String?` sin identidad.

## Criterios de aceptación

- [ ] Decidido 1 o 2 antes de tocar código.
- [ ] Un «Cancelar» confirmado durante la pasada que cruza el techo deja a la persona sabiendo qué pasó.
- [ ] No se rompe el caso normal: cancelar a tiempo sigue sin dejar nota ni alerta (lo decidió ella).

## Relacionado

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el que puso el aviso que ahora se puede borrar.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el que puso el botón en estas cuatro fases.
