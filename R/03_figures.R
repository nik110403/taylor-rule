source("R/config.R")
library(dplyr)

df_analysis <- readRDS(file.path(DATA_DIR, "df_analysis.rds"))
df_ccf      <- readRDS(file.path(DATA_DIR, "df_ccf.rds"))

dir.create(WIDGETS_DIR, recursive = TRUE, showWarnings = FALSE)

# ── Helpers ───────────────────────────────────────────────────────────────────

format_js_array <- function(vec, digits = 2) {
  vals <- ifelse(is.na(vec), "null",
                 formatC(round(as.numeric(vec), digits), format = "f", digits = digits))
  paste0("[", paste(vals, collapse = ", "), "]")
}

format_date_labels <- function(dates) {
  q <- as.integer(ceiling(as.integer(format(dates, "%m")) / 3))
  paste0(format(dates, "%Y"), "-Q", q)
}

format_scatter_js <- function(x_vec, y_vec, digits = 3) {
  pts <- mapply(function(x, y) {
    if (is.na(x) || is.na(y)) return("null")
    paste0("{x:", round(x, digits), ",y:", round(y, digits), "}")
  }, x_vec, y_vec)
  paste0("[", paste(pts, collapse = ","), "]")
}

stat_card_html <- function(label, value) {
  paste0(
    '<div style="background:var(--bg-soft);border:1px solid var(--border);',
    'border-radius:6px;padding:8px 12px;">',
    '<div style="font-size:0.68rem;color:var(--muted);text-transform:uppercase;',
    'letter-spacing:.05em;margin-bottom:2px;">', label, '</div>',
    '<div style="font-size:1.05rem;font-weight:600;color:var(--text);">', value, '</div>',
    '</div>'
  )
}

stat_cards_html <- function(cards, ncols = 3) {
  paste0(
    '<div style="display:grid;grid-template-columns:repeat(', ncols, ',1fr);',
    'gap:8px;margin-bottom:12px;">',
    paste(cards, collapse = ""),
    '</div>\n'
  )
}

fig_header_html <- function(context, title, subtitle) {
  paste0(
    '<p style="margin:0 0 3px;font-size:10px;letter-spacing:0.13em;',
    'text-transform:uppercase;color:var(--muted);">', context, '</p>\n',
    '<p style="margin:0 0 3px;font-size:18px;font-weight:500;',
    'color:var(--text);line-height:1.3;">', title, '</p>\n',
    '<p style="margin:0 0 18px;font-size:12px;color:var(--muted);">', subtitle, '</p>\n'
  )
}

legend_row_html <- function(items) {
  paste0(
    '<div style="display:flex;flex-wrap:wrap;gap:16px;margin-bottom:12px;">',
    paste(items, collapse = ""),
    '</div>\n'
  )
}

legend_line_html <- function(data_k, label) {
  paste0(
    '<span style="display:inline-flex;align-items:center;gap:6px;',
    'font-size:11px;color:var(--muted);">',
    '<span data-k="', data_k, '" style="display:inline-block;width:20px;height:2px;',
    'background:#888;border-radius:1px;flex-shrink:0;"></span>', label, '</span>'
  )
}

legend_dashed_html <- function(data_k, label) {
  paste0(
    '<span style="display:inline-flex;align-items:center;gap:6px;',
    'font-size:11px;color:var(--muted);">',
    '<span data-k="', data_k, '" data-dash="1" style="display:inline-block;',
    'width:20px;height:0;border-bottom:2px dashed #888;flex-shrink:0;"></span>',
    label, '</span>'
  )
}

legend_bar_html <- function(data_k, label) {
  paste0(
    '<span style="display:inline-flex;align-items:center;gap:6px;',
    'font-size:11px;color:var(--muted);">',
    '<span data-k="', data_k, '" style="display:inline-block;width:10px;height:10px;',
    'border-radius:2px;background:#888;flex-shrink:0;"></span>', label, '</span>'
  )
}

