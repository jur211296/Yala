# Grupos: que la entrada y el refresco respondan al instante (4 cards de 2.2)

## Contexto
Es la sesión 1 de la «Cola 2.2 por sesiones» que Jürgen ordenó el 22-oct. Base: origin/2.2. Son cuatro cards del tablero, todas en «ready to launch»; léelas enteras con `tablero ver <id>` antes de empezar, que traen medición, contexto y criterio de terminado:
- `tablero-grupos-sigue-mostrando-crea-tu-cuenta-de-nve0` (alta): Grupos sigue mostrando «Crea tu cuenta de Yala» más de 10 s después de conectar la cuenta (reporte de Jürgen en producción).
- `tablero-al-elegir-vengo-por-un-grupo-la-pantalla-apsn` (alta): al elegir «Vengo por un grupo» la pantalla queda negra unos 10 s antes de la presentación de Grupos; incluye la espera de «Abriendo tu invitación…» en instalación nueva (12 s medidos, objetivo 1-2 s).
- `tablero-grupos-un-consentimiento-aceptado-sin-se-m387` (baja): un consentimiento aceptado sin sesión espera a Grupos o a un arranque si se entra por otra puerta. Ticket en tickets/backlog/groups-consent-signed-in-elsewhere-waits-for-groups-to-be-sealed.md.
- `tablero-reabre-yala-solo-cuando-la-persona-entra-ypit` (media): «Reabre Yala» solo al entrar en el iCloud privado; en la nube y en Grupos, sin reabrir. Jürgen ya aprobó la propuesta (22-oct 05:42). Inventario en tickets/backlog/reopen-yala-only-for-private-icloud.md (PR #594): 9 sitios; 3 justificados; de los 6 restantes, 2 se pueden hacer ya con el cambio en caliente del cierre de sesión en la nube; los otros 4 apagan el espejo de iCloud con la app abierta.

En paralelo vive la sesión «pendientes-de-jurgen-2-2» (sin simulador): no tocarla ni su worktree. El PR #576 sigue en cola de auto-merge a 2.2.

## Qué se pide
1. nve0 y apsn: reproducir en el simulador (instalación limpia), medir con marcas de hora dónde se va el tiempo y arreglar la causa; nunca una pantalla negra: si queda alguna espera real, una pantalla de carga con marca. Test que lo cubra.
2. m387: sellar el consentimiento en el punto en que cada puerta acepta la sesión, sin romper el bloqueo [I] de L12-4. Test.
3. ypit: aplicar la regla aprobada. Los 2 sitios que se pueden hacer en caliente, hacerlos. Los otros 4: si en el simulador se puede demostrar que apagar el espejo con la app abierta es seguro (sin pérdida ni duplicados de datos), hacerlos con tests; si hace falta un iPhone real para saberlo, no los arriesgues: déjalos como están y escribe en el cierre un guion corto de prueba en iPhone para Jürgen y una card a jurgen en «in qa» o «blocked» con ese guion.
4. Cards: al empezar, las cuatro a «in progress» (`--agente frank`); al cerrar, a «done» si quedan cubiertas por tests, o a «in qa» asignadas a jurgen si piden prueba en iPhone real, con el guion en la nota. Tickets nuevos de lo que encuentres, con su card.

## Qué NO hay que tocar
- No cambiar textos aprobados salvo donde la regla de «Reabre Yala» lo exija (y entonces en todas las traducciones).
- No desactivar tests ni saltarse protecciones de rama.
- Nada de diseño nuevo inventado: si una pantalla de carga necesita decisión visual, usar la que ya existe en la app.

## Cómo se sabe que está bien
Los criterios «hecha cuando» de las cuatro cards se cumplen (o lo que no, queda con causa y guion), con tests nuevos en verde, PR a 2.2 en auto-merge y la suite unit entera en verde.

## Gate después del CI del PR anterior
La sesión arranca ya, sobre origin/2.2. Justo antes del gate, mirar si el PR #576 sigue en CI. Si sigue, esperar a que entre y rebasar una sola vez, con el simulador apagado. Si 2.2 no se movió, seguir de frente. Si ese CI falla, no esperar: rebasar con lo que haya y seguir. El build y el simulador van después de ese rebase, una sola vez.

## Mini
La Mini va justa (~19 GB libres, umbral 32 GB): al arrancar, limpiar sin preguntar sims muertos, DerivedData de sesiones cerradas y cachés de XcodeBuildMCP de worktrees que ya no existen. Pipeline serial de Yala: build con `xcodebuild -jobs 2` sin sim booteado, luego un solo simulador para tests, y al cerrar apagar y borrar ese sim. Al cerrar, borrar el DerivedData de esta sesión. No tocar los de la sesión viva «pendientes-de-jurgen-2-2». Si hay cambio visible, dejar capturas antes/después en capturas/ del worktree y listarlas en el cierre.

/cerrar-total

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · nve0: ¿por qué Grupos no cambia al conectar la cuenta?** → La pestaña lee la sesión de `CloudAuthService`, que no es observable: nada la repinta al cerrarse la hoja de cuenta (medido en el código; es el mismo patrón que el lote 12 arregló para el consentimiento). Arreglo: `CloudAuthService` avisa cuando cambia la sesión y la pestaña se re-decide con ese aviso.
Por qué: arregla la causa en un sitio y sirve a todas las puertas (hoja de Grupos, Ajustes, bienvenida). Alternativa descartada: hacer `CloudAuthService` `@Observable` — toca a decenas de lectores y cambia cuándo repintan pantallas ajenas.

**D2 · ¿el aviso de sesión sella el consentimiento o marca el historial?** → No: solo repinta. Sellar o marcar en cualquier inicio de sesión rompería el bloqueo [I] (la cuenta rechazada no puede dejar rastro), y con las seis páginas montadas desde el arranque, la pestaña de Grupos oye también los inicios de sesión de otras puertas.

**D3 · Test de nve0** → Seam DEBUG `-uitest-fake-cloud-session-after <s>`: la sesión fingida aparece a los N segundos con la pestaña delante, como un inicio de sesión real. El XCUITest pide que la tarjeta pase de «Crea tu cuenta» a «Acepta cómo se guardan tus grupos» en ≤ 3 s.
Por qué: el simulador no puede iniciar sesión de verdad (sin SIWA/Google); el seam reproduce justo el mecanismo roto (la sesión cambia con la vista montada).

**D4 · apsn** → Medir primero con marcas de hora temporales (no se commitean) qué retiene la cadena entre el toque y la presentación. Si la espera sobra en una sesión solo de grupos, se quita; si queda una espera real, se enseña la pantalla de carga que ya existe en la app (con su marca), nunca negro.

**D5 · m387: ¿dónde se sella?** → En el punto en que cada puerta da la sesión por buena: bienvenida (entrar a una cuenta solo-grupos, el adopt que pasa el guard cross-cuenta, el alta born-cloud que activa la nube) y Ajustes (la puerta de identidad de «Migrar a la nube» en `.proceed`). Nunca en `CloudAuthService.signIn`. Las tres que ya existían (hoja de Grupos, pestaña, arranque) no cambian.

**D6 · ypit: los 4 que apagan el espejo con la app abierta** → No se tocan. El simulador no tiene iCloud ni exporta a CloudKit, así que no puede demostrar que soltar el espejo en caliente no escribe nada después; la medición pide un iPhone real. Card a Jürgen con guion. Los 2 en caliente (celda solo-grupos del 8 y los dos «Borrar mi cuenta» del 9) sí se hacen, con tests.

**D7 · Limpieza de la Mini** → El sandbox deniega borrar; lo recuperable fuera del DerivedData son KB. El DerivedData vive en ExtDev (192 GB libres), no en el disco interno. Se anota en el cierre, sin pelear con permisos.

**D8 · Rebase** → Un solo `fetch` + rebase sobre `origin/2.2` antes del gate (regla de sesión: no se espera a otros PR).
