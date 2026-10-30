---
id: usage-mode-full-to-groups-only-and-back
status: done
priority: high
area: "settings, groups, notifications"
created: 2026-10-26
updated: 2026-10-26
source: "card tablero-pasar-de-la-app-completa-a-solo-grupos-s-p0iu · lienzo https://claude.ai/artifact/8BR6F2UisLqa81vyfaa8EZ"
---

# Pasar de Yala completo a solo grupos y volver, sin perder datos

## Qué cambia para quien usa la app

En Ajustes › Preferencias hay una fila nueva, «Cómo usas Yala», con dos opciones: «Yala completo» y «Solo grupos».
Elegir «Solo grupos» pide confirmación, deja la app en Grupos y pausa recordatorios y pagos programados; los datos
siguen guardados. En solo grupos, Ajustes y Más ofrecen «Volver a Yala completo · Tus cuentas y registros te esperan».
Al volver: sin registros, directo al Panel; con registros, «Seguir donde lo dejé» o «Empezar de cero» (doble
confirmación y solo la cuenta principal). No se repite la bienvenida.

## Lo verificado en el simulador

`YalaUITests/UsageModeUITests` (3/3): ida, vuelta sin registros, vuelta conservando y «Empezar de cero». Unit:
`UsageModeTests`, `UsageModeFreshStartWipeTests`. Capturas en el PR.

## Guion de device-QA (iPhone de pruebas, scheme Yala Dev)

Lo que el simulador no prueba: que los avisos de verdad callen y vuelvan, y el segundo dispositivo.

1. Con Yala completo y datos, en Ajustes › Notificaciones activa «Fin del día» a dos minutos vista, y ten un pago
   programado que venza hoy.
2. Ajustes › Preferencias › Cómo usas Yala › Solo grupos › «Usar solo grupos». La app queda en Grupos.
3. Espera a la hora del recordatorio: **no** debe llegar. Un gasto nuevo en un grupo compartido **sí** debe avisar.
4. Ajustes › «Volver a Yala completo» › «Seguir donde lo dejé». Debe salir «Ya tienes Yala completo de nuevo» y el
   Panel con todo.
5. Comprueba que el recordatorio vuelve a estar agendado (pon otro a un minuto vista) y que el pago de hoy aparece
   en la Bandeja.
6. Con un iPad del mismo Apple ID abierto en Yala completo, repite la ida en el iPhone y vuelve con «Empezar de
   cero». En el iPad: no debe volver a la bienvenida ni perder sus preferencias; los registros desaparecen al bajar
   el borrado (puede salir el aviso de datos borrados en iCloud, que es verdad).

Cerrado en el barrido de QA 2026-10-30: criterio estricto (filtro doble); motivo y evidencia en docs/qa/tanda-qa-jurgen-2.2-barrido-2026-10-30.md.
