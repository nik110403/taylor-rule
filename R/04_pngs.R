source("R/config.R")

df  <- readRDS(file.path(DATA_DIR, "df_analysis.rds"))
ccf <- readRDS(file.path(DATA_DIR, "df_ccf.rds"))

dir.create(file.path(PROJECT_ROOT, "output/figures"), recursive = TRUE, showWarnings = FALSE)
fig_dir <- file.path(PROJECT_ROOT, "output/figures")

# ── Palette (light-mode hex, suitable for print / white backgrounds) ──────────
pal <- list(
  actual  = "#1C1C1A",
  taylor1 = "#185FA5",
  taylor2 = "#1D9E75",
  taylor3 = "#BA7517",
  dev_pos = "#D85A30",
  dev_neg = "#185FA5",
  ecb     = "#534AB7",
  infl    = "#A32D2D",
  target  = "#dc2626",
  grid    = "#e5e5e5",
  muted   = "#888888",
  covid   = rgb(185, 210, 235, 80, maxColorValue = 255)
)

format_date_labels <- function(dates) {
  q <- as.integer(ceiling(as.integer(format(dates, "%m")) / 3))
  paste0(format(dates, "%Y"), "-Q", q)
}

footer_text <- function(line = 3.2) {
  mtext("Source: FRED, CBO. Author's calculations.  |  nikkhosravipour.com",
        side = 1, line = line, cex = 0.62, col = pal$muted, adj = 0)
}

# ── Figure 0: Hook ────────────────────────────────────────────────────────────

png(file.path(fig_dir, "fig0_hook.png"),
    width = 900, height = 380, res = 120, bg = "white")

fig0   <- dplyr::filter(df, !is.na(Dev_1), !is.na(PCEPILFE))
xlabs0 <- format_date_labels(fig0$date)
x0     <- seq_along(fig0$date)
show_x0 <- x0[x0 %% 4 == 1]
vals0  <- fig0$Dev_1
infl0  <- fig0$PCEPILFE

y_left0  <- range(vals0, na.rm = TRUE)
y_right0 <- range(infl0, na.rm = TRUE)
scale_r2l0 <- function(y) y_left0[1] + (y - y_right0[1]) / diff(y_right0) * diff(y_left0)

par(mar = c(4.5, 3.8, 3.5, 4.2), family = "sans")
plot(x0, vals0, type = "n",
     xlim = c(1, length(x0)),
     ylim = c(min(y_left0) - 0.5, max(y_left0) + 1.5),
     xaxt = "n", yaxt = "n", xlab = "", ylab = "", bty = "n")

covid1_0 <- match("2020-Q1", xlabs0); covid2_0 <- match("2022-Q1", xlabs0)
if (!is.na(covid1_0) && !is.na(covid2_0))
  rect(covid1_0, par("usr")[3], covid2_0, par("usr")[4], col = pal$covid, border = NA)

abline(h = axTicks(2), col = pal$grid, lwd = 0.7)

polygon(c(x0, rev(x0)), c(pmax(vals0, 0), rep(0, length(x0))),
        col = adjustcolor(pal$dev_pos, 0.35), border = NA)
polygon(c(x0, rev(x0)), c(pmin(vals0, 0), rep(0, length(x0))),
        col = adjustcolor(pal$dev_neg, 0.25), border = NA)

abline(h = 0, lty = 2, col = pal$muted, lwd = 0.9)
mtext("Rules-based prescription", side = 1, line = -0.5, cex = 0.58,
      col = pal$muted, adj = 0.98)

lines(x0, vals0, col = pal$dev_pos, lwd = 1.8)
lines(x0, scale_r2l0(infl0), col = pal$infl, lwd = 1.5, lty = 2)

for (a in list(list(lbl="2020-Q3", txt="AIT",   ln=0.2),
               list(lbl="2021-Q4", txt="Taper", ln=1.3),
               list(lbl="2022-Q1", txt="Hike",  ln=0.2))) {
  xi <- match(a$lbl, xlabs0)
  if (!is.na(xi)) {
    abline(v = xi, lty = 3, col = pal$muted, lwd = 0.7)
    mtext(a$txt, side = 3, at = xi, line = a$ln, cex = 0.55, col = pal$muted)
  }
}

