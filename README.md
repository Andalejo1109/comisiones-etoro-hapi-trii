# Comisiones eToro vs Hapi vs Trii — DCA Colombia

Pregunta del caso: **si una persona en Colombia aporta 200 o 500 USD al mes durante 5 o 10 años, al mismo libro de activos, ¿cuánto se come el depósito + el ticket de compra?**

El rendimiento del mercado se deja **igual en todos los brokers** (10% anual de planificación). Así el diferencial es solo costo. No es un backtest de SPYG/SMH/BRK.B/VTI/IEMG ni una recomendación de plataforma.

Código: [`R/simular_comisiones.R`](R/simular_comisiones.R).

## El libro (mismos pesos)

| Activo | Peso | Tipo en eToro |
|---|---:|---|
| SPYG | 35% | ETF → comisión $0 |
| SMH | 15% | ETF → $0 |
| BRK.B | 20% | acción → ~$1 por compra manual |
| VTI | 10% | ETF → $0 |
| IEMG | 20% | ETF → $0 |

Cada mes se compra el libro con el efectivo **neto de costos**. No hay rebalanceo de lo ya comprado ni ventas intermedias.

## Lo que había que corregir del planteamiento original

1. **Depósito ≠ conversión.** eToro no cobra *fee de depósito*, pero un fondeo COP→USD sí puede llevar **markup FX** (en cuentas LATAM suele cotizarse ~1,5% con tarjeta / hasta ~3% banca en línea según club). Hapi PSE publica **0,45% (mín. ~USD 1,99)**; tarjeta Hapi ~**3,85%**. Trii PSE **$0**.
2. **eToro no cobra $1 por ETF.** El $1 aplica a **acciones reales** (aquí, BRK.B). Los cuatro ETF quedan en $0. En **CopyTrader** eToro indica que las acciones copiadas **no pagan** esa comisión fija.
3. **Hapi no es 1–2% de depósito en el canal barato.** El 1–2% se parece más a Airtm u otros rieles; el canal local es PSE 0,45%. El **USD 0,15** es un supuesto razonable de *clearing* por orden fraccionada, no comisión de bróker.
4. **Trii cobra por ticket, no por portafolio.** Replicar 5 nombres = **5 tickets/mes**. A COP 14.875 IVA incl. y TRM 4.000 eso es **~USD 18,6/mes** sobre un DCA de 200. Por eso el repo corre dos modos: `5 tickets` (mismo libro) y `1 ticket` (un solo fondo/canasta, más realista en comisionista local).
5. **Trii probablemente no lista SPYG, SMH, VTI, IEMG y BRK.B en USD.** El acceso internacional va por MGC / fondos locales. La simulación **asume el mismo retorno** para aislar comisiones. No afirma que el producto sea el mismo.
6. **Trii Pro no siempre ahorra en DCA chico.** La membresía (~COP 27.900/mes ≈ USD 7) se come el descuento del 50% si el aporte es 200 y se opera un solo ticket.

Tarifas parametrizadas a **septiembre 2026**. Hay que re-chequear la página oficial antes de usar los números para una decisión.

## Supuestos fijos

| Pieza | Valor |
|---|---|
| TRM de trabajo | 4.000 COP/USD |
| Rentabilidad | 10% anual compuesto, constante |
| Aporte | 200 o 500 USD/mes, 5 o 10 años |
| Capital inicial | 0 |
| GMF 4×1000 | no modelado (sensibilidad fácil de añadir) |
| Spreads / bid-ask | no modelados (igualarían el ranking si son similares) |
| Retiro / inactividad | fuera de alcance (horizonte de acumulación) |
| Suscripción Trii Pro | se paga con el mismo flujo mensual |

Escenario `cero` = techo teórico (0 costos). Sirve de regla para medir *drag*.

## Resultado — 10 años al 10%

Aportes brutos: **24.000** (200/mes) o **60.000** (500/mes). Terminal sin costos: **39.973** y **99.932**.

