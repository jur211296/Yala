---
esfuerzo: medium
---
# Textos de la app dicen que los datos nunca salen del dispositivo

**Card:** tablero-textos-de-la-app-dicen-que-los-datos-nun-q54n · **Prioridad:** según la card · **Versión:** 2.1 · **Ticket:** `tickets/backlog/in-app-privacy-copy-says-data-never-leaves-the-device.md` (del PR #443, checklist de envío)

## Qué se pide
1. Lee el ticket y localiza en la app cada texto que diga que los datos nunca salen del teléfono, que no hay servidores o que solo viajan por iCloud (Localizable.strings en todos los idiomas, onboarding, Ajustes › Privacidad, «Dónde viven tus datos», paywall, ayudas).
2. Corrígelos para que digan la verdad de 2.1 según el modo: en privado, iCloud; en Modo Nube y Grupos, la nube de Yala (Supabase); la IA pasa por nuestro gateway hacia OpenAI. Usa el mismo tono y las claves existentes cuando se pueda; no inventes promesas legales (eso es de la política, card bis6 de Lola).
3. Traducción en los 16 .lproj con la receta de traducción del repo; nada de claves crudas.
4. Un test (source-scan o de cadenas) que falle si vuelve una frase prohibida («nunca sale», «sin servidores», «no servers»…).
5. Capturas antes y después de las 2 o 3 pantallas más visibles. Si una frase exige decidir producto, déjala anotada para Jürgen y no la cambies.

## Reglas de siempre
- Arranca sobre `origin/2.1` y trabaja sin esperar a nadie. Justo antes de abrir el PR: `git fetch` y rebase sobre `origin/2.1`, resolviendo ahí los conflictos (strict=false); si el rebase toca lo tuyo, recompila y repite los tests afectados con un solo simulador.
- Tickets nuevos al tablero (antes del `/cerrar-total`): por cada ticket nuevo en `tickets/`, mira con `tablero listar --proyecto Yala --todas` que no tenga card y, si no, `tablero crear --proyecto Yala --agente frank --asignado frank --estado backlog --prioridad <la del ticket> --titulo "<título claro en español neutro>" --contexto "<una línea>" --enlace "Ticket|https://github.com/jur211296/Yala/blob/2.1/tickets/backlog/<slug>.md" --enlace "PR #<N>|<url>"`. SIN --fecha (opcional desde el ADR-068; sin fecha de relleno). Lista esas cards en el aviso de cierre.
- Sin deploy, sin secretos y sin decisiones de UI de Jürgen: si algo lo pide, para y anótalo en el cierre.
- Cierre: `/cerrar-total` autónomo (PR a 2.1 en auto-merge, limpieza de simulador, worktree y DerivedData).

## Carga de la Mini (OBLIGATORIO)
- Todo xcodebuild va con `nice -n 10 xcodebuild -jobs 2 ...`.
- Nunca dos builds o tests a la vez (ni build + tests); pipeline serie: build → 1 simulador → tests → erase.
- Antes de cada build espera a que la carga baje de 8: `while [ $(sysctl -n vm.loadavg | awk '{print int($2)}') -ge 8 ]; do sleep 30; done`.
- Nunca pases xcodebuild por `| head` (mata el build): escribe a un log y lee el log.
- Los `-only-testing:` van en un array de zsh, no en un string.

## Paso 0

Medido sobre `origin/2.1` 43a278e38. El ticket vive en el PR #443 (aún abierto), no en 2.1.

**Inventario (es-419; las 16 `.lproj` tienen las mismas claves):**

| Clave | Dónde se ve | Hoy | Problema |
|---|---|---|---|
| `profile.privacyTitle` / `profile.privacyDesc` | Perfil › Datos personales | «nunca salen de tu dispositivo», «únicamente en tu dispositivo», la IA «nunca» ve gastos individuales | Falso con cuenta en la nube y Grupos; el escaneo manda el recibo |
| `onboarding.privacyLocalShort` / `onboarding.privacyIcloudShort` | Onboarding, último paso (rejilla 2×2) | «Datos en tu dispositivo» / «Solo tú accedes» | Falso con cuenta en la nube (el equipo puede verlos, lo dice el consentimiento) |
| `welcome.hero.cards.icloud.body` | Bienvenida, carrusel | «Sin servidores» | Grupos e IA pasan por nuestros servidores |
| `welcome.hero.trust` | Bienvenida, pie del botón «Empezar» | «100% privado · Tu info siempre contigo» | Falso con cuenta en la nube; la otra mitad («stays with you», «bleiben bei Ihnen») insinúa lo mismo en 7 idiomas |
| `whatsNew.v20.groups.description` | Novedades 2.0 | Grupos «por tu iCloud, sin servidores nuestros» | Grupos ya va al backend |
| `common.dataPrivacy`, `onboarding.privacyLocal`, `onboarding.privacyIcloud` | Sin uso en código | Mismas frases | Se corrigen igual para que no vuelvan |

**Decisiones (auto-contestadas, MODO AUTÓNOMO):**
1. **Texto neutro, verdadero en todos los modos, sin tocar Swift.** Tampoco «tú eliges»: la tarjeta de la nube depende de un interruptor remoto y de App Attest (`WelcomeAccountChoiceLogic.visibleNewOptions`), así que no todo el mundo puede elegir. Hacerlo por modo exige leer `CloudSyncFlags.storageMode` en el onboarding, y en la activación desde Grupos el modo se fija en `beforeCommit`, después de pintar la rejilla: el texto por modo podría salir equivocado. Neutro no puede mentir.
2. **Mismas claves**, sin claves nuevas: se cambia el valor en las 16 `.lproj`; `es` = copia de `es-419` y `pt` = copia de `pt-BR` (alias byte a byte). es-AR con voseo, es-ES/pt-PT/en-GB con su variante.
3. Vocabulario BRAND-VOICE §7: «tu iCloud privado» / «tu cuenta en la nube», sin «sesión». La IA: «pasa por nuestro servidor hasta OpenAI» (medido: `ProxyClientFactory` apunta al gateway, `gateway/src/ai/providers/openai.ts`).
4. **No se tocan** (verdad en su contexto): `icloud.privacyNote`, `storage.status.icloudBody`, `welcome.new.privateBody` (solo se ven en modo iCloud o al elegirlo), `groups.consent.point2` (el correo de verdad no sale).
5. **Se anotan para Jürgen sin cambiar** (promesas sobre la IA, son de la política de Lola, card bis6): la tarjeta «IA segura» (`onboarding.privacyNoSharingShort`), `onboarding.privacyNoSharing` «La IA no comparte ni almacena datos sensibles» e `insights.activateAIDisclaimer` «solo datos resumidos… nunca tus transacciones». Fuera de la app: `Web/src/i18n/translations.ts` faq1A «Yala has no servers».
6. Test: source-scan en YalaTests sobre las 16 `Localizable.strings` con una lista de frases prohibidas por idioma.
7. **El lema de la bienvenida** pasa a «Sin rastreo ni anuncios», el valor que ya existe en cada idioma (`onboarding.privacyNoTrackingShort`). Medido: `NSPrivacyTracking` es `false` y no hay SDK de anuncios.
8. Capturas: Bienvenida (carrusel), onboarding final y Perfil › Datos personales, en Yala Dev sobre iPhone 17 Pro.
