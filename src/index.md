---
html_modules: true
style: custom.css
---

# 🌐 Double IQD Experiment Analysis Matrix

Welcome to the **Double IQD (Interval-Quality-based Detrending)** interactive exploration dashboard. This interface enables real-world scientific exploration of geometric and density modeling configurations.

Using **Apache Arrow** and **Arquero**, we achieve instant client-sided query execution and extremely high-performance rendering directly from our pre-processed, ZSTD-compressed data partitions.

---

<div class="card controls-card">
  <div class="control-group">
    <label for="windowSize">🔍 Window Size (km)</label>
    <div>${viewWindowSize}</div>
  </div>
  <div class="control-group">
    <label for="baseline">⚖️ Detrending Baseline Model</label>
    <div>${viewBaseline}</div>
  </div>
  <div class="control-group">
    <label>📊 Window Ratio</label>
    <div style="padding-top: 5px; font-weight: bold; color: var(--theme-foreground-muted, #718096);">5 (Fixed)</div>
  </div>
</div>

```javascript
// Define interactive inputs
const viewWindowSize = Inputs.select([10.0, 20.0], {value: 10.0, format: d => `${d.toFixed(1)} km`});
const viewBaseline = Inputs.select(["MeanMatchedBaseline", "ZeroBaseline"], {value: "MeanMatchedBaseline", label: ""});

// Obtain reactive values
const windowSize = Generators.input(viewWindowSize);
const baseline = Generators.input(viewBaseline);
```

---

```javascript
// Import explicit high-performance Arrow IPC tables parsing engine
import * as Arrow from "npm:apache-arrow";
import * as aq from "npm:arquero";

// Statically pre-loaded paths mapped as FileAttachments
const attachments = {
  "10.0_5_ZeroBaseline_density": FileAttachment("data/double_iqd/window_size=10.0/ws_ratio=5/baseline=ZeroBaseline/density_xz.arrow"),
  "10.0_5_ZeroBaseline_ql": FileAttachment("data/double_iqd/window_size=10.0/ws_ratio=5/baseline=ZeroBaseline/ql_xz.arrow"),

  "10.0_5_MeanMatchedBaseline_density": FileAttachment("data/double_iqd/window_size=10.0/ws_ratio=5/baseline=MeanMatchedBaseline/density_xz.arrow"),
  "10.0_5_MeanMatchedBaseline_ql": FileAttachment("data/double_iqd/window_size=10.0/ws_ratio=5/baseline=MeanMatchedBaseline/ql_xz.arrow"),
  "10.0_5_MeanMatchedBaseline_profile_x": FileAttachment("data/double_iqd/window_size=10.0/ws_ratio=5/baseline=MeanMatchedBaseline/profile_x.arrow"),
  "10.0_5_MeanMatchedBaseline_profile_depth": FileAttachment("data/double_iqd/window_size=10.0/ws_ratio=5/baseline=MeanMatchedBaseline/profile_depth.arrow"),

  "20.0_5_ZeroBaseline_density": FileAttachment("data/double_iqd/window_size=20.0/ws_ratio=5/baseline=ZeroBaseline/density_xz.arrow"),
  "20.0_5_ZeroBaseline_ql": FileAttachment("data/double_iqd/window_size=20.0/ws_ratio=5/baseline=ZeroBaseline/ql_xz.arrow"),

  "20.0_5_MeanMatchedBaseline_density": FileAttachment("data/double_iqd/window_size=20.0/ws_ratio=5/baseline=MeanMatchedBaseline/density_xz.arrow"),
  "20.0_5_MeanMatchedBaseline_ql": FileAttachment("data/double_iqd/window_size=20.0/ws_ratio=5/baseline=MeanMatchedBaseline/ql_xz.arrow"),
  "20.0_5_MeanMatchedBaseline_profile_x": FileAttachment("data/double_iqd/window_size=20.0/ws_ratio=5/baseline=MeanMatchedBaseline/profile_x.arrow"),
  "20.0_5_MeanMatchedBaseline_profile_depth": FileAttachment("data/double_iqd/window_size=20.0/ws_ratio=5/baseline=MeanMatchedBaseline/profile_depth.arrow")
};

// Generic pipeline to fetch, parse, and convert to plain Javascript objects
async function loadAndOptimize(attachment) {
  if (!attachment) return [];
  const buffer = await attachment.arrayBuffer();
  const table = Arrow.tableFromIPC(new Uint8Array(buffer));
  return aq.fromArrow(table).objects();
}
```

