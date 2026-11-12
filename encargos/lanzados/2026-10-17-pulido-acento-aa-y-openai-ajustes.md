# Pulido 2 (17-oct): acento de marca a AA con texto blanco, y «OpenAI» fuera de Ajustes y Datos personales

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

Cards (Yala, 2.2). Muévelas a in progress al empezar y a done al cerrar con `--agente frank`:
- «El texto blanco sobre el índigo de marca se queda a 0,03 del contraste AA (4,47:1)»
- «Ajustes y Datos personales siguen nombrando a OpenAI: ¿quitarlo también ahí?»
Lee su contexto y su «hecha cuando». Las dos ya están decididas por Jürgen; anota la decisión en cada card.

## Qué hacer
1. **Acento de marca a AA** (decisión de Jürgen, 17-oct 16:17: «Oscurece un poco el acento de marca para que pase AA»). Hoy el blanco sobre `theme.accent` (#6366F1 en claro) da 4,47:1 en botones propios como «Nuevo registro» del Panel (15 pt medio) o «Aplicar», unos 40 sitios. Oscurece el acento lo mínimo necesario para que el blanco pase **≥ 4,5:1 con margen (apunta a ~4,6:1)** en todos los temas donde el texto sobre acento es blanco, sin que la marca se vea distinta. Hazlo en el token compartido, no botón por botón. Mantén coherentes `AccentColor.colorset` (incluida la variante oscura #585BEC que entró en el PR #539), `alertActionIndigo`/`alertActionTint` y su test de paridad, los widgets y cualquier otro sitio que copie el hex. Revisa que el acento siga legible como texto o icono sobre fondo claro y oscuro (no debe bajar de AA en ningún uso). Añade un test de contraste del token. Captura antes y después del Panel, Filtros y dos pantallas más, en claro y oscuro.
2. **«OpenAI» fuera de la app** (decisión de Jürgen, 17-oct 15:19: «Preferiría no decir literalmente OpenAI a menos que sea 100% necesario»). Quita el nombre del proveedor de `aiPrivacy.footerHint` (Ajustes › Privacidad de la IA) y `profile.privacyDesc` (Datos personales) en los 16 idiomas, diciendo «un servicio de IA» y manteniendo el enlace o la referencia a la Política de privacidad. Busca cualquier otra cadena visible que nombre a OpenAI, ChatGPT o GPT y quítala también, salvo la política. Amplía `AIConsentProviderNameTests` (o crea uno hermano) para que falle si cualquier cadena visible de `Localizable.strings` nombra al proveedor, con una lista explícita de excepciones justificadas si alguna es 100% necesaria.
- Ante cualquier duda, elige la opción recomendada y anótala en la card. Jürgen no está este fin de semana.
- Prueba según /barrido-qa en el simulador, con capturas de antes y después para el cierre.

## Reglas
- No esperes el CI de nadie. Haz `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Usa 1 simulador a la vez. Al terminar, apágalo y borra tu DerivedData. Mira `df -h /` antes de compilar.
- En `~/Yala` (el árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques las tmux `salud--*`, `sat-lab--*` ni `clinicas-dentales-bi--*`.
- Todo ticket nuevo lleva su card.
- Cierra con /cerrar-total.

## Paso 0 (Frank, 2026-10-17, autónomo; Jürgen fuera)

Ficheros previstos (nota, no pregunta): `UIHelpers.swift` (token y docblocks), `AccentColor.colorset`,
`LaunchBackground.colorset`, `WidgetColors.swift`, `SankeyFlowCalculator.swift`, `AlertActionIndigoParityTests.swift`
(comentarios), test nuevo de contraste, 16 × `Localizable.strings` + 16 × `InfoPlist.strings` + `Info.plist`,
`L10n.swift` (accesor muerto), `AIConsentProviderNameTests.swift` (ampliado), `swiftui-ds.md` (cifras), tickets.

1. **Hex nuevo: `#6063F1`** (medido). Mismo tono y saturación que `#6366F1`, solo baja la luminosidad. Blanco encima
   4,61:1 (era 4,47), ΔE 2,2 (no se distingue). Es el más claro que llega a ~4,6.
2. **Temas cubiertos: los de acento índigo** (Claro, Oscuro, Índigo, Translúcido, Liquid Glass). Rosa, Turquesa y
   Minimalista tienen otro acento con blanco muy por debajo de AA (3,8 / 2,2 / ~1,9): fuera, con ticket y card propios.
3. **Acento como texto en oscuro: conflicto matemático, gana el botón.** Un mismo color no puede dar blanco AA encima y
   AA sobre los fondos oscuros a la vez. Sobre negro puro sigue AA (4,70 → 4,55); sobre el fondo de Liquid Glass baja
   de 4,51 a 4,37, y sobre las tarjetas oscuras ya estaba por debajo (3,3–3,8). Se apunta en la card y en un ticket
   («token de texto índigo para temas oscuros»).
4. **`AccentColor`**: claro → `#6063F1`; oscuro se queda en `#585BEC` (`alertActionIndigo`, 5,09). La alerta en claro
   sigue con texto negro: 4,55:1, AA.
5. **Copias del hex de marca** que se actualizan: `WidgetColors.primary`, `LaunchBackground` (casa con el splash, que
   pinta `electricIndigo`) y el color «disponible» del Sankey. **No** se tocan los `#6366F1` de datos (color por defecto
   de cuentas y categorías, paletas para elegir, seeds): son datos del usuario que viajan por sync.
6. **«OpenAI» fuera**: `aiPrivacy.footerHint`, `profile.privacyDesc` y los tres permisos de cámara, micrófono y fotos
   (`InfoPlist.strings` ×16 + `Info.plist`) dicen «un servicio de IA». El pie de Ajustes ya lleva el enlace a la
   política debajo; Datos personales no tiene enlace, así que gana una frase que remite a la Política de privacidad.
   `insights.aiCaption` (muerta) se borra de los 16 idiomas y su accesor.
7. **Excepciones del test: ninguna en `.strings`.** Fuera de ellas quedan dos sitios con el nombre que no son copy de la
   app: el limpiador de notas de recibos reconoce el comercio «ChatGPT (OpenAI)» (es el nombre de un cobro del usuario),
   y los `errorDescription` «OpenAI API key not configured» de cuatro servicios nunca se lanzan (medido: ningún
   `throw` de esos casos).
