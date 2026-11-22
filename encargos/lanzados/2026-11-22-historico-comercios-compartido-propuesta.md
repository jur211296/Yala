Yala
# Propuesta visual: histórico compartido y anónimo de comercio a categoría
---
toca: docs/propuestas/2026-11-22-historico-comercios/,tickets/backlog/2026-11-22-historico-comercios-compartido-propuesta.md,tickets/done/2026-11-22-historico-comercios-compartido-propuesta.md
esfuerzo: high
cierre: cierra-sola
---

Jürgen dio GO el 22-nov (t1886u-3 y widget-t1886s10701) para que esta sesión prepare una propuesta. SOLO PROPUESTA: no se cambia código de la app ni nada en producción. El PR #1112 (foto/comercio) dejó fuera a propósito el histórico compartido entre usuarios. Ahora la categoría de un comercio se aprende por usuario.

## Dirección que le recomendé y que aceptó explorar
- Solo se comparte el par comercio normalizado y categoría, anónimo. Nunca montos, cuentas, fechas, notas ni quién lo apuntó.
- Un par entra al histórico solo cuando varios usuarios distintos coinciden. Propón el umbral y cómo evitar que se envenene.
- Lo que corrigió el propio usuario siempre manda sobre lo compartido.
- Se cubre en la política de privacidad. Propón el texto y explica si hace falta permiso explícito u opción para no participar.

## Qué entregar
Un artifact visual de Claude (nada de Markdown ni PDF como entregable) con:
- Cómo fluye el dato, de punta a punta, en un diagrama. Dónde vive (Supabase o iCloud) y qué pasa con Modo Nube apagado o sin cuenta.
- 2 o 3 variantes comparables (umbral, normalización de nombres, cuándo se actualiza), con pros y contras y la recomendada marcada.
- Cómo se vería para el usuario: maquetas en iPhone de una sugerencia que sale del histórico frente a una propia.
- Costos (solo opciones gratuitas o lo que ya se paga), riesgos de privacidad y el texto propuesto para la política.
- Las decisiones que Jürgen tiene que tomar, como opciones claras.
Fuentes en `docs/propuestas/2026-11-22-historico-comercios/`.

## Cómo trabajar
- Nada de código de la app ni nada en producción.
- Commit y PR contra 2.3, sin firma de IA, solo con la carpeta y el ticket. Auto-merge activado.
- Lo menor se decide con la recomendada y se anota. La elección final es de Jürgen sobre el artifact.
- Termina con /cerrar-total y deja el link del artifact bien visible.

## Paso 0 — decisiones (resueltas en semi, sin consultar: menores y reversibles; la elección final es de Jürgen sobre el artifact)

1. **Qué se comparte:** el tipo de comercio de la lista cerrada de 34 (`VisionMerchantKind`), no la subcategoría del usuario. Si su categoría no se traduce a un solo tipo, no se aporta.
2. **Dónde vive (recomendado):** D1 del servidor de Yala en Cloudflare, ya pagado; funciona sin cuenta y con Modo Nube apagado. Supabase e iCloud público, como alternativas comparadas.
3. **Lectura:** el teléfono baja la lista común entera y busca en local; no hay consulta por comercio.
4. **Aporte:** lote semanal, sin hora ni importe.
5. **Variante recomendada:** B (3 dispositivos, acuerdo ≥75 %, sucursal y sufijos fuera, lista diaria). A (prudente) y C (rápida) como comparables.
6. **Orden en la app:** memoria propia › lista común › IA › banco de 666. La lista común solo propone.
7. **Participación (recomendado):** aviso único + opción para salirse; recibir, para todos.
8. **Entrega:** artifact visual público + fuente en `docs/propuestas/2026-11-22-historico-comercios/`, ticket en `tickets/done/`. Sin código, sin `Web/`, sin producción.
