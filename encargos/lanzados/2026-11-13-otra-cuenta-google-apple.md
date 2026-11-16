Yala
# Entrar con otra cuenta de Google o Apple funciona al primer intento, sin cerrar Yala ni quedar en bucle
---
card: tablero-entrar-con-otra-cuenta-de-google-o-apple-38q3
toca: Yala/App/Logic/CloudWelcomeSignInFlow.swift, Yala/App/Logic/WelcomeAccountChoiceLogic.swift, Yala/App/Views/Onboarding/WelcomeCloudSignInView.swift, Yala/App/Views/Shared/GoogleSignInButton.swift, Yala/Services/CloudSync/CloudAuthService.swift, YalaTests/WelcomeOtherAccount/, tickets/backlog/other-account-sign-in-bounces-to-welcome.md, tickets/done/other-account-sign-in-bounces-to-welcome.md
esfuerzo: high
cierre: cierra-sola
---

Fallos reportados por Jürgen el 13-nov en el iPhone 14 con Yala Dev 2.3. Antes venían dentro de los ajustes visuales del Welcome; se separaron para priorizarlos como bug. Rama base: 2.3; la 2.2 está cerrada. Crea el ticket en `tickets/backlog/` con el nombre de `toca:`.

1. Google: al elegir «Usar otra cuenta», la app rebota a la bienvenida, y recién al tocar de nuevo «Entrar con Google» aparece el sign in. Tiene que abrir el selector de cuentas de Google en el primer intento.
2. Google: al entrar, la app le pide a Jürgen cerrar Yala por completo y, al reabrirla, vuelve a pedir el sign in que ya hizo. Encuentra la causa (sesión no guardada, redirect, cambio de modo u otra) y corrígela: entrar con Google una vez basta y la sesión queda guardada.
3. Apple: abre directo el sign in con la cuenta del dispositivo y no deja usar otra. «Usar otra cuenta» rebota a la bienvenida y queda en bucle. Investiga qué permite Apple (Sign in with Apple usa el Apple ID del dispositivo) y deja una salida clara, sin bucle. Si la única solución real necesita una decisión de producto, plantéala con opciones y recomendación según el modo de la sesión, y termina lo demás.

La sesión del bloqueo de 15 minutos, ya mergeada o por mergear, tocó el adopt. Rebasa sobre 2.3 antes de empezar.

**Pruebas:** reproduce en el iPhone 14 por DeviceMCP, conectado a la Mini, con la cuenta de staging que tiene grupos. Si hace falta que Jürgen toque el teléfono o inicie sesión, pídeselo según el modo. Puedes usar un segundo simulador si otra sesión ocupa el primero. Agrega tests que caigan sin el arreglo. Corre solo las pruebas de interfaz que toca el cambio y la suite completa una vez al final. Si hay dos timeouts seguidos, la prueba es inestable: anótalo y sigue. Tope de 30 minutos en pruebas de interfaz, y nunca más de 3 minutos sin escribir avance.

**Archivos:** puede correr en paralelo con otra sesión de Yala en la otra máquina, así que te quedas dentro de `toca:`. Si de verdad hace falta tocar algo fuera, que sea un cambio mínimo: lo anotas en «Decidido sin consultar» y rebasas sobre 2.3 antes del PR.

**Entrega:** un PR contra 2.3, mergeado si CI pasa, y el ticket en done. Commits y PR sin firma de IA. Lo menor y reversible lo decides y lo anotas en «Decidido sin consultar». Si el trabajo queda completo y el modo lo permite, cierra con `/cerrar-total`.

## Paso 0 — decisiones

*Modo semi. Jürgen está en el chat: lo que es suyo se le pregunta; lo menor se resuelve aquí.*

1. **Google · «Usar otra cuenta»** → suelta la sesión y abre la hoja de Google en el acto (selector de cuentas), sin pasar
   por la vitrina. Cancelar esa hoja vuelve a la vitrina (la sesión de antes ya se soltó). *Resuelto aquí.*
2. **Apple · «Usar otra cuenta»** → con el inicio de sesión web de Apple encendido (decisión A del 6-nov, hoy en
   staging) la salida pasa a «Otra cuenta de Apple» y abre Apple por la web. Sin él (producción hoy) no hay otro Apple ID
   posible: la salida de texto se sustituye por la nota de siempre («Con Apple, Yala usa siempre la cuenta de este
   dispositivo. Para usar otra, elige Google.») y «Entrar con Google». Sin bucle en los dos casos. Textos reutilizados,
   ya traducidos en los 16 idiomas. *Resuelto aquí: extiende a la bienvenida una decisión ya tomada.*
3. **La flecha «Volver»** conserva lo de hoy: suelta la sesión y vuelve a la vitrina. *Resuelto aquí.*
4. **Fallo 2 · segundo inicio de sesión tras reabrir.** Causa leída en el código: teléfono con datos del iCloud privado →
   opción B del 10-nov (dejar iCloud aparte) → el cierre privado suelta y purga la sesión de la nube antes del vaciado
   (regla del 26-sep) → reabrir es obligatorio con el espejo montado → al volver no hay sesión. **Pendiente de Jürgen**
   (pidió conversarlo): A vaciar antes de firmar, B conservar la sesión a través del vaciado, C solo avisar.
