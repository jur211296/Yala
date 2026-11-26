Yala
# Construir lo elegido: el mes gratis de Pro dentro de «¡Primeros pasos completos!» y el mazo centrado con «Hola, <nombre>» durante el paso 1
---
toca: Yala/App/Views/Panel/SetupChecklistCard.swift,Yala/Utils/L10n+PrimerosPasos23Final.swift,Yala/App/Views/Shared/ProUpgradeBanner.swift,Yala/App/Logic/SetupCompleteTrialOfferLogic.swift,Yala/App/Logic/ProPlanStatusLogic.swift,Yala/App/Views/Panel/PanelView.swift,Yala/App/Models/SetupChecklistManager.swift,Yala/App/Logic/SetupDeckLogic.swift,Yala/App/Services/AppPreferences.swift,Yala/Resources/de.lproj/Localizable.strings,Yala/Resources/en-GB.lproj/Localizable.strings,Yala/Resources/en.lproj/Localizable.strings,Yala/Resources/es-419.lproj/Localizable.strings,Yala/Resources/es-AR.lproj/Localizable.strings,Yala/Resources/es-ES.lproj/Localizable.strings,Yala/Resources/es.lproj/Localizable.strings,Yala/Resources/fr.lproj/Localizable.strings,Yala/Resources/it.lproj/Localizable.strings,Yala/Resources/ja.lproj/Localizable.strings,Yala/Resources/nl.lproj/Localizable.strings,Yala/Resources/pl.lproj/Localizable.strings,Yala/Resources/pt-BR.lproj/Localizable.strings,Yala/Resources/pt-PT.lproj/Localizable.strings,Yala/Resources/pt.lproj/Localizable.strings,Yala/Resources/zh-Hans.lproj/Localizable.strings,YalaTests/OfertaProMazoCentrado,YalaUITests/OfertaProMazoCentrado,tickets/backlog/2026-11-25-oferta-pro-mes-gratis-y-mazo-centrado.md,tickets/done/2026-11-25-oferta-pro-mes-gratis-y-mazo-centrado.md
esfuerzo: medium
cierre: cierra-sola
release: no
pruebas-ui: si
depende: Yala/pulido-textos-primeros-pasos-y-paywall
---

Decisión de Jürgen (25-nov, 19:42 Lima, «C y B») sobre las maquetas https://claude.ai/artifact/GdiXuiPLjfWskDWgq45JMn (PR de docs #1182, carpeta `docs/propuestas/maquetas-oferta-pro-y-mazo-centrado-2026-11-25/` con `index.html`, `NOTA.md` y las capturas claro y oscuro). Construir exactamente lo elegido.

## Contexto
- Cards del tablero de Yala 2.3 que cubre esta sesión (búscalas por título con `tablero listar --proyecto Yala`): «Oferta Pro tras Primeros pasos: anunciar el mes gratis y hacerla más llamativa» y «Primeros pasos centrado en la pantalla mientras se está en el paso 1».
- Va después de los tres lotes de Primeros pasos, porque tocan los mismos archivos; en especial el lote de pulido, que cambia el título «¡Primeros pasos completos!» cuando hay pasos para después. Respeta lo que esos lotes dejaron en 2.3 (paso 1 de cero también en «Solo gastos», guías, título final).
- Medido en 2.3 por la sesión de maquetas: la hoja «Prueba Yala Pro 1 mes gratis» ya sale al terminar el paso 2 y no se repite al completar (`SetupCompleteTrialOfferLogic.offersAtCompletion`). En Yala Dev no sale porque la App Store no da precios (`ProPlanStatusLogic.trialOfferDecision` → retenida). El mazo está solo hasta que se hace el paso 1 (`PrimerosPasosPanelGate.showsBalanceHero`); las acciones rápidas vuelven tras el paso 2 (`SetupChecklistManager.isQuietArrival`).

