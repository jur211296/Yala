---
id: groups-kept-by-the-late-notice-are-purged-by-the-welcome-fresh-start
status: qa
priority: low
updated: 2026-10-06
qa-status: pending
area: "onboarding, groups"
created: 2026-09-27
source: "review adversarial de `late-notice-of-a-welcome-private-session-purges-groups-joined-later` (2026-09-27, lente «después del borrado»); inferido por lectura, NO reproducido"
---

# Los grupos que el aviso tardío conserva se pierden si luego cancelo el onboarding y empiezo de cero en el Welcome

## El síntoma, en lenguaje de usuario

Contesto «Empezar de cero» en «Encontramos datos tuyos en iCloud». Mis grupos se quedan y vuelvo al onboarding
personal. Si ahí toco «Cancelar», vuelvo al Welcome; si elijo «Es mi primera vez → privado», me sale el aviso de «hay
datos en este teléfono» y, si confirmo, se borran también mis grupos, su sesión y el dominio queda sellado.

## Lo medido (2026-09-27, leyendo código)

- Tras el aviso, `hasShownWelcomeChooser` sigue en `true` y la persona entra directa al onboarding
  (`ContentView.presentNextOnboardingScreen`). El «Cancelar» del paso 1 lo baja y la manda al Hero.
- `startFreshPrivateOnboarding` cuenta los grupos (`hasLocalDataNow` → `SplitGroup`) y enseña el alert del handover,
  cuyo copy es el de «aquí empieza otro usuario». Su borrado purga y sella lo que el aviso acababa de conservar.
- Las puertas de organizador e invitación también ven esos grupos como datos del teléfono (`.returnsToNeutral`).
- Existe igual desde #280 para quien activó Yala completo; desde este ticket le pasa también a quien empezó en el
  Welcome privado.

## Qué hay que decidir

Si volver al Welcome desde el onboarding tras el aviso tardío debe ofrecer el camino de «misma persona» (conservar los
grupos) o si el alert del handover es lo correcto porque quien vuelve al Welcome puede ser otra persona.

## Criterios de aceptación

- [x] La persona que acaba de conservar sus grupos en el aviso no los pierde por cancelar el onboarding y volver a
      elegir privado, o lo hace con un copy que se lo diga.

## Relacionados

- [[late-notice-of-a-welcome-private-session-purges-groups-joined-later]]
- [[activation-private-gate-leaves-a-late-notice-that-purges-groups]]

## Decisión (2026-10-04, Jürgen) · opción A

Camino de la misma persona: el aviso tardío no prueba que sea otra gente, así que quien acaba de conservar sus grupos no
los pierde por cancelar el onboarding y volver a elegir privado.

## Qué cambia para el usuario

Quien contesta «Empezar de cero» en «Encontramos datos tuyos en iCloud» y luego cancela el onboarding vuelve a la
bienvenida como antes. Si ahí elige «Es mi primera vez → privado», **va directo al onboarding**: sin el aviso de «hay
datos en este teléfono», y con sus grupos, sus saldos y su sesión de Grupos intactos. Si en la puerta vuelve a ver
«Encontramos datos en iCloud» (otro dispositivo volvió a subir algo) y elige empezar de cero, se borra lo personal y los
grupos se quedan, igual que en el aviso.

Quien usa un teléfono que era de otra persona, sin ese aviso previo, ve lo mismo que hoy: el aviso de «hay datos» y su
borrado completo, grupos incluidos.

## Lo medido (2026-10-06)

- **Lectura del árbol en `123f59cd7`**: tras el aviso, el Welcome trataba los grupos conservados como de otra persona en
  seis sitios, no en uno (el alert y sus limpiezas, el portal del relanzamiento, la pregunta del teléfono con mount
  neutro, el borrado de la puerta privada y el término de datos de las puertas de organizador e invitación), y los dos
  borrados del teléfono llevaban al mismo handover.
- **Simulador** (`WelcomeLateNoticeKeptGroupsUITests`): con solo grupos en el teléfono y sin la marca sale el alert
  —la mitad del bug, reproducida—; con la marca, el onboarding abre sin él. El aviso tardío en sí necesita iCloud real.

## Arreglo

- `LateNoticeKeptGroupsMark`: la escribe el borrado del aviso cuando conserva los grupos, atada a la sesión de Grupos
  (solo la invalida otra cuenta abierta). Muere al completarse el onboarding, con el borrado del dominio de Grupos y con
  el cierre de sesión.
- `WelcomeKeptGroupsLogic`: con la marca, el Welcome solo cuenta lo personal, «Es mi primera vez» no retira a la
  persona anterior y ningún borrado del Welcome purga los grupos (`.importedRows` en la puerta de iCloud; los dos del
  teléfono sin purga ni reseteo de preferencias, con la convergencia de lo puenteado).
- Sin la marca, todo exactamente igual.

## Lo que queda fuera (con motivo)

- Las puertas de «Vengo por un grupo» con el espejo puesto (lo normal tras el aviso) siguen devolviendo al neutro: no
  por los grupos sino por el espejo. Esa vuelta es un cierre de sesión que sube los grupos y los recupera al volver a
  entrar.
- El guard cross-cuenta de «Ya tengo una cuenta» en la nube sigue contando los grupos conservados.
- Si la persona entrega el teléfono a otra a mitad del onboarding, la otra hereda los grupos (lo acepta la decisión A).
- Hermano previo, sin tocar: `performLocalWipeForRemoteSync` conserva los grupos y vuelve al Welcome sin marca.

## Guion de QA en iPhone (opcional; no bloquea)

Hace falta un Apple ID con datos viejos de Yala en iCloud y estar en un grupo (o unirse con una invitación).

1. Borra Yala e instálala. Activa el modo avión.
2. «Empezar» → «Es mi primera vez» → privado → «Seguir así». Termina el onboarding.
3. Quita el modo avión y únete al grupo. Cierra Yala del todo y ábrela.
4. En «Encontramos datos tuyos en iCloud» toca «Empezar de cero» → «Borrar todos los datos».
5. En el primer paso del onboarding toca «Cancelar». Debe salir la bienvenida.
6. «Empezar» → «Es mi primera vez» → privado.
7. **Comprueba**: va directo al onboarding, sin «Empezar desde cero / Detectamos datos previos». Termínalo y abre
   Grupos: el grupo sigue ahí con sus saldos, sin pedirte iniciar sesión.
