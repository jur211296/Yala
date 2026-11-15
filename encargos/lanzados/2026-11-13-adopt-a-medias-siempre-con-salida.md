Yala
# Entrar con la cuenta a medias: siempre hay salida, se retoma o se deshace, y la barra avanza en pasos reales
---
card: tablero-cerrar-yala-en-pleno-conectando-con-tu-c-gd78
toca: Yala/Services/CloudSync/CloudMigrationController.swift, Yala/Services/CloudSync/MigrationRunner.swift, Yala/Services/CloudSync/MigrationStateMachine.swift, Yala/Services/CloudSync/CloudSessionSignOut.swift, Yala/Services/CloudSync/CloudSyncEngine.swift, Yala/App/Logic/MigrationImportWaitLogic.swift, Yala/App/AppBootstrapper.swift, Yala/App/ContentView.swift, Yala/App/Views/Groups/FullModeActivationView.swift, Yala/App/Views/Settings/StorageSettingsView.swift, Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift, Yala/Utils/L10n.swift, Yala/Resources/es-419.lproj/Localizable.strings, Yala/Resources/es.lproj/Localizable.strings, Yala/Resources/es-AR.lproj/Localizable.strings, Yala/Resources/es-ES.lproj/Localizable.strings, Yala/Resources/pt-BR.lproj/Localizable.strings, Yala/Resources/pt-PT.lproj/Localizable.strings, Yala/Resources/pt.lproj/Localizable.strings, YalaTests/AdoptHalfwayExit/, tickets/backlog/adopt-halfway-always-has-an-exit.md, tickets/done/adopt-halfway-always-has-an-exit.md, docs/qa/adopt-halfway-always-has-an-exit/
esfuerzo: high
cierre: cierra-sola
---

Lote de 4 bugs muy altos de la entrada a una cuenta existente, medidos el 13-nov en el iPhone 14 (Yala Dev, staging, cuenta con grupos). Rama base: 2.3; la 2.2 está cerrada. Jürgen pide que se prueben de punta a punta en el iPhone 14, sin las limitaciones del simulador.

Cards del lote (lee en cada una el contexto, el siguiente paso, el «hecha cuando» y los comentarios; los logs están en el scratchpad de la sesión vuelve-bienvenida-tras-cuenta-lista):
1. `tablero-cerrar-yala-en-pleno-conectando-con-tu-c-gd78` · Cerrar Yala en pleno «Conectando con tu cuenta» la deja a medias en iCloud y sin salida.
2. `tablero-tras-un-traspaso-a-medias-entrar-con-goo-285z` · Tras un traspaso a medias, entrar con Google se queda para siempre en «Ahora mismo no podemos preparar este dispositivo».
3. `tablero-tras-reabre-yala-en-una-entrada-con-goog-rfzc` · Tras «reabre Yala», la cuenta no baja nada y «Descargando tus datos…» no termina (y Ajustes dice «Todo sincronizado»).
4. `tablero-conectando-con-tu-cuenta-avanza-a-saltos-jxbp` · «Conectando con tu cuenta» avanza a saltos (0, 60, lista): hitos más pequeños ligados a trabajo real, nunca simulados.

Las tres primeras son el mismo problema de fondo: un traspaso que queda a medias, entre el teléfono, iCloud y la cuenta, no tiene salida. Primero mide dónde vive ese estado a medias (journal, iCloud, claim de la cuenta, staging) y si la cuenta de staging conserva sus filas. Después arréglalo de raíz.

Qué se pide: cerrar Yala en cualquier punto del adopt y reabrirla retoma o deshace el paso, sin subir datos de la cuenta a iCloud. Un traspaso a medias de otro intento ya no bloquea la entrada con Google. Después de reabrir, la cuenta baja sus registros y grupos, o la pantalla dice qué la frena y qué hacer. La persona siempre tiene una salida que funciona: seguir, cancelar o cerrar sesión. Ningún dato de la cuenta se pierde. La barra de «Conectando» avanza en pasos pequeños y reales.

