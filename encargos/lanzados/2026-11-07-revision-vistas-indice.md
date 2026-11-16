# Revisión por vistas 2.3 · Índice de cobertura y resumen de decisiones pendientes
card: tablero-revision-por-vistas-2-3-indice-de-cobert-f8pd
toca: docs/ux/revision-vistas-2.3/README.md (solo este archivo nuevo)
esfuerzo: medium

Rama base: origin/2.3 en jur211296/Yala. Un solo PR de documentación a 2.3 y un solo cierre: termina con `/cerrar-total`. Cierre autónomo (cierra-sola). Commits y PR sin firma de IA. NO cambies código de la app, tests, gateway, auth, producción, marketing/, colas ni sesiones: es revisión y prototipo de UX, sin cambios funcionales ni merge de funcionalidad. Sin publicación pública, hosting nuevo ni compras. Da siempre una descripción corta en español a cada comando Bash. Jürgen duerme: no esperes respuesta; dudas no vitales anótalas con alternativas para mañana en el cierre; nada de seguridad o producto crítico sin él. Justo antes del PR: `git fetch` y un solo rebase sobre origin/2.3.

Simuladores: puedes y debes usarlos para capturas actuales con datos ficticios. En la Mini, tope 1; en la Max, tope 2 (puedes abrir un segundo aunque otra sesión de otro proyecto use uno) o el iPhone 14 por DeviceMCP. Build `xcodebuild -jobs 2` sin sim encendido, luego bootear, capturar, apagar y borrar solo lo que encendiste (simuladores, DerivedData propio, temporales). No toques recursos de otras sesiones.

## Qué se pide
Va al final de la serie. Lee las `ficha.md` de `docs/ux/revision-vistas-2.3/*/` ya mergeadas en origin/2.3 y el mapa `/Users/jur/Claude/flota/cobertura-vistas-yala-2.3.md`. Escribe un README índice: por zona, vistas cubiertas, enlace a su HTML/PDF, problemas principales y decisiones pendientes para Jürgen, y las zonas que quedaron sin revisar (con motivo). No inventes conclusiones que no estén en las fichas. Sin maquetas nuevas. Card a in qa y `/cerrar-total`.
FIN

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

**D1 · ¿Qué hacer con las 8 zonas sin ficha (34-41)?** → Se listan en «Zonas sin revisar» con sus vistas del mapa y el motivo medido: 34 en curso, 35-41 en cola sin lanzar. Respondió el bot dueño: opción A. Se entrega hoy con las 3 zonas mergeadas; 34 «en curso en la Mini» y 35-41 «pendiente, en cola, aún no corrió». No se reencola nada desde aquí: el bot ya dejó al final de la cola un «índice final» que completa este README. Card a in qa con nota de índice parcial.
Por qué: el encargo pide «zonas sin revisar con motivo», y el motivo real es que el índice salió antes que ellas. Alternativa descartada: esperar a que terminen (horas; la cola es secuencial).

**D2 · ¿Contenido de cada zona?** → Problemas y decisiones copiados de cada `ficha.md`, sin reinterpretar; enlaces relativos al `index.html` y al PDF de la zona.
Por qué: «no inventes conclusiones». Alternativa descartada: sección de patrones entre zonas (sería conclusión propia).

**D3 · ¿Dónde vive el mapa?** → Se cita su ruta de la Mini; no se copia al repo.
Por qué: el mapa dice que nadie lo edita y el encargo toca solo el README.
