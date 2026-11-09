# Revisión por vistas 2.3 · Perfil, Más, Ajustes generales, Pro y ayuda (zona 40)

Revisión de UX y eficiencia de la hoja de Ajustes entera (jerarquía y nombres), la pestaña Más, Pro y la ayuda, con el caso de
Andrea: cinco ajustes de los que se cambian una vez (modo oscuro, quitar decimales, recordatorio a las 21:00, la app en inglés y
cuándo se renueva Pro), entender qué le da Pro antes de pagar, mandar a su contador los gastos de octubre en Excel y escribir a
soporte. No implementa nada y no elige: cada problema prioritario (siete) trae de tres a cuatro alternativas maquetadas y una
recomendación. Decide Jürgen.

- **Abrir:** `index.html` (se abre en el móvil y en la Mac; capturas y estilo van al lado, en `capturas/` y `estilo.css`).
- **Respaldo:** `revision-perfil-ajustes.pdf` (68 páginas, ~7,4 MB).
- **Regenerar:** `cd fuente && python3 capturas.py <carpeta de PNG> && python3 build.py` (con `--todo <ruta>` deja la página única para imprimir el PDF).

## Vistas cubiertas

ProfileView, PersonalDetailsView, YalaAccountView, MoreView, PersonalizationSettingsView, ThemeSettingsView, AppIconSettingsView,
TabBarConfigView, NotificationsSettingsView, PermissionsSettingsView, SmartInsightsSettingsView, AIPrivacySettingsView,
BudgetsFavoritesSettingsView, UsageModeSettingsView, FaceIDProtectionGuideView, SubscriptionView + SubscriptionSuccessView, FAQView,
TutorialsListView + TutorialDetailView + TutorialCompletionView, ExportRecordsView, GroupsExportView y UserDataResetView. Capturas del
simulador (iPhone 17 Pro e iPad Pro 13, iOS 27.2) con las semillas de prueba de la app, sin cambios: gratis, Pro anual, Pro en prueba,
sin precios, comprado, con cuenta de Yala, Solo grupos, sin registros, texto grande (AX3) e iPad. El conductor de capturas es
`fuente/Revision40CapturasUITests.swift.txt` y no va en la app.

Sin capturar, documentado desde el código: Notificaciones con el permiso denegado (el seam de la app no cubre esa pantalla), la hoja
de exportar de Solo grupos (GroupsExportView) y «Escríbenos» sin una cuenta en Mail (el simulador no tiene Mail).

## Problemas, por severidad

| | Problema | Recomendada |
|---|---|---|
| 1 · alta | Ajustes son 31 filas en siete bloques y cuatro pantallas, sin buscador; decimales, idioma y formato viven dentro de «Personalización». Solo uno de los cinco ajustes del caso (la renovación de Pro, que se lee en la fila) se hace en menos de tres toques | A2: reordenar por intención (Tu plan, Apariencia e idioma, Tu día a día…) con el valor a la vista; A1 (buscador) después |
| 2 · alta | «Presupuestos» de Ajustes no abre tus presupuestos (elige los del Panel), «Pagos planificados» cierra Ajustes y salta de pestaña, y «Favoritos» se cruza con los presupuestos favoritos | B1: cada fila con el nombre de lo que abre; lo del Panel, a Configurar Panel |
| 3 · alta | Yala Pro enseña primero el precio; «Qué incluye» está dos pantallas abajo y el límite gratis (4 cuentas, 3 presupuestos) solo se le dice a quien ya paga | C1: tabla «Gratis o Pro» antes de los precios (+ C4, tu plan en una tarjeta arriba) |
| 4 · media-alta | Exportar abre en «Todo» (2.342 registros), sin «Mes pasado» y sin filtro de gastos o ingresos; sin registros, la fila sale gris sin decir por qué | D1: «Mes pasado» y «Qué registros» a la vista (+ D4, el motivo de la fila apagada) |
| 5 · media | La ayuda vive al fondo (cuarta pantalla), las 15 preguntas no se buscan ni llevan al sitio, y «Escríbenos» depende de la app Mail | E1: una sola «Ayuda» arriba con buscador y «Escríbenos» fijo (+ E2, «Ir a…» en las respuestas) |
| 6 · media | «Cómo usas Yala» (Completo / Solo grupos) y «Modo de uso» (Solo gastos) son dos cosas casi homónimas en dos sitios | F1: «Solo gastos» se muda a «Cómo usas Yala» como interruptor |
| 7 · media | Con texto grande (AX3), los títulos de Ajustes se parten por sílabas, los iconos no crecen y la lista pasa de 4 a 8 pantallas | G1: sin icono con texto de accesibilidad (+ G3, títulos de una palabra) |

Eficiencia, medido (Debug, simulador, marca `PERF ajustes` de la app, mediana de 7 aperturas): abrir Ajustes desde el Panel tarda
**130 ms** sin registros, **345 ms** con dos años y **~1.020 ms** con diez (la primera, 1.950 ms). Abierto desde Más cuesta la mitad (216 ms y ~470 ms), pero también crece con los registros. Ajustes solo cuenta los registros
(`fetchCount`): una parte del coste es del Panel al presentar la hoja y otra de algo común (la hoja o las páginas montadas debajo); sin aislar.
Hipótesis con cómo medirlas en la página «Perfiles y eficiencia».

## Lo que ya estaba decidido

La auditoría UX 2.2 decidió en esta zona el nombre «Ajustes» del avatar (L16-1), «Quitar mis datos de este dispositivo» sola al final
(L20-6), Vaciar datos con su frase y «Exportar una copia antes» (L20-D), la fila de Pro con su estado (L17-1), «Hacerlo ahora» en los
tutoriales (L15) y el molde de lista de iOS en Ajustes (`YalaSettingsList`). Ninguna alternativa recomendada reabre nada; E4 (recortar
tutoriales) sí reabre L15 y por eso no es la recomendada.

## Decisiones para Jürgen

1. Problema 1: ¿se reordena Ajustes por intención (A2)? ¿Tema, Idioma y Formato de cantidades salen de Personalización a su fila? ¿Buscador (A1) ahora o después?
2. Problema 2: ¿«Presupuestos en el Panel» pasa a Configurar Panel y «Pagos planificados» sale de Ajustes (B1)? ¿«Favoritos» pasa a «Registros favoritos»?
3. Problema 3: ¿tabla «Gratis o Pro» antes de los precios (C1)? ¿Tu plan en una tarjeta arriba de Ajustes (C4)? ¿«Cancela en los Ajustes del iPhone»?
4. Problema 4: ¿«Mes pasado» y «Qué registros» en Exportar (D1)? ¿Las transferencias cuentan en «Solo gastos»? ¿El motivo de la fila apagada, a la vista (D4)?
5. Problema 5: ¿una «Ayuda» arriba con buscador (E1)? ¿«Ir a…» en las respuestas (E2)? Probar antes «Escríbenos» en el iPhone 14 sin cuenta de Mail (E3).
6. Problema 6: ¿«Solo gastos» como interruptor dentro de «Cómo usas Yala» (F1) o como tercera opción (F2)?
7. Problema 7: ¿filas sin icono con texto de accesibilidad (G1)? ¿Títulos de una palabra (G3)?
8. Eficiencia: ¿se suma esta medida a la card de Sentry «La app se traba en Perfil (App Hang)», que ya está en «lista para lanzar», o se abre otra para medir con Instruments?
