Yala
# Maquetas: la IA asigna la cuenta sola al leer un pantallazo, y reglas de cuenta (Apple Pay y palabras clave)
---
toca: tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas.md,tickets/done/2026-11-20-captura-cuenta-automatica-y-reglas-maquetas.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Sesión de diagnóstico y diseño, sin código de la app: medición del estado actual, maquetas realistas comparables en un artifact visual de Claude y un ticket de implementación listo para encolar.

Pedido de Jürgen (20-nov, 09:36):
1. **Cuenta automática al leer un pantallazo.** Si el pantallazo dice «Tarjeta de crédito» y solo hay una cuenta con ese nombre, que se asigne sola. Si tiene una cuenta «Zip» y el pantallazo dice «Zip», que la IA entienda que es esa cuenta.
2. **Reglas de cuenta.** Por ejemplo: «si viene de Apple Pay con esta tarjeta, siempre va a esta cuenta», o «si el pantallazo trae estas palabras (o estas palabras juntas), va a esta cuenta». La IA lee esas reglas y clasifica mejor a partir de ellas.

Primero, mide lo que existe hoy (premisa que se verifica, no se asume):
- En 2.3, `Yala/App/Services/ImageOCR/` (`ScreenshotSingleExtractor`, `ScreenshotListExtractor`) deja `needsUserInput: ["account", ...]`, así que la cuenta no se cruza con los nombres de las cuentas. Confirma si alguna otra ruta ya lo hace: la IA del servidor o gateway que recibe imágenes, la captura entrante (`InboundCaptureDrain`), los Atajos o automatizaciones de Apple Pay/Wallet, el chat o el recuerdo de la última cuenta por comercio (`InboxViewModel`). Deja una tabla de cada ruta de captura con lo que hace hoy con la cuenta.
- Qué datos trae realmente una captura de Apple Pay (la automatización de Atajos: nombre de la tarjeta o del comercio) y si sirven como condición de una regla.

Qué entregar:
- 2 o 3 opciones (A/B/C) con recomendación, en claro y oscuro, con el estilo de cards de Yala:
  - **Coincidencia automática** por nombre (o alias) de cuenta, con un aviso suave y fácil de cambiar. Casos: una sola coincidencia, varias coincidencias, ninguna, o nombres parecidos («Zip» frente a «Zip Visa»).
  - **Reglas de cuenta**: dónde viven (Ajustes, la propia cuenta o al corregir una captura con «recordar para la próxima»), cómo se crean y se editan. Condiciones: tarjeta de Apple Pay, una palabra, varias palabras juntas, comercio. Destino: una cuenta. Prioridad: la regla manda sobre la coincidencia por nombre y esta sobre la adivinanza de la IA. Qué pasa si dos reglas chocan.
  - Cómo la IA recibe las cuentas y las reglas (contexto mínimo, sin mandar saldos ni datos de más) y cómo funciona sin conexión o sin Pro con la coincidencia local.
- Textos propuestos en español neutro latinoamericano.
- Preguntas de diseño en el artifact, cada una con su recomendación. No son vitales: la sesión cierra sola y Jürgen elige al revisar.
- Ticket `tickets/backlog/2026-11-20-captura-cuenta-automatica-y-reglas.md` con el diseño recomendado, criterios de aceptación, tests previstos y si conviene partirlo en dos (coincidencia primero, reglas después).

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Resueltas sin preguntar (modo semi, el encargo dice que las preguntas de diseño no son vitales): las
> recomendaciones se dan por buenas y Jürgen las cambia en la base del artifact. Se discuten en el PR.

**D1 · ¿La premisa (`ImageOCR` deja la cuenta sin cruzar) es la ruta real?** → No: `ImageOCRService` no tiene llamador de producción; la foto va por `ImageVisionService` + `VisionDraftFactory`, que solo elige por moneda. El diseño parte de esa ruta.
Por qué: medido con grep (solo lo usan sus pruebas). Alternativa descartada: diseñar sobre `ImageOCR`, que no ve nadie.

**D2 · ¿Maquetas con arnés SwiftUI dentro de la app o HTML con estilos de las piezas reales?** → «Hoy» con capturas reales del simulador (parche local que no se commitea) y las propuestas en HTML con los tokens y medidas de «Esto leí», el selector y Editar cuenta.
Por qué: son 16 pantallas nuevas que no existen; un arnés costaría más que el diseño y la decisión es de mecanismo, no de píxel. Alternativa descartada: arnés como en la oferta Pro (allí se variaba una hoja existente).

**D3 · ¿Opción recomendada?** → A: la IA copia el medio de pago y Swift decide con una escalera común; reglas locales.
Por qué: repite la regla del 4-nov del chat (nada nuevo sale del teléfono), vale sin conexión y sin Pro en Apple Pay y avisos del banco, y una regla se cumple siempre. Alternativas: B (la IA elige con nombres y reglas) y C (solo reglas), en el artifact.

**D4 · ¿Dónde viven las reglas?** → En la propia cuenta («Reglas de captura») y se crean también con «Recordar» al corregir.
Por qué: se piensan en el momento de corregir y pertenecen a una cuenta. Alternativa: pantalla en Ajustes (pregunta abierta en el artifact).

**D5 · ¿Últimos 4 dígitos como regla o como dato de la cuenta?** → Dato: el «Número de cuenta» que ya existe.
Por qué: no añade campo ni modelo, y el aviso del banco ya lee los 4 dígitos sin usarlos.

**D6 · ¿Un ticket o dos?** → Un solo fichero de ticket con dos partes; recomienda entregar la coincidencia primero (sin cambios de modelo) y las reglas después.
Por qué: el encargo pide ese fichero concreto; la parte 2 toca SwiftData y sincronización y conviene que no frene la 1.

**D7 · ¿Pasar el artifact a público?** → Un intento; con dos Chrome conectados elegir uno exige preguntar a Jürgen, así que se deja privado y se anota.
Por qué: ADR-123 de casa, es un intento y no condición de cierre.
