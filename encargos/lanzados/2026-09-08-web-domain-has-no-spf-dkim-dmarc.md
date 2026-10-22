# Prep DNS: checklist listo para pegar SPF/DKIM/DMARC de yala-app.pe (Jürgen teclea en los paneles)

## Contexto
Ticket: `tickets/backlog/web-domain-has-no-spf-dkim-dmarc.md` (high).
Cola nocturna / autónomo (Jürgen 2026-09-07): fx-manual ✓ → unit-suite ✓ → rojo-xcuitest ✓ → **este (prep)**; `groups-owner-debt-no-heir-dead-end` parado a decisión.

`yala-app.pe` no publica SPF, DKIM ni DMARC. Decidido (2026-09-03): rua `admin@yala-app.pe`, empezar en `p=none`. Los pasos los teclea el owner en admin.google.com y punto.pe (ambos exigen autenticarse). Tú NO entras a esos paneles.

Quien arranca EN CONTEXTO LIMPIO: no ve nuestra conversación.

## Que se pide
1. Re-medir con `dig` contra el autoritativo `ns.rcp.net.pe` (SPF raíz, `_dmarc`, selectores DKIM habituales, MX/A intactos). Anotar qué sigue ausente.
2. Dejar un checklist **listo para pegar** (host + valor exacto) siguiendo el ticket: DKIM 2048 desde Workspace sin «Iniciar autenticación» aún; luego los tres TXT en punto.pe; luego «Iniciar autenticación»; verificación `dig` al autoritativo; correo de prueba.
3. Incluir las trampas del ticket (no pisar los TXT de verificación Google/Apple; caché negativa 2 h; DKIM largo → 1024; rua del propio dominio).
4. Parar y avisar a Frank cuando el checklist esté listo: Jürgen tiene que autenticarse y pegar. No hay merge de producto aquí salvo docs/board si actualizas estado del ticket a «esperando pegado del owner».

## Que NO hay que tocar
- marketing/, clinicas-dentales-bi
- No autenticarte ni operar admin.google.com / punto.pe
- No tocar registros MX ni el A de Vercel
- No subir `p=` por encima de `none`
- No relanzar ni tocar `el-job-de-tests-del-ci-no-tiene-timeout` (ya cerrado vía #93; el pendiente en disco está stale)

## Como se sabe que esta bien
- Medición actual con dig al autoritativo
- Checklist pegable con valores/trampas del ticket
- Aviso a Frank pidiendo el pegado de Jürgen (decisión/acceso real)
- Board + `docs/TICKETS.md` coherentes si moviste el ticket

## MODO AUTÓNOMO HASTA EL PEGADO
Trabaja sin preguntar hasta tener el checklist listo. Ahí PARAS: hace falta acceso de Jürgen. Bugs/decisiones nuevas → ticket propio (`--solo-crear`). Si cierras el tramo de prep: resumen de usuario al webhook + no llames `/cerrar-total` como si el DNS ya estuviera publicado — el ticket sigue abierto hasta que Jürgen pegue y verifiquemos.

Avisos al bot dueño (Frank): POSTea al webhook local de la Mini (URL y key en fichero local, no en git; no las escribas en el repo) cuando:
  (1) necesitas una decisión de producto o de acceso de Jürgen;
  (2) abriste el PR o dejaste preview/artifact listo;
  (3) terminaste el tramo de prep y vas a parar — incluye resumen corto en lenguaje de usuario;
  (4) acabaste un tramo y no tienes siguiente paso claro — una vez, no en bucle.
NO avises por: un test rojo que vas a reclasificar, un build a reintentar, ni ruido de CI advisory. URL/key solo en la Mini.
