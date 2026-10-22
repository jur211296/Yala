---
id: welcome-sign-in-notes-say-the-account-is-bound-to-one-method
status: done
priority: low
area: "welcome, cuenta, copy"
created: 2026-10-19
updated: 2026-10-22
source: "lote decidido 2.2 · 04 (L20-9), visto al unificar la frase del método"
---

# Las notas de entrar del Welcome dicen que la cuenta queda ligada a un método, y no es así

## El problema, en lenguaje de usuario

Al entrar o crear la cuenta en la nube desde el Welcome leo «Entra con el mismo método que usaste al crear tu cuenta: tu
cuenta de Yala queda ligada a él» o «Tu cuenta de Yala quedará ligada al método que elijas». En Ajustes, «Tu cuenta de
Yala» y el selector de «Activar la nube» me dicen otra cosa: «Si usas el mismo correo, Apple y Google abren esta misma
cuenta». Las dos no pueden ser verdad.

## Lo medido

- Producción (`kefvaiymtgytemwbltlz`) y staging tienen Apple y Google activos y `security_manual_linking_enabled = false`
  (Management API de Supabase, 2026-10-19): GoTrue une por el correo verificado. En staging hay un usuario con las dos
  identidades en la misma cuenta (el H4 del 2026-07-16).
- Las dos notas viven en `welcome.cloud.providerNote` y `welcome.bornCloud.providerNote` (16 idiomas), usadas por
  `WelcomeCloudSignInView` y `WelcomeExistingChooserView`.
- L20-9 (lote decidido 04) unificó solo las dos pantallas que nombraba la decisión: «Tu cuenta de Yala» y el selector de
  Ajustes, que ya leen la misma key (`settings.yalaAccountLinkingNote`).

## Lo que hay que decidir

1. Que las dos notas del Welcome digan la misma frase (misma key). Matiz: con «Ocultar mi correo» de Apple el correo es
   otro y sí serían dos cuentas; la frase ya lo condiciona («si usas el mismo correo»).
2. Dejarlas: en el Welcome «entra con el mismo método» es un consejo práctico, aunque la razón que da no es exacta.

## Hecho (2026-10-22, lote decidido 2.2 · 15)

Implementada la opción que eligió Jürgen. Red: `YalaTests/UXAudit22Decidido15Tests` y `YalaUITests/Flows/SettingsLote15UITests`.
