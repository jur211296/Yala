Yala
# Decidido 9-nov 2.3 · Nube: dos nombres fijos, «En tu iCloud» y «En tu cuenta de Yala»
card: tablero-2-3-nube-dos-nombres-fijos-en-tu-icloud-c1f9
toca: Yala/App/Views/Settings/, Yala/App/Views/Onboarding/
esfuerzo: high
depende: Yala/merge-corto-2-2-en-2-3

Base: origin/2.3 en jur211296/Yala. Un solo PR y cierre autónomo (cierra-sola); `/cerrar-total`. Lanzamiento siempre --permission-mode bypassPermissions. Commits y PR sin firma de IA. No tocar marketing, producción, auth, datos reales, trabajo de otras sesiones ni colas. Antes de actuar comprobar PRs mergeados/abiertos y tablero: si ya está corregido, verificar y documentar; no duplicar. Justo antes del gate: git fetch y un solo rebase sobre origin/2.3; no esperar CI ajeno fallido. Simuladores: Mini máximo 1; Max máximo 2 o iPhone 14 por DeviceMCP permitido. Pipeline serial: limpiar solo recursos propios/huérfanos cerrados, build xcodebuild -jobs 2 sin sim encendido, boot, probar, apagar/limpiar solo sim y DerivedData propios al cerrar. Nunca borrar datos de dispositivos reales. En franja 22–05 Lima, dudas que requieren elección se preservan íntegramente en rama/commits y se pausa/reanuda con mecanismo existente liberando máquina para el siguiente; no esperar bloqueando ni asumir respuesta. No nuevas rutinas/wakes. Descripción corta en español de cada comando Bash.

## Contexto
Discusión del artefacto 2.3, decisión 51 (T1, con la bienvenida). Card reutilizada. Ficha: docs/ux/revision-vistas-2.3/41-nube-almacenamiento/ficha.md. Unos 60 textos en 16 idiomas.

## Encargo y criterio de terminado
Implementar SOLO este punto:
1. En toda la app y en la bienvenida, solo dos nombres: «En tu iCloud» y «En tu cuenta de Yala», con «Pasar a» / «Volver a». «La nube» queda solo como explicación. La cuenta de Yala es una (grupos y, si quiere, datos).

Reglas del lote:
- La decisión ya está tomada el 9-nov (`docs/ux/revision-2-3-artefacto/fuente/decisiones-discusion.md`). Implementa exactamente la opción elegida; no reabras la decisión ni ofrezcas alternativas.
- Antes de cada punto: confirma en código que sigue vivo en origin/2.3 y corre `git log origin/2.3..origin/2.2 -- <vista>`. Si 2.2 ya lo arregló, no lo portes a mano: documéntalo en el PR y queda para la decisión de integrar 2.2 en 2.3 (card tablero-2-3-no-tiene-los-arreglos-de-2-2-de-las-3a6c).
- Un test de regresión por punto (unit o XCUITest según `qa/coverage-index.json`), rojo sin el arreglo y verde con él. Capturas antes y después de lo que se vea.
- Textos nuevos según docs/planning/BRAND-VOICE.md y en los 16 idiomas, cuando toque copy.
- Cambia la bienvenida a la vez. No inventes un tercer nombre.
- Tickets citados: a `tickets/qa/` con guion o a `done` si no hay nada que probar a mano; `docs/TICKETS.md` al día.
- gate de proyecto.
## Añadido por Frank (Jürgen, 10-nov 6:03 Lima)
- Este lote espera en la cola a que cierre el merge de 2.2 en 2.3. Antes de nada, comprueba que `git rev-list --count origin/2.3..origin/2.2` dé 0 o casi 0. Si 2.3 no tiene lo de 2.2, para de inmediato con un `BLOQUEANTE:` corto.
- Haz tú el QA en el simulador o en el iPhone 14 por DeviceMCP y mueve la card a done con evidencia. Solo queda en qa lo que de verdad necesite la mano de Jürgen, y lo dices en el cierre.

FIN

## Sobre el catálogo de textos (`Yala/Resources`)

Jürgen (10-nov 12:54 Lima) sacó `Yala/Resources` del `toca:` de los lotes 2.3 para que corran dos sesiones a la vez. Puedes editar el catálogo de textos igual, pero otra sesión puede estar tocándolo en paralelo: antes de abrir el PR y de cerrar, ponte al día con `origin/2.3` (o la base del encargo) y resuelve cualquier cruce en `Yala/Resources` conservando los textos de las dos ramas. Anótalo en el cierre.

## Paso 0 — decisiones

