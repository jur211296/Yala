# Si el borrado de iCloud falla a mitad, la puerta privada ya no dice que iCloud sigue intacto

## Contexto
Cola A autónoma (riesgo real, callejón wipe / puerta privada). Acaba de mergearse a 2.1 el PR #276 (`private-gate-remote-wipe-can-strand-its-arm`): el borrado de iCloud de «Es mi primera vez → privado» ya termina aunque la pantalla se cierre por debajo. En el review de ese PR se reabrió / anotó en este ticket un segundo síntoma en la misma mitad a medias.

Ticket: `tickets/backlog/private-gate-wipe-failure-copy-claims-icloud-is-intact.md` (medium, onboarding / modo-nube / l10n).

Síntoma de usuario: confirmo dos veces que quiero borrar mis datos de iCloud; algo falla a medias y la app dice «Tus datos siguen en iCloud, intactos». No es verdad: la zona ya se borró y lo del teléfono está a medio vaciar.

Medido: `performICloudCorpusWipe` borra primero la zona CloudKit y después las filas locales; un fallo a media lista devuelve `"localWipeFailed"` con la zona ya borrada. La fase `.wipeFailed` de `WelcomePrivateICloudGateView` enseña un copy único que afirma iCloud intacto. El copy correcto ya existe: `wipeDeviceFailedBody` («puede que parte de tus datos ya no esté…»). El motivo ya viaja distinguido (`"localWipeFailed"` vs zona / CKError); no hace falta señal nueva — llevarlo dentro de la fase.

Añadido 2026-09-27 (review #276): salir de `.wipeFailed` por `leaveGate` desarma con `clearICloudCorpusWipeArm()`, que también borra `icloudCorpusWipeZoneDone`. El aviso tardío ya usa `disarmFailedICloudCorpusWipe()` / `leaveICloudCorpusWipeHalfway`. En la puerta nadie recuerda que iCloud quedó vacío con lo del teléfono dentro. Inferido por lectura; cierra ese hueco en el mismo PR si cabe sin ensanchar el alcance.

Cola A = solo riesgo real (copy engañoso de seguridad / wipe a medias). Device-QA pendiente de otros tickets no frena este trabajo de código.

## Que se pide
1. Leer el ticket completo y el código citado (`performICloudCorpusWipe`, fase `.wipeFailed` de `WelcomePrivateICloudGateView`, claves l10n existentes).
2. Cuando el fallo es LOCAL tras haber borrado la zona → enseñar el copy que dice que parte de los datos ya no está (`wipeDeviceFailedBody` u homólogo ya traducido). Sin claves nuevas; reusar las 16 locales.
3. Cuando el fallo es de la ZONA (no se llegó a borrar nada) → seguir diciendo que iCloud está intacto.
4. Si el alcance lo permite sin segundo ticket: al salir de `.wipeFailed` no borrar a ciegas el testigo de «zona ya borrada»; alinear con `disarmFailedICloudCorpusWipe` / `leaveICloudCorpusWipeHalfway` para que un aviso tardío o un reintento no mienta.
5. Tests de comportamiento que fijen los dos copies según el motivo del fallo.
6. Mover el ticket en `tickets/` y actualizar `docs/TICKETS.md`. Hallazgos nuevos → ticket propio (`--solo-crear` / fichero) antes de cerrar.
7. PR a `2.1`, merge, `/cerrar-total`.

## MODO AUTÓNOMO HASTA TERMINAR
Implementa de punta a punta sin pedir permiso para seguir: plan → código → tests → gate → commit → board (`tickets/` + `docs/TICKETS.md`) → PR → merge a `2.1` → `/cerrar-total`. Queda suspendida la regla del repo «si tocas >3 ficheros / ¿Sigo? tras el plan, espera aprobación». No preguntes «¿le doy?» ni «¿sigo?» tras el plan.

Horario Lima diurno (06:00–21:00): AskUserQuestion solo para una decisión de producto/acceso realmente descubierta y no cubierta. Para techos, copy, Cancel, salidas de welcome/adopt y preferencias reversibles, elige la opción robusta / recommended y sigue. Si es demasiado grave para asumir (datos irreversibles en prod, secreto, device de Jürgen), aparca en ticket propio y sigue con lo demás.

## Que NO hay que tocar
- marketing/
- clinicas-dentales-bi / datos de salud
- prod Supabase; si hace falta nube, solo staging / local
- no ensanchar a rediseño UI (Cola B) ni a mediums diferidos post-2.1 (Cola C)
- no relanzar otros encargos en curso

## Como se sabe que esta bien
- Fallo local post-zona → copy honesto de «parte ya no está»; fallo de zona → copy de iCloud intacto.
- Sin claves l10n nuevas.
- Tests verdes que fijen ambos caminos.
- Ticket en qa o done según criterio del repo; índice `docs/TICKETS.md` al día.
- PR mergeado a `2.1` y `/cerrar-total` limpio.

## Paso 0

Decisiones tomadas por la sesión (modo autónomo, ninguna es de producto):

1. **El testigo que elige el copy es la marca durable «zona ya borrada»** (`isICloudCorpusWipeZoneDone()`), no el
   motivo `"localWipeFailed"`. Medido: un reintento desde el estado a medias que falla EN la zona devuelve un
   `CKError`, con la zona ya borrada por el intento anterior; decidir por el motivo le enseñaría «intactos». La marca
   la escribe quien cruza la zona y ya la usa `gateWipeSettles`.
2. **El dato viaja dentro de la fase**: `.wipeFailed(zoneGone: Bool)`, leído UNA vez tras `await performWipe()` y
   compartido con `gateWipeSettles`.
3. **Copy**: con la zona ida, `wipeDeviceFailedBody` (16 locales, sin claves nuevas); sin tocarla, `wipeFailedBody`.
   Título, botones, icono e identificador no cambian.
4. **Punto 4 (salir sin olvidar la zona) → ticket propio, no en este PR.** No cabe sin ensanchar: el remedio de
   «a medias» es el aviso tardío, que termina con `.handover` (purga de Grupos); en la puerta de la activación eso se
   lo ofrecería a quien activa para CONSERVAR sus grupos. Hace falta una política por consumidor y por salida.
5. Tests: función de selección de copy con test de comportamiento que compara TEXTOS + cableado de la fase.
