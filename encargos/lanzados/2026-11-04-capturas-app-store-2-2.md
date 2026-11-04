# Rehacer las capturas de App Store 2.2 (iPhone, iPad y Duo) con el rediseño de Grupos y el perfil en la barra lateral del Duo

Base: origin/2.2 en jur211296/Yala. Una sola sesión, un cierre. Card: «Rehacer capturas App Store 2.2 (iPhone + iPad + Duo) con el rediseño de Grupos y el perfil en la barra lateral del Duo». Genera las capturas en es-PE con los datos demo de siempre y en los tamaños que pide App Store Connect: iPhone 6.9", iPad 13" y Duo. Tienen que mostrar la cabecera nueva de Grupos, el Panel actual y el perfil en la barra lateral del Duo. No las subas a App Store Connect: déjalas en el repo o en la carpeta de capturas, con una hoja de contacto en el PR para que Jürgen las apruebe. Mueve la card a «in qa».

Termina con /cerrar-total.

## Paso 0

Decisiones tomadas sin preguntar (sesión lanzada, nada vital en juego):

1. **Mismo set del 30-oct, solo pantallas nuevas.** Titulares, textos de Lola y composición se quedan; se recapturan
   las 30 pantallas (iPhone, iPad, Duo) sobre `origin/2.2` y se vuelve a renderizar. Los datos demo «de siempre» son
   la semilla `ficha` con Viaje a Cusco (`YALA_FICHA_MARKETING=0`), como el 30-oct.
2. **La cabecera nueva de Grupos está en la LISTA, no en el detalle del grupo.** En el iPad y el Duo abierto se ven
   las dos a la vez. En el iPhone la 06 pasa del detalle de Viaje a Cusco a la lista, y sus dos chips cambian a cifras
   que sí salen en ella (Beto S/ 110, Ana S/ 80). Titular y tarjeta de la lámina, sin tocar.
3. **Dónde quedan:** las 50 láminas en `~/Claude/propuestas/capturas-app-store-2-2-2026-11/` (118 MB, no van al
   repo); en el repo, las tres hojas de contacto y la nota en `docs/evidencia/capturas-app-store-2-2-2026-11-04/`.
4. **No se toca `marketing/`** (de Lola) ni App Store Connect.
