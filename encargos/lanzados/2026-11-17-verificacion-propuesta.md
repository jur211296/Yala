Yala
# Comparar cómo verificamos en Yala con el artículo de verificación de Claude Code y proponer qué adoptar
---
toca: docs/verificacion/, tickets/done/2026-11-16-verificacion-propuesta.md
esfuerzo: high
cierre: cierra-sola
---

## Qué pidió Jürgen (16-nov, 20:56 Lima)
Compartió https://claude.dev/blog/how-the-claude-code-team-thinks-about-verification/ y aprobó una sesión que compare nuestra verificación actual con el artículo y traiga una propuesta visual para decidir qué adoptar. Contexto: hoy entraron unos 56 merges en 2.3 en dos días y quedaron tres pruebas de UI en rojo en las tandas 1, 8 y 9, porque esa suite solo avisa y los encargos no corrieron esas clases en su gate (ya hay otra sesión encolada que arregla esas tres pruebas; esta NO las arregla).

## Qué hacer
1. Lee el artículo completo.
2. Haz un inventario real de cómo verificamos hoy, con evidencia del repo: `/gate`, skills de verificación, hooks (`.githooks`), sello de verificación en commits si existe, workflows de CI (QA, tandas de UI con `-retry-tests-on-failure`, «¿Se ha enterado alguien de los rojos de test?», vigilante de la nocturna), REVIEW/CLAUDE.md, reglas de `swiftdata-cloudkit.md`, review adversarial, uso de simulador, iPhone 14 por DeviceMCP y lecciones.
3. Para cada práctica del artículo, compárala con lo que tenemos: gate según el diff, pruebas E2E con el simulador o el dispositivo, property tests, differential tests (por ejemplo en las migraciones a la nube), no reintentar las pruebas inestables hasta que pasen, «humano tras tres rondas», checklist de confiabilidad con disparadores leídos del diff, un solo revisor con varias rondas, reglas que el cambio no puede modificar, modos apagado, observar y obligatorio para los gates nuevos, sello de verificación en cada commit, revisar a los revisores con reverts, convertir lo que se escapó en reglas y podarlas.
4. Mide con datos de 2.3 de las últimas dos semanas: rojos de CI, pruebas que solo pasaron al reintentar, reverts o arreglos de bugs ya mergeados, y qué gate los habría atrapado.
5. Propón entre 3 y 6 cambios ordenados por impacto y costo, cada uno con su recomendación y qué sesión lo implementaría. Esta sesión no implementa nada en el código ni en CI; solo documenta y propone.

## Entregable
Un artifact visual de Claude (no Markdown ni PDF), fácil para decidir: tabla de práctica contra lo que tenemos hoy, evidencia, impacto y recomendación, con opciones claras para que Jürgen apruebe una por una. Guarda la fuente en `docs/verificacion/` y el ticket de cierre en `tickets/done/2026-11-16-verificacion-propuesta.md`.

## Recursos
- Puedes usar el iPhone 14 conectado por DeviceMCP. Si corres en la Max y otra sesión ocupa un simulador, puedes usar un segundo simulador (tope 2 en la Max; 1 en la Mini).
- Commits y PR sin firma de IA.

## Cierre
- El modo queda fijo al arrancar (nocturno 20:00–05:30, semiautónomo 05:30–20:00, hora Lima). Lo menor y reversible lo decides y lo anotas. En semi, lo vital se pregunta y esperas con la sesión viva; en nocturno, lo vital deja checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear ni declarar completo lo incompleto.
- Si el trabajo está completo y el modo lo permite, `/cerrar-total`. El cierre incluye «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones

> Modo semi, sin Jürgen delante: resueltas con la recomendación de Frank. Se discuten en el PR.

**D1 · ¿Qué tipo de artifact?** → Página HTML propia con selector Sí / No / Después y nota por propuesta, guardado en la base del artifact (`db`).
Por qué: es lo que pidió el 11-nov para propuestas (tarjetas, antes/después, selector en la db) y deja su voto legible para la sesión que implemente. Alternativa descartada: el tipo «Docs» o «Data», que no traen un voto por fila.

**D2 · ¿Dónde vive la fuente?** → `docs/verificacion/propuesta-2026-11-17.html` (la página publicada) + `docs/verificacion/README.md` (inventario, mediciones y comandos que las produjeron).
Por qué: el encargo pide la fuente en `docs/verificacion/`; el README deja la evidencia en texto que se puede buscar con grep.

**D3 · ¿Cómo se entrega?** → Rama + PR en cola de auto-merge, aunque el diff sea solo `docs/`, `tickets/` y `encargos/`.
Por qué: el PR es donde viaja el parte, la memoria de Frank y el Paso 0; el CI de un diff sin código es corto. Alternativa: commit directo a `2.3`, que la regla permite pero deja sin parte.

**D4 · ¿Se corre el gate?** → Solo el paso 5 (índice de QA), que es lo que el gate exige para un diff sin código. No hay pruebas de interfaz en esta sesión: el presupuesto de UI no aplica.

**D5 · Datos de CI: ¿ventana?** → Desde el 2026-11-03 hasta hoy, sobre `2.3` y sus PR. Lo medido y lo inferido se marcan aparte en el artifact.

**D6 · Decisiones pendientes del 17-nov 06:17** → Se registran en `docs/DECISIONS.md` como un lote; no se ejecutan. `decisiones.py` no está en la Max: el registro del lote queda en «Necesita de ti». La revisión del video v4 de Gmail que Jürgen delegó en Frank no es de este encargo: queda anotada para su propia sesión.
