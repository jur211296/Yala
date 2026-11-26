---
id: 2026-11-25-pulido-textos-primeros-pasos-y-paywall
status: done
priority: low
area: "primeros-pasos, panel, presupuestos, grupos, pro"
created: 2026-11-25
updated: 2026-11-25
source: "Observación en vivo del iPhone 14 del 25-nov (docs/qa/observacion-iphone14-2026-11-25/bitacora.md); tercer lote, encolado por Jürgen a las 18:21 (Lima)"
---

# Pulido de Primeros pasos y del paywall visto en el iPhone 14

Siete detalles de texto y de diseño menor que salieron al recorrer Primeros pasos en el iPhone 14.

## Qué cambió para la persona

1. **Añadir una segunda moneda** en el paso 1 abre una hoja titulada «Otra moneda» (antes «Moneda principal») y los
   nombres salen como en la tarjeta: «sol peruano», «dólar estadounidense» (cada idioma con su grafía).
2. **La fila de pasos del mazo** pinta las siete etiquetas al mismo tamaño: cada columna mide lo que su palabra y los
   huecos se reparten. Si no caben (iPhone chico o texto grande), pasa a dos filas de cuatro.
3. **El nombre del presupuesto** en el Panel usa hasta dos líneas: «Mascotas y animales» ya no sale cortado.
4. **La intro de Grupos** dice «Antes de empezar», como las de los pasos 1, 3 y 4 (antes, «Grupos · paso 2 de 3»).
5. **El confeti** del cierre se desvanece antes de llegar al botón «Cerrar».
6. **El título final** dice «¡Listo por ahora!» cuando algún paso quedó para después; «¡Primeros pasos completos!»
   solo con los siete hechos.
7. **El paywall sin precios** dice «Ahora no podemos mostrar los precios. Inténtalo en un rato.» en vez de culpar a la
   conexión.

## Decisiones

- Los textos nuevos van en una tabla propia (`PulidoPrimerosPasosPaywall.strings`, 16 idiomas) para no chocar con
  otra rama que edita `Localizable.strings`.
- La grafía natural de las monedas solo en el selector del paso 1: otros diez sitios de Ajustes y Grupos fuerzan
  mayúsculas y cambiarlos es otra decisión.
- «Solo gastos» / «Gastos e ingresos» chicos: no se encontró dónde se encogen (los botones del chat de bienvenida no
  reducen el texto y ninguna captura lo muestra).

## Pruebas

- `YalaTests/PulidoPrimerosPasos/PulidoPrimerosPasosPaywallTests.swift`: título final según los pasos para después,
  texto neutro sin precios en los 16 idiomas, título del selector por hueco, la tabla completa y el cableado.
- `YalaUITests/PulidoPrimerosPasos/PulidoPrimerosPasosCapturasUITests.swift`: capturas del después.
