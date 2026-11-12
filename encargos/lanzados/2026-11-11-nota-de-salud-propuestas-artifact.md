Yala
# Artifact visual de las 6 propuestas de la nota de salud para que Jürgen decida
---
toca: docs/propuestas (solo el artifact; sin código de la app)
cierre: cierra-sola
---

## Qué hay que hacer
Jürgen pidió que la propuesta de mejoras de la nota de salud del Panel le llegue como **artifact visual de Claude**, no como Markdown. Es una mini sesión: no se implementa nada en la app.

Fuente: el documento `propuestas-nota-de-salud.md` que dejó la sesión «Lote 2.3 panel nota de salud» (PR 904, adjunto en #yala). Si está en el repo o en los archivos de esa sesión en la Max, úsalo de ahí; si no, su texto íntegro va al final de este encargo. Las cifras «de hoy» salen de `FinancialScoreCalculator` en `origin/2.3`: comprueba rápido que sigan siendo ciertas antes de mostrarlas.

## El artifact debe
- Mostrar en una vista lo que mide hoy la nota (las tres partes, su peso y su punto débil) y la contradicción del suelo de 50 frente a «de 0 a 100».
- Presentar las 6 propuestas como tarjetas comparables: qué ve hoy la persona, qué cambia, esfuerzo, efecto en las notas actuales y recomendación. Marcar como recomendadas la 1 (Ritmo cuenta días desde el último registro) y la 3 (pasarse pesa según cuánto).
- Incluir ejemplos visuales con números (antes y después) por propuesta, por ejemplo con una mini simulación interactiva: quien registró los días 1 a 3 y nada más, o pasarse por S/ 1 frente al doble.
- Mostrar el orden propuesto (1 y 3, luego 5a, después 2 y 6; la 4 con datos) y «Lo que no recomiendo».
- Terminar con un bloque claro para decidir: casillas o selector por propuesta (sí / no / después), para que Jürgen responda rápido.
- Todo en español neutro latinoamericano, sin ids, visual y fácil de decidir. Puedes usar las capturas antes y después de esa sesión si ayudan.

## Entrega y cierre
- Publica el artifact como corresponde en la flota y deja su enlace en el cierre y en la card «Decidir qué mejoras lleva la nota de salud» del tablero (comentario con `tablero comentar … --agente frank`). Esa card queda abierta esperando la decisión de Jürgen; no la muevas a hecha.
- No implementes ninguna propuesta ni abras PR de código.
- Lo menor y reversible lo decides tú y lo anotas en «Decidido sin consultar». Al terminar, en el mismo turno, ejecuta `/cerrar-total`. Escribir el reporte no es cerrar.

## Texto íntegro de la fuente
# Nota de salud: propuestas de mejora (para decidir)

La primera parte de la decisión 9 de la revisión 2.3 ya está hecha (lote del 11-nov). Esto son propuestas. Nada está implementado.

## Lo que la nota mide hoy
| Parte | Peso | Qué mira | Su punto débil |
|---|---|---|---|
| Presupuestos | 40 % | Cada presupuesto vale 100; pasarse resta 8, rozar el límite al final resta 3 | Pasarse por el doble sigue dando 92 |
| Ritmo | 25 % | La racha más larga sin registrar entre dos días con registros | No mira los días desde el último registro hasta hoy |
| Compromisos | 35 % | Si el saldo cubre los pagos pendientes, y cuánto de lo que entra se va en ellos | Sin ingresos, la mitad vale 50 fijo |
La nota total nunca baja de 50, aunque Configurar Panel la describe «de 0 a 100».

### 1. Ritmo: contar también los días desde el último registro (recomendada, esfuerzo bajo)
Hoy: quien registró los días 1, 2 y 3 y nada más ve Ritmo 100 el día 25. Con un solo día de registros, también 100.
Cambio: el hueco hasta hoy cuenta como cualquier otro (en un período en curso).
Coste: un cambio en computeMaxGap y sus tests. Bajarán las notas de quien dejó de registrar.

### 2. Una parte nueva: lo que te queda del mes (tasa de ahorro) (recomendada, esfuerzo medio)
Hoy: la nota no mira si gastas más de lo que entra.
Cambio: «Te queda» del período (entró − salió) sobre lo que entró. Ej.: 20 % o más vale 100; 0 % vale 50; gastar más de lo que entra baja de 50.
Coste: pesos nuevos para cuatro partes, textos en 16 idiomas, decisión para «Solo gastos» (la parte no cuenta).

### 3. Pasarse de un presupuesto pesa según cuánto (recomendada, esfuerzo bajo)
Hoy: pasarse por S/ 1 o por el doble del límite da lo mismo: 92.
Cambio: 100 % del límite vale 90; 150 %, 50; el doble o más, 0.
Coste: solo scoreForBucket y sus tests.

### 4. Cuentas en rojo dentro de la nota (opción D, esfuerzo medio-alto)
Hoy: la tarjeta las nombra pero la nota no baja.
Cambio: una cuenta en negativo (sin tarjetas de crédito) resta en Compromisos, o es una cuarta parte.
Coste: decidir qué es «rojo» de verdad (sobregiro, préstamo, efectivo mal apuntado). Recomienda esperar datos reales (inferido: muchas son efectivo no apuntado como ingreso).

### 5. Quitar el suelo de 50 o pasar a niveles (opción C, esfuerzo medio)
Hoy: «La nota total nunca baja de 50» frente a «de 0 a 100».
Cambio: (a) quitar el suelo; (b) «Bien · Atento · Revisa» en vez del número.
Coste: (a) una línea y un texto; (b) rehace tarjeta, hoja y textos.

### 6. Visibilidad: la nota en el Panel y su evolución (esfuerzo medio)
Hoy: la sección llega apagada en el Panel (PanelDefaults.hiddenSections); se ve en Estadísticas › Resumen.
Cambio: encenderla por defecto cuando 1-3 estén dentro, y una línea «subió 6 desde el mes pasado».
Coste: calcular la nota del período anterior y decidir el texto.

## Lo que no recomienda
- Más partes de golpe: ya no se entiende de dónde sale el número.
- Comparar con «la media de usuarios»: no hay ese dato sin mandar finanzas a un servidor.

## Orden propuesto
1 y 3 primero, luego 5a, después 2 y 6. La 4 se decide con datos.

## Paso 0 — decisiones (resueltas en semi, menores y reversibles)

- **Fuente:** `docs/ux/revision-vistas-2.3/30-panel/propuestas-nota-de-salud.md` de `origin/2.3`; cifras medidas en `FinancialScoreCalculator` de esa rama (pesos 40/25/35, suelo 50, −8 al pasarse, Ritmo = 100 − (hueco−2)×12, sin ingresos la carga vale 50). Coinciden con la fuente.
- **Formato:** página HTML propia (no un tipo de artifact): tarjetas + simuladores + bloque de decisión.
- **Respuesta de Jürgen:** se guarda en la base del artifact (`decision/jurgen`), escritura solo del dueño; Frank la lee con ArtifactData.
- **Orden de tarjetas:** el del plan (1, 3, 5, 2, 6, 4); 5a y 5b se deciden por separado.
- **Curva de la 2 por debajo de 0 %:** la fuente no la fija; el ejemplo usa −50 % → 0 y lo dice en la tarjeta.
- **Decisión pendiente (propuestas como artifact visual):** va a la memoria de Frank como forma de trabajar con Jürgen; viaja en el PR de memoria.
- **Sin código de la app:** el único PR es el de la memoria.
