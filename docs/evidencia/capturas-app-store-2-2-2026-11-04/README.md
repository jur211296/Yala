# Capturas de la App Store · 2.2 (4-nov-2026)

> En el repo van solo las tres hojas de contacto y esta nota. Las 50 láminas (118 MB) viven en
> `~/Claude/propuestas/capturas-app-store-2-2-2026-11/`, en la Mini; las rutas de abajo son de esa carpeta.

**Es el set del 30-oct con las pantallas rehechas sobre la 2.2 de hoy.** Mismas 10 láminas, mismo orden, mismos
titulares y textos de Lola, mismo fondo navy. Cambian las pantallas: ahora traen la **cabecera nueva de Grupos**, el
**Panel actual** y, en el Duo abierto, el **perfil en la barra lateral**. PNG sin alfa, en español (Perú).
**No se ha subido nada a App Store Connect.**

| Qué | Dónde (en esta carpeta) |
|---|---|
| iPhone 6,9" · 1320×2868 | `6.9/01.png … 10.png` |
| iPhone 6,5" · 1284×2778 | `6.5/01.png … 10.png` (sale del mismo render) |
| iPad 13" · 2064×2752 | `ipad-13/01.png … 10.png` |
| iPhone Duo · interior 2007×2853 | `duo/2007x2853/01.png … 10.png` |
| iPhone Duo · exterior 1398×2034 | `duo/1398x2034/01.png … 10.png` |
| Hojas de contacto | `hoja-iphone.jpg` · `hoja-ipad.jpg` · `hoja-duo.jpg` |
| Pantallas sin componer | `capturas/s-*` (iPhone 17 Pro) · `i-*` (iPad Pro 13") · `d-*` (iPhone Duo) |
| El set del 30-oct, para comparar | `_antes-30oct/` |
| El código que las genera | `_fuente/` (y `_fuente/duo10.sh`, el conductor de las 10 del Duo) |

## Qué cambió respecto al 30-oct

- **06 Grupos.** La cabecera nueva vive en la **lista** de Grupos: la cifra grande «Te deben en total · en S/
  S/ 495.68», la barra de lo que debes y te deben, y debajo cada lado por divisa.
  - En el iPad y en el Duo abierto se ve sola, porque lista y detalle van juntos.
  - **En el iPhone la pantalla pasa del detalle del viaje a la lista**, porque el detalle no tiene la cabecera. Los dos
    chips de la lámina cambian para que sus cifras estén en la pantalla: «Beto te debe S/ 110» y «Ana te debe S/ 80»
    (las filas de Viaje a Cusco, que suman los S/ 190 de la tarjeta). Titular y tarjeta, iguales.
- **Duo abierto (01, 05-09).** El avatar del perfil ya no va arriba de la columna izquierda: está en la barra lateral,
  y el contenido usa todo el alto. En la 01 (Panel con Yala IA) el avatar sigue en la barra superior del Panel: es como
  lo pinta la app con el chat abierto.
- **Panel (02, 03, 04, 08, 09).** El de la 2.2 de hoy.

## Lo que se comprobó

- **Semilla** `ficha` del molde (`ficha-app-store/`), con Viaje a Cusco, en modo oscuro, Pro, soles y reloj fijo al
  13-oct-2026 a las 9:41. Build Yala Debug de `origin/2.2` del 4-nov, compilado con Xcode 27.2; el Duo en su runtime
  iOS 27.2 propio.
- **Las cifras de los objetos están en las pantallas**: S/ 4,686 · Hogar 47 % · Alimentación 28 % · Te deben
  S/ 190 · S/ 470 en Comidas fuera · 19 días · 74 % · $ 33,615.00 · Teléfono S/ 60 · Spotify S/ 18.
- **Medidas y alfa**: las 50 láminas a la medida exacta de App Store Connect, en RGB.
- **La barra de estado** marca 9:41; el iPad pone al lado la fecha real del simulador («Mié 4 nov.»), límite ya
  documentado en el molde.

## Cómo se rehace

```bash
cd ~/Claude/propuestas/capturas-app-store-2-2-2026-11
_fuente/render.sh                  # iPhone (6,9" y 6,5"), iPad y Duo
python3 _fuente/hojas.py iphone && python3 _fuente/hojas.py ipad && python3 _fuente/hojas.py duo
```

Las pantallas del iPhone y del iPad salen de `ficha-app-store/capturas/conducir.sh es iphone|ipad` con
`YALA_FICHA_MARKETING=0`; dos se repitieron a mano: Estadísticas en la pestaña «Gráficas» con «Este mes» (el molde la
deja en «Detalle»), y la lista de Grupos del iPhone (`-uitest-deeplink groups`). Las del Duo, con `_fuente/duo10.sh`
y Device Hub abierto.