axis(1, at = show_x0, labels = xlabs0[show_x0], tick = FALSE,
     cex.axis = 0.68, col.axis = pal$muted, gap.axis = 0)
axis(2, at = axTicks(2), labels = paste0(axTicks(2), "pp"),
     las = 1, cex.axis = 0.72, col.axis = pal$muted, col = NA)
right_ticks0 <- pretty(y_right0, n = 5)
axis(4, at = scale_r2l0(right_ticks0), labels = paste0(right_ticks0, "%"),
     las = 1, cex.axis = 0.72, col.axis = pal$infl, col = NA, tick = FALSE)

mtext("Policy gap (pp)", side = 2, line = 2.7, cex = 0.70, col = pal$muted)
mtext("Core PCE (%)",    side = 4, line = 3.0, cex = 0.70, col = pal$infl)

legend("topleft", inset = c(0.01, 0.01),
       legend = c("Policy gap (Taylor deviation)", "Core PCE inflation"),
       col = c(pal$dev_pos, pal$infl), lwd = c(1.8, 1.5), lty = c(1, 2),
       bty = "n", cex = 0.68, seg.len = 1.8)

mtext("The Fed's Departure from Rules-Based Policy",
      side = 3, line = 2.2, cex = 0.88, font = 2, adj = 0)
mtext("Baseline Taylor Rule deviation and core PCE inflation · quarterly",
      side = 3, line = 1.1, cex = 0.70, col = pal$muted, adj = 0)

footer_text()
dev.off()

# ── Figure 1: Taylor vs. Actual ───────────────────────────────────────────────

png(file.path(fig_dir, "fig1_taylor_vs_actual.png"),
    width = 900, height = 420, res = 120, bg = "white")

fig1 <- dplyr::filter(df, !is.na(FEDFUNDS))
dates <- fig1$date
xlabs <- format_date_labels(dates)
x_idx <- seq_along(dates)
show_x <- x_idx[x_idx %% 4 == 1]
y_rng  <- range(c(fig1$FEDFUNDS, fig1$Taylor_1, fig1$Taylor_2, fig1$Taylor_3),
                na.rm = TRUE)

par(mar = c(4.5, 3.8, 3.5, 1.2), family = "sans")
plot(x_idx, fig1$FEDFUNDS, type = "n",
     xlim = c(1, length(dates)), ylim = c(min(y_rng) - 0.3, max(y_rng) + 0.5),
     xaxt = "n", yaxt = "n", xlab = "", ylab = "", bty = "n")

# COVID shading
covid1 <- match("2020-Q1", xlabs); covid2 <- match("2022-Q1", xlabs)
if (!is.na(covid1) && !is.na(covid2))
  rect(covid1, par("usr")[3], covid2, par("usr")[4],
       col = pal$covid, border = NA)

abline(h = axTicks(2), col = pal$grid, lwd = 0.7)
abline(h = 0, lty = 2, col = pal$muted, lwd = 0.8)

lines(x_idx, fig1$Taylor_1, col = pal$taylor1, lwd = 1.4, lty = 2)
lines(x_idx, fig1$Taylor_2, col = pal$taylor2, lwd = 1.4, lty = 2)
lines(x_idx, fig1$Taylor_3, col = pal$taylor3, lwd = 1.4, lty = 3)
lines(x_idx, fig1$FEDFUNDS, col = pal$actual,  lwd = 2.2)

axis(1, at = show_x, labels = xlabs[show_x], tick = FALSE,
     cex.axis = 0.68, col.axis = pal$muted, gap.axis = 0)
axis(2, at = axTicks(2), labels = paste0(axTicks(2), "%"),
     las = 1, cex.axis = 0.72, col.axis = pal$muted, col = NA)

mtext("Federal Reserve Policy vs. Rules-Based Prescriptions",
      side = 3, line = 2.2, cex = 0.88, font = 2, adj = 0)
