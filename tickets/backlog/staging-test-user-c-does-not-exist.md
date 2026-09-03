---
id: staging-test-user-c-does-not-exist
status: backlog
priority: low
area: qa, cloud
created: 2026-09-03
updated: 2026-09-03
source: rotación de credenciales de test (2026-09-03)
---

# El usuario C de las cuentas de test no existe, y el .env lo prometía

## Lo MEDIDO (2026-09-03)

Consultando `auth.users` del Supabase de staging (`fostjbbwstyuunmmefuk`) sólo existen **dos** de las
tres cuentas que la batería documenta:

| Cuenta | Estado |
|---|---|
| `i5-user-a@test.yala` | existe |
| `i5-user-b@test.yala` | existe |
| `i5-user-c@test.yala` | **no existe** |

No es que su contraseña estuviera rotada: la fila no está. El fichero
`~/Secrets/yala-supabase-test/test-users.env` la prometía con email y contraseña, y su login fallaba
como los otros dos —que sí estaban rotados— lo que hacía indistinguibles dos problemas distintos.

## Impacto: bajo, y ya estaba previsto

`qa/cloud/README.md` declara C como **opcional**: «solo `cross-member-rls-test.sh`; sin ella, ese
sub-caso cae a B». O sea, la batería no se rompe — ese sub-caso simplemente prueba menos de lo que su
nombre sugiere (una RLS *cross-member* con dos usuarios en vez de tres).

## Dos salidas

1. **Crearla** en staging y añadirla al `.env` (que hoy ya no la menciona, se retiró en la rotación
   del 2026-09-03). Recupera la cobertura real del test cross-member.
2. **Declararla muerta**: quitar C del README y renombrar el sub-caso para que no prometa tres
   usuarios. Más barato y honesto si nadie va a usarla.

Lo que no conviene es el estado actual, en el que el documento describe una cobertura que no existe.
