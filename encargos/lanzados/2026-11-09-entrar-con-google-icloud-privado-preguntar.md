---
toca: Yala/App/Logic/CrossAccountEntryGuardLogic.swift, Yala/App/Logic/CloudWelcomeSignInFlow.swift, Yala/App/Logic/CloudIdentityRoutingLogic.swift, Yala/App/Logic/ICloudRestoreInProgressLogic.swift, Yala/App/Views/Onboarding/, Yala/Services/CloudSync/, Yala/Resources/, YalaTests/, YalaUITests/
release: no
---
Yala
# Entrar con Google o Apple teniendo tu propio iCloud privado: preguntar en vez de bloquear

Card del tablero: «Entrar con Google bloqueado por tus propios datos de iCloud privado («datos de otra cuenta»)» (v2.2, backlog). Léela entera con `tablero listar --proyecto Yala --version 2.2` y `tablero ver`. Contexto medido el 6-nov en el iPhone 14 (Yala Dev): con los datos del iCloud privado en el teléfono, «Ya tengo cuenta › Entrar con Google» termina en «Este dispositivo tiene datos de otra cuenta». `CrossAccountEntryGuardLogic` cuenta filas locales sin claim y no distingue datos ajenos de los propios del iCloud privado. Hoy la única salida es «Empezar de cero», que borra también iCloud.

## Decisión de Jürgen (9-nov, registrada en decisiones.py con la clave t1488u; reemplaza a t1487u)
Opción C: cuando el dueño del iCloud privado entra con su cuenta en la nube, NO se le bloquea ni se le dice «de otra cuenta». Se le pregunta qué prefiere: (a) pasar sus datos de iCloud a la nube, o (b) entrar en la nube dejando los de iCloud aparte. La protección del teléfono prestado/heredado (datos realmente ajenos) se mantiene intacta.

## Cómo
- Desde `origin/2.2` al día. Un solo PR contra 2.2, commits y PR sin firma de IA.
- Distingue con un criterio fiable «datos del iCloud privado de este mismo dueño» frente a «datos ajenos». Si no hay forma segura de distinguirlos, eso es vital: pregúntalo según el modo, no lo inventes.
- Textos en español neutro latinoamericano, cortos y con el estilo de la app.
- Tests de lógica para los tres casos (propio con opción a, propio con opción b, ajeno sigue bloqueado) y verificación en simulador.
- QA: hazlo tú mismo en el iPhone 14 por DeviceMCP (está en Yala Dev con una cuenta iCloud privada). En la Max puedes usar un segundo simulador si otro está ocupado (tope 2).
- Hay PR abiertos de la calculadora del saldo (#876) y del informe de QA (#874), y puede haber otro del lote de cierre 2.2: no los pises; rebasa si hace falta.
- Jürgen pidió (9-nov) que cierre solo hasta done: NO dejes la card en «in qa». Con CI verde y QA hecho, mergea y muévela directo a done con evidencia (PR, capturas, tests).

## Límites
- No toques TestFlight, marketing/ ni 1.0. No debilites la protección de teléfono ajeno ni borres datos de iCloud sin elección explícita del usuario.
- Lo menor y reversible lo decides tú y lo anotas en «Decidido sin consultar».

## Cierre
Según el modo fijado al arrancar: en semiautónomo, si está completo y mergeado, `/cerrar-total`; lo vital se pregunta y se espera con la sesión viva. En nocturno, lo vital va a checkpoint recuperable con card «Espera decisión» para Jürgen, sin mergear lo incompleto; si está completo, `/cerrar-total`.

## Paso 0 — decisiones (resueltas en autónomo, nocturno)

1. **¿Hay un criterio fiable «iCloud propio» vs «ajeno»?** Medido: solo para un subconjunto (faro del modo nube o asociación de Grupos en el iCloud key-value que coincidan con la cuenta que entra). Para el resto no hay prueba. → **Vital**: el encargo manda no inventarlo.
2. **¿Qué es la opción (a)?** La cuenta de la nube que entra ya es completa; pasar iCloud a ella es una fusión, que la tabla de identidad descarta por escrito. → **Vital** (diseño de datos).
3. **¿Existe mecanismo para (b)?** No: la sesión secundaria M1 se retiró el 2026-09-09 y nube e iCloud comparten archivo de store. Construirlo es un flujo nuevo de sincronización. → Alcance a decidir por Jürgen.
4. **Qué hago esta noche:** sin código. Documento lo medido y las preguntas en `docs/sessions/2026-11-09-icloud-privado-entrar-con-cuenta-nube.md` y preservo con `checkpoint_nocturno.py` (card «Espera decisión», PR en borrador, sin merge).
