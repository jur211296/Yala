# Telemetría propia · construcción (decisiones confirmadas)
toca: docs/telemetria, workers de analítica / panel

Rama base: origin/2.3. Un solo PR contra 2.3, un solo cierre. Máquina: la libre (máx. 1 Yala por máquina). Simulador solo si el gate lo pide. Cierre autónomo. Termina con `/cerrar-total`.

## Contexto
La propuesta está en el PR 819 (https://github.com/jur211296/Yala/pull/819), `docs/telemetria/propuesta-2026-11.md` y la maqueta https://claude.ai/artifact/6RGD5czHr7HvP9cR3JmRBT. TelemetryDeck ya no está en el código; la 2.1 publicada ya manda datos al servidor de Yala en Cloudflare (Analytics Engine). Falta el panel por secciones con frases y reponer datos de Grupos, Pro y parte de Uso.

Card: «Telemetría propia en Cloudflare y dashboard en lenguaje natural, para reemplazar TelemetryDeck».

El 6-nov Jürgen confirmó las 8 recomendadas (todas A):
1. Volver a medir qué funciones se usan: un evento por función, uno al día.
2. El panel vive en un Worker propio con Cloudflare Access.
3. Historia de más de 90 días: resumen diario en D1.
4. Frases con plantillas fijas (no un resumen semanal de IA).
5. Grupos, Nube y Pro se cuentan desde el servidor.
6. Cerrar ya la app en TelemetryDeck.
7. El manifiesto de privacidad declara el identificador de aparato como «vinculado»: se revisa en la sesión de ingesta (no lo asumas; si cambia un texto legal, pregunta con `preguntar-bot`).
8. Reescribir el «hecha cuando» de la card sin envío doble.

## Qué se pide
Construir según la propuesta y esas 8 decisiones. Panel usable, ingesta/eventos que falten, resumen diario en D1, conteos de servidor, cierre de TelemetryDeck si aún queda algo por cerrar. Actualiza la card (hecha cuando + nota) y déjala en `in qa` con un guion corto. Si una decisión de producto o un texto legal no está claro, `preguntar-bot` con opciones; no saltes ni asumas.

## Qué NO hay que tocar
marketing/. No inventes métricas que la propuesta no pide. No despliegues a producción por tu cuenta: deja los pasos de deploy anotados para Dan/Jürgen.

## Hecha cuando
Panel y datos alineados con la propuesta y las 8 A; card al día; gate verde; `/cerrar-total`.

## Paso 0

*Resuelto por la sesión el 2026-11-06 (Frank). Lo marcado «pregunta» se consultó al bot dueño.*

- **Base:** la rama nació de 2.2; se reubicó sobre `origin/2.3` como pide el encargo (sin commits propios que mover).
- **Dónde vive cada cosa.** El gateway se toca lo mínimo: `use` entra en la lista de eventos de `/metrics`; el aviso de Apple (`/webhooks/appstore`) apunta en Analytics Engine el tipo de aviso (sin ids ni importes); y el limitador de la IA marca cuándo una petición gasta la última pregunta del día (un apunte por persona y día, no por intento). Todo lo nuevo va en un Worker aparte, `panel/`: cron diario que resume en su propia D1, lectura de Analytics Engine por la API SQL y de Supabase por una RPC de solo conteos, y la página. Un fallo del panel no toca el sync.
- **Conteos de Supabase:** rol de máquina `yala_stats` con EXECUTE sobre una sola función `yala_stats_counts()` que devuelve números (molde `yala_push`, g8_02). Migración + rollback en `qa/cloud/`; aplicarla es de Jürgen/Dan.
- **D1 sin identificadores:** solo agregados por día. Los `install` se usan en memoria durante el cron (retención) y no se guardan.
- **Retención:** cohorte = instalaciones con `register` el día C; vuelve a 7 = abrió entre C+7 y C+13; a 30 = entre C+30 y C+36.
- **Pro desde Apple:** pruebas (alta con oferta de prueba gratis), compras, renovaciones, cancelaciones de la renovación, vencimientos y reembolsos. «Se convirtieron en suscripción» NO se pinta: Apple no lo distingue de una renovación sin cruzar transacciones. Asumido.
- **Costo de IA:** tabla de precios por modelo en el panel (los de `gateway/bench/candidates.ts`); modelo sin precio = se dice, no se inventa.
- **Salud (umbrales):** canarios informativos (éxitos, entregas, desenlaces) no colorean; el resto: ámbar con ≥1 aparato, rojo con ≥3. Asumido, ajustable en un fichero.
- **Privacidad:** cortes con menos de 3 aparatos se pintan «menos de 3».
- **Access:** el Worker exige y verifica el JWT de Cloudflare Access (equipo + AUD por variable) y el correo `admin@yala-app.pe`. Sin configurar, responde 503: falla cerrado.
- **Manifiesto (decisión 7):** `DeviceID` vinculado es correcto (token de avisos de Grupos y llave de App Attest van con la cuenta; Apple pide un solo «vinculado» por tipo). No cambia ningún texto legal. Jürgen confirma que la ficha de App Store Connect dice lo mismo.
- **Respuesta (Jürgen, vía el bot, 6-nov):** decisión 1 = **C**: las ~15 funciones, más «vio la oferta de Pro», «chocó con el límite del plan gratis» y los pasos del alta con dónde abandonan. Los pasos del alta viajan como `use` con nombre `alta.<paso>` (uno al día por paso). TelemetryDeck en su web lo cierran Jürgen o Dan: pasos en el PR, la sesión no lo toca.
- **Sin deploys.** Pasos para Dan/Jürgen en el PR y en `panel/README.md`. Orden obligatorio: gateway con `use` antes de cualquier build que lo mande (si no, el gateway viejo rechaza el lote entero y se pierden los canarios del lote).
