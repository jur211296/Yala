---
id: group-receipt-split-home-buttons
status: backlog
area: groups
priority: medium
created: 2026-11-13
updated: 2026-11-13
source: card tablero-grupos-repartir-un-recibo-con-ia-foto-o-fu74 · pedido de Jürgen del 13-nov
---

# Grupos: Voz y Foto en el inicio de Grupos, y la barrera de IA para Free

## Qué pidió Jürgen (13-nov, probando Yala Dev 2.3)

1. Los botones de foto y voz, en el inicio de Grupos como en personal, no dentro de Nuevo gasto.
2. ¿Hay barrera de IA en Grupos? Grupos es gratis y le estamos metiendo IA.

## Lo medido (Fase 1)

Artifact con capturas y opciones: https://claude.ai/artifact/CNDthi5HMDYdm3No9vvMEZ

- **Personal:** Voz y Foto del Panel llevan candado para Free (`PanelView.startAIEntry`, `FeatureGateService.canAccess`).
  Las 5 fotos y 5 notas de prueba solo se gastan en la práctica de «Configura tu Yala» (`enableSetupTrial`).
- **Grupos:** «Desde un recibo» no mira si eres Pro. La barrera es solo del servidor: `receipt.photo` cuenta en
  `vision` y `receipt.voice` en `voice` (`gateway/src/ai/tasks.ts`), con el MISMO cupo de prueba de Free (5 + 5 por
  instalación, `gateway/src/policy.ts`) y los mismos topes diarios de Pro (50 fotos, 100 notas). Agotado, el aviso sale
  después de sacar la foto (`GroupReceiptSplitView.failure`).
- **Yala Dev no enseña la barrera:** staging va en `ENFORCE = "observe"` y `TRUST_ATTESTED_AS_PRO = "true"`
  (`gateway/wrangler.toml`). Producción, `enforce`.
- **El plan de 2.3 dice «repartir un recibo con IA (Pro)»** (`docs/DECISIONS.md`); el ticket
  `group-expense-from-a-receipt-with-ai` dice que gasta la prueba. No cuadran.
- **No hay otra IA dentro de Grupos.**

## Propuesta de botones

- Inicio de Grupos: Voz y Foto entre «Nuevo gasto» y «Nuevo grupo», con las píldoras del Panel. Un solo grupo elegible:
  entra directo; varios: «¿En qué grupo?» (`GroupPickerSheet`, último usado primero). Sin ninguno, no salen.
- Dentro de un grupo: Voz y Foto bajo el saldo, directo a ese grupo. El + no cambia.
- Foto abre la hoja lista para la foto; Voz la abre escuchando. «Usar este reparto» abre Nuevo gasto relleno.
- Quitar la píldora «Desde un recibo» de Nuevo gasto.

## Barrera: opciones

- A · Igual que hoy (prueba compartida, sin candado).
- B · Solo Pro con candado, como personal (recomendada; el servidor no cambia).
- C · Cupo propio de Grupos (app + servidor).

**Decisión (Jürgen, 14-nov):** ni A ni B ni C tal cual. Grupos es el gancho: todo usuario Free, use solo Grupos o
también personal, tiene **5 recibos con IA al día** (foto o voz, un contador). Pro, **50 al día** con contador propio.
Ninguno gasta lo de personal. Botones: sí, en el inicio y dentro del grupo, y fuera la píldora.

## Qué se construyó (14-nov)

- **Servidor:** cubo `receipt` en `gateway/src/policy.ts` (Free `daily: 5`, Pro `daily: 50`). `receipt.photo`,
  `receipt.voice` y la tarea nueva `receipt.transcribe` cuentan ahí (`tasks.ts`, `routes.ts`). La transcripción acepta su
  tarea por cabecera (`resolve.ts`, `handler.ts`). Una app vieja sin la cabecera nueva sigue funcionando.
- **App:** Voz y Foto en el inicio de Grupos (`GroupsContainerView`) y bajo el saldo del grupo, también con el grupo
  vacío (`GroupRecordsView`). La pieza común es `GroupReceiptEntry.swift`, con los botones y el camino: selector de grupo,
  hoja del recibo y Nuevo gasto relleno. Sin la píldora «Desde un recibo» en Nuevo gasto. Agotado el cupo, Free ve
  «Ver Yala Pro» y Pro «vuelve mañana». Textos en 16 idiomas.
- **Despliegue:** el Worker lo despliega Jürgen (`deploy:staging` y `deploy:production`) antes de publicar 2.3. Mientras
  no esté desplegado, el recibo sigue gastando la prueba de personal, como hoy, y la app lo entiende.
