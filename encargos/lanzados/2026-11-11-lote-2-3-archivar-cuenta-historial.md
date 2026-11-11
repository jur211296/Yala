Yala
# Decidido 9-nov 2.3 · Cuentas: archivar conserva el historial
card: tablero-archivar-una-cuenta-decidir-si-oculta-su-9brj
toca: Yala/App/Views/Accounts/,Yala/App/Views/Settings/,Yala/App/Views/Panel/,Yala/App/ViewModels/,Yala/App/Logic/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote propio de la discusión del artefacto 2.3 (decisión 6). Card reutilizada: «Archivar una cuenta: decidir si oculta su historial…», ya en 2.3. Ficha: docs/ux/revision-vistas-2.3/39-cuentas-categorias/ficha.md. Hallazgo 39 P1: archivar una tarjeta aparta también lo gastado. La opción A del 8-oct se adelanta de 2.4 a 2.3.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. Archivar saca la cuenta del saldo y del carrusel, y conserva el historial (los movimientos siguen viéndose en Registros y en los cálculos del período). Opción A, decisión 6. Incluye el downgrade y las cuentas ya archivadas: el historial no desaparece.

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Cálculo financiero: review adversarial obligatoria (varias lentes y refutación). No ocultes ni borres movimientos al archivar.
- No toques el campo de número de cuenta ni «ajustar el saldo»: eso ya va en el lote necesario 09, ya encolado.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Paso 0 (Frank, 2026-11-11, modo nocturno)

**Precondición medida.** `origin/2.3..origin/2.2` = 16 commits: el merge corto de 2.2 en 2.3 ya entró; lo que falta son
arreglos de Grupos, release y docs, ninguno de Cuentas ni de archivar. `git log origin/2.3..origin/2.2` sobre
Accounts/Panel/ViewModels/Logic no trae nada de este punto: no hay arreglo de 2.2 que portar. Rama recreada desde
origin/2.3. Ningún PR abierto toca archivar.

**Qué es la opción A en el código** (decisión del 8-oct, adelantada el 9-nov):
- Dos preguntas que hoy contesta un solo flag (`excludeFromStatistics`) pasan a ser dos reglas en un sitio:
  - **¿Suma en un saldo?** (cifra, curva de saldo, «en N cuentas», hoja «¿Cuánto tienes hoy?», saldo de widgets,
    Yala IA, aviso de informe, salud financiera): ni excluida **ni archivada**.
  - **¿Se ven sus movimientos?** (Registros, ingresos/gastos de cualquier período, tartas, tendencias, día más caro,
    Yala IA): archivada **o** no excluida. Una cuenta archivada nunca oculta su historial.
- Archivar deja de encender «Excluir de las estadísticas» (formulario y líneas de la tarjeta).
- Downgrade y archivadas de antes del 3-oct: ya archivaban sin excluir; con A dejan de sumar al saldo y su historial
  sigue. Sin migrar nada.
- **Archivadas entre el 3-oct y hoy, que llevan «Excluir» encendido por archivar** (está en 2.1 publicada): su historial
  vuelve a verse sin tocar el dato, porque archivada manda sobre excluida para el historial. No se distingue de quien
  excluyó a mano y luego archivó: los dos ven el historial (es lo que dice A: «archivar conserva el historial»). Al
  desarchivar, el flag guardado vuelve a mandar. Sin migración.
- En el formulario, con la cuenta archivada el interruptor «Excluir» no se enseña (no haría nada) y el aviso dice lo
  nuevo: deja de sumar y de salir al registrar, sus movimientos se quedan. 16 idiomas.
- El conector `mcp/` porta la misma regla (golden de paridad).

**Fuera:** el botón y la hoja de A1 (rediseño del formulario), número de cuenta y «ajustar el saldo» (lote 09).
**Review adversarial** del cálculo: obligatoria. **Test de regresión** rojo sin el arreglo.
