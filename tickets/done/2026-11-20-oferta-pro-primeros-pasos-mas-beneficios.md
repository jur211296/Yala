---
id: 2026-11-20-oferta-pro-primeros-pasos-mas-beneficios
status: done
priority: medium
area: "onboarding, primeros-pasos, pro"
created: 2026-11-20
updated: 2026-11-20
source: "encargo 2026-11-20-oferta-pro-final-primeros-pasos-mas-beneficios-maquetas"
---

# Oferta Pro de Primeros pasos: todos los beneficios y «Ver todos los beneficios»

Jürgen (20-nov): «La nueva vista simplificada para invitar a PRO la siento muy pobre. Pocos beneficios. Y no hay
algo para ir a ver todos los beneficios.» Hoy `SetupCompleteTrialOfferSheet` enseña tres funciones (dictar, leer
recibos, Yala IA) y nada más.

Maquetas y medidas: artifact «Oferta Pro: más beneficios» (https://claude.ai/artifact/62MFq13V23S7oVQY83gnWu,
público), y la sesión en `tickets/done/2026-11-20-oferta-pro-primeros-pasos-mas-beneficios-maquetas.md`. **Jürgen elige A, B o C en la base
del artifact (colección `decisiones`, documento `opcion`).** Este ticket describe la recomendada (A); si elige otra,
cambia la sección «Diseño» y los criterios siguen valiendo.

## Beneficios que se pueden prometer (medido en `FeatureGateService.ProFeature`, 2026-11-20)

| Puerta | Gratis | Pro |
|---|---|---|
| `voiceInput` | — | Dictar |
| `imageInput` (foto, captura, PDF, y lo que llega por Compartir) | — | Sí |
| `chatAssistant` | — | Pregúntale a Yala IA |
| `smartInsightsAI` (Distribución, Tendencias, Resumen, flujo de caja) | — | Resúmenes con IA |
| `accounts` | 4 | Sin límite |
| `budgets` | 3 | Sin límite |
| `proThemes` (`AppTheme.isPro`) | 4 temas | 9 (Índigo, Rosa, Turquesa, Minimalista, Translúcido) |
| `premiumIcons` (`AppIconOption.isPremium`) | 1 icono | 4 (Oscuro, Claro, Neón) |

**No se prometen** (la web los anuncia y la app no los tiene como puerta): «Reportes avanzados», «Acceso adelantado a
nuevas funciones», «soporte prioritario». Grupos no entra: es gratis por decisión de Jürgen (14-nov). Las cifras de
gratis (4, 3, 4 temas, 1 icono) se leen del código (`freeLimit`, `AppTheme.allCases`, `AppIconOption`), no se escriben
a mano en el texto.

## Diseño (opción A, recomendada)

1. **Cabecera más corta**: estrella, «Prueba Yala Pro 1 mes gratis» en `DS.Typography.title` (hoy `welcomeHeadline`) y
   una línea. Se conserva la línea de «Lo que acabas de probar…» cuando la persona probó voz, foto o IA en el paso 2.
2. **Una tarjeta con cuatro bloques** (icono en ficha de color, título y detalle), que cubren las ocho puertas:
   - Anota sin teclear · Dictando, o con una foto, captura o PDF
   - Yala IA · Pregúntale cómo vas y te resume tus gastos
   - Sin límites · Todas tus cuentas y presupuestos
   - A tu estilo · 5 temas y 3 iconos exclusivos
3. **«Ver todos los beneficios ›»** como última fila de la tarjeta (color `accentText`, 44 pt de alto).
4. **Planes, línea de tiempo, «Restaurar compras» y pie legal**, como hoy.
5. **«Empezar mi mes gratis» fijo abajo** (`safeAreaBar`), como hoy. «Ahora no» sigue en la barra. Nunca un botón
   debajo de otro.

### Destino de «Ver todos los beneficios»

Página nueva **empujada dentro de la misma hoja** («Qué incluye Yala Pro»), no `SubscriptionView`:
`SubscriptionView` es el paywall de Ajustes y repite planes y botón (dos pagos apilados). La página:

- Tabla Gratis | Pro por grupos (Anotar, Yala IA, Organizar, A tu estilo) con las cifras de la tabla de arriba.
- Pie: «Tus registros, tus estadísticas y Grupos siguen gratis, como siempre.»
- El mismo «Empezar mi mes gratis» fijo abajo, que compra el plan elegido en la oferta.
- «‹» vuelve a la oferta con el plan elegido intacto (la página no tiene `@State` de plan: lo lee de la oferta).

Arnés de la maqueta (no es código de producción, sirve de punto de partida para la vista):
`docs/maquetas/oferta-pro-primeros-pasos/arnes-maquetas-oferta-pro.patch` (se aplica con `git apply`)
(`-mockOffer A|B|C`, `-mockOfferAll`).

