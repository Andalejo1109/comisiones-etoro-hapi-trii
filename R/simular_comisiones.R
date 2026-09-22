# Simulación de comisiones: eToro vs Hapi vs Trii
# Caso Colombia — DCA mensual sobre un mismo libro de activos
# Rendimiento idéntico en todos los brokers: el único diferencial es el costo.
#
# Uso:
#   Rscript R/simular_comisiones.R
#   o source("R/simular_comisiones.R")

dir.create("output", showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1. Parámetros del caso (editar aquí)
# ---------------------------------------------------------------------------
COP_POR_USD <- 4000          # TRM de trabajo; no es pronóstico
RENTA_ANUAL <- 0.10          # escenario de planificación, no de marketing
APORTES_USD <- c(200, 500)
HORIZONTES  <- c(5, 10)

PESOS <- c(SPYG = 0.35, SMH = 0.15, BRKB = 0.20, VTI = 0.10, IEMG = 0.20)
ES_ACCION <- c(SPYG = FALSE, SMH = FALSE, BRKB = TRUE, VTI = FALSE, IEMG = FALSE)
stopifnot(abs(sum(PESOS) - 1) < 1e-9)

# Tarifas vigentes usadas como supuesto (septiembre 2026). Verificar antes de decidir.
# eToro (cuenta no UK): depósito $0; conversión COP→USD 1.5%–3% según método/club;
#   ETF $0; acción real ~$1 apertura (y $1 cierre). CopyTrader: sin comisión extra
#   y las copias no pagan el $1 de acciones.
# Hapi Colombia: PSE 0.45% (mín. ~USD 1.99); tarjeta ~3.85%; clearing fracción ~USD 0.15/ticket.
# Trii: depósito PSE $0; ticket ~COP 14.875 IVA incl. hasta COP 5M;
#   Pro ~COP 27.900/mes y ~50% del ticket (~COP 7.438).
TARIFAS <- list(
  cero = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
              ticket_usd = 0, fee_accion = 0, n_tickets = 5, sub_usd = 0),
  etoro_manual_usd = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
                          ticket_usd = 0, fee_accion = 1, n_tickets = 5, sub_usd = 0),
  etoro_copy_usd = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
                        ticket_usd = 0, fee_accion = 0, n_tickets = 5, sub_usd = 0),
  etoro_manual_fx1.5 = list(dep_pct = 0, dep_min = 0, fx_pct = 0.015,
                            ticket_usd = 0, fee_accion = 1, n_tickets = 5, sub_usd = 0),
  etoro_manual_fx3.0 = list(dep_pct = 0, dep_min = 0, fx_pct = 0.03,
                            ticket_usd = 0, fee_accion = 1, n_tickets = 5, sub_usd = 0),
  hapi_pse = list(dep_pct = 0.0045, dep_min = 1.99, fx_pct = 0,
                  ticket_usd = 0.15, fee_accion = 0, n_tickets = 5, sub_usd = 0),
  hapi_tarjeta = list(dep_pct = 0.0385, dep_min = 2.99, fx_pct = 0,
                      ticket_usd = 0.15, fee_accion = 0, n_tickets = 5, sub_usd = 0),
  trii_std_5tickets = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
                           ticket_usd = 14875 / COP_POR_USD, fee_accion = 0,
                           n_tickets = 5, sub_usd = 0),
  trii_std_1ticket = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
                          ticket_usd = 14875 / COP_POR_USD, fee_accion = 0,
                          n_tickets = 1, sub_usd = 0),
  trii_pro_5tickets = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
                           ticket_usd = 7438 / COP_POR_USD, fee_accion = 0,
                           n_tickets = 5, sub_usd = 27900 / COP_POR_USD),
  trii_pro_1ticket = list(dep_pct = 0, dep_min = 0, fx_pct = 0,
                          ticket_usd = 7438 / COP_POR_USD, fee_accion = 0,
                          n_tickets = 1, sub_usd = 27900 / COP_POR_USD)
)

# ---------------------------------------------------------------------------
# 2. Motor
# ---------------------------------------------------------------------------
r_mes <- function(anual) (1 + anual)^(1 / 12) - 1

fee_trading_mes <- function(tar) {
  if (tar$n_tickets == 5 && tar$fee_accion > 0) {
    # un ticket por activo: $1 solo en BRK.B; ETF a $0
    sum(ifelse(ES_ACCION, tar$fee_accion, tar$ticket_usd))
  } else {
    tar$ticket_usd * tar$n_tickets
  }
}

