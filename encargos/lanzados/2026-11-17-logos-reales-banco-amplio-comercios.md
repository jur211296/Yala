Yala
# Logos reales de marcas y un banco mucho más amplio de comercios en pagos planificados
---
toca: Yala/App/Logic/SubscriptionBrandCatalog.swift,Yala/App/Logic/MerchantLogos/,Yala/App/Views/Planning/SubscriptionBrandBadge.swift,Yala/App/Views/Planning/ScheduledPaymentEditorView.swift,Yala/App/Views/Planning/ScheduledPaymentRowView.swift,Yala/App/Views/Planning/ScheduledPaymentsListView.swift,Yala/App/Views/Planning/PagosRecurrentes/,YalaTests/SubscriptionBrandCatalogTests.swift,YalaTests/MerchantLogos/,tickets/backlog/scheduled-payments-real-brand-logos.md,tickets/done/scheduled-payments-real-brand-logos.md
depende: Yala/pagos-que-se-repiten-banner-y-hoja
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3, con «Pagos que se repiten: banner en Planificación…» ya mergeado. Cierra la card «Pagos planificados: logos reales de las marcas» (`tickets/backlog/scheduled-payments-real-brand-logos.md`).

## Qué decidió Jürgen (17-nov, 15:55 Lima)
1. **Logos reales** (imágenes de las marcas), no la inicial sobre color. Sin revisión de licencias marca por marca: es uso nominativo para identificar un pago de la persona (como Copilot, Rocket Money o los bancos). Reglas: no deformar ni recolorear el logo, nada que sugiera patrocinio, y ningún logo de terceros en la ficha del App Store ni en publicidad.
2. **Un banco MUCHO más amplio de comercios**: hoy son 40 servicios y en su TestFlight salen con el ícono genérico SmartFit, Claro, Cloudflare o ExchangeRate Host. Meta orientativa: cientos de comercios (mínimo ~500), priorizando Perú y Latinoamérica (gimnasios, telcos, bancos y fintech, retail, delivery, streaming, transporte, servicios básicos, educación, seguros, software y SaaS, apps de IA), más los globales. Cada entrada con nombre, alias o variantes de cómo aparece en un registro, y dominio.
3. **Solo soluciones gratuitas** (regla dura de Jürgen del 17-nov: no se gasta dinero en esto). Nada de plan pago.

## Recomendado (decide la sesión y anota)
- Fuente de imagen: un servicio de logos por dominio con plan gratuito (Brandfetch Logo API, logo.dev u otro equivalente sin costo), con caché en disco del celular y la inicial de color como respaldo sin red o sin logo. Alternativa: empaquetar en la app los más usados. Compara peso, privacidad (solo se envía el dominio del catálogo, nunca datos de la persona) y términos del plan gratuito, y elige.
- **Si el servicio pide una clave o cuenta**, no la inventes ni la crees: es vital, se pregunta según el modo (en semi, a Jürgen y espera viva; en nocturno, checkpoint y card «Espera decisión»). Mientras tanto, deja todo listo con el respaldo.
- Coincidencia por nombre tolerante (mayúsculas, tildes, sufijos como «J1», «P2», «Crédito», «PE», «S.A.C.») para que «SmartFit J1» encuentre SmartFit.
- Se ve en la lista, línea de tiempo, calendario, editor, la hoja de pagos que se repiten y su banner. El logo elegido a mano sigue funcionando como hoy (`ScheduledPayment.brandLogoID`), sin campo nuevo de iCloud.
- Si el mismo catálogo serviría para los registros (Registros/Panel), no lo apliques aquí: déjalo como card nueva con la propuesta.

## Cómo entregar
- Probar en claro, oscuro y con el iPhone girado, en el iPhone 14 por DeviceMCP, con los pagos de la captura de Jürgen (SmartFit, Claro, Spotify, Cloudflare). En la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Tests nuevos en `YalaTests/MerchantLogos/`.
- Entregable visual: artifact de Claude con antes y después, y una muestra del banco de comercios por categoría con sus logos. Nunca Markdown ni PDF.

