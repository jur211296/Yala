# Pulido visual pedido por Jürgen (17-oct): botones Voz/Foto y texto blanco en botones púrpura

Base y PR: **2.2**. `lanzar-sesion` te deja sobre origin/2.1: antes del primer commit haz `git fetch origin && git switch -C encargo-tmp origin/2.2` y comprueba que `git log origin/2.2..HEAD` sale vacío. PR contra 2.2.

Cards (Yala, 2.2, frank). Muévelas a in progress al empezar y a done al cerrar con `--agente frank`:
- «Botones Voz y Foto del Panel: iconos del mismo alto y textos alineados…»
- «Botones de fondo púrpura con texto oscuro: pasar a texto blanco…»
- «Avisos de IA: quitar «OpenAI» y decir «un servicio de IA», con el detalle en la política»
Lee su contexto y su «hecha cuando».

## Qué hacer
1. **Barra del Panel** (Nuevo registro / Voz / Foto / IA). Hoy la onda de Voz y el icono de Foto tienen distinto alto, y por eso «Voz» y «Foto» no quedan a la misma altura. Usa un marco de icono común, de alto fijo, y alinea los rótulos en la misma línea base, un punto más pequeños si mejora. Captura la barra en los 16 idiomas y con texto grande: nada debe truncarse ni partirse. Respeta lo que ya entró del lote 14 sobre el botón de IA.
2. **Botón principal púrpura con texto oscuro.** Pasa el texto a blanco con contraste AA, en claro y en oscuro. Empieza por «Activar» en el aviso «Yala lo apunta por ti», arréglalo en el estilo compartido y revisa todas las pantallas que lo usan.
3. **Avisos de IA sin «OpenAI».** Decisión de Jürgen del 17-oct a las 09:09. En todas las cadenas `aiConsent.*` (avisos de voz y foto, insights y chat, y las pistas cortas `inlineHint*`), en los 16 idiomas, quita el nombre del proveedor y di «un servicio de IA». Sigue el estilo del aviso de voz y foto: primero el beneficio, después qué se envía y que no se usa para entrenar a la IA. Cada aviso mantiene el enlace a la Política de privacidad, que ya nombra al proveedor. No toques la política. Añade un test que falle si «OpenAI» vuelve a una cadena visible de consentimiento.
- Ante cualquier duda, elige la opción recomendada y anótala en la card. Jürgen no está este fin de semana.
- Prueba según /barrido-qa en el simulador, con capturas de antes y después para el cierre.

## Reglas
- No esperes el CI de nadie. Haz `git fetch && git rebase origin/2.2` justo antes de abrir tu PR.
- Usa 1 simulador a la vez. Al terminar, apágalo y borra tu DerivedData. Mira `df -h /` antes de compilar.
- En `~/Yala` (el árbol principal) no toques los `.ckdb` sin commitear, `Yala.xcscheme` ni `encargos/pendientes/`. No toques las tmux `salud--*`, `sat-lab--*` ni `clinicas-dentales-bi--*`.
- Todo ticket nuevo lleva su card.
- Cierra con /cerrar-total.

## Paso 0 — decisiones

> Resueltas en autónomo (bypass): las recomendaciones se dan por buenas. Se discuten en el PR.

Hechos medidos antes de decidir (simulador iPhone 17 Pro, iOS 27.0, modo oscuro):
- «Voz» queda 1 pt por debajo de «Foto»: el icono de la onda mide 15 pt de alto y el de la foto 13 pt.
- «Activar» sale en negro sobre `#6366F1`. La alerta del sistema toma el **relleno** del `AccentColor`
  del catálogo y el **texto** del tinte de SwiftUI de quien la presenta. Cuando coinciden, elige negro o
  blanco según cuál contraste más: sobre `#6366F1` el negro da 4,70:1 y el blanco 4,47:1 (por debajo de AA).
- Es la **única** alerta de la app con acción destacada (`.keyboardShortcut(.defaultAction)`). Los
  `.borderedProminent` de SwiftUI («Aplicar» de Filtros, etc.) ya salen con texto blanco.
- Las pistas `aiConsent.inlineHint*` no las usa ningún código hoy; se reescriben igual, como pide el encargo.

**D1 · Cómo igualar Voz y Foto** → marco de icono común de 18 pt con `@ScaledMetric`, para que crezca con el
texto grande. Por qué: mismo alto arriba ⇒ misma línea base abajo. Alternativa descartada: alto fijo sin
escalar (con letra grande el icono quedaría enano).

**D2 · ¿Rótulos un punto más pequeños?** → no. Ya están en `caption2` (11 pt), el tamaño mínimo de iOS.
Por qué: bajar de ahí daña la lectura y no lo pide el desalineado, que arregla D1.

**D3 · Cómo poner blanco el texto de «Activar»** → la alerta se presenta desde un ancla de fondo con su propio tinte
(`Color.alertActionTint`): **blanco en los temas oscuros** y `electricIndigo` en el Claro; el `AccentColor` del catálogo
gana una variante oscura `#585BEC` (`Color.alertActionIndigo`), con test de paridad. Resultado medido: oscuro, texto
blanco a 5,09:1; claro, negro a 4,70:1 (AA, igual que antes). Por qué: medido en píxeles, el texto del botón destacado
sale del tinte de quien presenta la alerta y, si coincide con el relleno, sale NEGRO siempre (también sobre `#3D36B3`):
no elige por contraste, como suponía la primera versión de esta decisión. En claro, un tinte blanco pondría también en
blanco «Política» y «Cancelar» sobre el cristal claro, ilegibles: ahí queda el negro AA como límite de la alerta del
sistema. Descartadas: `.tint` o `foregroundStyle` en el botón y `role: .confirm` (la alerta los ignora, medido), cambiar
el acento de toda la app (decisión de marca) y pasar el aviso a hoja (tocaría las cinco pantallas que lo presentan).

**D4 · Alcance de «todos los botones púrpura»** → solo el que tiene texto oscuro: la alerta. Los botones
propios rellenos con `theme.accent` y texto blanco miden 4,47:1 (0,03 por debajo de AA en texto normal; AA
como texto grande en los de 17 pt seminegrita). Pasarlos a AA es cambiar el acento de marca en ~40 sitios:
va a ticket con su card, para que decida Jürgen.

**D5 · Texto de los avisos sin «OpenAI»** → estilo de L4-2: lo que gana la persona, qué se envía «a un
servicio de IA» y que no se usa para entrenar a la IA. Se conservan todas las afirmaciones que había (qué se
envía, que no va el historial completo, que no entrena) y no se añade ninguna nueva. Las pistas cortas solo
cambian el proveedor. El francés del aviso de voz y foto sigue en «vous», como estaba.

**D6 · ¿Y «OpenAI» fuera de `aiConsent.*`?** → no se toca. `aiPrivacy.footerHint` (Ajustes › Privacidad de
la IA) y `profile.privacyDesc` (Datos personales) lo nombran, pero no son avisos de consentimiento sino el
detalle, como la política. Va como hallazgo en la card del aviso.

**D7 · Test** → `AIConsentProviderNameTests`: ningún valor `aiConsent.*` de los 16 idiomas contiene
«OpenAI» (ni «ChatGPT»/«gpt-»), el escáner caza el texto viejo, y los tres avisos conservan el botón de la
política. Más `AlertActionIndigoParityTests` para D3.