mtext("Effective federal funds rate and three Taylor Rule variants, 2015–2024 · percent",
      side = 3, line = 1.1, cex = 0.70, col = pal$muted, adj = 0)
mtext("Rate (%)", side = 2, line = 2.7, cex = 0.70, col = pal$muted)

legend("topleft", inset = c(0.01, 0.01),
       legend = c("Actual EFFR", "Taylor (r*=0.5%)", "Taylor (r*=1.0%)", "Inertial Taylor"),
       col    = c(pal$actual, pal$taylor1, pal$taylor2, pal$taylor3),
       lwd    = c(2.2, 1.4, 1.4, 1.4),
       lty    = c(1, 2, 2, 3),
       bty    = "n", cex = 0.68, seg.len = 1.8)

footer_text()
dev.off()

# ── Figure 2: Deviation bars ──────────────────────────────────────────────────

png(file.path(fig_dir, "fig2_deviation.png"),
    width = 900, height = 360, res = 120, bg = "white")

fig2  <- dplyr::filter(df, !is.na(Dev_1))
xlabs2 <- format_date_labels(fig2$date)
vals   <- fig2$Dev_1
cols   <- ifelse(vals > 0, pal$dev_pos, pal$dev_neg)
show_x2 <- seq_along(vals)[seq_along(vals) %% 4 == 1]

par(mar = c(4.5, 3.8, 3.5, 1.2), family = "sans")
bp <- barplot(vals, col = cols, border = NA,
              ylim = c(min(vals) - 0.5, max(vals) + 1.2),
              yaxt = "n", xaxt = "n", space = 0.2)

abline(h = 0, lty = 2, col = pal$muted, lwd = 0.9)
mtext("Rules-based prescription", side = 1, line = -0.5, cex = 0.58,
      col = pal$muted, adj = 0.98)

axis(2, at = axTicks(2), labels = paste0(axTicks(2), "pp"),
     las = 1, cex.axis = 0.72, col.axis = pal$muted, col = NA)
axis(1, at = bp[show_x2], labels = xlabs2[show_x2], tick = FALSE,
     cex.axis = 0.68, col.axis = pal$muted)

peak_i <- which.max(vals)
text(bp[peak_i], vals[peak_i] + 0.85,
     paste0(xlabs2[peak_i], "\n+", round(vals[peak_i], 1), "pp"),
     cex = 0.62, col = pal$dev_pos, font = 2)

mtext("Policy Gap: Taylor Rule Prescription Minus Actual Rate",
      side = 3, line = 2.2, cex = 0.88, font = 2, adj = 0)
mtext("Quarterly deviation in percentage points · positive = policy too loose",
      side = 3, line = 1.1, cex = 0.70, col = pal$muted, adj = 0)

footer_text()
dev.off()

# ── Figure 3: Scatter ─────────────────────────────────────────────────────────

png(file.path(fig_dir, "fig3_scatter.png"),
    width = 900, height = 500, res = 120, bg = "white")

df_scatter <- df |>
  dplyr::select(date, Dev_1, PCEPILFE) |>
  dplyr::filter(!is.na(Dev_1), !is.na(PCEPILFE)) |>
  dplyr::mutate(infl_lead3 = dplyr::lead(PCEPILFE, 2)) |>
  dplyr::filter(!is.na(infl_lead3)) |>
  dplyr::rename(dev1 = Dev_1)

fit       <- lm(infl_lead3 ~ dev1, data = df_scatter)
r2        <- summary(fit)$r.squared
x_seq     <- seq(min(df_scatter$dev1), max(df_scatter$dev1), length.out = 80)
y_hat     <- predict(fit, newdata = data.frame(dev1 = x_seq))

year_ramp <- colorRampPalette(c("#93c5fd", "#1e3a8a"))(10)
pt_cols   <- year_ramp[as.integer(format(df_scatter$date, "%Y")) - 2014L]

