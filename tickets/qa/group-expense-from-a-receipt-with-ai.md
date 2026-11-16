---
id: group-expense-from-a-receipt-with-ai
status: qa
priority: high
area: groups
created: 2026-11-05
updated: 2026-11-05
source: tablero-grupos-repartir-un-recibo-con-ia-foto-o-fu74 (decisión de Jürgen del 21-oct; encargo 2026-11-05-grupos-repartir-recibo-con-ia)
---

# Grupos: repartir un recibo con IA (foto o voz)

## Qué cambia para el usuario

En Nuevo gasto de un grupo hay una píldora nueva, «Desde un recibo», junto a «Hoy». Abre una hoja donde se saca o elige
la foto del recibo y se escribe (o se dicta con el teclado) quién comió qué: «Ana el lomo, Luis y yo la pizza». También se
puede dictar todo en una nota de voz. Yala lee las líneas del recibo y propone a quién le toca cada una; en la revisión se
cambia con un toque quién comió cada cosa, se quitan líneas, y la propina, el servicio y los impuestos quedan **sin
incluir** hasta que la persona elija cómo entran (según lo que consumió cada uno, a partes iguales o solo para alguien),
con atajos para añadir una propina del 10 % o 15 % o un servicio del 10 %. «Usar este reparto» rellena el formulario de
siempre con el total, el nombre del local y el reparto exacto, y se guarda como cualquier gasto de grupo: sin guardar
líneas ni foto.

Gasta una foto (o una nota de voz) de la prueba gratuita; agotada, ofrece Yala Pro.

## Guion corto de prueba (iPhone, Yala Dev, tras desplegar el gateway en staging)

1. Abre un grupo con al menos dos personas más → «+» → toca «Desde un recibo».
2. Toca «Fotos» (o «Cámara») y elige la foto de un recibo de restaurante con unas cinco líneas.
3. En «¿Quién comió qué?» escribe, con los nombres de tu grupo, algo como «Ana el lomo, Luis y yo la pizza». Toca «Repartir».
4. Comprueba en «Revisa el reparto»: cada plato con su persona, lo no nombrado «Entre todos», y la propina o el servicio
   del recibo «Sin incluir». Cambia una persona tocando su línea (un solo ajuste debería bastar).
5. Toca el servicio o la propina → «Según lo que consumió cada uno»: el total sube y «A cada uno» cambia.
6. «Usar este reparto» → el formulario sale con el total, el nombre del local y «por monto fijo» con lo de cada uno. Guarda.
7. Repite con «Dictar el recibo»: di «pizza 40, lomo 35, dos chichas 16; Ana el lomo, Luis y yo la pizza» y toca «Listo».

## Qué queda fuera

- Guardar las líneas o la foto del recibo (decisión del encargo: sin cambiar el esquema).
- «Dividir pago grupal escaneando un recibo» (botón en el registro personal, nombres libres, resumen para compartir):
  espera la propuesta visual que elija Jürgen. La lógica de reparto (`ReceiptSplitLogic`) queda lista para reusarla.
- El gateway no está desplegado: hasta `deploy:staging`, la lectura contesta «No pude leer el recibo» (entrada en
  `gateway/RUNBOOK.md`).
