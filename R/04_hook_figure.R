source("R/config.R")
library(dplyr)

df_analysis <- readRDS(file.path(DATA_DIR, "df_analysis.rds"))

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

stat_card_sub_html <- function(label, value, subtext) {
  paste0(
    '<div style="background:var(--bg-soft);border:1px solid var(--border);',
    'border-radius:6px;padding:8px 12px;">',
    '<div style="font-size:0.68rem;color:var(--muted);text-transform:uppercase;',
    'letter-spacing:.05em;margin-bottom:2px;">', label, '</div>',
    '<div style="font-size:1.05rem;font-weight:600;color:var(--text);">', value, '</div>',
    '<div style="font-size:0.68rem;color:var(--muted);margin-top:2px;">', subtext, '</div>',
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
      dev_pos: light ? '#D85A30'                : '#f87171',
      dev_neg: light ? '#185FA5'                : '#60a5fa',
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
    "    s.src = 'https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.js';\n",
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

# ── Figure 0: Hook ────────────────────────────────────────────────────────────

fig0_data <- df_analysis |>
  dplyr::filter(!is.na(Dev_1), !is.na(PCEPILFE)) |>
  dplyr::select(date, Dev_1, PCEPILFE)

date_labels_0 <- format_date_labels(fig0_data$date)
labels_js_0   <- paste0('["', paste(date_labels_0, collapse = '","'), '"]')
dev1_js       <- format_js_array(fig0_data$Dev_1)
infl_js       <- format_js_array(fig0_data$PCEPILFE)

peak_dev_val  <- max(fig0_data$Dev_1,    na.rm = TRUE)
peak_dev_date <- fig0_data$date[which.max(fig0_data$Dev_1)]
peak_pce_val  <- max(fig0_data$PCEPILFE, na.rm = TRUE)
peak_pce_date <- fig0_data$date[which.max(fig0_data$PCEPILFE)]
n_below       <- sum(fig0_data$Dev_1 > 0, na.rm = TRUE)
n_total       <- nrow(fig0_data)

fmt_qtr <- function(d) {
  q <- ceiling(as.integer(format(d, "%m")) / 3)
  paste0("Q", q, " ", format(d, "%Y"))
}

html_fig0 <- paste0(
  '<figure class="chart-embed" style="margin:0; font-family:var(--font-body);">\n',
  fig_header_html(
    "Federal Reserve · Deep Dive · 2015–2024",
    "The Fed's Departure from Rules-Based Policy",
    "Baseline Taylor Rule deviation and core PCE inflation · percentage points and % YoY · quarterly"
  ),
  stat_cards_html(list(
    stat_card_sub_html("Peak policy gap",
      sprintf("+%.1fpp", peak_dev_val),
      fmt_qtr(peak_dev_date)),
    stat_card_sub_html("Peak core PCE",
      sprintf("%.1f%%", peak_pce_val),
      fmt_qtr(peak_pce_date)),
    stat_card_sub_html("Quarters below prescription",
      sprintf("%d of %d", n_below, n_total),
      "2015–2024")
  ), ncols = 3),
  legend_row_html(list(
    legend_line_html("dev_pos", "Policy gap (Taylor deviation)"),
    legend_dashed_html("infl",  "Core PCE inflation")
  )),
  '<div style="position:relative; width:100%; height:200px;">\n',
  '<canvas id="taylor-hook" role="img" aria-label="Dual-axis: Taylor Rule policy gap and core PCE inflation, 2015-2024"></canvas>\n',
  '</div>\n',
  footer_html(),
  js_open("taylor-hook"),
  JS_PALETTE, "\n",
  "  function hexAlpha(hex, a) {\n",
  "    var r = parseInt(hex.slice(1,3),16),\n",
  "        g = parseInt(hex.slice(3,5),16),\n",
  "        b = parseInt(hex.slice(5,7),16);\n",
  "    return 'rgba(' + r + ',' + g + ',' + b + ',' + a + ')';\n",
  "  }\n",
  "  function render() {\n",
  "    if (!window.Chart) return;\n",
  "    var c = palette();\n",
  JS_SWATCH, "\n",
  "    var labels = ", labels_js_0, ";\n",
  "    var dev1   = ", dev1_js, ";\n",
  "    var fillPlugin = {\n",
  "      id: 'devFill',\n",
  "      beforeDatasetsDraw: function(chart) {\n",
  "        var ctx = chart.ctx, ca = chart.chartArea;\n",
  "        var meta = chart.getDatasetMeta(0);\n",
  "        var ys = chart.scales.y;\n",
  "        var y0 = ys.getPixelForValue(0);\n",
  "        var posColor = hexAlpha(c.dev_pos, 0.35);\n",
  "        var negColor = hexAlpha(c.dev_neg, 0.25);\n",
  "        ctx.save();\n",
  "        ctx.beginPath();\n",
  "        ctx.rect(ca.left, ca.top, ca.width, ca.height);\n",
  "        ctx.clip();\n",
  "        var pts = [];\n",
  "        for (var i = 0; i < meta.data.length; i++) {\n",
  "          if (dev1[i] === null) continue;\n",
  "          pts.push({ px: meta.data[i].x, py: meta.data[i].y, val: dev1[i] });\n",
  "        }\n",
  "        for (var j = 0; j < pts.length - 1; j++) {\n",
  "          var p1 = pts[j], p2 = pts[j+1];\n",
  "          var pos1 = p1.val >= 0, pos2 = p2.val >= 0;\n",
  "          if (pos1 === pos2) {\n",
  "            ctx.beginPath();\n",
  "            ctx.moveTo(p1.px, y0); ctx.lineTo(p1.px, p1.py);\n",
  "            ctx.lineTo(p2.px, p2.py); ctx.lineTo(p2.px, y0);\n",
  "            ctx.closePath();\n",
  "            ctx.fillStyle = pos1 ? posColor : negColor;\n",
  "            ctx.fill();\n",
  "          } else {\n",
  "            var t = p1.val / (p1.val - p2.val);\n",
  "            var crossPx = p1.px + t * (p2.px - p1.px);\n",
  "            ctx.beginPath();\n",
  "            ctx.moveTo(p1.px, y0); ctx.lineTo(p1.px, p1.py); ctx.lineTo(crossPx, y0);\n",
  "            ctx.closePath();\n",
  "            ctx.fillStyle = pos1 ? posColor : negColor; ctx.fill();\n",
  "            ctx.beginPath();\n",
  "            ctx.moveTo(crossPx, y0); ctx.lineTo(p2.px, p2.py); ctx.lineTo(p2.px, y0);\n",
  "            ctx.closePath();\n",
  "            ctx.fillStyle = pos2 ? posColor : negColor; ctx.fill();\n",
  "          }\n",
  "        }\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    var covidPlugin = {\n",
  "      id: 'covidShade',\n",
  "      afterDraw: function(chart) {\n",
  "        var ctx = chart.ctx, ca = chart.chartArea, xs = chart.scales.x;\n",
  "        var i1 = labels.indexOf('2020-Q1'), i2 = labels.indexOf('2022-Q1');\n",
  "        if (i1 < 0 || i2 < 0) return;\n",
  "        var px1 = xs.getPixelForValue(i1), px2 = xs.getPixelForValue(i2);\n",
  "        ctx.save();\n",
  "        ctx.fillStyle = c.covid;\n",
  "        ctx.fillRect(px1, ca.top, px2 - px1, ca.bottom - ca.top);\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    var zeroLinePlugin = {\n",
  "      id: 'zeroLine',\n",
  "      afterDraw: function(chart) {\n",
  "        var ctx = chart.ctx, ca = chart.chartArea, ys = chart.scales.y;\n",
  "        var y0 = ys.getPixelForValue(0);\n",
  "        ctx.save();\n",
  "        ctx.strokeStyle = c.tick; ctx.lineWidth = 1;\n",
  "        ctx.setLineDash([4, 4]);\n",
  "        ctx.beginPath(); ctx.moveTo(ca.left, y0); ctx.lineTo(ca.right, y0); ctx.stroke();\n",
  "        ctx.setLineDash([]);\n",
  "        ctx.fillStyle = c.tick;\n",
  "        ctx.font = '9px system-ui, sans-serif';\n",
  "        ctx.textAlign = 'right';\n",
  "        ctx.fillText('Rules-based prescription', ca.right - 4, y0 - 4);\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    var annotPlugin = {\n",
  "      id: 'annotations',\n",
  "      afterDraw: function(chart) {\n",
  "        var ctx = chart.ctx, ca = chart.chartArea, xs = chart.scales.x;\n",
  "        var annots = [\n",
  "          { lbl: '2020-Q3', text: 'AIT announced',   yOff: 0 },\n",
  "          { lbl: '2021-Q4', text: 'Taper decision',  yOff: 13 },\n",
  "          { lbl: '2022-Q1', text: 'First rate hike', yOff: 0 }\n",
  "        ];\n",
  "        ctx.save();\n",
  "        annots.forEach(function(a) {\n",
  "          var idx = labels.indexOf(a.lbl);\n",
  "          if (idx < 0) return;\n",
  "          var px = xs.getPixelForValue(idx);\n",
  "          ctx.globalAlpha = 0.5;\n",
  "          ctx.strokeStyle = c.tick; ctx.lineWidth = 1;\n",
  "          ctx.setLineDash([3, 3]);\n",
  "          ctx.beginPath(); ctx.moveTo(px, ca.top); ctx.lineTo(px, ca.bottom); ctx.stroke();\n",
  "          ctx.setLineDash([]); ctx.globalAlpha = 1;\n",
  "          ctx.fillStyle = c.yTick;\n",
  "          ctx.font = 'bold 10px system-ui, sans-serif';\n",
  "          ctx.textAlign = 'center';\n",
  "          ctx.fillText(a.text, px, ca.top - 6 - a.yOff);\n",
  "        });\n",
  "        ctx.restore();\n",
  "      }\n",
  "    };\n",
  "    if (chart) chart.destroy();\n",
  "    chart = new Chart(canvas, {\n",
  "      type: 'line',\n",
  "      plugins: [fillPlugin, covidPlugin, zeroLinePlugin, annotPlugin],\n",
  "      data: {\n",
  "        labels: labels,\n",
  "        datasets: [\n",
  "          { label: 'Policy gap (pp)', data: dev1,\n",
  "            borderColor: c.dev_pos,\n",
  "            segment: { borderColor: function(sctx) { return sctx.p0.parsed.y >= 0 ? c.dev_pos : c.dev_neg; } },\n",
  "            borderWidth: 2, tension: 0.3, pointRadius: 0, fill: false, yAxisID: 'y' },\n",
  "          { label: 'Core PCE inflation (%)', data: ", infl_js, ",\n",
  "            borderColor: c.infl, borderWidth: 1.5, borderDash: [4,3],\n",
  "            tension: 0.3, pointRadius: 0, fill: false, yAxisID: 'y1' }\n",
  "        ]\n",
  "      },\n",
  "      options: {\n",
  "        responsive: true, maintainAspectRatio: false, animation: false,\n",
  "        layout: { padding: { top: 26, right: 20, left: 0, bottom: 4 } },\n",
  "        interaction: { mode: 'index', axis: 'x', intersect: false },\n",
  "        plugins: { legend: { display: false }, title: { display: false } },\n",
  "        scales: {\n",
  "          x: {\n",
  "            border: { display: false },\n",
  "            grid: { color: c.grid },\n",
  "            ticks: { color: c.tick, font: { size: 10, family: 'system-ui, sans-serif' },\n",
  "              maxRotation: 0, autoSkip: false,\n",
  "              callback: function(val, i) { return i % 4 === 0 ? labels[i] : null; } }\n",
  "          },\n",
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
  "            title: { display: true, text: 'Core PCE (%)',\n",
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

writeLines(html_fig0, file.path(WIDGETS_DIR, "fig0_hook.html"))

# ── Verification ──────────────────────────────────────────────────────────────

path  <- file.path(WIDGETS_DIR, "fig0_hook.html")
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
cat(sprintf("\nfig0_hook.html  %d bytes  %s\n", bytes,
            if (ok) "[OK]" else paste("[FAIL:", paste(names(checks)[!checks], collapse=","), "]")))
