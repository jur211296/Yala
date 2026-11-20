Yala
# Maquetas para decidir: paso 7 de Primeros pasos, la sheet de los 7 pasos, coach tips de Ajustes y Pro, y cuándo regalar los 30 días de Pro
---
toca: docs/maquetas/primeros-pasos-paso-7-y-prueba/,tickets/backlog/2026-11-19-primeros-pasos-paso-7-y-prueba-maquetas.md,tickets/done/2026-11-19-primeros-pasos-paso-7-y-prueba-maquetas.md
esfuerzo: medium
cierre: cierra-sola
depende:
---

Rama base: 2.3. Sesión de maquetas: no cambia código de la app. Jürgen tiene que decidir cuatro cosas de los Primeros pasos y necesita verlas para elegir. Arma maquetas realistas con lo que ya tiene la app (mismos componentes, colores, tipografía y textos de 2.3; mira el código y captura la app actual en el simulador o en el iPhone 14). Para cada tema muestra la versión actual capturada, 2 o 3 alternativas y tu recomendación con el motivo.

## 1. Paso 7 (tutoriales)
Jürgen: el paso 7 tiene que aclarar mucho mejor, de forma intuitiva, que son tutoriales. «Añade el widget» suena agresivo y no se muestran ejemplos de los widgets. El paso de Apple Pay no dice nada: una línea como «cada pago llega a tu bandeja» no vende ni convence. Lo mismo pasa con compartir y con Siri. Propón cómo presentar cada tutorial (widgets, Apple Pay, compartir y Siri) con un ejemplo visual concreto, un beneficio claro y una acción suave.

## 2. La sheet de los 7 pasos
A Jürgen no le gusta nada la sheet que lista los 7 pasos. Captura la actual y propón alternativas (otra forma de ver el progreso, o directamente quitarla si el Panel progresivo ya cumple esa función).

## 3. Coach tips de Ajustes y de Pro
¿Se quitan o se mejoran? Muestra cuándo y cómo aparecen hoy, y compara quitarlos con 1 o 2 mejoras concretas. Recomienda una opción.

## 4. Sheet de prueba de 30 días de Pro
Hoy nunca se muestra la sheet que regala los 30 días de prueba. Busca en el código cuándo debía salir (por ejemplo `CourtesyTrial.swift`) y por qué no sale. Propón el momento: al completar el paso 7 u otra alternativa. Maqueta también la sheet.

Entrega: un artifact visual de Claude con las cuatro decisiones, cada una con su sección «Tu decisión» y las opciones claras. No implementes nada; la implementación se encola después, según lo que elija Jürgen.
Card: «Maquetas: paso 7, sheet de los 7 pasos, coach tips de Ajustes y Pro, y prueba de 30 días».

## Cómo trabajar
- iPhone 14 (Jürgen, 19-nov): queda conectado a la Mini para cualquier sesión de cualquier máquina vía DeviceMCP. Antes de recurrir al simulador, verifica de verdad si está libre (que responda y que ninguna otra sesión lo esté usando en ese momento); no lo des por ocupado sin comprobarlo. Si lo usas, suéltalo al terminar.
- Textos nuevos en su propia tabla, nunca en Localizable.strings. Nunca un botón debajo de otro.
- En la Max puedes usar un segundo simulador además del de otra sesión, o el iPhone 14 por DeviceMCP; en la Mini, uno solo. No uses `-derivedDataPath /tmp/claude-*`.
- Nada en producción (ni CloudKit ni Supabase).
- Commit y PR sin firma de IA, contra 2.3. Deja el auto merge activado y no cierres hasta ver el PR dentro de 2.3. Si hay conflicto o el CI falla por tu PR, arréglalo tú. Si tras unos 45 minutos el CI sigue rojo por algo ajeno, cierra y anota el motivo.
- Lo menor y reversible se decide con la opción recomendada y se anota. Lo vital, según el modo fijado al arrancar: en semi (05:30–20:00) preguntas y esperas con la sesión viva; en nocturno (20:00–05:30) dejas un checkpoint recuperable y una card «Espera decisión» para Jürgen, sin cerrar como completo, sin mergear ni desplegar lo incompleto.
- Entregable del cierre: artifact visual de Claude (capturas antes y después, comparación de los Primeros pasos), nunca Markdown ni PDF.
- Cierre: `/cerrar-total`, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada», y el link del artifact.

## Paso 0 — decisiones (resueltas en autónomo, bypass, modo nocturno)

1. **Dónde capturar:** simulador iPhone 17 Pro de la Max (libre). El iPhone 14 respondía y estaba libre, pero saltar al paso 7, a la hoja y a la oferta exige los atajos `-uitest-*` de una build Debug-Dev con precios de prueba; en el teléfono no se pueden reproducir esos estados sin tocar sus datos.
2. **Coach tips:** están apagados con `-uitest` y fuera de ese modo la app exige la bienvenida completa. Se capturan las pantallas reales y el tour se dibuja encima con el estilo de `CoachMarkOverlay`, avisándolo en el artifact.
3. **Entregable:** artifact HTML con capturas reales del antes, maquetas por opción y selector «Tu decisión» guardado en la `db` del artifact (solo escribe el dueño). Copia en `docs/maquetas/primeros-pasos-paso-7-y-prueba/`.
4. **Oferta de 30 días:** la hoja es `SetupCompleteTrialOfferSheet`, no `CourtesyTrial`. Se mide el recorrido real en el simulador y se listan los cortes silenciosos del código; la causa en el iPhone de Jürgen queda como inferida.
5. **Textos de las maquetas:** solo en el HTML; no se toca ningún `.strings` ni código de la app.
6. **Ticket:** se crea en `tickets/done/` (la sesión entrega maquetas, no implementación); la implementación se encola cuando Jürgen elija.
7. **Gate:** el diff cae entero en `docs/`, `tickets/` y `encargos/` → validación del índice.
