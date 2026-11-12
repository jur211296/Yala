---
id: cloud-session-removed-by-the-sdk-does-not-announce-itself
status: backlog
priority: low
area: "modo-nube, grupos, ajustes"
created: 2026-10-28
updated: 2026-10-28
source: "card n533 (`views-reading-the-cloud-session-do-not-repaint-when-it-changes`), hueco que dejó la review de nve0"
---

# La sesión que el SDK borra solo no avisa, y las pantallas siguen pintando como si estuviera

## Qué pasa

Cuando un refresco del token falla de forma terminal, el SDK de Supabase borra la sesión guardada por su cuenta.
`CloudAuthService.hasSession` pasa a `false`, pero `sessionEpoch` no se mueve y no sale
`sessionDidChangeNotification`, así que tampoco sube `CloudSessionRevision`. Las pantallas que pintan con la sesión
(la pestaña de Grupos, Ajustes y «Tu cuenta de Yala», el aviso del attest del Panel) siguen con el estado de antes
hasta que otra cosa las repinte: por ejemplo, Ajustes sigue ofreciendo «Tu cuenta de Yala» con la sesión ya caducada.

Lo dejan escrito los docblocks de `sessionDidChangeNotification` y de `CloudSessionRevision`.

## Qué hacer

Medir antes cómo llega ese borrado: el SDK expone `authStateChanges` (evento `signedOut` / `tokenRefreshed`), que
puede ser el sitio para emitir el aviso. Hay que comprobar que ese evento no sale también en los cierres de sesión
propios (que ya avisan dos veces) y que no se dispara al arrancar. Solo para repintar: no es sitio para sellar nada.

## Hecha cuando

Con la sesión borrada por el SDK, las pantallas que leen la sesión se repintan sin un gesto, o consta por qué no
se puede.
