---
id: 2026-11-19-welcome-carrusel-barras-y-toque
status: done
priority: medium
area: "onboarding, welcome, a11y"
created: 2026-11-19
updated: 2026-11-19
card: tablero-welcome-al-deslizar-a-la-siguiente-tarje-s8ou
source: "Jürgen, 19-nov 21:21, build 2.3 (5)"
---

# Welcome: al deslizar a la siguiente tarjeta la anterior no queda llena, y tocar la mitad derecha no avanza

## Lo que vio Jürgen

En la vitrina del Welcome («Mis finanzas» y «Cuentas claras con tus amigos»), al pasar a la segunda tarjeta las dos
barras de progreso avanzaban a la vez. Y tocar la caja la pausaba, en vez de pasar de tarjeta como en las historias.

## Causa

Cada barra animaba su propio relleno con una animación lineal de 5 s. Al pasar de tarjeta, la anterior cambiaba a
«llena», pero su ancho final ya era 1: el cambio no cortaba la animación en vuelo y la barra seguía llenándose.

## Qué cambia

- Las barras salen de un solo reloj, sin animación propia: anteriores llenas, la actual avanza, las siguientes vacías.
  Igual al avanzar solo, al deslizar adelante o atrás y con pausa.
- La pausa congela la barra donde está y, al reanudar, sigue con lo que le quedaba.
- Tocar la mitad derecha pasa a la siguiente; la izquierda vuelve a la anterior (en la primera, da la vuelta a la
  última, como el deslizamiento). La pausa queda solo en su botón.
- VoiceOver: la función en pantalla es ajustable (deslizar arriba/abajo) y tiene las acciones «Siguiente función» y
  «Función anterior». Con Reducir movimiento o VoiceOver la vitrina sigue sin rotar sola.

## Pin

`YalaTests/WelcomeCarruselBarrasYToque/WelcomeCarruselBarrasYToqueTests.swift`.