simular_uno <- function(aporte, anios, tar, anual = RENTA_ANUAL) {
  meses <- anios * 12
  rm <- r_mes(anual)
  port <- 0
  bruto <- dep <- fx <- tr <- sub <- invertido <- 0
  fee_tr_mes <- fee_trading_mes(tar)

  for (m in seq_len(meses)) {
    bruto <- bruto + aporte
    fee_dep <- max(aporte * tar$dep_pct, if (aporte > 0) tar$dep_min else 0)
    dep <- dep + fee_dep
    despues_dep <- aporte - fee_dep
    fee_fx <- despues_dep * tar$fx_pct
    fx <- fx + fee_fx
    despues_fx <- despues_dep - fee_fx
    sub <- sub + tar$sub_usd
    # la suscripción se paga con el mismo flujo mensual
    caja <- despues_fx - tar$sub_usd
    tr <- tr + fee_tr_mes
    neto <- max(caja - fee_tr_mes, 0)
    invertido <- invertido + neto
    port <- port * (1 + rm) + neto
  }

  list(
    aporte = aporte,
    anios = anios,
    n_aportes = meses,
    bruto = bruto,
    invertido = invertido,
    fee_deposito = dep,
    fee_fx = fx,
    fee_trading = tr,
    fee_suscripcion = sub,
    fees_total = dep + fx + tr + sub,
    terminal = port
  )
}

# ---------------------------------------------------------------------------
# 3. Correr grilla
# ---------------------------------------------------------------------------
filas <- list()
i <- 1
for (anios in HORIZONTES) {
  for (aporte in APORTES_USD) {
    base <- simular_uno(aporte, anios, TARIFAS$cero)
    for (nm in names(TARIFAS)) {
      r <- simular_uno(aporte, anios, TARIFAS[[nm]])
      filas[[i]] <- data.frame(
        escenario = nm,
        aporte_usd = aporte,
        anios = anios,
        aportes_brutos = round(r$bruto, 2),
        invertido_neto = round(r$invertido, 2),
        fee_deposito = round(r$fee_deposito, 2),
        fee_fx = round(r$fee_fx, 2),
        fee_trading = round(r$fee_trading, 2),
        fee_suscripcion = round(r$fee_suscripcion, 2),
        fees_total = round(r$fees_total, 2),
        fees_pct_bruto = round(100 * r$fees_total / r$bruto, 2),
        terminal_10pct = round(r$terminal, 2),
        drag_vs_cero = round(base$terminal - r$terminal, 2),
        stringsAsFactors = FALSE
      )
      i <- i + 1
    }
  }
}

res <- do.call(rbind, filas)
write.csv(res, "output/resultados_comisiones.csv", row.names = FALSE)

# Tabla compacta para el README: 200 USD / 10 años y 500 USD / 10 años
compacta <- res[res$anios == 10, c(
  "escenario", "aporte_usd", "aportes_brutos", "fees_total",
  "fees_pct_bruto", "terminal_10pct", "drag_vs_cero"
)]
write.csv(compacta, "output/tabla_10anios.csv", row.names = FALSE)

cat("=== Resultados (renta anual 10%, TRM", COP_POR_USD, ") ===\n")
print(res, row.names = FALSE)
cat("\nArchivos: output/resultados_comisiones.csv, output/tabla_10anios.csv\n")

# ---------------------------------------------------------------------------
# 4. Gráfico (base R, sin dependencias)
# ---------------------------------------------------------------------------
png("output/drag_10anios.png", width = 1400, height = 800, res = 120)
op <- par(mfrow = c(1, 2), mar = c(10, 5, 3, 1), las = 2)

esc_ord <- c(
  "cero", "etoro_copy_usd", "etoro_manual_usd", "hapi_pse",
  "trii_std_1ticket", "etoro_manual_fx1.5", "hapi_tarjeta",
  "trii_pro_1ticket", "etoro_manual_fx3.0", "trii_pro_5tickets",
  "trii_std_5tickets"
)
cols <- c(
  cero = "#2f2f2f",
  etoro_copy_usd = "#12C47A",
  etoro_manual_usd = "#0C7B4B",
  hapi_pse = "#1F6FEB",
  hapi_tarjeta = "#8B8B8B",
  etoro_manual_fx1.5 = "#3D8B6E",
  etoro_manual_fx3.0 = "#6AA88E",
  trii_std_1ticket = "#E39B2B",
  trii_std_5tickets = "#C0392B",
  trii_pro_1ticket = "#D68910",
  trii_pro_5tickets = "#922B21"
)

for (ap in APORTES_USD) {
  d <- res[res$anios == 10 & res$aporte_usd == ap, ]
  d <- d[match(esc_ord, d$escenario), ]
  d <- d[!is.na(d$escenario), ]
  barplot(
    d$drag_vs_cero,
    names.arg = d$escenario,
    col = unname(cols[d$escenario]),
    main = paste0("Drag vs. cero comisión — $", ap, "/mes × 10 años"),
    ylab = "USD de valor terminal perdido (10% anual)",
    cex.names = 0.7
  )
}
par(op)
dev.off()
cat("Gráfico: output/drag_10anios.png\n")