```javascript
// Reactively load current selection
const densityData = loadAndOptimize(attachments[`${windowSize.toFixed(1)}_5_${baseline}_density`]);
const qlData = loadAndOptimize(attachments[`${windowSize.toFixed(1)}_5_${baseline}_ql`]);

// Conditionally load profile data based on baseline selection
const profileXData = baseline === "MeanMatchedBaseline"
  ? loadAndOptimize(attachments[`${windowSize.toFixed(1)}_5_MeanMatchedBaseline_profile_x`])
  : Promise.resolve([]);

const profileDepthData = baseline === "MeanMatchedBaseline"
  ? loadAndOptimize(attachments[`${windowSize.toFixed(1)}_5_MeanMatchedBaseline_profile_depth`])
  : Promise.resolve([]);
```

## 🗺️ 2D Vertical Slice Field Models

The graphs below display the 2D cross-section ($X$-$Z$ space) of the experimental environment. Scroll over the plots to investigate exact coordinates and continuous numerical values.

<div class="grid-cols-2">
  <div class="card">
    <h3>🌋 Density ($g / cm^3$) Field Distribution</h3>
    <p class="muted">Visualizes vertical distribution of earth density. X-axis specifies position, Y-axis represents depth (increasing downwards).</p>
    <div>
      ${resize((width) => Plot.plot({
        width: Math.max(400, width),
        height: 380,
        color: { scheme: "turbo", legend: true, label: "Density (g/cm³)" },
        x: { label: "X Coordinates (km)" },
        y: { reverse: true, label: "Depth (km)" },
        marks: [
          Plot.cell(densityData, { x: "x_km", y: "depth_km", fill: "value", tip: true })
        ]
      }))}
    </div>
  </div>

  <div class="card">
    <h3>⚡ Ql (Quality Factor Interval) Energy Field Map</h3>
    <p class="muted">Visualizes the computed attenuation profile (inverted quality factor metric) in $X$-$Z$ dimensional space.</p>
    <div>
      ${resize((width) => Plot.plot({
        width: Math.max(400, width),
        height: 380,
        color: { scheme: "warm", legend: true, label: "Ql Metric" },
        x: { label: "X Coordinates (km)" },
        y: { reverse: true, label: "Depth (km)" },
        marks: [
          Plot.cell(qlData, { x: "x_km", y: "depth_km", fill: "value", tip: true })
        ]
      }))}
    </div>
  </div>
</div>

---

## 📐 1D Boundary Boundary Profiles

1D boundary profiles map horizontal and vertical sections across specific detrending baselines, detailing discrete trends on coordinate borders.

<div>
  ${
    baseline === "MeanMatchedBaseline"
    ? html`
      <div class="grid-cols-2">
        <div class="card">
          <h4>📉 Profile X (Across Depth)</h4>
          <p class="muted">Vertical boundary values ($value$ vs. $depth\_km$). Plotted vertically with reversed Y-axis to mirror deep geophysical structures.</p>
          <div>
            ${resize((width) => Plot.plot({
              width: Math.max(400, width),
              height: 350,
              x: { label: "Value" },
              y: { reverse: true, label: "Depth (km)" },
              marks: [
                Plot.lineY(profileXData, { y: "depth_km", x: "value", stroke: "#2b6cb0", strokeWidth: 2 }),
                Plot.dot(profileXData, { y: "depth_km", x: "value", fill: "#2b6cb0", r: 2.5, tip: true })
              ]
            }))}
          </div>
        </div>

        <div class="card">
          <h4>📈 Profile Depth (Across X-Position)</h4>
          <p class="muted">Horizontal profile slice ($value$ along $x\_km$). Illustrates surface matching trends along the longitudinal coordinate.</p>
          <div>
            ${resize((width) => Plot.plot({
              width: Math.max(400, width),
              height: 350,
              x: { label: "X Coordinate (km)" },
              y: { label: "Profile Value" },
              marks: [
                Plot.areaY(profileDepthData, { x: "x_km", y: "value", fill: "#319795", fillOpacity: 0.15 }),
                Plot.lineY(profileDepthData, { x: "x_km", y: "value", stroke: "#319795", strokeWidth: 2 }),
                Plot.dot(profileDepthData, { x: "x_km", y: "value", fill: "#319795", r: 2.5, tip: true })
              ]
            }))}
          </div>
        </div>
      </div>
    `
    : html`
      <div class="card info-banner">
        <strong>⚠️ Profiles Unavailable</strong>
        <p style="margin: 0.5rem 0 0 0; color: #4a5568;">
          The <strong>ZeroBaseline</strong> model applies a zero-field assumption on outer boundaries, removing matching boundary metrics. Therefore, 1D Profiles do not exist for this detrending configuration.
          To explore horizontal and vertical boundary slices, please select <strong>MeanMatchedBaseline</strong> in the control panel.
        </p>
      </div>
    `
  }
</div>


// Define relative configuration base paths pointing to your deployed DVC assets
const DATA_BASE_URL = "data/double_iqd";