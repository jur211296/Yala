Yala
# Maquetas para elegir: oferta Pro con el mes gratis tras Primeros pasos y mazo centrado durante el paso 1
---
toca: docs/propuestas/maquetas-oferta-pro-y-mazo-centrado-2026-11-25/,tickets/backlog/2026-11-25-maquetas-oferta-pro-y-mazo-centrado.md,tickets/done/2026-11-25-maquetas-oferta-pro-y-mazo-centrado.md
esfuerzo: medium
cierre: propuesta-visual
release: no
pruebas-ui: no
---

Pedido de Jürgen (25-nov, 18:47 Lima): «Sí, encola las maquetas». Sesión corta de SOLO propuesta visual para el lote de diseño que salió de la observación en vivo del iPhone 14. No se construye nada en la app.

## Contexto
- Bitácora de la observación: `docs/qa/observacion-iphone14-2026-11-25/bitacora.md` en `origin/2.3` (hallazgos de las 17:22 y 17:49:51, capturas `capturas/171340.jpg` y `capturas/174951.jpg`). Página de la observación: https://claude.ai/artifact/WURtsKhAZqZ83dhddeVmvi
- Cards del tablero de Yala 2.3 (búscalas por título con `tablero listar --proyecto Yala`): «Oferta Pro tras Primeros pasos: anunciar el mes gratis y hacerla más llamativa» y «Primeros pasos centrado en la pantalla mientras se está en el paso 1».
- Oferta Pro: hoy la tarjeta del Panel dice «Lleva tus finanzas al siguiente nivel · Desbloquea voz, resumen con IA y cuentas ilimitadas · Pasarme a Pro» (`proBanner.*`, `Yala/App/Views/Shared/ProUpgradeBanner.swift`). Las dos suscripciones de Pro tienen un mes gratis de prueba y la app ya sabe si la persona tiene derecho (`StoreKitManager.isIntroOfferEligible`). Ya existen textos como «Prueba Yala Pro gratis 1 mes» y «Empezar prueba gratis». Jürgen quiere que se anuncie el mes gratis y que llame más; mencionó una ventana con confeti al terminar Primeros pasos.
- Mazo centrado: al llegar, el Panel solo muestra el mazo de Primeros pasos arriba, con dos tercios vacíos. Idea de Jürgen: mientras se está en el paso 1 (sin cuenta), el mazo va centrado; al terminar el paso 1 aparecen más elementos y vuelve arriba (`PanelView.swift`, `setupDeckSlot` / `isQuietArrival`). Vale para «Solo gastos» y para «Ingresos y gastos» (decisión de Jürgen del 25-nov: con «Solo gastos» el paso 1 también se hace de cero; ese cambio lo está haciendo otra sesión ahora).
- Hubo antes maquetas de la oferta Pro de Primeros pasos (encargo «oferta-pro-final-primeros-pasos-mas-beneficios-maquetas» en `~/Claude/flota/borradores/`); míralas para no repetir y para ser coherente con lo ya construido.

## Qué se pide
1. **Oferta Pro tras Primeros pasos: 2 o 3 maquetas comparables**, cada una con su versión para quien tiene derecho a la prueba y para quien no:
   - **A (recomendada de partida):** la tarjeta del Panel reescrita. Con derecho: «Prueba Yala Pro gratis 1 mes» y botón «Empezar mes gratis». Sin derecho: el texto de hoy.
   - **B:** una ventana con confeti al terminar Primeros pasos que anuncia el mes gratis, con su botón y su «Ahora no».
   - **C (opcional):** otra variante si aporta (por ejemplo A con más presencia visual), solo si se diferencia de verdad.
   Para cada una: claro y oscuro, cómo se ve en el iPhone 14, qué pasa al tocar y al descartar, y pros y contras en una línea.
2. **Mazo de Primeros pasos centrado** durante el paso 1: maqueta del Panel con el mazo centrado mientras no hay cuenta, y la transición o el estado siguiente cuando termina el paso 1 y el mazo vuelve arriba. Si ves una variante mejor (por ejemplo centrado con un saludo arriba), sumala como opción B.
3. **Recomendación clara** arriba del todo: qué elegirías en cada uno y por qué, en dos o tres líneas, para que Jürgen decida rápido.
4. Entrega final: **artifact visual de Claude** que facilite decidir; no Markdown, PDF ni documento de puro texto. Guarda también en `docs/propuestas/maquetas-oferta-pro-y-mazo-centrado-2026-11-25/` las imágenes o el HTML de las maquetas y una nota corta con el link al artifact, y crea el ticket por archivo.
5. Al final, una card «Espera decisión» de Yala 2.3 asignada a `jurgen` (`tablero crear --proyecto Yala --version 2.3 --asignado jurgen --estado "espera decisión" --cierre propuesta-visual --agente frank`), con `--pregunta` con las opciones en una línea cada una, la recomendación y el link del artifact. En las dos cards de arriba, deja una nota con el link del artifact (no las cierres).

## Qué NO hay que tocar
- Nada del código de la app, pruebas, proyecto de Xcode ni textos de `Localizable.strings`. Solo la carpeta de docs de arriba y su ticket.
- No instales nada en el iPhone 14. Si quieres capturas reales como base, puedes mirarlo por DeviceMCP sin tocarlo (Jürgen puede estar usándolo), o en la Max usar un segundo simulador además del de otra sesión; en la Mini, uno solo. Apaga y limpia los simuladores que enciendas.

## Cómo se sabe que está bien
- El artifact muestra las maquetas lado a lado, comparables, con la recomendación arriba, y se entiende en el celular.
- Existe la card «Espera decisión» a nombre de Jürgen con las opciones y el link.

## Reglas de la sesión
- Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas).
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Ninguna espera de más de 3 min sin escribir avance.
- PR solo de docs a `2.3` con auto-merge activado; cierra sin quedarte esperando.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen.
- Sin firma de IA en commits, PR ni textos. Español neutro latinoamericano en todo lo que lea Jürgen.

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: ninguna es vital)

1. **Formato de las maquetas:** HTML dibujado con las piezas reales del Panel (textos sacados de `Localizable.strings` de `2.3`), no capturas del simulador. Motivo: es solo propuesta, no hay código que lanzar, y el encargo prohíbe tocar la app; el simulador no aporta.
2. **Lo ya construido manda:** medido que la hoja «Prueba Yala Pro 1 mes gratis» ya sube al terminar el paso 2 (opción B del 20-nov) y no se repite al completar; en Yala Dev no sube por falta de precios. Se dice arriba del artifact porque cambia el peso de la opción B (sería la segunda ventana de pago).
3. **Opción C sí se incluye:** la oferta dentro de la tarjeta «¡Primeros pasos completos!». Se diferencia de verdad de A (otra tarjeta) y de B (ventana). Es la recomendada; A queda como texto de la tarjeta de Pro los días siguientes.
4. **Mazo:** A centrado (recomendada) y B centrado con saludo. Medido: el mazo está solo hasta el paso 1 en «Ingresos y gastos»; el saldo sale al crear la cuenta y las acciones rápidas al terminar el paso 2.
5. **Decisión de Jürgen:** selector en la base del artifact (`decisiones/maquetas`, escritura solo del dueño) además de la card «Espera decisión».
6. **`~/Claude/referencias-ui/` no existe en la Max:** no se pudo consultar; se sigue con el design system del repo.
