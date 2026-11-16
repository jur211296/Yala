---
esfuerzo: medium
toca: docs/onboarding-2-3/
release: no
---

# Revisar con Jürgen el artifact de la bienvenida 2.3 y sumar crear cuenta, nuevo registro y presupuesto

## Contexto
Esta sesión es INTERACTIVA y NO SE CIERRA SOLA: Jürgen la sigue desde la misma sesión de Claude, revisa el artifact ahí y contesta ahí tus preguntas. Modo manual: no hay `/cerrar-total` ni cierre final sin su GO explícito.

Es la continuación de la sesión del sábado 7-nov-2026 (`Yala--onboarding-artifact-tres-direcciones`, en la Max). Lo que dejó:
- Artifact nativo de Claude, privado: https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6 — la versión 10 es la elegida; las versiones 1 a 9 guardan las cinco rondas previas.
- Fuente e instrucciones para seguir montando sobre el MISMO artifact, en la Max: `/Users/max-jur/Claude/entregas/onboarding-yala-20261107/prototipo/README.md` (léelo entero primero), con `fuente-actual/`, `ev/` y `build-actual.py`.
- Investigación (incluye referencias de X): `/Users/max-jur/Claude/entregas/onboarding-yala-20261107/investigacion.md`.
- Evidencia en iPhone 14 por ronda: `/Users/max-jur/Claude/entregas/onboarding-yala-20261107/evidencia/` (`r4-iphone14-recorrido.mp4` es el más reciente).
- El encargo del sábado con su «Paso 0 — decisiones»: `encargos/lanzados/2026-11-07-onboarding-artifact-tres-direcciones.md` (PR #861, mergeado en 2.2).
- Memorias de Frank del repo: `reference_probar_un_artifact_en_el_iphone_14.md` y `feedback_maquetas_con_piezas_reales_de_la_app.md` en `.claude/agent-memory/frank/`.

Decidido por Jürgen el 7-nov (no lo reabras): vitrina que rota con seis funciones (foto y voz con rótulo PRO) y grupos dentro de la vitrina (G3); «Entrar con Google», «Entrar con Apple» y la tarjeta «Entrar con mi iCloud privado»; fondo F2 solo oscuro; Yala verifica el correo y dice «Vamos a crear tu cuenta» o «¿Cargamos tus datos y entramos?»; conversación de tres preguntas (nombre, moneda, qué llevar) con la tarjeta «Tu Yala»; llegada tranquila con «Crea tu primera cuenta»; primera cuenta C2 con los campos del formulario real y la calculadora de saldo; grupos: crear grupo / tengo un enlace / solo crear mi cuenta. Quedó pendiente: ajustes de detalle en los pasos de crear la cuenta (C2), que Jürgen dirá.

Pedido de Jürgen del 9-nov-2026: revisar el artifact que salió de esa sesión y decidir con él más detalles de procesos para que el artifact quede más completo: cómo crear cuenta (mejorar), cómo hacer un nuevo registro, cómo crear un presupuesto, etc.

## Qué se pide
1. Lee el artifact actual (`Artifact action:read url:https://claude.ai/artifact/AcwrfYm96uy8k6Ga2EXnU6`) y el README. Muéstrale a Jürgen, en esta sesión, un repaso corto de lo que hay y pregúntale qué ajustar en crear la cuenta (C2).
2. Con él, define y maqueta en el MISMO artifact los procesos nuevos, uno por vez y en el orden que él diga: crear cuenta (mejorado), nuevo registro, crear presupuesto, y los que él agregue. Para cada uno, propone 2-3 variantes comparables con el mismo caso y datos ficticios, con recomendación, y pregúntale cuál sigue.
3. Publica siempre con el `url:` de ese artifact (sin `url` se crea otro). Nada de HTML suelto ni PDF como entregable: el entregable es el artifact nativo de Claude.
4. Solo UI: diseño desde los colores de marca, divertido, simple y moderno, sin abrumar. Animaciones, sonidos, gestos y variantes donde sumen. Sin mascota todavía, pero con el espacio listo para sumarla luego.
5. Antes de diseñar, mira `~/Claude/referencias-ui/README.md` y usa lo que aplique como inspiración (no copies marcas ni pantallas). Usa piezas reales de la app (formulario real, calculadora real) como en el sábado.
6. Prueba cada ronda en el iPhone 14 conectado por DeviceMCP (permitido) o en simulador; en la Max puedes usar un segundo simulador (tope 2) aunque otra sesión use uno; en la Mini, máximo 1. Apaga y borra solo los simuladores que encendiste.
7. Todas las dudas, en esta misma sesión de Claude. Cuando una ronda de propuestas esté lista para mirar, dilo con claridad en la sesión para que Jürgen la revise.
8. Al final de cada ronda, actualiza el README del prototipo con lo decidido y lo pendiente, para que otra sesión pueda continuar.
9. Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Qué NO hay que tocar
- Código de la app, tests, gateway, auth, producción, marketing/, colas ni otras sesiones: no se implementa nada.
- Lo ya decidido el 7-nov (arriba), salvo que Jürgen lo reabra.
- No crees otro artifact ni publiques nada fuera del artifact privado.
- Sin bug hunt: los fallos que veas en la app solo se anotan.
- Si al final hay commit de notas, commits y PR sin firma de IA (nada de «Generated with Claude Code», «Co-Authored-By» ni enlaces de sesión).

## Cómo se sabe que está bien
- El mismo artifact tiene una versión nueva con los ajustes de crear cuenta y los procesos que Jürgen eligió (al menos nuevo registro y crear presupuesto), probada en el iPhone 14.
- Las decisiones de Jürgen quedan escritas en el README del prototipo.
- La sesión sigue abierta hasta que Jürgen dé el GO de cierre.