## Qué se pide
1. **Oferta Pro, opción C:** dentro de la tarjeta «¡Primeros pasos completos!» (`SetupChecklistCard.swift`), un solo bloque con el confeti, «1 mes gratis» y la oferta, como en la maqueta C: «Para seguir: prueba Yala Pro 1 mes gratis», tres beneficios (Anota sin teclear · Yala IA · Sin límites), botón «Empezar mi mes gratis», «Hoy no pagas · te avisamos antes de cobrar» y «Ahora no» / «Cerrar».
   - Solo para quien tiene derecho a la prueba (`isIntroOfferEligible` / la lógica de `ProPlanStatusLogic`). Sin derecho: la tarjeta de «completos» como hoy y la de Pro de hoy debajo.
   - «Empezar mi mes gratis» abre la hoja «Prueba Yala Pro 1 mes gratis» con los planes. «Cerrar» quita la tarjeta entera, como hoy.
   - Los días siguientes, la tarjeta de Pro del Panel (`ProUpgradeBanner.swift`) usa el texto de la maqueta A para quien tiene derecho: «Prueba Yala Pro gratis 1 mes» y botón «Empezar mes gratis»; sin derecho, el texto de hoy.
   - Tiene que caber en el iPhone 14 sin bajar, en claro y oscuro; con texto grande, que se pueda desplazar sin cortar el botón.
2. **Mazo, opción B:** mientras se está en el paso 1 (sin cuenta), el mazo va centrado en la pantalla con un saludo arriba: «Hola, <nombre>» y debajo «Siete pasos cortos para dejar Yala a tu medida.» (`PanelView.swift`, `setupDeckSlot` / llegada tranquila).
   - El nombre es el de la persona (el que Yala sabe por Apple o Google; búscalo donde ya se guarda, por ejemplo lo que usa la bienvenida), **nunca fijo**. Si Yala no sabe el nombre, solo «Hola».
   - Al crear la cuenta, el saludo se va y el mazo vuelve arriba con una transición suave, como en la maqueta («Ver la transición»).
   - Vale para «Solo gastos» y para «Ingresos y gastos».
3. Textos nuevos en los 16 idiomas de `Localizable.strings`, español neutro latinoamericano en `es` y `es-419`.
4. Pruebas unitarias en `YalaTests/OfertaProMazoCentrado/`: oferta en la tarjeta final solo con derecho a la prueba; texto de A los días siguientes; saludo con nombre, sin nombre y que desaparece tras el paso 1.

## Qué NO hay que tocar
- La hoja de pago que sale tras el paso 2 ni `StoreKitManager`.
- La lógica de qué paso cuenta como hecho, guías y pulido (ya van en los lotes anteriores).

## Cómo se sabe que está bien
- Con derecho a la prueba: al completar Primeros pasos, la tarjeta final muestra la oferta del mes gratis como la maqueta C y el botón abre la hoja de planes; al día siguiente, la tarjeta de Pro dice «Prueba Yala Pro gratis 1 mes».
- Sin derecho: todo como hoy.
- En el paso 1, el mazo centrado con «Hola, <nombre>» (o «Hola»); al crear la cuenta, el saludo se va y el mazo sube.
- Capturas antes/después en `capturas/` del worktree, claro y oscuro, iPhone 14. Mueve a done las dos cards de arriba al terminar.

## Cómo trabajar
- Arranca sobre `origin/2.3`, en tu worktree. Mira la maqueta (`index.html` de la carpeta de docs) antes de diseñar, y `~/Claude/referencias-ui/README.md` como inspiración.
- Verificación visual: puedes usar el iPhone 14 por DeviceMCP (Yala Dev ya instalada; si Jürgen lo está usando, no lo toques y usa simulador) o, en la Max, un segundo simulador además del de otra sesión. En la Mini, un solo simulador. Apaga y limpia los simuladores que enciendas. En Yala Dev no hay precios: para ver la oferta con derecho a la prueba usa la configuración de StoreKit local o un gancho de prueba.
- Pipeline serial: limpiar, build `xcodebuild -jobs 2` sin simulador encendido, encender un simulador, pruebas, apagarlo.
- Corre solo las pruebas que toca el cambio; la suite completa, una sola vez al final. 2 timeouts = inestable, se anota y se sigue. Tope de 30 min en pruebas de interfaz. Ninguna espera de más de 3 min sin escribir avance.
- Da siempre una descripción corta, en español y sobre el tema, a cada comando Bash.

