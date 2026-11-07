# Revisión por vistas 2.3 · Índice final de cobertura: completar el README con las 11 zonas
card: tablero-revision-por-vistas-2-3-indice-de-cobert-f8pd
toca: docs/ux/revision-vistas-2.3/README.md (actualizar el índice parcial que ya existe)
esfuerzo: medium

Rama base: origin/2.3 en jur211296/Yala. Un solo PR de documentación a 2.3 y un solo cierre: termina con `/cerrar-total`. Cierre autónomo (cierra-sola). Commits y PR sin firma de IA. NO cambies código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales ni merge de funcionalidad. Sin publicación pública, hosting nuevo ni compras. Da siempre una descripción corta en español a cada comando Bash. Jürgen duerme: no esperes respuesta; dudas no vitales anótalas con alternativas para mañana en el cierre; nada de seguridad o producto crítico sin él. Justo antes del PR: `git fetch` y un solo rebase sobre origin/2.3.

Simuladores: puedes y debes usarlos para capturas actuales con datos ficticios. En la Mini, tope 1; en la Max, tope 2 (puedes abrir un segundo aunque otra sesión de otro proyecto use uno) o el iPhone 14 por DeviceMCP. Build `xcodebuild -jobs 2` sin sim encendido, luego bootear, capturar, apagar y borrar solo lo que encendiste (simuladores, DerivedData propio, temporales). No toques recursos de otras sesiones.

## Qué se pide
Va al final de la serie. Ya existe en origin/2.3 un README índice parcial (hecho el 2026-11-07 con solo Panel, Registros y Nuevo registro, y las demás zonas marcadas como pendientes). Antes de empezar, comprueba en origin/2.3 que ya están mergeadas las fichas de Planificación, Estadísticas, Reportes, Grupos, Bandeja/IA, Cuentas, Perfil y Nube; si falta alguna, pregúntale al bot con `preguntar-bot` (opciones: esperar, cerrar el índice marcándola pendiente con motivo). Actualiza ese README en vez de crear uno nuevo. Lee las `ficha.md` de `docs/ux/revision-vistas-2.3/*/` ya mergeadas en origin/2.3 y el mapa `/Users/jur/Claude/flota/cobertura-vistas-yala-2.3.md`. Escribe un README índice: por zona, vistas cubiertas, enlace a su HTML/PDF, problemas principales y decisiones pendientes para Jürgen, y las zonas que quedaron sin revisar (con motivo). No inventes conclusiones que no estén en las fichas. Sin maquetas nuevas. Card a in qa y `/cerrar-total`.
FIN
