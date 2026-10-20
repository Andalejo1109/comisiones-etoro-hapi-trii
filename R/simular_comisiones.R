# Simulación de comisiones: eToro vs Hapi vs Trii
# Caso Colombia — DCA mensual sobre un mismo libro de activos
# Rendimiento idéntico en todos los brokers: el único diferencial es el costo.
# Autor: Andrés Alejandro Rodríguez Lozano
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
GMF         <- 0.004         # 4x1000 sobre el débito de la cuenta bancaria (pago PSE o tarjeta)

PESOS <- c(SPYG = 0.35, SMH = 0.15, BRKB = 0.20, VTI = 0.10, IEMG = 0.20)
ES_ACCION <- c(SPYG = FALSE, SMH = FALSE, BRKB = TRUE, VTI = FALSE, IEMG = FALSE)
stopifnot(abs(sum(PESOS) - 1) < 1e-9)

# Conversión COP→USD: la TRM la fija el banco y como inversores en Colombia la
# aceptamos. No se modela ningún diferencial FX (fx = 0 en todas las plataformas).
#
# Tarifas usadas (octubre 2026). Verificar antes de decidir.
# eToro: depósito con tarjeta sin comisión de eToro; ETF $0; acción real (BRK.B) ~$1
#   por orden manual; CopyTrader sin costo adicional y sin comisión de acciones;
#   retiro US$5 (mín. US$30).
# Hapi: PSE 2% (supuesto del usuario; la ayuda de Hapi publica 0,45%, mín. US$1,99);
#   ~US$0,15 de clearing por orden fraccionada (supuesto); retiro a banco local US$4,99.
# Trii: depósito PSE $0; ticket COP 14.875 IVA incl. hasta COP 5M.
#
# Campos: dep_pct, dep_min (USD), fee_etf y fee_accion (USD por orden mensual),
#         sub_usd (USD/mes), retiro_usd (una vez al final).
TARIFAS <- list(
  cero = list(dep_pct = 0, dep_min = 0, fee_etf = 0, fee_accion = 0,
              sub_usd = 0, retiro_usd = 0),
  etoro_copy_tarjeta = list(dep_pct = 0, dep_min = 0, fee_etf = 0, fee_accion = 0,
                            sub_usd = 0, retiro_usd = 5),
  etoro_manual_tarjeta = list(dep_pct = 0, dep_min = 0, fee_etf = 0, fee_accion = 1,
                              sub_usd = 0, retiro_usd = 5),
  hapi_pse_2pct = list(dep_pct = 0.02, dep_min = 1.99, fee_etf = 0.15, fee_accion = 0.15,
                       sub_usd = 0, retiro_usd = 4.99),
  trii_std_1ticket = list(dep_pct = 0, dep_min = 0, fee_etf = NA, fee_accion = NA,
                          ticket_unico = 14875 / COP_POR_USD, sub_usd = 0, retiro_usd = 0),
  trii_std_5tickets = list(dep_pct = 0, dep_min = 0, fee_etf = 14875 / COP_POR_USD,
                           fee_accion = 14875 / COP_POR_USD, sub_usd = 0, retiro_usd = 0)
)

# ---------------------------------------------------------------------------
# 2. Motor
# ---------------------------------------------------------------------------
r_mes <- function(anual) (1 + anual)^(1 / 12) - 1

# Costo de trading por mes, explícito por activo (sin ramas frágiles):
# un ticket por activo con su tarifa según sea ETF o acción; o un ticket único.
fee_trading_mes <- function(tar) {
  if (!is.null(tar$ticket_unico)) return(tar$ticket_unico)
  sum(ifelse(ES_ACCION, tar$fee_accion, tar$fee_etf))
}

simular_uno <- function(aporte, anios, tar, anual = RENTA_ANUAL, gmf = GMF) {
  meses <- anios * 12
  rm <- r_mes(anual)
  port <- 0
  bruto <- g <- dep <- tr <- sub <- invertido <- 0
  fee_tr_mes <- fee_trading_mes(tar)

  for (m in seq_len(meses)) {
    bruto <- bruto + aporte
    fee_gmf <- aporte * gmf
    g <- g + fee_gmf
    fee_dep <- max(aporte * tar$dep_pct, if (aporte > 0) tar$dep_min else 0)
    dep <- dep + fee_dep
    sub <- sub + tar$sub_usd
    tr <- tr + fee_tr_mes
    neto <- max(aporte - fee_gmf - fee_dep - tar$sub_usd - fee_tr_mes, 0)
    invertido <- invertido + neto
    port <- port * (1 + rm) + neto
  }
  port <- port - tar$retiro_usd

  list(bruto = bruto, invertido = invertido, fee_gmf = g, fee_deposito = dep,
       fee_trading = tr, fee_suscripcion = sub, fee_retiro = tar$retiro_usd,
       fees_total = g + dep + tr + sub + tar$retiro_usd, terminal = port)
}

