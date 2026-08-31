---
id: staging-test-credentials-in-public-repo
status: backlog
priority: high
area: cloud
created: 2026-08-31
updated: 2026-08-31
---
# Las credenciales de los usuarios de test de staging están en el repo público

`jur211296/Yala` es **público** (`gh repo view` → `visibility: PUBLIC`). Las contraseñas de
las tres cuentas de test del Supabase de staging (`i5-user-a`, `i5-user-b`, `i5-user-c`
@test.yala) están escritas en claro en el árbol, junto a la `SUPABASE_ANON_KEY` y la URL del
proyecto. Con esas tres piezas, cualquiera puede pedir un JWT por password-grant y hablar con
el backend de staging como usuario autenticado. Lo que vea después lo limita RLS, no la clave.

No es catastrófico —son cuentas sintéticas en staging, sin datos reales— pero es una puerta
abierta a un backend real, y cerrarla es barato.

## Inventario medido (2026-08-31)

~25 apariciones en 16 ficheros. Las contraseñas NO se transcriben aquí a propósito.

| Dónde | Forma |
|---|---|
| `YalaTests/CloudSync/{PrefsSync,CloudSync,MigrationCutover,CloudAccountClaim}E2EStagingTests.swift` | literal JSON en el `httpBody` de `login()` |
| `qa/cloud/{cross-user-rls,cross-member-rls,pgcrypto-spike,push-e2e}-test.sh` | valor por defecto de `${USER_x_PASS:-…}` |
| `gateway/test/{sync,push.fanout,groups,account}.goldens.test.ts` | argumento literal de `login(…)` |
| `qa/cloud/README.md`, `qa/cloud/g3_02_*.sql` | documentadas en el texto |
| `docs/modo-nube/_archive/{groups-backend-v1,MODO-NUBE-HANDOFF-2026-07-28}.md` | citadas en archivo histórico |

**El hook de secretos solo ve 4 de las ~25.** Su patrón `par clave/valor` exige la forma
`"password":"…"`, así que caza los tests Swift y se le escapan los `.sh` (usan `A_PASS=`, no
`PASSWORD=`), los `.ts` (argumento posicional) y la documentación. Un tercer usuario,
`i5-user-c`, no aparecía en ningún hallazgo. Conviene no leer ese informe como cobertura.

## Trabajo

1. **Rotar primero** las tres contraseñas en Supabase staging. Es lo único urgente y no depende
   del resto: mientras no se rote, sacarlas del código no cambia nada — el histórico del repo
   público sigue teniéndolas, y reescribirlo no las desactiva.
2. Sustituir los literales por lectura de entorno en los tres frentes (Swift, `.sh`, `.ts`).
   Los tests Swift ya están gateados por `YALA_CLOUD_E2E=1` y los `.sh` ya aceptan
   `USER_A_PASS`, así que la forma existe: lo que falta es quitar el valor por defecto.
   Al construir el cuerpo JSON, evitar `"password":"\(var)"` — el patrón del hook lo seguiría
   viendo; usar un diccionario y `JSONSerialization`.
3. Documentar en `qa/cloud/README.md` qué variables hay que exportar para correr la batería.
4. Decidir qué hacer con las citas del `_archive/`: si se rota, quedan inertes y pueden
   quedarse como registro histórico.

## Notas

- La `SUPABASE_ANON_KEY` que está al lado **no** es un hallazgo: verificado que los 16 JWT del
  repo llevan `role: anon`, ninguno `service_role`. Es pública por diseño.
- Estas 4 apariciones son las que hoy bloquean cualquier subida al remoto desde este repo. Se
  decidió **no** exentarlas en `~/.claude/hooks/secretos-permitidos.txt`: son credenciales
  reales, y esa lista significa "he mirado esto y no es un secreto".