par(mar = c(5.5, 4.0, 3.5, 1.2), family = "sans")
plot(df_scatter$dev1, df_scatter$infl_lead3,
     col = pt_cols, pch = 19, cex = 1.1,
     xlab = "", ylab = "",
     xaxt = "n", yaxt = "n", bty = "n")

abline(h = axTicks(2), col = pal$grid, lwd = 0.7)
abline(v = axTicks(1), col = pal$grid, lwd = 0.7)
lines(x_seq, y_hat, col = pal$infl, lwd = 1.5, lty = 2)

axis(1, at = axTicks(1), labels = paste0(axTicks(1), "pp"),
     cex.axis = 0.72, col.axis = pal$muted, col = NA)
axis(2, at = axTicks(2), labels = paste0(axTicks(2), "%"),
     las = 1, cex.axis = 0.72, col.axis = pal$muted, col = NA)

mtext("Taylor deviation (pp, positive = too loose)", side = 1, line = 2.8,
      cex = 0.70, col = pal$muted)
mtext("Core PCE, % YoY (t+2)", side = 2, line = 2.9, cex = 0.70, col = pal$muted)

text(par("usr")[2], par("usr")[3] + 0.15,
     paste0("R² = ", round(r2, 2)), adj = 1, cex = 0.72, col = pal$muted)

mtext("Policy Looseness and Subsequent Inflation",
      side = 3, line = 2.2, cex = 0.88, font = 2, adj = 0)
mtext("Taylor Rule deviation in quarter t vs. core PCE inflation two quarters later · 2015–2024",
      side = 3, line = 1.1, cex = 0.70, col = pal$muted, adj = 0)

legend("topleft", inset = c(0.01, 0.01),
       legend = c("2015", "2019", "2024", "OLS trend"),
       col    = c(year_ramp[1], year_ramp[5], year_ramp[10], pal$infl),
       pch    = c(19, 19, 19, NA), lty = c(NA, NA, NA, 2),
       lwd    = c(NA, NA, NA, 1.5), pt.cex = 0.9,
       bty = "n", cex = 0.65)

footer_text(line = 4.5)
dev.off()

# ── Figure 4: ECB comparison ──────────────────────────────────────────────────

png(file.path(fig_dir, "fig4_ecb.png"),
    width = 900, height = 400, res = 120, bg = "white")

fig4 <- df |>
  dplyr::rename(ea_inflation = CP0000EZ19M086NEST) |>
  dplyr::select(date, ECB_Dev, ea_inflation) |>
  dplyr::filter(!is.na(ECB_Dev), !is.na(ea_inflation))

xlabs4 <- format_date_labels(fig4$date)
x4     <- seq_along(fig4$date)
show_x4 <- x4[x4 %% 4 == 1]

y_left  <- range(fig4$ECB_Dev,     na.rm = TRUE)
y_right <- range(fig4$ea_inflation, na.rm = TRUE)

par(mar = c(4.5, 3.8, 3.5, 4.2), family = "sans")
plot(x4, fig4$ECB_Dev, type = "n",
     xlim = c(1, length(x4)),
     ylim = c(min(y_left) - 0.5, max(y_left) + 1),
     xaxt = "n", yaxt = "n", xlab = "", ylab = "", bty = "n")

covid1_4 <- match("2020-Q1", xlabs4); covid2_4 <- match("2022-Q1", xlabs4)
if (!is.na(covid1_4) && !is.na(covid2_4))
  rect(covid1_4, par("usr")[3], covid2_4, par("usr")[4],
       col = pal$covid, border = NA)

abline(h = axTicks(2), col = pal$grid, lwd = 0.7)
abline(h = 0, lty = 2, col = pal$muted, lwd = 0.8)

lines(x4, fig4$ECB_Dev, col = pal$ecb, lwd = 1.8, lty = 2)

# Right axis: scale ea_inflation onto left-axis coordinates
scale_r2l <- function(y) {
  y_left[1] + (y - y_right[1]) / diff(y_right) * diff(y_left)
}
lines(x4, scale_r2l(fig4$ea_inflation), col = pal$infl, lwd = 1.8)

