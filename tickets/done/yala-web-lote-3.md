---
id: yala-web-lote-3
status: done
priority: high
area: web
created: 2026-11-14
updated: 2026-11-14
source: encargo 2026-11-14-yala-web-lote-3 (card tablero-yala-web-lote-3-segun-el-plan-aprobado-qf6g)
---
# Yala web, lote 3: Grupos desde el navegador

Cuarto lote de Yala web (plan en `docs/web-app/index.html`), sobre el lote 2. El 14-nov Jürgen pidió los lotes 2 y 3 ya
en 2.3. Las 13 decisiones del artifact siguen con la recomendada: la colección `decisiones` de su db sigue vacía (medido
con `ArtifactData` el 14-nov). Las que tocan este lote: **D3** («solo Grupos» entra en el lote 3), **D13** (la web no
crea cuentas hasta 3.0) y **D11** (la web no escribe en la sincronización personal hasta 3.0).

## Alcance, tomado del plan

Del lote 3 del plan:

1. **Añadir gastos de grupo, saldar e invitar.** Es escribir datos compartidos: ver «Paso 0», P1.
2. **Las cuentas «solo Grupos» pueden entrar.** Ven Grupos y Configurar; el resto de la app les explica que vive en la
   nube completa.
3. **Editar o descartar un borrador que el iPhone aún no recogió** (los que la web dejó con «Apuntar»).

Y, del lote 2 del plan, lo que el lote 2 dejó fuera y este lote necesita como base: **Grupos en lectura** (la lista con
lo que te deben y lo que debes, y el detalle con saldos, deudas, gastos y pagos), con las cifras del iPhone.

Fuera: Presupuestos, ⌘K, CSV y los 16 idiomas (resto del lote 2 del plan). La web sigue en español e inglés.

## Paso 0 — decisiones

Medido antes de decidir (14-nov, sobre la rama del lote 2, en cola de auto-merge con todo verde menos `tests`):

- Los datos de Grupos viven en Supabase con ocho columnas cifradas (`pgcrypto`). La llave (`GROUPS_ENC_KEY`) solo la
  tiene el gateway, que la pasa a los RPC lectores `groups_pull_rows_*` (SECURITY INVOKER). El rol de la web
  (`yala_mcp_reader`, el del conector de Claude) no tiene permiso sobre ninguna tabla ni función de Grupos.
- Las rutas de Grupos del gateway (`/groups/*`) usan `requireUserAndAttest`: staging en `observe`, producción en
  `enforce` (`.claude/rules/gateway-attest.md`). Un navegador no tiene App Attest.
- Los saldos del iPhone salen de `GroupBalanceService` (`Yala/Services/Groups/`): deudas por gasto y reparto, menos pagos
  confirmados, «Menos pagos entre ustedes» con `DebtSimplificationService` y, con «una sola moneda», todo convertido a la
  divisa del grupo con la última tasa.

| # | Decisión | Elegida | Por qué |
|---|---|---|---|
| P1 | ¿Cómo escribe la web en Grupos? | **Decisión vital de Jürgen**, preguntada el 14-nov 10:14 con tres opciones (rol propio de escritura por el gateway, borradores que sube el iPhone, o nada hasta 3.0). Se construye primero la lectura. | El plan lo deja abierto («hace falta una puerta para la web») y cambia el modelo de permisos. |
| P2 | ¿Por dónde lee la web los datos de Grupos? | Por el gateway, con una **entrada interna** (un *service binding* de Cloudflare entre los dos Workers, sin ruta pública) que usa el token de solo lectura de la web y la llave que ya tiene. | La llave no sale del gateway. El plan pone Grupos «por las rutas de Grupos del gateway». Darle una copia a la web repartiría la llave. |
| P3 | ¿Qué permiso nuevo hace falta en Supabase? | `web3_01` (solo staging): SELECT y los RPC lectores de Grupos para `yala_mcp_reader`, **solo si el token es del cliente de la web** (`client_id`) y la persona es miembro. Ni una escritura. | El conector de Claude comparte ese rol: con la condición del `client_id` no gana nada. |
| P4 | ¿Qué ve una cuenta «solo Grupos»? | Grupos y Configurar. Panel, Registros, Bandeja, Apuntar, Estadísticas y Pagos le explican que viven en la nube completa y cómo activarla. | D3. Sin nube completa no hay datos personales que enseñar. |
| P5 | ¿Qué grupos salen? | Los de membresía activa, sin los archivados ni los ocultos para todos, como la lista del iPhone. | La lista del iPhone; lo pendiente de aprobación no tiene saldos. |
| P6 | ¿Editar y descartar borradores escribe datos compartidos? | No: es la cola de borradores de la propia persona (D9, la del lote 1). Se edita y se borra por `id` y `user_id`, solo los de `source = web`. | Ya decidido en el lote 1: la web escribe en esa cola. |
| P7 | Datos de prueba | Se crean en staging, para los usuarios de prueba A y B, por las rutas del gateway que usa un iPhone (crear grupo, unirse, gasto, pago). | Sin grupos en staging no se puede ver ni medir la paridad en pantalla. Solo staging. |

## Pruebas

- Paridad: el golden de la app (`YalaTests/MCP/MCPAppParityGoldenTests.swift`) suma un bloque `grupos` con los casos de
  `GroupBalanceService`, y `shared-core` los comprueba.
- Web: pruebas unitarias del cálculo, de la entrada interna y de las rutas; e2e contra staging con A y B.
- Una sonda: con el token de la web, el rol no puede escribir en Grupos ni leer las filas de un grupo ajeno.

## Hecho (14-nov, staging)

- **Grupos en lectura** en la web: lista con lo que te deben y lo que debes (sin los archivados, como el iPhone) y
  detalle con quién le debe a quién, saldos por persona, gastos con tu parte y pagos. Español e inglés.
- **Cuentas «solo Grupos»** entran (D3): abren en Grupos, sin «Apuntar», y lo de la nube completa les explica por qué
  no tiene nada (409 `solo_grupos` en el servidor).
- **Borradores de la web**: editar y descartar desde la Bandeja lo que el iPhone aún no recogió.
- **Lectura segura**: entrada interna `WebGroupsReader` del gateway (service binding; la llave no sale del gateway) y
  `web3_01` en Supabase staging (solo el cliente de la web, solo miembros, ninguna escritura).
- **Paridad**: `shared-core/src/logic/groupBalances.ts` contra `GroupBalanceService` con su golden
  (`mcp/test/golden/groups-parity.json`, lo escribe la app); dos mutantes caen.
- **Datos de prueba** en staging: «Viaje a Cusco» (Ana, Beto y Caro) y «Depa Miraflores» (Ana y Beto), creados por
  las rutas del gateway que usa el iPhone.

Pruebas: web 95/95, conector 255/255 (con la paridad de Grupos), gateway 699 en verde (86 de staging se saltan offline); e2e contra staging 21/21;
gate de iOS en verde (las dos schemes, 2 suites de paridad, 20/20 checks del CI).

## Queda fuera

- **Escribir en Grupos desde la web** (añadir gasto, saldar, invitar): decisión de Jürgen, preguntada con opciones.
- Entrar con el iPhone por QR sigue siendo solo para la nube completa.
- «Solo Grupos» se decide al entrar: si la cuenta pasa a completa, hay que volver a entrar.
- Con 50 grupos la lista tarda unos 6 s (cinco lecturas por grupo); con pocos grupos, ~1 s.
