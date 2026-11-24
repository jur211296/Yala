Yala
# Bandeja: emparejador entre fuentes, lógica pura con la regla de coincidencia y pruebas de todos los escenarios
---
toca: Yala/App/Logic/InboxMatchLogic.swift,YalaTests/InboxMatchLogic/,tickets/backlog/2026-11-24-bandeja-emparejador-entre-fuentes.md,tickets/done/2026-11-24-bandeja-emparejador-entre-fuentes.md
esfuerzo: high
cierre: cierra-sola
depende: Yala/subir-testflight-2-3-build-8
---

Decisión de Jürgen (24-nov, 14:30 y 14:32 Lima): «vamos con todo lo recomendado» de `docs/propuestas/bandeja-sin-duplicados/README.md` (opción B, un pendiente por consumo), y los lotes 1 a 4 entran **en 2.3**, después de la subida a TestFlight de la build 8.

Decisiones ya tomadas (todas las recomendadas): unir solo en coincidencia fuerte, con «Separar» a un toque; si el importe difiere entre fuentes, manda el del banco; un planificado de monto fijo con cargo distinto pregunta, no se actualiza solo; grupos y cuentas compartidas quedan fuera (el emparejador ignora los borradores de grupo).

## Qué se pide
Lote 1 del plan (sección 5). Lógica pura `InboxMatchLogic`, sin UI: la regla de coincidencia fuerte y dudosa de la sección 3·B (tipo, cuenta, importe, tiempo, comercio, fuentes), emparejamiento uno a uno, dos borradores de la misma fuente nunca se funden, y qué fuente manda campo a campo (importe y moneda del banco, comercio de Apple Pay, hora de Apple Pay o del aviso, cuenta de quien traiga tarjeta o últimos 4). Pruebas en `YalaTests/InboxMatchLogic/` con todos los escenarios del informe (E1 a E8 y los casos difíciles: dos compras reales iguales, reversas, cuotas, cargos parciales, aviso después de un registro manual). El artifact puede ser la tabla de escenarios con el resultado de cada prueba.

## Cómo entregar
- Un PR contra 2.3, sin firma de IA. Deja el auto merge activado y cierra; no esperes al CI.
- **Entregable visual:** artifact público de Claude (capturas o flujo según el lote). Pon el link en «Qué salió».
- Si necesitas un archivo fuera de `toca:`, tócalo solo si es imprescindible y anótalo en «Decidido sin consultar». Si cambian textos, ponte al día con el catálogo de 2.3 antes del PR y agrega las claves en todos los idiomas.
- Pruebas en el iPhone 14 (DeviceMCP, conectado a la Mini): verifica primero que esté libre; si no, usa un simulador (en la Max puedes usar un segundo simulador además del de otra sesión; en la Mini, uno solo).
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Lo vital, según el modo fijado al arrancar: en semi preguntas y esperas con la sesión viva; en nocturno dejas un checkpoint recuperable y una card «Espera decisión».
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Paso 0 — decisiones

> Modo semi, sesión sin Jürgen delante: las respondo con mi recomendación porque todas son técnicas y reversibles, ninguna es de producto. Se discuten en el PR.

**D1 · ¿La lógica habla con el modelo (`InboxDraft`) o con un tipo propio?** → Tipo propio (`Candidate`) con fuente, importe con signo, moneda, fecha, «¿trae hora?», cuenta, últimos 4 y comercio. Solo una función `source(for:isBankNotice:)` traduce del `DraftSourceType`.
Por qué: así es pura y se prueba sin `ModelContext`. El lote 2 traduce al llegar. Alternativa descartada: leer `InboxDraft`, que ata el lote 1 a SwiftData y a la migración del lote 2.

**D2 · ¿Qué fuentes entran?** → Apple Pay, aviso del banco, correo del banco, IA y web (las del lote 2), más `manual` para lo ya guardado de origen desconocido. Fuera: grupos (decisión 7), planificados y suscripciones (lote 4), y Siri, voz, foto y capturas.
Por qué: la propuesta cablea esas cinco. Siri no deduplica a propósito. Alternativa descartada: meter Siri, que vuelve a juntar dos gastos reales dictados.

**D3 · E7 (planificado estimado + correo) en el lote 1** → No se empareja aquí: el planificado no tiene `Source` y la prueba lo deja fijado como frontera del lote 4.
Por qué: casar con planificados tiene reglas propias (±5 días, alias aprendido, estimado) que son el lote 4. Alternativa descartada: adelantar el lote 4 dentro de este, que crece el alcance sin pedirlo.

**D4 · Con un consumo ya unido, ¿lo que llega se compara contra cada miembro o contra lo que manda?** → Contra el resultado (lo que manda en cada campo), y su fuente tiene que estar libre.
Por qué: un consumo «Apple Pay en dólares + correo en soles» compara en soles con el aviso que llega, no pregunta otra vez por la moneda. Alternativa descartada: el mínimo entre miembros, que degrada a «dudosa» todo lo que toca un miembro en otra moneda.

**D5 · Tiempo cuando ninguno trae hora (IA y correo)** → Fuerte solo el mismo día; dudosa hasta 3 días.
Por qué: la regla de la propuesta («ese día o el siguiente») está pensada para una compra con hora y un correo que asienta después. Entre dos fechas sin hora no hay dirección. Alternativa descartada: ±1 día fuerte, que uniría solo dos cafés de días seguidos.

**D6 · Moneda sin decir (un `$` suelto)** → Nunca une solo: mismo número sale «dudosa».
Por qué: puede ser otra moneda con el mismo número. Otra moneda sin tasa disponible: no se parecen.

**D7 · Lo ya guardado** → Siempre pregunta («Ya registrado»), fuerte o dudosa, nunca se une solo. Un pendiente fuerte gana a lo guardado; lo guardado fuerte gana a un pendiente dudoso.
Por qué: así lo dibuja la propuesta («Descartar / Guardar igual»). La misma fuente tampoco cuenta aquí: un Apple Pay guardado no frena otro Apple Pay igual.

**D8 · Empate entre dos pendientes fuertes** → El más cercano en el tiempo, luego en el importe, luego el que llegó antes.
Por qué: determinista y, en las dos compras reales iguales, da a cada aviso su compra.

**D9 · Qué fuente manda entre las dos del banco** → El correo antes que el aviso para el importe (es el cargo asentado); el aviso antes que el correo para la hora (la trae).

**D10 · Índice de QA (`qa/coverage-index.json`)** → Se toca aunque esté fuera de `toca:`, porque el `CLAUDE.md` lo pide en el mismo commit de código bajo `Yala/`. Va en «Decidido sin consultar».

Nada de esto pide ADR: el lote 2 lo recoge y el código lleva la regla escrita arriba.
