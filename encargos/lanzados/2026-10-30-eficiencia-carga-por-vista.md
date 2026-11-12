---
esfuerzo: high
---
# Eficiencia vista por vista: medir y arreglar los tiempos de carga de cada pantalla de Yala 2.2

Cierre: **cierra-sola** → al terminar, `/cerrar-total`.
Versión **2.2**. Base `origin/2.2`. Slug: `eficiencia-carga-por-vista` · Sesión cola **S27e** · al cerrar → **S27f**.
Card: `tablero ver tablero-eficiencia-vista-por-vista-que-cada-pant-mw8u`.

## Contexto
Pedido de Jürgen (2026-10-29 05:36 Lima): pre-check serio antes de preparar release; que los datos carguen rápido, como se espera, vista por vista.

## Qué se pide
1. Sembrar datos realistas (una cuenta con año+ de movimientos, varias monedas, grupos, presupuestos, pagos planificados, Bandeja con borradores).
2. Medir con os_signpost / Instruments (o equivalente reproducible) el tiempo hasta contenido útil de: arranque en frío, Panel, Registros, Estadísticas, Planificación/Presupuestos, Grupos, Flujo de caja, Bandeja, Ajustes y widgets.
3. Arreglar lo que esté claramente lento (fetch en main thread, recomputar en body, fetch sin predicado, etc.) sin cambiar comportamiento.
4. Lo que no quepa: ticket hijo + card en backlog 2.2/2.3 con la medida.
5. Un PR a 2.2 en auto-merge con tabla antes/después por vista. Card a in progress al empezar; al cerrar, done (o in qa si pide device-QA).

## Reglas de Mini
Pipeline serial: limpiar → build `xcodebuild -jobs 2` sin sim → boot 1 sim → tests → apagar sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar; no toques las de un worktree vivo. Haz un solo fetch y rebase sobre `origin/2.2` antes de abrir el PR, con el simulador apagado; no esperes el CI de otro PR.

## Qué NO tocar (común)
- marketing/ y Web/ (Lola). No lanzar otras sesiones Yala. No rediseñar notificaciones (eso es la card 2.4 «Rediseñar las notificaciones desde cero»).

## Cómo se sabe que está bien
Tabla antes/después con método de medida; ninguna regresión en tests; hijos creados para lo pendiente.

## Noche autónoma (Jürgen 2026-10-29 22:18 Lima: «que la noche fluya sin pedirme inputs»)
- Se lanza con `--permission-mode bypassPermissions`. No uses AskUserQuestion ni esperes respuesta de Jürgen: es de noche (21:00–6:00).
- Ante una decisión abierta, toma la opción conservadora (la más reversible y de menor alcance), documéntala en el ticket/card y en el PR, y sigue.
- Lo que de verdad necesite a Jürgen (borrar datos de usuario, seguridad, diseño crítico, firma/2FA): no lo hagas; crea una card separada con `cierra-sola` asignada a jurgen explicando la decisión pendiente, termina el resto y cierra.
- Git: haz un solo fetch y rebase sobre origin/2.2 antes de abrir el PR; no esperes el CI de otro PR.
- Termina siempre con `/cerrar-total`.

/cerrar-total

## Paso 0 (Frank, 2026-10-30, auto-contestado: noche autónoma)

1. **Datos sembrados.** Perfil de semilla nuevo `rendimiento`, solo en DEBUG: la vida personal de `realista`
   (730 días, varias monedas, presupuestos, pagos planificados, borradores de la Bandeja) más los grupos de
   `grupos`. Es aditivo: ningún perfil existente cambia. *Conservador: no toco `realista`, del que dependen tests.*
2. **Método de medida.** Marcas DEBUG con `OSSignposter` + `Logger` (subsistema `perf`): el intervalo empieza al
   elegir la pestaña (o al arrancar el proceso, para el frío) y acaba donde la vista asigna el estado que pinta los
   datos. Un XCUITest conductor (`LoadTimesUITests`, se salta salvo con `YALA_PERF=1`, así que no entra en el CI)
   siembra una vez, relanza en frío varias veces y recorre las pestañas; los ms salen de `log show`. Mediana de N
   pasadas en el simulador iPhone 17 Pro (iOS 27.0). Son cifras de simulador: valen para comparar antes/después,
   no como tiempos absolutos de un iPhone.
3. **Qué se arregla aquí.** Solo lo claramente lento y sin cambio de comportamiento (fetch en main repetido,
   recomputar en `body`, fetch sin predicado, O(n²)). Lo que pida rediseño o toque cálculo financiero con riesgo
   va a ticket hijo + card.
4. **Review adversarial** si un arreglo toca un cálculo financiero (saldos, presupuestos, estadísticas).
5. **Device-QA.** No hace falta: no cambia UI ni comportamiento; si un arreglo lo pidiera, la card irá a `in qa`.
