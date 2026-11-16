Yala
# Conciliar los 19 PR abiertos contra 2.3: mergear lo vigente, cerrar lo reemplazado y ordenar las cards
---
toca: docs/qa/conciliacion-prs-2-3/
esfuerzo: high
cierre: cierra-sola
---

Rama base: 2.3. Pedido de Jürgen del 14-nov: hay 19 PR abiertos contra 2.3 sin mergear, varios de hace días, y hoy se mergearon 14 PR (bienvenida, nube, cerrar sesión, Yala web lotes 2 y 3, barridos del iPhone 14) que probablemente reemplazan parte de ellos.

Para cada PR abierto contra 2.3 (gh pr list --base 2.3 --state open), salvo el de «Conectar Gmail» que es borrador y NO se mergea, y los de esta tarde (tandas rojas de pruebas de interfaz y presupuesto pasado, que cierran sus propias sesiones):
1. Decidir con evidencia: vigente y mergeable / vigente con conflicto / reemplazado por lo ya mergeado / obsoleto.
2. Vigente, CI verde y sin conflicto: mergear (squash, sin firma de IA) y mover sus cards a in qa.
3. Reemplazado u obsoleto: cerrar el PR con un comentario que diga qué lo reemplaza, y mover o cerrar sus cards según corresponda.
4. Vigente con conflicto (por ejemplo «iCloud y cerrar sesión», que Jürgen ya autorizó desbloquear): no resolverlo en esta sesión salvo que sea trivial y seguro; encolar una continuación por PR con `lanzar-sesion Yala <slug> --nuevo --permission-mode bypassPermissions`, con toca acotado a los archivos del PR, cierre cierra-sola y permiso de segundo simulador en la Max o iPhone 14 por DeviceMCP.
5. Revisar las cards de 2.3 en «en curso» sin sesión viva (guía visual de usuario nuevo y onboarding 2.3 desde cero) y dejarlas en el estado real.

Sin carga de producto: nada de código nuevo salvo resolver un conflicto trivial. No toques CloudKit Production. Entregable: artifact visual de Claude con la tabla PR → decisión → motivo → cards tocadas, y fuente en docs/qa/conciliacion-prs-2-3/.

Lo menor y reversible lo decides con la opción recomendada y lo anotas en «Decidido sin consultar». Cierre: /cerrar-total según el modo de sesión fijado al arrancar, con «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada».

## Paso 0 — decisiones

> Resueltas en semiautónomo con la recomendación de la sesión (nadie delante). Se discuten en el PR.

**D1 · ¿Qué PR entran en el alcance?** → Los 15 abiertos contra 2.3 menos 613 (Gmail, borrador), 977 y 978 (esta tarde). Son 15, no 19: el «19» del encargo contaba a mano.
Por qué: es lo que mide `gh pr list --base 2.3 --state open` a las 16:51.

**D2 · ¿Se resuelve aquí algún conflicto «trivial»?** → No, ninguno.
Por qué: los 15 están en conflicto, y hasta los de solo documentos (973, 930) obligan a traer al PR el Swift entrado en 2.3; el pre-commit pide entonces el sello de `/gate` (build ×2, unit, XCUITest), con simulador, y en esta Max ya corre la sesión de las tandas rojas de UI. Alternativa descartada: `--no-verify`, que se salta la única red sin PR revisado.

**D3 · ¿Qué cuenta como «reemplazado»?** → Que lo mergeado en 2.3 arregle lo mismo o lo contenga (commits ancestros, mismo síntoma y causa, o el texto ya presente). Un PR cuyo código no está en 2.3 y nada lo sustituye es vigente aunque sea viejo.
Por qué: la medición de líneas añadidas presentes en 2.3 da 0–16 %; la antigüedad sola no reemplaza nada.

**D4 · ¿A qué estado van las cards de un PR vigente que no llegó a 2.3?** → A `blocked`, con un comentario (no en la nota, que `--nota` sustituye): qué PR, por qué no entró y qué continuación lo desbloquea. Las cards de decisión (nota de salud, archivar) se quedan en `done`: la decisión sí está tomada.
Por qué: hoy figuran en `done` o `in qa` sin que el código esté en 2.3, y QA sobre una build de 2.3 no puede verlas. Alternativa descartada: `in progress`, que volvería a ser «en curso sin sesión viva» hasta que el coordinador despache.

**D5 · ¿Una continuación por PR, o agrupadas?** → Una por PR, como pide el encargo, salvo 962, que va dentro de la de 973 (ya lo contiene).
Por qué: cada una con `toca:` de sus ficheros para que dos de Yala no se crucen.

**D6 · ¿Cómo cierra cada continuación?** → Actualiza la rama del PR existente con 2.3, resuelve, pasa `/gate` y deja el mismo PR en cola de auto-merge (ya lo está). No abre PR nuevo.
Por qué: conserva la descripción y el historial que Jürgen ya conoce.

**D7 · Cards «en curso» sin sesión viva.** → Guía visual de usuario nuevo: `done` (sus dos PR se mergearon el 7-nov y cumplen su «hecha cuando»). Onboarding 2.3 desde cero: `done`, la exploración de direcciones desembocó en la Bienvenida 2.3, construida y mergeada del 12 al 14-nov.
Por qué: no hay sesión viva de ninguna en la Max ni trabajo pendiente que dependa de ellas.

**D8 · ¿Cómo se evita que las continuaciones vuelvan a dejarse en conflicto entre ellas?** → Dos cadenas con `depende:` (una sesión de cada cadena a la vez) y cada continuación **espera a su propio merge** antes de cerrar, con tope de 90 min o dos vueltas.
Por qué: los 12 tocan los mismos `Localizable.strings` y `coverage-index.json`; si cada una cerrase en modo cola, el merge de la anterior dejaría en conflicto a la siguiente, que es justo cómo se quedaron colgados. Cadena 1: iCloud y cerrar sesión → cifrado y fotos → volver a iCloud → cambiar de cuenta → archivar. Cadena 2: Grupos → VoiceOver selectores → Estadísticas → categorías recientes → nota de salud → calendario (el único que hay que reescribir) → Tu IA. Alternativa descartada: doce sesiones sueltas en modo cola.

**D9 · «Tu IA registra en Yala» (#818): ¿cerrar como obsoleto o desbloquear?** → Desbloquear y, en la misma continuación, cambiar su transporte a la cola de borradores común.
Por qué: la herramienta, el OAuth de ChatGPT y Grok, el permiso y la fuente «Tu IA» siguen faltando; lo superado es solo su cola paralela, por la D9 del plan de Yala web, ya implementada en Yala web beta. Si al medir la cola común no cubre algo, la continuación lo pregunta. Alternativa descartada: cerrarlo y perder el trabajo que sí vale.

**D10 · El rojo de `tests` de #899.** → No es del PR: el runner se perdió a los 62 min sin ningún test fallido. La continuación lo vuelve a mirar tras su push.
