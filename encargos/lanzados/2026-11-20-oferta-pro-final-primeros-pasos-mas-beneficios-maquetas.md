Yala
# Maquetas: oferta de prueba Pro al final de Primeros pasos, con más beneficios y un enlace a ver todos
---
toca: tickets/backlog/2026-11-20-oferta-pro-primeros-pasos-mas-beneficios.md,tickets/done/2026-11-20-oferta-pro-primeros-pasos-mas-beneficios-maquetas.md
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Sesión de diseño sin código de la app: maquetas realistas comparables en un artifact visual de Claude, más un ticket de implementación listo para encolar.

Hoja actual: `Yala/App/Views/Subscription/SetupCompleteTrialOfferSheet.swift` (textos en `Yala/Resources/es-419.lproj/PrimerosPasosPaso7.strings`, struct `SetupOfferFeatures`). Captura de cómo se ve hoy en el iPhone de Jürgen: `~/Claude/flota/adjuntos/oferta-pro-primeros-pasos-hoy.png` («Prueba Yala Pro 1 mes gratis», solo 3 beneficios: Dicta tus gastos, Lee recibos y PDF, Pregúntale a Yala IA; planes Anual/Mensual; «Empezar mi mes gratis»).

Opinión de Jürgen (20-nov): **«La nueva vista simplificada para invitar a PRO la siento muy pobre. Pocos beneficios. Y no hay algo para ir a ver todos los beneficios.»**

Contexto: la lista completa de Pro que ya existe en la app (`uxpro.feature.*`, `L10n+UXAudit22Lote06YalaPro.swift`) tiene 6: apunta hablando, apunta con una foto, Pregúntale a Yala IA, cuentas sin límite, presupuestos sin límite, temas e iconos. Revisa además el resto de pantallas de Pro (`ProTrialOfferSheet`, `ProTryNowSection`, `ProPurchaseComponents`) y la web (`Web/src/i18n/translations.ts`, `pricingPro*`) para no dejar fuera beneficios reales; no inventes beneficios que la app no tenga.

Qué entregar:
- 2 o 3 opciones (A/B/C) de la hoja completa con recomendación, en claro y oscuro, en tamaño iPhone real, con el estilo glass de Yala. Ideas a explorar: todos los beneficios reales agrupados (registrar más rápido, IA, sin límites, personalización), un «Ver todos los beneficios ›» que abra la pantalla completa de Pro o una comparación Gratis vs Pro, y cómo se mantiene visible «Empezar mi mes gratis» sin bajar (hoy hay un test de UI que lo exige: `YalaUITests/Flows/Bienvenida23FinalUITests.swift`).
- Que la hoja no se sienta pobre pero tampoco recargada: mide qué entra sin scroll en iPhone SE/mini y en Pro Max.
- Destino de «Ver todos los beneficios»: qué pantalla existente abre (o si hace falta una nueva) y cómo vuelve a la oferta.
- Textos propuestos en español neutro latinoamericano.
- Ticket `tickets/backlog/2026-11-20-oferta-pro-primeros-pasos-mas-beneficios.md` con el diseño recomendado, criterios de aceptación y tests previstos. Las preguntas de diseño van en el artifact con su recomendación; no son vitales: la sesión cierra sola y Jürgen elige al revisar.

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después y mediciones), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en semi, sin preguntar: ninguna es vital)

1. **Cómo se maquetan:** variantes SwiftUI dentro de la app (piezas reales: `ProPlanCard`, `YalaPrimaryButton`, glass, temas), capturadas en el simulador. Un arnés DEBUG (`-mockOffer A|B|C`, `-mockOfferAll`) que NO se commitea: viaja como parche a `~/Claude/entregas/`. Motivo: «tamaño iPhone real» y «mide qué entra sin scroll» piden la medida del render de verdad, no la de un HTML.
2. **Beneficios que se pueden prometer** = las 8 puertas de `FeatureGateService.ProFeature`: voz, foto/captura/PDF, Yala IA (chat), resúmenes con IA, cuentas (gratis 4), presupuestos (gratis 3), temas Pro (5 de 9) e iconos premium (3 de 4). Fuera: lo que la web promete y la app no tiene («Reportes avanzados», «Acceso adelantado», «soporte prioritario») y el cupo de IA de Grupos (no verificado en la app; además Grupos es gratis por decisión de Jürgen).
3. **Opciones:** hoy + A (cuatro bloques en una tarjeta), B (rejilla de ocho), C (lo probado + «Y además»). Destino de «Ver todos»: página nueva empujada dentro de la misma hoja («Qué incluye Yala Pro», Gratis vs Pro), con «‹» que vuelve a la oferta con el plan elegido intacto. Se descarta abrir `SubscriptionView` (repite planes y botón: dos paywalls apilados).
4. **Aparatos:** iPhone SE (3.ª gen., 375×667), iPhone 17 Pro (402×874, el más parecido al 14 de Jürgen) y 17 Pro Max (440×956). Claro (`-userTheme 1`) y Oscuro (`-userTheme 2`). Texto a tamaño normal. iPhone 14 por Device MCP: no hace falta (son capturas de maqueta, no QA).
5. **Precios:** los de prueba de `-uitest-fake-prices` ($29.99 / $4.99); se dice en el artifact.
6. **Entrega:** artifact visual con las capturas, medidas y selector de opción en su db; ticket de implementación en backlog; PR solo con tickets (sin código), auto-merge.
