---
esfuerzo: high
toca: docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/
release: no
---

# Consolidación final 2.3 · Encolar mejoras necesarias de las revisiones restantes sin elegir rediseños

## Contexto
Viene de la cola del 7-nov-2026 que Jürgen pausó ese día a las 12:42 Lima; el 9-nov-2026 la confirmó en la nueva cola oficial («las revisiones y la consolidación de revisiones»). Las revisiones por vistas 2.3 de las otras zonas ya están mergeadas en 2.3 (PR #846, #847, #848, #852, #853, #856, #859, #860; revisión del usuario nuevo PR #837). Esta sesión no ve nada más que este encargo. Va DESPUÉS de las revisiones 39 Cuentas, 40 Perfil y Ajustes y 41 Nube, que entran en la cola justo antes.

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Qué se pide
No implementar app en esta sesión. Dependencias: revisiones 34 Planificación, 35 Estadísticas, 36 Reportes/Flujo, 37 Grupos, 38 Bandeja/IA, 39 Cuentas, 40 Perfil/Ajustes, 41 Nube. Los PR850/851 se titularon índices final/parcial antes de acabarlas: NO asumir cobertura completa por esos títulos.
1. Verificar en GitHub cuáles están mergeadas, leer fichas/hallazgos de esas revisiones y PRs recientes, cotejar tablero y cola/lanzados. Matriz por zona con PR y evidencia; faltantes explícitas.
2. Clasificar bugs/accesibilidad/regresiones/claridad objetiva frente preferencias y rediseños incompatibles. Usuario 7nov06:56 autoriza IMPLEMENTAR las necesarias en lotes coherentes de 3–5 pequeñas; no elegir rediseño completo. Separar dudas materiales para Jürgen. No fabricar tareas para llenar lotes.
3. Para hallazgos nuevos necesarios con evidencia, crear/reutilizar tarjetas firmadas frank conservando notas y preparar encargos autocontenidos en `encargos/pendientes/` del repo (NO en `~/Claude/flota/cola-yala/` ni en la cola global: los encola Frank con el OK de Jürgen) (base2.3, toca rutas concretas sin comentarios ni comas en prosa, cierre-sola, /cerrar-total, bypassPermissions, permisos Mini1/Max2 o iPhone14, tests y capturas antes/después). No duplicar lotes 10/11, PRs abiertos ni QA existente. No implementar ni lanzar sesiones.
4. Si faltan revisiones mergeadas, procesar SOLO disponibles y rotular PARCIAL; no quedarse esperando ni producir índice falsamente final. Guardar pendientes en ficha para reanudación por mecanismo existente (sin nuevas rutinas/wakes); si todas faltan cerrar con evidencia de faltantes sin inventar trabajo.
Entrega: clasificación por hallazgo y razón, mapa cobertura real, lotes escritos/cards creadas con orden, decisiones excluidas. Sin mensajes externos ni publicación.

## Qué NO hay que tocar
- No implementar código de la app en esta sesión ni lanzar sesiones.
- marketing/, producción, auth, datos reales, colas (ni `~/Claude/flota/cola-yala/` ni la cola global) ni trabajo de otras sesiones.
- Commits y PR sin firma de IA (nada de «Generated with Claude Code», «Co-Authored-By» ni enlaces de sesión).

## Cómo se sabe que está bien
- Matriz de cobertura real por zona con PR y evidencia, y faltantes explícitas (PARCIAL si falta alguna revisión).
- Cada hallazgo clasificado con su razón; necesarias agrupadas en lotes de 3-5 con encargos escritos y cards creadas o reutilizadas, en orden; decisiones excluidas listadas para Jürgen.
- Un PR a `2.3` y cierre autónomo (cierra-sola).

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo semi): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Se espera a la zona 41 (Nube)?** → No se esperó: se avanzó con 34-40. La 41 aterrizó a mitad de la sesión (PR 865), se rebasó antes del commit y se procesó: lote 11. La entrega es completa.
Por qué: el encargo pide no esperar; al estar mergeada, procesarla es lo pedido. Alternativa descartada: cerrar PARCIAL con la revisión ya en 2.3.

**D2 · ¿Qué cuenta como «necesaria»?** → Bug, accesibilidad que impide leer o usar, texto que dice algo falso y regresión. Lo que pide elegir alternativa o reabre algo decidido va a decisiones; lo cosmético, a «menor» sin lote.
Por qué: es el criterio del encargo y el de los lotes de Panel y Formulario ya mergeados. Alternativa descartada: meter los «baratos» de cada ficha, que son alternativas de rediseño.

**D3 · ¿Qué se hace con lo que 2.2 ya arregló y 2.3 no tiene?** → Fuera de los lotes; se cita en la ficha y depende de la card en espera de decisión sobre integrar 2.2 en 2.3.
Por qué: portarlo a mano duplica trabajo si Jürgen elige el merge. Alternativa descartada: meterlo en lotes, choca con la integración.

**D4 · ¿Card por hallazgo o por lote?** → Una card por lote (diez) y se reusan las cards y tickets que ya existen, citados en el encargo.
Por qué: es lo que hicieron los lotes de Panel y Formulario y evita ~40 cards sueltas. Alternativa descartada: card por hallazgo, satura el tablero.

**D5 · ¿Orden de los lotes?** → Primero lo que pierde o duplica datos y las cifras financieras, luego accesibilidad, al final textos.
Por qué: severidad para el usuario. Alternativa descartada: por zona, mezclaría riesgos.

**D6 · ¿Dónde viven la ficha y los encargos?** → Ficha en `docs/ux/revision-vistas-2.3/consolidacion-necesarias-2026-11/ficha.md`; encargos en `encargos/pendientes/2026-11-09-necesarias-NN-*.md`, sin encolar.
Por qué: lo dice el encargo. El `README.md` de la revisión no se toca aunque esté desactualizado: queda fuera del `toca:`.

**D7 · ¿Se toca la zona 31?** → No; se anota en «Fuera de este encargo».
Por qué: el encargo nombra 34-41. Alternativa descartada: ampliarlo, sería alcance no pedido.

Ninguna sube a ADR: son de este encargo y caducan con 2.3.
