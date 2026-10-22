---
id: detach-does-not-verify-the-cloud-session-actually-closed
status: done
priority: medium
area: "modo-nube, groups"
created: 2026-09-11
updated: 2026-09-26
source: "review adversarial del paso 10 (`groups-account-association-in-storage-row`), lente de sync"
---

# El desasociar no comprueba que la sesión en la nube se cerró de verdad

## Lo medido (2026-09-11)

`CloudAuthService.signOut()` envuelve `client.signOut(scope: .local)` en un `do/catch` que **solo
loguea**. Los demás caminos que lo llaman se lo pueden permitir porque acaban en `armSignOutWipe` +
relanzamiento; `detachGroupsAccount` no.

Si la sesión sobrevive al `signOut()`: en el siguiente foreground `startIfEligible` pasa su
`sessionCheck()`, arranca el loop, y como el cursor se purgó **vuelve a bajar el corpus entero** que el
desasociar acaba de borrar. La asociación ya está limpia, así que el libro de conservados no casa y todo
se re-puentea: duplicados junto a los movimientos que el usuario decidió conservar. Estado final peor que
el inicial, y sin ningún aviso.

**Sospecha parcialmente verificada**: el hueco del `catch` y la ausencia de postcondición están medidos;
lo que no se midió es si `supabase-swift` puede lanzar dejando `currentSession != nil`.

## Lo que se espera

Una postcondición antes del punto de no retorno:
`guard !CloudAuthService.shared.hasSession else { phase = .blocked(…); return }`. Con el sign-out fallido,
el desasociar se detiene y se puede reintentar, en vez de dejar el dispositivo a medias.

## Lo hecho (2026-09-26)

**Para la persona:** si al soltar la cuenta de grupos la sesión de esa cuenta no se cierra de verdad, la app se para antes de
tocar nada y lo dice («No pudimos cerrar la sesión de tu cuenta de grupos en este iPhone. No se soltó nada. Vuelve a
intentarlo.»). Antes seguía, borraba los grupos, y en el siguiente arranque volvían a bajar re-puenteados al lado de lo que
eligió conservar.

**La sospecha, medida en supabase-swift 2.50.0** (`SupabaseSignOutContractTests`): `signOut(scope: .local)` borra la sesión
antes de la red, así que sin red lanza con la sesión ya fuera; con el llavero negándose a borrar NO lanza y la sesión sigue; y
un refresco en vuelo la repone. El `catch` del ticket no era el testigo: lo es el llavero releído.

- `CloudAuthService.signOut()` devuelve si queda sesión guardada (`sessionIsGone`, fallo cerrado: viva si el SDK la ve, si el
  llavero no se deja leer o si guarda una sesión que decodifica). El perfil capturado y el proveedor se borran solo con la
  sesión ida.
- El desasociar cierra la sesión ANTES del puente (el punto de no retorno) y la comprueba; con la sesión viva, `.blocked`
  con el motivo nuevo `.sessionNotClosed` (16 locales) y el canario `groupsDetachSessionSurvived`. Coste asumido: si el
  puente no se deja leer, la sesión ya está cerrada (celda del segundo móvil; el reintento no necesita sesión).
- Rule nueva en `.claude/rules/swiftdata-cloudkit.md` («Que `signOut()` volviera no dice que la sesión se fuera»).

**Verificado:** suite unitaria completa; XCUITest `GroupsAssociationRowUITests#test_detachWhenTheSessionSurvivesSignOut_stopsAndSaysSo`
(seam `-uitest-sign-out-keeps-session`) con su control; mutantes sobre orden, testigo, perfil, motivo, Perfil y seam.
Review adversarial en tres lentes: cazó el fixture en formato de red, las tablas de `allCases`, `.containing` en el XCUITest y
una regresión que abría el arreglo (el perfil borrado con la sesión viva).

**Fuera, con ticket:** `sign-out-exits-do-not-verify-the-cloud-session-closed` (la premisa de arriba sobre los cierres no se
sostiene: el boot-wipe no purga la sesión del llavero) y `detach-postcondition-misses-a-token-refresh-that-lands-after-it`.
