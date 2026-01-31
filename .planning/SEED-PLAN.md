# Plan de Implementación - Seed de Desarrollo Realista

## Objetivo
Crear un seed 100% realista que cubra TODAS las subcategorías y permita testing completo de la app.

## Estadísticas del Seed

### Cuentas (3)
- **BCP Cuenta Corriente** (PEN) - 50% de transacciones
- **BBVA Ahorros USD** (USD) - 15% de transacciones
- **Efectivo** (PEN) - 35% de transacciones

### Período
- Inicio: 1 Nov 2024
- Fin: 30 Ene 2026
- Total: ~15 meses

### Transacciones Estimadas
- **Ingresos**: ~45 (3/mes × 15 meses)
- **Gastos**: ~1,500 (100/mes × 15 meses)
- **Transferencias**: ~30 (2/mes × 15 meses)
- **TOTAL**: ~1,575 transacciones

---

## 1. INGRESOS (4 tipos mínimo)

### 1.1. Salario (Mensual - Fijo con variación)
- **Subcategoría**: "Salario"
- **Cuenta**: BCP Cuenta Corriente (PEN)
- **Día**: 30 de cada mes
- **Monto Base**: S/6,500
- **Variación**:
  - Meses normales: S/6,500
  - Meses buenos (aguinaldo): +S/3,000 (Jul, Dic)
  - Meses con bono: +S/500-1,000 (aleatorio 2-3 meses/año)
- **Nota**: "Salario mensual"
- **Frecuencia**: 1 por mes = 15 transacciones

### 1.2. Facturación y freelance (Ocasional - Variable)
- **Subcategoría**: "Facturación y freelance"
- **Cuenta**: BCP Cuenta Corriente (PEN)
- **Día**: Aleatorio entre 15-25
- **Monto**: S/800-2,500 (aleatorio)
- **Notas**: ["Proyecto web cliente", "Consultoría IT", "Desarrollo app móvil", "Diseño logo", "Mantenimiento sistema"]
- **Frecuencia**: 40% meses (1 ingreso) = ~6 transacciones

### 1.3. Reembolsos (Esporádico)
- **Subcategoría**: "Reembolsos"
- **Cuenta**: BCP Cuenta Corriente (PEN)
- **Día**: Aleatorio
- **Monto**: S/50-400 (aleatorio)
- **Notas**: ["Reembolso gastos médicos", "Devolución compra defectuosa", "Reembolso trabajo", "Ajuste facturación"]
- **Frecuencia**: 30% meses = ~4-5 transacciones

### 1.4. Regalos y otros ingresos (Ocasional)
- **Subcategoría**: "Regalos y otros ingresos"
- **Cuenta**: Efectivo (PEN) o BCP
- **Día**: Aleatorio
- **Monto**: S/100-800 (aleatorio)
- **Notas**: ["Regalo cumpleaños", "Propina extraordinaria", "Venta artículo usado", "Premio sorteo"]
- **Frecuencia**: 20% meses = ~3 transacciones

---

## 2. GASTOS - TODAS LAS SUBCATEGORÍAS (53 usables)

### 2.1. ALIMENTACIÓN (4 subcategorías)

#### Delivery
- **Cuenta**: BCP (70%), Efectivo (30%)
- **Moneda**: PEN
- **Monto**: S/25-80
- **Frecuencia**: 6/mes
- **Notas**: ["Rappi almuerzo", "PedidosYa cena", "Uber Eats", "Delivery sushi", "Pizza familiar"]

#### Restaurantes
- **Cuenta**: BCP (80%), Efectivo (20%)
- **Moneda**: PEN
- **Monto**: S/30-120
- **Frecuencia**: 10/mes
- **Notas**: ["Almuerzo trabajo", "Cena fin de semana", "Brunch dominical", "Comida china", "Menú ejecutivo"]

#### Suplementos alimenticios
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/40-150
- **Frecuencia**: 1/mes
- **Notas**: ["Proteína whey", "Vitaminas", "Omega 3", "Multivitamínico"]

