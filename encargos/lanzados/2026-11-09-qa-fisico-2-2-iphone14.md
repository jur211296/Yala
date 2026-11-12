---
toca: docs/qa/
release: no
cierre: cierra-sola
---
Yala
# QA físico de 2.2 en el iPhone 14 con DeviceMCP y cierre de las cards verificadas

## Contexto
Jürgen pidió (9-nov, 18:02 Lima) una sesión de QA físico de la versión 2.2 en el iPhone 14 que está siempre conectado a la Max por DeviceMCP. La sesión hace el QA y va cerrando las cards que pasen. Hay 28 cards de 2.2 en «in qa»: 16 asignadas a frank (trabajo hecho, falta verificar) y 12 asignadas a Jürgen (son de diseño o decisión suya). También está en backlog la card «QA en el iPhone físico con Device MCP (después del barrido, antes de TestFlight…)», que es justamente este encargo. Rama base: `2.2` (traer `origin/2.2` al día antes de compilar). Lista viva: `tablero listar --proyecto Yala` (filtrar versión 2.2, columna in qa). Toda escritura en el tablero va firmada con `--agente frank`.

## Qué se pide
1. Compilar la 2.2 actual e instalarla en el iPhone 14 por DeviceMCP. Si hace falta, se puede usar además un segundo simulador en la Max (tope de 2 simuladores, puede haber otra sesión usando uno).
2. Recorrer en el iPhone cada card de 2.2 en «in qa» asignada a frank y verificar en el teléfono lo que dice su criterio:
   - Si pasa: anotar la evidencia en la card (qué se probó, captura o paso) y moverla a done.
   - Si falla: dejarla en «in qa» o devolverla a backlog con el fallo reproducible y la evidencia. NO arreglar código en esta sesión.
   - Si no se puede verificar en el teléfono (por ejemplo, las de Sentry, CI, ficha de App Store, capturas o video), anotar por qué y dejarla como está.
3. En las 12 cards asignadas a Jürgen: probar en el teléfono y adjuntar la evidencia en la card, pero NO moverlas a done: las aprueba él.
4. Al final, mover a done la card «QA en el iPhone físico con Device MCP…» si el recorrido quedó completo, y dejar un informe en `docs/qa/qa-fisico-2-2-iphone14.md` con la tabla de cards: pasó, falló o no verificable, con evidencia.
5. Los fallos nuevos que no tengan card se crean como cards nuevas de 2.2 en backlog, asignadas a frank, con pasos para reproducir.

## Qué NO hay que tocar
- Nada de código de la app ni de los tests: solo `docs/qa/` y el tablero.
- No mergear nada, no subir a TestFlight, no tocar App Store Connect.
- No mover a done las cards de Jürgen.
- No tocar `marketing/`.
- Commits y PR sin firma de IA.

## Cómo se sabe que está bien
Todas las cards de 2.2 en «in qa» tienen una nota de QA físico con su resultado. Las de frank que pasaron están en done. Las de Jürgen tienen evidencia y siguen en «in qa». El informe está en un PR contra `2.2`, sin mergear. Cierra con `/cerrar-total` (sin merge del PR del informe si el modo no lo permite).

## Paso 0 — decisiones (resueltas en semiautónomo, Frank, 2026-11-09)

1. **Cuántas cards.** Medido en el tablero a las 18:05: 28 de 2.2 en «in qa», 17 de Frank y 11 de Jürgen (el encargo decía 16 y 12). Se recorren las 28.
2. **Cómo instalar.** `build_and_run` de Device MCP pide licencia Pro → `xcodebuild` (Yala Dev, Debug-Dev) + `devicectl install` en el iPhone 14 (iPhone14,7), no en el 18 Pro Max.
3. **Datos del teléfono.** Son de desarrollo: crear gastos, pagos y cuentas, cerrar sesión de la nube y pasar a iCloud privado lo decido yo (memoria «QA físico: datos dev»).
4. **Cards de Frank que pasan pero esperan el visto bueno de Jürgen** (cuentas de Grupos en un chip): se quedan en «in qa»; moverlas saltaría su pregunta pendiente.
5. **Cards de Frank no verificables en el teléfono** aunque su criterio se pueda medir en GitHub (CI, Panel del iPad): se anota la medida y se dejan como están, como dice el encargo.
6. **Cards cuyo arreglo está en 2.3 y no en 2.2** (foto de perfil, filtros de Sentry): se anotan como «falla para 2.2» y se quedan en «in qa»; llevar el PR a 2.2 o cambiar la versión de la card es decisión de Jürgen.
7. **Pasos que piden la mano de Jürgen** (Google, Apple Intelligence, Sandbox de StoreKit): no se le despierta; se anota qué falta en la card.
8. **Capturas** en `~/Claude/entregas/2026-11-09-qa-fisico-2-2-iphone14/evidencia/`, no en el repo; el informe y las cards apuntan ahí.
9. **Fichas de `tickets/qa/`** de las cards cerradas: no se tocan (el encargo limita a `docs/qa/` y el tablero).
