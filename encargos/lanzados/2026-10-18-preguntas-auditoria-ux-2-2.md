# Sesión interactiva: preguntas de la auditoría UX 2.2 con Jürgen

Jürgen está delante ahora (18-oct 18:41 Lima) y quiere responder las decisiones pendientes de los lotes de la auditoría UX 2.2. Esta sesión es una conversación con él: NO toca código, NO usa simulador, NO abre PR. Va en paralelo con la sesión de Siri (no la toques).

## Qué haces
1. Lista las cards en espera de decisión: `tablero listar --proyecto yala --estado "espera decisión" --json` (unas 144). Quédate con las de la auditoría UX/UI 2.2 (título «UX 2.2 · L…» o «UI 2.2 · L…»), ordenadas por lote y número. Las de otro tipo, al final.
2. Pregúntale de a una (o de a tres si son del mismo flujo y cortas), en español neutro latinoamericano, sin ids de card (nombra por título y lote). Para cada una:
   - En dos o tres frases qué pasa hoy y a quién afecta.
   - Las opciones tal como están en la card, explicadas en llano, con la recomendada marcada y por qué.
   - Si la card trae capturas, dale la ruta para que las abra (`open <ruta>` funciona en esta Mac si te lo pide).
   - Pregunta con AskUserQuestion o como pregunta directa. Acepta respuestas cortas («B», «la recomendada», «todas las recomendadas de este lote»).
3. En cuanto responde, en el MISMO turno, registra en el tablero:
   - `tablero editar <id> --asignado frank --sin-pregunta --nota "Jürgen decidió el <fecha hora Lima>: <opción y matiz>." --siguiente-paso "Frank: implementar en 2.2 (agrupar con su lote)." --agente frank`
   - `tablero mover <id> --a "ready to launch" --agente frank`. Si la decisión es «dejarlo como está», muévela a `done` con la nota.
   - Ojo: `--nota` reemplaza la nota entera; si la card tenía nota, cópiala delante.
4. Si dice «salta» o «después», déjala como está y sigue. Si dice que paramos, para.
5. Cada 10 decisiones, dile cuántas van y cuántas quedan.
6. Al terminar (o cuando Jürgen pare), escribe un resumen en `~/Claude/entregas/Yala--preguntas-auditoria-ux-2-2/decisiones.md` con una línea por card decidida (título, opción, matiz) y las que quedaron sin responder. Ese archivo lo usa Frank para escribir los briefs de implementación agrupados por lote.
7. Cierra con /cerrar-total cuando Jürgen diga que terminó o no queden preguntas. No hay nada que commitear ni PR que abrir.

## Reglas
- Nunca nombres «OpenAI» al hablar de la IA; di «un servicio de IA».
- No toques los tmux salud--, sat-lab--, clinicas-dentales-bi-- ni los Yala-- que estén vivos.
- En ~/Yala no toques, commitees ni descartes los .ckdb, Yala.xcscheme ni encargos/pendientes/.
- No inventes opciones nuevas; si Jürgen propone una distinta, anótala literal en la nota.

## Paso 0 — decisiones (sesión interactiva, Jürgen delante)

- Orden: lote y número; las 4 del lote 1 ya estaban decididas e implementadas (PR #485) → Jürgen pidió moverlas a «in qa».
- Registro: helper en el scratchpad que conserva la nota previa delante de la decisión.
- Capturas: se envían al chat (SendUserFile) antes de cada tanda de preguntas, a pedido de Jürgen.
- Única escritura en el repo: memoria de Frank (`.claude/agent-memory/frank/`). Sin código, sin PR.
