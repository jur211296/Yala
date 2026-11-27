# Barrido de QA de la 2.3 antes de la build 12 — 27-nov-2026

Sobre `2.3` en `1ef2fdadf` (ya con el pulido de Grupos y «Esto leí» y con Eficiencia 8). Max, simulador iPhone 17 Pro
(iOS 27.2) y el **iPhone 14 por Device MCP** (iOS 27.2, desbloqueado y con el candado de esta sesión), con una copia
`Release-Dev` optimizada y el almacén de pruebas de **16.004 movimientos**.

**Alcance (Jürgen, 27-nov, en el chat):** todo lo de 2.3 que no está en «done», no solo lo nuevo desde la build 11. Es
decir, las 42 cards en «in qa», los 18 tickets de `tickets/qa/` y, de las cards de bugs del backlog de 2.3, comprobar si
siguen pasando. Tope de pruebas: 2 h.

## Pruebas automáticas

| Qué | Resultado |
|---|---|
| Interfaz, lo nuevo y lo «in qa» que tiene prueba (16 clases: Compartido, Grupos, Flujo de caja, Nuevo registro, Favoritos, productividad, pago compartido, ayuda de Distribución, dividir boleta, convertir foto a compartido, enlace a un grupo en frío) | **43/43** en 18 min |
| Interfaz del pulido (Grupos y Personas sin gastos, «Esto leí» en grande y su recorrido) | **9/9** en 4 min |
| Unitarias de la nota de salud (10 suites, con la prueba nueva del arreglo) | **53/53** |
| Unitarias de toda la 2.3 | verdes en el CI del push a `2.3` (tres tandas) |
| Interfaz de la nota de salud (gate del arreglo) | ver «Gate» abajo |

La nocturna de interfaz lleva días saltada (el CI de UI está roto): la arregla la sesión siguiente, la de CI y subida de
la build 12. Por eso estas corridas en local son la única red de interfaz de hoy.

## En el iPhone 14

| Qué | Resultado |
|---|---|
| Arranque en frío con 16.004 movimientos | El Panel sale en ~3 s con el saldo y responde al dedo enseguida |
| Volver a Yala desde inicio | Vuelve al instante, en el mismo sitio |
| Panel, Flujo de caja y widget | **Cuadran.** Saldo S/ 370,493.03 en los tres. Inicio de mes S/ 374,277.78 en el Panel y en «Empezaste con». «Al 30 de noviembre tendrías S/ 369,333.05» = «Terminas con ≈ S/ 369,333.05». Widget «Este mes ↓ S/ 3785» = 374,277.78 − 370,493.03 |
| Flujo de caja | Abre en ~2 s, se desplaza fluido; «Crear mi plan» tarda ~2 s y luego la guía; ingresos 28,226.83 = salario 22,666.67 + facturación 5,560.16 (cobrada de más, toma lo real) |
| Nota de salud | «Lo que te queda» cuadra con el Flujo (entró 22,560.16, salió 17,472.01, queda 5,088.16) |
| Compartido sin datos | Chips Grupos y Personas, botones de registro arriba, vacío centrado; «Nuevo gasto» pregunta «¿Con quién?»; sin cuenta pide conectar Apple o Google (previsto) |
| «Esto leí» en grande | Fondo de card, deslizar asoma «Descartar», descarta con «Deshacer» y la otra tarjeta se queda |

## Hallazgos

1. **Arreglado en este PR — nota de salud con cuentas que se llaman igual.** Con tres cuentas en negativo llamadas
   «Cuenta Principal», la tarjeta decía «Cuenta Principal en negativo» tres veces. Ahora cada texto sale una vez.
   Prueba: `YalaTests/BarridoQA23AntesBuild12/NotaSaludCuentasConElMismoNombreTests.swift`.
2. **«Esto leí» con texto al máximo** sigue como dice su card (monto más chico que la descripción, chips cortados).
   Ya está en el encargo de arreglos 1 de 3 del fin de semana. Captura: `sim-esto-lei-texto-max.png`.
3. **Bugs del backlog que ya no pasan** (propuesta: cerrarlos): Panel y Flujo con distinto inicio de mes (medido hoy en el
   iPhone), el enlace a un grupo en frío (su prueba, verde hoy), «Considerar a futuro» entre teléfonos, dos suscripciones
   de la misma marca y la duración de los cuelgues en Sentry (los tres, arreglados con prueba en el código).
4. **«Crear mi plan» propone distinto con los mismos datos:** en el código la elección de líneas es determinista; lo
   más probable es que varíe la semilla de datos de prueba. Sin medir.
5. Los demás bugs del backlog siguen y casi todos ya tienen sesión en la cola (arreglos 1, 2 y 3 del fin de semana).

## Lo que va al iPhone de Jürgen con la build 12

Ver el artifact del barrido. Resumen: Compartido con su cuenta (persona sin grupo, invitar, foto de recibo y voz), el
rebote de Flujo de caja con el dedo, la nube real (Vaciar datos, «Eliminar cuenta», ida y vuelta a iCloud) y cuatro
vistos buenos (gastos hormiga, sugerencias, logos de suscripción, Yape en Yala IA).

## Capturas

`~/Claude/entregas/2026-11-27-barrido-qa-2-3-build-12/evidencia/`: `iphone-panel-proyectado.png`,
`iphone-widget-saldo.png`, `iphone-esto-lei-deslizar.png`, `sim-esto-lei-texto-max.png`.
