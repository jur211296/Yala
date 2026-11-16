Yala
# Yala web, lote 2: resumen, tendencias, próximos cobros, suscripciones y acceso con QR
---
card: tablero-yala-web-lote-2-segun-el-plan-aprobado-7yhc
toca: webapp/, shared-core/, docs/web-app/, Yala/App/Views/ConnectedBrowsers/, Yala/Services/ConnectedBrowsers/, YalaTests/ConnectedBrowsers/, tickets/backlog/yala-web-lote-2.md, tickets/done/yala-web-lote-2.md
depende: Yala/yala-web-beta
esfuerzo: high
cierre: cierra-sola
---

## Contexto
Jürgen aprobó la maqueta y el plan de lotes de Yala web, y el 14-nov pidió avanzar más lotes ya en 2.3, sin esperar a 3.0. Los cimientos (lote 0) están mergeados y la beta (lote 1) va antes que este encargo.

## Qué se pide
Construye el lote 2 tal como lo define `docs/web-app/index.html`: resumen, distribución, tendencias, próximos cobros, suscripciones y el acceso con QR (con su cambio en «Navegadores conectados» del iPhone, si el plan lo pone en este lote). Escribe primero el ticket `tickets/backlog/yala-web-lote-2.md` con el alcance exacto que tomas del plan, y muévelo a done al cerrar. Usa `shared-core` para los cálculos y suma pruebas de paridad con lo que muestra la app de iOS.

## Reglas
- Sigue `docs/web-app/index.html` (en `origin/2.3`) y las decisiones aprobadas por Jürgen (artifact https://claude.ai/artifact/JN7jw8J1UXBQGNNpLNErAe): Worker en Cloudflare, React con TypeScript, `shared-core` con pruebas de paridad con iOS, sesiones con revocación desde el iPhone y lector del servidor de solo lectura salvo que el lote diga explícitamente lo contrario.
- Solo staging (`yala-web-staging.misty-surf-6866.workers.dev`). No toques Production de CloudKit ni de Supabase, ni el dominio real. Turnstile sigue con las llaves de prueba de Cloudflare; el widget real lo crea Jürgen.
- Nada de secretos en el repo, el chat ni el cierre.
- Si el lote pide algo que el plan no deja decidido y cambia seguridad, datos de usuarios o el modelo de permisos (por ejemplo, escribir desde la web), es vital: en modo nocturno, checkpoint recuperable y card «Espera decisión» para Jürgen con opciones y recomendación; lo demás, menor y reversible, lo decides tú y lo anotas.
- Si el lote toca iOS, pruébalo de punta a punta en el iPhone 14 por DeviceMCP; puedes usar un segundo simulador si lo necesitas (en la Max el tope es 2, en la Mini 1).
- Bloque de pruebas de interfaz:
  - Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final.
  - Si una prueba falla 2 veces por timeout, anótala como inestable en el cierre y sigue.
  - Tope total de 30 min en pruebas de interfaz; al llegar, checkpoint o pregunta según el modo.
  - Ninguna espera de más de 3 min sin escribir avance; nada de bucles de 10 min ni comandos a ciegas en segundo plano.
  - Antes de compilar en iOS mira la carga: si otra sesión compila con xcodebuild en la misma máquina y la carga pasa los núcleos, espera en tramos cortos con aviso.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.
- Commits y PR sin firma de IA. Textos de la web en los idiomas que ya tiene Yala, en español neutro latinoamericano para el español.
- La sesión arranca sobre `origin/2.3`; justo antes del PR, `git fetch` y un solo rebase sobre 2.3.
- Dependencias: este lote corre después del anterior porque ambos tocan `webapp/` y `shared-core/`. Si al empezar el anterior no está mergeado en 2.3, no adivines: checkpoint y card «Espera decisión».
- Entrega final: artifact visual de Claude que facilite decidir; no Markdown, PDF ni documento de puro texto. Debe mostrar las pantallas nuevas en staging, qué quedó y qué no.
- Termina con /cerrar-total si el lote quedó completo y verde. Si no, en modo nocturno checkpoint sin mergear ni desplegar lo incompleto. Deja «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con su motivo o «Nada».

## Cómo se sabe que está bien
Las pantallas del lote 2 funcionan en staging con datos de prueba, los números cuadran con la app de iOS en las pruebas de paridad, las pruebas están verdes, el PR va contra 2.3 y el artifact visual está enlazado en el cierre.

## Paso 0 — decisiones (resueltas en semiautónomo, sin preguntar: ninguna es vital)

Detalle y mediciones en `tickets/backlog/yala-web-lote-2.md`. Resumen:

- **Alcance:** Estadísticas (Resumen, Distribución, Tendencias), Pagos planificados (próximos cobros y suscripciones) y
  vincular con el iPhone por QR. Del lote 2 del plan quedan fuera, por no pedirlos el encargo: Presupuestos, Grupos en
  lectura, ⌘K y CSV, y los 16 idiomas (la web sigue en español e inglés).
- **Dependencia:** la beta (lote 1) estaba en cola de auto-merge con todo verde menos `tests`, en curso. Se trabaja
  sobre su rama y se rebasa sobre 2.3 antes del PR.
- **Períodos:** este mes, mes pasado, este año. **Distribución:** como `TopSpendingCategoriesCalculator`.
  **Tendencias:** entradas y salidas de 6 meses. **Próximos cobros:** 30 días con el calendario del iPhone, sin «ya
  pagado». **Suscripciones:** pagos de tipo suscripción (la app no detecta suscripciones).
- **QR:** código de 60 s ligado al navegador por cookie y PKCE; el iPhone aprueba con su sesión tras Face ID o código;
  Durable Object por código. Face ID solo en el Info.plist de Yala Dev.
- **Paridad:** se amplía el golden que escribe la app (`MCPAppParityGoldenTests`).
