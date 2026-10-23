# Activar la nube y volver a iCloud: que tarden menos y que el progreso diga la verdad (3 cards de 2.2)

## Contexto
Es la sesión 2 de la «Cola 2.2 por sesiones» que Jürgen ordenó el 22-oct. Base: origin/2.2. Son tres cards del tablero, en «ready to launch»; léelas enteras con `tablero ver <id>` antes de empezar (traen mediciones del QA guiado, contexto y criterio de terminado):
- `tablero-activar-la-nube-con-6-movimientos-espera-ppxk` (alta): «Activar la nube» con pocos movimientos tarda minutos esperando a que iCloud «termine de sincronizar» (9,5 min en producción para 5 movimientos en el TF19; ~2,5 min en staging). Jürgen pidió reducir esos tiempos, es urgente. Ojo también: «Cancelar la activación» queda desactivado mientras espera.
- `tablero-al-activar-la-nube-con-muchos-movimiento-igt9` (alta): con miles de movimientos la barra se queda quieta en ~60 % mientras los movimientos sí suben, y parece colgada.
- `tablero-tras-confirmar-borrar-y-volver-a-icloud-27z3` (alta): tras confirmar «Borrar y volver a iCloud» la pantalla no dice que trabaja; «Pendientes de subir: 448» queda quieto ~10 min y termina de golpe.

Decisión de Jürgen (22-oct 05:42): opción B (la recomendada) del lienzo de propuestas https://claude.ai/artifact/CvEQtrq9rTpfwvAXH9PLpq, pasos con su cifra para el progreso de «Activar la nube» y de «Volver a iCloud». Ticket de base: `cloud-progress-shows-real-steps-and-counts` (PR #594). El diseño ya está decidido: implementa la B tal cual el lienzo, sin inventar otro.

En paralelo vive la sesión «Yala--pendientes-de-jurgen-2-2» (sin simulador): no tocarla ni su worktree. El PR #607 (Grupos refresco y entrada) está en cola de merge a 2.2. La card bloqueada «Cuatro "Reabre Yala" de la nube y de Grupos esperan una medición en un iPhone real» no es de esta sesión: no la toques.

## Qué se pide
1. Medir con marcas de hora dónde se va el tiempo al activar la nube con pocos datos (espera de quiescencia del espejo de iCloud, tope de 300 s, reintentos solo al volver a primer plano) y al volver a iCloud. Reducirlo de raíz donde sea seguro; si una espera es necesaria para no perder ni duplicar datos, que sea la mínima y que la pantalla lo diga.
2. Implementar la opción B del lienzo: pasos con su cifra real (cuántos movimientos subidos o pendientes de un total) que cambian al menos cada pocos segundos, en «Activar la nube» y en «Volver a iCloud» / «Borrar y volver a iCloud». Nada de barra quieta ni cifra congelada.
3. Que se pueda cancelar la activación mientras espera, si es seguro; si no lo es, que la pantalla explique por qué.
4. Tests que cubran el progreso y los tiempos (unit y XCUITest donde se pueda), con capturas antes/después.
5. Cards: al empezar, las tres a «in progress» (`--agente frank`); al cerrar, a «done» si quedan cubiertas por tests, o a «in qa» asignadas a jurgen si piden prueba en iPhone real, con un guion corto en la nota. Tickets nuevos de lo que encuentres, con su card.

## Qué NO hay que tocar
- No cambiar textos aprobados fuera de estas pantallas; si cambias textos, en todas las traducciones.
- No desactivar tests ni saltarse protecciones de rama.
- No tocar datos de producción ni desplegar nada a producción.

## Cómo se sabe que está bien
Los criterios «hecha cuando» de las tres cards se cumplen (o lo que no, queda con causa medida y guion para el iPhone), con tests nuevos en verde, capturas antes/después en `capturas/`, PR a 2.2 en auto-merge y la suite unit entera en verde.

## Dependencias y gate
La sesión arranca ya, sobre origin/2.2, sin esperar el CI ni el merge del PR #607. Justo antes del gate y de abrir el PR, `git fetch` y mirar si el #607 sigue en CI. Si sigue, esperar a que entre y rebasar una sola vez, con el simulador apagado. Si 2.2 no se movió, seguir de frente. Si ese CI falla, no esperar: rebasar con lo que haya y seguir. El build y el simulador van después de ese rebase, una sola vez.

