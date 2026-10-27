---
id: groups-only-by-choice-still-shows-apple-pay-and-siri-banners
status: qa
priority: low
area: "notifications, siri, apple-pay"
created: 2026-10-26
updated: 2026-10-27
source: "review adversarial de la card p0iu (completa ↔ solo grupos)"
---

# En «Solo grupos» siguen saliendo los avisos de Apple Pay y Siri

En «Solo grupos» sobre Yala completo, las automatizaciones de Apple Pay y Siri siguen mandando su banner con enlace a la
Bandeja (QuickExpenseIntent), que en esa shell no se ve. No son recordatorios, así que la pausa no los cubre. Decisión de
producto pendiente: ¿se callan o se quedan?

## Decisión de Jürgen (2026-10-27)

No se permiten. La acción dice algo como «No tienes Yala completo, actívalo para usar esta funcionalidad». Ampliada en
el Paso 0 del encargo S11e: también las preguntas de Siri (gasto, saldo), y también quien nunca activó Yala completo
(con «Activa…»; quien eligió «Solo grupos» oye «Vuelve…»).

## Hecho (encargo S11e)

- `GroupsOnlyIntentGate` decide como la shell. Bloqueado:
  - Apple Pay no encola el pago y manda «Pago sin registrar · Ahora ves solo tus grupos. Vuelve a Yala completo para
    registrar tus pagos con Apple Pay.» Tocarla abre la vuelta a Yala completo (o su activación).
  - «Anotar con Siri» dice el aviso antes de pedir el texto y abre Yala en la vuelta.
  - «¿Cuánto gasté?» y «¿Cuánto tengo?» dicen el aviso. «Abrir cuenta» (iOS 27) abre la vuelta.
- Textos en los 16 idiomas. Tests: `GroupsOnlyIntentGateTests` y el cableado en `UsageModeWiringTests`.

## Guion de iPhone (Jürgen)

Montaje: iPhone de pruebas con Yala Dev de este build, Yala completo, la automatización de Apple Pay ya creada en
Atajos (Tutoriales › Apple Pay si no la tienes) y una frase de Siri de Yala a mano.

1. Ajustes › Preferencias › «Cómo usas Yala» › «Solo grupos» › «Usar solo grupos».
2. Di «Oye Siri, cuánto gasté en Yala». Siri debe decir «Ahora ves solo tus grupos. Vuelve a Yala completo para
   usar esta función.», sin cifras.
3. Di «Oye Siri, anota un gasto en Yala». Mismo aviso, sin preguntarte el gasto, y Yala se abre y te devuelve a Yala
   completo (con la hoja «Seguir donde lo dejé» si tienes registros: elige esa). Repite el paso 1 antes de seguir.
4. Bloquea el iPhone y paga algo pequeño con Apple Pay. Debe llegar «Pago sin registrar» con «Vuelve a Yala completo…».
   Nada de «por revisar».
5. Toca esa notificación. Yala se abre en la vuelta a Yala completo: elige «Seguir donde lo dejé».
6. Paga otra vez con Apple Pay: vuelve el «Pago de … por revisar» de siempre.
