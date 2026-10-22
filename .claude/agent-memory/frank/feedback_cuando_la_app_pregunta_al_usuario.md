---
name: cuando-la-app-pregunta-al-usuario
description: Jürgen quiere que la app PREGUNTE al usuario cuando la decisión mueve o destruye sus datos, y que NO pregunte cuando solo cambia la navegación; no es un gusto general por preguntar
metadata:
  type: feedback
---

**El corte está en si la decisión toca los DATOS del usuario, no en si es importante.**

Medido el 2026-09-09 en la pasada de desbloqueo del rediseño de sesiones, sobre trece tickets:

| Decisión | Qué eligió |
|---|---|
| Traer el historial de grupos al Panel al activar Yala completo | **preguntar al usuario** |
| Qué hacer con las filas puenteadas al desasociar la cuenta de grupos | **preguntar al usuario** |
| Entrar por «Vengo por un grupo» con una cuenta que resulta completa | **adoptar en silencio** |
| Volver al neutro borrando lo local cuando otra rama había montado el espejo | **avisar, sin confirmar** |
| Desasociar con deudas pendientes en un grupo | **ni aviso ni bloqueo** |

**Why:** las dos primeras mueven datos que ya existen y cuya pérdida o duplicación el usuario no puede
deshacer. Las tres últimas cambian dónde aterriza o qué se ve, y ahí un paso extra solo estorba — dos de
ellas están en la puerta de captación de usuarios nuevos, que es donde menos quiere fricción.

**How to apply:** antes de proponer un alert, pregúntate si lo que está en juego son datos del usuario o
solo el recorrido. Si son datos: ofrécele elegir, y asume que eso son **dos comportamientos que hay que
implementar y probar**, no una rama y un default. Si es recorrido: informa o calla, pero no le pidas
permiso. Y cuando el aviso sea inevitable pero no deba frenar, existe el término medio que él usa:
**avisar sin confirmar**. Relacionado: [[prefiere-lo-limpio-a-lo-defensivo]] — no confundir «que el
usuario elija» con «apuntalar por si acaso»; lo segundo lo descarta.
