---
id: 2026-11-21-novedades-2-3-panel-llegada-nota-salud
status: done
priority: high
area: panel
created: 2026-11-22
updated: 2026-11-22
source: auditoría de decisiones contra 2.3 (21-nov), decisiones 118, 137, 117 y 30 de Jürgen
---
# Novedades 2.3 con el iPhone Duo, Panel con llegada solo desde Primeros pasos y nota de salud «lo que te queda del mes»

Encargo del 22-nov-2026 (modo nocturno) y su continuación de la mañana. El «uso de línea» de la hoja de cuenta esperó
una decisión de Jürgen, que eligió la opción A (22-nov 06:23): el límite de la tarjeta será un campo nuevo sincronizado
de la cuenta, en un encargo aparte que va después de este.

## Hecho

- **Novedades 2.3:** ocho tarjetas, la primera «Hecha para el iPhone Duo», en los 16 idiomas (tabla propia
  `Novedades23.strings`). Solo lo que la app publicada hace en producción.
- **Panel, llegada:** con Primeros pasos a medias y sin cuenta, el saldo grande no sale (`showsBalanceHero`). Al entrar,
  solo el mazo; el saldo vuelve con la primera cuenta (en «Solo gastos», con el paso 2).
- **Nota de salud, lote 2:** cuarta parte «Lo que te queda» (entró − salió sobre lo que entró, con la regla del hero del
  Panel). 20 % o más → 100; 0 % → 50; gastar más de lo que entra baja con suelo de 30. Sin ingresos no cuenta; en
  «Solo gastos», nunca. Pesos 32 · 28 · 20 · 20: sin la parte nueva la nota es la de antes. Tarjeta de Estadísticas, hoja de
  la parte y hoja de la nota con su sección, su cápsula y su fila en «¿Cómo se calcula?». Textos en
  `NotaSaludTeQueda.strings` (16 idiomas). Los tres textos que decían «tres partes» ya no lo dicen.
- Estadísticas recalcula la nota al cambiar «Solo gastos» (hallazgo del revisor).

## «Uso de línea»: listo, sin pintar hasta que exista el límite

Referencia: `docs/design/referencias/2026-11-17-hoja-cuenta-tarjeta-referencia.jpg` («16 % used · 6,752.50 available of
8,000.00»). La hoja tiene la línea «X % usado · N disponible de M» (`HojaCuentaTarjetaLogica.usoDeLinea`, texto
`hojaCuenta.lineUsage` en los 16 idiomas) y no la pinta sin límite: ni texto vacío ni «0 %». Con varias divisas tampoco.
El encargo siguiente crea el campo y se lo pasa a `HojaCuentaTarjetaEstado(card:limite:)`.

## Pruebas

`YalaTests/NovedadesPanelNota/` (cinco suites: Novedades en 16 idiomas, puerta del saldo y su cableado, curva,
cálculo con medianoche, marcas «≈» y pata de grupo, textos de la parte nueva) y
`YalaTests/HojaCuentaTarjeta/HojaCuentaTarjetaLogicaTests` (uso de línea: sin límite no sale; con límite, como la
referencia; pasado del límite; varias divisas).
