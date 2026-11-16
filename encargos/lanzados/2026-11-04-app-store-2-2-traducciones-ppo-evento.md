# Lote 2.2 App Store: capturas y video traducidos, páginas de producto personalizadas y evento de lanzamiento con variante A/B

Base: origin/2.2 en jur211296/Yala. Una sola sesión, un cierre. Parte de las capturas es-PE ya aprobadas del encargo anterior (rehacer capturas 2.2). Cards:
1. «Capturas y video de App Store traducidos a en-US, en-GB, pt-BR y pt-PT»: genera las capturas y el video de vista previa en esos cuatro idiomas, con la app en ese idioma.
2. «Páginas de producto personalizadas de App Store: voz, Grupos y Yala IA»: prepara las capturas, los textos promocionales y el enlace de cada página.
3. «Evento dentro de la app para el lanzamiento de la 2.2 y variante A/B de App Store»: escribe el texto del evento y su imagen, y arma la variante B de capturas para Product Page Optimization.
No envíes nada a revisión ni publiques en App Store Connect sin el OK de Jürgen. Deja todo listo, con una hoja de contacto en el PR, y mueve las cards a «in qa». Para textos en español, usa español neutro latinoamericano.

Termina con /cerrar-total.

## Paso 0 — decisiones (Frank, 4-nov-2026; las abiertas, preguntadas al bot dueño)

- **D1 · ¿Entra Frank en la ficha y las capturas?** → Sí: el encargo se lo asigna, como en las capturas de 2.1 y 2.2. No toco `marketing/`: el molde vive en `ficha-app-store/`, las salidas fuera del repo (`~/Claude/propuestas/`) y la evidencia en `docs/evidencia/`.
- **D2 · Copy que no existe** (pt-PT de las capturas, promocionales de las 3 páginas, textos del evento) → **lo escribe Frank, marcado «BORRADOR para Lola»** (respuesta del bot dueño, 4-nov). Los textos de Lola que ya existen no se reescriben.
- **D3 · Idiomas de páginas, evento y variante B** → **español neutro (es-MX, el idioma principal de la ficha) e inglés (en-US)** (Jürgen, 4-nov).
- **D4 · Video** → **en-US, en-GB, pt-BR y pt-PT** (Jürgen, 4-nov), aunque la card decía que en pt servía el inglés.
- **D5 · en-GB y pt-PT** → **set propio: en-GB con libras y pt-PT con euros** (Jürgen, 4-nov). Toca la semilla (`DevSeedFicha.cifras`), así que pasa por el gate completo. Sus textos adaptan los de Lola y van como borrador para Lola.
- **D6 · Borradores en App Store Connect** → **sí** (bot dueño, 4-nov): las 3 páginas, el evento y la prueba A/B como borrador, con capturas y textos «BORRADOR para Lola», y los enlaces reales. Ni revisión, ni publicar, ni arrancar la prueba. Si ASC pide algo que no sea un borrador (asociar a una versión en revisión, aceptar algo legal), se para y se pregunta.
- **D7 · Composición 2.2 en el molde.** El set es-PE 2.2 se hizo a mano fuera del molde (Estadísticas en «Gráficas», lista de Grupos en el iPhone). Lo paso al molde (`conducir.sh` y `sets.js`, chips de la lista en `chipsLista`) para que los idiomas salgan iguales. Los chips nuevos de la lista llevan cifras de la pantalla de cada idioma y van como borrador para Lola.
- **D8 · Variante B de la prueba A/B** → mismas láminas, otro orden: abre con lo gratis (Grupos, Estadísticas, Tus cuentas) en vez de lo Pro (Yala IA, foto, voz). Hipótesis: para una descarga gratis convence más lo que no pide pagar. Es barata (sin copy nuevo) y se mide en las tres primeras, las de la búsqueda.
- **D9 · Páginas personalizadas** → las 10 láminas de la ficha, reordenadas para abrir con su función, más su promocional y sus palabras clave. Sin enlace profundo: la app solo abre enlaces universales de invitación de grupo.
- **D10 · Imágenes del evento** → tarjeta 16:9 (1920×1080) y detalle 9:16 (1080×1920), navy, pantallas de la 2.2 y sin texto encima (Apple pone el nombre y la descripción).
- **D11 · Disco** → 12 GB libres. No pude borrar los DerivedData de una sesión retirada (permiso denegado): se apunta en el cierre. Se borran los simuladores del carril al terminar cada tanda.
- **D12 · Herramienta de App Store Connect.** La asc instalada no crea páginas personalizadas; la nueva necesita el Issuer ID, que llega vía Dan. No se cambia la asc de la Mini (bot dueño). Las páginas se crean al final.
