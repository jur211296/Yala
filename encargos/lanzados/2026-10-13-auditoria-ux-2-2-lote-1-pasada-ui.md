# Auditoría UX 2.2 · lote 1: pasada UI y decisiones

> **ALCANCE ESTRICTO:** esta sesión trabaja SOLO en los flujos de su lote. Los criterios UX/UI permanentes (calculadoras, ayuda, foco, kargul, etc.) se aplican solo a las pantallas del lote. Si ves algo fuera del lote, anótalo en una línea en el informe y no lo revises ni lo toques.


Card: «Auditoría UX 2.2 · lote 1: pasada UI y decisiones» (Yala, 2.2, high). Card madre ogl6: no la muevas.
Base y PR: **origin/2.2** (fetch + rebase antes del PR). Brief madre: ~/Claude/tmp-frank/auditoria-ux-flujos-2-2.md (formato de informe, HTML acumulado y «Criterios UX/UI permanentes de Jürgen»). Mapa: docs/ux/mapa-de-flujos-2.2.md. Lote 1 original: PR #482, ~/Claude/entregas/Yala--auditoria-ux-2-2-lote-1-primera-vez/informe.md. Referencias UI: lee primero ~/Claude/referencias-ui/README.md.

## Parte 1 · Implementar las 13 decisiones de Jürgen (cards UX 2.2 · L1-n, ya en lista para lanzar)
- L1-1, L1-2, L1-3, L1-5, L1-6, L1-8, L1-10, L1-11, L1-13: opción B tal como la describe cada card / informe.md.
- L1-4: opción A. Era decisión de diseño: Yala empuja el modo nube. Se mantiene el alta privada con su reinicio, pero añade una línea que explique que el reinicio sirve para mantener sus datos siempre privados.
- L1-7: opción B. El saldo estaba a propósito para que no se salten el paso con prisa; con B el usuario debe seguir entendiendo cómo está rellenando su saldo.
- L1-9: parcial. Fusiona «cómo te organizas» con «primera cuenta», pero NO fusiones el paso del saldo: el usuario tiene que entender cómo se rellena.
- L1-12: opción B, y además muestra la oferta Pro al terminar «Primeros pasos».
Copy en los 16 idiomas, tests con -only-testing y /gate, capturas antes/después de cada una. Mueve cada card L1-n a in qa (o done si no necesita QA en dispositivo) con nota del PR.

## Parte 2 · Auditoría UI y propuestas (onboarding / primera vez)
a) Todas las calculadoras completamente claras para cualquier tipo de usuario (las cinco lentes).
b) Que el usuario entienda qué está haciendo en cada paso: ayuda contextual, microcopy, ejemplos.
c) El glass se queda, pero todo en glass no da foco: las opciones preseleccionadas van rellenas de color (no solo contorno) y se jerarquiza con contraste, efectos y movimiento.
d) «Calculemos tu saldo juntos»: resaltarlo con relleno/contraste (rosa), manteniendo el glass, y copy tipo «Toca aquí y te ayudamos a calcular tu saldo». Feedback de usuarios: se atascan en el saldo y no lo ven.
e) Auditoría de colores, efectos, transiciones y animaciones para que el onboarding no sea aburrido.
Para cada propuesta: capturas antes + mock/boceto después, opciones A/B/C y recomendación, y una card en espera decisión (Yala, 2.2, assignee jurgen) numerada L1UI-1, L1UI-2… Lo que sea bug claro se arregla con su propia card.


### Ajuste de Jürgen (2026-10-13 07:50 Lima; manda sobre a–e)
1. Calculadoras: la claridad absoluta es puntual para el onboarding y para crear/editar cuentas (mismo criterio en ambos).
2. Regla de fondo: el usuario SIEMPRE se siente instruido, SIN obligarlo a pasos adicionales, y NUNCA se siente perdido (si no entiende qué pasa, deja la app).
3. El liquid glass se queda. El problema es que todo con glass no da foco a nada: suma contraste, rellenos, efectos, animaciones y transiciones para jerarquizar.
4. Referencia principal: ~/Claude/referencias-ui/kargul-2026-10-07/ (la que más le gusta a Jürgen).
5. No transformar la app: adaptarla.
6. SOLO HOY 2026-10-13: Lola no usa el simulador de 9 a 11 Lima, así que se puede usar en esa franja (siempre 1 a la vez y apagado al terminar). Cualquier otro día vuelve la regla de no usarlo de 9 a 11.