footer_html <- function() {
  paste0(
    '<div style="margin-top:14px;padding-top:10px;border-top:1px solid var(--border);',
    'display:flex;justify-content:space-between;font-size:10px;',
    'color:var(--muted);letter-spacing:0.02em;">',
    '<span>Source: <a href="https://fred.stlouisfed.org/" target="_blank" rel="noopener" ',
    'style="color:inherit;text-decoration:underline;">Federal Reserve Economic Data (FRED)</a>, ',
    'CBO. Author&#8217;s calculations.</span>',
    '<a href="https://nikkhosravipour.com" target="_blank" rel="noopener" ',
    'style="color:inherit;text-decoration:underline;">nikkhosravipour.com</a>',
    '</div>\n'
  )
}

# ── JS building blocks ────────────────────────────────────────────────────────

JS_PALETTE <- "  function palette() {
    var light = document.documentElement.classList.contains('is-light');
    return {
      tick:    light ? 'rgba(0,0,0,0.42)'       : 'rgba(255,255,255,0.5)',
      grid:    light ? 'rgba(0,0,0,0.06)'       : 'rgba(255,255,255,0.07)',
      yTick:   light ? 'rgba(0,0,0,0.65)'       : 'rgba(255,255,255,0.7)',
      actual:  light ? '#1C1C1A'                : '#E8E6DF',
      taylor1: light ? '#185FA5'                : '#60a5fa',
      taylor2: light ? '#1D9E75'                : '#34d399',
      taylor3: light ? '#BA7517'                : '#f59e0b',
      dev_pos: light ? '#D85A30'                : '#f87171',
      dev_neg: light ? '#185FA5'                : '#60a5fa',
      ecb:     light ? '#534AB7'                : '#a78bfa',
      infl:    light ? '#A32D2D'                : '#ef4444',
      covid:   light ? 'rgba(185,210,235,0.35)' : 'rgba(96,165,250,0.12)',
      text:    light ? '#1C1C1A'                : '#E8E6DF',
      muted:   light ? 'rgba(0,0,0,0.50)'       : 'rgba(255,255,255,0.55)',
    };
  }"

JS_SWATCH <- "    scope.querySelectorAll('[data-k]').forEach(function(sw) {
      if (sw.dataset.dash) sw.style.borderBottomColor = c[sw.dataset.k];
      else sw.style.background = c[sw.dataset.k];
    });"

js_open <- function(cid) {
  paste0(
    "</figure>\n<script>\n(function () {\n",
    "  window.__chartjs = window.__chartjs || new Promise(function(resolve) {\n",
    "    if (window.Chart) return resolve();\n",
    "    var s = document.createElement('script');\n",
    "    s.src = 'https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.js';\n",
    "    s.onload = resolve;\n",
    "    document.head.appendChild(s);\n",
    "  });\n",
    "  var canvas = document.getElementById('", cid, "');\n",
    "  if (!canvas) return;\n",
    "  var scope = canvas.closest('figure');\n",
    "  var chart;\n"
  )
}

JS_CLOSE <- "  window.__chartjs.then(function() {
    render();
    new MutationObserver(render).observe(document.documentElement, { attributes: true, attributeFilter: ['class'] });
  });
})();
</script>"

COVID_PLUGIN <- "    var covidPlugin = {
      id: 'covidShade',
      afterDraw: function(chart) {
        var ctx = chart.ctx, ca = chart.chartArea, xs = chart.scales.x;
        var i1 = labels.indexOf('2020-Q1'), i2 = labels.indexOf('2022-Q1');
        if (i1 < 0 || i2 < 0) return;
        var px1 = xs.getPixelForValue(i1), px2 = xs.getPixelForValue(i2);
        ctx.save();
        ctx.fillStyle = c.covid;
        ctx.fillRect(px1, ca.top, px2 - px1, ca.bottom - ca.top);
        ctx.restore();
      }
    };"

ZERO_LINE_PLUGIN <- "    var zeroLinePlugin = {
      id: 'zeroLine',
      afterDraw: function(chart) {
        var ctx = chart.ctx, ca = chart.chartArea, ys = chart.scales.y;
        var y0 = ys.getPixelForValue(0);
        ctx.save();
        ctx.strokeStyle = c.tick; ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);
        ctx.beginPath(); ctx.moveTo(ca.left, y0); ctx.lineTo(ca.right, y0); ctx.stroke();
        ctx.setLineDash([]);
        ctx.fillStyle = c.tick;
        ctx.font = '9px system-ui, sans-serif';
        ctx.textAlign = 'right';
        ctx.fillText('Rules-based prescription', ca.right - 4, y0 - 4);
        ctx.restore();
      }
    };"

