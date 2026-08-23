# MAPS — Microvascular Analysis & Phenotyping Suite

A MATLAB GUI for two-photon microvascular imaging analysis: vessel diameter over time from *xy* time-lapse imaging, and vascular density/morphology from a z-stack.

![MAPS logo](images/MAPSlogo.png)

See `example_MAPS_GUI_4x_small.mp4` for a video of the GUI in use (recorded live on a laptop, sped up 4×).

## Contents

- [Requirements](#requirements)
- [Getting started](#getting-started)
- [xyDiam — vessel diameter over time](#xydiam--vessel-diameter-over-time)
- [zstack — vascular density from a z-stack](#zstack--vascular-density-from-a-z-stack)
- [linescan — not yet implemented](#linescan--not-yet-implemented)
- [Credits](#credits)
- [License](#license)

## Requirements

- MATLAB, R2023b or later recommended. `readstruct` (used for the `.xml` auto-detect path in both analysis types) needs R2020b+; `xline` (used in the zstack export figure) needs R2018b+.
- Image Processing Toolbox — `bwmorph`, `imfill`, `bwareaopen`, `poly2mask`, `bwboundaries`, `drawpolygon`, `roipoly` (xyDiam); `bwskel`, `bwdist`, `imresize3`, `imgaussfilt3`, `graythresh` (zstack).
- No Statistics and Machine Learning Toolbox needed — the zstack percentile calculations use a small local implementation instead.

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

No data of your own to hand? `exampleData4Testing/` has a sample TIF plus its accompanying `.xml` for each analysis type — `xyDiam/vessel.tif` and `ZStack/Stack.tif` — so you can try either pipeline, including auto pixel-size/frame-rate/z-step detection, out of the box.

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
- **Perpendicular-line geometry via `atan2`**, so it holds up across vessel orientations (including near-vertical/horizontal segments) without special-casing, plus a fallback that reuses the last valid angle if a skeleton window is degenerate.
- **Live visualisation** during the frame-by-frame scan — geometry sanity-check overlay first (so you can catch a bad skeleton/ROI before the full scan runs), then a filling-in heatmap and trace.
- **Export**: results as a `.mat` file or as one Excel file per branch (frame, time in seconds, average diameter, per-skeleton-point diameters), and a multi-panel summary figure (vessel + skeleton + ROI + perpendicular lines, diameter heatmap, average trace) as PNG/PDF/FIG.

**Workflow:**
1. **Analysis type** → `xyDiam`, then **Load Data** → select a vessel TIF (multi-frame, single channel).
2. In **Processing options**: set the number of branches, then **Generate skeleton** and **Draw around vessel branch** for each one.
3. Check/enter **Pixel size (microns)** and **Frame rate (Hz)** in the Parameters panel (auto-filled where possible — see [Getting started](#getting-started)).
4. **GO** to run the analysis.
5. **Export data** / **Export figure** once it completes.

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

## linescan — not yet implemented

Scaffolded in the **Analysis type** dropdown for a future analysis mode, but not yet built.

## Credits

Developed by [Kira Shaw](mailto:kira.shaw@manchester.ac.uk), University of Manchester. GUI built with [Claude Code](https://claude.com/claude-code) assistance.

`subfunctions/ini2struct.m` is a third-party utility by Andriy Nych, included as-is (see its header) — it is not covered by this repo's license below.

## License

MIT — see [LICENSE](LICENSE).