## Entregables
- Capturas en ~/Claude/entregas/<sesión>/capturas/ y mocks; informe.md en español.
- HTML acumulado ~/Claude/propuestas/auditoria-ux-2.2/auditoria-ux-2.2.html: añade la sección «Lote 1 · pasada UI» sin borrar nada (índice arriba, móvil).
- PR contra 2.2 con la implementación de la Parte 1 (y bugs claros).

## Reglas
Totalmente autónomo: Jürgen duerme o está ocupado; nunca AskUserQuestion ni preguntas, decide tú. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. NINGÚN simulador de 9:00 a 11:00 Lima (en esa franja apágalo y sigue con código/informe). Sin deploy. Cierra con /cerrar-total.


## Reglas de lanzamiento (2026-10-13 10:45 Lima)
Base y PR: 2.2. ALCANCE ESTRICTO: solo los flujos del lote 1. Totalmente autónomo, sin preguntas ni AskUserQuestion. Como máximo 1 simulador; `xcrun simctl shutdown all` al terminar. Hoy el simulador se puede usar ya. Cierra con /cerrar-total.

## Paso 0 (Frank, 2026-10-13 11:00 Lima; autónomo, auto-contestado)

Ficheros que se tocan (nota, no pregunta): `ContentView.swift` (splash L1-1, momento de la oferta L1-12),
`OnboardingStepPlan.swift` + `OnboardingNextEnablement.swift` + `OnboardingView.swift` (L1-5…L1-11),
`WelcomeMirrorRelaunchView.swift` (L1-4), `WelcomePrivateICloudGateView.swift` (L1-3), `SetupChecklistManager.swift`
y las pantallas de éxito de registro (L1-12), `L10n.swift`, los 16 `Localizable.strings`, y sus tests.

Decisiones tomadas:
1. **L1-1 «primer arranque»** = onboarding sin completar. Con el onboarding hecho, el splash dura lo que tarde la app
   en estar lista (sin mínimo). Sin clave nueva en `UserDefaults`: no hay nada que borrar ni migrar.
2. **L1-3**: título nuevo solo en la salida que sigue (`proceedWatchingTheMirror`); la que vuelve atrás conserva el suyo.
3. **L1-4**: una línea nueva bajo el cuerpo, con la promesa ya aprobada en «Tu cuenta en tu iCloud privado»
   («nadie más puede leerlos, ni siquiera nosotros»). No se toca el reinicio.
4. **L1-7 (B)**: el saldo sigue obligatorio. Subtítulo «Un aproximado está bien. ¿No lo sabes? Escribe 0 y
   ajústalo después.» e icono de cálculo en «Calculemos tu saldo juntos». El contrato `balance_emptyText_isDisabled` se
   queda.
5. **L1-9 (parcial)**: se retira el paso `.accounts`; `.accountType` pasa a ser «¿Dónde está tu dinero?» con «Todo junto
   en una sola cuenta» + los cuatro tipos. «Todo junto» = el `.dayToDay` de antes (cuenta general, mentalidad
   patrimonial); un tipo = `.fullControl` (mentalidad cashFlow). Nada preseleccionado al entrar (igual que el paso 4 de
   hoy): «Siguiente» exige elegir. Llevar el control queda en 7 pasos; el saldo no se fusiona.
6. **L1-11**: título y subtítulo propios del paso de divisa solo en «solo gastos»; «una sola cuenta» conserva los suyos.
7. **L1-12 (B + Primeros pasos)**: el one-shot `needsPostOnboardingTrial` se sigue armando al terminar el alta, pero ya
   no se presenta al cerrar el onboarding: se pide al guardar un registro (pantallas de éxito de registro y de bandeja),
   y el router lo retiene hasta que la hoja se cierre. Al completar «Primeros pasos» se vuelve a armar y a pedir (si no
   es Pro). El reintento al arrancar se conserva, pero solo si ya hubo un primer registro.
8. **Parte 2**: propuestas L1UI-n con captura del antes y maqueta del después renderizada en el simulador con un
   parche temporal que no se commitea; card en «espera decisión» por cada una. Solo se arregla lo que sea bug claro.