X_SCALE_QTR <- "          x: {
            border: { display: false },
            grid: { color: c.grid },
            ticks: { color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' },
              maxRotation: 0, autoSkip: false,
              callback: function(val, i) { return i % 4 === 0 ? labels[i] : null; } }
          }"

CHART_OPTIONS_HEAD <- "      options: {
        responsive: true, maintainAspectRatio: false, animation: false,
        layout: { padding: { top: 26, right: 20, left: 0, bottom: 4 } },
        interaction: { mode: 'index', intersect: false },
        plugins: { legend: { display: false }, title: { display: false } },"

# ── Figure 1: Taylor vs. Actual ───────────────────────────────────────────────

fig1_data <- df_analysis |>
  dplyr::filter(!is.na(FEDFUNDS)) |>
  dplyr::select(date, FEDFUNDS, Taylor_1, Taylor_2, Taylor_3, Dev_1, PCEPILFE)

peak_dev1    <- max(fig1_data$Dev_1,    na.rm = TRUE)
zlb_quarters <- sum(fig1_data$FEDFUNDS < 0.15, na.rm = TRUE)
peak_pce     <- max(fig1_data$PCEPILFE, na.rm = TRUE)

date_labels_1 <- format_date_labels(fig1_data$date)
labels_js_1   <- paste0('["', paste(date_labels_1, collapse = '","'), '"]')
fedfunds_js   <- format_js_array(fig1_data$FEDFUNDS)
taylor1_js    <- format_js_array(fig1_data$Taylor_1)
taylor2_js    <- format_js_array(fig1_data$Taylor_2)
taylor3_js    <- format_js_array(fig1_data$Taylor_3)

html_fig1 <- paste0(
  '<figure class="chart-embed" style="margin:0; font-family:var(--font-body);">\n',
  fig_header_html(
    "Federal Reserve · Deep Dive · 2015–2024",
    "Federal Reserve Policy vs. Rules-Based Prescriptions",
    "Effective federal funds rate and three Taylor Rule variants · percent · quarterly"
  ),
  stat_cards_html(list(
    stat_card_html("Peak deviation",          sprintf("+%.1fpp", peak_dev1)),
    stat_card_html("Quarters at zero bound",  as.character(zlb_quarters)),
    stat_card_html("Peak core PCE",           sprintf("%.1f%%", peak_pce))
  ), ncols = 3),
  legend_row_html(list(
    legend_line_html("actual",  "Actual EFFR"),
    legend_dashed_html("taylor1", "Taylor (baseline, r*=0.5%)"),
    legend_dashed_html("taylor2", "Taylor (r*=1.0%)"),
    legend_dashed_html("taylor3", "Inertial Taylor")
  )),
  '<div style="position:relative; width:100%; height:260px;">\n',
  '<canvas id="taylor-fig1" role="img" aria-label="Line chart: Taylor Rule variants vs actual federal funds rate, 2015-2024"></canvas>\n',
  '</div>\n',
  footer_html(),
  js_open("taylor-fig1"),
  JS_PALETTE, "\n",
  "  function render() {\n",
  "    if (!window.Chart) return;\n",
  "    var c = palette();\n",
  JS_SWATCH, "\n",
  "    var labels = ", labels_js_1, ";\n",
  COVID_PLUGIN, "\n",
  "    if (chart) chart.destroy();\n",
  "    chart = new Chart(canvas, {\n",
  "      type: 'line',\n",
  "      plugins: [covidPlugin],\n",
  "      data: {\n",
  "        labels: labels,\n",
  "        datasets: [\n",
  "          { label: 'Actual EFFR', data: ", fedfunds_js, ",\n",
  "            borderColor: c.actual, borderWidth: 3, pointRadius: 0, tension: 0.3, fill: false },\n",
  "          { label: 'Taylor (baseline)', data: ", taylor1_js, ",\n",
  "            borderColor: c.taylor1, borderWidth: 1.5, borderDash: [6,3], pointRadius: 0, tension: 0.3, fill: false },\n",
  "          { label: 'Taylor (r*=1.0%)', data: ", taylor2_js, ",\n",
  "            borderColor: c.taylor2, borderWidth: 1.5, borderDash: [6,3], pointRadius: 0, tension: 0.3, fill: false },\n",
  "          { label: 'Inertial Taylor', data: ", taylor3_js, ",\n",
  "            borderColor: c.taylor3, borderWidth: 1.5, borderDash: [3,3], pointRadius: 0, tension: 0.3, fill: false }\n",
  "        ]\n",
  "      },\n",
  CHART_OPTIONS_HEAD, "\n",
  "        scales: {\n",
  X_SCALE_QTR, ",\n",
  "          y: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            ticks: { color: c.yTick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return v + '%'; } }\n",
  "          }\n",
  "        }\n",
  "      }\n",
  "    });\n",
  "  }\n",
  JS_CLOSE
)

