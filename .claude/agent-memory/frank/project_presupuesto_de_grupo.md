---
name: presupuesto-de-grupo
description: El tope de gasto por grupo está en prod (PR #91, g14_01). Qué queda abierto — device-QA, tres migraciones de staging y el despliegue del Worker que reenciende el Merkle.
metadata:
  type: project
---

**Cerrado en código y aplicado en producción el 2026-09-07.** Un grupo puede tener un tope de gasto,
con barra de progreso en sus registros y aviso al cruzar 50/75/90/100 %. Un solo campo nuevo
(`budgetLimitAmount`), como se decidió el 6-sep.

## Lo que queda abierto, y de quién es

1. **Device-QA de dos teléfonos.** No es mío: pide TestFlight y App Attest en `enforce`. Que el tope
   que fija un admin aparezca en el teléfono de otro miembro, que un no-admin no pueda cambiarlo, y que
   el aviso llegue como notificación.
2. **Staging arrastra TRES migraciones** — g13_04, g13_05 y g14_01. **El procedimiento ya está
   escrito: `docs/RUNBOOK-staging-ddl.md`** (8-sep), con orden, idempotencia y trampas; ver
   [[runbook-staging-ddl]]. Sigue sin haber credencial de DDL allí. Con g14_01 el drift ya muerde: fijar un presupuesto contra staging deja un dead-letter
   permanente, y un dead-letter **apaga el Merkle de ese grupo**.
3. **El Worker sin desplegar deja el Merkle de Grupos apagado**, a propósito y sin daño: los clientes
   saltan por el guard de canon. Vuelve cuando Jürgen despliegue y el parque converja.

## Por qué `canon_version` subió a c2, por si alguien lo quiere revertir

**No es cosmético y no se toca sin leer esto.** El canal de Grupos **no manda
`X-Yala-Capability-Set`** (el personal sí), así que el server no puede podar columnas por versión de
cliente. Como el root del Merkle se calcula sobre TODAS las columnas del manifest —y el canon emite
`null` para las que la fila no trae—, **una columna nueva cambia el root de todas las filas**. Sin el
bump, cada cliente con el contrato anterior habría reportado divergencia falsa en el 100 % de sus
grupos, con reset de cursores y re-pull por sesión, y el canario de divergencia quemado. Con el bump,
caen en el guard de canon y **saltan**. El arreglo estructural está en
`groups-canal-sin-capability-set`.

## Lo que conviene recordar del cómo

- **La premisa del ticket era falsa por tercera vez** —hablaba de CloudKit, cero ocurrencias en `Yala/`—
  y la nota del owner ya pedía comprobarla. Medirla costó un `grep`.
- **Cifrar el tope destapó una trampa que llevaba meses ahí**: la normalización de escala del cifrado
  estaba atada al nombre literal `'amount'`, con un comentario que decía «es la ÚNICA columna †
  numérica». Era cierto hasta que dejó de serlo, y con el cliente de hoy el fallo habría sido
  **byte-idéntico por casualidad**. Un comentario que afirma una unicidad es una afirmación con fecha.
- **El control negativo necesita su propio control positivo.** Mi primera medición del «no-admin no
  puede» capturaba solo excepciones, y el RPC no lanza: devuelve `{"noop":true,...}`. Lo que zanjó el
  asunto fue mirar el VALOR EN DISCO tras el intento, y comprobar que el mismo no-admin sobre una
  columna vieja recibe el mismo rechazo — o sea que protege la RLS, no un accidente del campo nuevo.

Relacionado: [[verificar-backend-yala]] · [[la-premisa-del-encargo-tambien-se-mide]] ·
[[review-adversarial-caza-lo-mio]]


## El ticket salió de `in-progress` el 2026-09-08

Estuvo en `tickets/in-progress/` con `status: in-progress` **desde que el PR #91 se mergeó** (7-sep,
21:53 UTC) hasta el día siguiente. Coherente consigo mismo —carpeta y frontmatter cuadraban— y
mentiroso con la realidad: no quedaba trabajo, quedaba device-QA. Ahora está en `tickets/qa/`, y
`in-progress` quedó **vacío**, que es lo que corresponde con la cola en pausa.

⇒ **Mergear el PR no mueve el ticket.** El cierre de una sesión de encargo tiene que moverlo a mano,
y el sitio es `qa/` mientras quede device-QA — nunca `done` por el hecho de que el código esté
dentro.