#### Supermercados y bodegas
- **Cuenta**: Efectivo (60%), BCP (40%)
- **Moneda**: PEN
- **Monto**: S/20-250
- **Frecuencia**: 12/mes
- **Notas**: ["Compra semanal", "Metro", "Bodega esquina", "Plaza Vea", "Compra mensual grande"]

### 2.2. COMPRAS (7 subcategorías)

#### Cuidado personal y belleza
- **Cuenta**: BCP (90%), Efectivo (10%)
- **Moneda**: PEN
- **Monto**: S/30-120
- **Frecuencia**: 2/mes
- **Notas**: ["Shampoo y productos", "Cremas faciales", "Perfume", "Artículos aseo"]

#### Farmacia y botiquín
- **Cuenta**: BCP (70%), Efectivo (30%)
- **Moneda**: PEN
- **Monto**: S/20-150
- **Frecuencia**: 3/mes
- **Notas**: ["Medicamentos", "Inkafarma", "Mifarma", "Botiquín casa", "Analgésicos"]

#### Hogar y decoración
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/80-400
- **Frecuencia**: 1/mes
- **Notas**: ["Cortinas nuevas", "Cuadros decorativos", "Plantas", "Organizadores", "Almohadas"]

#### Otros (Compras)
- **Cuenta**: BCP (80%), Efectivo (20%)
- **Moneda**: PEN
- **Monto**: S/30-200
- **Frecuencia**: 2/mes
- **Notas**: ["Varios", "Compra emergencia", "Artículos varios"]

#### Regalos y detalles
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/50-300
- **Frecuencia**: 2/mes
- **Notas**: ["Regalo cumpleaños", "Detalles familia", "Regalo amigo secreto", "Flores", "Chocolates"]

#### Ropa y calzado
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/80-500
- **Frecuencia**: 2/mes
- **Notas**: ["Zapatos nuevos", "Polos trabajo", "Jeans", "Ropa sport", "Zapatillas"]

#### Tecnología y accesorios
- **Cuenta**: BCP (80%), BBVA USD (20%)
- **Moneda**: PEN o USD según cuenta
- **Monto**: S/100-800 o $30-200
- **Frecuencia**: 1/mes
- **Notas**: ["Auriculares Bluetooth", "Mouse gaming", "Cable USB-C", "Funda laptop", "Teclado mecánico"]

### 2.3. TRANSPORTE (3 subcategorías)

#### Movilidad ocasional
- **Cuenta**: Efectivo (80%), BCP (20%)
- **Moneda**: PEN
- **Monto**: S/15-50
- **Frecuencia**: 4/mes
- **Notas**: ["Scooter eléctrico", "Bicicleta compartida", "Moto taxi", "Movilidad especial"]

#### Taxis y apps
- **Cuenta**: BCP (70%), Efectivo (30%)
- **Moneda**: PEN
- **Monto**: S/10-45
- **Frecuencia**: 12/mes
- **Notas**: ["Uber trabajo", "Taxi nocturno", "Beat", "InDriver", "Cabify"]

#### Transporte público
- **Cuenta**: Efectivo (95%), BCP (5%)
- **Moneda**: PEN
- **Monto**: S/2.50-8
- **Frecuencia**: 18/mes
- **Notas**: ["Metropolitano", "Bus", "Combi", "Corredor", "Pasaje diario"]

### 2.4. FINANZAS (5 subcategorías)

#### Comisiones y cargos
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/5-35
- **Frecuencia**: 2/mes
- **Notas**: ["Comisión transferencia", "Cargo mantenimiento", "Comisión banco", "Cargo tarjeta"]

#### Impuestos
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/150-600
- **Frecuencia**: 0.3/mes (trimestral/anual)
- **Notas**: ["Predial", "Impuesto renta", "Arbitrios", "Declaración anual"]

#### Pensiones y aportes
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/400-800
- **Frecuencia**: 1/mes
- **Notas**: ["AFP mensual", "Aporte jubilación", "Fondo pensiones"]

#### Préstamos y créditos
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/300-900
- **Frecuencia**: 1/mes
- **Notas**: ["Cuota préstamo personal", "Pago tarjeta crédito", "Cuota consumo"]

