---
esfuerzo: medium
---
# Actualizar skill `/barrido-qa`: criterio estricto Jürgen 24-oct (mínimo QA)

**Solo docs.** Sin simulador. PR a **2.2**. `/cerrar-total`.

## Contexto
Jürgen 2026-10-24 13:39 Lima (1:1 con Frank): quiere probar **lo menos posible**, solo lo indispensable. Dice que el skill debería quedar así. Welcome A+B puede estar viva en paralelo: **no uses simulador ni xcodebuild**.

Skill actual: `.claude/skills/barrido-qa/SKILL.md` (lee `origin/2.2`).

## Qué se pide
Reescribe/ajusta la skill para que el filtro sea más duro. Mantén la estructura (inventario → tabla de decisión → sim → §4 → guion → cierre), pero incorpora esto **literal en espíritu**:

### Principio
A Jürgen solo le llega lo que **puede afectar gravemente un flujo** y **además no se puede probar bien en el simulador**. Todo lo demás: confía en el código y en las pruebas → `done`.

### Endurecer la tabla (§2)
- Accesibilidad **y tamaños** (Dynamic Type, layout por tamaño, contraste, VoiceOver, Reducir movimiento) → done sin probar (ya está; deja claro «tamaños»).
- Si hay **test del flujo completo** (XCUITest / integración) que fija el hechaCuando → done (refuerza caso 3; «sesión real» no gana si el test ya cubre el flujo).
- Si el **simulador lo replica correctamente** → el barrido lo prueba y cierra (caso 4); **no** se queda «por si acaso» en el iPhone.
- **Edge case de muy pocos usuarios** (improbable, % bajo) → done si hay test o el código es claro; **no** va a la tanda. Añade una fila nueva o amplía el caso 2.
- «Inicio de sesión real / App Attest / iCloud» **solo** retienen si la parte que importa **no** se puede montar en el sim **y** el fallo sería grave para un flujo principal. Si solo es «más realista», no basta.

### §4 — lista más estrecha
Deja la lista, pero abre con: **filtro doble** = (1) impacto grave en un flujo principal **y** (2) imposible de validar bien en sim/tests. Ejemplos que sí quedan: dos dispositivos físicos, iCloud real puntual (espejo/import/Apple ID), compras sandbox cuando el seam miente, push/Apple Pay/Siri por voz cuando el sim no reproduce. Ejemplos que **no** bastan solos: «hace falta cuenta real» si ya hay XCUITest del mismo flujo; «App Attest» solo para cronometrar si el sim ya cubre el camino feliz.

### §5 / vistos buenos — cambio de proceso
- **No** meten la tanda de teléfono.
- Frank (el bot) manda **un mensaje 1:1 por cada pregunta** con las fotos; Jürgen aprueba al tiro.
- En el cierre del barrido: deja las capturas listas en `_capturas/<slug>/` y en el resumen del PR lista «preguntas de visto bueno pendientes para Frank»; **no** digas que van en `/qa-guiado`.
- Quita o corrige «un solo lote» si choca: el lote de archivos puede existir, pero el canal hacia Jürgen es **una pregunta por mensaje**.

### Señal de barrido malo (ampliar)
Además de «prueba 100 % simulable en la tanda»: también es fallo dejar edge cases raros, accesibilidad/tamaños, o cards con XCUITest del flujo completo «por sesión real».

### Memoria del agente
Añade/actualiza una línea corta en `.claude/agent-memory/frank/` (feedback) citando la fecha y el criterio, para que las sesiones futuras no aflojen el filtro.

## Qué NO hay que tocar
- Código de app, tests, marketing/, CloudKit, deploys.
- No relances un barrido de cards ahora: solo el skill (+ feedback).
- No apagues la sesión Welcome ni uses el sim.

## Cómo se sabe que está bien
- Skill en 2.2 con el criterio estricto y el proceso de vistos buenos por mensaje.
- PR a 2.2; `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, bypass)

- **Ficheros:** `.claude/skills/barrido-qa/SKILL.md` (reescritura) · `.claude/agent-memory/frank/feedback_barrido_filtro_doble_minimo_qa.md` (nuevo) · `MEMORY.md` de Frank (una línea).
- **Edge case de pocos usuarios:** fila nueva (caso 3), separada del caso 2 (difícil de provocar), porque su criterio de cierre es más laxo: basta test **o** código claro.
- **Orden de la tabla:** «test del flujo completo» sube antes de «simulable», y el filtro doble de §4 pasa a ser un caso explícito antes de las decisiones.
- **Vistos buenos:** capturas en `_capturas/<slug>/` una carpeta por pregunta; sección «Preguntas de visto bueno pendientes para Frank» en el PR; nunca a `/qa-guiado`.
- **`/qa-guiado` y `CLAUDE.md`:** no se tocan; no chocan con el cambio.
- **Va por PR** aunque sea solo docs: `.claude/` está fuera de la lista de directo-a-2.2. Sin código → no hay build; el gate se reduce a la validación del índice.
