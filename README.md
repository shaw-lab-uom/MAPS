# MAPS
Microvascular Analysis &amp; Phenotyping Suite

# MAPS — Microvascular Analysis & Phenotyping Suite

A MATLAB GUI for measuring vessel diameter over time from two-photon *xy* time-lapse imaging, using a full-width-at-half-maximum (FWHM) intensity profile along a manually defined vessel skeleton.


## What it does

Given a time-lapse TIF of a vessel (single channel, one frame per timepoint), MAPS:

1. Loads the TIF into MATLAB.
2. Lets you draw a skeleton (centreline) along the vessel, for one or more branches.
3. Lets you draw an ROI box around each branch to constrain the analysis region.
4. At every point along each skeleton, draws a line perpendicular to the vessel and measures the FWHM of the intensity profile across it, frame by frame — giving a continuous diameter trace per skeleton point, per branch, over time.
5. Displays the result live as a diameter heatmap (skeleton point × frame) and an averaged trace, and exports both the raw data and summary figures.

See `example_MAPS_GUI_xyDiam_4x_small.mp4` for a demo of the workflow (sped up 4×).

## Features

- **Multiple vessel branches** in one pass, each tracked and plotted in its own colour.
- **Automatic pixel size / frame rate detection** when loading a TIF — checks, in order:
  1. the TIF's own metadata (an ImageJ/Fiji-calibrated hyperstack's `XResolution` + `finterval`/`unit` fields),
  2. a `.ini` file in the experiment folder (Scientifica/SciScan rigs),
  3. an `Experiment.xml` file in the experiment folder (ThorLabs rigs).
  
  Anything not found is left blank for manual entry in the Parameters panel — leave both blank to get diameter in pixels and time in frames instead of microns/seconds.
- **Perpendicular-line geometry via `atan2`**, so it holds up across vessel orientations (including near-vertical/horizontal segments) without special-casing, plus a fallback that reuses the last valid angle if a skeleton window is degenerate.
- **Live visualisation** during the frame-by-frame scan — geometry sanity-check overlay first (so you can catch a bad skeleton/ROI before the full scan runs), then a filling-in heatmap and trace.
- **Export**: results as a `.mat` file or as one Excel file per branch (frame, time in seconds, average diameter, per-skeleton-point diameters), and a multi-panel summary figure (vessel + skeleton + ROI + perpendicular lines, diameter heatmap, average trace) as PNG/PDF/FIG.

## Requirements

- MATLAB (developed against R2023b/R2024a; needs `readstruct`, so R2020b or later for the `Experiment.xml` auto-detect path — everything else works on older releases).
- Image Processing Toolbox (`bwmorph`, `imfill`, `bwareaopen`, `poly2mask`, `bwboundaries`, `drawpolygon`, `roipoly`, etc.).

## Getting started

```matlab
% from MATLAB, with this repo's folder on your path (or just cd into it):
MAPS
```

`MAPS.m` adds its own `subfunctions/` folder to the path automatically, so no manual setup is needed beyond having MATLAB + Image Processing Toolbox available.

1. **Load Data** → select a vessel TIF (multi-frame, single channel).
2. Set the number of branches, then **Generate skeleton** and **Draw around vessel branch** for each one.
3. Check/enter **Pixel size (microns)** and **Frame rate (Hz)** in the Parameters panel (auto-filled where possible — see above).
4. **GO** to run the analysis.
5. **Export data** / **Export figure** once it completes.

## Current scope / roadmap

The **Analysis** dropdown (`xyDiam` / `zstack` / `linescan`) is scaffolded for future analysis modes, but only **`xyDiam`** is implemented right now — `zstack` and `linescan` are on the roadmap.

## Credits

Developed by [Kira Shaw](mailto:kira.shaw@manchester.ac.uk), University of Manchester. GUI built with [Claude Code](https://claude.com/claude-code) assistance.
