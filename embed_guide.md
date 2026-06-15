# Embedding the Taylor Rule Widgets

> **Canonical method for personal.site is inline `html-embed`, not iframes.**
> Paste the figure's `<figure>`+`<canvas>`+`<script>` fragment into the post
> markdown wrapped in a ` ```html-embed ` fence. Chart.js must load from
> `cdn.jsdelivr.net` (the site CSP blocks every other CDN). No hardcoded
> `nonce=`, no inline `on*=` handlers. Full rules:
> `~/.claude/_shared/chart-embed-contract.md`. The iframe section below is
> legacy — only valid if the site explicitly serves these standalone files.

Each figure is a standalone HTML file in `output/widgets/`. The files are
hand-authored HTML with Chart.js 4.4.1 lazy-loaded from jsDelivr (cdn.jsdelivr.net) (a single
`<script>` tag injected by `window.__chartjs`). They are **not** self-contained
in the htmlwidgets sense — the visitor's browser fetches Chart.js from the CDN
on first load. Subsequent figures on the same page share the same cached
request because all five widgets check `window.__chartjs` before injecting the
script tag.

All figures respond to the site's light/dark theme via a `MutationObserver`
that watches `document.body.classList` for the `is-light` class.

---

## Recommended heights per figure

These heights account for the canvas, stat cards, legend row, and footer:

| File | Canvas | Recommended iframe height |
|------|--------|--------------------------|
| fig1_taylor_vs_actual.html | 280 px | 440 px |
| fig2_deviation.html | 240 px | 340 px |
| fig3_scatter.html | 320 px | 410 px |
| fig4_ecb.html | 260 px | 450 px |
| fig5_ccf.html | 220 px | 320 px |

Adjust after checking the figure's natural height in your browser at your
site's content-column width. The `scrolling="no"` attribute only hides the
scrollbar — it does not clip content. If the iframe height is too short the
chart will be cut off silently.

---

## Basic iframe embed

```html
<!-- Figure 1 -->
<iframe
  src="/deep-dives/taylor-rule/widgets/fig1_taylor_vs_actual.html"
  width="100%"
  height="440"
  frameborder="0"
  scrolling="no"
  title="Federal Reserve Policy vs. Rules-Based Prescriptions"
></iframe>

<!-- Figure 2 -->
<iframe
  src="/deep-dives/taylor-rule/widgets/fig2_deviation.html"
  width="100%"
  height="340"
  frameborder="0"
  scrolling="no"
  title="Policy Gap: Taylor Rule Prescription Minus Actual Rate"
></iframe>

<!-- Figure 3 -->
<iframe
  src="/deep-dives/taylor-rule/widgets/fig3_scatter.html"
  width="100%"
  height="410"
  frameborder="0"
  scrolling="no"
  title="Policy Looseness and Subsequent Inflation"
></iframe>

<!-- Figure 4 -->
<iframe
  src="/deep-dives/taylor-rule/widgets/fig4_ecb.html"
  width="100%"
  height="450"
  frameborder="0"
  scrolling="no"
  title="ECB Policy Deviation and Euro Area Inflation"
></iframe>

<!-- Figure 5 -->
<iframe
  src="/deep-dives/taylor-rule/widgets/fig5_ccf.html"
  width="100%"
  height="320"
  frameborder="0"
  scrolling="no"
  title="Cross-Correlation: Policy Looseness Leading Inflation"
></iframe>
```

---

## Responsive wrapper (aspect-ratio trick)

For layouts where the content column width changes across breakpoints, wrap the
iframe in a `position:relative` div and use a `padding-bottom` percentage to
maintain a fixed aspect ratio. The iframe then fills the wrapper with
`position:absolute`.

The padding-bottom percentage is `(height / width) * 100`. For a 16:9 ratio
that is `56.25%`; for a 3:1 ratio (wide, shallow charts) it is `33.3%`. Pick
the ratio that matches each figure's natural proportions.

```html
<!-- Example: Figure 2 at roughly 4:1 width-to-height -->
<div style="position:relative; padding-bottom:25%; height:0; overflow:hidden;">
  <iframe
    src="/deep-dives/taylor-rule/widgets/fig2_deviation.html"
    style="position:absolute; top:0; left:0; width:100%; height:100%;"
    frameborder="0"
    scrolling="no"
    title="Policy Gap: Taylor Rule Prescription Minus Actual Rate"
  ></iframe>
</div>
```

Note that this technique locks the aspect ratio regardless of viewport size.
On very narrow screens (< 400 px) Chart.js will still re-layout responsively
inside the iframe canvas, but the stat cards and footer text may become cramped.
Test at mobile widths and consider using a fixed-height iframe there instead:

```html
<style>
  .chart-wrap { position:relative; padding-bottom:28%; height:0; overflow:hidden; }
  @media (max-width: 600px) {
    .chart-wrap { padding-bottom:0; height:320px; }
  }
</style>
<div class="chart-wrap">
  <iframe
    src="/deep-dives/taylor-rule/widgets/fig2_deviation.html"
    style="position:absolute; top:0; left:0; width:100%; height:100%;"
    frameborder="0" scrolling="no"
  ></iframe>
</div>
```

---

## CDN dependency note

All five widgets load Chart.js from:

```
https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js
```

The `window.__chartjs` promise is attached to the **parent** page's `window`
only when the widgets are embedded inline (e.g. via `<script>` injection or
SSI), not inside iframes, because each iframe has its own `window`. In iframe
mode each figure loads the CDN script independently — they do not share the
promise across frames. If you embed multiple figures on the same page as iframes
and want to eliminate redundant CDN requests, the cleanest approach is to load
Chart.js once in the parent page and embed the figures as inline HTML rather
than iframes.
