# Entrar con Google o Apple teniendo tu propio iCloud privado — espera decisión

> **Resuelta el 2026-11-10.** Jürgen eligió la opción B (clave t1503u-icloud): se abre la nube con la cuenta que
> entra y los datos de iCloud se quedan en iCloud sin tocar, por la vuelta al neutro de la puerta del Welcome. Se
> construyó en la sesión del 10-nov (`ICloudAsideEntryLogic`, propósito `.enterCloudAccount`); la decisión está en
> `docs/DECISIONS.md` (2026-11-10). Esta acta queda como registro de lo medido.

Sesión nocturna del 2026-11-09. Card del tablero: «Entrar con Google bloqueado por tus propios datos de
iCloud privado («datos de otra cuenta»)». Decisión de partida de Jürgen (9-nov, clave `t1488u`): opción C,
preguntarle al dueño si pasa sus datos de iCloud a la nube o entra dejándolos aparte, sin romper la
protección del teléfono ajeno.

**No se tocó código.** El encargo dice que, si no hay forma segura de distinguir «datos propios» de
«datos ajenos», eso es vital y no se inventa. Lo medido abajo dice que no la hay para el caso general, y
que las dos salidas de la opción C chocan con decisiones anteriores o piden un mecanismo que hoy no existe.

## Lo medido (árbol `origin/2.2` en `a43ae15ef`)

1. **El guard no tiene con qué distinguir.** `CrossAccountEntryGuardLogic.decide` recibe tres booleanos:
   hay datos, hay claim de esta cuenta, hay restauración en curso. El claim vive en `UserDefaults`
   (`CloudClaimActionStore`) y muere al reinstalar o al volver al inicio, que es justo el escenario.
   Los datos del iCloud privado del teléfono son siempre los del Apple ID que tiene ese teléfono; nada en
   el teléfono une ese Apple ID con la cuenta de Google o Apple que entra a la nube.

2. **La única prueba fiable cubre un subconjunto.** Hay dos registros en el iCloud key-value del Apple ID
   que solo pudo escribir su dueño y que nombran una cuenta de la nube:
   - el faro del modo nube (`CloudBeacon`, hash del `sub`), que **se borra al volver a iCloud**
     (`MigrationWorkExecutor.swift:1353`, `CloudIdentityDiscovery.swift:185`);
   - la asociación de la cuenta de Grupos (`GroupsAccountAssociation`, `sub` en claro), que **se borra al
     desasociar** (`clear`, línea 263).
   Si uno de los dos coincide con la cuenta que entra, es el mismo dueño, demostrado. Si no hay ninguno
   —quien nunca usó Grupos ni la nube desde ese iCloud, o quien volvió de la nube a iCloud— no hay prueba,
   y un teléfono prestado con la sesión de iCloud del dueño se ve exactamente igual.

3. **La opción (a), «pasar mis datos de iCloud a la nube», es una fusión.** El guard solo corre cuando la
   cuenta ya existe y es completa (`adoptAsComplete`, `WelcomeCloudSignInView.swift:1283`). Esa cuenta ya
   tiene sus propias finanzas. El adopt sube las filas locales sin dueño a la cuenta que entra (cabecera de
   `CrossAccountEntryGuardLogic`), así que (a) mezclaría dos conjuntos de datos personales: cuentas y
   categorías repetidas, saldos sumados. La tabla de identidad lo descarta hoy por escrito: «Juntar dos
   datasets personales sería una fusión, que el ADR descartó» (`CloudIdentityRoutingLogic.swift:129`).

4. **La opción (b), «entrar dejando iCloud aparte», no tiene mecanismo.** El modo nube y el modo iCloud
   usan **el mismo archivo** de store (`SwiftDataConfiguration`, caso `.cloudMirrorOff`). Para entrar en la
   nube sin los datos de iCloud hay que vaciar ese archivo sin que el borrado viaje a iCloud: apagar el
   espejo, relanzar, borrar el archivo local y recién entonces adoptar. Lo más parecido, la «sesión
   secundaria» de M1, se retiró el 2026-09-09 (`SwiftDataConfiguration.swift:897`). Es un flujo nuevo de
   sincronización, de los que piden review adversarial, y un error ahí borra el iCloud del dueño.

## Qué hace falta que decida Jürgen

**Pregunta 1 — el criterio.** Sin prueba no se puede afirmar «son tuyos». ¿Qué hacemos?

- **A · Solo con prueba (recomendada).** Si el faro o la asociación de Grupos del iCloud coinciden con la
  cuenta que entra, se pregunta (a)/(b). Si no, sigue bloqueado, pero con un texto que no miente: «Este
  teléfono tiene datos de iCloud que no podemos unir a esta cuenta», con la salida de entrar dejándolos
  aparte. Tu caso del iPhone 14 entra solo si ese iCloud tuvo asociada esa cuenta de Google.
- **B · Confirmar con el código del teléfono.** Sin prueba, se pide Face ID o el código del iPhone antes de
  ofrecer (a). Demuestra que quien entra maneja el teléfono, no que es dueño del iCloud: un prestado
  desbloqueado pasa.
- **C · Ofrecer siempre solo (b).** Sin prueba, nunca se pasa nada; solo se entra dejando iCloud aparte, que
  no mueve datos de nadie.

**Pregunta 2 — qué es (a).** La cuenta de la nube ya tiene datos. ¿«Pasar» significa **sumar** los de
iCloud a los de la nube (fusión, lo que el ADR descartó), o **reemplazar** lo de la nube por lo de iCloud?
Recomendado: no ofrecer (a) en esta versión y dejar solo (b); la fusión es un proyecto propio.

**Pregunta 3 — alcance de (b).** Construir «entrar dejando iCloud aparte» es un flujo de sincronización
nuevo (espejo apagado + relanzar + vaciar el archivo local + adoptar). ¿Entra en 2.2 o pasa a 2.3?

## Para retomar

- Rama `encargo/2026-11-09-entrar-con-google-icloud-privado-preguntar`, sin cambios de código.
- Con la respuesta, los ficheros son: `CrossAccountEntryGuardLogic.swift` (nuevo veredicto con prueba),
  `WelcomeCloudSignInView.swift` (pantalla de elección), `MigrationRunner`/`SwiftDataConfiguration` si
  (b) entra, `Localizable.xcstrings`, y tests de los tres casos en `CrossAccountEntryGuardLogicTests`.
- Otra sesión (`encargo/2026-11-05-registrar-decisiones-2026-11-05`) declaró tocar los mismos ficheros de
  onboarding y CloudSync: mirar si sigue viva antes de retomar.
