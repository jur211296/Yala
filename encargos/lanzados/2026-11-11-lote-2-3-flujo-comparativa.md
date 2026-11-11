Yala
# Decidido 9-nov 2.3 · Flujo de caja: la Comparativa a medias y «Te faltan» sin ingresos
card: tablero-2-3-flujo-de-caja-la-comparativa-a-media-d7c8
toca: Yala/App/Views/Reports/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisiones 32 y 33. Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/36-reportes-flujo/ficha.md.

## Encargo y criterio de terminado
Implementar SOLO estos 2 puntos:
1. La Comparativa deja de decir «Noviembre» cuando compara del 1 al 7. Opción A + B: rótulos con el tramo exacto («1–7 nov.» frente a «1–7 oct.»), «igual»/«nuevo» en vez de «=+0%»/«N/A»; abre desglosada por categoría, ordenada por cambio en soles.
2. La primera semana, sin ingresos, deja de decir «Te faltan S/ 2,573». Opción A: el armado pregunta «¿Cuánto recibes al mes?» cuando no ve ingresos, con «Aún no lo sé».

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones (resueltas en semiautónomo, Frank, 2026-11-11)

Medido antes de decidir:
- `origin/2.3..origin/2.2` = 16 commits, todos de Grupos, del release (build 9) y de documentación; ninguno toca Reportes ni Flujo de caja. Se toma como «casi 0»: 2.3 ya trae la 2.2 hasta el 10-nov (merge «build 9 en 2.3»). Los dos puntos siguen vivos en `origin/2.3`.
- La otra sesión que declaraba `Yala/App/Views/Reports/` (login Apple/Google, 4-nov) no está viva: sin tmux, sin rama remota ni worktree.

Punto 1 — Comparativa (decisión 32, A + B):
1. **El tramo exacto sale de la misma regla que ya recorta el anterior.** Un período en curso («Este mes», «Esta semana», «Este año») se nombra de su inicio al último día con movimientos (o hoy): «1–7 nov». Mes pasado, rodantes y rango propio no cambian.
2. **Frase de arriba con tramo a los dos lados:** se reusa la frase aprobada de 2.2, «1–7 de noviembre comparado con el 1–7 de octubre», en vez de construir «Del 1 al 7…» (no se arma igual en los 16 idiomas). Sin clave nueva.
3. **Pie del neto:** «En 1–7 de octubre te quedaron…» no se lee bien; con un tramo de días pasa a «El 1–7 de octubre te quedaron…» (dos claves nuevas). Con un mes entero, igual que hoy.
4. **«igual» y «nuevo» solo en esta tabla**: el chip de variación compartido gana un modo con palabras, y el resto de la app sigue con «=» y «N/A». «−100 %» no estaba en la decisión y se queda.
5. **Debajo de cada monto sigue «en 1–7 oct.»** (decisión de 2.2, L18-3). La maqueta pone «antes», pero la decisión 32 no lo pide.
6. **Abre con Categoría puesta** (`[.tipo, .categoria]`); «Desglosar» sigue para añadir o quitar niveles.
7. **Orden por cambio en soles, de más a menos** (como la maqueta: +156, +143, −98, −189), en todos los niveles bajo «Ingresos/Gastos» y solo cuando hay comparación. Sin comparación («Todo el tiempo»), por monto como hoy. Las cifras siguen en % (opción A); B solo pide el orden.

Punto 2 — Primera semana sin ingresos (decisión 33, A):
8. **La pregunta sale cuando el armado no sugiere ninguna línea de ingreso.** Hasta contestarla no hay resumen ni «Crear mi plan».
9. **La cifra se escribe en la hoja de monto que ya existe** (la del saldo inicial, sin «Usar este monto» ni fecha), no en un campo nuevo dentro de la tarjeta.
10. **El ingreso escrito se guarda como línea manual atada a la categoría de ingresos de la persona** (la primera visible que no es de sistema; sin ninguna, sin categoría). Sin categoría, el sueldo real se contaría dos veces al llegar: una en la línea y otra en «otros ingresos».
11. **«Aún no lo sé»:** el resumen dice «Gastos al mes S/ X» y, en vez de «Te faltan al mes», «Falta tu ingreso», sin cifra. Se puede crear el plan igual.

Pruebas: unitarias de los rótulos, el orden y la agrupación por defecto, y del ingreso escrito al crear el plan; un XCUITest por punto, rojo en la base y verde con el arreglo, que deja las capturas de antes y después.
