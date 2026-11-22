---
id: 2026-11-21-novedades-2-3-panel-llegada-nota-salud
status: backlog
priority: high
area: panel
created: 2026-11-22
updated: 2026-11-22
source: auditoría de decisiones contra 2.3 (21-nov), decisiones 118, 137, 117 y 30 de Jürgen
---
# Novedades 2.3 con el iPhone Duo, Panel con llegada solo desde Primeros pasos y nota de salud «lo que te queda del mes»

Encargo del 22-nov-2026 (modo nocturno). Hecho todo menos el «uso de línea» de la hoja de cuenta, que **espera una
decisión de Jürgen**: pide guardar el límite de la tarjeta, un campo nuevo en la cuenta que toca el modelo de datos,
iCloud de producción y la nube de Yala. Por eso el PR queda en borrador y no se mergea solo.

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

## Pendiente: «uso de línea» (espera decisión)

Referencia: `docs/design/referencias/2026-11-17-hoja-cuenta-tarjeta-referencia.jpg` («16 % used · 6,752.50 available of
8,000.00»). Opciones y recomendación en la card «Espera decisión» del tablero.

## Pruebas

`YalaTests/NovedadesPanelNota/` (cinco suites: Novedades en 16 idiomas, puerta del saldo y su cableado, curva,
cálculo con medianoche, marcas «≈» y pata de grupo, textos de la parte nueva).