No dupliques trabajo: la vuelta a la bienvenida después de «Ya está tu cuenta» la está arreglando otra sesión (vuelve-bienvenida-tras-cuenta-lista), y «Usar otra cuenta» está en el PR abierto de otra-cuenta-google-apple. Rebasa sobre 2.3 antes de empezar y antes del PR.

**Pruebas:** de punta a punta en el iPhone 14 por DeviceMCP, conectado a la Mini, con la cuenta de staging que tiene grupos, incluido matar la app en cada fase del adopt. Si hace falta que Jürgen toque el teléfono, inicie sesión o borre datos de iCloud, pídeselo según el modo. Puedes usar un segundo simulador si otra sesión ocupa el primero. Agrega tests que caigan sin el arreglo. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance. Deja la evidencia (video y capturas del iPhone) en `docs/qa/adopt-halfway-always-has-an-exit/`.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR. Crea el ticket en `tickets/backlog/` con el nombre de `toca:`.

**Entrega:** un PR contra 2.3, mergeado si CI pasa, el ticket en done y las 4 cards en QA con lo que probaste. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Si una decisión cambia lo que ve la persona de forma importante (por ejemplo, borrar el traspaso a medias en vez de terminarlo), es vital: pregúntala según el modo. Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones

> Modo semi: las menores y reversibles las toma Frank y se discuten en el PR; una vital se pregunta.

**Hechos medidos antes de decidir (13-nov, 13:50 Lima).**
- Staging conserva la cuenta: 8 movimientos vivos, 6 cuentas y 13 categorías; `profiles` sin traspaso en curso.
- El iPhone 14 está limpio: solo Yala Dev instalada y su App Group vacío.
- Por lectura del código (se confirma en el iPhone): `onAdoptStarted` retira el montaje neutro y marca el onboarding
  ANTES de conducir el traspaso. Si Yala se cierra antes de escribir el par «nube + espejo apagado», el arranque
  siguiente monta el espejo de iCloud, exporta lo que haya en el almacén y deja a la persona en la app.
- La card 2 no tiene un estado a medias en el servidor: el journal vive en el App Group, que en el iPhone de pruebas
  sobrevivía a desinstalar Yala Dev porque Yala de producción declara el mismo App Group.
- La barra solo tiene tres valores: 0 % antes de arrancar la máquina, 60 % fijo durante TODO el efecto del adopt y
  «lista».

**D1 · Qué hace el arranque tras cerrar Yala a mitad del traspaso** → sigue montando neutro (sin espejo) hasta que el
par se escriba o el traspaso salga. Lo sostiene una marca durable propia, escrita al empezar y retirada al terminar o
salir.
Por qué: es lo único que impide subir a iCloud los datos de la cuenta. Alternativa descartada: no marcar el onboarding
hasta el final, que reabre el riesgo de sembrar categorías encima de una cuenta existente.

**D2 · Qué ve la persona al reabrir** → la misma pantalla «Conectando con tu cuenta», que retoma el traspaso y ofrece
«Cancelar». Cancelar deshace lo que el traspaso marcó y vuelve a la bienvenida.
Por qué: «retoma o deshace» con una salida visible. Alternativa descartada: la app con la tarjeta de Almacenamiento,
que es donde hoy se queda girando sin salida.

**D3 · Traspaso a medias de otro intento al volver a entrar con Google** → **opción A de Jürgen (13-nov, por su
bot)**: se deshace ese paso a medias y se entra limpio. Lo del iCloud se queda en iCloud (decisión del 10-nov) y lo de
la cuenta vive en el servidor (medido). La pantalla ofrece cancelar ese traspaso, con confirmación, y sigue sola.
Descartadas: B (terminarlo con lo que hay en el teléfono, que mezcla el iCloud del aparato con la cuenta) y C.

**D4 · La barra** → hitos por cada paso real del efecto del adopt (comprobar la cuenta, comparar con el servidor,
probar que los datos son de la cuenta, preparar el teléfono) en vez del 60 % fijo. Ninguno simulado.
Por qué: lo pide la card. Detalle de los pasos tras medir cuánto dura cada uno en el iPhone.

**D5 · Card 3 (no baja nada tras reabrir)** → se decide tras medir en el iPhone si el motor corre y por qué no baja.
Si algo lo frena, la pantalla lo dice con su salida.
