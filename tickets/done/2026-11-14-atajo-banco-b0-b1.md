---
id: 2026-11-14-atajo-banco-b0-b1
status: done
priority: high
area: "atajo-banco, intents, inbox"
created: 2026-11-14
updated: 2026-11-14
source: "encargo 2026-11-14 · Atajo del banco: prueba B0 en el iPhone 14 y lectura del aviso (B1)"
---

# Atajo del banco: prueba B0 y lectura del aviso (B1)

Definición: `docs/ux/atajo-banco-y-suscripciones/` (decisiones de Jürgen del 14-nov: las recomendadas A1-A6, con I2 y L2).

## B0 · la prueba en el iPhone 14 (iOS 27.2.1)

Sin app del BCP con cuenta real: Yala Dev emite el aviso con una acción solo de DEBUG («Emitir aviso de banco de
prueba») y la automatización se arma «Al recibir una notificación de Yala Dev». Evidencia en
`docs/ux/atajo-banco-y-suscripciones/prueba-b0/` y en el artifact de B0.

1. **¿Llega el texto con el monto?** Sí. La variable «Notificación» entrega «título␤cuerpo»:
   `Consumo con tu tarjeta␤Realizaste un consumo de S/ 12.50 con tu Tarjeta de Débito BCP ****4821 en TAMBO+ MIRAFLORES.`
2. **¿Corre bloqueado y pide algo?** Corre y no pide nada: el texto llegó entero aunque la pantalla de bloqueo
   enseñaba «Notificación» sin vista previa. En iOS 27 la automatización no ofrece «Preguntar antes de ejecutar»: solo
   «Automatización» (encendida) y «Notificaciones» (apagada). «Mostrar contenido» sí espera un toque: el atajo real no
   lleva acciones con UI.
3. **¿El disparador viaja en el enlace de iCloud?** Sí, pero llega apagado. El `.shortcut` publicado lleva
   `WFWorkflowTriggers` con `WFNotificationTrigger` y la app elegida (bundle y equipo). Al añadirlo desde el enlace,
   Atajos lo deja con «La automatización está desactivada»; encenderla es un toque. Con I2, la guía son dos toques:
   «Añadir atajo» y el interruptor «Automatización».
4. **¿El disparador Correo pasa el cuerpo?** Sí. La variable «Correo electrónico» ofrece la propiedad «Contenido», que
   entregó el cuerpo entero. Corre sin pedir nada; este disparador sí tiene «Confirmar antes de ejecutar», apagado por
   defecto. B3 queda permitido. Medido con el iPhone desbloqueado.

**Punta a punta (B1 instalado en el iPhone 14):** aviso simulado → la automatización con «Registrar movimiento desde
texto» (banco BCP) corre sola → al abrir Yala, «Se añadió 1 registro automático a tu bandeja» → en la Bandeja,
«TAMBO+ MIRAFLORES −S/ 12,50 · Aviso de BCP», por confirmar (pide cuenta: hay dos en soles). Los atajos de prueba se
borraron del teléfono al terminar.

**Límite que la simulación no prueba:** que la app real del BCP (y de los demás) deje pasar su texto al disparador, y
el formato exacto de sus avisos. Se confirma con el primer aviso real de Jürgen.

## B1 · la lectura

- Acción de Atajos «Registrar movimiento desde texto» (`BankNoticeIntent`): corre por detrás, no toca SwiftData,
  encola en el App Group. Sin notificación propia (A5).
- Reglas por banco (`BankNoticeRules`): BCP, Yape, Plin y genéricas para Interbank, BBVA y Scotiabank; rechazos,
  publicidad, claves y saldos son «No eran compras»; anulaciones y devoluciones, «No entendimos».
- Respaldo con el modelo del iPhone (`BankNoticeModelReader`), solo si el importe está escrito en el aviso.
- Borrador `.automation` con el banco en la evidencia; la Bandeja dice «Aviso de BCP» o «No entendimos este aviso».
- Cola drenada por `InboundCaptureDrain` y purgada por `AppGroupInboundPurge`, como Apple Pay y Siri.

## Queda para B2

Fila en «Lo que Yala apunta solo», elegir banco, atajos listos por enlace, estado y contadores, pausa, y la cuenta por
los últimos cuatro dígitos (pide un campo en `Account`: esquema).
