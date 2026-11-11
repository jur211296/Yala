Yala
# Decidido 9-nov 2.3 · Estadísticas: no congelar la pestaña con diez años de datos
card: tablero-2-3-estadisticas-no-congelar-la-pestana-o3ix
toca: Yala/App/Views/Statistics/,Yala/App/Views/Settings/,Yala/App/Views/Profile/,Yala/App/ViewModels/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 28 (G1 medir antes + G2 + G3). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/35-estadisticas/ficha.md. La medición de Ajustes con diez años (decisión 50, hallazgo de la zona 40) se hace en esta misma sesión; la nota ya está en la card «La app se traba en Perfil (App Hang)».

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Con diez años de datos, Estadísticas deja de congelarse ~2 s. Opción G1 + G2 + G3: primero medir con Instruments en el iPhone 14 de pruebas (Release) dónde se va el tiempo; luego la pestaña responde al toque con esqueleto y las cifras llegan después. Gráficas por mes y año en períodos largos (eje legible). Sankey del iPhone empieza en las categorías. En la misma sesión, mide también Ajustes con diez años (~1 s) y deja la evidencia en la card del App Hang de Perfil; no abras un lote nuevo para eso.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- No declares el arreglo terminado sin la medición en Instruments (Release, iPhone 14).
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Paso 0 — decisiones

> Resueltas en autónomo (bypass, modo semi): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Sobre qué base?** → `origin/2.3`; la rama nació de 2.2 y se recreó sobre 2.3 sin commits propios.
Por qué: el encargo pide 2.3 y el merge corto de 2.2 en 2.3 ya entró; los 16 commits de 2.2 que faltan son Grupos y release, nada de Estadísticas. Alternativa descartada: parar con BLOQUEANTE, porque «casi 0» se cumple en lo que toca este lote.

**D2 · ¿Cómo se mide «Release» con diez años en el iPhone 14?** → `Release-Dev` (optimizado, whole-module) compilado desde una copia aparte del código con la condición `DEBUG` añadida solo ahí, para tener la semilla `pesado` y el almacén aislado de `-uitest`.
Por qué: la semilla y el almacén de pruebas solo existen con `DEBUG`; así el código de la app sale optimizado como en Release y los datos de Yala Dev del iPhone no se tocan (el almacén `YalaModel-UITest` es otro fichero). Alternativa descartada: copiar el almacén sembrado encima del real del iPhone, porque pisa sus datos.

**D3 · G1, ¿cálculo en otro hilo o esqueleto y cálculo diferido?** → la pestaña pinta en el acto con esqueleto donde van las cifras, y el cálculo corre una vuelta después; se recorta además lo que la medición señale como caro.
Por qué: es lo decidido («responde al toque con esqueleto y las cifras llegan después»), y los `@Model` de SwiftData viven en el hilo principal: sacarlos a otro hilo es un rediseño de todo el cálculo. Alternativa descartada: copiar los datos a valores y calcular fuera del hilo principal, fuera de alcance de este lote.

**D4 · G2, ¿cuándo se agrupa por mes y cuándo por año?** → por mes cuando el período mostrado pasa de unos tres meses; por año cuando los datos cubren más de tres años. El eje dice años.
Por qué: es la letra de G2 («por mes, y por año pasados 3 años»). Alternativa descartada: reducir puntos con un muestreo, que no arregla el eje.

**D5 · G3, ¿«iPhone» por aparato o por ancho?** → por ancho: si las cuatro columnas no caben a un ancho legible, tres (ingresos, flujo, categorías) sin desplazar; con una categoría elegida vuelven las subcategorías de esa categoría.
Por qué: la regla del repo prohíbe decidir layout por aparato, y «las subcategorías para el toque en una categoría» es lo que ya hace el filtro. Alternativa descartada: cambiar qué hace el toque, que es otra card (decisión B1).

**D6 · La medición de Ajustes, ¿dónde queda?** → en la nota de la card del App Hang de Perfil (ya hecha), sin reabrirla ni abrir lote.
Por qué: decisión 50, opción A. Alternativa descartada: card nueva.

**D7 · ¿Qué test por punto?** → unit tests de lógica pura para G2 (agrupación) y G3 (columnas), y uno de cableado o XCUITest para G1 (el esqueleto sale antes de las cifras), rojos sin el arreglo.
Por qué: lo pide el encargo y `qa/coverage-index.json`. Alternativa descartada: solo capturas.