writeLines(html_fig1, file.path(WIDGETS_DIR, "fig1_taylor_vs_actual.html"))

# ── Figure 2: Policy Deviation Bars ──────────────────────────────────────────

fig2_data <- df_analysis |>
  dplyr::filter(!is.na(Dev_1)) |>
  dplyr::select(date, Dev_1)

peak_dev_val  <- max(fig2_data$Dev_1, na.rm = TRUE)
peak_dev_lbl  <- format_date_labels(fig2_data$date)[which.max(fig2_data$Dev_1)]
excess_loose  <- sum(fig2_data$Dev_1 > 0, na.rm = TRUE)

date_labels_2 <- format_date_labels(fig2_data$date)
labels_js_2   <- paste0('["', paste(date_labels_2, collapse = '","'), '"]')
dev1_js_2     <- format_js_array(fig2_data$Dev_1)

html_fig2 <- paste0(
  '<figure class="chart-embed" style="margin:0; font-family:var(--font-body);">\n',
  fig_header_html(
    "Federal Reserve · Deep Dive · 2015–2024",
    "Policy Gap: Taylor Rule Prescription Minus Actual Rate",
    "Quarterly deviation in percentage points · positive = policy too loose relative to rules-based benchmark"
  ),
  stat_cards_html(list(
    stat_card_html("Peak policy gap",             sprintf("+%.1fpp", peak_dev_val)),
    stat_card_html("Quarters of excess looseness", as.character(excess_loose))
  ), ncols = 2),
  legend_row_html(list(
    legend_bar_html("dev_pos", "Too loose (above prescription)"),
    legend_bar_html("dev_neg", "Too tight (below prescription)")
  )),
  '<div style="position:relative; width:100%; height:220px;">\n',
  '<canvas id="taylor-fig2" role="img" aria-label="Bar chart of quarterly Taylor Rule deviation, 2015-2024"></canvas>\n',
  '</div>\n',
  footer_html(),
  js_open("taylor-fig2"),
  JS_PALETTE, "\n",
  "  function render() {\n",
  "    if (!window.Chart) return;\n",
  "    var c = palette();\n",
  JS_SWATCH, "\n",
  "    var labels = ", labels_js_2, ";\n",
  "    var vals   = ", dev1_js_2, ";\n",
  "    var peakLbl = '", peak_dev_lbl, "';\n",
  "    var peakVal = ", round(peak_dev_val, 2), ";\n",
  ZERO_LINE_PLUGIN, "\n",
  "    var peakPlugin = {\n",
  "      id: 'peakAnnotation',\n",
  "      afterDraw: function(chart) {\n",
  "        var ctx = chart.ctx, xs = chart.scales.x, ys = chart.scales.y;\n",
  "        var peakIdx = labels.indexOf(peakLbl);\n",
  "        if (peakIdx < 0) return;\n",
  "        var px = xs.getPixelForValue(peakIdx);\n",
  "        var py = ys.getPixelForValue(peakVal);\n",
  "        ctx.save();\n",
  "        ctx.fillStyle = c.dev_pos;\n",
  "        ctx.font = 'bold 10px system-ui, sans-serif';\n",
  "        ctx.textAlign = 'center';\n",
  "        ctx.fillText(peakLbl, px, py - 16);\n",
  "        ctx.fillText('+' + peakVal.toFixed(1) + 'pp', px, py - 5);\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    if (chart) chart.destroy();\n",
  "    chart = new Chart(canvas, {\n",
  "      type: 'bar',\n",
  "      plugins: [zeroLinePlugin, peakPlugin],\n",
  "      data: {\n",
  "        labels: labels,\n",
  "        datasets: [{\n",
  "          label: 'Policy gap (pp)',\n",
  "          data: vals,\n",
  "          backgroundColor: vals.map(function(v) { return v > 0 ? c.dev_pos : c.dev_neg; }),\n",
  "          borderRadius: 2\n",
  "        }]\n",
  "      },\n",
  CHART_OPTIONS_HEAD, "\n",
  "        scales: {\n",
  X_SCALE_QTR, ",\n",
  "          y: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            ticks: { color: c.yTick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return v + 'pp'; } }\n",
  "          }\n",
  "        }\n",
  "      }\n",
  "    });\n",
  "  }\n",
  JS_CLOSE
)