> Resueltas en autónomo (modo semi, sin decisión vital pendiente): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes: `origin/2.2` no tiene nada que no esté en `origin/2.3` (0 commits). En `es-419` hay 142 textos que
usan «la nube», «iCloud privado», «modo privado», «Migrar» o «desvincular», todos referenciados desde el código, y ~15
con «volver a iCloud» sin «tu». Dos PR abiertos en cola tocan la misma zona: «volver a tu iCloud en hojas que dicen la
verdad» (#910) y «Cambiar de cuenta en una fila» (#916).

**D1 · ¿Solo textos o también la pantalla «elección con las dos opciones a la vista» de la maqueta T1?** → Solo textos.
Por qué: la decisión 51 registrada habla de nombres y verbos («~60 textos en 16 idiomas»); la forma de la pantalla la están
cambiando los lotes de las decisiones 53, 55 y 54 en otros PR. Alternativa descartada: rehacer la pantalla, que chocaría con esos PR.

**D2 · ¿Qué frases quedan prohibidas como nombre de sitio?** → «iCloud privado», «modo privado», «modo nube», «nube de
Yala», «cuenta en la nube», «cuenta de la nube», «cuenta Yala en la nube», «Migrar», «activar la nube», «seguir / sigues /
seguirás en la nube», «desvincular». «La nube» solo como explicación («tu cuenta de Yala, que vive en la nube»).
«Los servidores de Yala» se queda donde explica qué es la cuenta (consentimiento, privacidad, preguntas frecuentes).
Por qué: es lo que la ficha contó como nueve nombres; los servidores son la explicación honesta que el consentimiento necesita.

**D3 · Verbos.** → Ida: «Pasar a tu cuenta de Yala» (título, botón, confirmación; «Pasando a tu cuenta de Yala…» en
curso). Vuelta: «Volver a tu iCloud» («Volviendo a tu iCloud…»). Cuando la cuenta ya tiene los datos y se abre en otro
dispositivo (adopt) no hay paso entre sitios: «Usar tu cuenta de Yala en este dispositivo» y «entrar en tu cuenta de Yala».
Por qué: el verbo dice el destino, como pide T1. Alternativa descartada: «Activar», que es el verbo que T1 retira.

**D4 · «Sincronización iCloud» (otra fila de Ajustes).** → No se toca. Por qué: la decisión 54 (S1) funde esa fila con
«Dónde viven tus datos»; renombrarla ahora sería trabajo que esa card deshace.

**D5 · Textos de la IA y el avatar «Nube».** → Los 8 textos de la IA que dicen «tu cuenta en la nube» SÍ cambian (nombran el
sitio de los datos: «Con tus datos en tu cuenta de Yala, la IA puede leer…»). El avatar «Nube» no: es el nombre de un icono.

**D6 · Bienvenida.** → «En tu iCloud» y «En tu cuenta de Yala» como títulos de las dos opciones; la tarjeta del carrusel
«iCloud privado» pasa a «En tu iCloud»; «Tu cuenta Yala en la nube» pasa a «Tu cuenta de Yala». La línea de debajo dice
quién puede ver los datos (T1: «En tu iCloud» no dice «privado», lo dice la línea).

**D7 · Lo que prometen los textos (p. ej. «sin perder nada», «en pausa por si vuelves»).** → Solo cambian los nombres; el
contenido lo decide la decisión 53, en el PR #910. Por qué: alcance mínimo y no pisar ese lote.

**D8 · Choque con los PR #910 y #916.** → Los cambios se aplican con un script reaplicable (clave → idioma → texto). Justo
antes del PR: fetch + un rebase sobre `origin/2.3`; si alguno ya entró, se reaplica y se renombran sus textos nuevos con
los nombres viejos. Si entran después, el test de regresión (D9) les marcará los textos viejos que traigan.

**D9 · Test de regresión.** → Unit test que recorre `es-419` y falla si un texto (fuera de la lista de D4-D5) usa un
nombre prohibido de D2, y fija los títulos de los dos sitios a «En tu iCloud» / «En tu cuenta de Yala» en `es-419`, `en`
y `pt-BR`. Rojo sin el cambio, verde con él.

**D10 · Traducciones.** → 13 idiomas con traducción propia (agentes que entregan JSON, sin tocar los `.strings`); `es` =
`es-419`, `pt` = `pt-BR`; variantes adaptadas (es-ES tú, es-AR voseo, en-GB, pt-PT). Nombres fijados por idioma antes de
repartir, para que no salga un tercer nombre en ninguno.

**D11 · Regla durable.** → El vocabulario va a `.claude/rules/l10n.md` (sustituye el párrafo que citaba «Tu cuenta en tu
iCloud privado» / «Tu cuenta en la nube») y al glosario. Sin ADR: es convención de copy, no decisión de arquitectura.

**D12 · QA.** → Todo es texto visible en el simulador: capturas antes/después con un conductor XCUITest temporal (no se
commitea). La card va a `done` si nada pide la mano de Jürgen.
