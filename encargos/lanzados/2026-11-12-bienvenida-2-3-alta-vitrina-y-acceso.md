Yala
# Bienvenida 2.3 · Alta: vitrina, accesos y tres preguntas
card: tablero-bienvenida-2-3-vitrina-y-accesos-de-goog-syf7,tablero-bienvenida-2-3-acceso-con-google-o-apple-11hi,tablero-bienvenida-2-3-entrar-con-icloud-privado-q1pj,tablero-bienvenida-2-3-conversacion-de-tres-preg-73wg,tablero-bienvenida-2-3-entrada-por-grupos-hmaf
toca: Yala/App/Views/Onboarding/, Yala/App/Logic/, Yala/App/Views/Groups/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3, Yala/bienvenida-2-3-base-mazo-pestanas-permisos

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Lote 02 de 5 de la implementación oficial de la bienvenida y el alta de Yala 2.3. Fuente: docs/onboarding-2-3/SPEC.md, sección A, cards Y23-01 a Y23-04 y Y23-06. Prototipo oficial v35, pestañas 1 · Mis finanzas y 2 · Viene por grupos: https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6. Depende del lote 01 porque la conversación termina en la llegada y el mazo (Y23-05). Las decisiones ya están en el SPEC; no se reabren.

## Encargo y criterio de terminado
Implementar SOLO estas 5 cards, cada una tal como está en su sección del SPEC:
1. Y23-01 · Bienvenida con vitrina y accesos (atajo `#fin`). Vitrina, fondo F2 (solo modo oscuro) y un único botón por proveedor. Fuera de alcance: modo claro y mascota (solo el espacio reservado).
2. Y23-02 · Acceso con Google o Apple: el servidor decide (atajo `#fin`, mando «Qué pasa con ese correo»). Verificar SIEMPRE. Consentimiento de la nube en la misma hoja «Vamos a crear tu cuenta», como consentimiento explícito. Si el servidor aún no puede decir con qué proveedor se creó la cuenta en un iPhone nuevo, para con `BLOQUEANTE:` y no inventes el contrato.
3. Y23-03 · Entrar con iCloud privado (atajo `#fin-icloud`). Encaje visual; «Traer mis datos» cuando hay datos. Con iCloud privado no hay Grupos en la bienvenida. No quites el reinicio de iCloud privado (cambio técnico aparte). Nota: la ficha dice «ver Y23-12» y es un error; la referencia correcta es Y23-06 / Y23-13.
4. Y23-04 · Conversación de tres preguntas (atajo `#fin-s_nombre`). Nombre (propuesto el de Google o Apple), moneda, y «Gastos e ingresos» o «Solo gastos». Se quita «Prefiero crearlas yo». Termina en la llegada del lote 01.
5. Y23-06 · Entrada por Grupos (atajo `#grp`). Tres caminos y la invitación, encajados en la bienvenida nueva. Splitwise y Tricount salen del alta.

Reglas del lote:
- Los textos exactos y el comportamiento salen del SPEC y del prototipo. No se reabren decisiones. Si el artifact y la ficha no coinciden, manda la ficha y se avisa en el cierre.
- Compara con el prototipo (https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6, versión 35) y deja capturas antes y después de lo que se vea, en `capturas/` del worktree.
- Accesibilidad de la ficha «Cómo usar esta especificación»: Reducir movimiento deja solo fundidos y las páginas que avanzan solas se quedan quietas; VoiceOver no avanza solo; texto grande no corta.
- Textos en español neutro, con «tú», según docs/planning/BRAND-VOICE.md. Los textos marcados «de la app» se copian de Localizable.strings, no se reescriben.
- Un test de comportamiento por card (unit o XCUITest según `qa/coverage-index.json`). Review adversarial obligatoria.
- Si un punto exige una decisión de producto que no esté ya en el SPEC, sepáralo y déjalo pendiente con su pregunta; no elijas alternativa. Infraestructura o un hueco del servidor: `BLOQUEANTE:`, sin inventar.
- No choques con otras sesiones de bienvenida ni con los lotes 2.3 ya en cola: si comparten fichero, rebasa y cita.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:55 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- La especificación oficial vive en `docs/onboarding-2-3/SPEC.md` (entró por el PR 873 en 2.2; tras el merge tiene que estar en origin/2.3). Léela completa para las cards de este lote y no implementes lo que sea de otra card.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve las cards a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 (Frank, 12-nov 10:40 Lima, modo semi)

