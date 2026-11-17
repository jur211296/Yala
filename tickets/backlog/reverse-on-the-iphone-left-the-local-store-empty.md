---
id: reverse-on-the-iphone-left-the-local-store-empty
status: backlog
priority: high
area: "modo-nube, migración"
created: 2026-11-16
updated: 2026-11-16
source: "prueba de punta a punta del encargo «Nube 2.3: los cinco bugs media» (iPhone 14, Yala Dev, staging)"
---

# Tras «Volver a tu iCloud», el iPhone se quedó sin ningún dato y salió «Datos no disponibles»

## Lo que pasó (medido el 2026-11-16, iPhone 14, iOS 27.2, Yala Dev contra staging)

1. Instalación nueva de Yala Dev (el App Group se conserva entre instalaciones). «Entrar con iCloud privado» → «Traer
   mis datos»: 6 registros, 5 cuentas, 67 categorías de este Apple ID.
2. «Pasar a tu cuenta de Yala» con Google (`test@yala-app.pe`, cuenta nueva): subió 533 filas; en el servidor, 9
   movimientos y 6 cuentas vivos.
3. «Volver a tu iCloud» → reabrir. La vuelta llegó a `icloudActive` sin esperar nada (`rUpload>icloudActive` 0 s, ninguna
   línea `uploadPending` ni `uploadFailedRows`).
4. Justo después: el Panel aún pintaba los datos de antes, pero Registros decía «Crea tu primera cuenta» y al tocarlo
   salió «Datos no disponibles · Se vació Yala en otro de tus dispositivos». El store personal del App Group
   (`YalaModel-Dev.store`) tenía **0 movimientos, 0 cuentas y 0 categorías**, y siguió así minutos después.
5. La copia del servidor seguía con sus 9 movimientos (congelada, `groups_only`).

Rastro del arranque tras reabrir: `rMount>rReconcile.awaitingQuiescence`, `deletingZombies` (3 s; el servidor no tenía
ningún borrado), `rebindingUUIDs`, `dedupHealed`, `rUpload>icloudActive`, y después `remoteWipeAlert`.

## Hipótesis (sin medir)

- Una señal de «Vaciar datos» vieja en el iCloud de este Apple ID (el iPhone 14 probó «Vaciar mis datos» el mismo día,
  card lplc) que el receptor tardío aplica al montar el espejo en la vuelta: se lleva lo creado antes de la señal. Si es
  esto, el iCloud tampoco tendría esas filas.
- O la vuelta no subió nada a iCloud (muestra a 0 en la primera observación) y el remonte dejó el store sin lo que la nube
  tenía.

## Qué falta

- Repetirlo en un Apple ID sin señal de «Vaciar datos» en su iCloud, contando el store antes y después del remonte.
- Mirar si el iCloud del teléfono conserva esas filas (otro dispositivo del mismo Apple ID, o la consola de CloudKit).