## Cierre
- Un solo PR a `2.3`, auto-merge activado, y cierra sin quedarte esperando: los conflictos los relanza el vigía.
- Cierre con `/cerrar-total` cuando el trabajo esté completo y el modo lo permita. En semiautónomo, lo vital se le pregunta a Jürgen y se espera con la sesión viva. En nocturno, lo vital se preserva con checkpoint recuperable y card «Espera decisión» para Jürgen, sin mergear lo incompleto.
- El cierre lleva «Saltado o asumido sin preguntar» y «Decidido sin consultar», cada uno con motivo o «Nada». `BLOQUEANTE:` solo si algo de verdad no puede seguir sin Jürgen.
- Sin firma de IA en commits, PR ni textos. Español neutro latinoamericano en todo lo que lea Jürgen.

## Paso 0 — decisiones (resueltas en autónomo (bypass), nocturno)

1. **Base**: `origin/2.3` al día. El pulido (PR abierto, auto-merge) toca `SetupChecklistCard.swift` en el título final y el confeti; se trabaja sobre 2.3 y se rebasa antes del PR, respetando su título por `PrimerosPasosFinalTitleLogic` si ya entró.
2. **Contenido de C**: el que dice el encargo (manda sobre la maqueta, que es más corta): chip «YALA PRO · 1 MES GRATIS», «Para seguir: prueba Yala Pro 1 mes gratis», tres beneficios (Anota sin teclear · Yala IA · Sin límites, con los detalles de la maqueta B), «Empezar mi mes gratis», «Hoy no pagas · te avisamos antes de cobrar», y una fila con «Ahora no» y «Cerrar».
3. **«Ahora no» vs «Cerrar»**: «Ahora no» pliega solo la oferta (queda la tarjeta de «completos» con su «Cerrar»); «Cerrar» quita la tarjeta entera, como hoy. «Ahora no» se recuerda (UserDefaults, se borra con el reinicio del gestor).
4. **Quién tiene derecho**: sin Pro, elegibilidad medida, con días de prueba y prueba de un mes (`announcesFreeMonth`). Sin medir (Yala Dev sin precios), todo como hoy.
5. **«Empezar mi mes gratis»**: pide la hoja «Prueba Yala Pro 1 mes gratis» por el router (`.presentTrialOffer` con la marca de la oferta de Primeros pasos), la misma que sale tras el paso 2. No se toca la hoja ni StoreKit.
6. **Hoja al completar**: si la tarjeta ya lleva la oferta, no sube además la hoja al completar (taparía el logro y repetiría la oferta). Sin derecho, igual que hoy.
7. **Tarjeta de Pro del Panel**: con derecho, el texto de A (chip «1 MES GRATIS», «Prueba Yala Pro gratis 1 mes», línea de A y «Empezar mes gratis»); el botón sigue abriendo lo de hoy (el encargo pide el texto). Mientras la tarjeta final lleva la oferta, la de Pro no sale a la vez.
8. **Nombre del saludo**: `userName` de Ajustes (lo llena la bienvenida con Apple o Google); vacío o el de relleno («Usuario» en cualquier idioma) → «Hola». Solo el primer nombre.
9. **Centrado**: se mide el alto visible del scroll y el del bloque saludo+mazo, y se baja el bloque lo justo para centrarlo; al resolver el paso 1 el desplazamiento vuelve a 0 con la animación implícita del Panel (`DS.Animation.appear`; sin animación con Reducir movimiento) y el saludo se funde.
10. **Pruebas**: unitarias en `YalaTests/OfertaProMazoCentrado/` (lógica + 16 idiomas); XCUITest de capturas en `YalaUITests/OfertaProMazoCentrado/` con `-uitest-fake-prices`.