writeLines(html_fig2, file.path(WIDGETS_DIR, "fig2_deviation.html"))

# ── Figure 3: Scatter — deviation vs. future inflation ───────────────────────

df_scatter <- df_analysis |>
  dplyr::select(date, Dev_1, PCEPILFE) |>
  dplyr::filter(!is.na(Dev_1), !is.na(PCEPILFE)) |>
  dplyr::mutate(infl_lead = dplyr::lead(PCEPILFE, 2)) |>
  dplyr::filter(!is.na(infl_lead)) |>
  dplyr::rename(dev1 = Dev_1)

fit       <- lm(infl_lead ~ dev1, data = df_scatter)
slope     <- coef(fit)[["dev1"]]
intercept <- coef(fit)[["(Intercept)"]]
r_squared <- summary(fit)$r.squared

x_range  <- seq(min(df_scatter$dev1), max(df_scatter$dev1), length.out = 50)
y_fitted <- intercept + slope * x_range

scatter_pts_js    <- format_scatter_js(df_scatter$dev1, df_scatter$infl_lead)
trend_pts_js      <- format_scatter_js(x_range, y_fitted)
scatter_labels_js <- paste0('["', paste(format_date_labels(df_scatter$date), collapse = '","'), '"]')

year_ramp    <- colorRampPalette(c("#93c5fd", "#1e3a8a"))(10)
pt_years     <- as.integer(format(df_scatter$date, "%Y"))
pt_colors    <- year_ramp[pt_years - 2014L]
pt_colors_js <- paste0('["', paste(pt_colors, collapse = '","'), '"]')

html_fig3 <- paste0(
  '<figure class="chart-embed" style="margin:0; font-family:var(--font-body);">\n',
  fig_header_html(
    "Federal Reserve · Deep Dive · 2015–2024",
    "Policy Looseness and Subsequent Inflation",
    "Taylor Rule deviation in quarter t vs. core PCE inflation two quarters later · 2015–2024"
  ),
  stat_cards_html(list(
    stat_card_html("OLS slope", sprintf("%.2fpp inflation per 1pp deviation (t+2)", slope))
  ), ncols = 1),
  legend_row_html(list(
    legend_line_html("infl", "OLS trend line")
  )),
  '<div style="position:relative; width:100%; height:300px;">\n',
  '<canvas id="taylor-fig3" role="img" aria-label="Scatter: Taylor deviation vs core PCE two quarters later, 2015-2024"></canvas>\n',
  '</div>\n',
  footer_html(),
  js_open("taylor-fig3"),
  JS_PALETTE, "\n",
  "  function render() {\n",
  "    if (!window.Chart) return;\n",
  "    var c = palette();\n",
  JS_SWATCH, "\n",
  "    var scatterLabels = ", scatter_labels_js, ";\n",
  "    var ptColors = ", pt_colors_js, ";\n",
  "    var r2 = ", round(r_squared, 4), ";\n",
  "    var r2Plugin = {\n",
  "      id: 'r2label',\n",
  "      afterDraw: function(chart) {\n",
  "        var ctx = chart.ctx, ca = chart.chartArea;\n",
  "        ctx.save();\n",
  "        ctx.fillStyle = c.tick;\n",
  "        ctx.font = '11px system-ui, sans-serif';\n",
  "        ctx.textAlign = 'right';\n",
  "        ctx.fillText('R² = ' + r2.toFixed(2), ca.right - 6, ca.bottom - 6);\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    if (chart) chart.destroy();\n",
  "    chart = new Chart(canvas, {\n",
  "      type: 'scatter',\n",
  "      plugins: [r2Plugin],\n",
  "      data: {\n",
  "        datasets: [\n",
  "          { label: 'Quarters', data: ", scatter_pts_js, ",\n",
  "            backgroundColor: ptColors, pointRadius: 5, pointHoverRadius: 7 },\n",
  "          { label: 'OLS trend', type: 'line', data: ", trend_pts_js, ",\n",
  "            borderColor: c.infl, borderWidth: 1.5, borderDash: [4,3],\n",
  "            pointRadius: 0, fill: false, tension: 0 }\n",
  "        ]\n",
  "      },\n",
  "      options: {\n",
  "        responsive: true, maintainAspectRatio: false, animation: false,\n",
  "        layout: { padding: { top: 26, right: 20, left: 0, bottom: 4 } },\n",
  "        interaction: { mode: 'nearest', intersect: false },\n",
  "        plugins: { legend: { display: false }, title: { display: false },\n",
  "          tooltip: { callbacks: { label: function(ctx) {\n",
  "            if (ctx.datasetIndex !== 0) return null;\n",
  "            var pt = ctx.raw, lbl = scatterLabels[ctx.dataIndex];\n",
  "            return ['Q: ' + lbl, 'Deviation: ' + pt.x.toFixed(2) + 'pp', 'Inflation +2Q: ' + pt.y.toFixed(2) + '%'];\n",
  "          }}}},\n",
  "        scales: {\n",
  "          x: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            title: { display: true, text: 'Taylor deviation (pp)',\n",
  "              color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } },\n",
  "            ticks: { color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } }\n",
  "          },\n",
  "          y: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            title: { display: true, text: 'Core PCE, % YoY (t+2)',\n",
  "              color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } },\n",
  "            ticks: { color: c.yTick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return v + '%'; } }\n",
  "          }\n",
  "        }\n",
  "      }\n",
  "    });\n",
  "  }\n",
  JS_CLOSE
)

