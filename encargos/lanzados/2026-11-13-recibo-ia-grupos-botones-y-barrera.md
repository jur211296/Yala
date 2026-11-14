Yala
# Grupos: foto y voz en el inicio de Grupos y explicar la barrera de IA
---
card: tablero-grupos-repartir-un-recibo-con-ia-foto-o-fu74
toca: Yala/App/Views/Groups/GroupsContainerView.swift, Yala/App/Views/Groups/GroupDetailView.swift, Yala/App/Views/Groups/GroupExpenseFormView.swift, Yala/App/Views/Groups/GroupReceiptSplitView.swift, Yala/App/Services/ReceiptSplitService.swift, Yala/App/Logic/ReceiptSplitLogic.swift, Yala/Utils/L10n+ReceiptSplit.swift, Yala/Resources/, YalaTests/GroupReceiptSplitHome/, YalaUITests/Flows/GroupReceiptSplitUITests.swift, tickets/backlog/group-receipt-split-home-buttons.md, tickets/done/group-receipt-split-home-buttons.md, docs/qa/group-receipt-split-home-buttons/
esfuerzo: medium
cierre: manual
---

Sesión en MODO MANUAL: no cierres por tu cuenta. Rama base: 2.3 (la 2.2 está cerrada y no se toca). Contexto: el PR de repartir un recibo con IA (https://github.com/jur211296/Yala/pull/817, ya en 2.3) puso «Desde un recibo» como píldora dentro de Nuevo gasto del grupo. Jürgen lo probó en Yala Dev 2.3 y pidió el 13-nov:

1. «Asemejar la experiencia que se tiene en personal: los botones de imagen y voz deben estar en el inicio de Grupos como botones, no dentro del nuevo registro.»
2. «¿Hay barrera de uso de IA en Yala Grupos? Grupos es free pero ahí estamos metiendo funcionalidades de IA.»

FASE 1 · EXPLICAR (sin tocar código de la app):
- Mide en el código real de 2.3 cómo funciona hoy la barrera de IA en Grupos: qué pasa a un usuario Free y a uno Pro al usar foto o voz para repartir un recibo, si comparte el cupo de prueba (5 fotos y 5 notas) con el registro personal, qué valida el gateway y qué se ve al agotarlo. Compáralo con foto y voz del registro personal. Di también qué otras funciones de IA hay hoy dentro de Grupos, si las hay.
- Propón cómo quedarían los botones de foto y voz en el inicio de Grupos, copiando el patrón del inicio de personal: dónde van, qué pasa al tocarlos (elegir grupo si hay varios o estás en la lista, y entrar directo si estás dentro de un grupo), y qué pasa con la píldora actual dentro de Nuevo gasto (recomendación: quitarla).
- Entrégalo como artifact visual de Claude (nunca Markdown ni PDF): maqueta del inicio de Grupos antes y después, el recorrido Free y Pro con capturas reales del simulador, y 2 o 3 opciones de barrera (por ejemplo: igual que hoy, solo Pro, o cupo propio de Grupos) con tu recomendación, para que Jürgen decida fácil.
- Pregunta a Jürgen y espera con la sesión viva. No asumas su respuesta.

FASE 2 · CONSTRUIR (solo con el GO de Jürgen y lo que él elija):
- Implementa los botones en el inicio de Grupos y la barrera elegida. Los tests nuevos van en `YalaTests/GroupReceiptSplitHome/`. Actualiza `GroupReceiptSplitUITests`. Textos en los 16 idiomas, en español neutro latinoamericano.
- Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.
- Crea el ticket `tickets/backlog/group-receipt-split-home-buttons.md`, muévelo a done al terminar y abre un PR contra 2.3 con capturas. No mergees ni cierres sin el GO final de Jürgen.

Reglas: commits y PR sin firma de IA. Si otra sesión usa el simulador, puedes abrir un segundo simulador o usar el iPhone 14 por DeviceMCP. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Modo manual: no hay cierre final sin GO humano. El cierre conserva «Saltado o asumido sin preguntar» y «Decidido sin consultar».

## Paso 0 — decisiones

> Modo manual. D1, D2 y D2b-D2d las contestó Jürgen en el chat el 14-nov (artifact
> https://claude.ai/artifact/CNDthi5HMDYdm3No9vvMEZ). D3-D7 las tomo yo y se discuten en el PR.

**D1 · ¿Voz y Foto en el inicio de Grupos y dentro del grupo, y fuera la píldora de Nuevo gasto?** → Sí a los tres (Jürgen, 14-nov).
Por qué: un solo camino, como en personal. Alternativa: dejar también la píldora (dos caminos al mismo sitio).

**D2 · Barrera de IA para Free en Grupos** → Cupo propio y diario, sin candado (Jürgen, 14-nov; descartó mi B, solo Pro).
Por qué, en sus palabras: «no puedo hacerlo pagar Pro de personal+grupos. Grupos será el gancho, debemos dar ventajas». Supersede el «(Pro)» del plan de 2.3 en `docs/DECISIONS.md`.

**D2b · Free que además usa personal** → Los mismos 5 al día que quien solo usa Grupos (Jürgen).
Por qué: no castiga empezar a usar personal, y el servidor no necesita saber el modo. Personal sigue con candado y su prueba de «Configura tu Yala».

**D2c · Pro** → Cupo propio de 50 recibos al día, aparte de las 50 fotos y 100 notas de personal (Jürgen).

**D2d · Cómo cuenta** → 5 en total al día, foto o voz, un solo contador (Jürgen).
Consecuencia técnica: categoría nueva `receipt` en el gateway (free `daily: 5`, pro `daily: 50`), y la transcripción de la nota del recibo va por una tarea propia en `receipt` para no gastar la prueba de voz de personal. El despliegue del Worker lo hace Jürgen (`gateway/RUNBOOK.md`), antes de publicar 2.3.

**D3 · Con varios grupos elegibles, ¿cómo se elige?** → `GroupPickerSheet` con el último grupo usado primero (`LastExpenseGroupMark`).
Por qué: es el selector y la regla que ya usa «Nuevo gasto». Alternativa: abrir siempre en el último grupo (esconde a cuál va el gasto).

**D4 · ¿Qué pasa tras «Usar este reparto» desde el inicio?** → Abre Nuevo gasto del grupo elegido ya relleno, como hoy desde el formulario.
Por qué: el gasto se guarda por el formulario de siempre (quién pagó, cuenta). Alternativa: guardar directo (salta quién pagó).

**D5 · Voz: ¿abre la hoja o empieza a escuchar?** → Abre la hoja y empieza a escuchar, como Voz en personal.
Por qué: el botón dice Voz; un toque más sería una pantalla de paso. Reversible.

**D6 · Sin ningún grupo donde apuntar** → Voz y Foto no salen.
Por qué: igual que «Nuevo gasto» hoy en el inicio de Grupos.

**D7 · El flotante (+) del inicio de Grupos** → No cambia.
Por qué: el encargo pide los botones de arriba; tocar el flotante es alcance no pedido.

**D8 · Las cuatro acciones no caben en una fila del iPhone en español** → *Superada por D12.* Si no caben, «Nuevo grupo»
baja a una segunda fila (`ViewThatFits`). Medido en el simulador: en una sola fila salían «Nuevo gas…» y «Nuevo gr…». Las
alternativas eran desplazar la fila, como el Panel, o quitar «Nuevo grupo», que ya está en el +. Desplazar esconde una
acción y quitarla es alcance no pedido.

**D9 · Grupo sin gastos** → Voz y Foto salen también encima del vacío. Un grupo recién creado es justo donde se reparte
el primer recibo.

**D10 · Nuevo gasto que llega con un reparto** → No deja cambiar de grupo. El reparto va por los miembros de ese grupo y,
en otro, no casaría.

**D11 · Textos del cupo agotado** → Sin la cifra, como los de la prueba de personal. Así no caducan si el cupo cambia.

**D12 · La fila de arriba (Jürgen, 14-nov, tras ver la captura de D8)** → Lleva «Nuevo gasto», Voz, Foto y Yala IA, como
en personal, en el inicio de Grupos y bajo el saldo del grupo. «Nuevo grupo» va en la barra de arriba, como un icono
junto a Ajustes. Su motivo: «la segunda fila se ve fea y ocupa demasiado espacio».

**D13 · Qué hace Yala IA en Grupos (Jürgen)** → Abre la hoja del recibo para escribir el gasto («pizza 40 Ana y yo…»).
Sigue la misma revisión y termina en Nuevo gasto relleno. Cuenta en los 5 recibos al día. Se descartó el chat de Yala
IA: es solo Pro y no sabe crear gastos de grupo.

**D14 · Aspecto de Yala IA en Grupos (Jürgen)** → El dorado y el nombre de personal, sin candado.

**D15 · Si la fila no cabe en algún idioma** → Se desplaza a los lados, como la del Panel. Nunca se corta un título.