| Escenario | 200/mes fees | 200/mes terminal | 200 drag | 500/mes fees | 500/mes terminal | 500 drag |
|---|---:|---:|---:|---:|---:|---:|
| Cero comisión | 0 | 39.973 | 0 | 0 | 99.932 | 0 |
| eToro Copy (USD ya en cuenta) | 0 | 39.973 | 0 | 0 | 99.932 | 0 |
| eToro manual (USD; $1 solo BRK.B) | 120 | 39.773 | 200 | 120 | 99.732 | 200 |
| Hapi PSE 0,45% + 5×0,15 | 329 | 39.425 | 548 | 360 | 99.332 | 600 |
| Trii estándar, 1 ticket | 446 | 39.230 | 743 | 446 | 99.189 | 743 |
| eToro manual + FX 1,5% | 480 | 39.173 | 800 | 1.020 | 98.233 | 1.699 |
| Hapi tarjeta 3,85% | 1.014 | 38.284 | 1.689 | 2.400 | 95.935 | 3.997 |
| Trii Pro, 1 ticket | 1.060 | 38.207 | 1.766 | 1.060 | 98.166 | 1.766 |
| eToro manual + FX 3,0% | 840 | 38.574 | 1.399 | 1.920 | 96.734 | 3.198 |
| Trii Pro, 5 tickets | 1.953 | 36.721 | 3.252 | 1.953 | 96.680 | 3.252 |
| Trii estándar, 5 tickets | 2.231 | 36.257 | 3.716 | 2.231 | 96.216 | 3.716 |

A 5 años el orden no cambia; el drag es menor en dólares porque hay menos meses y menos interés compuesto sobre lo no invertido.

### Lectura (no ranking de brokers)

- El **ticket fijo en COP** pega más cuando el aporte es chico **y** se parte en varios nombres. A 200 USD, 5 tickets en Trii estándar se llevan **~9,3% de cada aporte** antes de que el mercado trabaje.
- En eToro, si el fondeo ya está en USD (o se copia), el costo de *operar este libro* es casi irrelevante: un dólar al mes por BRK.B, cero en los ETF.
- El costo que sí mueve la aguja en eToro para un colombiano es la **conversión COP→USD**, no el $1 del ticket.
- Hapi por **PSE** queda en el medio: el 0,45% escala con el aporte; el 0,15 × 5 = 0,75 USD/mes no escala.
- Hapi por **tarjeta** y eToro con FX 3% se parecen: el riel de entrada pesa más que el bróker.
- Trii Pro **no** es automático ahorro a 200 USD/mes. Conviene cuando hay muchos tickets grandes, no cuando el DCA es chico y ya se comprime a 1 orden.

Nada de esto incluye regulación, fracciones, catálogo, CopyTrader, impuestos ni riesgo operativo. Un colombiano puede elegir Trii por SFC y pesos, o Hapi por SIPC, o eToro por copiar — con otros criterios. Aquí solo se mide **cuánto deja de invertirse**.

## Cómo correrlo

```r
# desde la raíz del repo
source("R/simular_comisiones.R")
```

o

```bash
Rscript R/simular_comisiones.R
```

Salida:

- `output/resultados_comisiones.csv` — grilla 5/10 años × 200/500
- `output/tabla_10anios.csv`
- `output/drag_10anios.png`

Para cambiar TRM, tarifas o rentabilidad, editar el bloque de parámetros al inicio del script.

## Sensibilidades que faltan (próximas)

- GMF 4×1000 sobre el PSE.
- Liquidar al año 10 (cierra BRK.B a $1 en eToro; 5 tickets de salida en Trii).
- Backtest con precios reales de los 5 tickers en vez de 10% plano.
- Aporte en COP constante (el USD mensual fluctúa con la TRM).

## Disclaimer

Ejercicio ilustrativo con tarifas y una TRM de trabajo. Las comisiones cambian. Rentabilidades pasadas o supuestos de 10% no predicen resultados. No es recomendación de inversión ni de intermediario. Invertir en acciones y ETF implica riesgo de pérdida de capital.