#### Seguros (Finanzas)
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/80-200
- **Frecuencia**: 1/mes
- **Notas**: ["Seguro vida", "Seguro salud", "Seguro SOAT", "Póliza personal"]

### 2.5. HOGAR (6 subcategorías)

#### Alquiler o hipoteca
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/1,500 (fijo)
- **Frecuencia**: 1/mes
- **Notas**: ["Alquiler mensual", "Renta departamento"]

#### Mantenimiento y reparaciones
- **Cuenta**: BCP (80%), Efectivo (20%)
- **Moneda**: PEN
- **Monto**: S/80-400
- **Frecuencia**: 1.5/mes
- **Notas**: ["Gasfitero", "Pintura pared", "Reparación puerta", "Electricista", "Arreglo mueble"]

#### Otros (Hogar)
- **Cuenta**: BCP (70%), Efectivo (30%)
- **Moneda**: PEN
- **Monto**: S/30-150
- **Frecuencia**: 1/mes
- **Notas**: ["Varios hogar", "Compra urgente", "Artículos limpieza"]

#### Personal de apoyo
- **Cuenta**: Efectivo (70%), BCP (30%)
- **Moneda**: PEN
- **Monto**: S/100-300
- **Frecuencia**: 2/mes
- **Notas**: ["Limpieza casa", "Jardinero", "Ayuda doméstica", "Plomero"]

#### Seguro del hogar
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/120 (fijo)
- **Frecuencia**: 1/mes
- **Notas**: ["Póliza mensual", "Seguro inmueble"]

#### Servicios del hogar
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/150-220
- **Variación**: Luz/agua varían ±20%, internet fijo
- **Frecuencia**: 3/mes (luz, agua, internet)
- **Notas**: ["Internet Movistar", "Luz Enel", "Agua Sedapal"]

### 2.6. ENTRETENIMIENTO (8 subcategorías)

#### Bares y salidas sociales
- **Cuenta**: BCP (60%), Efectivo (40%)
- **Moneda**: PEN
- **Monto**: S/40-180
- **Frecuencia**: 5/mes
- **Notas**: ["Cerveza fin de semana", "After office", "Bar Barranco", "Drinks amigos", "Terraza"]

#### Deportes y recreación
- **Cuenta**: BCP (90%), Efectivo (10%)
- **Moneda**: PEN
- **Monto**: S/30-150
- **Frecuencia**: 3/mes
- **Notas**: ["Partido fútbol", "Alquiler cancha", "Clase tenis", "Entrada parque"]

#### Espectáculos y eventos
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/50-300
- **Frecuencia**: 1.5/mes
- **Notas**: ["Concierto", "Teatro", "Stand up comedy", "Cine premium", "Festival"]

#### Fiestas y vida nocturna
- **Cuenta**: BCP (70%), Efectivo (30%)
- **Moneda**: PEN
- **Monto**: S/80-250
- **Frecuencia**: 2/mes
- **Notas**: ["Discoteca", "Club nocturno", "Fiesta privada", "Cover club", "Salida nocturna"]

#### Hobbies y gaming
- **Cuenta**: BCP (80%), BBVA USD (20%)
- **Moneda**: PEN o USD
- **Monto**: S/50-300 o $15-80
- **Frecuencia**: 2/mes
- **Notas**: ["Juego PS5", "Steam", "Nintendo eShop", "Suscripción Xbox", "DLC juego"]

#### Salidas en pareja
- **Cuenta**: BCP (90%), Efectivo (10%)
- **Moneda**: PEN
- **Monto**: S/80-250
- **Frecuencia**: 3/mes
- **Notas**: ["Cena romántica", "Cine pareja", "Paseo Larcomar", "Café especial", "Día especial"]

#### Streaming y plataformas
- **Cuenta**: BCP (50%), BBVA USD (50%)
- **Moneda**: PEN o USD
- **Monto**: S/10-50 o $3-15
- **Frecuencia**: 4/mes (suscripciones)
- **Notas**: ["Netflix", "Spotify Premium", "Disney+", "HBO Max", "YouTube Premium"]

