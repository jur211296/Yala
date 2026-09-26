# Documento de exploración: plugin de Yala para Claude (MCP remoto + skills), sin código de producto

## Contexto
Jürgen quiere valorar un plugin de Yala para Claude: un conector MCP remoto sobre la nube de Yala, con OAuth por usuario y solo lectura en la primera fase (saldos, movimientos, categorías, presupuestos, suscripciones recurrentes), más unas skills de análisis (gasto del mes, suscripciones sin usar, cómo va frente al presupuesto). Anthropic acaba de abrir un portal para enviar plugins y seguir su revisión: https://x.com/claudedevs/status/2103577007938228300
En paralelo hay sesiones en curso sobre el modo nube (cola A: sync, sign-out, adopt, wipe). Jürgen cree que el plugin no tocaría los mismos ficheros; hay que comprobarlo.

## Qué se pide
Un documento corto en `docs/exploracion/plugin-claude-mcp.md` que responda:
1. Qué herramientas expondría el MCP y con qué datos: nombre, entrada, salida y la tabla o endpoint de origen de cada una.
2. Cómo encaja con la API y la autenticación actuales del modo nube (Supabase, RLS, sesión): qué existe ya, qué falta (servidor OAuth, scopes de solo lectura, tokens por usuario, revocación) y qué depende de trabajo aún no terminado.
3. Paralelismo: si se puede desarrollar sin chocar con el trabajo en curso del modo nube. Ficheros, módulos, esquemas o contratos compartidos, con rutas concretas. Recomendación razonada: carpeta dentro del repo, paquete aparte o repo aparte.
4. Qué exige el portal de Anthropic para aprobarlo: privacidad, datos financieros, consentimiento, política de datos, revisión. Citar la fuente; lo que no se pueda verificar se marca como no verificado, nunca se supone.
5. Estimación de esfuerzo y propuesta de fases (fase 1 solo lectura; después, lo que tenga sentido).

## Qué NO hay que tocar
Ningún código de la app, del backend ni de migraciones. Nada en Supabase (ni staging ni prod), nada desplegado. No crear el plugin. No tocar marketing/. No compilar la app ni correr la suite de tests: hay otra sesión de Yala compilando en paralelo. Solo el documento, más el ticket y el índice del board.

## Cómo se sabe que está bien
El documento existe, responde a los 5 puntos con rutas y fuentes reales, y cabe en unas 2–4 páginas. PR con solo ese documento más el ticket, mergeado a 2.1, y cierre con /cerrar-total (ticket en tickets/ y docs/TICKETS.md al día).

MODO AUTÓNOMO: no preguntes «¿Sigo?» ni esperes aprobación por tocar más de 3 ficheros; implementa hasta PR, merge y /cerrar-total. De día (06:00–21:00 Lima) puedes preguntar a Jürgen con AskUserQuestion solo lo de producto o acceso; de noche, elige lo recomendado o aparca.

## Paso 0

Decisiones tomadas antes de escribir (sesión autónoma, sin preguntas a Jürgen: ninguna era de producto ni de acceso para *escribir* el documento).

- **Antecedente, no idea nueva.** El conector ya existe como diferido #22 en `docs/modo-nube/MODO-NUBE-DIFERIDOS.md:281` (FUTURO-v2). El documento parte de ahí y no lo contradice.
- **Ticket**: uno en `tickets/backlog/` para el plugin (no para la exploración), sin `priority` porque nadie la dio. Busqué duplicado: no hay.
- **Fuentes del portal**: solo docs primarias de Anthropic (claude.com/docs, support.claude.com). Lo que no aparece ahí se marca NO VERIFICADO.
- **Nada contra Supabase**: el esquema se lee del snapshot `supabase-staging.ddl`, no de la base. La doc de Supabase sí se consulta (es documentación, no el proyecto).
- **Las preguntas de producto** (gratis o Pro, solo usuarios de nube, «suscripciones sin usar») van al documento como decisiones abiertas, no a `AskUserQuestion`: el encargo pide explorar, no decidir.
- **Sin build ni tests**: el diff es todo `docs/` + `tickets/`, que el gate y el CI saltan.
