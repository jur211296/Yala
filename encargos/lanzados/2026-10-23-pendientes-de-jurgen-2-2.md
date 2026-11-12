# Pendientes de Jürgen en 2.2: dejar las 5 decisiones de UI con propuestas claras, implementar lo que Jürgen decida y ordenar la card bloqueada de «Reabre Yala» (sin simulador)

## Contexto
Sesión paralela «Pendientes de Jürgen 2.2» (relanzada, versión b). Base: origin/2.2 al día (82bf4bb81 al lanzar). Es la excepción aprobada por Jürgen a la regla de una sola sesión viva de Yala: corre al lado de `Yala--activar-la-nube-progreso-2-2`, que NO se toca (ni su tmux ni su worktree).

Cards (léelas enteras con `tablero ver <id>` antes de empezar; traen las propuestas previas, mediciones y capturas):
- `tablero-el-permiso-de-avisos-de-grupo-ya-no-se-p-fptw` (espera decisión): el permiso de avisos de grupo ya no se pide a quien llega a su primer grupo por otro camino. Aún no tiene propuestas A/B/C: hay que redactarlas (ticket tickets/backlog/groups-notifications-permission-skipped-when-the-group-arrives-another-way.md).
- `tablero-revisar-si-seguridad-y-cuenta-en-ajustes-2745` (espera decisión): dividir «Seguridad y cuenta» en Ajustes. Propuestas A/B/C ya en la nota (recomendada B).
- `tablero-ux-2-2-l16-14-que-ensena-permisos-de-yal-tipp` (espera decisión): Face ID en «Permisos de Yala». Propuestas A/B/C en la nota (recomendada A).
- `tablero-ux-2-2-l16-5-el-idioma-de-la-app-solo-se-qb1r` (espera decisión): cambio de idioma de la app. La C decidida no sirve con un solo idioma en el iPhone; propuestas A/B/C nuevas en la nota (recomendada B híbrido).
- `tablero-ux-2-2-l20-15-datos-no-disponibles-el-bo-pm2w` (espera decisión): aviso «Datos no disponibles». La B decidida no es legible en un aviso del sistema; propuestas A/B/C en la nota (recomendada B: hoja).
- `tablero-cuatro-reabre-yala-de-la-nube-y-de-grupo-5zpq` (blocked, jurgen): cuatro «Reabre Yala» esperan una medición en un iPhone real. No se puede resolver sin el iPhone de QA conectado: deja el guion de medición listo y claro, y pásala a su dueño.

Orientación mínima: STATE.md, CLAUDE.md, índice de DECISIONS.md y solo el ADR concreto. No leas el repo entero.

## Qué se pide
1. Al empezar, pregúntale a Jürgen (AskUserQuestion, en español) por cada card en espera decisión, con opciones A/B/C claras, la recomendada marcada y su porqué, y las capturas que ya existen en las rutas de las notas. Para la de avisos de grupo, redacta tú las opciones a partir del ticket. No inventes decisiones ni implementes nada de UI sin su elección. Una pregunta por card, sin ids cortos: nombra cada card por su título.
2. Si una opción necesita maqueta nueva, hazla como artifact de Claude (no simulador).
3. Lo que Jürgen decida: implementarlo en 2.2 en el worktree, con tests unitarios donde se pueda; las traducciones de cualquier texto cambiado en los 16 idiomas. Mueve cada card al decidirse (fuera de espera decisión, assignee frank) y al terminar (done si queda cubierta por tests; in qa a jurgen con un guion corto si pide ojo en un iPhone). Firma siempre `--agente frank`.
4. Card de «Reabre Yala»: deja en la nota el guion de medición (pasos, ~30 min, qué se cuenta) y déjala en blocked asignada a jurgen; si Jürgen conecta el iPhone durante la sesión y lo pide, se coordina, pero sin simulador.
5. Quédate viva esperando a Jürgen mientras falten decisiones. Cuando todas las cards estén resueltas o pasadas a su dueño, abre el PR a 2.2 (si hubo código) con auto-merge y haz /cerrar-total.

## Qué NO hay que tocar
- NO usar el simulador (ni bootear, ni XCUITest, ni XcodeBuildMCP con sim). Build solo si hace falta, con `xcodebuild -jobs 2` y sin simulador.
- No tocar Yala.xcscheme, `encargos/pendientes/` ni los .ckdb sin commitear.
- No tocar la sesión `Yala--activar-la-nube-progreso-2-2` ni su worktree, ni ninguna tmux `salud--`, `sat-lab--` o `clinicas-dentales-bi--`.
- No avisar a Dan. No desactivar tests ni saltarse protecciones de rama. Nada a producción.
- Todo lo que se le escriba a Jürgen va en español neutro latinoamericano.

## Cómo se sabe que está bien
Cada una de las 5 cards tiene la decisión de Jürgen registrada y, si cambiaba algo, implementada con tests en verde (o en in qa con guion); la card de «Reabre Yala» tiene el guion de medición y está con su dueño. Ninguna decisión inventada.

## Dependencias
La sesión arranca ya sobre origin/2.2, sin esperar CI ni merges de otras sesiones. Justo antes de abrir el PR, `git fetch` + un solo rebase sobre origin/2.2. Solo si toca el mismo archivo que la sesión de activar la nube, espera a su merge.

## Mini
Al cerrar, borra el DerivedData de esta sesión. No toques los de la sesión viva de activar la nube.

Al terminar, cierre autónomo: los pasos manuales de Jürgen (probar en el iPhone, mergear) no impiden cerrar, quedan como pendiente suyo.

/cerrar-total

## Paso 0 — decisiones (Frank, 2026-10-23; las de producto las tomó Jürgen por AskUserQuestion a las 10:45)

**De Jürgen (todas las recomendadas):**
1. Avisos de grupo: **B** — la tarjeta de avisos también en el formulario de gasto del Panel y una sola vez arriba de la lista de Grupos para quien tiene grupos y nunca la vio. Sin alerta suelta.
2. «Seguridad y cuenta»: **B** — «Seguridad y privacidad» (Face ID, Permisos, Privacidad y datos IA) + bloque «Tu cuenta»; Siri y Atajos a Preferencias; Valorar/Recomendar al final de «¿Necesitas ayuda?».
3. Face ID en «Permisos de Yala»: **A** — fila sin estado con «Ver cómo» que abre la guía.
4. Idioma: **B** híbrido.
5. «Datos no disponibles»: **B** — hoja propia con «Seguir esperando» arriba y relleno.

**Técnicas, resueltas por mí (autónomo):**
- Ajustes: el bloque «Datos» no se mueve; «Tu cuenta» va entre Seguridad y Ayuda y solo sale si tiene filas. Se reusa la clave `settings.security` cambiando su valor en los 16 idiomas.
- Idioma: con un idioma elegido en el selector de Yala, la fila abre el selector de Yala aunque el iPhone tenga varios (el de Yala manda sobre el de iOS y cambiarlo en iOS no haría nada). Volver a Personalización tras elegir: el Panel recién reconstruido reabre Ajustes en Personalización (`SceneNavigation.pendingSettingsReturn`), por el mismo camino que ⌘,.
- Face ID: la fila es un enlace de la lista a la guía (`ProfileDestination.faceIDProtectionGuide`), registrado en las dos pilas de Ajustes.
- «Datos no disponibles»: molde de la hoja de `AppleIDCloseNoticeView`; mismo blocker de la matriz y misma red de presentación.
- Sin simulador (encargo): lo visual va a `in qa` con guion para el iPhone de Jürgen; lo que se puede fijar, con unit tests y source-scans.