#### Viajes y vacaciones
- **Cuenta**: BCP (80%), BBVA USD (20%)
- **Moneda**: PEN o USD
- **Monto**: S/300-2,000 o $80-500
- **Frecuencia**: 0.3/mes (2-3 veces/año)
- **Notas**: ["Pasajes Cusco", "Hotel playa", "Tour Arequipa", "Fin semana norte", "Airbnb"]

### 2.7. PERSONAL (8 subcategorías)

#### Asesorías y trámites
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/80-300
- **Frecuencia**: 0.5/mes
- **Notas**: ["Contador", "Abogado consulta", "Trámite notarial", "Gestoría", "Asesoría legal"]

#### Belleza y estética
- **Cuenta**: BCP (80%), Efectivo (20%)
- **Moneda**: PEN
- **Monto**: S/40-150
- **Frecuencia**: 2/mes
- **Notas**: ["Corte cabello", "Barbería", "Manicure", "Spa facial", "Tratamiento estético"]

#### Educación y desarrollo
- **Cuenta**: BCP (90%), BBVA USD (10%)
- **Moneda**: PEN o USD
- **Monto**: S/100-600 o $30-150
- **Frecuencia**: 1.5/mes
- **Notas**: ["Curso online Udemy", "Clase inglés", "Certificación", "Libro técnico", "Taller"]

#### Fitness y actividad física
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/150 (fijo mensual)
- **Frecuencia**: 1/mes
- **Notas**: ["Gym mensualidad", "Cuota gimnasio", "Membresía fitness"]

#### Salud y atención médica
- **Cuenta**: BCP (90%), Efectivo (10%)
- **Moneda**: PEN
- **Monto**: S/50-400
- **Frecuencia**: 2/mes
- **Notas**: ["Consulta médica", "Dentista", "Exámenes laboratorio", "Oftalmólogo", "Terapia"]

#### Suscripciones de ocio
- **Cuenta**: BCP (70%), BBVA USD (30%)
- **Moneda**: PEN o USD
- **Monto**: S/20-80 o $5-20
- **Frecuencia**: 2/mes
- **Notas**: ["Revista digital", "App premium", "Audible", "Kindle Unlimited", "Patreon"]

#### Suscripciones de utilidad
- **Cuenta**: BCP (60%), BBVA USD (40%)
- **Moneda**: PEN o USD
- **Monto**: S/10-50 o $3-15
- **Frecuencia**: 3/mes
- **Notas**: ["iCloud 200GB", "Google One", "Dropbox Plus", "VPN", "Antivirus"]

#### Telefonía y comunicaciones
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/55-80
- **Variación**: Fijo S/55, ocasional exceso datos
- **Frecuencia**: 1/mes
- **Notas**: ["Plan Claro", "Recarga móvil", "Plan Movistar", "Paquete datos"]

### 2.8. MASCOTAS Y ANIMALES (4 subcategorías)

#### Accesorios y juguetes
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/30-120
- **Frecuencia**: 0.5/mes
- **Notas**: ["Juguete perro", "Collar nuevo", "Cama mascota", "Plato comedero"]

#### Alimentación de mascotas
- **Cuenta**: BCP (80%), Efectivo (20%)
- **Moneda**: PEN
- **Monto**: S/80-200
- **Frecuencia**: 2/mes
- **Notas**: ["Alimento balanceado", "Croquetas perro", "Comida gato", "Snacks mascota"]

#### Salud veterinaria
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/100-400
- **Frecuencia**: 1/mes
- **Notas**: ["Veterinario revisión", "Vacunas", "Desparasitación", "Consulta urgencia", "Medicamento"]

#### Servicios y cuidados
- **Cuenta**: BCP (70%), Efectivo (30%)
- **Moneda**: PEN
- **Monto**: S/40-150
- **Frecuencia**: 1.5/mes
- **Notas**: ["Peluquería canina", "Baño mascota", "Guardería perro", "Paseador", "Grooming"]

### 2.9. VEHÍCULO (6 subcategorías)

#### Combustible
- **Cuenta**: BCP (90%), Efectivo (10%)
- **Moneda**: PEN
- **Monto**: S/80-200
- **Frecuencia**: 4/mes
- **Notas**: ["Gasolina 90", "Gasolina 95", "Primax", "Repsol", "Tanque lleno"]