axis(1, at = show_x4, labels = xlabs4[show_x4], tick = FALSE,
     cex.axis = 0.68, col.axis = pal$muted, gap.axis = 0)
axis(2, at = axTicks(2), labels = paste0(axTicks(2), "pp"),
     las = 1, cex.axis = 0.72, col.axis = pal$muted, col = NA)

right_ticks <- pretty(y_right, n = 5)
axis(4, at = scale_r2l(right_ticks), labels = paste0(right_ticks, "%"),
     las = 1, cex.axis = 0.72, col.axis = pal$infl, col = NA, tick = FALSE)

mtext("Policy gap (pp)", side = 2, line = 2.7, cex = 0.70, col = pal$muted)
mtext("HICP % YoY", side = 4, line = 3.0, cex = 0.70, col = pal$infl)

legend("topleft", inset = c(0.01, 0.01),
       legend = c("ECB policy gap", "Euro area HICP"),
       col = c(pal$ecb, pal$infl), lwd = 1.8, lty = c(2, 1),
       bty = "n", cex = 0.68, seg.len = 1.8)

mtext("ECB Policy Deviation and Euro Area Inflation, 2018–2024",
      side = 3, line = 2.2, cex = 0.88, font = 2, adj = 0)
mtext("Simplified Taylor prescription minus ECB deposit rate, vs. HICP · output gap approximated",
      side = 3, line = 1.1, cex = 0.70, col = pal$muted, adj = 0)

footer_text()
dev.off()

# ── Figure 5: Cross-correlation ───────────────────────────────────────────────

png(file.path(fig_dir, "fig5_ccf.png"),
    width = 900, height = 340, res = 120, bg = "white")

lags  <- ccf$lag
corrs <- ccf$correlation
cols5 <- ifelse(corrs > 0, pal$dev_pos, pal$dev_neg)

par(mar = c(5.5, 4.0, 3.5, 1.2), family = "sans")
bp5 <- barplot(corrs, col = cols5, border = NA,
               ylim = c(min(corrs) - 0.1, max(corrs) + 0.15),
               names.arg = paste0("t+", lags),
               yaxt = "n", xaxt = "n", space = 0.35, width = 0.65)

abline(h = 0, lty = 2, col = pal$muted, lwd = 0.9)
axis(2, las = 1, cex.axis = 0.72, col.axis = pal$muted, col = NA)
axis(1, at = bp5, labels = paste0("t+", lags), tick = FALSE,
     cex.axis = 0.72, col.axis = pal$muted)

peak_i5 <- which.max(abs(corrs))
text(bp5[peak_i5], corrs[peak_i5] + 0.03,
     paste0("t+", lags[peak_i5], "\nr=", round(corrs[peak_i5], 2)),
     cex = 0.62, col = pal$dev_pos, font = 2)

mtext("How Many Quarters Does Policy Looseness Lead Inflation?",
      side = 3, line = 2.2, cex = 0.88, font = 2, adj = 0)
mtext("Cross-correlation: Taylor Rule deviation vs. core PCE · lags 0–8 quarters",
      side = 3, line = 1.1, cex = 0.70, col = pal$muted, adj = 0)
mtext("Lead of inflation (quarters after deviation)", side = 1, line = 2.8,
      cex = 0.70, col = pal$muted)
mtext("Correlation", side = 2, line = 2.9, cex = 0.70, col = pal$muted)

footer_text(line = 4.5)
dev.off()

# ── Summary ───────────────────────────────────────────────────────────────────

figs <- c("fig0_hook.png",
          paste0("fig", 1:5, c("_taylor_vs_actual","_deviation","_scatter","_ecb","_ccf"), ".png"))
cat("\n── PNG output ───────────────────────────────────────────────────────────\n")
for (f in figs) {
  p <- file.path(fig_dir, f)
  cat(sprintf("  %-38s  %s\n", f,
              if (file.exists(p)) paste0(format(file.size(p), big.mark=","), " bytes")
              else "NOT FOUND"))
}
cat("─────────────────────────────────────────────────────────────────────────\n\n")
