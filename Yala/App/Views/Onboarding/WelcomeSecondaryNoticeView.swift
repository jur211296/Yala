//
//  WelcomeSecondaryNoticeView.swift
//  Yala
//
//  **La rama privada deja de callarse en sesión secundaria.** «Es mi primera vez → privacidad total»
//  llevaba a la visita al onboarding sin decirle una palabra de que estaba en el móvil de otra persona,
//  mientras la rama de al lado —«Vengo por un grupo»— sí se lo decía y con copy propio. La app se
//  contradecía según por dónde entraras.
//
//  **Informa, NO bloquea**, y esa es la diferencia entera con `WelcomeGroupsGateView`, de quien toma el
//  molde visual. Allí la sesión secundaria es una de tres razones para NO seguir —el alta escribiría seis
//  preferencias en el `UserDefaults` del dueño—; aquí no queda ninguna escritura que impedir. Es la
//  decisión del owner del 2026-09-02 para la familia entera —«encauzar, no bloquear»— aplicada a la letra,
//  y la del 2026-09-06 para esta rama en concreto.
//
//  **Ese «no queda ninguna» hubo que ganárselo, y por poco no es verdad.** El dominio de preferencias por
//  sesión (2026-08-26) y `258a90c3` cerraron casi todas, pero la review adversarial de este mismo commit
//  encontró una viva **a un tap de esta pantalla**: `OnboardingResetHelper.clearResidualPreferencesForFreshStart`
//  —que `startFreshPrivateOnboarding` llama justo detrás del CTA— borraba `userName` y `defaultCurrencyCode`
//  del `UserDefaults.standard` del DUEÑO. Su mitad iKV sí estaba protegida; la local se había quedado en el
//  store crudo. Se cerró con la puerta de dominio por sesión porque sin eso **este copy sería falso**: la
//  pantalla promete que lo tuyo no se mezcla con lo suyo y un tap después le borraba el nombre. **Esa
//  puerta se retiró el 2026-09-12**, y con ella el riesgo: en el mismo cambio se apagó el encendido
//  compilado de la entrada a sesión secundaria, así que ya no hay visita que pueda llegar hasta aquí. Lo que
//  queda abierto en esta frontera —el prellenado que LEE del dueño, y el centinela de notificaciones— no
//  contradice el copy y vive en `secondary-onboarding-still-crosses-owner-domain`.
//
//  **Por qué el copy es propio y no el de la rama de Grupos.** El hecho que nombran es el mismo («estás de
//  visita») pero la salida es opuesta: allí se acaba el camino y se le pide volver desde su dispositivo,
//  aquí se sigue. Un copy compartido obligaría a que las dos pantallas evolucionaran juntas para siempre,
//  y la de Grupos tiene que sonar a «no puedes» justo donde ésta tiene que sonar a «puedes, y esto es lo
//  que pasa». Es el mismo criterio con el que la rama organizador dejó de pedir prestado el copy del guard
//  de datos ajenos (ver `welcome-copy-blames-owner`).
//
//  **El cuerpo dice «solo en este dispositivo» porque está MEDIDO, no por prudencia.** El store de la
//  sesión secundaria se monta con `cloudKitDatabase: .none` (`SwiftDataConfiguration.swift:1188`), así que
//  no se espeja a ninguna CloudKit: ni a la del dueño ni a la de la visita. Eso importa aquí más que en
//  ninguna otra pantalla, porque la card que la visita acaba de tocar promete lo contrario —«se sincronizan
//  por tu iCloud privado» (`welcome.new.privateBody`)— y en visita esa promesa no se cumple. **Esa card
//  SÍ se lee**: el percent remoto de la elección nube está EN 100 en producción (medido el 2026-09-09),
//  así que el sub-chooser se muestra y `handleNewBranch` ya no hace bypass. Aquí ponía que «casi nunca se
//  lee» porque en prod el sub-chooser no salía, y con eso se aplazaba corregirla; corregirla sigue siendo
//  de su propio ticket, pero ya no es un caso raro. Esta pantalla dice el hecho verdadero en el sitio por
//  el que sí pasa todo el mundo.
//
//  Es un STEP del `WelcomeFlowContainer` por las mismas tres razones que `.groupsGate` y `.mirrorRelaunch`:
//  `leaveWelcome` es el único punto de salida del cover, una presentación nueva del anchor de `ContentView`
//  entraría en la matriz de readiness (regla 3 de Presentaciones), y un step que se queda DENTRO ya lo
//  cubre `showWelcomeFlow`. Y **no puede ser un `.alert(`**: dos source-scans independientes lo prohíben en
//  el container (`WelcomeHeroReentryTests`, `GroupsOrganizerBranchTests`).
//

