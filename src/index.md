---
toc: false
title: Double IQD Exploration Dashboard
---

# Double IQD Core Diagnostics

<!-- Referring https://gemini.google.com/app/3c752cb65ef9704d -->

<div class="card grid grid-cols-4" style="gap: 1.5rem; background-color: #f8f9fa; padding: 1.2rem;">
  <div>
    <label style="font-weight: bold; display: block; margin-bottom: 0.5rem;">Grid Resolution (dx = d_depth)</label>
    ${dx_input}
  </div>
  <div>
    <label style="font-weight: bold; display: block; margin-bottom: 0.5rem;">Window Size (w_x = w_depth)</label>
    ${wx_input}
  </div>
  <div>
    <label style="font-weight: bold; display: block; margin-bottom: 0.5rem;">Integration Baseline</label>
    ${baseline_input}
  </div>
  <div style="display: flex; align-items: flex-end; justify-content: flex-end;">
    <div style="font-size: 0.85rem; color: #666; text-align: right;">
      <strong>Selected Experiment Tag:</strong><br>
      <code style="color: #d63384; font-size: 1rem;">${experiment_tag}</code>
    </div>
  </div>
</div>

---

${loading_indicator}

<div class="grid grid-cols-2" style="margin-top: 1rem;">
  <div class="card">
    <h2>Event Density</h2>
    ${plot_density}
  </div>
  <div class="card">
    <h2>Quasi-Laplacian (QL) Field</h2>
    ${plot_ql}
  </div>
</div>

```js
// --- PARAMETER RESOLUTION & STATE MANAGEMENT ---
// Read discrete options configured across the experiments matrix
const dx_input = Inputs.select([5.0, 2.5, 1.0, 0.4, 0.2], {value: 2.5, format: d => `${d} km`});
const wx_input = Inputs.select([10.0, 5.0, 2.0, 1.0], {value: 10.0, format: w => `${w} km`});
const baseline_input = Inputs.radio(["ZeroBaseline", "MeanMatchedBaseline"], {value: "ZeroBaseline"});

const dx = Generators.observe(dx_input);
const wx = Generators.observe(wx_input);
const baseline = Generators.observe(baseline_input);

// Map slider coordinates back to your explicit experiment tag schema
const experiment_tag = cal_tag(dx, wx, baseline);

function cal_tag(dx, wx, baseline) {
  const isMean = baseline === "MeanMatchedBaseline";
  if (dx === 5.0 && wx === 10.0) return isMean ? "mean_matched_base" : "zero_base";
  if (dx === 2.5 && wx === 10.0) return isMean ? "mean_matched_fine" : "zero_fine";
  if (dx === 1.0 && wx === 5.0)  return "zero_finer_w5";
  if (dx === 0.4 && wx === 2.0)  return "zero_finer_w2";
  if (dx === 0.2 && wx === 1.0)  return "zero_finer_w1";
  return "UNKNOWN_COMBINATION";
}

// --- ASYNC BINARY DATA LOADER ---
// Dynamically fetches individual files over the network based on UI state
const data = html`<span></span>`; // Reactive trigger hook

const records = div(async () => {
  if (experiment_tag === "UNKNOWN_COMBINATION") {
    return { error: true, msg: "The alignment constraint/combination does not match any precomputed sequence." };
  }

  try {
    const url = `./data/exp_${experiment_tag}.arrow`;
    const response = await fetch(url);
    if (!response.ok) throw new Error("File missing or unaligned resource.");

    // Parse using framework's standard internal Apache Arrow pipeline
    const arrowTable = await response.arrow();
    return { error: false, table: arrowTable };
  } catch (err) {
    return { error: true, msg: `Missing asset target for: ${experiment_tag}. Run export pipeline.` };
  }
});

// UI helper to present error/loading notification states safely
const loading_indicator = html`${() => {
  if (!records) return html`<div style="color: #ffc107; font-weight: bold;">⏳ Loading Columnar Layer Assets...</div>`;
  if (records.error) return html`<div style="color: #dc3545; padding: 1rem; border: 1px dashed red;">⚠️ ${records.msg}</div>`;
  return html`<div style="color: #28a745; font-size: 0.85rem;">✓ Matrix points parsed. Performance rendering pipeline active.</div>`;
}}`;


// Javascripts
```js
// --- HIGH INDEPENDENT PERFORMANCE VISUALIZATIONS ---
const plot_density = html`${() => {
  if (!records || records.error) return html`<div>No active data map trace.</div>`;

  const t = records.table;
  return Plot.plot({
    height: 480,
    grid: true,
    y: { reverse: true, label: "Depth (km)" },
    x: { label: "Position X Axis (km)" },
    color: { scheme: "viridis", label: "Density Value", legend: true },
    marks: [
      Plot.raster(t, {
        x: "x_km",
        y: "depth_km",
        fill: "density",
        interpolate: "nearest"
      })
    ]
  });
}}`;

const plot_ql = html`${() => {
  if (!records || records.error) return html`<div>No active data map trace.</div>`;

  const t = records.table;

  // Dynamic symetrical bounds computation for the divergent colormap
  const qlValues = t.getChild("ql").toArray();
  let maxAbs = 0;
  for (let i = 0; i < qlValues.length; i++) {
    const absV = Math.abs(qlValues[i]);
    if (absV > maxAbs) maxAbs = absV;
  }

  return Plot.plot({
    height: 480,
    grid: true,
    y: { reverse: true, label: "Depth (km)" },
    x: { label: "Position X Axis (km)" },
    color: {
      type: "diverging",
      scheme: "RdBu",
      domain: [-maxAbs, maxAbs],
      label: "QL Signature Amplitude",
      legend: true
    },
    marks: [
      Plot.raster(t, {
        x: "x_km",
        y: "depth_km",
        fill: "ql",
        interpolate: "nearest"
      })
    ]
  });
}}`;
```