## Mini
La Mini va justa (~20 GB libres, umbral 32 GB): al arrancar, limpiar sin preguntar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen. Pipeline serial de Yala: build con `xcodebuild -jobs 2` sin sim booteado, luego un solo simulador para tests, y al cerrar apagar y borrar ese sim. Al cerrar, borrar el DerivedData de esta sesión. No tocar los de la sesión viva «pendientes-de-jurgen-2-2». Si hay cambio visible, dejar capturas antes/después en capturas/ del worktree y listarlas en el cierre.

Al terminar, cierre autónomo: los pasos manuales de Jürgen (probar en el iPhone, desplegar) no impiden cerrar, quedan como pendiente suyo.

/cerrar-total

## Paso 0 (Frank, 2026-10-23, autocontestado: MODO AUTÓNOMO)

**Medido antes de tocar nada** (Analytics Engine, timestamps del servidor; los eventos salen al momento con red):
- TF19 producción 20-oct: consentimiento 21:37:42 → claim 21:37:47 → **9 min sin un solo evento** (ni un export de
  iCloud) → exports cada ~4 s desde 21:46:45 → marcador sano y cutover 21:47:17. Staging (Yala Dev) 20-oct: 13:36:36 →
  13:38:51 (2 min 15 s) y 21:57:05 → 22:03:59 (6 min 54 s), con el mismo hueco mudo antes del primer export.
- El hueco no es la red de Yala: la subida de 5 movimientos son 1-2 peticiones. INFERIDO: el espejo de iCloud ocupado
  (import) y las esperas de la app detrás de él — pre-espera de 300 s del controller + 120 s del runner por entrada, y
  cada pasada aparcada (marcador sin exportar, import sin asentar) solo se re-empuja cada 30 s con la pantalla abierta.
  La app no dejaba rastro de qué paso duraba cuánto: no se puede medir más fino sin instrumentar.
- «Cancelar la activación» ya se puede tocar durante la pre-espera desde 7d389f101 (`MigrationImportWaitLogic`): la nota
  de la card es anterior. Se conserva y se cubre en la vista nueva.

**Decisiones:**
1. **Medir en la flota**: canario nuevo por cada cambio de paso de la ida y la vuelta con los segundos que duró el
   anterior, y otro al terminar cada espera a iCloud con lo que duró. La próxima corrida en iPhone dice dónde se va el
   tiempo sin inferir.
2. **Reducir lo que es de la app, no lo de iCloud**: (a) el paso del marcador espera el export dentro de la pasada
   (sondeo de 1 s, hasta 30 s) en vez de aparcar y esperar al re-empuje de 30 s; (b) con la pantalla delante, las fases
   que solo esperan una observación local de iCloud (marcador, espejo, subida de la vuelta) se re-empujan cada 5 s, no
   cada 30. La espera a que iCloud termine de importar **se queda**: un `save()` durante el import tumba la app y una
   foto con el import a medias sube un corpus incompleto. La pantalla lo dice con su nombre.
3. **Opción B tal cual el lienzo** (Main/B/B2/B3): cuatro pasos en la ida (Conectar · Preparar · Subir con «X de N
   movimientos» y su barra · Confirmar con iCloud), «Esperar a iCloud» con su explicación cuando la app espera el
   import, tres pasos en la vuelta (Traer de la nube · iCloud revisa lo que ya tiene · Subir a iCloud con «N por
   subir»). Sin «Retomar» (el lienzo no lo lleva; el re-empuje automático lo sustituye). Pie «Mantén Yala abierta…» en
   la ida y «Puedes seguir usando Yala…» en la vuelta.
4. **Asumido**: «este iPhone» del lienzo pasa a «este dispositivo» (Yala corre también en iPad). La barra de «Subir»
   cuenta todas las filas (se mueve también mientras suben cuentas y tipos de cambio); la cifra cuenta movimientos.
5. **«Borrar y volver a iCloud»**: el borrado de lo de antes es el primer paso de la vuelta, con su cifra; y desde el
   «Sí» hasta que el journal se mueve, la tarjeta de pasos ya está en pantalla (antes: «Volver a iCloud» apagado y nada).
6. **La cifra se mueve cada pocos segundos**: la subida avisa por cada trozo de 50 filas confirmado, no por página de 200;
   la cifra de la vuelta se relee en cada re-empuje de 5 s.
7. Tests: lógica pura de los pasos (tabla), cadencia del re-empuje, progreso del uploader con su mutante, espera del
   marcador; XCUITest con un seam que finge la fase y la cifra (capturas antes/después de cada pantalla).
8. Cards: igt9 y 27z3 a «in qa» con guion corto (piden capturas aprobadas y iPhone real); ppxk a «in qa» (el «< 1 min»
   depende de iCloud en un iPhone real; queda el canario para medirlo).