# ---------------------------------------------------------------------------
# 3. Correr grilla
# ---------------------------------------------------------------------------
filas <- list()
i <- 1
for (anios in HORIZONTES) {
  for (aporte in APORTES_USD) {
    base <- simular_uno(aporte, anios, TARIFAS$cero, gmf = 0)
    for (nm in names(TARIFAS)) {
      r <- simular_uno(aporte, anios, TARIFAS[[nm]], gmf = if (nm == "cero") 0 else GMF)
      filas[[i]] <- data.frame(
        escenario = nm, aporte_usd = aporte, anios = anios,
        aportes_brutos = round(r$bruto, 2), invertido_neto = round(r$invertido, 2),
        fee_gmf = round(r$fee_gmf, 2), fee_deposito = round(r$fee_deposito, 2),
        fee_trading = round(r$fee_trading, 2), fee_suscripcion = round(r$fee_suscripcion, 2),
        fee_retiro = round(r$fee_retiro, 2), fees_total = round(r$fees_total, 2),
        fees_pct_bruto = round(100 * r$fees_total / r$bruto, 2),
        terminal_10pct = round(r$terminal, 2),
        drag_vs_cero = round(base$terminal - r$terminal, 2),
        stringsAsFactors = FALSE)
      i <- i + 1
    }
  }
}

res <- do.call(rbind, filas)
res <- res[order(res$anios, res$aporte_usd, res$fees_total), ]
# Validaciones
stopifnot(all(res$fees_total >= 0), all(res$drag_vs_cero >= -1e-6),
          all(abs(res$aportes_brutos - res$aporte_usd * res$anios * 12) < 1e-6))
write.csv(res, "output/resultados_comisiones.csv", row.names = FALSE)

compacta <- res[res$anios == 10, c("escenario", "aporte_usd", "aportes_brutos", "fees_total",
                                   "fees_pct_bruto", "terminal_10pct", "drag_vs_cero")]
write.csv(compacta, "output/tabla_10anios.csv", row.names = FALSE)

cat("=== Resultados (renta anual 10%, TRM", COP_POR_USD, ", GMF 4x1000) ===\n")
print(res, row.names = FALSE)
for (ap in APORTES_USD) {
  d <- res[res$anios == 10 & res$aporte_usd == ap & res$escenario != "cero", ]
  cat("Menor costo $", ap, "/mes 10 años: ", d$escenario[which.min(d$fees_total)], "\n", sep = "")
}

# ---------------------------------------------------------------------------
# 4. Gráfico (base R, sin dependencias)
# ---------------------------------------------------------------------------
cols <- c(cero = "#2f2f2f", etoro_copy_tarjeta = "#12C47A", etoro_manual_tarjeta = "#0C7B4B",
          hapi_pse_2pct = "#1F6FEB", trii_std_1ticket = "#E39B2B", trii_std_5tickets = "#C0392B")
dibujar <- function() {
  op <- par(mfrow = c(1, 2), mar = c(10, 5, 3, 1), las = 2)
  for (ap in APORTES_USD) {
    d <- res[res$anios == 10 & res$aporte_usd == ap, ]
    barplot(d$drag_vs_cero, names.arg = d$escenario, col = unname(cols[d$escenario]),
            main = paste0("Drag vs. cero comisión — $", ap, "/mes × 10 años"),
            ylab = "USD de valor terminal perdido (10% anual)", cex.names = 0.7)
  }
  par(op)
}
png("output/drag_10anios.png", width = 1400, height = 800, res = 120); dibujar(); dev.off()
svg("output/drag_10anios.svg", width = 11.7, height = 6.7); dibujar(); dev.off()
cat("Archivos: output/resultados_comisiones.csv, output/tabla_10anios.csv, output/drag_10anios.png/.svg\n")
