# Checklist de assets de la ficha 2.1 (iPhone + iPad)

> **Nada de esto se ha subido.** Viene de `~/Claude/lola-borradores/2.1/app-store-assets-2.1.md`
> (investigado el 2026-10-12 en las páginas de Apple). El 2026-10-13 solo cambiaron dos cosas: el
> título y el enlace al sistema visual, que ahora vive en [`../marca/`](../marca/).
> Las capturas actuales están en `../App Store/PNG-*`; el generador, en `../screenshots-appstore/generator`.


## 1. Espacios nuevos o cambiados (2025-2026)

| Asset | Qué es / dónde sale | Specs | ¿Obligatorio? | Fuente |
|---|---|---|---|---|
| **Encabezado de la ficha (Product page header)** — NUEVO (WWDC26, anunciado el 5-oct-2026) | Banner ancho arriba de la ficha, sobre el ícono y el nombre. iOS/iPadOS 27+ | Imagen 21:9 **3840×1646** (JPEG/PNG, sin alfa) o universal 16:9 **5244×2950** PNG. Video 21:9 3840×1646, 30/60 fps, 5–30 s, .mov/.m4v/.mp4, en silencio y en bucle | Opcional | [Noticia](https://developer.apple.com/news/?id=ljpl7kyn) · [Specs](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) · [WWDC26 205](https://developer.apple.com/videos/play/wwdc2026/205/) |
| **Asset de resultados de búsqueda** — NUEVO | Reemplaza las capturas en la tarjeta de búsqueda. iOS/iPadOS 27+ | Imagen 3:2 de 1920×1280 a 3840×2560 (o la universal 5244×2950). Video 3:2, 5–30 s, sin sonido | Opcional | [Specs](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) |
| **Asset Library + herramienta de vista previa** — NUEVO | Biblioteca para subir y aprobar assets sin una versión nueva; vista previa con modo oscuro, dispositivos y orientaciones | — | Herramienta | [Noticia](https://developer.apple.com/news/?id=ljpl7kyn) · [Manage assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets) · [Buenas prácticas y plantillas](https://developer.apple.com/app-store/asset-best-practices/) |
| **Tarjetas de In-App Events** (ahora son «creative assets») | Tarjeta del evento (búsqueda, Hoy, ficha) y página de detalle | Tarjeta 16:9, 1920×1080–3840×2160; detalle 9:16, 1080×1920–2160×3840; video 15–30 s | Opcional | [Specs](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications) |
| **Capturas: el tamaño obligatorio de iPhone ahora es «Dynamic Island (medium)»** | Ficha + búsqueda. Hay una fila nueva «iPhone Duo» (obligatoria desde abril de 2027 con el SDK de iOS 27.1) | iPhone medium 1206×2622 / 1179×2556; large 1320×2868 / 1290×2796 / 1260×2736; iPad 13" 2064×2752 o 2048×2732 (también en horizontal). 1–10 por tamaño, sin alfa | **Sí**: iPhone + iPad 13" (Yala corre en iPad) | [Screenshot specs](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) |
| **App previews** (sin cambios en el formato) | Video antes de las capturas; si la proporción no coincide con las capturas, va a «A Closer Look» | 15–30 s, ≤500 MB, ≤30 fps. iPhone 886×1920 (o 1920×886); iPad 1200×1600 (o 1600×1200). Hasta 3 por tamaño | Opcional | [App preview specs](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications) |
| **Páginas de producto personalizadas: 70 y con keywords** (29-oct-2025) | Variantes de la ficha con sus propias capturas, previews y texto promocional; con keywords salen en la búsqueda | Mismos specs que la ficha | Opcional | [Noticia](https://developer.apple.com/news/?id=gf6mgrs6) · [Ayuda](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions/) |
| **Ícono Liquid Glass (Icon Composer)** — WWDC25 | Un archivo `.icon` por capas → Default, Dark y Mono (Clear claro/oscuro, Tinted claro/oscuro) en iPhone, iPad, Mac y Watch. Va en el build, no se sube a ASC | Se hace en Icon Composer (macOS Tahoe 26.4+) y se agrega a Xcode | No es obligatorio; si no lo haces, el sistema genera los modos oscuro y tintado | [Icon Composer](https://developer.apple.com/icon-composer/) · [Doc Xcode](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer) · [ASC: ícono](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/) · [WWDC25 361](https://developer.apple.com/videos/play/wwdc2025/361/) |

Nota: el encabezado y el asset de búsqueda pasan por revisión de Apple, pero ya aprobados se pueden cambiar sin una versión nueva. Aclaración: aso.dev (fuente externa, no de Apple) dice que solo se muestran en iOS/iPadOS 27 o posterior.

## 2. Checklist para enviar 2.1

**Obligatorio**
- [ ] Capturas de iPhone, es y en. Hoy hay 10 por idioma en 1320×2868 (large). Según la página de Apple, el tamaño medium usa como respaldo esas capturas escaladas, pero falta **confirmarlo en ASC**. Si no aparecen, exporta 1206×2622 desde el Simulador del iPhone 17 Pro. Hay que rehacer las 1, 2, 3, 4, 5, 8 y 10 (checklist §3). La 3 dice «Vía tu iCloud», que es falso. La 10 habla de la nube: hay que reescribirla **sin Modo Nube**.
- [ ] Capturas de iPad 13", es y en: rehacer **todas** con la interfaz nativa (barra lateral, dos columnas, Yala IA al lado). Hoy son 8 por idioma en 2752×2064 horizontal, del generador de 2.0.
- [ ] Ícono 1024 en el build (ya existe `AppIcon.appiconset`, con un solo PNG).

**Recomendado**
- [ ] Encabezado 3840×1646 (o el universal 5244×2950, que también sirve para la búsqueda), es y en.
- [ ] Asset para resultados de búsqueda, 3:2 (si no usas el universal).
- [ ] Ícono con Icon Composer (`.icon`) o, como mínimo, variantes oscura y tintada. Hoy el repo no las tiene: el sistema las generaría solo y el resultado puede verse mal sobre el navy.
- [ ] App preview de iPhone (886×1920) mostrando voz en una hoja y varias capturas. Opcional: preview de iPad horizontal (1600×1200).
- [ ] Páginas personalizadas («Grupos para viajes», «Yala en iPad») con keywords propias, después de cerrar i6tj.
- [ ] Revisar todo en la nueva vista previa de ASC (modo oscuro, iPhone y iPad).

**Qué se puede sacar del Simulador**
- Capturas de iPhone 17 Pro (1206×2622), iPhone 17 Pro Max (1320×2868) e iPad Pro 13" M5 (2064×2752) con `xcrun simctl io booted screenshot`. Después se componen en el generador `marketing/screenshots-appstore/generator`.
- Video para el preview: `xcrun simctl io booted recordVideo`. Luego se reescala a 886×1920 o 1600×1200, a ≤30 fps y con duración de 15 a 30 s. Sirven el PDF con contraseña, Grupos con datos de prueba, el Panel y el tipo de cambio, Yala IA y el iPad. **No sirven** Apple Pay real ni compartir desde WhatsApp (ahí hace falta un iPhone real). La voz funciona con el micrófono de la Mac, pero queda más natural en un dispositivo.
- El encabezado y el asset de búsqueda son piezas de diseño (plantillas de Apple en Figma, Photoshop, Pixelmator o Sketch). Pueden llevar capturas del Simulador adentro.

## 3. Consistencia de diseño (detalle y hex en [`../marca/`](../marca/))

- Fondo **navy** en todo: capturas, encabezado, asset de búsqueda e In-App Events. Sin alfa, y Apple lo exige.
- Destellos **rosa, azul y teal**: pocos, en las esquinas, nunca debajo del texto. En el 21:9, deja libre la zona que se recorta en iPhone vertical (revísalo en la vista previa).
- Titular **blanco en negrita**, con **una sola palabra clave subrayada** por pieza (por ejemplo «Tus gastos en el **iPad**»). Copy según BRAND-VOICE: tuteo, nada de «fácil».
- **Pill tag** arriba del titular para la novedad («Nuevo en 2.1», «iPad»). Úsalo igual en las capturas y en el encabezado.
- Logo **«yala» blanco**. En el encabezado, mejor no repetir el ícono: la ficha ya lo pone justo debajo.
- Mismo orden de historia en las capturas de iPhone y de iPad, para que el usuario reconozca la marca en los dos.
- No mostrar Modo Nube, «tu cuenta en la nube», el conector MCP ni «Vía tu iCloud» en ningún asset.