## Reglas
- Sin esquema de datos nuevo. No toques CloudKit Production. Commits y PR sin firma de IA, PR contra 2.3. Toca solo lo declarado; si hace falta otro archivo, mínimo y anotado.
- Lo menor y reversible se decide con la opción recomendada y se anota en «Decidido sin consultar». Lo vital, según el modo fijado al arrancar (semi 05:30–20:00: pregunta y espera viva; nocturno 20:00–05:30: checkpoint recuperable y card «Espera decisión», sin mergear ni desplegar lo incompleto).
- Cierre: si está completo, CI verde y el modo lo permite, `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas por la sesión (modo semi, ninguna es vital: no hace falta clave ni cuenta). Se discuten en el PR.

**D1 · ¿Servicio de logos por dominio o logos empaquetados?** → Empaquetados en la app: un script (`scripts/merchant_logos.py`) baja una sola vez, en la Mac, el icono que cada comercio publica en su propia web (`apple-touch-icon`; respaldo: iconos públicos de Google y DuckDuckGo) y los deja en un catálogo de imágenes dentro de `Yala/App/Logic/MerchantLogos/`.
Por qué: gratis sin cuenta ni clave, cero red en el teléfono (nada sale del celular, ni el dominio), funciona sin conexión y no depende de que un servicio gratuito cambie sus términos. Alternativa descartada: logo.dev y Brandfetch piden cuenta y clave (pregunta vital y espera); el icono público de Google sin clave no tiene términos escritos y devuelve tamaños irregulares (Spotify a 48 px).

**D2 · ¿Ampliar `SubscriptionBrandCatalog` o un catálogo aparte?** → Catálogo aparte (`MerchantCatalog`, JSON empaquetado) solo para el LOGO. `SubscriptionBrandCatalog` sigue igual.
Por qué: el de suscripciones decide más que el dibujo —el detector de recurrentes exige monto exacto y categoría «suscripción» a una marca, y el chat guiado busca sus nombres dentro de cualquier frase—; meter Claro o Luz del Sur ahí cambiaría esas dos funciones. Los 40 ids de siempre existen igual en el catálogo nuevo (un test lo fija), así que `brandLogoID` guardado sigue valiendo.

**D3 · ¿Cómo casa un nombre?** → Igual que hoy (nombre o alias, o empieza por él), y si no casa, una segunda pasada quitando ruido: palabras de trámite al principio (pago, recibo, tarjeta, crédito, cuota, plan, seguro…), códigos como «J1»/«P2», números, y sufijos de razón social o país al final (PE, S.A.C., SAA, Perú…). Gana el alias más largo.
Por qué: «SmartFit J1», «Interbank Crédito» o «Tarjeta de crédito BCP» encuentran su marca sin abrir coincidencias por palabra suelta en medio («Viaje a Paris» no es Paris). Alternativa descartada: buscar el alias en cualquier parte del nombre: falsos positivos con nombres comunes.

**D4 · Forma del distintivo** → Círculo, como el resto de iconos de la fila; el logo de fondo transparente va sobre blanco y ocupa el 66 % del lado, que cabe entero en el círculo. Sin logo, la inicial sobre color de siempre.
Por qué: coherencia con los iconos de categoría de la lista y del calendario; el icono que publica cada marca ya deja margen. Alternativa descartada: cuadrado redondeado solo para los logos (dos formas mezcladas en la misma lista).

**D5 · Elegir a mano entre 666 comercios** → El menú de la fila «Logo» pasa a una hoja con buscador (Automático, Sin logo y la lista). Sin textos nuevos: reusa los que ya existen y el buscador del sistema.
Por qué: un menú de 666 opciones no se puede usar. Archivo nuevo, anotado: `Yala/App/Views/Planning/MerchantLogoPicker.swift`.

**D6 · Archivos fuera de lo declarado** → `scripts/merchant_logos.py` (generador), `Yala/App/Views/Planning/MerchantLogoPicker.swift` (hoja), `qa/coverage-index.json` (contrato de cobertura). Nada de textos nuevos ni de esquema.

**D7 · Registros y Panel** → No se tocan. Card nueva con la propuesta de usar el mismo catálogo ahí.