#### Estacionamientos
- **Cuenta**: Efectivo (60%), BCP (40%)
- **Moneda**: PEN
- **Monto**: S/5-30
- **Frecuencia**: 8/mes
- **Notas**: ["Parking centro", "Estacionamiento mall", "Parqueo calle", "Valet"]

#### Leasing
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/800-1,200 (fijo)
- **Frecuencia**: 1/mes
- **Notas**: ["Cuota leasing auto", "Cuota mensual vehículo"]

#### Mantenimiento del vehículo
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/150-600
- **Frecuencia**: 0.5/mes
- **Notas**: ["Cambio aceite", "Revisión técnica", "Alineación balanceo", "Cambio llantas", "Frenos"]

#### Préstamo vehicular
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/500-1,000 (fijo)
- **Frecuencia**: 1/mes
- **Notas**: ["Cuota préstamo auto", "Cuota crédito vehicular"]

#### Seguro vehicular
- **Cuenta**: BCP (100%)
- **Moneda**: PEN
- **Monto**: S/180-250
- **Frecuencia**: 1/mes
- **Notas**: ["SOAT", "Seguro todo riesgo", "Póliza vehicular mensual"]

---

## 3. TRANSFERENCIAS ENTRE CUENTAS

### 3.1. Retiros de efectivo (BCP → Efectivo)
- **Frecuencia**: 2/mes
- **Monto**: S/300-600
- **Nota**: "Retiro cajero" o "Retiro ventanilla"

### 3.2. Depósitos de efectivo (Efectivo → BCP)
- **Frecuencia**: 0.5/mes
- **Monto**: S/200-500
- **Nota**: "Depósito efectivo" o "Ingreso efectivo a cuenta"

### 3.3. Ahorro en dólares (BCP PEN → BBVA USD)
- **Frecuencia**: 0.5/mes
- **Monto**: S/500-1,500 convertido a USD con exchange rate del día
- **Nota**: "Ahorro mensual USD" o "Compra dólares ahorro"

---

## 4. EXCHANGE RATES REALISTAS

### Lógica de tipos de cambio PEN/USD
- **Base histórica**: ~3.70-3.80 PEN por 1 USD
- **Variación mensual**: ±0.02-0.05
- **Nov 2024**: 3.75
- **Dic 2024**: 3.77
- **Ene 2025**: 3.76
- **Feb 2025**: 3.78
- (continuar con variación realista)

### Aplicación
- Transacciones en USD usan el exchange rate del mes correspondiente
- `isExchangeRateProvisional = false` (todas son exactas)

---

## 5. MESES BUENOS vs MESES MALOS

### Meses Buenos (Mayor ingreso, menor gasto)
- **Julio**: Aguinaldo + Menos gastos discrecionales
- **Diciembre**: Aguinaldo + Bonos, pero más gastos regalos

### Meses Normales
- Mayoría de meses: Gastos estándar

### Meses Malos (Gastos extraordinarios)
- **Marzo**: Impuestos anuales, inicio clases (educación)
- **Agosto**: Gastos vehículo (mantenimiento mayor), viaje vacaciones

---

## 6. DISTRIBUCIÓN DE NOTAS

- **Ingresos**: 100% con notas
- **Gastos recurrentes fijos**: 100% con notas
- **Gastos variables**: 30% con notas
- **Transferencias**: 100% con notas

---

## 7. IMPLEMENTACIÓN

### Estructura de código
```swift
// 1. Definir templates por subcategoría (todas las 53)
// 2. Generar ingresos mensuales con variación
// 3. Generar gastos recurrentes fijos
// 4. Generar gastos variables según templates
// 5. Generar transferencias entre cuentas
// 6. Aplicar exchange rates realistas
// 7. Asignar notas según porcentaje
// 8. Distribuir entre cuentas según lógica
```

### Validaciones
- ✅ Todas las 53 subcategorías de gastos usadas
- ✅ 4+ tipos de ingresos
- ✅ Divisas según cuenta (no todo preferredCurrency)
- ✅ Notas realistas
- ✅ Meses buenos/malos
- ✅ Exchange rates variables
- ✅ Distribución 3 cuentas