writeLines(html_fig3, file.path(WIDGETS_DIR, "fig3_scatter.html"))

# ── Figure 4: ECB comparison ──────────────────────────────────────────────────

fig4_data <- df_analysis |>
  dplyr::rename(ea_inflation = CP0000EZ19M086NEST) |>
  dplyr::select(date, ECB_Dev, ea_inflation, ECBDFR) |>
  dplyr::filter(!is.na(ECB_Dev), !is.na(ea_inflation))

ecb_peak_dev  <- max(fig4_data$ECB_Dev,     na.rm = TRUE)
peak_hicp     <- max(fig4_data$ea_inflation, na.rm = TRUE)
ecb_end_rate  <- tail(na.omit(fig4_data$ECBDFR), 1)

date_labels_4 <- format_date_labels(fig4_data$date)
labels_js_4   <- paste0('["', paste(date_labels_4, collapse = '","'), '"]')
ecbdev_js     <- format_js_array(fig4_data$ECB_Dev)
hicp_js       <- format_js_array(fig4_data$ea_inflation)

html_fig4 <- paste0(
  '<figure class="chart-embed" style="margin:0; font-family:var(--font-body);">\n',
  fig_header_html(
    "ECB · Deep Dive · 2018–2024",
    "ECB Policy Deviation and Euro Area Inflation",
    "Simplified Taylor prescription minus ECB deposit facility rate, vs. HICP · percent · quarterly"
  ),
  stat_cards_html(list(
    stat_card_html("ECB peak policy gap",        sprintf("+%.1fpp", ecb_peak_dev)),
    stat_card_html("Peak euro area HICP",        sprintf("%.1f%%", peak_hicp)),
    stat_card_html("ECB deposit rate (end 2024)", sprintf("%.2f%%", ecb_end_rate))
  ), ncols = 3),
  legend_row_html(list(
    legend_dashed_html("ecb",  "ECB policy gap"),
    legend_line_html("infl",   "Euro area HICP")
  )),
  '<div style="position:relative; width:100%; height:240px;">\n',
  '<canvas id="taylor-fig4" role="img" aria-label="Dual-axis: ECB policy deviation and euro area HICP, 2015-2024"></canvas>\n',
  '</div>\n',
  '<p style="font-size:10px;color:var(--muted);margin-top:8px;margin-bottom:0;">',
  'ECB Taylor Rule uses r*=1.0% and inflation gap only; euro area potential output not available on FRED.',
  '</p>\n',
  footer_html(),
  js_open("taylor-fig4"),
  JS_PALETTE, "\n",
  "  function render() {\n",
  "    if (!window.Chart) return;\n",
  "    var c = palette();\n",
  JS_SWATCH, "\n",
  "    var labels = ", labels_js_4, ";\n",
  COVID_PLUGIN, "\n",
  ZERO_LINE_PLUGIN, "\n",
  "    if (chart) chart.destroy();\n",
  "    chart = new Chart(canvas, {\n",
  "      type: 'line',\n",
  "      plugins: [covidPlugin, zeroLinePlugin],\n",
  "      data: {\n",
  "        labels: labels,\n",
  "        datasets: [\n",
  "          { label: 'ECB policy gap', data: ", ecbdev_js, ",\n",
  "            borderColor: c.ecb, borderWidth: 1.5, borderDash: [5,3],\n",
  "            pointRadius: 0, tension: 0.3, fill: false, yAxisID: 'y' },\n",
  "          { label: 'Euro area HICP', data: ", hicp_js, ",\n",
  "            borderColor: c.infl, borderWidth: 2,\n",
  "            pointRadius: 0, tension: 0.3, fill: false, yAxisID: 'y1' }\n",
  "        ]\n",
  "      },\n",
  "      options: {\n",
  "        responsive: true, maintainAspectRatio: false, animation: false,\n",
  "        layout: { padding: { top: 26, right: 20, left: 0, bottom: 4 } },\n",
  "        interaction: { mode: 'index', axis: 'x', intersect: false },\n",
  "        plugins: { legend: { display: false }, title: { display: false },\n",
  "          tooltip: { mode: 'index', intersect: false } },\n",
  "        scales: {\n",
  X_SCALE_QTR, ",\n",
  "          y: {\n",
  "            position: 'left',\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            title: { display: true, text: 'Policy gap (pp)',\n",
  "              color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } },\n",
  "            ticks: { color: c.yTick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return v + 'pp'; } }\n",
  "          },\n",
  "          y1: {\n",
  "            position: 'right',\n",
  "            border: { display: false },\n",
  "            grid: { drawOnChartArea: false },\n",
  "            title: { display: true, text: 'HICP % YoY',\n",
  "              color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } },\n",
  "            ticks: { color: c.yTick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return v + '%'; } }\n",
  "          }\n",
  "        }\n",
  "      }\n",
  "    });\n",
  "  }\n",
  JS_CLOSE
)

