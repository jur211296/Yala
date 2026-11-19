Yala
# Resumen con IA de Estadísticas: mostrar a qué hora se escribió y un botón «Actualizar»
---
toca: Yala/App/Logic/StatsAIAutoRefreshLogic.swift,Yala/App/ViewModels/InsightsViewModel.swift,Yala/App/Views/Statistics/InsightsTabView.swift,Yala/Utils/L10n+ResumenIAHora.swift,YalaTests/ResumenIAHora/,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,tickets/backlog/stats-ai-summary-shows-figures-from-before-the-latest-records.md,tickets/done/2026-11-17-resumen-ia-hora-y-actualizar.md,Yala.xcodeproj/project.pbxproj
esfuerzo: medium
cierre: cierra-sola
---

## Qué hay que hacer
Ticket: `tickets/backlog/stats-ai-summary-shows-figures-from-before-the-latest-records.md` (en `origin/2.3`). Jürgen aprobó el 17-nov la opción **B** recomendada: se mantiene el umbral actual de regeneración automática (no cambia el coste), pero cuando el texto de IA de Estadísticas › Resumen se escribió con datos que ya no son los actuales, se marca así: «Escrito con tus datos de las HH:MM · Actualizar».

- «Actualizar» regenera el texto en ese momento con los datos actuales (respeta el techo y las reglas de `.claude/rules/ai-gateway.md`; si ya se llegó al techo, mensaje claro, sin fallar en silencio).
- La marca solo aparece cuando los datos cambiaron desde que se escribió el texto (registros o totales distintos), no siempre. Con datos iguales, no se muestra.
- La hora va en el formato de hora local del usuario. Textos en los 16 idiomas.
- Tests unitarios en `YalaTests/ResumenIAHora/` que cubran: datos iguales sin marca, un gasto nuevo bajo el umbral con marca, Actualizar regenera y quita la marca, techo diario alcanzado.
- Revisar en el simulador en modo claro, modo oscuro y con el iPhone girado. Evidencia antes/después.
- Mover el ticket a `tickets/done/2026-11-17-resumen-ia-hora-y-actualizar.md`.

## Reglas
- Commits y PR sin firma de IA. PR hacia `2.3`.
- Simuladores: en la Max puedes usar un segundo simulador si la otra sesión ocupa uno (tope 2); también puedes usar el iPhone 14 conectado por DeviceMCP.
- Lo menor y reversible lo decides tú y lo anotas. Lo vital (acceso, credenciales, seguridad, coste de IA fuera de lo aprobado) se pregunta, no se asume.
- Modo de sesión: el que quede fijado al arrancar. Si el trabajo queda completo y el modo lo permite, termina con `/cerrar-total`. En nocturno, una decisión vital pendiente se deja en checkpoint sin mergear ni desplegar.
- Entregable: artifact visual de Claude con antes/después.
- El cierre incluye las secciones «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada una con motivo o «Nada».

## Paso 0 (decidido por Frank, 2026-11-17)

- **Cuándo sale la marca:** cuando las cifras con que se escribió el texto que se ve (registros, gasto e ingreso del
  período: el `Snapshot` de `StatsAIAutoRefreshLogic`) no son las de ahora. Con las mismas cifras, nunca.
- **Qué hora enseña:** la de cuando se guardó ese texto en su ranura (`savedAt`), no la de cuando se abrió la pantalla.
- **«Actualizar» y el techo:** cuenta para el mismo techo diario de 4 por página que lo automático. Así la opción B
  sigue sin cambiar el coste. Con el techo gastado no llama y lo dice; un fallo deja el texto viejo con su marca y el
  motivo debajo.
- **Formato de la hora:** 12 o 24 horas según el ajuste del iPhone; «p. m.», «PM», «午後» en el idioma de la app.
- **Dónde:** debajo de la tarjeta del resumen en Resumen. Distribución enseña el mismo texto y queda fuera (su vista no
  está en el `toca:`).
