---
id: reopen-yala-only-for-private-icloud
status: backlog
priority: medium
area: "modo-nube, onboarding, grupos"
created: 2026-10-21
updated: 2026-10-21
source: "tablero-reabre-yala-solo-cuando-la-persona-entra-ypit (QA guiado TF19, 2026-10-20)"
---

# «Reabre Yala» solo cuando la persona entra en su iCloud privado

## La regla de Jürgen (2026-10-20)

«Solo deberíamos pedir reabrir cuando el usuario pida algo privado. Es el único momento en el que se justifica con
privacidad el que tenga que reabrir.»

## Inventario (medido en el código el 2026-10-21, árbol `4593908e1`)

Hoy Yala pide reabrir en 9 situaciones. 3 entran en el iCloud privado (las justifica la regla) y 6 son nube, Grupos o
salidas de sesión.

| # | Qué ve la persona | Dónde sale | Por qué hoy reabre | Clase | ¿Sin reabrir? |
|---|---|---|---|---|---|
| 1 | «Un último paso: reabre Yala» | Es mi primera vez › privado; Restaurar / Traer mis datos; Activar Yala completo › privado | Monta el espejo de iCloud sobre un store sin él | Privado | No: encender el espejo con la app abierta no está medido, y montar un segundo contenedor sobre el mismo fichero deja la app vacía (`WelcomeMirrorRelaunchLogic`) |
| 2 | «iCloud ya disponible · ciérrala y vuelve a abrirla» | Yala arrancó sin iCloud y luego se entró en iCloud | Igual que el 1 | Privado | No |
| 3 | «Ya casi está · Al abrirla otra vez, empiezan a subir a tu iCloud» | Ajustes › Volver a iCloud | Monta el espejo | Privado | No |
| 4 | «Ya casi está · Tus datos ya están en tu cuenta de la nube» | Final de «Activar la nube» y de «Activar la nube en este dispositivo» | Apaga el espejo | Nube | Bloqueado (ver abajo) |
| 5 | «Tus datos siguen en la nube · La vuelta a iCloud se detuvo» | «Cancelar y seguir en la nube» tras montar el espejo, o el techo de la espera | Apaga el espejo | Nube | Bloqueado |
| 6 | «Un último paso: reabre Yala · Ciérrala del todo y vuelve a abrirla» | Ya tengo una cuenta › nube, o Es mi primera vez › Tu cuenta en la nube, **solo si el proceso arrancó con el espejo montado** (en una instalación nueva no sale) | Apaga el espejo | Nube | Bloqueado |
| 7 | «Abre Yala otra vez para unirte» | Vengo por un grupo › Tengo una invitación, con cuenta en la nube y finanzas propias, recién pasadas a la nube con el espejo aún montado | Es el relanzamiento pendiente del 4 | Grupos | Bloqueado |
| 8 | «Ya casi está · Sesión cerrada» (y «Yala se reiniciará y seguirás con tu invitación») | Vengo por un grupo › Crear / Tengo una invitación con el espejo montado | Cierra la sesión privada: borra archivos al arrancar | Grupos | Con sesión privada, bloqueado por el espejo. **Con sesión solo-grupos ya se podría** (ver «Barato») |
| 9 | La misma pantalla del 8 | Cerrar sesión en la nube (ya va en caliente; la pantalla solo sale si el cambio falla), borrar la cuenta en la nube o solo-grupos, cerrar la sesión privada | Salida de sesión | Salidas | Nube: ya en caliente. **Borrar cuenta (nube y solo-grupos): se podría** |

**El mecanismo que ya existe:** `PersonalContainerSwap` cambia el contenedor sin relanzar, y hoy solo lo usa el cierre
de sesión en la nube. Se niega cuando el montaje lleva el espejo (`PersonalSwapReleaseLogic.mountAdmitsSwap`), porque
medido: el espejo emitió 5 eventos en los 10 s después de soltarlo. Por eso los 4, 5, 6 y 7 están bloqueados por lo
mismo: apagar el espejo con la app abierta.

**Ya resuelto antes de este inventario:** «Tengo una invitación» en una instalación limpia dejó de pedir el espejo el
2026-10-20 (`WelcomeMirrorRelaunchLogic`).

## Propuesta (espera la decisión de Jürgen)

1. **Barato, sin riesgo nuevo** — los tres caminos cuyo montaje ya va sin espejo pasan por el cambio en caliente que ya
   usa el cierre de sesión en la nube: la celda solo-grupos del 8 y los dos «Borrar mi cuenta» del 9
   (`attemptSignOutSwap()` tras el arm, como `CloudSessionSignOut.swift:1768`). Recomendado.
2. **Los de apagar el espejo (4, 5, 6, 7)** — antes de tocar nada, una medición en un iPhone real: soltar el contenedor
   con espejo justo después de exportar el marcador y montar el mismo fichero sin espejo, mirando si CloudKit escribe
   algo después. Si no escribe, se amplía `PersonalContainerSwap` a esa salida. Si escribe, se quedan como excepción
   aprobada.
3. **Los privados (1, 2, 3)** se quedan: son los que la regla justifica.

## Hecha cuando

Solo entrar en el iCloud privado pide reabrir; o cada excepción de las 4-7 tiene la aprobación de Jürgen.