writeLines(html_fig4, file.path(WIDGETS_DIR, "fig4_ecb.html"))

# ── Figure 5: Cross-correlation ───────────────────────────────────────────────

peak_ccf_idx <- which.max(abs(df_ccf$correlation))
peak_ccf_lag <- df_ccf$lag[peak_ccf_idx]
peak_ccf_val <- df_ccf$correlation[peak_ccf_idx]

ccf_labels_js <- paste0('["', paste(paste0("t+", df_ccf$lag), collapse = '","'), '"]')
ccf_vals_js   <- format_js_array(df_ccf$correlation, digits = 4)

html_fig5 <- paste0(
  '<figure class="chart-embed" style="margin:0; font-family:var(--font-body);">\n',
  fig_header_html(
    "Federal Reserve · Deep Dive · 2015–2024",
    "How Many Quarters Does Policy Looseness Lead Inflation?",
    "Cross-correlation between Taylor Rule deviation and core PCE inflation · lags 0–8 quarters"
  ),
  stat_cards_html(list(
    stat_card_html("Peak correlation", sprintf("r = %.2f", abs(peak_ccf_val))),
    stat_card_html("At lag",           sprintf("t+%d quarters", peak_ccf_lag))
  ), ncols = 2),
  legend_row_html(list(
    legend_bar_html("dev_pos", "Positive correlation"),
    legend_bar_html("dev_neg", "Negative correlation")
  )),
  '<div style="position:relative; width:100%; height:200px;">\n',
  '<canvas id="taylor-fig5" role="img" aria-label="Bar chart: cross-correlation between Taylor deviation and core PCE, lags 0-8 quarters"></canvas>\n',
  '</div>\n',
  footer_html(),
  js_open("taylor-fig5"),
  JS_PALETTE, "\n",
  "  function render() {\n",
  "    if (!window.Chart) return;\n",
  "    var c = palette();\n",
  JS_SWATCH, "\n",
  "    var labels = ", ccf_labels_js, ";\n",
  "    var vals   = ", ccf_vals_js, ";\n",
  "    var peakLbl = 't+", peak_ccf_lag, "';\n",
  "    var peakVal = ", round(peak_ccf_val, 4), ";\n",
  ZERO_LINE_PLUGIN, "\n",
  "    var peakPlugin = {\n",
  "      id: 'peakAnnotation',\n",
  "      afterDraw: function(chart) {\n",
  "        var ctx = chart.ctx, xs = chart.scales.x, ys = chart.scales.y;\n",
  "        var peakIdx = labels.indexOf(peakLbl);\n",
  "        if (peakIdx < 0) return;\n",
  "        var px = xs.getPixelForValue(peakIdx);\n",
  "        var py = ys.getPixelForValue(peakVal);\n",
  "        ctx.save();\n",
  "        ctx.fillStyle = peakVal > 0 ? c.dev_pos : c.dev_neg;\n",
  "        ctx.font = 'bold 10px system-ui, sans-serif';\n",
  "        ctx.textAlign = 'center';\n",
  "        ctx.fillText(peakLbl, px, py - 16);\n",
  "        ctx.fillText('r = ' + peakVal.toFixed(2), px, py - 5);\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    if (chart) chart.destroy();\n",
  "    chart = new Chart(canvas, {\n",
  "      type: 'bar',\n",
  "      plugins: [zeroLinePlugin, peakPlugin],\n",
  "      data: {\n",
  "        labels: labels,\n",
  "        datasets: [{\n",
  "          label: 'Cross-correlation',\n",
  "          data: vals,\n",
  "          backgroundColor: vals.map(function(v) { return v > 0 ? c.dev_pos : c.dev_neg; }),\n",
  "          borderRadius: 3\n",
  "        }]\n",
  "      },\n",
  "      options: {\n",
  "        responsive: true, maintainAspectRatio: false, animation: false,\n",
  "        layout: { padding: { top: 26, right: 20, left: 0, bottom: 4 } },\n",
  "        interaction: { mode: 'index', intersect: false },\n",
  "        plugins: { legend: { display: false }, title: { display: false },\n",
  "          tooltip: { mode: 'index', intersect: false } },\n",
  "        scales: {\n",
  "          x: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            title: { display: true, text: 'Lead of inflation (quarters after deviation)',\n",
  "              color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } },\n",
  "            ticks: { color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return 't+' + v; } }\n",
  "          },\n",
  "          y: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            title: { display: true, text: 'Correlation coefficient',\n",
  "              color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' } },\n",
  "            ticks: { color: c.yTick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              callback: function(v) { return v.toFixed(1); } }\n",
  "          }\n",
  "        }\n",
  "      }\n",
  "    });\n",
  "  }\n",
  JS_CLOSE
)

writeLines(html_fig5, file.path(WIDGETS_DIR, "fig5_ccf.html"))

# ── Verification ──────────────────────────────────────────────────────────────

files <- c(
  "fig1_taylor_vs_actual.html",
  "fig2_deviation.html",
  "fig3_scatter.html",
  "fig4_ecb.html",
  "fig5_ccf.html"
)

cat("\n── Output verification ───────────────────────────────────────────────────\n")
for (f in files) {
  path  <- file.path(WIDGETS_DIR, f)
  bytes <- file.size(path)
  lines <- readLines(path, warn = FALSE)
  txt   <- paste(lines, collapse = "\n")
  checks <- c(
    `</figure>` = grepl("</figure>", txt, fixed = TRUE),
    `no white`  = !grepl("white", txt, fixed = TRUE),
    `title=F`   = grepl('title.*display.*false', txt),
    `legend=F`  = grepl('legend.*display.*false', txt)
  )
  ok <- all(checks)
  cat(sprintf("  %-35s  %6d bytes  %s\n", f, bytes,
              if (ok) "[OK]" else paste("[FAIL:", paste(names(checks)[!checks], collapse=","), "]")))
}
cat("─────────────────────────────────────────────────────────────────────────\n\n")
