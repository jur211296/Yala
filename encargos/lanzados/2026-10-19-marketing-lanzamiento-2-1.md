# Material de marketing para el lanzamiento de 2.1 (pedido de Lola, aprobado por Jürgen)

## Contexto
Lola (marketing de Yala) prepara el lanzamiento de 2.1. Reglas para todo el material: nunca «gratis», «ahora gratis» ni «Beta» para Grupos; nada de viajes ni ejemplos de viaje. Usa solo datos de prueba en soles: una persona con sueldo de S/ 1,500, sin datos reales. Base: origin/2.1. Todo se entrega en ~/Claude/propuestas/marketing-lanzamiento/ (créala), con un README.md que liste cada archivo y qué es.

## Qué se pide
1. Grupos en la ficha y el evento:
   - Una captura nueva de Grupos con un nombre de grupo genérico (por ejemplo «Depa compartido» o «Almuerzos de la oficina»), para reemplazar la lámina 06 (hoy dice «Viaje a Cusco») en todos los idiomas de la ficha 2.1. Usa el mismo pipeline, tamaños y marcos de las láminas actuales (busca en ~/Claude/propuestas/assets-asc-2.1-2026-10-13/).
   - La escena de Grupos del video de vista previa, sin «GRUPOS · GRATIS» ni «cuentas claras en el viaje».
   - Las imágenes y los textos del evento in-app (en ~/Claude/propuestas/assets-asc-2.1-2026-10-13/eventos/) sin «gratis» ni «Viaje a Cusco», con un nombre nuevo como «Grupos, sin hacer cuentas». Deja las versiones nuevas en la carpeta de entrega; no borres los originales.
2. Confirmación de producto, leída del código de 2.1 (no de memoria): qué es gratis y qué es Pro en 2.1 y cómo se activa el mes de prueba. Va en confirmacion-gratis-pro.md, con la ruta del código que lo respalda.
3. Grabaciones en el simulador, en vertical, de 15 a 30 s cada una, sin cortes: Yala AI respondiendo «¿cuánto gasté en comida este mes?»; Grupos (crear el grupo, anotar un gasto compartido, ver quién le debe a quién); un registro por voz; un recorrido por el panel, los presupuestos y lo planificado.
4. Plan B para Apple Pay: una captura de la notificación de Yala y del gasto que crea la automatización de Apple Pay, con datos de prueba.

## Qué NO hay que tocar
No cambies código de la app ni abras un PR de código (si hace falta un dato de prueba, usa un seed local en el simulador). No toques marketing/ ni Web/ del repo, ni Cloudkit Schemas, Yala.xcscheme o encargos/pendientes/. No uses los iPhones ni el iPad de Jürgen (sigue el QA guiado). Pipeline serial: limpiar, build con -jobs 2 sin sim, bootear 1 sim, grabar, apagar y borrar el sim. Al lanzar y al cerrar, borra el DerivedData de esta sesión y las cachés de XcodeBuildMCP de worktrees que ya no existen, sin preguntar. Nunca «OpenAI» en textos.

## Cómo se sabe que está bien
Están todos los archivos en ~/Claude/propuestas/marketing-lanzamiento/ con su README, no hay «gratis», «Beta» ni viajes en ninguno, y las grabaciones duran 15–30 s, sin cortes. Luego /cerrar-total.

## Paso 0 (Frank, 2026-10-19 22:40, sin nadie delante: decisiones asumidas)

1. **Nada se commitea al repo.** El seed y los textos se cambian en local en este worktree, solo para el simulador, y se revierten al terminar. Sin PR de código; el cierre es el del worktree.
2. **Grupo nuevo:** «Depa compartido» / «Shared apartment» / «Apê compartilhado», con icono de casa. Gastos: Alquiler (tú, 600), Internet (Ana, 240), Luz y agua (Beto, 180), Limpieza (Beto, 90) y Mercado (Ana, 120). Te deben S/ 190 (mismo reparto de la ficha). Se quitan los gastos en dólares/euros del viaje. Segundo grupo: «Almuerzos de la oficina».
3. **Titular de la lámina 06:** la frase de Lola, con «Depa compartido» en lugar del viaje. Chips: Mercado · Ana pagó y Luz y agua · Beto pagó.
4. **Vídeo:** los tres idiomas de la ficha (es, en, pt-BR) llevan «Gratis» y el viaje en la escena de Grupos; se rehacen los tres. Pill «Grupos» sin «Gratis».
5. **Una sola build Yala Dev (Debug)**, para todo: Yala IA solo contesta en el simulador con Yala Dev, contra staging, con el secreto de desarrollo de `~/Secrets/yala-gateway/`.
6. **Persona de S/ 1,500:** seed local `lanzamiento` = `realista` reescalado a sueldo S/ 1,500 (solo para las grabaciones). La lámina 06 sigue con la persona de la ficha, que solo enseña el grupo.
7. **Grabación de Grupos:** crear un grupo exige cuenta y que otra persona se una por enlace; en el simulador no se puede. Se graba con el grupo sembrado: abrir el grupo, anotar un gasto compartido y ver Balances. Se dice en el README.
8. **Voz:** el simulador no tiene micrófono; se usa el modo de demostración `-uitest-voice-result one`, como en el vídeo de la ficha.
9. **Apple Pay:** el simulador no tiene Wallet. Se corre la acción «Registrar pago de Apple Pay» desde Atajos con datos de prueba; si no se puede, plan C con la notificación simulada y se dice.
10. **Evento:** nombre «Grupos, sin hacer cuentas».
11. **Agregado de Lola (20-oct):** grabaciones a 60 fps en un iPhone de 6,9" con barra limpia, en claro y oscuro; diez capturas estáticas por modo; categorías del mes. Todo en la misma carpeta de entrega.

## Resultado

Entregado en `~/Claude/propuestas/marketing-lanzamiento/` (README dentro). Ningún cambio de la app quedó en el repo: el seed y los textos del molde se cambiaron en local y se revirtieron.
