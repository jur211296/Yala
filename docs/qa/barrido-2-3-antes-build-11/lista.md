# Barrido de QA antes de la 2.3 (11) — 26-nov-2026

Sobre una mezcla local de `2.3` con el PR de la oferta Pro y el mazo centrado, que esperaba su CI con el auto-merge puesto.
Max, simulador iPhone 17 Pro (iOS 27.2) y un iPad Pro 11 creado y borrado para la pasada, scheme `Yala Dev`.

**El iPhone 14 estuvo bloqueado con código toda la sesión** (01:30–02:05, Lima). Device MCP respondía
«iPhone de JURGEN isn't ready (Locked)». La build quedó instalada en el teléfono, pero nadie pudo recorrerla.
Todo lo de abajo se probó en el simulador.

## Qué entró desde la build 10

| Cambio | Qué cambia para quien usa Yala | ¿Toca la app? |
|---|---|---|
| Observación en vivo del iPhone 14 | Bitácora y ticket; la fuente de los tres lotes | No |
| Lote 1 · cada paso cuenta bien | «Solo gastos» de cero sin cuenta creada sola; guía del primer registro con cuenta de dos monedas; el pago del mes que viene sale en el widget; ver las historias deja el paso 7 hecho; «Ahora no» en Grupos cuenta | Sí |
| Lote 2 · guías y avisos | Toque de historias en toda la zona; «… viven en Más» con la barra desplegada y Más destacado; foco del paso 6 y vuelta al Panel; la intro de Grupos no vuelve tras cerrar sesión | Sí |
| Lote 3 · pulido | Hoja «Otra moneda»; las siete etiquetas al mismo tamaño; nombre del presupuesto en dos líneas; intro de Grupos sin «paso 2 de 3»; el confeti no tapa «Cerrar»; «¡Listo por ahora!» con pasos para después; paywall sin precios con texto neutro | Sí |
| Maquetas de la oferta y el mazo | Solo documentos | No |
| Oferta Pro C y mazo B (PR abierto) | El mes gratis dentro de la tarjeta final; el mazo centrado con «Hola, <nombre>» en el paso 1 | Sí |

## Resultado

| Qué | Cómo | Resultado |
|---|---|---|
| Pruebas de interfaz de lo nuevo | `OfertaProMazoCentradoUITests`, `Bienvenida23FinalUITests`, `PrimerosPasosCuentaBienUITests`, `GuiasSenalanBienUITests`, `PulidoPrimerosPasosCapturasUITests` | **22/22** en 7 min 16 s |
| Pruebas unitarias de lo nuevo | 23 suites de los cuatro lotes y del paso 7 | **94/94** |
| Mazo centrado (B), simulador | Paso 1 con «Hola, Jürgen» en tema oscuro y claro; texto al máximo; iPad | Bien |
| Oferta del mes gratis (C), simulador | Con derecho y sin derecho (precios fingidos), tema oscuro y claro, texto al máximo, iPad | Bien |
| Giro del iPhone | La Max no tiene Simulator.app para girar; el centrado se anula solo si el bloque no cabe (`centeringOffset` da 0) | Sin captura |

El PR de la oferta decía «Verificado: ninguno» porque no pasó por el gate. Sus pruebas pasaron aquí, sobre la mezcla con `2.3`.

## Hallazgos

- **Texto al máximo, paso 1** (no grave, accesibilidad): el saludo ocupa media pantalla y el mazo queda a medio ver,
  con «PRIMEROS PASOS · 1 DE 7» partido en cuatro líneas. Se lee y se toca bajando. Criterio de Jürgen: no va a su
  tanda. Captura: `sim-b-paso1-textomax.png`.
- **La oferta de la tarjeta depende de que los precios ya hayan cargado** (leído en el código, no medido): si al
  completar el paso 7 la App Store aún no contestó, sube la hoja de antes y, al llegar los precios, la tarjeta muestra
  también la oferta. Pide completar los siete pasos antes de que respondan los precios: un caso de pocos usuarios. No se
  abre card.

## Lo que va al iPhone de Jürgen con la build 11

1. **El mes gratis real** (TestFlight, cuenta de Sandbox sin prueba usada): completar Primeros pasos, ver la oferta
   dentro de «¡Primeros pasos completos!», tocar «Empezar mi mes gratis» y llegar a la hoja de la App Store con
   «1 mes gratis». Lo retiene: pagar es flujo principal, y en Yala Dev no hay precios (el simulador los finge).
2. **Primeros pasos desde cero con cuenta nueva** en «Solo gastos» y en «Ingresos y gastos», con «Eliminar cuenta»
   antes. Lo retiene: la sesión de nube real (Apple o Google) no se monta en el simulador, y es lo que falló el 25-nov.

Lo demás de la lista del encargo (guías, historias, pulido, mazo, cifras del widget) queda cerrado por las pruebas y las
capturas de arriba.

## Capturas

`~/Claude/entregas/2026-11-26-barrido-qa-2-3-antes-de-build-11/evidencia/`: `sim-b-paso1-claro.png`,
`sim-b-paso1-claro-tema.png`, `sim-b-paso1-textomax.png`, `sim-c-final-conderecho-oscuro.png`,
`sim-c-final-conderecho-claro.png`, `sim-c-final-sinderecho-oscuro.png`, `sim-c-final-conderecho-textomax.png`,
`ipad-b-paso1.png`, `ipad-c-final-conderecho.png`.
