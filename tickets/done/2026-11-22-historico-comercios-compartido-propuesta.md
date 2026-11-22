---
id: 2026-11-22-historico-comercios-compartido-propuesta
status: done
area: "captura"
created: 2026-11-22
updated: 2026-11-22
source: "GO de Jürgen del 22-nov (10:03 Lima) a una sesión de propuesta visual del histórico compartido de comercios, sin construir. El PR de foto y comercio (#1112) lo dejó fuera a propósito."
---

# Propuesta: histórico compartido y anónimo de comercio a categoría

Solo propuesta: no se tocó código de la app, ni el servidor, ni producción. Jürgen elige sobre el artifact y la
construcción va en otro encargo.

## Dónde está

- Artifact (flujo del dato, variantes A · B · C con simulador de umbral, maquetas en iPhone, costos, riesgos, texto
  de la política y el bloque «Tus decisiones»): **https://claude.ai/artifact/PsU8Pp6cwPbEPaBPLiw8tL** (público con
  enlace).
- Fuente: `docs/propuestas/2026-11-22-historico-comercios/index.html`.
- La decisión se guarda en la base del artifact: colección `decision`, documento `jurgen` (`variante` A · B · C,
  `detalles` d2-d6 con la opción elegida y `nota`). **Antes de construir, leer esa decisión.**

## Estado de partida (medido en `origin/2.3` el 2026-11-22)

- La memoria de comercios es por persona: `MerchantMemory` (comercio canónico → subcategoría, aprobaciones y
  correcciones) y `MerchantMemoryService`. Propone con 3 aprobaciones y ≤30 % de correcciones; pone sola con 5 y
  ≤10 %. Se alimenta al aprobar un borrador (`DraftService`, `InboxDraftEditSheet`) y la consultan Apple Pay, el
  aviso y el correo del banco, la voz y la Bandeja.
- La normalización es `MerchantCanonicalizer.canonicalize`: mayúsculas, sin prefijos de procesador (`DP*`, `IZI*`…),
  sin símbolos. No quita números de sucursal ni ciudad.
- La foto ya trae `merchantKind` de una lista cerrada de 34 tipos (`VisionMerchantKind`) y el teléfono lo traduce a
  la subcategoría del usuario por nombre de semilla o por icono (`MerchantKindSubcategory.match`). Sin IA, el banco
  de 666 marcas del teléfono (`MerchantCatalog`) da el tipo cuando no deja duda.
- El servidor de Yala es un Worker de Cloudflare (Workers Paid, ya se paga) con D1 y KV. Cada llamada va con App
  Attest. Supabase solo guarda la cuenta en la nube y Grupos.

## Lo que propone (recomendado; el detalle y las alternativas, en el artifact)

1. **Se comparte el tipo de comercio de la lista cerrada, no la subcategoría.** Las categorías de cada persona tienen
   nombres propios y 16 idiomas; el tipo ya existe para la foto y cada teléfono lo traduce. Si la categoría elegida
   no se traduce a un solo tipo (creada o renombrada con otro icono), no se aporta nada.
2. **Vive en D1 del servidor de Yala en Cloudflare.** Funciona sin cuenta y con Modo Nube apagado, no cuesta más y no
   mezcla el dato con las cuentas de Supabase.
3. **Lectura sin consulta por comercio:** el teléfono baja la lista común entera y busca en local. Un pago de Apple
   Pay, que hoy no sale del teléfono, sigue sin salir.
4. **Aporte en lote semanal**, sin hora ni importe, para que el servidor no pueda deducir cuándo compraste.
5. **Variante B (equilibrada):** 3 dispositivos distintos con 7 días o más, acuerdo ≥75 % y dos votos de ventaja;
   cambiar un par ya publicado pide 5. Sucursal, números y sufijos legales fuera, y alias del banco de 666.
6. **Orden en la app:** tu memoria (aunque sea una vez) › lista común › IA › banco de 666. La lista común solo
   propone, nunca pone sola.
7. **Participación:** aviso una vez y opción para salirse en Perfil; recibir sigue para todos. El texto de la
   política va propuesto en el artifact. No es asesoría legal.

## Qué queda

- Jürgen elige en el artifact. La sesión que construya lee `decision/jurgen` y abre su propio ticket.
- El encargo de construcción incluye también la política publicada en `Web/` (16 idiomas) y la etiqueta de
  privacidad de la App Store.
