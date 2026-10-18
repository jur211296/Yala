---
id: scheduled-payment-save-does-nothing-when-a-field-is-missing
status: backlog
area: scheduled-payments
priority: medium
created: 2026-10-14
updated: 2026-10-14
source: auditoría UX 2.2, lote 5 (primeros días), encontrado fuera del lote — es del lote 10
---

# «Nuevo pago planificado»: el ✓ no hace nada si falta la cuenta o la subcategoría, y el pago recién creado no sale en la lista

**Clase:** posible bug para el lote 10 (pagos planificados). No se tocó en el lote 5.

## Qué se vio (medido en el simulador, 2026-10-14)

1. Con nombre e importe, tocar ✓ no guarda ni avisa: la cuenta y la subcategoría están más abajo, fuera de la
   pantalla, con «Seleccionar» en rosa. Quien llega desde «Primeros pasos» cree que el botón no funciona.
2. Guardado «Netflix · S/ 45 · cada mes, día 1, desde hoy», la lista de Pagos planificados sigue diciendo «Aún no
   tienes pagos planificados» en «Este mes»; a la vez, la Bandeja avisa «Se añadieron 1 pagos planificados».

Capturas: `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/capturas/5.1-05-tras-guardar-pago.png`, `~/Claude/entregas/Yala--auditoria-ux-2-2-lote-5-primeros-dias/capturas/5.1-10-aviso-bandeja-tras-practica.png`.

## Qué medir antes de arreglar

Si (2) es el filtro de «Este mes» con el primer cobro el 1 del mes que viene, o un refresco que falta.

## Lote 10 (2026-10-14)

Medido: (1) el ✓ sale gris (apagado) y tocarlo no hace nada; VoiceOver decía «Crea al menos una cuenta y una categoría». (2) es correcto en el cálculo —el primer pago cae el 1 del mes que viene— pero la lista mentía con «Aún no tienes pagos planificados», y el borrador de la Bandeja nacía el día de inicio porque el primer vencimiento se guardaba como la fecha de inicio.

Arreglado en el PR del lote 10: B8 (VoiceOver dice lo que falta), B10 (el primer vencimiento es la primera fecha del pago) y B12 («Sin pagos este mes»). Lo de UX —que el ✓ lleve al campo que falta y que guardar diga cuándo es el primer pago— va como propuesta L10-4 y L10-5, con card para Jürgen.
