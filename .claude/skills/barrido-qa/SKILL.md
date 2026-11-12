---
name: barrido-qa
description: Barrido de QA de Yala — vaciar la cola «in qa» antes de una tanda de Jürgen con el filtro más duro posible. Prueba en el simulador lo que se pueda, cierra lo que ya fijan los tests y le deja solo lo grave que el simulador no reproduce, más las preguntas de visto bueno. Úsala al pedir un barrido de QA o preparar la tanda de Jürgen.
---

# Barrido de QA

**Principio (Jürgen, 2026-10-24): probar lo menos posible.** A Jürgen solo le llega lo que **puede afectar gravemente
a un flujo** y **además no se puede probar bien en el simulador ni con tests**. Todo lo demás se cierra en el barrido:
se confía en el código y en las pruebas, y pasa a `done`.

Los dos errores que corrige esta skill:

- **10 y 12-oct:** los barridos trabajaban sin simulador y solo cerraban lo que ya traía pruebas. Lo que se podía
  probar en el simulador se quedaba en la tanda. **Un barrido que no prueba nada no filtra nada.**
- **24-oct:** el filtro era blando. Cards con XCUITest del flujo entero, edge cases raros o cosas que el simulador
  reproduce se quedaban «por si acaso» o «por sesión real». **Ante la duda, el item no va a la tanda.**

## 1. Inventario

1. `tablero listar --proyecto Yala --todas` → todas las cards en `in qa`.
2. `tickets/qa/` en `origin/<rama de release>`.
3. PRs mergeados desde el último barrido: `gh pr list --state merged --base <rama> --search "merged:>=AAAA-MM-DD"`.
4. Para cada item, anota **en qué build está su arreglo**: el último TestFlight (`asc` o la nota del encargo de
   subida) o solo `origin/<rama>`. Lo que no está en TestFlight se prueba en Yala Dev.

## 2. Decisión por item: el primer caso que encaje gana

| # | Caso | Destino |
|---|---|---|
| 1 | Es de **accesibilidad o de tamaños**: Dynamic Type, layout por tamaño de texto o de pantalla, contraste, VoiceOver, Reducir movimiento | **done** sin probar. Jürgen confía en el código para esto. Motivo: «accesibilidad/tamaños, criterio de Jürgen». |
| 2 | Es un **edge case imposible o muy difícil de provocar a mano**: techos de horas o días, fallos inyectados, carreras, kills en un instante preciso | **done** si lo fija un test unitario o de integración con su mutante muerto. Si no hay test, escríbelo: el barrido no lo deja a Jürgen. |
| 3 | Es un **edge case de muy pocos usuarios**: un camino improbable, un porcentaje bajo del parque, aunque se pudiera provocar | **done** si hay test o si el código es claro. No va a la tanda. Motivo: «edge case de pocos usuarios». |
| 4 | **Ya hay un test del flujo completo**: un XCUITest o un test de integración que recorre el hechaCuando contra el código real, o goldens, o capturas del antes y el después | **done**, citando el test o la ruta de la captura. Que el flujo pida «sesión real», «cuenta real» o «iCloud» **no lo retiene** si el test ya cubre el flujo. |
| 5 | **El simulador lo reproduce correctamente** | **Pruébalo tú en el barrido** (§3). Si pasa, **done** con la evidencia. Si falla, card de bug y el item sigue en qa. **No** se deja también en el iPhone «por si acaso». |
| 6 | Necesita **visto bueno visual o de identidad** de Jürgen: un rediseño, copy nuevo, una pantalla que él no ha visto | **No va a la tanda del iPhone.** Haz las capturas en el simulador y deja la pregunta lista para Frank (§6). Queda en qa hasta que diga que sí. |
| 7 | Pasa el **filtro doble de §4** | **Se queda para Jürgen**, con guion (§5). |
| 8 | Es una **decisión** suya (card «Decidir …») | Si ya está tomada e implementada, **done**. Si no, se queda y se dice qué falta decidir. |

**El paso termina cuando cada item tiene destino, motivo y evidencia** (test, captura o la pasada de §3). Un item sin
evidencia no está decidido: vuelve a la tabla.

**Lo que toca dinero, migraciones o borrado de datos ya no se queda solo por eso.** Necesita evidencia fuerte, y esa
evidencia la produce el barrido: un test de integración o una pasada en el simulador con el antes y el después. Se queda
para Jürgen solo si además pasa el filtro doble de §4.

## 3. Cómo se prueba en el simulador

- **Un simulador como máximo.** Antes de encender uno, mira si otra sesión lo está usando
  (`xcrun simctl list devices booted` y las sesiones vivas). Si está ocupado, espera; no lo apagues tú.
- Las herramientas y el arranque del simulador, como en `/qa`.
- Siembra con `DevSeed*` / `-uitest-*`. Nunca contra CloudKit de producción.
- Para cada item probado guarda: el paso, lo que se esperaba, lo que salió y la captura en `_capturas/<slug>/`.
- Si el flujo merece red permanente y es determinista, escribe el XCUITest en vez de conducirlo a mano.
- Al terminar: `xcrun simctl shutdown all` y borrar los simuladores que creaste.

## 4. Lo único que se queda para el iPhone de Jürgen

