---
id: secondary-onboarding-still-crosses-owner-domain
status: discarded
priority: medium
area: modo-nube
created: 2026-09-07
updated: 2026-09-09
---

# El onboarding de la visita todavía cruza la frontera del dueño por dos sitios

Why: Discarded 2026-09-09. Superado por el ADR 2026-09-09 «Sesiones — dos ejes» (docs/DECISIONS.md): la sesión de visita (M1) se retira del modelo. No hay onboarding «de visita»: sin sesión privada propia solo hay sesión en la nube, y la privada del dueño ya no está montada (su cierre borra lo local).

## Qué queda abierto, medido (2026-09-07)

El ticket madre ([[secondary-visitor-writes-owner-domain]]) y el dominio de preferencias por sesión
(2026-08-26) cerraron casi todas las escrituras de la visita al dominio del dueño. La review
adversarial de `welcome-privacy-branch-has-no-secondary-door` barrió el camino entero del onboarding
privado en visita y encontró **tres** sitios vivos. **Uno se cerró allí** porque hacía falsa la
pantalla nueva; **estos dos quedan**, y los dos tienen contrapartida de producto, no solo de código.

### 1 · El prellenado LEE del dueño (`OnboardingView.swift:326`)

```swift
.task {
    let defaults = UserDefaults.standard
    if let name = OnboardingPrefillResolver.resolveUserName(
        prefilled: prefilledData,
        defaultsName: defaults.string(forKey: "userName")
    ) {
```

En visita, el onboarding se prellena con **el nombre y la divisa del dueño del teléfono**. No es una
escritura: es una fuga en sentido contrario —la visita ve datos de la otra persona— y encima le
propone empezar con ellos.

**Y arrastra un efecto que no es cosmético:** por la misma vía hereda `expensesOnlyMode`. Si el
dueño lo tiene puesto, la visita entra en modo solo-gastos sin haberlo elegido, y eso **apaga la
rama que crea la subcategoría de «Ajuste de saldo»** (`if !willSeedCategories && !expensesOnlyMode`)
— justo la que se acaba de encender para que su saldo inicial no se pierda.

**La contrapartida:** la divisa heredada probablemente **sí** se quiere (la del país del teléfono es
mejor apuesta que ninguna). El nombre y el modo, no. Así que no es un `SessionDefaults.current` a
secas: hay que decidir key por key.

### 2 · El centinela de notificaciones escribe en el dueño (`OnboardingView.swift:1982`)

```swift
private func createDefaultNotifications() {
    let defaults = UserDefaults.standard
    if defaults.bool(forKey: "notificationsSeeded") { return }
    defaults.set(true, forKey: "notificationsSeeded")
```

En visita, `completeOnboarding` marca `notificationsSeeded` en el `UserDefaults` **del dueño**. Dos
efectos, según quién llegue primero:

- Si el dueño **no** lo tenía puesto: la visita se lo pone, y el dueño se queda sin sus
  notificaciones por defecto para siempre (el centinela no se repone).
- Si el dueño **sí** lo tenía: la visita no recibe ninguna notificación, sin motivo.

**La contrapartida:** arreglarlo con `SessionDefaults.current` es una línea, pero **cambia
funcionalidad**: la visita pasaría a recibir notificaciones que hoy no recibe. Eso puede ser
justo lo que se quiere, o exactamente lo que no se quiere en un móvil prestado (las notificaciones
de la visita sonarían en el teléfono de otra persona). Es decisión, no limpieza.

## Lo que YA se cerró, para que nadie lo busque aquí

`OnboardingResetHelper.clearResidualPreferencesForFreshStart` borraba `userName` y
`defaultCurrencyCode` del `UserDefaults.standard` del dueño, y la visita entraba SIEMPRE por esa
rama (`hasExistingData` mide el store de la invitada, que nace vacío). Cerrado el 2026-09-07 con
`SessionDefaults.current`, en el commit de `welcome-privacy-branch-has-no-secondary-door`, porque
sin eso la pantalla nueva —«lo tuyo no se mezcla con lo suyo»— era falsa un tap después.

Su mitad iKV ya estaba protegida desde antes, con un comentario que nombraba la sesión secundaria:
**era un arreglo hecho a medias**, y ese es el patrón que conviene buscar en el resto de la
frontera — no «¿está protegido este fichero?», sino «¿están protegidas las dos mitades?».

## Criterio de hecho

- [ ] Decisión sobre el prellenado, **key por key**: divisa sí / nombre no / `expensesOnlyMode` no
      (es la propuesta; el owner decide).
- [ ] Decisión sobre las notificaciones de la visita en un móvil prestado.
- [ ] Un barrido que compruebe que no queda una tercera mitad abierta: por cada consumidor de
      `UserDefaults.standard` en el camino del onboarding, decir si es del dispositivo o de la persona.

## Relacionados

- [[secondary-visitor-writes-owner-domain]] — el ticket madre de la familia
- [[welcome-privacy-branch-has-no-secondary-door]] — de ahí salió la medición, y ahí se cerró el tercero