import SwiftUI

/// Aviso de sesión secundaria en la rama privada del Welcome. No comprueba nada: quien la pinta ya
/// decidió (`WelcomeFlowContainer.handleNewOption`), igual que `.mirrorRelaunch` no re-decide el mount.
struct WelcomeSecondaryNoticeView: View {

    /// Seguir al onboarding privado. El container lo cablea al portal `leaveWelcome(to: .privateOnboarding)`
    /// — esta vista no sale del cover por su cuenta, que es la invariante que el source-scan del portal
    /// (`NeutralMountRelaunchZeroTests.everyWelcomeExit_goesThroughThePortal`) comprueba línea a línea.
    var onContinue: () -> Void
    /// Vuelta al step del que vino. **No es un camino muerto**: la pantalla informa y las dos salidas
    /// —seguir y volver— llevan a algún sitio.
    var onBack: () -> Void

    var body: some View {
        WelcomeFlowScreen { logoTopSpacing in
            VStack(spacing: 0) {
                Spacer(minLength: logoTopSpacing)

                Image("YalaLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 128)
                    .colorMultiply(.white)
                    .accessibilityHidden(true)

                Spacer(minLength: DS.Spacing.xl)

                VStack(spacing: DS.Spacing.lg) {
                    // El candado sobre el teléfono dice las dos mitades del cuerpo a la vez: cerrado
                    // (nadie más lo ve) y en ESTE dispositivo (no viaja a ninguna nube).
                    Image(systemName: "lock.iphone")
                        .font(.system(size: 44)) // A11Y-DT: icono decorativo hero, tamaño fijo (patrón del flow)
                        .foregroundStyle(.white.opacity(0.8))
                        .accessibilityHidden(true)

                    // **Los dos identifiers son HERMANOS y no anidan, y eso no es estético.** Un id puesto
                    // a un contenedor PISA el de sus hijos en el árbol de accesibilidad
                    // (`.claude/rules/testing.md`): con el de la pantalla colgado del VStack de fuera, el
                    // del CTA desaparecía del árbol y el XCUITest lo buscaba en vano — medido, no
                    // supuesto. La rama de Grupos no lo sufre porque su `blockedContent` marca solo el
                    // contenedor y su botón no lleva id propio; aquí hacen falta los dos, porque este CTA
                    // sí se tapea (es la mitad de «informa y sigue»).
                    VStack(spacing: DS.Spacing.sm) {
                        Text(L10n.Welcome.Private.secondaryTitle)
                            .font(DS.Typography.title2)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(L10n.Welcome.Private.secondaryBody)
                            .font(DS.Typography.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .accessibilityIdentifier("welcome_private_secondary_notice")

                    YalaPrimaryButton(L10n.Welcome.Private.secondaryCta) {
                        onContinue()
                    }
                    .padding(.horizontal, DS.Spacing.xl)
                    .accessibilityIdentifier("welcome_private_secondary_continue")
                }

                Spacer(minLength: DS.Spacing.xl)
            }
        }
        .welcomeBackButton(tint: .white, action: onBack)
    }
}