**Filtro doble.** Un item solo se queda si cumple **las dos** condiciones:

1. Un fallo tendría **impacto grave en un flujo principal**: perder o duplicar datos, no poder entrar, no poder
   pagar, la sincronización rota.
2. **No se puede validar bien** ni en el simulador ni con los tests que ya hay: la parte que importa no se monta ahí.

Si cumple una sola, va a `done`. Cada item de la tanda dice qué parte de esta lista lo retiene y por qué el simulador
no basta.

Ejemplos que **sí** pasan el filtro:

- **Dos dispositivos físicos** (grupos, sincronización entre teléfonos).
- **iCloud real** en un punto concreto: la importación real del espejo, cambiar de Apple ID, apagar iCloud Drive.
- **Compras con StoreKit en sandbox** cuando el seam del simulador miente sobre lo que importa.
- **Notificaciones push, Apple Pay o Siri por voz** cuando el simulador no reproduce la integración.
- **Actualizar encima** de un build anterior de TestFlight, si toca migración.
- **Inicio de sesión real, Face ID o App Attest** solo si la parte que importa no se monta en el simulador **y** el
  fallo rompería un flujo principal. Que sea «más realista» no basta.

Ejemplos que **no** bastan solos:

- «Hace falta una cuenta real» cuando ya hay un XCUITest del mismo flujo.
- «App Attest» solo para cronometrar o confirmar, si el simulador ya cubre el camino feliz.
- «Por si acaso», «para verlo en un teléfono de verdad» o «el simulador es menos realista».

**App Store Connect, legal o la ficha** van aparte, al final, sin iPhone.

Si dudas entre §4 y «se puede en el simulador», prueba en el simulador. Se queda solo si el simulador no reproduce la
parte que importa **y** esa parte es grave.

## 5. El guion de lo que se queda

Cada paso se **verifica contra el código antes de escribirlo**. El 15-oct una prueba pedía «un pago programado con
fecha de ayer», y el editor no permite fechas pasadas en un pago nuevo (`minDate: today`): el paso era imposible.

- Lenguaje de usuario, sin jerga. Rutas con los textos reales de la app (`es.lproj/Localizable.strings`).
- Solo pasos de función: la accesibilidad y los tamaños ya salieron en §2.1.
- Por item: qué build usar, cuánto tarda, si bloquea el lanzamiento y por qué no se pudo cerrar en el barrido.
- Agrupa por **montaje**: el mismo estado del teléfono, una sola vez. Orden: lo que bloquea primero, luego Yala Dev
  contra staging, luego TestFlight, luego dos dispositivos, y al final lo que no pide iPhone.
- Datos de prueba ya preparados en `~/Claude/entregas/<slug>/` (CSV, PDFs, imágenes), y dicho cómo pasarlos al
  teléfono.
- **Los vistos buenos no entran en la tanda.** Van por su propio canal (§6).

## 6. Cierre

1. Tickets cerrados: `git mv tickets/qa/X.md tickets/done/` con la línea
   «Cerrado en el barrido de QA AAAA-MM-DD: <motivo>». Tickets nuevos de QA, con su guion. `docs/TICKETS.md` al día.
2. Cards cerradas: `tablero mover <id> --a done --agente frank`. **`--nota` sustituye la nota entera**: léela antes con
   `tablero ver` y repite lo que había.
3. Escribe `docs/qa/tanda-qa-jurgen-<versión>.md` con:
   - resumen: revisados, cerrados, probados en el simulador, preguntas de visto bueno y para el iPhone, y el tiempo
     total;
   - la tabla de bloqueantes;
   - las pruebas por grupo;
   - **dos tablas al final:** lo que pasó a done (id, motivo y evidencia) **y lo que se queda (id y qué parte del
     filtro doble de §4, o qué visto bueno de §2.6, lo retiene)**. Sin esta segunda tabla no se puede auditar el
     barrido.
4. **Vistos buenos de §2.6.** Deja las capturas en `_capturas/<slug>/`, una carpeta por pregunta. En el cuerpo del PR
   añade la sección **«Preguntas de visto bueno pendientes para Frank»**: por pregunta, la card, qué se pregunta en una
   frase y la ruta de sus capturas. Frank, el bot, se las manda a Jürgen **una pregunta por mensaje, con sus fotos**, y
   él aprueba al momento. Las capturas pueden ir juntas en disco; hacia Jürgen nunca van en un solo lote. No las
   mandes a `/qa-guiado`.
5. PR a la rama de release y `/cerrar-total`. En MODO AUTÓNOMO, en cola de auto-merge.
6. En el aviso de cierre, di que la tanda del iPhone está lista para `/qa-guiado` (esa sesión la lanza Jürgen cuando
   vaya a probar) y que las preguntas de visto bueno esperan a Frank en el PR.

**Señales de que el barrido salió mal.** Si al repasar la tanda encuentras alguna, saca el item y vuelve a §2:

- una prueba que se puede hacer entera en el simulador;
- un edge case de pocos usuarios;
- un paso de accesibilidad o de tamaños;
- una card con XCUITest o test de integración del flujo completo que se queda «por sesión real» o «por cuenta real»;
- un item que no cumple las dos condiciones del filtro doble de §4;
- una pregunta de visto bueno metida en la tanda del teléfono.