## Textos (tabla propia, `PrimerosPasosPaso7.strings` o una nueva `OfertaProBeneficios.strings`; 16 idiomas)

Español neutro, `es-419`. Ver la lista completa en el artifact. Claves nuevas mínimas: subtítulo corto, cuatro
títulos, cuatro detalles, «Ver todos los beneficios», título de la página, cabeceras Gratis/Pro, cuatro grupos, filas
de la tabla, «Sin límite», el pie. Nada en `Localizable.strings`.

## Criterios de aceptación

- [x] La oferta nombra las ocho puertas Pro de la tabla y ninguna que la app no tenga.
- [x] «Empezar mi mes gratis» se ve sin bajar en iPhone SE (3.ª gen.), 17 Pro y 17 Pro Max, claro y oscuro, a tamaño
      de texto normal (sigue en la barra fija).
- [x] Sin bajar, en el SE se ven la tarjeta de beneficios completa y los dos planes (como hoy); en el 17 Pro y el Pro
      Max, además, la línea «Hoy no pagas · cobro el…». Medido en la maqueta A: en el SE el plan mensual acaba en 600 pt
      y el botón empieza en 605. Va justo: las filas de la tarjeta llevan 6 pt de aire vertical y la cabecera 4 pt
      entre piezas; si se agranda algo, se vuelve a medir en el SE.
- [x] «Ver todos los beneficios» empuja «Qué incluye Yala Pro» en la misma hoja; «‹» vuelve con el plan elegido.
- [x] Desde la página, «Empezar mi mes gratis» compra el plan elegido (con `-uitest-fake-purchase`, sale «¡Listo!
      Tienes Pro»).
- [x] Las cifras de gratis salen del código, no de una cadena.
- [x] A AX5 la oferta se desplaza y nada se corta (el botón sigue fijo). A tamaños de accesibilidad el icono de cada
      bloque va encima del texto (`AdaptiveRowStack` o el `if dynamicTypeSize.isAccessibilitySize` de las reglas): en la
      maqueta a AX3 el icono se queda a la izquierda y le quita ancho al texto.
- [x] VoiceOver: cada bloque se lee como un elemento («Anota sin teclear. Dictando, o con una foto…»); el enlace es
      botón; la tabla se lee por fila («Cuentas: gratis 4, Pro sin límite»).

## Tests previstos

- `Bienvenida23FinalUITests`: mantener `test_final_offer_keepFree_closesWithoutPro` (el botón `isHittable`) y añadir
  `test_final_offer_seeAllBenefits_pushesAndComesBack` (empuja, ve `setup_offer_all_benefits`, vuelve, el plan
  mensual elegido antes sigue elegido) y `test_final_offer_purchaseFromAllBenefits_showsProIsOn`.
- Unit `YalaTests/PrimerosPasosPaso7/`: la tabla de beneficios se arma de `ProFeature.freeLimit`, `AppTheme.isPro` y
  `AppIconOption.isPremium` (cambiar un límite cambia el texto); paridad de las claves nuevas en los 16 idiomas.
- `qa/coverage-index.json`: el área de Primeros pasos con los casos nuevos.

## Fuera

- La web (`Web/src/i18n/translations.ts`, `pricingPro*`) promete tres beneficios que la app no tiene: ticket aparte.
- El paywall de Ajustes (`ProIncludedGrid`, seis fichas) no se toca aquí.

## Resultado (2026-11-20, implementación de la opción A)

- Hecho: `OfertaProBeneficiosCard` (cuatro bloques + «Ver todos los beneficios ›»), `OfertaProTodosLosBeneficiosPage`
  (empujada dentro de la hoja, con el botón de la oferta abajo) y `OfertaProBeneficiosLogic` (cifras del código). Textos
  en `OfertaProBeneficios.strings`, 16 idiomas.
- Medido en el simulador (iOS 27.2): en el SE el plan mensual acaba en 600 pt y el botón empieza en 605; en el 17 Pro y
  el Pro Max se ve además «Hoy no pagas · cobro el…». A AX5 la oferta se desplaza, el icono sube encima del texto y el
  botón sigue fijo.
- Tests: unit `YalaTests/OfertaProBeneficios/` (14 casos) · XCUITest
  `Bienvenida23FinalUITests#test_final_offer_seeAllBenefits_pushesAndComesBack` y
  `#test_final_offer_purchaseFromAllBenefits_showsProIsOn`.
- La unit de lo tocado se fija en `OfertaProBeneficiosTests`, no en `YalaTests/PrimerosPasosPaso7/` como decía el plan:
  `PrimerosPasosPaso7Tests.sheet_layout` solo cambia su aserción de «tres funciones».