Medido antes de decidir:
- `origin/2.3..origin/2.2` = 0: 2.3 tiene lo de 2.2. La rama nació de 2.2 y se avanzó (fast-forward) a `origin/2.3`.
- Lote 01 (`bienvenida-2-3-base-mazo-pestanas-permisos`, la llegada y el mazo) está ABIERTO en cola de auto-merge. Se
  construye sobre 2.3 y se rebasa una vez antes del gate; la conversación termina en `onComplete` del alta, que es la
  entrada a la llegada del lote 01.
- El artifact v35 no se lee desde la Mini: se usó su fuente, traída de la Max (`07-welcome.js`, `08-flow.js`,
  `08b-chat.js`). Configuración oficial del prototipo: `S.g = "g3"`, `S.bg = "f2"`, `S.acc = "c2"`.
- **Contrato del servidor (Y23-02): NO contesta el proveedor con que se creó una cuenta en un iPhone nuevo.**
  `GET /account/exists` busca por el `sub` de la identidad, no por correo, y no devuelve proveedor; el proveedor solo
  sale en el claim (`existing_stable`) y en el faro de iCloud-KV (mismo Apple ID). ⇒ `BLOQUEANTE:` consultado al bot
  (A seguir con el contrato de hoy / B dejar el acceso con el elector / C parar). Mientras, se avanza con 01, 03, 04, 06.
- **Choque de textos:** la decisión 51 de 2.3 (9-nov, «con la bienvenida») retira «iCloud privado» y «nube de Yala», y
  `DosNombresDeSitioTests` lo hace cumplir. ⇒ «Entrar con mi iCloud» y el pie «En tu iCloud» / «En tu cuenta de Yala».
  Menor y reversible; se avisa en el cierre.

Decisiones (menores, sin preguntar):
1. La vitrina sustituye al Hero en el mismo step (`.hero`) del contenedor: el portal de salida y las puertas de hoy no
   se tocan. «Empezar» y el elector dejan de ser la entrada; el elector sigue alcanzable desde «Crear otra cuenta».
2. Vitrina «g3»: seis funciones en este orden — Lee tus tickets (PRO), Anota con tu voz (PRO), Ordena tus gastos,
   Divide cualquier gasto, Cuida un presupuesto, Quién le debe a quién — con «Dividir gastos con amigos ›» en las dos de
   grupos, que abre la puerta de Grupos («Cuentas claras con tus amigos.», tres funciones, solo Google y Apple).
3. Rotación cada 4 s; se para con Reducir movimiento y con VoiceOver; tocar pausa; deslizar cambia de función.
4. La mascota: solo su espacio reservado (círculo punteado), oculto a VoiceOver.

### Respuestas y decisiones posteriores (12-nov)

- **Jürgen, 11:14 — opción A** del `BLOQUEANTE:` del proveedor: se queda lo del artifact v35, con el contrato de hoy, sin
  volver al elector. Mitigación: aviso antes de crear («¿Creaste tu cuenta con Apple? Entra con Apple…») con su botón.
  Mejora de servidor en `tickets/backlog/account-exists-should-return-the-creation-provider.md`.
- Acceso único = `WelcomeCloudSignInView.Entry.unified`: firma, verifica y enseña «Vamos a crear tu cuenta» o «¿Cargamos
  tus datos y entramos?». **Las dos hojas llevan el consentimiento de la nube** (sus tres puntos, pie y política): la de
  crear porque lo pide la ficha; la de entrar porque, sin él, el adopt subía `now()` como fecha de un consentimiento que
  nadie vio (review adversarial). El prototipo no lo dibuja en la de entrar: se avisa en el cierre.
- «Vamos a crear tu cuenta» conserva la sesión (si no, Apple pedía su hoja dos veces y perdía nombre y correo).
- Grupos (Y23-06): «Solo crear mi cuenta» reusa la rama del organizador y termina en la pregunta del nombre del primer
  grupo (Grupos vacío). Orden distinto del prototipo (allí la cuenta va antes de «¿Qué quieres hacer?»): se reusan las
  pantallas de Grupos que ya existen («Existe con ajustes»), con el proveedor de la vitrina lanzado solo.
- Seams nuevos de XCUITest: `-uitest-private-gate-icloud-has-data` y `-uitest-unified-access-phase <create|confirm>`.
