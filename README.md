# MAPS — Microvascular Analysis & Phenotyping Suite

A MATLAB GUI for two-photon microvascular imaging analysis: vessel diameter over time from *xy* time-lapse imaging, and vascular density/morphology from a z-stack.

![MAPS logo](images/MAPSlogo.png)

See `example_MAPSGUI_xyDiam.mp4`, `example_MAPSGUI_linescan.mp4`, `example_MAPSGUI_zstack.mp4`, and `example_MAPSGUI_perivascCa.mp4` for videos of the GUI in use (recorded live on a laptop, sped up 4×) — one per analysis type, plus one covering the Perivascular Calcium option within xyDiam.

## Contents

- [Requirements](#requirements)
- [Graphical abstract](#graphical-abstract)
- [Getting started](#getting-started)
- [xyDiam — vessel diameter over time](#xydiam--vessel-diameter-over-time)
- [linescan — RBC velocity, haematocrit & flux from a repeated-line scan](#linescan--rbc-velocity-haematocrit--flux-from-a-repeated-line-scan)
- [zstack — vascular density from a z-stack](#zstack--vascular-density-from-a-z-stack)
- [Credits](#credits)
- [License](#license)

## Requirements

- MATLAB, R2023b or later recommended. `readstruct` (used for the `.xml` auto-detect path in both analysis types) needs R2020b+; `xline` (used in the zstack export figure) needs R2018b+.
- Image Processing Toolbox — `bwmorph`, `imfill`, `bwareaopen`, `poly2mask`, `bwboundaries`, `drawpolygon`, `roipoly` (xyDiam); `bwskel`, `bwdist`, `imresize3`, `imgaussfilt3`, `graythresh` (zstack); `radon`, `drawline` (linescan).
- No Statistics and Machine Learning Toolbox needed — the zstack percentile calculations use a small local implementation instead, and linescan's mean/SD/range/percentile figures are all base-MATLAB (`mean`/`std`/`min`/`max` with `'omitnan'`).

## Graphical abstract

![MAPS graphical abstract](images/maps_graphical_abstract.png)

One MATLAB GUI, four microvascular read-outs from the same two-photon dataset — `xyDiam` (vessel diameter over time), perivascular calcium (ΔF/F₀ or z-score, user-selectable), `linescan` (RBC velocity, haematocrit and flux) and `zstack` (density, branch length and tortuosity) — cross-validated against VasoMetrics (diameter) and the Drew-lab Radon method (RBC velocity).

## Getting started

```matlab
% from MATLAB, with this repo's folder on your path (or just cd into it):
MAPS
```

`MAPS.m` adds its own `subfunctions/` folder to the path automatically, so no manual setup is needed beyond having MATLAB + Image Processing Toolbox available.

The GUI always starts with the **Analysis type** dropdown — pick `xyDiam` or `zstack` *before* clicking **Load Data**, since the choice determines how the file gets read in.

Pixel size, frame rate, and (for zstack) z-step are auto-detected where possible when you load a TIF — checked in this order, stopping as soon as a value's found:
1. the TIF's own metadata (an ImageJ/Fiji-calibrated (hyper)stack's `XResolution` + `finterval`/`unit`/`spacing` fields),
2. a `.ini` file anywhere under the experiment folder (Scientifica/SciScan rigs),
3. a `.xml` file anywhere under the experiment folder (ThorLabs rigs).

Neither the `.ini` nor `.xml` step assumes a filename — both are found by extension, so renaming or relocating the accompanying metadata file doesn't break detection. Anything not found is left blank for manual entry in the Parameters panel.

Because that search is by extension across the whole experiment folder rather than by matching filename, **keep each TIF and its accompanying metadata file together in their own subfolder**, without any other TIFs or `.ini`/`.xml` files alongside them — with more than one candidate metadata file in scope, the GUI has no reliable way to tell which one actually belongs to the TIF you loaded, and could silently pick up the wrong pixel size/frame rate/z-step.

No data of your own to hand? `exampleData4Testing/` has a sample TIF plus its accompanying `.xml` for each analysis type — `xyDiam/vessel.tif` and `ZStack/Stack.tif` — so you can try either pipeline, including auto pixel-size/frame-rate/z-step detection, out of the box.

The red **Reset** button in the header (next to the credit line) discards all loaded/analysed data across all three analysis types and reopens a fresh instance — the fastest way back to a clean starting point before processing the next TIF, without closing and relaunching MATLAB by hand. It asks for confirmation first, since it can't be undone.

## xyDiam — vessel diameter over time

Given a time-lapse TIF of a vessel (single channel, one frame per timepoint), measures diameter over time using a full-width-at-half-maximum (FWHM) intensity profile along a manually defined vessel skeleton.

**What it does:**
1. Loads the TIF into MATLAB.
2. Lets you draw a skeleton (centreline) along the vessel, for one or more branches.
3. Lets you draw an ROI box around each branch to constrain the analysis region.
4. At every point along each skeleton, draws a line perpendicular to the vessel and measures the FWHM of the intensity profile across it, frame by frame — giving a continuous diameter trace per skeleton point, per branch, over time.
5. Displays the result live as a diameter heatmap (skeleton point × frame) and an averaged trace, and exports both the raw data and summary figures.

**Features:**
- **Multiple vessel branches** in one pass, each tracked and plotted in its own colour.
- **Perpendicular-line geometry via `atan2`**, so it holds up across vessel orientations (including near-vertical/horizontal segments) without special-casing, plus a fallback that reuses the last valid angle if a skeleton window is degenerate. The perpendicular intensity profile is sampled at **uniform 1-pixel arc length, in order from one end of the line to the other** (via `interp2`), so consecutive samples are exactly one pixel apart along the line and the FWHM `(i₂ − i₁) × pixel size` is a true distance at any vessel orientation. Validated against synthetic vessels of known FWHM at 0°/15°/30°/45° (orientation-flat) and against the VasoMetrics cross-line FWHM method on real recordings — see the manuscript.
- **Live visualisation** during the frame-by-frame scan — geometry sanity-check overlay first (so you can catch a bad skeleton/ROI before the full scan runs), then a filling-in heatmap and trace.
- **Perivascular calcium (optional)** — see below.
- **Export**: results as a `.mat` file (everything, one `results` struct) or as Excel workbooks (one per branch, plus a calcium-settings sidecar), and a multi-panel summary figure (vessel + skeleton + ROI + perpendicular lines, diameter heatmap, average trace — plus, if calcium was run, the calcium channel with the same perp lines, the actual sampled pixels, and the average dF/F0 *or* z-score trace) as PNG/PDF/FIG. Exactly what each format contains is listed under **[Data export](#data-export-xydiam)** below.

**Perivascular calcium (optional):** clicking the **Perivascular Calcium** button in the Processing options panel prompts for a second TIF (same field of view as the vessel channel); a green tick appears next to the button once a calcium channel is loaded (click it again to remove it). Once **GO** is run, MAPS samples fluorescence around each FWHM-detected vessel edge, per skeleton point/branch/frame — the same edge-expansion approach as the underlying `FWHM_diam_perivascCa_adapted.m` script. Numeric fields sit next to/below the button, all editable once a recording is loaded and all with sensible defaults, so you only need to touch the ones you want to change:
- **In (µm) / Out (µm)** — *editable* — how far the perivascular sampling band extends inside/outside each vessel edge (defaults 3.5 / 7 µm; converted to pixels at run time using the auto-detected pixel size, so the physical size is the same at any zoom — this reproduces the original 10 / 20 px behaviour at ~0.35 µm/px). If no pixel size is set, the values are treated as pixels and a note is printed.
- **Dark-offset floor** — automatic, not a GUI field: raw detector counts are rarely true-zero at rest, so before anything else, the 1st percentile of the *entire* calcium recording (every pixel, every frame) is taken as an estimate of that fixed floor and subtracted from it. Skipping this step would leave a leftover offset dominating dF/F0's denominator, making it come out artificially tiny (far below real transient sizes) regardless of genuine signal changes. Reported alongside the other calcium parameters in the data export for reference.
- **Normalisation** (Suite2p-inspired — see [References](#references)) — **BG ring (µm)**, **r**, and **Baseline (s)** are all *editable*: a further-out background ring (default 5 µm wide) is sampled as a local background reference — the perivascular equivalent of the *neuropil* reference used in two-photon somatic calcium imaging — and subtracted with coefficient **r** (default 0.7, Suite2p's own default neuropil coefficient) to remove common-mode brightness shared between the signal and background rings: out-of-focus and scattered light, drift, and field-wide changes caused by the dilation itself. Without it, F0 is inflated by background (so dF/F0 is under-reported) and any shared brightness change reads as spurious activity. The BG ring starts a **1 µm guard gap** beyond the Out ring, so the point-spread-function tail and edge-tracking jitter don't leak real signal straight into the background estimate. A sliding **maximin** baseline (Gaussian-smooth, then a sliding min filter, then a sliding max filter, all over the **Baseline (s)** window — default 60 s, matching Suite2p's own default) is then computed from the (dark-floor- and background-) corrected trace to give a genuine resting-fluorescence F0, and **dF/F0 = (F − F0) / F0** is what's shown live and in the export figure. Raw fluorescence, the background-ring signal, the background-subtracted trace, and dF/F0 are *all* kept in the data export — only the plots default to dF/F0. The background subtraction is the standard neuropil-subtraction step of two-photon calcium analysis (Kerlin et al. 2010; Chen et al. 2013; Pachitariu et al. 2017).
- **Background-ring quality checks** — after each branch, MAPS reports two numbers to the processing log and the data export (`caSigBgCorr`, `caBgKeptFrac`): the correlation between that branch's mean signal- and background-ring traces (a value near 1 warns that the background ring is picking up perivascular-cell signal, so `F − r·F_bg` is over-correcting — widen In/Out, move the ring out, or lower `r`), and the fraction of the background ring that fell inside the image/ROI (below 0.7 warns the background is being sampled from a biased sliver — draw a larger branch ROI or reduce the ring widths).
- **Both vessel edges are pooled into one number per skeleton point/frame**, matching `FWHM_diam_perivascCa_adapted.m`'s own behaviour — not tracked separately for the near/far side of the vessel.
- **A small negative dF/F0 is normal** (noise around a resting baseline, not censored) — but a frame/skeleton point where the baseline F0 is **at or near zero** is excluded (`NaN`) rather than reported. Two cases: background-ring subtraction can legitimately push the background-corrected trace (and so its own baseline) non-positive for a stretch; and a recording with a large fixed DC offset (a "pedestal") can leave F0 collapsed toward zero once the dark-offset floor and background have been subtracted. In either case dividing by F0 gives a huge, not-meaningfully-signed number rather than a real percentage change. MAPS blanks dF/F0 wherever F0 falls below **5 % of its typical (median positive) value**, and also blanks any remaining |dF/F0| > 20 as physically implausible, so the live/exported trace shows **gaps rather than divergent spikes**. The background-corrected trace is unaffected and remains the readout to use in that situation. (Same class of physical-floor guard as the linescan velocity noise floor.)

**Extraction: ΔF/F₀ or z-score.** Below the **Perivascular Calcium** button, the **Extraction:** dropdown chooses how the background-corrected signal is normalised. It is disabled until a calcium channel is loaded, and both options use the *same* perpendicular lines / branch ROI and the *same* In / Out / BG ring / r sampling bands — only the final normalisation step differs.
- **F/F0** (default) — the ΔF/F₀ pipeline described above, unchanged. The **Baseline (s)** field (sliding-maximin window, default 60 s) applies to this mode only.
- **ZScore** — expresses the signal relative to the *variability* of a quiescent baseline rather than its resting *level*, after Longden et al. (2021, see [References](#references)), who found a z-score more sensitive to very small, sparse events and more robust to the wide range of basal indicator brightness across capillaries. For each skeleton point MAPS takes the dimmest **Quiet %** of that point's finite samples as the quiescent baseline (default 35 %, matching Longden), then reports **z = (F_bgcorr − mean_q) / SD_q**. An optional **z thresh** field zeroes any |z| below this value. Longden et al. discard z < 2.5 as an event-detection cutoff; MAPS leaves it at **0 (off)** by default because it reports a continuous averaged trace for comparison against ΔF/F₀, not Longden's spatially-integrated event mass. **Quiet %** and **z thresh** replace the **Baseline (s)** field in the panel when ZScore is selected. Longden's spatial machinery (statistically defined active-site masks) is *not* used — MAPS already anchors sampling to the tracked vessel edges, so only the normalisation changes.

  *If you want a 2.5 cutoff, where you apply it matters — the two orders are not equivalent:*
  - **Threshold then average** (what the **z thresh** field does): each skeleton point's z-value is zeroed if |z| < 2.5, *then* the points are averaged into the branch trace. This is closest to Longden's per-column approach. A localised event that is real at a few points survives, because it clears the threshold *before* being diluted by the quiet points around it.
  - **Average then threshold** (dropping values < 2.5 from the exported `Avg perivascular Ca z-score` column afterwards): the branch trace is formed first, then thresholded. A localised event may already have been pulled below 2.5 by averaging it with the many quiet points in the band, so it never registers. Simpler, but less sensitive to small/focal events — the opposite of what the z-score is meant to buy you.
  - To do threshold-then-average yourself (e.g. to sweep the cutoff), leave **z thresh** at 0 and work from the full per-skeleton-point z-score — `results.cont_calcium_zscore` in the `.mat`, or the **ZScorePerSkelPoint** sheet in the Excel export (see [Data export](#data-export-xydiam)).

Both traces are always computed and exported regardless of the dropdown; it only changes which one is drawn live, plotted in the pop-out, and labelled on the y-axis (`\DeltaF/F_0` vs `z-score`). The z-score amplitude is in "SDs above rest", a detection/sensitivity aid rather than a physiological % change.

#### Data export (xyDiam)

Two formats, chosen when you click **Export data**:

*MAT file* (`MAPS_results.mat`, one `results` struct — everything, nothing summarised):
- `cont_diams{b}` — per-skeleton-point diameter over time, per branch; `times{b}`, `nanInds{b}`, `pxsz_um`, `fps`, `diamUnit`, `timeUnit`.
- Perivascular calcium (empty if not run), each `{b}` a skeleton-point × frame matrix: `cont_calcium` (raw AU), `cont_calcium_bg` (background ring), `cont_calcium_bgcorr` (background-subtracted), `cont_calcium_dFF` (ΔF/F₀), `cont_calcium_zscore` (**full** per-skeleton-point z-score — kept for a Longden-style position × time spatial analysis).
- Calcium parameters: `caInsideUm`/`caOutsideUm`/`caBgRingUm`/`caGuardUm` and their resolved-pixel forms, `caBgCoeff`, `caBaselineSec`, `caExtract`, `caQuietPct`, `caZThr`, `caDarkFloor`, and per-branch QC `caSigBgCorr`, `caBgKeptFrac`.

*Excel* — one workbook per branch, `<base>_Branch<k>.xlsx`, with up to three sheets:
- **Summary** — `Frame`, `Time (seconds)`, `Avg diam` (+ `Avg diam (pixels)` if the diameter unit isn't already pixels), then one **branch-average** column per calcium stage: `Avg perivascular Ca (AU)`, `… bg ring (AU)`, `… bg-corrected (AU)`, `… dF/F0`, `… z-score`.
- **PerSkelPoint** — `Frame`, `Time`, then `SkelPt01_diam …` and, if calcium was run, `SkelPtNN_calcium` / `_calciumBg` / `_calciumBgCorr` / `_calciumDFF` (one column per skeleton point per stage). **No z-score here** — it has its own sheet.
- **ZScorePerSkelPoint** — `Frame`, `Time`, `SkelPt01_zscore …` (one column per skeleton point). Written only when a z-score exists for that branch. This is the sheet to use for a position × time image of the z-scored signal / event-mass integration.
- If a MATLAB install can't write a multi-sheet `.xlsx`, PerSkelPoint and ZScorePerSkelPoint fall back to separate `_perSkelPoint` / `_zscorePerSkelPoint` files.

*Excel sidecar* — `<base>_calciumSettings.xlsx`, written once per Excel export when calcium was run:
- **Settings** sheet — every calcium parameter used for the run (In/Out/BG ring/guard in both µm and resolved px, `r`, extraction mode, Baseline (s) *or* Quiet %/z thresh, dark-offset floor, pixel size, frame rate).
- **BackgroundRingQC** sheet — per-branch `SignalBgCorr_r` and `BgRingKeptFrac`.
- The MAT `results` struct already carries all of these, so no sidecar is written for a MAT save.

**Workflow:**
1. **Analysis type** → `xyDiam`, then **Load Data** → select a vessel TIF (multi-frame, single channel).
2. In **Processing options**: set the number of branches, then **Generate skeleton** and **Draw around vessel branch** for each one. Click **Perivascular Calcium** and select a second TIF if you want it (adjust the In/Out/BG ring/r fields if the defaults don't suit, and pick **Extraction:** F/F0 or ZScore — tuning Baseline (s), or Quiet % / z thresh, as appropriate).
3. Check/enter **Pixel size (microns)** and **Frame rate (Hz)** in the Parameters panel (auto-filled where possible — see [Getting started](#getting-started)).
4. **GO** to run the analysis.
5. **Export data** / **Export figure** once it completes.

**References:**
- Pachitariu M, Stringer C, Dipoppa M, Schröder S, Rossi LF, Dalgleish H, Carandini M, Harris KD (2016). [Suite2p: beyond 10,000 neurons with standard two-photon microscopy](https://www.biorxiv.org/content/10.1101/061507v2). *bioRxiv* 061507. — source of the background-ring/neuropil-coefficient and sliding-baseline dF/F0 approach adapted above for perivascular calcium.
- Kerlin AM, Andermann ML, Berezovskii VK, Reid RC (2010). Broadly tuned response properties of diverse inhibitory neuron subtypes in mouse visual cortex. *Neuron* 67, 858–871. — neuropil (background) contamination and its subtraction in two-photon population imaging.
- Chen T-W, Wardill TJ, Sun Y, et al. (2013). Ultrasensitive fluorescent proteins for imaging neuronal activity. *Nature* 499, 295–300. — widely-used neuropil correction with contamination ratio ≈ 0.7.
- Longden TA, Mughal A, Hennig GW, et al. (2021). [Local IP3 receptor–mediated Ca²⁺ signals compound to direct blood flow in brain capillaries](https://www.science.org/doi/10.1126/sciadv.abh0101). *Science Advances* 7, eabh0101. — source of the z-score (quiescent-baseline SD) normalisation offered as an alternative to ΔF/F₀. No analysis code or raw data was released with the paper (the custom tools *VolumetryG9*, G.W. Hennig, and *SparkAn*, A. Bonev, are named but request-only), so MAPS's z-score is an independent implementation of the described method, not a port.

## linescan — RBC velocity, haematocrit & flux from a repeated-line scan

Given a repeated-line ("RBCV.tif"-style) two-photon scan — the same line traced over and over along a vessel's centreline, so each row of the TIF is one more sweep of it — measures red blood cell (RBC) velocity, haematocrit, and flux in a sliding window along the recording, using the space–time streak pattern RBCs leave behind as they pass through the scanned line.

**What it does:**
1. Loads the TIF as a space–time image: rows = successive scan lines (time), columns = position along the scanned line (space).
2. Binarises it (adjustable threshold) to separate RBCs (dark, low-signal — they occlude the labelled plasma) from plasma (bright).
3. Steps a sliding window (size in ms, always kept a multiple of 4 lines; step = ¼ window) along the recording. In each window:
   - **Angle → velocity**: a two-pass Radon transform (coarse over 0–179°, then a fine ±3° pass at 0.1° steps around the coarse peak) finds the streak angle θ, exactly the method in [Drew et al. 2010](#references). Apparent velocity is `V_app = (pixel size / line time) · cot(θ)` — using the *per-pixel* spatial size (not the scanned line's total width), so the result comes out directly in mm/s.
   - **Haematocrit**: percentage of binarised-dark pixels in the window (RBCs occlude the plasma label, so % dark ≈ % of the vessel cross-section occupied by RBCs at that moment).
   - **RBC flux**: number of RBC crossings per second, counted as transitions (dark↔light) along the window's centre spatial pixel over time — each RBC passage is one dark run, i.e. two transitions.
4. Displays all three live as they're computed — the raw/binary panels and small window preview step through the data in sync with the sliding window, and the three result traces grow window-by-window (mirrors the xyDiam live view) — so you can watch the full run rather than wait for a static end result.
5. Displays each trace with a 2-line title: what it is, then that trace's mean/SD/range across the whole recording (computed from the raw per-window values, not the smoothed display line below).

**Features:**
- **Live per-window QC before committing to a full run**: click **Check line angle** on the current sliding window to see its direction (anterograde/retrograde/uncertain) and signal quality (SNR) without running the whole recording; **Detect individual RBCs** overlays a count for just that window, from dark-run detection at *both* the left and right edges of the window (averaged) — using both edges rather than one catches streaks that are faint or exit the window before reaching a single edge, and separates closely-spaced RBCs that blur together on one side but not the other. Both update live as you move the frame/window sliders/slider.
- **Optional width-only crop**: draw a line across the width on the raw display, double-click to confirm; only the *spatial* extent is cropped (never height/time, which would corrupt the timing calculation). Re-clickable to redraw before confirming, or to reset and crop again afterwards. Applied across the whole recording, and re-binarising is required afterwards.
- **Scan-velocity (Vscan) correction** — optional, off by default (see [Corrections applied](#corrections-applied) below).
- **Live traces, colour-coded**: RBC velocity (red), haematocrit (purple), RBC flux (green) — each panel filling the available space rather than a fixed small tile.
- **Export figure** pops the three result graphs out into a standalone, savable figure (PNG/PDF/FIG) — same pattern as the xyDiam/zstack export.

**Corrections applied:**

*Detecting scan direction.* An RBC passing through the scanned line shows up as a diagonal streak (shadow) in the space–time image, and which way that streak leans encodes not just speed but sign — the same two-pass Radon transform used for velocity above gives an angle whose sign carries the direction. Rather than trust any single window (noisy windows can read the wrong sign), the recording's overall scan direction is taken from the **sign of the median** apparent velocity across every window in the run - median rather than mean specifically so that a handful of noisy/wrong-signed windows can't flip the whole recording's classification. A positive median is labelled **retrograde**, a negative one **anterograde** (and its sign flipped so reported velocity is positive) - this happens automatically once **Run Linescan Analysis** completes; there's no manual direction selection.

*Apparent-to-true velocity.* The Radon-transform angle gives an *apparent* velocity, which only equals the RBC's true velocity if the scan itself is effectively instantaneous. In reality, the beam takes a finite time to sweep across the line — the **scan velocity**, `Vscan = (line width) / (line time)` — and if the RBC's own motion is a non-trivial fraction of that, the streak angle is measurably distorted by the scan's own sweep, not just the RBC's motion. Correcting for it (checkbox: **Apply scan-velocity correction (Vscan)**) uses one of two formulas, chosen by this code's own window-by-window sign classification of the recording (labelled on screen and in exports as **retrograde**/**anterograde**):
- Same-sign case (labelled **retrograde**): `V_true = V_app · Vscan / (Vscan − V_app)` — the denominator approaches zero as `V_app → Vscan`, so this branch is only numerically valid when `Vscan` is comfortably larger than the true velocity.
- Opposite-sign case (labelled **anterograde**): `V_true = V_app · Vscan / (Vscan + V_app)` — always well-conditioned, no such limit.

This is the classic correction from the two-photon line-scan RBC-velocimetry literature pioneered by the Kleinfeld and Charpak groups (see [References](#references)). It's **off by default** since whether it's appropriate depends on your scan settings relative to the flow speeds you're imaging — it isn't assumed to apply universally. Ticking it shows *three* velocity traces for direct comparison: the raw apparent velocity (red, always shown, uncorrected), the corrected velocity without the validity filter applied (yellow — shows what the correction does before implausible windows are removed), and the corrected velocity with that filter applied (blue — the value actually reported/exported). If the filter removes most of the run (`Vscan` too close to the measured velocity for most windows), the reported value automatically falls back to the uncorrected apparent velocity rather than reporting a mostly-empty result, and this is flagged in the processing log and next to the on-screen Direction readout.

**Which direction the correction is recommended for.** Chaigneau & Charpak (2022; see [References](#references)) define *anterograde* scanning as the beam sweeping the *same* direction as flow — which they show *overestimates* apparent velocity — and *retrograde* as *opposite* to flow, which *underestimates* and gives access to a wider reliably-measurable velocity range. That's the reverse pairing from what the label names above might suggest at a glance, and this code's retrograde/anterograde labels are assigned purely from the measured *sign* of the apparent velocity, not from independent knowledge of which way the beam scans relative to blood flow — so the two couldn't just be assumed to line up. That mapping is now settled from direct observation of RBC-shadow slant on real recordings: a streak running **higher on the left-hand side and lower on the right-hand side** of the window corresponds to the `retrograde` label above (confirmed against this exact Radon pipeline: this slant gives a positive apparent velocity, which is what triggers the `retrograde` branch) - **and it's this slant/direction that the scan-velocity correction is recommended for.** The opposite slant (lower-LHS, higher-RHS; `anterograde`) is *not* a recommended case for the correction. The on-screen note next to the Direction readout (and the live per-window "Check line angle" result) states this explicitly, with the matching slant arrow (↘/↗), once a direction is determined.

*Physical floors.* Velocity at or below the noise floor (< 0.1 mm/s, including any negative value once a scan direction is established — a corrected velocity in the established flow direction can't be negative) is treated as unreliable and excluded (`NaN`) rather than plotted or averaged.

*Display smoothing.* All three live/exported traces show a 5-window moving mean (NaN-aware, so a run of excluded windows doesn't spread into its neighbours) — linescan data is noisy window-to-window. The underlying stored/exported values are always the raw, unsmoothed per-window numbers; only the line drawn on screen is smoothed.

**Workflow:**
1. **Analysis type** → `linescan`, then **Load Data** → select a repeated-line-scan TIF.
2. Check/enter **Pixel size (microns)** and **Frame rate (Hz)** in the Parameters panel (auto-filled where possible — see [Getting started](#getting-started)); set **Window (ms)** if the default doesn't suit (must be divisible by 4 — an invalid entry is flagged in red and reverts).
3. In **Preprocessing**: optionally **Crop (width)**, then **Binarise** (adjust the threshold slider as needed). Use **Check line angle** / **Detect individual RBCs** on a window or two first to sanity-check signal quality before committing to a full run.
4. Tick **Apply scan-velocity correction (Vscan)** if you want it (off by default — see [Corrections applied](#corrections-applied)).
5. **Run Linescan Analysis** — watch it progress live, or wait for it to finish.
6. **Export figure** once it completes.

**References:**
- Drew PJ, Blinder P, Cauwenberghs G, Shih AY, Kleinfeld D (2010). [Rapid determination of particle velocity from space-time images using the Radon transform](https://link.springer.com/article/10.1007/s10827-009-0159-1). *Journal of Computational Neuroscience* 29(1-2):5-11. — the angle-detection method used here.
- Chaigneau E, Oheim M, Audinat E, Charpak S (2003). [Two-photon imaging of capillary blood flow in olfactory bulb glomeruli](https://www.pnas.org/doi/10.1073/pnas.2133652100). *PNAS* 100(22):13081-13086. — foundational two-photon line-scan RBC-velocity methodology, source of the scan-velocity correction's naming above.
- Chaigneau E, Charpak S (2022). [Measurement of Blood Velocity With Laser Scanning Microscopy: Modeling and Comparison of Line-Scan Image-Processing Algorithms](https://www.frontiersin.org/articles/10.3389/fphys.2022.848002/full). *Frontiers in Physiology* 13:848002. — a modern, comprehensive comparison of line-scan velocity algorithms and corrections, including the apparent-vs-true/scan-velocity relationship above.

## zstack — vascular density from a z-stack

Given a z-stack TIF of the vasculature, thresholds and skeletonises it in 3D to give vessel density, per-vessel length/diameter/depth/tortuosity, and how far tissue sits from its nearest vessel — a MATLAB-native stand-in for a Fiji pipeline (Skeletonize 3D + 3D Distance Map + AnalyzeSkeleton_).

**What it does:**
1. Loads the z-stack into MATLAB.
2. **Preprocessing**: threshold the stack (Otsu/IsoData/Triangle auto, or manual, with optional per-frame-range overrides), with an optional Gaussian smoothing step first — smoothing (and the 3D mask clean-up described below) is usually what fixes a skeleton that isn't tracking vessel centres. A live **Skeleton preview** overlays a quick 2D skeleton on the current thresholded frame, so pruning can be tuned by eye before committing to the full 3D run.
3. **Process Stack**: builds the binarised volume, resamples to isotropic voxels where feasible (so the distance map/branch lengths aren't distorted by anisotropic z-spacing), smooths the mask in 3D (morphological open/close with a spherical structuring element, sized in microns) to round out small surface bumps, skeletonises in 3D (`bwskel`, with `MinBranchLength` pruning), computes a 3D distance transform, and extracts per-branch length/diameter/depth/tortuosity (a simplified stand-in for Fiji's `AnalyzeSkeleton_` graph — junction voxels are removed and each remaining connected component is one branch).
4. Reports vascular density (total vessel length ÷ tissue volume analysed), mean tortuosity, and the 50th/95th percentile tissue-to-vessel distance, highlighted in their own results box.
5. Displays skeleton and distance-map max-projections, and diameter/length/tortuosity by depth plus a distance-to-nearest-vessel histogram; exports the underlying data and a multi-panel summary figure.

**Features:**
- **Per-frame-range threshold overrides** — carve out a sub-range of frames (e.g. deeper slices needing a different value) via Start/End range, on top of the whole-stack default. To set one: step to the range's *first* frame and click **Start range**; step to its *last* frame; tick **Manual threshold** (or leave it unticked to use Auto for just that range) and, if manual, drag the slider to the value you want *for that range* — the preview on the frame you're on updates live as you drag; then click **End range & apply**. Frames outside the range you just defined keep whatever they had before (unaffected by this). A fixed bug worth knowing about if you used an earlier build: toggling Manual threshold used to change the currently-active segment immediately, which — if no range had been carved out yet — could be the *whole stack*, and that mutation could leak into the leftover frames once a range was applied on top of it (i.e. defining frames 1–6 as manual could silently make the rest manual too). Manual threshold no longer touches any stored segment while a range is pending; it only affects the segment being defined.
- **Gaussian smoothing** (adjustable σ) applied before thresholding, grouped with Auto/Manual threshold since it shapes the same raw data.
- **3D mask smoothing** (morphological open/close, ~2 µm structuring element radius) applied before skeletonising, to stop small surface irregularities pulling the medial axis off-centre — most noticeable on large vessels, where a swirling/spiral skeleton instead of a straight centreline is a sign this is needed.
- **Live skeleton preview** with adjustable pruning (`MinBranchLength`, in voxels), so you can see the effect of a pruning change immediately.
- **Branch length via a smoothed centreline, not a raw sum**: each branch's skeleton voxels are walked end-to-end (graph diameter) into an ordered path, then smoothed (moving average) before measuring length — corrects for the same swirl/spiral artifact on large vessels rather than just summing however wiggly the raw path is.
- **Tortuosity** per vessel segment: actual (skeleton) path length ÷ straight-line ("as the crow flies") distance between its start and end points. 1.0 is perfectly straight, higher is more tortuous. Reported as a mean across all branches (results box) and per-branch, plotted against depth and included in the data export.
- **Slant-correct:** — two independent, opt-in tissue-volume corrections grouped under this subheading, directly above the stack display. Both are off by default, both change the reported density/distance numbers when on, and both are flagged explicitly in the exports (see below) — **never turn themselves on** based on anything detected in the stack.
  - **Tissue signal (10um)**: a stack imaged at a slight angle to the tissue surface has some genuinely empty/black space inside its rectangular W × H × D bounding box at any given depth, which a plain box-volume calculation counts as tissue and so understates density. When ticked, the volume is instead built up from ~10 µm z-bins (rounded to the nearest whole frame for that stack's own z-step), each contributing only the xy area that actually shows tissue signal (rather than reads as empty/black) somewhere within that bin. This is applied consistently to everything volume-dependent, not just the headline density number: the same tissue mask also restricts which voxels count toward the tissue-to-vessel distance percentiles/histogram (so black/non-tissue space can't inflate those), and the results box shows the corrected "Total volume" (mm³) rather than leaving the displayed number looking unchanged — the full H × W × D bounding-box breakdown behind that number is kept for the exported figure's title, where there's room for it. It's deliberately scoped to *volume* only — the skeleton, branch lengths/diameters/depths, and tortuosity are unaffected either way, since those describe where the vessels are, not how much of the imaged box counts as tissue.
  - **Vessel boundary**: a second, independent density measure. Rather than a bounding box or a raw-intensity black test, this one uses the actual thresholded vessel mask itself: for each frame independently, if it has any vessel signal, that frame's "tissue" is taken as the convex hull of its vessel-positive pixels (the region a vessel network was actually detected spanning in that frame) — a frame with no vessel signal at all contributes nothing. The same per-frame boundary also restricts a second tissue-to-vessel distance sample/percentile pair, for consistency with the second volume, and its coordinates are saved per frame (see Export below) so the exact outline used can be checked or reused later. Deliberately kept out of the main plots to avoid clutter — it shows up in its own yellow panel on the right side of the (green) results box, labelled **"Boundary restricted:"**, following the exact same 4-line layout as the green "Full tissue:" panel on the left (title, then density + tortuosity, then total volume, then tissue-to-vessel distance percentiles — always labelled, so the two sides read the same way), and everywhere in the data exports, labelled `boundaryRestricted`. When ticked, that frame's convex hull is also drawn live on the stack display as a dotted, semi-transparent yellow line (updates as you step through frames), in the same yellow as the results-box panel. **Export figure** only offers this as a volume-definition choice ("Full tissue" vs "Boundary-restricted") when it was actually computed for the results being exported; choosing boundary-restricted also overlays that frame-by-frame boundary, dotted and semi-transparent in the same yellow, on the skeleton and distance-map plots, so it's visible what's actually being restricted to, and the default filename it offers when saving is tagged `_boundaryRestricted` so it can't silently overwrite a full-tissue export of the same stack.
  - **Comparability warning**: ticking or unticking *either* checkbox posts *"Data may not be comparable between stacks if diff slant corrections applied (or not)."* to the status bar — both corrections only ever shrink the tissue volume they touch, so a stack processed with a correction on will typically read a higher density than the same stack with it off, purely from the smaller denominator, not a real biological difference. Decide up front whether a correction applies to the whole comparison (e.g. every stack from a rig/protocol known to image at an angle) and apply it uniformly, rather than mixing settings within the same analysis.
- **50th/95th percentile tissue-to-vessel distance**, shown in the results box; the full 5th–95th percentile range (2.5% steps) is included in the data export. Its histogram's sample count is capped at 2,000,000 voxels (subsampled if there are more, purely so it computes quickly) — if a plot title reads exactly `nVox=2000000`, that's this cap being hit, not a coincidence. The raw per-voxel distance list in the Excel export is capped further still (500,000 rows, subsampled) — an Excel sheet can only hold ~1,048,576 rows including its header, so the full 2,000,000-row list can't fit there; the `.mat` export isn't affected by this and keeps the full list.
- Plot titles label their n by what it's actually counting — `nVess=` for the per-branch plots (diameter/length/tortuosity by depth), `nVox=` for the distance-to-vessel histogram (a count of background voxels, not 2D pixels) — in both the live GUI and the exported figure.
- **Export**: results as a `.mat` file or as Excel files — summary (includes explicit `VolumeSlantCorrected`/`BoundaryRestrictApplied` flags so it's clear from the file alone which corrections were on), per-vessel length/diameter/depth/tortuosity, tissue-to-vessel distances for both volume definitions, distance percentiles for both, and the threshold/smoothing/pruning settings used (useful for a methods write-up) — six files, plus a seventh, `_boundaryCoordinates.xlsx` (Frame/X_px/Y_px, one row per boundary point per frame), only when **Vessel boundary** was ticked for that run. The `.mat` file carries the same flags (`results.summary.volumeSlantCorrected`, `results.summary.boundaryRestrictApplied`) plus the per-frame coordinates themselves (`results.boundaryRestricted.coords`). Also exports a multi-panel summary figure (layered skeleton and distance-map slices with a shared depth axis — the distance-map colourbar is labelled "Distance to vessel (um)" rather than a bare "um" — diameter/length/tortuosity by depth, and the distance histogram with the 50th/95th percentile marked) as PNG/PDF/FIG.

**Workflow:**
1. **Analysis type** → `zstack`, then **Load Data** → select a z-stack TIF.
2. In **Preprocessing**: turn on **Auto threshold** (or **Manual threshold**), optionally **Smooth**, and add per-range overrides with **Start range** / **End range & apply** if needed. Tick **Skeleton preview** and adjust **Prune (vox)** to check the skeleton looks right before running the full analysis.
3. Check/enter **Pixel size (microns)** and **Z-step (microns)** in the Parameters panel (auto-filled where possible). Under **Slant-correct:**, above the stack display, tick **Tissue signal (10um)** and/or **Vessel boundary** if your stacks need one or both corrections (see Features above) — either tick posts a comparability warning to the status bar.
4. **Process Stack** — if pixel size/z-step are still missing, a dialog prompts for them rather than failing partway through.
5. **Export data** / **Export figure** once it completes. Export figure asks which tissue volume definition ("Full tissue" or "Boundary-restricted") to build the figure around, only when Vessel boundary was ticked for that run — see Features above.

## Planned / in development

These are scaffolded in the GUI but **not yet validated** — they need data that is still being collected.

> The **z-score** extraction option for perivascular calcium (Longden et al. 2021) is now implemented and documented in [xyDiam → Perivascular calcium](#xydiam--vessel-diameter-over-time) above. It still needs real data to answer the open question — *does the z-score catch small perivascular transients that ΔF/F₀ misses?* — but the code path is live, not scaffolding.

### `Widefield perivascular calcium` analysis mode (placeholder)

The existing perivascular-calcium path assumes a **zoomed-in** recording in which the vessel walls are resolved, so the signal can be sampled in bands referenced to each FWHM edge. **Widefield** recordings (large field, many vessels, walls not resolved) break that assumption. A separate `Widefield perivascular calcium` dropdown option is present but **inert** — selecting it posts a "not yet implemented" message. It will likely need Longden-style statistically defined active-site masks (derived from the Ca²⁺ events themselves) rather than edge-referenced bands. Deferred until widefield data are available.

## Credits

Developed by [Kira Shaw](mailto:kira.shaw@manchester.ac.uk) (University of Manchester) and Catherine N Hall. GUI built with [Claude Code](https://claude.com/claude-code) assistance.

The underlying analysis methods (vessel diameter via FWHM, vascular density/morphology from a skeletonised z-stack, and the linescan velocity/haematocrit/flux methods above) were originally developed in Catherine Hall's lab group, prior to and independent of this GUI. They were used, for example, in Shaw K, Bell L, Boyd K, Grijseels DM, Clarke D, Bonnar O, Crombag HS, Hall CN (2021). [Neurovascular coupling and oxygenation are decreased in hippocampus compared to neocortex because of microvascular differences](https://www.nature.com/articles/s41467-021-23508-y). *Nature Communications* 12:3190. The original (non-GUI) analysis scripts are available separately at [shaw-lab-uom/original-vascular-analysis-scripts](https://github.com/shaw-lab-uom/original-vascular-analysis-scripts); MAPS is a GUI-driven adaptation of that underlying analysis, built with Claude Code assistance.

`subfunctions/ini2struct.m` is a third-party utility by Andriy Nych, included as-is (see its header) — it is not covered by this repo's license below.

## License

MIT — see [LICENSE](LICENSE).
