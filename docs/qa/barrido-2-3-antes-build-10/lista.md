# Barrido de QA antes de la 2.3 (10) — 25-nov-2026

Sobre una mezcla local de 2.3 con los tres PR de la app que llevan la build (bugs de cuenta, «Esto leí» y Estadísticas),
mientras esperaban su CI. Mini, simulador iPhone 17 Pro (iOS 27.2), scheme `Yala Dev`.

## Qué entró desde la build 9

| PR | Qué cambia para quien usa Yala | ¿Toca la app? |
|---|---|---|
| Bugs de cuenta (#1176) | «Vaciar datos» sin aviso de iniciar sesión ni Panel cargando; «Eliminar mi cuenta» siempre con datos en la nube; Primeros pasos tras el alta en un teléfono que tuvo Yala | Sí |
| «Esto leí» (#1178) | Moneda editable, descripción con peso, sin hueco arriba; hoja de varios con lo incompleto sin marcar | Sí |
| Estadísticas (#1179) | El chip del mismo mes del año pasado queda marcado | Sí (2 vistas) |
| Gateway, CI, análisis y pruebas (#1172, #1173, #1174, #1175, #1177) | Nada en la build | No |

## Resultado

| Qué | Cómo | Resultado |
|---|---|---|
| Pruebas de interfaz de lo nuevo | `PrimerosPasosTrasElAltaUITests`, `EstoLeiRecorridoUITests`, `MultiDraftReviewUITests`, `UXAudit22Lote11y16UITests` (chip del año pasado) y `Bienvenida23AltaUITests` (la bienvenida que va a probar Jürgen) | **22/22** en 7 min 15 s |
| Pruebas unitarias de lo nuevo | 12 suites: cuenta en la nube (cableado, cola, retirada de altas, espera del Panel, marca de Primeros pasos, fila de eliminar), subida por trozos, «Esto leí» y hoja de varios | **92/92** |
| «Esto leí» en el simulador | Recibo fingido: oscuro, claro y texto al máximo. «S/ ▾» → USD cambia el monto a «$» y la cuenta a «Ahorros USD» | Bien |
| Esquemas de iCloud de Producción | `cktool export-schema` del contenedor de producción contra el repo; ningún campo pendiente | Al día |

**Un rojo que no era de la app:** la primera corrida se lanzó con el scheme `Yala` (producción) y seis casos de la
bienvenida cayeron por «Falta Entrar con Google». Con `Yala` y `-uitest` la nube se apaga a propósito; con `Yala Dev`,
el de siempre, pasaron los ocho.

## Hallazgos

- **«Esto leí» con texto al máximo** (no grave, accesibilidad): la descripción se corta en dos líneas con «…», la
  categoría también («Restaur…»), el chip de cuenta queda solo con el icono y la flecha de «Ver todo» asoma por el borde
  derecho de la tarjeta. Se lee y se guarda. Sigue el criterio de Jürgen de no llevar accesibilidad a su tanda.

## Lo que va al iPhone de Jürgen

Solo la bienvenida desde cero (lo que pidió), con la cuenta nueva y «Eliminar mi cuenta»: necesita un teléfono real con
iCloud y Google, y el simulador no tiene sesión de nube.
