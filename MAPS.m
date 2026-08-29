function MAPS()
% MAPS  Microvascular Analysis & Phenotyping Suite
% Call MAPS in the MATLAB command window to launch the GUI.
% Developed by Kira Shaw.  GUI built with Claude Code assistance.

% ---- add subfunctions to path -----------------------------------------------
mapsDir = fileparts(mfilename('fullpath'));
addpath(fullfile(mapsDir, 'subfunctions'));

% ---- branch colours: pink, blue, green, red, yellow -------------------------
BC = {[0.95 0.45 0.65], [0.30 0.50 0.95], [0.20 0.75 0.35], ...
      [0.90 0.20 0.20], [0.85 0.80 0.10]};

% ---- analysis prefs (not yet exposed in GUI) --------------------------------
prefs.skelLineLength = 8;
prefs.imgThresh      = 0.5;
prefs.clean          = 1;

% =============================================================================
%  SCALE-TO-FIT
% =============================================================================
% Written by Kira Shaw with Claude Code, Aug 2026.
% Everything below is laid out for a 1430 x 860 design canvas. Rather than
% hardcode that (which can run off the edge of a smaller/scaled laptop
% screen), we work out one scale factor from the actual screen size and
% apply it uniformly - via P() for positions and F() for font sizes - so
% the whole GUI shrinks as a single consistent layout instead of clipping.
% On a monitor that comfortably fits the design size, SC = 1 and nothing
% about the layout changes from before.
designW = 1430;  designH = 860;
scrSize = get(0, 'ScreenSize');                  % [left bottom width height]
SC = min([1, (scrSize(3)*0.92)/designW, (scrSize(4)*0.86)/designH]);
SC = max(SC, 0.55);                              % don't shrink past readable

P = @(x,y,w,h) round([x y w h] * SC);            % scale a Position vector
F = @(sz) max(7, round(sz * SC));                % scale a FontSize (floor 7pt)
% uislider's InnerPosition height is hard-fixed at 3 px regardless of what
% you ask for (see matlab.ui.control.Slider's PrivateInnerPosition default)
% - scaling that 3 by SC on anything but a 1:1 screen rounds it away from 3
% and MATLAB warns "The height of this component cannot be changed" on
% every uislider call. Pslider scales x/y/w as usual but always passes the
% unscaled 3 for height, so it matches what the slider forces anyway and
% the warning never fires. (Written by Kira Shaw with Claude Code, Aug 2026)
Pslider = @(x,y,w) [round([x y w] * SC), 3];
% Vertical uislider has the exact same quirk on its OTHER dimension: its
% InnerPosition WIDTH is hard-fixed at 3 px (confirmed empirically - a
% vertical uislider's actual width stays 3 regardless of what's requested,
% same underlying mechanism as Pslider's height fix above), so a vertical
% slider whose Position asks for any other width warns "The width of this
% component cannot be changed" every time - this is what lsWinVertSlider
% was doing on creation and on every switch into linescan mode. PsliderV
% scales x/y/h as usual but always passes the unscaled 3 for width (Written
% by Kira Shaw with Claude Code, Aug 2026).
PsliderV = @(x,y,h) [round(x*SC), round(y*SC), 3, round(h*SC)];

figW = round(designW * SC);
figH = round(designH * SC);
figX = round(scrSize(1) + (scrSize(3) - figW)/2);
figY = round(scrSize(2) + (scrSize(4) - figH)/2);

% =============================================================================
%  FIGURE
% =============================================================================
fig = uifigure( ...
    'Name',     'MAPS', ...
    'Position', [figX figY figW figH], ...
    'Color',    [0.96 0.96 0.97], ...
    'Resize',   'off');

% =============================================================================
%  HEADER  (logo left, title right)
% =============================================================================
logoPath = fullfile(mapsDir, 'images', 'MAPSlogo.png');
if isfile(logoPath)
    uiimage(fig, 'ImageSource', logoPath, 'Position', P(8,788,68,66));
end

uilabel(fig, ...
    'Position',   P(85,818,700,24), ...
    'Text',       'Microvascular Analysis & Phenotyping Suite  (MAPS)', ...
    'FontSize',   F(17), 'FontWeight', 'bold', ...
    'FontColor',  [0.15 0.15 0.15]);
uilabel(fig, ...
    'Position',   P(85,797,600,20), ...
    'Text',       'Vascular analysis from two-photon imaging', ...
    'FontSize',   F(11), 'FontColor', [0.40 0.40 0.40]);

% credit line, moved here from the bottom-right corner (Written by Kira
% Shaw with Claude Code, Aug 2026) - the header has room to spare to the
% right of the title, so it can run bigger here than it could squeezed
% into the bottom strip. Widened (was 200px, x=1222) to fit the longer
% two-author text without clipping - right edge held fixed at 1422 so it
% still hugs the right edge the same way; the title ends well before
% x=922 (its box ends at 785), so there's no risk of the two overlapping.
uilabel(fig, ...
    'Position',            P(922,818,500,24), ...
    'Text',                'K Shaw & C N Hall (2026)', ...
    'FontSize',            F(14), 'FontColor', [0.40 0.40 0.40], ...
    'HorizontalAlignment', 'right');

% Reset button - sits in the same gap the comment above notes (title box
% ends at 785, credit label starts at 922), just to the left of the credit
% line. Confirms before acting since it discards all loaded/analysed data
% (Kira Shaw with Claude Code, Aug 2026).
uibutton(fig, ...
    'Position',        P(795,814,115,32), ...
    'Text',            'Reset', ...
    'FontSize',        F(13), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.75 0.05 0.05], ...
    'FontColor',       [1 1 1], ...
    'ButtonPushedFcn', @(~,~) cb_reset());

% thin separator line below header
uipanel(fig, 'Position', P(0,782,1430,2), 'BackgroundColor', [0.7 0.7 0.75], ...
    'BorderType', 'none');

% =============================================================================
%  LEFT PANEL  (x = 8, width = 415)
% =============================================================================
LX = 8;   LW = 415;

% ---- Setup: analysis type, then Load Data (Written by Kira Shaw with -------
% Claude Code, Aug 2026) ------------------------------------------------------
% Analysis type first, load second - you need to know which mode you're in
% before loading (it decides how the file gets read in), so the order
% matters, not just habit. Boxed as its own section (tinted background +
% border) and both controls enlarged, so this "step 1/step 2" is obvious
% rather than reading as just another row of controls. dispAx below is
% shrunk by the same amount this box needs (45px), so nothing else moves.
pnlSetup = uipanel(fig, ...
    'Position',        P(LX,706,LW,76), ...
    'BackgroundColor', [0.93 0.95 0.98], ...
    'BorderType',      'line', ...
    'HighlightColor',  [0.55 0.65 0.80]);

uilabel(pnlSetup, 'Position', P(10,44,105,26), 'Text', 'Analysis type:', ...
    'FontSize', F(13), 'FontWeight', 'bold', 'FontColor', [0.20 0.20 0.20]);
ddAnalysis = uidropdown(pnlSetup, ...
    'Position', P(120,44,LW-140,26), ...
    'Items',    {'xyDiam', 'linescan', 'zstack'}, ...
    'Value',    'xyDiam', 'FontSize', F(13), ...
    'ValueChangedFcn', @(~,~) cb_analysisChanged());

btnLoad = uibutton(pnlSetup, ...
    'Position',        P(10,6,LW-20,32), ...
    'Text',            'Load Data', ...
    'FontSize',        F(14), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.20 0.45 0.75], ...
    'FontColor',       [1 1 1], ...
    'ButtonPushedFcn', @(~,~) cb_loadData());

% ---- Vessel display axes ----------------------------------------------------
lblDisplayHeader = uilabel(fig, 'Position', P(LX,684,250,18), ...
    'Text', 'Vessel display', ...
    'FontSize', F(10), 'FontColor', [0.35 0.35 0.35]);

% ---- Slant-correct (zstack only - Written by Kira Shaw with Claude Code,
% Aug 2026) ----------------------------------------------------------------
% Two independent ways of correcting the reported tissue volume for a
% stack imaged at a slight angle to the surface, grouped under one
% subheading since they're both answering the same underlying problem:
% "Tissue signal" bins into ~10um z-slabs and tests raw intensity against
% a near-black floor (see computeSlantCorrectedVolume); "Vessel boundary"
% instead uses the actual thresholded vessel mask, per frame (see
% computeBoundaryRestrictedVolume). Both off by default, both change the
% reported numbers when on - see cb_slantOptionChanged for the
% comparability warning either one posts when toggled. Sits directly
% above the z-stack display, on the left with the rest of the processing
% controls (moved here from the right panel originally, then widened to
% fit both options) - dispAx is correspondingly shorter in zstack mode
% (see cb_analysisChanged).
lblSlantHeading = uilabel(fig, 'Position', P(LX,657,95,24), ...
    'Text', 'Slant-correct:', 'FontSize', F(10), 'FontWeight', 'bold', ...
    'FontColor', [0.25 0.25 0.25], 'Visible', 'off');
chkSlantCorrect = uicheckbox(fig, ...
    'Position', P(LX+98,657,160,24), ...
    'Text',     'Tissue signal (10um)', ...
    'Value',    false, 'FontSize', F(10), 'Visible', 'off', ...
    'ValueChangedFcn', @(~,~) cb_slantOptionChanged());
chkBoundaryRestrict = uicheckbox(fig, ...
    'Position', P(LX+262,657,140,24), ...
    'Text',     'Vessel boundary', ...
    'Value',    false, 'FontSize', F(10), 'Visible', 'off', ...
    'ValueChangedFcn', @(~,~) cb_slantOptionChanged());

dispAx = uiaxes(fig, 'Position', P(LX,320,LW,361));
dispAx.XTick = []; dispAx.YTick = [];
dispAx.Box   = 'off';
dispAx.Color = [0.88 0.88 0.90];
% Axes toolbar (pan/zoom/datacursor/home icons) sits right over the linescan
% mode's header labels above this axes - not needed here (navigation is via
% the sliders/buttons), so switch it off rather than let it overlap text
% (Kira Shaw with Claude Code, Aug 2026).
dispAx.Toolbar.Visible = 'off';
dispAx.Title.String = 'Pending vessel display';
dispAx.Title.Color  = [0.45 0.45 0.45];
axis(dispAx, 'equal');

% ---- Z-stack frame slider (zstack only) --------------------------------------
% Written by Kira Shaw with Claude Code, Aug 2026.
% Sits in the strip freed up when dispAx shrinks for zstack mode (see
% cb_analysisChanged). ValueChangingFcn fires live during drag so the
% displayed frame - and its threshold preview - updates as you scrub.
% Written by Kira Shaw with Claude Code, Aug 2026 - strip widened (dispAx's
% zstack bottom raised 346->366, slider/label pushed up to match) after
% the Preprocessing panel below grew tall enough to sit under the
% slider's real footprint (labels included, well beyond its 3px inner
% track - same issue as sldManualThresh, see Pslider above).
zSlider = uislider(fig, ...
    'Position',         Pslider(LX+6,352,LW-70), ...
    'Limits',           [1 2], 'Value', 1, ...
    'Visible',          'off', ...
    'ValueChangingFcn', @(~,ev) cb_zSliderChanging(ev.Value, true), ...
    'ValueChangedFcn',  @(src,~) cb_zSliderChanging(src.Value, false));
lblZFrame = uilabel(fig, ...
    'Position',            P(LX+LW-58,340,58,18), ...
    'Text',                '1 / 1', ...
    'FontSize',            F(9), 'FontColor', [0.35 0.35 0.35], ...
    'HorizontalAlignment', 'right', 'Visible', 'off');

% ---- Processing options section (xyDiam) -------------------------------------
% Boxed to match the zstack side's Preprocessing panel (Written by Kira
% Shaw with Claude Code, Aug 2026) - same native-title/border/tint
% treatment, just for consistency between the two modes.
% Grown downward by 34px (96->130px tall, y 212->178), then a further 36px
% (130->166px tall, y 178->142) to fit the calcium normalisation row below
% (BG ring / r / baseline window - see cb_go) - grown DOWN both times
% since there's only ~12px clear above (to dispAx's bottom edge), but the
% shared Parameters panel below only starts at y=142, leaving genuine free
% space there in xyDiam mode specifically (that gap is normally used by
% Parameters' zstack sibling, pnlPreprocessing, which is hidden here).
% Existing rows shifted up within the taller panel each time so the
% panel's own top edge - and dispAx's clearance from it - stays unchanged
% (Kira Shaw with Claude Code, Aug 2026).
pnlProcOptions = uipanel(fig, ...
    'Position',        P(LX,142,LW,166), ...
    'Title',           'Preprocessing', ...
    'FontWeight',      'bold', ...
    'BackgroundColor', [0.97 0.97 0.98]);

btnSkel = uibutton(pnlProcOptions, ...
    'Position',        P(LX,114,172,28), ...
    'Text',            'Generate skeleton', ...
    'FontSize',        F(11), ...
    'ButtonPushedFcn', @(~,~) cb_generateSkeleton());

lblSkelTick = uilabel(pnlProcOptions, 'Position', P(188,112,30,30), ...
    'Text', '', 'FontSize', F(20), 'FontColor', [0.10 0.70 0.20]);

btnBranch = uibutton(pnlProcOptions, ...
    'Position',        P(LX,78,210,28), ...
    'Text',            'Draw around vessel branch', ...
    'FontSize',        F(11), ...
    'ButtonPushedFcn', @(~,~) cb_drawBranch());

lblBranchTick = uilabel(pnlProcOptions, 'Position', P(226,76,30,30), ...
    'Text', '', 'FontSize', F(20), 'FontColor', [0.10 0.70 0.20]);

% Perivascular calcium (optional second channel/TIF) - ticking prompts for
% a second TIF file to associate with this recording (Kira Shaw with
% Claude Code, Aug 2026).
chkPerivascularCa = uicheckbox(pnlProcOptions, ...
    'Position',        P(LX,44,220,22), ...
    'Text',            'Perivascular Calcium', ...
    'Value',           false, 'FontSize', F(11), ...
    'ValueChangedFcn', @(src,~) cb_perivascularCaChanged(src));

% Calcium-line lengths, in MICRONS (Written by Kira Shaw with Claude Code,
% Aug 2026) - how far the perivascular sampling band extends either side of
% each FWHM-detected vessel edge. Originally entered in pixels (10/20,
% matching prefs.insidePx/outsidePx in FWHM_diam_perivascCa_adapted.m), but
% a fixed pixel width means a different physical distance at every zoom, so
% at high magnification the background ring could sit on top of labelled
% perivascular processes. These fields are now in microns and converted to
% pixels in cb_go using the (auto-detected) pixel size; the defaults 3.5 /
% 7 um reproduce the old 10 / 20 px behaviour at ~0.35 um/px. Always
% editable, not just once ticked.
lblCaIn = uilabel(pnlProcOptions, 'Position', P(232,45,42,20), ...
    'Text', 'In (um):', 'FontSize', F(9), 'FontColor', [0.25 0.25 0.25]);
efCaInsidePx = uieditfield(pnlProcOptions, 'numeric', ...
    'Position', P(274,43,32,22), ...
    'Value',    3.5, 'Limits', [0 Inf], 'FontSize', F(9));
lblCaOut = uilabel(pnlProcOptions, 'Position', P(310,45,48,20), ...
    'Text', 'Out (um):', 'FontSize', F(9), 'FontColor', [0.25 0.25 0.25]);
efCaOutsidePx = uieditfield(pnlProcOptions, 'numeric', ...
    'Position', P(358,43,32,22), ...
    'Value',    7, 'Limits', [0 Inf], 'FontSize', F(9));

% Calcium normalisation row (Written by Kira Shaw with Claude Code, Aug
% 2026) - Suite2p-style dF/F0: a further-out background ring (sampled the
% same way as In/Out above, but starting just beyond the Out ring, after a
% 1 um guard gap) is subtracted with coefficient r (Suite2p's own default
% neuropil coefficient, neucoeff = 0.7), then a sliding maximin filter over
% the baseline window gives F0 for dF/F0 = (F-F0)/F0. BG ring width is in
% MICRONS (converted to px in cb_go); default 5 um ~= the old 15 px at
% ~0.35 um/px. See cb_go for the computation and the README for references.
lblCaBg = uilabel(pnlProcOptions, 'Position', P(LX,9,74,20), ...
    'Text', 'BG ring (um):', 'FontSize', F(9), 'FontColor', [0.25 0.25 0.25]);
efCaBgRingPx = uieditfield(pnlProcOptions, 'numeric', ...
    'Position', P(84,7,30,22), ...
    'Value',    5, 'Limits', [0 Inf], 'FontSize', F(9));
lblCaBgCoeff = uilabel(pnlProcOptions, 'Position', P(120,9,16,20), ...
    'Text', 'r:', 'FontSize', F(9), 'FontColor', [0.25 0.25 0.25]);
efCaBgCoeff = uieditfield(pnlProcOptions, 'numeric', ...
    'Position', P(136,7,32,22), ...
    'Value',    0.7, 'Limits', [0 Inf], 'FontSize', F(9));
lblCaBaseline = uilabel(pnlProcOptions, 'Position', P(174,9,66,20), ...
    'Text', 'Baseline (s):', 'FontSize', F(9), 'FontColor', [0.25 0.25 0.25]);
efCaBaselineSec = uieditfield(pnlProcOptions, 'numeric', ...
    'Position', P(240,7,36,22), ...
    'Value',    60, 'Limits', [1 Inf], 'FontSize', F(9));

% group of xyDiam-only left-panel controls, shown/hidden as one by the
% Analysis dropdown (see cb_analysisChanged)
xyDiamLeftH = [pnlProcOptions, btnSkel, lblSkelTick, btnBranch, lblBranchTick, ...
    chkPerivascularCa, lblCaIn, efCaInsidePx, lblCaOut, efCaOutsidePx, ...
    lblCaBg, efCaBgRingPx, lblCaBgCoeff, efCaBgCoeff, lblCaBaseline, efCaBaselineSec];

% ---- Preprocessing panel (zstack) ------------------------------------------
% Written by Kira Shaw with Claude Code, Aug 2026.
% Everything that shapes the binary mask before skeletonising lives here
% together: threshold (auto/manual, per-range), smoothing, and skeleton
% pruning - now its own boxed section (native panel title + border,
% matching Parameters below and Setup above) rather than a bare label +
% loose controls. Auto threshold (Otsu for now - more methods can be added
% to ddThreshMethod's Items later without changing this layout) sets the
% whole-stack default. Manual threshold reveals a slider that nudges the
% *active* segment's value (the one covering whatever frame is currently
% shown). Start/End range lets you carve out a sub-range of frames (e.g.
% deeper slices needing a different value) and give it its own threshold,
% on top of the whole-stack default.
%
% The manual-threshold slider used to sit only 6px above the smoothing row
% below it - fine for its 3px *inner* track, but a uislider's actual
% rendered footprint (value labels included) is much taller than that
% (~39px, per its own default OuterPosition), so the smoothing row was
% genuinely being rendered over by the slider's label area. Every row
% below the slider now sits further down to give it real clearance.
% Reorganised again (Written by Kira Shaw with Claude Code, Aug 2026):
% Smooth moved up to sit with Auto/Manual threshold (it shapes the raw
% vessel data, same as thresholding does); Skeleton preview + Prune length
% now form their own row at the bottom, next to the Start/End range
% buttons - ticking Skeleton preview overlays a quick 2D skeleton on the
% current thresholded frame (see renderZFrame), so nudging Prune length
% shows its effect immediately without running the full 3D "Process
% Stack". Panel grown a little (top nudged up from y=300 to y=308, and
% Parameters below tightened a touch more) to fit the extra row.
pnlPreprocessing = uipanel(fig, ...
    'Position',        P(LX,136,LW,187), ...
    'Title',           'Preprocessing', ...
    'FontWeight',      'bold', ...
    'BackgroundColor', [0.97 0.97 0.98], ...
    'Visible',         'off');

% One consistent font size across every control in this panel (Written by
% Kira Shaw with Claude Code, Aug 2026) - some had an explicit smaller
% size and some were left at the (larger) default, which read as
% inconsistent side by side. PPFS = "Preprocessing panel font size".
PPFS = F(11);

% Auto threshold first, Smooth right below it (swapped - Written by Kira
% Shaw with Claude Code, Aug 2026) - both shape the raw vessel data before
% skeletonising, grouped together.
chkAutoThresh = uicheckbox(pnlPreprocessing, ...
    'Position',        P(LX,139,150,22), ...
    'Text',            'Auto threshold', ...
    'Value',           false, 'FontSize', PPFS, ...
    'ValueChangedFcn', @(~,~) cb_autoThreshChanged());
ddThreshMethod = uidropdown(pnlPreprocessing, ...
    'Position',        P(190,139,150,22), ...
    'Items',           {'Otsu (recommended)', 'IsoData', 'Triangle'}, ...
    'Value',           'Otsu (recommended)', 'FontSize', PPFS, ...
    'Enable',          'off', ...
    'ValueChangedFcn', @(~,~) cb_methodChanged());

chkSmooth = uicheckbox(pnlPreprocessing, ...
    'Position',        P(LX,114,80,22), ...
    'Text',            'Smooth', ...
    'Value',           false, 'FontSize', PPFS, ...
    'ValueChangedFcn', @(~,~) cb_smoothChanged());
lblSmoothSigma = uilabel(pnlPreprocessing, 'Position', P(LX+84,114,14,22), ...
    'Text', char(963), 'FontSize', PPFS, 'FontColor', [0.25 0.25 0.25]);  % sigma
efSmoothSigma = uieditfield(pnlPreprocessing, 'numeric', ...
    'Position',        P(LX+100,114,42,22), ...
    'Value',           1, 'Limits', [0.1 10], 'FontSize', PPFS, ...
    'ValueChangedFcn', @(~,~) cb_smoothChanged());

% manual threshold checkbox + its slider share one row (checkbox top-
% aligned, slider's true footprint given room below it - a uislider's
% rendered footprint, labels included, is far taller than its 3px inner
% track - see Pslider above). Shifted up 15px from where it first landed
% (Written by Kira Shaw with Claude Code, Aug 2026) - screenshotted proof
% that clearance still wasn't enough: the slider's tick labels were
% crowding into Start/End range below it. Panel had spare, unused height
% at the bottom (below Skeleton preview) that's now used here instead -
% kept to +15 (not more) to leave a margin below the z-frame slider above
% this panel, which had the same kind of clearance issue fixed earlier.
chkManualThresh = uicheckbox(pnlPreprocessing, ...
    'Position',        P(LX,89,145,22), ...
    'Text',            'Manual threshold', ...
    'Value',           false, 'FontSize', PPFS, 'Enable', 'off', ...
    'ValueChangedFcn', @(~,~) cb_manualThreshChanged());
sldManualThresh = uislider(pnlPreprocessing, ...
    'Position',         Pslider(165,95,LW-181), ...
    'Limits',           [0 1], 'Value', 0, ...
    'Enable',           'off', ...
    'ValueChangingFcn', @(~,ev)  cb_manualSliderChanging(ev.Value, true), ...
    'ValueChangedFcn',  @(src,~) cb_manualSliderChanging(src.Value, false));

% Start/End range apply to whichever threshold mode (auto/manual) is
% current, so they sit with the threshold controls, not down with
% skeleton preview (Written by Kira Shaw with Claude Code, Aug 2026).
btnRangeStart = uibutton(pnlPreprocessing, ...
    'Position',        P(LX,31,172,26), ...
    'Text',            'Start range', ...
    'FontSize',        PPFS, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_rangeStart());
btnRangeEnd = uibutton(pnlPreprocessing, ...
    'Position',        P(196,31,172,26), ...
    'Text',            'End range && apply', ...
    'FontSize',        PPFS, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_rangeEnd());

% ---- Skeleton preview (Written by Kira Shaw with Claude Code, Aug 2026) ---
% Quick 2D skeleton of the current thresholded frame, overlaid live on the
% preview above - lets pruning be tuned by eye rather than by trial and
% error against the full 3D "Process Stack" run (see renderZFrame).
chkSkelPreview = uicheckbox(pnlPreprocessing, ...
    'Position',        P(LX,2,120,22), ...
    'Text',            'Skeleton preview', ...
    'Value',           false, 'FontSize', PPFS, ...
    'ValueChangedFcn', @(~,~) cb_skelPreviewChanged());
lblPruneLen = uilabel(pnlPreprocessing, 'Position', P(LX+124,2,75,22), ...
    'Text', 'Prune (vox):', 'FontSize', PPFS, 'FontColor', [0.25 0.25 0.25]);
efPruneLen = uieditfield(pnlPreprocessing, 'numeric', ...
    'Position',        P(LX+202,2,45,22), ...
    'Value',           10, 'Limits', [0 Inf], 'FontSize', PPFS, ...
    'ValueChangedFcn', @(~,~) cb_prunePreviewChanged());

zstackLeftH = [pnlPreprocessing, chkAutoThresh, ddThreshMethod, chkManualThresh, ...
    sldManualThresh, chkSmooth, lblSmoothSigma, efSmoothSigma, chkSkelPreview, ...
    lblPruneLen, efPruneLen, btnRangeStart, btnRangeEnd, ...
    lblSlantHeading, chkSlantCorrect, chkBoundaryRestrict];

% =============================================================================
%  LINESCAN LEFT-PANEL CONTROLS  (all Visible off; shown by cb_analysisChanged)
% =============================================================================

% NOTE: the old static "crop RBCV.tif before loading" warning label has
% been replaced by an interactive width-crop step in the Preprocessing
% panel below (btnLsCrop) - see "Row 3: Crop" (Kira Shaw with Claude
% Code, Aug 2026).

% Frame slider + counter (sits in the gap between dispAx and lsWinAx)
lblLsFrameHdr = uilabel(fig, ...
    'Position',  P(LX,417,70,14), ...
    'Text', 'Frame:', 'FontSize', F(9), ...
    'FontColor', [0.35 0.35 0.35], 'Visible', 'off');
lblLsFrame = uilabel(fig, ...
    'Position',            P(LX+72,417,90,14), ...
    'Text',                '1 / 1', ...
    'FontSize',            F(9), 'FontColor', [0.35 0.35 0.35], ...
    'HorizontalAlignment', 'left', 'Visible', 'off');
lsFrameSlider = uislider(fig, ...
    'Position',         Pslider(LX+170,420,LW-175), ...
    'Limits',           [1 2], 'Value', 1, 'Visible', 'off', ...
    'ValueChangingFcn', @(~,ev) cb_lsFrameSlider(ev.Value, true), ...
    'ValueChangedFcn',  @(src,~) cb_lsFrameSlider(src.Value, false));

% Sliding-window display — shows the current 40ms (or user-set) window
% (y 258->272: see lsWinAx above - reclaims clearance from the Preprocessing
% panel below, which had shrunk to ~4px)
lblLsWinHdr = uilabel(fig, ...
    'Position',  P(LX,272,150,14), ...
    'Text', 'Sliding window:', 'FontSize', F(9), ...
    'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25], 'Visible', 'off');
lblLsWin = uilabel(fig, ...
    'Position',            P(LX+155,272,120,14), ...
    'Text',                'Win 1 / 1', ...
    'FontSize',            F(9), 'FontColor', [0.45 0.45 0.45], ...
    'HorizontalAlignment', 'left', 'Visible', 'off');
% Shifted up (y 275->289) and shortened (h 130->110) to open a proper gap
% below the "Sliding window" header labels and the Preprocessing panel's
% top edge, which had shrunk to ~4px when that panel grew a 4th row -
% (Kira Shaw with Claude Code, Aug 2026).
lsWinAx = uiaxes(fig, 'Position', P(LX,289,LW,110), 'Visible', 'off');
lsWinAx.XTick = []; lsWinAx.YTick = [];
lsWinAx.Color  = [0.10 0.10 0.10];
lsWinAx.Toolbar.Visible = 'off';   % see dispAx above
lsWinAx.Title.String = 'Sliding window (80 ms)';
lsWinAx.Title.FontSize = F(9);
xlabel(lsWinAx, 'Time (scan lines)');  ylabel(lsWinAx, 'Space');
lsWinSlider = uislider(fig, ...
    'Position',         Pslider(LX,262,LW-5), ...
    'Limits',           [1 2], 'Value', 1, 'Visible', 'off', ...
    'ValueChangingFcn', @(~,ev) cb_lsWinSlider(ev.Value, true), ...
    'ValueChangedFcn',  @(src,~) cb_lsWinSlider(src.Value, false));

% Vertical per-frame window slider — sits to the left of the raw/binary panels
% in linescan mode; positioned by cb_analysisChanged. Slider top = window at
% top of frame; slider bottom = window at bottom of frame (value is inverted).
% Labelled "Window" (lblLsWinVertHdr, positioned by cb_analysisChanged) - it
% had no label of its own before, sitting right beside the unrelated "Frame:"
% text for the frame slider below, which read as if IT were labelled "frame"
% (Written by Kira Shaw with Claude Code, Aug 2026).
lblLsWinVertHdr = uilabel(fig, ...
    'Position',  P(LX,676,60,12), ...
    'Text', 'Window', 'FontSize', F(8), ...
    'FontColor', [0.35 0.35 0.35], 'Visible', 'off');
% Live readout of the current line-within-frame value the slider points at
% (1 at top, maxLr at bottom - matches the slider's own top=1/bottom=max
% layout) - kept updated alongside the slider in renderLsFrame (Kira Shaw
% with Claude Code, Aug 2026).
lblLsWinVertVal = uilabel(fig, ...
    'Position',  P(LX,662,60,12), ...
    'Text', '', 'FontSize', F(8), ...
    'FontColor', [0.35 0.35 0.35], 'Visible', 'off');
lsWinVertSlider = uislider(fig, ...
    'Orientation',      'vertical', ...
    'Position',         PsliderV(LX, 435, 240), ...
    'Limits',           [1 2], 'Value', 2, 'Visible', 'off', ...
    'MajorTicks',       [], 'MinorTicks', [], ...
    'ValueChangingFcn', @(~,ev) cb_lsWinVertSlider(ev.Value, true), ...
    'ValueChangedFcn',  @(src,~) cb_lsWinVertSlider(src.Value, false));

% Processing options panel (linescan)
% Grown to 4 rows (was 3/92px tall) to fit the new Crop row - order is
% Crop, Binarise, Check line angle, Detect RBCs: Crop first since it's
% optional but (if used) invalidates everything below it; Binarise next
% since RBC detection depends on it (Written by Kira Shaw with Claude
% Code, Aug 2026).
% Moved up (y 136->152) and grown (h 118->122) - was only 4px clear of the
% Parameters panel below it, visually reading as overlapping; there was
% 35px of slack above (to lsWinAx) to take this from, so both edges are
% now comfortably clear (~20px below, ~15px above) - Kira Shaw with Claude
% Code, Aug 2026.
pnlLsProc = uipanel(fig, ...
    'Position',        P(LX,152,LW,122), ...
    'Title',           'Preprocessing', ...
    'FontWeight',      'bold', ...
    'BackgroundColor', [0.97 0.97 0.98], ...
    'Visible',         'off');

LSFS = F(11);

% Row 1: Crop (width-only, optional) - first/topmost since it's the one
% step that (if used) invalidates everything below it; replaces the old
% static warning label about pre-cropping RBCV.tif before loading. Draw a
% line across the width on the raw display (dispAx), double-click to
% confirm; click again to redraw before confirming, or to reset+redraw
% after applying (Kira Shaw with Claude Code, Aug 2026).
% Rows nudged down 8px from the panel top (88/62/36 -> 80/56/32) to give
% the panel's own title bar ("Processing options") proper clearance - the
% previous 8px gap wasn't enough and "Crop"/"Not cropped" were overlapping
% the title text (Kira Shaw with Claude Code, Aug 2026).
btnLsCrop = uibutton(pnlLsProc, ...
    'Position',        P(8,80,90,22), ...
    'Text',            'Crop (width)', ...
    'FontSize',        LSFS, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_lsCropToggle());
lblLsCropStatus = uilabel(pnlLsProc, 'Position', P(105,80,LW-120,22), ...
    'Text', 'Not cropped', 'FontSize', LSFS, 'FontColor', [0.45 0.45 0.45]);

% Row 2: Binarise button + threshold slider
btnLsBinarise = uibutton(pnlLsProc, ...
    'Position',        P(8,56,90,22), ...
    'Text',            'Binarise', ...
    'FontSize',        LSFS, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_lsBinarise());
lblLsThresh = uilabel(pnlLsProc, 'Position', P(105,56,55,22), ...
    'Text', 'Thresh:', 'FontSize', LSFS, 'FontColor', [0.45 0.45 0.45]);
sldLsThresh = uislider(pnlLsProc, ...
    'Position',         Pslider(162,62,LW-178), ...
    'Limits',           [0 1], 'Value', 0.5, 'Enable', 'off', ...
    'ValueChangingFcn', @(~,ev) cb_lsThreshSlider(ev.Value, true), ...
    'ValueChangedFcn',  @(src,~) cb_lsThreshSlider(src.Value, false));

% Row 3: Check line angle button + result label
btnLsCheckAngle = uibutton(pnlLsProc, ...
    'Position',        P(8,32,140,22), ...
    'Text',            'Check line angle', ...
    'FontSize',        LSFS, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_lsCheckAngle());
lblLsAngleResult = uilabel(pnlLsProc, 'Position', P(155,32,LW-170,22), ...
    'Text', '', 'FontSize', LSFS, 'FontColor', [0.20 0.20 0.20]);

% Row 4: Detect individual RBCs - now a button styled like the rest of
% this panel (was a checkbox), so a status label carries the on/off state
% (Kira Shaw with Claude Code, Aug 2026).
btnLsRBC = uibutton(pnlLsProc, ...
    'Position',        P(8,8,140,22), ...
    'Text',            'Detect individual RBCs', ...
    'FontSize',        LSFS, 'Enable', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_lsRBCToggle());
lblLsRBCStatus = uilabel(pnlLsProc, 'Position', P(155,8,LW-170,22), ...
    'Text', 'Off', 'FontSize', LSFS, 'FontColor', [0.45 0.45 0.45]);

% NOTE: lblLsWinSzParam and efLsWinSz are created in the Parameters panel
% below, so linescanLeftH is completed there (search "linescanLeftH =").
% lsWinSlider (paged window-stepping) deliberately left out here and kept
% permanently hidden: redundant now that the frame slider + lsWinVertSlider
% ("Window") together reach any window directly, and freeing its row gives
% the sliding-window preview a bit more breathing room (Written by Kira
% Shaw with Claude Code, Aug 2026).
linescanLeftH_part1 = [lblLsFrameHdr, lblLsFrame, lsFrameSlider, ...
    lblLsWinHdr, lblLsWin, lsWinAx, lblLsWinVertHdr, lblLsWinVertVal, lsWinVertSlider, ...
    pnlLsProc, btnLsCheckAngle, lblLsAngleResult, btnLsBinarise, ...
    lblLsThresh, sldLsThresh, btnLsCrop, lblLsCropStatus, ...
    btnLsRBC, lblLsRBCStatus];

% ---- Parameters panel -------------------------------------------------------
% Grown back to 90px tall (was 80px) - linescan's row 2 (Pixel size +
% the scan-velocity-correction checkbox crammed beside it) was overlapping
% below/wrapping, since that checkbox's text didn't actually fit its old
% width. There was 20px of slack freed up above (pnlLsProc having since
% moved up) to take the extra 10px from, keeping a 10px gap to pnlLsProc's
% own bottom edge (Kira Shaw with Claude Code, Aug 2026).
pnl = uipanel(fig, ...
    'Position',        P(LX,52,LW,90), ...
    'Title',           'Parameters', ...
    'FontWeight',      'bold', ...
    'BackgroundColor', [1 1 1]);

% row 1 is mode-dependent: xyDiam wants no. of branches, zstack wants
% z-step (which xyDiam has no use for) - same slot, toggled visibility
lblNBranch = uilabel(pnl, 'Position', P(10,48,110,18), ...
    'Text', 'No. of branches:', 'FontSize', F(10));
efNBranch = uieditfield(pnl, 'numeric', ...
    'Position', P(122,48,45,18), 'Value', 1, 'Limits', [1 5], 'FontSize', F(10));

lblZstep = uilabel(pnl, 'Position', P(10,48,110,18), ...
    'Text', 'Z-step (microns):', 'FontSize', F(10), 'Visible', 'off');
efZstep = uieditfield(pnl, 'text', ...
    'Position', P(122,48,80,18), 'Value', '', 'FontSize', F(10), ...
    'Placeholder', 'blank = n/a', 'Visible', 'off');

% Linescan: lines per second (auto-computed, read-only display)
lblLps = uilabel(pnl, 'Position', P(10,48,110,18), ...
    'Text', 'Lines per second:', 'FontSize', F(10), 'Visible', 'off');
efLps = uieditfield(pnl, 'text', ...
    'Position', P(122,48,80,18), 'Value', '', 'FontSize', F(10), ...
    'Editable', false, 'Visible', 'off');

% Linescan: window size — right side of same row as Lines per second
lblLsWinSzParam = uilabel(pnl, 'Position', P(212,48,72,18), ...
    'Text', 'Window (ms):', 'FontSize', F(10), 'Visible', 'off');
efLsWinSz = uieditfield(pnl, 'numeric', ...
    'Position',        P(286,48,58,18), ...
    'Value',           40, 'Limits', [4 10000], 'FontSize', F(10), ...
    'Visible',         'off', ...
    'ValueChangedFcn', @(~,~) cb_lsWinSzChanged());

uilabel(pnl, 'Position', P(10,26,110,18), ...
    'Text', 'Pixel size (microns):', 'FontSize', F(10));
efPxsz = uieditfield(pnl, 'text', ...
    'Position', P(122,26,80,18), 'Value', '', 'FontSize', F(10), ...
    'Placeholder', 'blank = pixels');

% Linescan: scan-velocity (Vscan) correction, named for the equation it
% applies rather than an author - see README for the full derivation and
% references. OFF by default ("parked"), opt-in: its physical validity for
% this acquisition hasn't been independently confirmed (unlike the
% underlying apparent-velocity formula itself, which now has been - see
% cb_lsGo), and it can NaN out most of the trace when the true velocity
% approaches Vscan, so it's an explicit choice rather than always-on
% (variable name kept as chkLsCharpak internally for continuity with
% earlier discussion of this feature - Kira Shaw with Claude Code, Aug 2026).
% Text shortened to fit its 193px-wide slot at F(9) without wrapping - the
% full description ("Apply scan-velocity correction (Vscan)...") was
% wrapping to multiple lines and running into the row below; kept as the
% Tooltip instead (Kira Shaw with Claude Code, Aug 2026).
chkLsCharpak = uicheckbox(pnl, ...
    'Position', P(212,26,LW-222,18), ...
    'Text',     'Vscan correction', ...
    'Value',    false, 'FontSize', F(9), 'Visible', 'off', ...
    'Tooltip',  ['Apply scan-velocity correction (Vscan): corrects apparent ' ...
        'velocity for the finite line-scan sweep rate - see README. Can ' ...
        'wipe out most of the trace if unstable for this Vscan (see ' ...
        'Processing updates)']);

uilabel(pnl, 'Position', P(10,4,110,18), ...
    'Text', 'Frame rate (Hz):', 'FontSize', F(10));
efFPS = uieditfield(pnl, 'text', ...
    'Position', P(122,4,80,18), 'Value', '', 'FontSize', F(10), ...
    'Placeholder', 'blank = frames');

% Complete linescanLeftH now that lblLsWinSzParam and efLsWinSz exist
linescanLeftH = [linescanLeftH_part1, lblLsWinSzParam, efLsWinSz, chkLsCharpak];

% ---- GO button (xyDiam) ------------------------------------------------------
btnGo = uibutton(fig, ...
    'Position',        P(LX,14,LW,33), ...
    'Text',            'GO', ...
    'FontSize',        F(15), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.12 0.55 0.20], ...
    'FontColor',       [1 1 1], ...
    'ButtonPushedFcn', @(~,~) cb_go());

% ---- zstack equivalent of GO --------------------------------------------------
% Written by Kira Shaw with Claude Code, Aug 2026.
btnZAnalyze = uibutton(fig, ...
    'Position',        P(LX,14,LW,33), ...
    'Text',            'Process Stack', ...
    'FontSize',        F(15), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.12 0.55 0.20], ...
    'FontColor',       [1 1 1], ...
    'Enable',          'off', 'Visible', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_zAnalyze());

% ---- linescan equivalent of GO ------------------------------------------------
btnLsGo = uibutton(fig, ...
    'Position',        P(LX,14,LW,33), ...
    'Text',            'Run Linescan Analysis', ...
    'FontSize',        F(14), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.55 0.15 0.55], ...
    'FontColor',       [1 1 1], ...
    'Enable',          'off', 'Visible', 'off', ...
    'ButtonPushedFcn', @(~,~) cb_lsGo());

% =============================================================================
%  RIGHT PANEL  (x = 435, width = 985)
% =============================================================================
RX = 435;  RW = 985;

% ---- Processing updates -----------------------------------------------------
uilabel(fig, 'Position', P(RX,762,200,18), ...
    'Text', 'Processing updates', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25]);
txaUpdates = uitextarea(fig, ...
    'Position', P(RX,730,RW,30), ...
    'Editable', false, ...
    'Value',    'Load data to begin.', ...
    'FontSize', F(11));
% uitextarea cannot render coloured/bold text, so validation errors (e.g.
% window size not divisible by 4) show in this overlay label instead -
% same position/size as txaUpdates, hidden except while an error is
% active. postUpdate() hides it again on the next normal message
% (Kira Shaw with Claude Code, Aug 2026).
lblUpdatesError = uilabel(fig, ...
    'Position',        P(RX,730,RW,30), ...
    'Text',            '', ...
    'FontSize',         F(11), 'FontWeight', 'bold', ...
    'FontColor',        [0.75 0.05 0.05], ...
    'BackgroundColor',  [1 1 1], ...
    'Visible',          'off');

% ---- Diameter heatmap axes (xyDiam) -------------------------------------------
% Built at their original (pre-calcium-feature) full size; only shrunk to
% make room for the calcium trace plot (caAx) when Perivascular Calcium is
% actually ticked - see applyCaLayout() - so the calcium feature costs no
% screen real estate at all until it's switched on (Written by Kira Shaw
% with Claude Code, Aug 2026).
lblHeatmap = uilabel(fig, 'Position', P(RX,708,350,18), ...
    'Text', 'Diameter map', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25]);
heatAx = uiaxes(fig, 'Position', P(RX,415,RW,290));
heatAx.Color   = [0.97 0.97 0.97];
heatAx.XColor  = [0.30 0.30 0.30];
heatAx.YColor  = [0.30 0.30 0.30];
colormap(heatAx, 'parula');
xlabel(heatAx, 'Frame');  ylabel(heatAx, 'Skeleton pt');

% ---- Average diameter trace axes (xyDiam) -------------------------------------
% Default y-axis label set here (not just inside cb_go) so it's not blank/
% unaligned with the other plots before Run has ever been pressed - cb_go
% still overwrites it with the correct unit (microns/pixels) once pixel
% size is known (Kira Shaw with Claude Code, Aug 2026).
lblTrace = uilabel(fig, 'Position', P(RX,393,350,18), ...
    'Text', 'Average diameter  (mean across skeleton pts)', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25]);
traceAx = uiaxes(fig, 'Position', P(RX,55,RW,335));
traceAx.Color  = [0.97 0.97 0.97];
traceAx.XColor = [0.30 0.30 0.30];
traceAx.YColor = [0.30 0.30 0.30];
xlabel(traceAx, 'Frame');  ylabel(traceAx, 'Diameter (microns)');
hold(traceAx, 'on');

% ---- Perivascular calcium trace axes (xyDiam) ----------------------------------
% Written by Kira Shaw with Claude Code, Aug 2026. Branch-by-branch, colour
% -coded the same way as traceAx above - only populated with real data when
% Perivascular Calcium is ticked and run (see cb_go). Hidden by default
% (Visible off, and deliberately left OUT of xyDiamRightH below) so it
% takes no space in the live view unless the box is actually ticked - see
% applyCaLayout(), called from cb_perivascularCaChanged and
% cb_analysisChanged, which is what shows/positions it and shrinks
% heatAx/traceAx to make room.
lblCaTrace = uilabel(fig, 'Position', P(RX,254,350,18), ...
    'Text', 'Perivascular calcium  (mean across skeleton pts)', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25], ...
    'Visible', 'off');
caAx = uiaxes(fig, 'Position', P(RX,55,RW,197), 'Visible', 'off');
caAx.Color  = [0.97 0.97 0.97];
caAx.XColor = [0.30 0.30 0.30];
caAx.YColor = [0.30 0.30 0.30];
title(caAx, 'Perivascular Calcium (not enabled)');
hold(caAx, 'on');

% group of xyDiam-only right-panel content, shown/hidden as one - lblCaTrace/
% caAx deliberately excluded (see comment above); their visibility is
% managed separately by applyCaLayout()
xyDiamRightH = [lblHeatmap, heatAx, lblTrace, traceAx];

% ---- Threshold segments table (zstack) ---------------------------------------
% Written by Kira Shaw with Claude Code, Aug 2026.
% One row per frame-range: the whole-stack default plus any per-range
% overrides added via Start/End range on the left. Shrunk to leave room
% below for the density results grid (added when "Calculate Vascular
% Density" is built out - see cb_zAnalyze).
lblSegments = uilabel(fig, 'Position', P(RX,708,450,18), ...
    'Text', 'Threshold segments  (per frame-range overrides)', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25], ...
    'Visible', 'off');

% (Correct volume for tissue slant used to sit here - moved to the left
% panel, next to the z-stack display, in Aug 2026 - it's a processing
% control like everything else on that side, not a results-panel item)
% shrunk from 125 to 95 to 85px tall (Written by Kira Shaw with Claude
% Code, Aug 2026) to give the density box below room, most recently for
% its 4th line (a labelled title row, "Full tissue:"/"Boundary
% restricted:", on top of density/tortuosity/volume/distance) - its top
% edge (y=705) is unchanged from before, only its bottom edge moved up.
tblSegments = uitable(fig, ...
    'Position',   P(RX,620,RW,85), ...
    'ColumnName', {'Start frame', 'End frame', 'Mode', 'Threshold value'}, ...
    'Data',       cell(0,4), ...
    'Visible',    'off');

% (smoothing/pruning controls used to sit here - moved to the left panel's
% Preprocessing block, alongside threshold, in Aug 2026)

% ---- Density results (zstack) -------------------------------------------------
% Written by Kira Shaw with Claude Code, Aug 2026.
% Density is only meaningful alongside the tissue volume it was measured
% over (a 50-slice and a 100-slice stack aren't comparable otherwise), so
% both are always shown together here, plus the tissue-to-vessel distance
% percentiles - all in a highlighted box (cf. Nature Comms 2021
% 10.1038/s41467-021-23508-y, fig 7) so the headline numbers stand out
% from the plots around them, rather than reading as just another label.
% Grown from 88 to 100px tall (Written by Kira Shaw with Claude Code, Aug
% 2026) to fit a 4th text line (see RESULTS_FS below) - its bottom edge
% (y=516) is unchanged, tblSegments above gave up the matching 12px.
pnlDensity = uipanel(fig, ...
    'Position',        P(RX,516,RW,100), ...
    'BackgroundColor', [0.87 0.95 0.83], ...
    'BorderType',      'line', ...
    'HighlightColor',  [0.55 0.75 0.50], ...
    'Visible',         'off');
% Written by Kira Shaw with Claude Code, Aug 2026. Both labels share one
% font size (RESULTS_FS) - previously the primary text was F(16) against
% the boundary text's F(12); both boxes also now follow the exact same
% 4-line structure (title / density+tortuosity / volume / distance) so
% the two sides read as one standardised results box rather than two
% differently-formatted ones. F(13), a bit bigger than the old shared
% F(12), fits the panel's new extra height.
RESULTS_FS = F(13);
lblDensity = uilabel(pnlDensity, ...
    'Position',  P(10,4,580,92), ...
    'Text',      {'Full tissue:', 'run "Process Stack" first'}, ...
    'FontSize',  RESULTS_FS, 'FontWeight', 'bold', 'FontColor', [0.10 0.35 0.10], ...
    'BackgroundColor', [0.87 0.95 0.83]);
% Boundary-restricted results (2nd density measure - see
% computeBoundaryRestrictedVolume), on the RHS of the same box, in a
% distinct yellow colour rather than a separate box, since there's room
% here and it's a companion set of numbers, not an unrelated one (Written
% by Kira Shaw with Claude Code, Aug 2026). Same yellow ([0.80 0.65 0.0],
% "BOUNDARY_YELLOW") is reused for the boundary overlay line drawn on the
% stack display and in the export figure, so the results box colour and
% the outline it corresponds to visually match.
% Shifted left and widened (was x=600, width=375; then x=575 - still not
% enough) - Written by Kira Shaw with Claude Code, Aug 2026. The longest
% line (the distance-percentile one) was being clipped mid-number
% ("...95th pct 98...") because the label itself was too narrow for it,
% not just positioned badly - moving the box alone without widening it
% just shifts where the same clipping happens. x=545/width=435 (right
% edge 980, still inside the panel's own 985 width) gives it noticeably
% more room; checked against lblDensity's actual rendered text (which
% only reaches partway across its own 580px box, per screenshot) so this
% doesn't visually collide with it despite the two boxes' declared
% bounds now overlapping on paper.
lblDensityBoundary = uilabel(pnlDensity, ...
    'Position',  P(545,4,435,92), ...
    'Text',      {'Boundary restricted:', ''}, ...
    'FontSize',  RESULTS_FS, 'FontWeight', 'bold', 'FontColor', [0.80 0.65 0.00], ...
    'BackgroundColor', [0.87 0.95 0.83]);

% Top row (2 cols): skeleton | distance map - images, so wider.
% Bottom row (4 cols, was 3): diameter-by-depth | length-by-depth |
% distance histogram | tortuosity-by-depth (Written by Kira Shaw with
% Claude Code, Aug 2026 - rejigged from 3 to 4 columns to fit it in).
% row gap widened to 45px (was 10) - the bottom row's titles are two lines
% (name + stats line), which need more headroom above them than a single-
% line title does, or they crowd into the row above.
gridH = 200;
gridY = @(row) 55 + (2-row)*(gridH+45);   % row 1 = top, row 2 = bottom

imgW = floor((RW - 10) / 2);
imgX = @(col) RX + (col-1)*(imgW+10);
pltW = floor((RW - 30) / 4);
pltX = @(col) RX + (col-1)*(pltW+10);

axSkel = uiaxes(fig, 'Position', P(imgX(1), gridY(1), imgW, gridH), 'Visible', 'off');
axSkel.XTick = []; axSkel.YTick = [];
title(axSkel, 'Skeleton  (max projection)');

axDist = uiaxes(fig, 'Position', P(imgX(2), gridY(1), imgW, gridH), 'Visible', 'off');
axDist.XTick = []; axDist.YTick = [];
title(axDist, 'Distance to nearest vessel  (max projection, um)');

axDiamDepth = uiaxes(fig, 'Position', P(pltX(1), gridY(2), pltW, gridH), 'Visible', 'off');
title(axDiamDepth, 'Diameter by depth');
xlabel(axDiamDepth, 'Depth (um)');  ylabel(axDiamDepth, 'Diameter (um)');

axLengthDepth = uiaxes(fig, 'Position', P(pltX(2), gridY(2), pltW, gridH), 'Visible', 'off');
title(axLengthDepth, 'Length by depth');
xlabel(axLengthDepth, 'Depth (um)');  ylabel(axLengthDepth, 'Length (um)');

% tortuosity = actual (skeleton) path length / straight-line ("as the
% crow flies") distance between a branch's start and end - 1 is perfectly
% straight, higher is more tortuous (Written by Kira Shaw with Claude
% Code, Aug 2026; see extractBranches). Swapped with the histogram below
% (was slot 4, now slot 3) to match the pop-out figure's order.
axTortDepth = uiaxes(fig, 'Position', P(pltX(3), gridY(2), pltW, gridH), 'Visible', 'off');
title(axTortDepth, 'Tortuosity by depth');
xlabel(axTortDepth, 'Depth (um)');  ylabel(axTortDepth, 'Tortuosity');

axDistHist = uiaxes(fig, 'Position', P(pltX(4), gridY(2), pltW, gridH), 'Visible', 'off');
title(axDistHist, 'Distance to nearest vessel');
xlabel(axDistHist, 'Distance (um)');  ylabel(axDistHist, '% of tissue');

% ---- visibility groups (Written by Kira Shaw with Claude Code, Aug 2026) ----
% zstackRightH: settings, shown as soon as zstack mode is picked.
% zstackResultsH: the results grid + density headline - stays blank/hidden
% until "Process Stack" has actually produced something (see
% cb_analysisChanged, resetDensityDisplay, cb_zAnalyze), instead of
% showing a wall of empty titled axes from the moment zstack is selected.
zstackRightH   = [lblSegments, tblSegments];
zstackResultsH = [pnlDensity, axSkel, axDist, axDiamDepth, axLengthDepth, ...
    axDistHist, axTortDepth];

% =============================================================================
%  LINESCAN RIGHT PANEL
% =============================================================================
% Upper half: binary linescan image (after Binarise)
lblLsBinaryHdr = uilabel(fig, 'Position', P(RX,718,500,18), ...
    'Text', 'Binary linescan  (current frame — after Binarise)', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25], ...
    'Visible', 'off');
lsBinaryAx = uiaxes(fig, 'Position', P(RX,528,RW,186), 'Visible', 'off');
lsBinaryAx.XTick = []; lsBinaryAx.YTick = [];
lsBinaryAx.Color = [0.10 0.10 0.10];
lsBinaryAx.Toolbar.Visible = 'off';   % see dispAx above
colormap(lsBinaryAx, 'gray');
lsBinaryAx.Title.String = 'Binary (not yet computed)';
lsBinaryAx.Title.FontSize = F(9);
% Matches dispAx's (raw) convention set in renderLsFrame - kept in sync
% here too, and re-applied on every entry to linescan mode (see
% cb_analysisChanged), so raw and binary never show mismatched axis
% labels regardless of load state (Written by Kira Shaw with Claude
% Code, Aug 2026).
xlabel(lsBinaryAx, 'Spatial pixel');  ylabel(lsBinaryAx, 'Scan line (time ↓)');

% Angle-check result overlay text (shown after Check line angle)
lblLsAngleRight = uilabel(fig, 'Position', P(RX,702,RW,20), ...
    'Text', '', 'FontSize', F(11), 'FontWeight', 'bold', ...
    'FontColor', [0.15 0.35 0.65], 'Visible', 'off');

% RBC detection count — large readable label in right panel (linescan mode only)
lblLsRBCResult = uilabel(fig, 'Position', P(RX,672,600,28), ...
    'Text', '', 'FontSize', F(15), 'FontWeight', 'bold', ...
    'FontColor', [0.08 0.45 0.08], 'Visible', 'off', ...
    'HorizontalAlignment', 'left');

% Lower half: three result traces, stacked in rows (was side-by-side
% columns) - RBCV top, Haematocrit middle, RBC flux bottom, full width.
% Grown to fill the space up to the scan-info/RBC-count labels above (was
% capped at a fixed 136px/row with a redundant "Analysis results" header
% eating another row's worth of blank space above them) - each plot's own
% title already says what it is, so the header is dropped rather than
% fought for room (Kira Shaw with Claude Code, Aug 2026).
lsResH   = 190;  % each row's height
lsResGap = 12;
lsRowFlux = 55;                              % bottom row
lsRowHct  = lsRowFlux + lsResH + lsResGap;   % middle row
lsRowVel  = lsRowHct  + lsResH + lsResGap;   % top row

lsVelAx = uiaxes(fig, 'Position', P(RX,lsRowVel,RW,lsResH), 'Visible', 'off');
lsVelAx.Color  = [0.97 0.97 0.97];
lsVelAx.XColor = [0.30 0.30 0.30];
lsVelAx.YColor = [0.30 0.30 0.30];
xlabel(lsVelAx, 'Time (s)');  ylabel(lsVelAx, 'Velocity (mm/s)');
title(lsVelAx, 'Red Blood Cell Velocity');

lsHctAx = uiaxes(fig, 'Position', P(RX,lsRowHct,RW,lsResH), 'Visible', 'off');
lsHctAx.Color  = [0.97 0.97 0.97];
lsHctAx.XColor = [0.30 0.30 0.30];
lsHctAx.YColor = [0.30 0.30 0.30];
xlabel(lsHctAx, 'Time (s)');  ylabel(lsHctAx, 'RBC density (%)');
title(lsHctAx, 'Haematocrit');

lsFluxAx = uiaxes(fig, 'Position', P(RX,lsRowFlux,RW,lsResH), 'Visible', 'off');
lsFluxAx.Color  = [0.97 0.97 0.97];
lsFluxAx.XColor = [0.30 0.30 0.30];
lsFluxAx.YColor = [0.30 0.30 0.30];
xlabel(lsFluxAx, 'Time (s)');  ylabel(lsFluxAx, 'Flux (RBC/s)');
title(lsFluxAx, 'RBC Flux');

linescanRightH  = [lblLsBinaryHdr, lsBinaryAx, lblLsAngleRight, lblLsRBCResult];
linescanResultsH = [lsVelAx, lsHctAx, lsFluxAx];

% ---- Export buttons (figure and data, side by side - figure first, per
% Kira Shaw's request Aug 2026) --------------------------------------------
btnW2 = floor((RW-10)/2);   % width of each button
btnExport = uibutton(fig, ...
    'Position',        P(RX+btnW2+10,14,btnW2,33), ...
    'Text',            'Export data', ...
    'FontSize',        F(13), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.15 0.25 0.68], ...
    'FontColor',       [1 1 1], ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) cb_export());

btnExportFig = uibutton(fig, ...
    'Position',        P(RX,14,btnW2,33), ...
    'Text',            'Export figure', ...
    'FontSize',        F(13), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.35 0.20 0.55], ...
    'FontColor',       [1 1 1], ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) cb_exportFig());


% =============================================================================
%  INITIAL STATE
% =============================================================================
state.rawVess       = [];
state.expDir        = '';
state.frame50       = [];
state.perivascularCaPath = '';  % xyDiam: optional second TIF (perivascular calcium)
state.cont_calcium  = {};       % xyDiam: per-branch raw perivascular Ca trace (AU),
                                 % aligned row-for-row with cont_diams (see cb_go)
state.cont_calcium_bg     = {}; % xyDiam: per-branch background-ring trace (AU)
state.cont_calcium_bgcorr = {}; % xyDiam: per-branch background-subtracted trace (AU)
state.cont_calcium_dFF    = {}; % xyDiam: per-branch dF/F0 (Suite2p-style, see cb_go)
state.caInsideUm    = 3.5;      % xyDiam: microns inside vessel edge sampled for calcium
state.caOutsideUm   = 7;        % xyDiam: microns outside vessel edge sampled for calcium
state.caBgRingUm    = 5;        % xyDiam: micron width of the background ring beyond Out
state.caGuardUm     = 1;        % xyDiam: guard gap between the signal ring and the BG ring
state.caInsidePx    = NaN;      % xyDiam: the above, resolved to px in cb_go via pixel size
state.caOutsidePx   = NaN;
state.caBgRingPx    = NaN;
state.caGuardPx     = NaN;
state.caBgCoeff     = 0.7;      % xyDiam: background subtraction coefficient r
state.caBaselineSec = 60;       % xyDiam: dF/F0 sliding-baseline window, seconds
state.caDarkFloor   = NaN;      % xyDiam: dark-offset floor subtracted from calcium (see cb_go)
state.skeletons     = {};
state.masks         = {};
state.perpEndpts    = {};
state.cont_diams    = {};
state.nanInds       = {};
state.times         = {};
state.pxsz_um       = NaN;
state.fps           = NaN;
state.diamUnit      = 'pixels';
state.timeUnit      = 'frames';
state.skelDrawn     = false;
state.branchesDrawn = false;
state.analysisRun   = false;

% ---- zstack mode state (Written by Kira Shaw with Claude Code, Aug 2026) ----
state.zRaw          = [];      % loaded z-stack, frames x H x W
state.zNumFrames    = 0;
state.zCurrentFrame = 1;
state.zStep_um      = NaN;
% segments: struct array, one row per frame-range - startF, endF (inclusive,
% 1-indexed), mode ('auto'/'manual'), value (threshold in raw data units).
% Empty = no threshold applied yet (raw display).
state.zSegments     = struct('startF', {}, 'endF', {}, 'mode', {}, 'value', {});
state.zRangeStart   = [];       % frame marked by "Start range"; [] = none pending

% ---- z-stack smoothing + pruning (Written by Kira Shaw with Claude Code,
% Aug 2026) --------------------------------------------------------------
% zWorkVol is the volume threshold/skeleton logic actually reads from -
% double(zRaw) when smoothing is off, Gaussian-smoothed when it's on, kept
% in sync by refreshZWorkVol(). zRaw itself is left untouched so the "raw"
% display mode always shows the true data.
state.zSmooth       = false;
state.zSmoothSigma  = 1;        % pixels, Gaussian sigma
state.zPruneLen     = 10;       % voxels, bwskel MinBranchLength
state.zSkelPreview  = false;    % live 2D skeleton overlay on the current frame
state.zWorkVol      = [];

% ---- vascular density analysis results (Written by Kira Shaw with Claude
% Code, Aug 2026) --------------------------------------------------------
state.zBranches        = [];    % table: length_um, diam_um, depth_um per branch
state.zVolume_mm3       = NaN;
state.zVolumeHWZ_um     = [NaN NaN NaN];   % [height width depth], for display
state.zDensity_mPerMm3  = NaN;
state.zTortuosity_mean  = NaN;  % mean actual/chord length ratio across branches
state.zSlantCorrected   = false; % whether the last run used slant-corrected volume
state.zDistVals_um      = [];   % sampled tissue-to-vessel distances, for the histogram
state.zDistP50_um       = NaN;  % 50th/95th percentile tissue-to-vessel distance
state.zDistP95_um       = NaN;
% boundary-restricted (2nd density measure, per-frame convex hull of the
% vessel mask) - Written by Kira Shaw with Claude Code, Aug 2026
state.zVolume_boundaryRestricted_mm3      = NaN;
state.zDensity_boundaryRestricted_mPerMm3 = NaN;
state.zDistVals_boundaryRestricted_um     = [];
state.zDistP50_boundaryRestricted_um      = NaN;
state.zDistP95_boundaryRestricted_um      = NaN;
state.zBoundaryRestrictApplied = false;   % whether the last run computed this measure
state.zBoundaryCoords   = {};   % per-frame boundary outline [x y] coords, original grid
state.zBoundaryMaskVol  = [];   % cached, for the export figure's boundary overlay
state.zSkelVol          = [];   % cached skeleton volume, for the export "stacked slices" view
state.zDistMapVol       = [];   % cached distance-map volume, same purpose
state.zAnalysisRun      = false;

% ---- linescan mode state -----------------------------------------------
state.lsRaw          = [];      % [nF x nSp x nT] raw linescan volume
state.lsRawLine      = [];      % [nSp x (nT*nF)]: rows=spatial, cols=time
state.lsBinaryLine   = [];      % [nSp x (nT*nF)] binarised
state.lsNumFrames    = 0;
state.lsNumSpatial   = 0;       % spatial pixels (rows of rawLine)
state.lsNumTime      = 0;       % scan reps per frame (cols per frame)
state.lsCurrentFrame = 1;
state.lsCurrentWin   = 1;
state.lsNumWins      = 0;
state.lsMspline      = NaN;
state.lsLps          = NaN;
state.lsWindowSz_ms  = 80;      % default 80 ms (was 40 ms/Drew paper rec.; changed 2026-08-27)
state.lsWindowSz_px  = 0;       % windowsize in pixels, divisible by 4
state.lsStepSz_px    = 0;       % stepsize = windowsize/4
state.lsThresh       = 0.5;     % binarisation threshold [0,1]
state.lsVelocity     = [];      % velocity trace (mm/s) - "main" reported value
state.lsHct          = [];      % haematocrit trace (%)
state.lsFlux         = [];      % RBC flux trace (RBC/s)
state.lsTime         = [];      % time vector (s)
state.lsVelApp       = [];      % raw/uncorrected apparent velocity (mm/s) -
                                 % kept alongside lsVelocity for Export data
state.lsApplyCharpak = false;   % was the scan-velocity correction on for this run
state.lsWinLineStart = [];      % absolute start line index of each window
state.lsPxsz         = NaN;
state.lsAngleChecked = false;   % cleared on every slide (frame/window) rather than
                                 % live-recomputed - re-click "Check line angle" for
                                 % wherever you land (Kira Shaw with Claude Code, Aug 2026)
state.lsBinarised    = false;
state.lsRBCActive    = false;   % individual-RBC detection is now a toggle button,
                                 % not a checkbox (Kira Shaw with Claude Code, Aug 2026)
state.lsCropRange    = [];      % [x0 x1] spatial-px crop (in ORIGINAL px coords),
                                 % or [] = no crop. Applied by regenLsRawLine().
state.lsCropPhase    = 'idle';  % 'idle' | 'drawing' | 'applied' - crop button state
state.lsCropROI      = [];      % handle to the in-progress drawline ROI, if any
state.lsAnalysisRun  = false;
setappdata(fig, 'state', state);

% =============================================================================
%  NESTED CALLBACKS  (share fig, BC, prefs, dispAx, etc. via closure)
% =============================================================================

    % =========================================================================
    function cb_loadData()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Used to pass cd (current directory) straight through as the
        % dialog's starting folder. MATLAB's file chooser can reject that
        % outright ("'Initial file path' must be ... a valid path") if the
        % current directory isn't one it's happy with right now (e.g. a
        % OneDrive folder that isn't fully available) - validate first and
        % fall back to '' (dialog's own default) rather than erroring out
        % of Load Data entirely before the file picker even opens.
        startDir = pwd;
        if isempty(startDir) || ~isfolder(startDir)
            startDir = '';
        end
        [tifName, tifFolder] = uigetfile( ...
            {'*.tif;*.tiff', 'TIF / OME-TIF files (*.tif, *.tiff, *.ome.tif, *.ome.tiff)'}, ...
            'Select vessel TIF file', startDir);
        if isequal(tifName, 0), return; end
        tifPath = fullfile(tifFolder, tifName);
        expDir  = tifFolder;

        postUpdate('Loading TIF — please wait...');
        rawVess = loadTifFileIn2Mat(tifPath);

        s            = getappdata(fig, 'state');
        s.expDir     = expDir;

        % ---- auto-detect pixel size / fps / z-step, shared by both modes ---
        % Checks the TIF's own metadata first, then falls back to an
        % accompanying .ini (Scientifica) or .xml (ThorLabs) file found
        % anywhere under expDir - by extension, not by an assumed filename
        % (see autoDetectAcqParams.m). Anything not found is left blank
        % for manual entry.
        [pxsz_auto, fps_auto, zstep_auto, pxSrc, fpsSrc] = ...
            autoDetectAcqParams(tifPath, expDir);

        if ~isnan(pxsz_auto)
            efPxsz.Value = num2str(pxsz_auto, '%.4g');
        else
            efPxsz.Value = '';
        end
        if ~isnan(fps_auto)
            efFPS.Value = num2str(fps_auto, '%.4g');
        else
            efFPS.Value = '';
        end
        if ~isnan(zstep_auto)
            efZstep.Value = num2str(zstep_auto, '%.4g');
        else
            efZstep.Value = '';
        end

        if strcmp(ddAnalysis.Value, 'zstack')
            % ---- zstack setup ---------------------------------------------
            s.zRaw          = rawVess;
            s.zNumFrames    = size(rawVess, 1);
            s.zCurrentFrame = 1;
            s.zStep_um      = zstep_auto;
            s.zSegments     = struct('startF', {}, 'endF', {}, 'mode', {}, 'value', {});
            s.zRangeStart   = [];
            s.zBranches       = [];
            s.zVolume_mm3     = NaN;
            s.zVolumeHWZ_um   = [NaN NaN NaN];
            s.zDensity_mPerMm3 = NaN;
            s.zTortuosity_mean = NaN;
            s.zSlantCorrected = false;
            s.zDistVals_um    = [];
            s.zDistP50_um     = NaN;
            s.zDistP95_um     = NaN;
            s.zVolume_boundaryRestricted_mm3      = NaN;
            s.zDensity_boundaryRestricted_mPerMm3 = NaN;
            s.zDistVals_boundaryRestricted_um     = [];
            s.zDistP50_boundaryRestricted_um      = NaN;
            s.zDistP95_boundaryRestricted_um      = NaN;
            s.zBoundaryRestrictApplied = false;
            s.zBoundaryCoords = {};
            s.zBoundaryMaskVol = [];
            s.zSkelVol        = [];
            s.zDistMapVol     = [];
            s.zAnalysisRun    = false;
            s.zSmooth         = false;
            s.zSmoothSigma    = 1;
            s.zPruneLen       = 10;
            s.zSkelPreview    = false;
            s.zWorkVol        = double(rawVess);
            setappdata(fig, 'state', s);

            zSlider.Limits = [1, max(2, s.zNumFrames)];  % Limits can't collapse to a point
            zSlider.Value  = 1;
            lblZFrame.Text = sprintf('1 / %d', s.zNumFrames);

            chkAutoThresh.Value    = false;
            chkManualThresh.Value  = false;
            chkManualThresh.Enable = 'off';
            sldManualThresh.Enable = 'off';
            ddThreshMethod.Enable  = 'off';
            btnRangeStart.Enable   = 'off';
            btnRangeEnd.Enable     = 'off';
            btnZAnalyze.Enable     = 'off';
            chkSmooth.Value        = false;
            efSmoothSigma.Value    = 1;
            efPruneLen.Value       = 10;
            chkSkelPreview.Value   = false;
            chkSlantCorrect.Value  = false;
            chkBoundaryRestrict.Value = false;

            resetDensityDisplay();
            renderZFrame(s);
            refreshSegmentsTable(s);

            msg = sprintf('Loaded: %s   (%d slices, %d x %d px)', ...
                tifName, s.zNumFrames, size(rawVess,2), size(rawVess,3));
        elseif strcmp(ddAnalysis.Value, 'linescan')
            % ---- linescan setup ---------------------------------------------
            % loadTifFileIn2Mat returns [nF x width x height] because it
            % transposes each TIF frame: t.read()'  gives [width x height].
            % For a ThorLabs linescan RBCV.tif:
            %   width  (dim 2) = spatial pixels along the scan line (SPACE)
            %   height (dim 3) = scan-line repetitions per frame   (TIME)
            nF  = size(rawVess, 1);
            nSp = size(rawVess, 2);   % spatial pixels (many, portrait Y-axis)
            nT  = size(rawVess, 3);   % scan reps per frame (few, time X-axis)

            % Build concatenated space-time image [nSp x (nT*nF)]:
            % rows = spatial pixels (Y), cols = total scan lines / time (X)
            % matches original extractLinescanVelocity convention:
            %   rawLine = reshape(A, [width, height*num_images])
            vol = permute(double(rawVess), [2 3 1]);   % nSp x nT x nF
            rawLine = reshape(vol, [nSp, nT*nF]);       % [spatial x total_time]

            % Robust percentile normalisation
            p_lo = pctileLocal(rawLine(:), 1);
            p_hi = pctileLocal(rawLine(:), 99);
            if p_hi > p_lo
                rawLine = (rawLine - p_lo) / (p_hi - p_lo);
            end
            rawLine = max(0, min(1, rawLine));

            % Timing: nT scan reps per frame at fps frames/sec
            if ~isnan(fps_auto) && fps_auto > 0
                mspline_v = 1000 / (fps_auto * nT);   % ms per scan line
                lps_v     = fps_auto * nT;             % lines per second
            else
                mspline_v = NaN;  lps_v = NaN;
            end

            % Default window size: 80 ms (was 40 ms/Drew paper rec.; changed
            % 2026-08-27), snapped to multiple of 4
            winMs = 80;
            if ~isnan(mspline_v) && mspline_v > 0
                winPx = round((winMs / mspline_v) / 4) * 4;
                winPx = max(4, winPx);
            else
                winPx = 40;
            end
            stepPx = round(0.25 * winPx);
            nWins  = floor((nT * nF) / stepPx) - 3;   % total time cols / step

            s.lsRaw          = rawVess;
            s.lsRawLine      = rawLine;   % [nSp x (nT*nF)]
            s.lsPxsz         = pxsz_auto;
            s.lsBinaryLine   = [];
            s.lsNumFrames    = nF;
            s.lsNumSpatial   = nSp;   % spatial pixels (rows of rawLine)
            s.lsNumTime      = nT;    % scan reps per frame (cols per frame)
            s.lsCurrentFrame = 1;
            s.lsCurrentWin   = 1;
            s.lsNumWins      = max(1, nWins);
            s.lsMspline      = mspline_v;
            s.lsLps          = lps_v;
            s.lsWindowSz_ms  = winMs;
            s.lsWindowSz_px  = winPx;
            s.lsStepSz_px    = stepPx;
            s.lsThresh       = 0.5;
            s.lsVelocity     = [];
            s.lsHct          = [];
            s.lsFlux         = [];
            s.lsTime         = [];
            s.lsVelApp       = [];
            s.lsApplyCharpak = false;
            s.lsWinLineStart = [];
            s.lsAngleChecked  = false;
            s.lsBinarised     = false;
            s.lsRBCActive     = false;
            if isfield(s,'lsCropROI') && ~isempty(s.lsCropROI) && isvalid(s.lsCropROI)
                delete(s.lsCropROI);
            end
            s.lsCropRange    = [];
            s.lsCropPhase    = 'idle';
            s.lsCropROI      = [];
            s.lsAnalysisRun  = false;
            setappdata(fig, 'state', s);

            % Update parameters panel
            if ~isnan(lps_v)
                efLps.Value = num2str(lps_v, '%.1f');
            else
                efLps.Value = '';
            end
            efLsWinSz.Value = winMs;

            % Configure sliders
            lsFrameSlider.Limits = [1, max(2, nF)];
            lsFrameSlider.Value  = 1;
            lblLsFrame.Text      = sprintf('1 / %d', nF);
            lsWinSlider.Limits   = [1, max(2, nWins)];
            lsWinSlider.Value    = 1;
            lblLsWin.Text        = sprintf('Win 1 / %d', nWins);

            % Enable processing buttons now data is loaded
            btnLsCheckAngle.Enable = 'on';
            btnLsBinarise.Enable   = 'on';
            btnLsCrop.Enable       = 'on';
            btnLsRBC.Enable        = 'off';  % re-enabled once binarised (cb_lsBinarise)
            btnLsGo.Enable         = 'on';

            % Reset right panel
            cla(lsBinaryAx);
            lsBinaryAx.Title.String = 'Binary (not yet computed)';
            % Explicitly clear the old traces, not just hide the axes - the
            % previous file's plot lines were left in place under the
            % hidden axes, so anything that re-shows linescanResultsH
            % without a fresh Run Analysis (or a rendering hiccup) could
            % expose stale data from the last file (Kira Shaw with Claude
            % Code, Aug 2026).
            cla(lsVelAx);  title(lsVelAx, '');
            cla(lsHctAx);  title(lsHctAx, '');
            cla(lsFluxAx); title(lsFluxAx, '');
            for h = linescanResultsH, h.Visible = false; end
            lblLsAngleResult.Text = '';
            lblLsAngleRight.Text  = '';
            lblLsRBCStatus.Text   = 'Off';
            lblLsRBCResult.Text    = '';
            lblLsRBCResult.Visible = 'off';
            btnLsCrop.Text        = 'Crop (width)';
            lblLsCropStatus.Text  = 'Not cropped';

            % Render first frame and first window
            renderLsFrame(s);
            renderLsWindow(s);

            msg = sprintf('Loaded: %s   (%d frames, %d spatial px, %d scan reps/frame, %d lines total)', ...
                tifName, nF, nSp, nT, nT*nF);
        else
            % ---- xyDiam setup (unchanged) -----------------------------------
            s.rawVess     = rawVess;
            s.frame50     = squeeze(rawVess(min(50, size(rawVess,1)), :, :));
            s.skeletons   = {};  s.masks     = {};
            s.perpEndpts  = {};  s.cont_diams = {};
            s.cont_calcium = {};  s.cont_calcium_bg = {};
            s.cont_calcium_bgcorr = {};  s.cont_calcium_dFF = {};
            s.skelDrawn   = false;  s.branchesDrawn = false;
            s.analysisRun = false;
            % A previously-associated perivascular calcium TIF belongs to
            % whichever vessel recording was loaded before - don't carry it
            % over to a new one (Kira Shaw with Claude Code, Aug 2026).
            s.perivascularCaPath = '';
            chkPerivascularCa.Value = false;
            cla(caAx);  title(caAx, 'Perivascular Calcium (not enabled)');
            applyCaLayout(false);
            setappdata(fig, 'state', s);

            % show frame in display axes
            refreshDisplay(s, {}, {});

            lblSkelTick.Text    = '';
            lblBranchTick.Text  = '';
            cla(heatAx);  cla(traceAx);  hold(traceAx, 'on');

            msg = sprintf('Loaded: %s   (%d frames, %d x %d px)', ...
                tifName, size(rawVess,1), size(rawVess,2), size(rawVess,3));
        end

        btnExport.Enable    = 'off';
        btnExportFig.Enable = 'off';

        msgParts = {msg};
        if ~isnan(pxsz_auto)
            msgParts{end+1} = sprintf('Pixel size auto-filled: %.4g um (%s).', pxsz_auto, pxSrc);
        else
            msgParts{end+1} = 'Pixel size not found in TIF metadata/OME-XML/ini/xml - enter manually.';
        end
        if ~isnan(fps_auto)
            msgParts{end+1} = sprintf('Frame rate auto-filled: %.4g Hz (%s).', fps_auto, fpsSrc);
        else
            msgParts{end+1} = 'Frame rate not found in TIF/ini/xml - enter manually.';
        end
        if strcmp(ddAnalysis.Value, 'zstack')
            if ~isnan(zstep_auto)
                msgParts{end+1} = sprintf('Z-step auto-filled: %.4g um (TIF metadata).', zstep_auto);
            else
                msgParts{end+1} = 'Z-step not found in TIF metadata - enter manually.';
            end
        end

        postUpdate(strjoin(msgParts, '  '));
    end

    % =========================================================================
    %  ZSTACK MODE  (Written by Kira Shaw with Claude Code, Aug 2026)
    % =========================================================================
    function cb_analysisChanged()
        isZ  = strcmp(ddAnalysis.Value, 'zstack');
        isLS = strcmp(ddAnalysis.Value, 'linescan');
        isXY = ~isZ && ~isLS;
        s    = getappdata(fig, 'state');

        % Clear every display axis so no stale content shows in the new mode
        cla(dispAx);      title(dispAx,'');  xlabel(dispAx,'');  ylabel(dispAx,'');
        axis(dispAx, 'normal');
        cla(heatAx);
        cla(traceAx);     try, legend(traceAx,    'off'); catch, end
        cla(lsBinaryAx);  lsBinaryAx.Title.String = 'Binary (not yet computed)';
        cla(lsWinAx);
        % zstack result axes
        cla(axSkel);      title(axSkel,      'Skeleton  (max projection)');
        cla(axDist);      title(axDist,      'Distance to nearest vessel  (max projection, um)');
                          try, colorbar(axDist,    'off'); catch, end
                          axis(axDist, 'normal');
        cla(axDiamDepth); title(axDiamDepth, 'Diameter by depth');
                          try, legend(axDiamDepth, 'off'); catch, end
        cla(axLengthDepth); title(axLengthDepth, 'Length by depth');
        cla(axDistHist);  title(axDistHist,  'Distance to nearest vessel');
        cla(axTortDepth); title(axTortDepth, 'Tortuosity by depth');
        % linescan result axes
        cla(lsVelAx);  cla(lsHctAx);  cla(lsFluxAx);
        % RBC result label
        lblLsRBCResult.Text    = '';
        lblLsRBCResult.Visible = 'off';
        % reset processing updates
        txaUpdates.Value = 'Waiting for data input.';

        for h = xyDiamLeftH,      h.Visible = isXY;                          end
        for h = zstackLeftH,      h.Visible = isZ;                           end
        for h = linescanLeftH,    h.Visible = isLS;                          end
        for h = xyDiamRightH,     h.Visible = isXY;                         end
        % lblCaTrace/caAx are deliberately outside xyDiamRightH (see where
        % they're created) - their own visibility/size is calcium-tick-
        % dependent, not just mode-dependent, so it's set separately here
        % (Kira Shaw with Claude Code, Aug 2026).
        applyCaLayout(isXY && chkPerivascularCa.Value);
        for h = zstackRightH,     h.Visible = isZ;                           end
        for h = linescanRightH,   h.Visible = isLS;                          end
        for h = linescanResultsH, h.Visible = (isLS && s.lsAnalysisRun);    end
        % zstack results stay hidden until analysis has run
        for h = zstackResultsH,   h.Visible = (isZ && s.zAnalysisRun);      end

        btnGo.Visible       = isXY;
        btnZAnalyze.Visible = isZ;
        btnLsGo.Visible     = isLS;

        lblNBranch.Visible = isXY;
        efNBranch.Visible  = isXY;
        lblZstep.Visible   = isZ;
        efZstep.Visible    = isZ;
        lblLps.Visible     = isLS;
        efLps.Visible      = isLS;

        zSlider.Visible    = isZ;
        lblZFrame.Visible  = isZ;

        if isZ
            dispAx.Position           = P(LX,366,LW,287);
            lsBinaryAx.Position       = P(RX,528,RW,186);
            lblDisplayHeader.Position = P(LX,684,250,18);
            lblDisplayHeader.Text     = 'Z-stack display';
            lblDisplayHeader.Visible  = 'on';   % linescan mode hides this - restore it here
            lblLsBinaryHdr.Position   = P(RX,718,500,18);   % restore default
            lblLsFrameHdr.Position    = P(LX,    417,70,14);
            lblLsFrame.Position       = P(LX+72, 417,90,14);
            lsFrameSlider.Position    = Pslider(LX+170, 420, LW-175);
            lblLsAngleRight.Position  = P(RX,507,RW,18);
        elseif isLS
            % Raw and binary panels sit side by side in the LEFT panel,
            % in the space normally occupied by dispAx (y=435, h=240).
            % An 18 px strip on the far left holds the per-frame window slider.
            % The right panel is kept clear for future data displays.
            slW = 18;  % vertical slider strip width
            halfW_ls = floor((LW - 6 - slW) / 2);   % ~195 px each
            panelsRight = LX+slW+2*halfW_ls+6;       % right edge of lsBinaryAx
            lsWinVertSlider.Position  = PsliderV(LX, 435, 240);
            dispAx.Position           = P(LX+slW,           435, halfW_ls, 240);
            lsBinaryAx.Position       = P(LX+slW+halfW_ls+6, 435, halfW_ls, 240);
            % "Linescan | raw (left) binary (right)" and "Frame #/#" are
            % dropped here - both are redundant with dispAx's own "Raw -
            % frame #/#" title, and removing them frees up the top strip
            % for the "Sliding window: Win #/#" readout below (Kira Shaw
            % with Claude Code, Aug 2026).
            lblDisplayHeader.Visible  = 'off';
            lblLsFrameHdr.Visible     = 'off';
            lblLsFrame.Visible        = 'off';
            lblLsBinaryHdr.Position   = P(-600,-50,LW,18);  % parked off-screen
            % Raw and binary must always show matching axes - re-applied here
            % (not just in the render functions) so they still match even
            % before any file is loaded (Written by Kira Shaw with Claude
            % Code, Aug 2026).
            xlabel(dispAx, 'Spatial pixel');     ylabel(dispAx, 'Scan line (time ↓)');
            xlabel(lsBinaryAx, 'Spatial pixel'); ylabel(lsBinaryAx, 'Scan line (time ↓)');
            % "Window" label sits directly above lsWinVertSlider; frame
            % slider spans the full width below BOTH raw and binary. The
            % "Sliding window: Win #/#" pair (previously right below the
            % small preview axes, where it crowded that axes' rotated Y-
            % label) now sits here instead, in the space "Frame #/#" used
            % to occupy before being dropped above (Kira Shaw with Claude
            % Code, Aug 2026).
            lblLsWinVertHdr.Position  = P(LX,        676, 50,12);
            lblLsWinVertVal.Position  = P(LX,        662, 50,12);
            lblLsWinHdr.Position      = P(LX+slW+60, 676, 100,12);
            lblLsWin.Position         = P(LX+slW+164,676, 90,12);
            lsFrameSlider.Position    = Pslider(LX+slW, 420, panelsRight-(LX+slW));
            % Angle result + RBC result in right panel - sit just below the
            % Processing updates box (which ends around y=730), well clear
            % of where the Run-analysis line plots render (y up to 483), so
            % they never fight the plots for space (Kira Shaw with Claude
            % Code, Aug 2026).
            lblLsAngleRight.Position  = P(RX, 702, 700, 20);
            lblLsRBCResult.Position   = P(RX, 672, 700, 28);
        else
            dispAx.Position           = P(LX,320,LW,361);
            lsBinaryAx.Position       = P(RX,528,RW,186);
            lblDisplayHeader.Position = P(LX,684,250,18);
            lblDisplayHeader.Text     = 'Vessel display';
            lblDisplayHeader.Visible  = 'on';   % linescan mode hides this - restore it here
            lblLsBinaryHdr.Position   = P(RX,718,500,18);   % restore default
            lblLsFrameHdr.Position    = P(LX,    417,70,14);
            lblLsFrame.Position       = P(LX+72, 417,90,14);
            lsFrameSlider.Position    = Pslider(LX+170, 420, LW-175);
            lblLsAngleRight.Position  = P(RX,507,RW,18);
        end

        if isZ && ~isempty(s.zRaw)
            renderZFrame(s);
        elseif isLS && ~isempty(s.lsRawLine)
            renderLsFrame(s);
            renderLsWindow(s);
        elseif isXY && ~isempty(s.rawVess)
            refreshDisplay(s, s.skeletons, s.masks);
        end
    end

    % =========================================================================
    function cb_zSliderChanging(value, fastMode)
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % fastMode (true while actively dragging, via ValueChangingFcn)
        % skips renderZFrame's mask cleanup/skeleton preview, which is what
        % made scrubbing feel slow - a full-quality render always follows
        % once the slider settles, via ValueChangedFcn below.
        if nargin < 2, fastMode = false; end
        s = getappdata(fig, 'state');
        if isempty(s.zRaw), return; end

        frameIdx = round(value);
        frameIdx = max(1, min(s.zNumFrames, frameIdx));
        s.zCurrentFrame = frameIdx;
        setappdata(fig, 'state', s);

        lblZFrame.Text = sprintf('%d / %d', frameIdx, s.zNumFrames);
        renderZFrame(s, fastMode);

        % reflect the active segment's auto/manual state + value in the
        % controls as the slider crosses into a different segment's range
        idx = getActiveSegmentIdx(s.zSegments, frameIdx);
        if ~isempty(idx)
            seg = s.zSegments(idx);
            isManual = strcmp(seg.mode, 'manual');
            chkManualThresh.Value = isManual;
            if isManual
                lo = min(s.zRaw(:));  hi = max(max(s.zRaw(:)), lo+1);
                sldManualThresh.Limits = [lo, hi];
                sldManualThresh.Value  = seg.value;
            end
        end
    end

    % =========================================================================
    function cb_autoThreshChanged()
        s = getappdata(fig, 'state');
        if isempty(s.zRaw)
            uialert(fig, 'Load a z-stack first.', 'No data');
            chkAutoThresh.Value = false;
            return;
        end

        if chkAutoThresh.Value
            % ---- turn on: whole-stack Otsu threshold as the single default -
            method = currentMethodName();
            postUpdate(sprintf('Computing whole-stack auto threshold (%s)...', method));
            drawnow;
            val = computeThreshold(s, s.zWorkVol, method);
            s.zSegments = struct('startF', 1, 'endF', s.zNumFrames, ...
                'mode', 'auto', 'value', val);
            setappdata(fig, 'state', s);

            ddThreshMethod.Enable  = 'on';
            chkManualThresh.Enable = 'on';
            btnRangeStart.Enable   = 'on';
            btnRangeEnd.Enable     = 'on';
            btnZAnalyze.Enable     = 'on';

            renderZFrame(s);
            refreshSegmentsTable(s);
            postUpdate(sprintf('Auto threshold (%s) applied to whole stack: %.4g.', method, val));
        else
            % ---- turn off: full reset, back to raw display ------------------
            s.zSegments    = struct('startF', {}, 'endF', {}, 'mode', {}, 'value', {});
            s.zRangeStart  = [];
            s.zAnalysisRun = false;
            setappdata(fig, 'state', s);

            chkManualThresh.Value  = false;
            chkManualThresh.Enable = 'off';
            sldManualThresh.Enable = 'off';
            ddThreshMethod.Enable  = 'off';
            btnRangeStart.Enable   = 'off';
            btnRangeEnd.Enable     = 'off';
            btnZAnalyze.Enable     = 'off';

            resetDensityDisplay();
            renderZFrame(s);
            refreshSegmentsTable(s);
            postUpdate('Threshold cleared - showing raw data.');
        end
    end

    % =========================================================================
    function cb_slantOptionChanged()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Both Slant-correct options change the reported density/distance
        % numbers whenever they're on, so a stack processed with one on and
        % another processed with it off aren't directly comparable (see the
        % README) - post that warning every time either is toggled, in
        % either direction, since changing which stacks use which setting
        % is exactly the situation to watch for.
        postUpdate(['Data may not be comparable between stacks if diff ' ...
            'slant corrections applied (or not).']);
    end

    % =========================================================================
    function cb_manualThreshChanged()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Bug found via a real report: ticking this while a range was
        % pending (Start range clicked, End range not yet) mutated the
        % ACTIVE segment immediately - which, before the range has been
        % carved out, can still be the WHOLE-STACK segment, not just the
        % frames about to be selected. Once "End range & apply" then split
        % it, the leftover remainder inherited that mutation (see
        % insertSegment) - so e.g. setting a harsher manual value for
        % frames 1-6 could silently make frames 7-end manual too. Now:
        % while a range is pending, this never touches any stored segment
        % - it only reveals/enables the slider (renderZFrame previews its
        % live value on the current frame instead). The segment mutation
        % path below only runs for the "just toggle the current segment,
        % no range being defined" use of this checkbox.
        s = getappdata(fig, 'state');
        if isempty(s.zSegments)
            chkManualThresh.Value = false;
            return;
        end
        rangePending = ~isempty(s.zRangeStart);

        idx = getActiveSegmentIdx(s.zSegments, s.zCurrentFrame);
        if chkManualThresh.Value
            lo = min(s.zRaw(:));  hi = max(max(s.zRaw(:)), lo+1);
            sldManualThresh.Limits = [lo, hi];
            if ~isempty(idx)
                sldManualThresh.Value = s.zSegments(idx).value;
            end
            sldManualThresh.Enable = 'on';
            if ~rangePending
                s.zSegments(idx).mode = 'manual';
            end
        else
            if rangePending
                sldManualThresh.Enable = 'off';
            else
                % turn off: recompute this segment's value as auto again
                seg    = s.zSegments(idx);
                region = s.zWorkVol(seg.startF:seg.endF, :, :);
                s.zSegments(idx).mode  = 'auto';
                s.zSegments(idx).value = computeThreshold(s, region, currentMethodName());
                sldManualThresh.Enable = 'off';
            end
        end
        setappdata(fig, 'state', s);
        renderZFrame(s);
        refreshSegmentsTable(s);
    end

    % =========================================================================
    function cb_manualSliderChanging(value, fastMode)
        % While a range is pending, don't touch the stored segment (see
        % cb_manualThreshChanged) - just redraw, so renderZFrame's own
        % pending-range preview logic shows the live slider value on the
        % current frame (Written by Kira Shaw with Claude Code, Aug 2026).
        % fastMode (true while actively dragging, via ValueChangingFcn)
        % skips renderZFrame's mask cleanup/skeleton preview - running that
        % on every tick while dragging was what made this slider feel slow
        % and hard to use for picking a value. ValueChangedFcn (fastMode
        % false) always follows once the slider settles, for a full-
        % quality render, and is the only one that updates the segments
        % table (no point doing that on every intermediate tick either).
        if nargin < 2, fastMode = false; end
        s = getappdata(fig, 'state');
        if isempty(s.zSegments), return; end
        if ~isempty(s.zRangeStart)
            renderZFrame(s, fastMode);
            return;
        end
        idx = getActiveSegmentIdx(s.zSegments, s.zCurrentFrame);
        if isempty(idx), return; end
        s.zSegments(idx).value = value;
        s.zSegments(idx).mode  = 'manual';
        setappdata(fig, 'state', s);
        renderZFrame(s, fastMode);
        if ~fastMode
            refreshSegmentsTable(s);
        end
    end

    % =========================================================================
    function cb_methodChanged()
        % Re-run every 'auto' segment (not manually-overridden ones) with
        % the newly selected method.
        s = getappdata(fig, 'state');
        if isempty(s.zSegments), return; end
        method = currentMethodName();
        for i = 1:numel(s.zSegments)
            if strcmp(s.zSegments(i).mode, 'auto')
                region = s.zWorkVol(s.zSegments(i).startF:s.zSegments(i).endF, :, :);
                s.zSegments(i).value = computeThreshold(s, region, method);
            end
        end
        setappdata(fig, 'state', s);
        renderZFrame(s);
        refreshSegmentsTable(s);
        postUpdate(sprintf('Recomputed auto segment(s) using %s.', method));
    end

    % =========================================================================
    function cb_smoothChanged()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Toggling "Smooth" or editing sigma rebuilds zWorkVol (the volume
        % threshold/skeleton logic reads from) and re-runs every 'auto'
        % segment against it, same as switching threshold method. Manual
        % segments keep whatever value was set by hand.
        s = getappdata(fig, 'state');
        if isempty(s.zRaw), return; end

        s.zSmooth      = chkSmooth.Value;
        s.zSmoothSigma = efSmoothSigma.Value;
        s = refreshZWorkVol(s);

        if ~isempty(s.zSegments)
            method = currentMethodName();
            for i = 1:numel(s.zSegments)
                if strcmp(s.zSegments(i).mode, 'auto')
                    region = s.zWorkVol(s.zSegments(i).startF:s.zSegments(i).endF, :, :);
                    s.zSegments(i).value = computeThreshold(s, region, method);
                end
            end
        end
        setappdata(fig, 'state', s);

        renderZFrame(s);
        refreshSegmentsTable(s);
        if s.zSmooth
            postUpdate(sprintf('Smoothing on (sigma %.3g px) - auto threshold(s) recomputed.', s.zSmoothSigma));
        else
            postUpdate('Smoothing off - auto threshold(s) recomputed on raw data.');
        end
    end

    % =========================================================================
    function cb_skelPreviewChanged()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Just flips the flag and redraws - the actual 2D skeleton overlay
        % is computed in renderZFrame, so it always matches whatever's
        % currently shown (raw/thresholded, whichever frame, current
        % smoothing) without duplicating that logic here.
        s = getappdata(fig, 'state');
        if isempty(s.zRaw), return; end
        s.zSkelPreview = chkSkelPreview.Value;
        setappdata(fig, 'state', s);
        renderZFrame(s);
    end

    % =========================================================================
    function cb_prunePreviewChanged()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Saves the edited value into state (zPruneLen was being read
        % straight off efPruneLen.Value everywhere it's used, so this
        % wasn't causing a bug, but it left state stale/unused - keeping
        % it in sync mirrors zSmooth/zSmoothSigma). Then redraws so
        % editing Prune length is reflected immediately if the skeleton
        % preview is on (a no-op visually otherwise).
        s = getappdata(fig, 'state');
        if isempty(s.zRaw), return; end
        s.zPruneLen = efPruneLen.Value;
        setappdata(fig, 'state', s);
        renderZFrame(s);
    end

    % =========================================================================
    function cb_rangeStart()
        s = getappdata(fig, 'state');
        if isempty(s.zSegments)
            uialert(fig, 'Turn on Auto threshold first.', 'No threshold yet');
            return;
        end
        s.zRangeStart = s.zCurrentFrame;
        setappdata(fig, 'state', s);
        postUpdate(sprintf(['Range start set at frame %d - step to the last ' ...
            'affected frame, set Auto/Manual as wanted, then click ' ...
            '"End range & apply".'], s.zCurrentFrame));
    end

    % =========================================================================
    function cb_rangeEnd()
        s = getappdata(fig, 'state');
        if isempty(s.zRangeStart)
            uialert(fig, 'Click "Start range" first.', 'No range started');
            return;
        end

        a = min(s.zRangeStart, s.zCurrentFrame);
        b = max(s.zRangeStart, s.zCurrentFrame);

        if chkManualThresh.Value
            val  = sldManualThresh.Value;
            mode = 'manual';
        else
            region = s.zWorkVol(a:b, :, :);
            val    = computeThreshold(s, region, currentMethodName());
            mode   = 'auto';
        end

        newSeg        = struct('startF', a, 'endF', b, 'mode', mode, 'value', val);
        s.zSegments   = insertSegment(s.zSegments, newSeg);
        s.zRangeStart = [];
        setappdata(fig, 'state', s);

        renderZFrame(s);
        refreshSegmentsTable(s);
        postUpdate(sprintf('Applied %s threshold (%.4g) to frames %d-%d.', mode, val, a, b));
    end

    % =========================================================================
    function cb_zAnalyze()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % MATLAB-native stand-in for the beanshell pipeline's Fiji step
        % (Skeletonize (2D/3D) + 3D Distance Map + AnalyzeSkeleton_):
        % bwskel/bwdist for the skeleton + distance transform, then a
        % simplified branch extraction (see extractBranches) since there's
        % no MATLAB equivalent of AnalyzeSkeleton_'s graph to call directly.
        s = getappdata(fig, 'state');
        if isempty(s.zRaw)
            uialert(fig, 'Load a z-stack first.', 'No data');  return;
        end
        if isempty(s.zSegments)
            uialert(fig, 'Turn on Auto threshold first.', 'No threshold');  return;
        end

        pxsz_um  = str2double(efPxsz.Value);
        zstep_um = str2double(efZstep.Value);
        if isnan(pxsz_um) || pxsz_um <= 0 || isnan(zstep_um) || zstep_um <= 0
            % Written by Kira Shaw with Claude Code, Aug 2026.
            % Vascular density is only meaningful in physical units, so it
            % can't proceed without both values. Pop up a small dialog to
            % enter them right here (pre-filled with whatever's already in
            % the Parameters panel) rather than just refusing and pointing
            % back at the fields - Cancel, or leaving either blank/invalid,
            % stops the analysis.
            answer = inputdlg( ...
                {'Pixel size (microns):', 'Z-step (microns):'}, ...
                'Missing calibration - enter to continue', [1 45], ...
                {efPxsz.Value, efZstep.Value});
            if isempty(answer)
                postUpdate('Process Stack cancelled - pixel size/z-step missing.');
                return;
            end
            pxsz_um  = str2double(answer{1});
            zstep_um = str2double(answer{2});
            if isnan(pxsz_um) || pxsz_um <= 0 || isnan(zstep_um) || zstep_um <= 0
                uialert(fig, ['Pixel size and z-step must both be positive ' ...
                    'numbers (in microns).'], 'Invalid calibration');
                return;
            end
            efPxsz.Value  = num2str(pxsz_um, '%.4g');
            efZstep.Value = num2str(zstep_um, '%.4g');
        end

        postUpdate('Building binarised volume...');  drawnow;
        BW = buildBinaryVolume(s);
        [nZ, nY, nX] = size(BW);
        origNZ = nZ;
        % Written by Kira Shaw with Claude Code, Aug 2026. Kept as-is
        % (straight thresholded, pre-resample/pre-smoothing) for the
        % boundary-restricted volume below - that measure works frame by
        % frame on the original acquisition, not the resampled/smoothed
        % grid BW itself is about to become.
        BW_origFrames = BW;

        % ---- resample z to isotropic voxels (matching the xy pixel size) so
        % the distance map / branch lengths aren't distorted by anisotropy -
        % skip it (with a note) if that would blow the array up too much.
        resampleFactor    = zstep_um / pxsz_um;
        newNZ             = max(1, round(nZ * resampleFactor));
        isotropicApplied  = false;
        if newNZ ~= nZ && (newNZ * nY * nX) <= 4 * numel(BW) && newNZ <= 2000
            postUpdate(sprintf('Resampling z (%d -> %d slices) for isotropic voxels...', nZ, newNZ));
            drawnow;
            BW = logical(imresize3(BW, [newNZ, nY, nX], 'nearest'));
            isotropicApplied = true;
        else
            postUpdate('Skipping z-resampling (stack too large) - using raw anisotropic voxel grid.');
        end

        if isotropicApplied
            voxSize = [pxsz_um, pxsz_um, pxsz_um];   % [z y x], microns
        else
            voxSize = [zstep_um, pxsz_um, pxsz_um];
        end

        % ---- boundary-restricted volume, a second density measure - now
        % opt-in (Written by Kira Shaw with Claude Code, Aug 2026; was
        % always-on) via the "Vessel boundary" tick under Slant-correct.
        % See computeBoundaryRestrictedVolume. Off: no computation done at
        % all (skips the per-frame convex-hull/boundary work entirely),
        % and every boundaryRestricted output is NaN/empty, same
        % convention as slant correction when it's off.
        boundaryRestrictApplied = chkBoundaryRestrict.Value;
        if boundaryRestrictApplied
            postUpdate('Computing boundary-restricted volume (2nd density measure)...');
            drawnow;
            [volume_boundaryRestricted_mm3, boundaryMaskOrig, boundaryCoords] = ...
                computeBoundaryRestrictedVolume(BW_origFrames, pxsz_um, zstep_um);
            if isotropicApplied
                boundaryMask = logical(imresize3(boundaryMaskOrig, [newNZ, nY, nX], 'nearest'));
            else
                boundaryMask = boundaryMaskOrig;
            end
        else
            volume_boundaryRestricted_mm3 = NaN;
            boundaryMask   = false(size(BW));
            boundaryCoords = cell(origNZ, 1);
        end

        % ---- smooth the binary mask in 3D (Written by Kira Shaw with
        % Claude Code, Aug 2026) - morphological close then open with a
        % spherical structuring element rounds out small surface bumps
        % that otherwise nudge bwskel's medial-axis path off-centre. Most
        % visible on large vessels: a "fat" tube doesn't have one
        % well-defined centreline the way a thin one does, so any
        % boundary noise (and there's proportionally more of it, the
        % bigger the vessel) tips the medial axis from one near-
        % equidistant voxel to another as you move along it, producing a
        % swirl instead of a straight line down the middle.
        % Radius is in physical microns (converted to voxels using the
        % current voxel size) rather than a fixed voxel count, so it
        % scales with calibration; strel('sphere',...) assumes isotropic
        % spacing, so when the grid is still anisotropic (resampling
        % skipped above) the smallest voxel dimension is used to stay
        % conservative rather than over-smoothing in the coarser direction.
        smoothMaskRadius_um = 2;
        smoothRadiusVox = max(1, round(smoothMaskRadius_um / min(voxSize)));
        postUpdate(sprintf('Smoothing binarised volume (morphological, radius %d vox)...', ...
            smoothRadiusVox));
        drawnow;
        se = strel('sphere', smoothRadiusVox);
        BW = imclose(BW, se);
        BW = imopen(BW, se);

        % Written by Kira Shaw with Claude Code, Aug 2026.
        % MinBranchLength (voxels, in the volume bwskel is run on - i.e.
        % post-resample if isotropic resampling applied above) prunes short
        % spurious spurs off the skeleton. 0/NaN/negative = no pruning.
        pruneVox = efPruneLen.Value;
        if isnan(pruneVox) || pruneVox < 0
            pruneVox = 0;
        end

        postUpdate(sprintf(['Skeletonising (bwskel, prune %.3g vox) - this can ' ...
            'take a while on a large stack...'], pruneVox));
        drawnow;
        skel = bwskel(BW, 'MinBranchLength', pruneVox);

        postUpdate('Computing 3D distance map (bwdist)...');
        drawnow;
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Two different distance transforms, for two different purposes -
        % bwdist(BW) is 0 everywhere INSIDE BW (a true voxel's nearest true
        % voxel is itself), so it's only meaningful in the background: how
        % far is this bit of tissue from the nearest vessel. bwdist(~BW) is
        % the opposite - 0 in the background, and inside BW it's the
        % distance to the nearest background voxel, i.e. the local vessel
        % radius, which is what's needed at skeleton (centreline) points
        % for diameter. Using bwdist(BW) for both (as this used to) made
        % every branch's diam_um exactly 0, since skeleton voxels are
        % always inside BW.
        distMap   = bwdist(BW)  * pxsz_um;   % tissue -> nearest vessel (background)
        radiusMap = bwdist(~BW) * pxsz_um;   % vessel interior -> nearest edge (radius)
        % both valid for either voxSize case, since bwdist itself assumes
        % isotropic voxels - which is exactly what the resampling above was for

        postUpdate('Extracting vessel branches...');
        drawnow;
        branches = extractBranches(skel, radiusMap, voxSize);

        % volume analysed: from the ORIGINAL (pre-resample) dimensions and
        % calibration, so resampling can't distort the reported tissue
        % volume. Optionally corrected for tissue slant (Written by Kira
        % Shaw with Claude Code, Aug 2026) - a stack imaged at a slight
        % angle to the tissue surface has some genuinely empty/black space
        % within this rectangular box at any given depth, which a plain
        % box overstates as tissue (see computeSlantCorrectedVolume).
        slantCorrected = chkSlantCorrect.Value;
        if slantCorrected
            postUpdate('Correcting tissue volume for slant (10 um z-bins)...');
            drawnow;
            [volume_mm3, tissueMaskOrig] = computeSlantCorrectedVolume(s.zRaw, pxsz_um, zstep_um);
            % Written by Kira Shaw with Claude Code, Aug 2026. tissueMaskOrig
            % is in zRaw's ORIGINAL grid (pre-resample); resample it exactly
            % as BW was, so the two line up voxel-for-voxel below. Reuses
            % isotropicApplied/newNZ from the resampling step above rather
            % than recomputing them.
            if isotropicApplied
                tissueMask = logical(imresize3(tissueMaskOrig, [newNZ, nY, nX], 'nearest'));
            else
                tissueMask = tissueMaskOrig;
            end
        else
            volume_mm3 = (nY*pxsz_um) * (nX*pxsz_um) * (origNZ*zstep_um) / 1000^3;
        end

        if isempty(branches)
            totalLength_m = 0;
        else
            totalLength_m = sum([branches.length_um]) / 1e6;
        end
        density_mPerMm3 = totalLength_m / volume_mm3;
        % boundary-restricted density - same vessel length, second volume
        % (Written by Kira Shaw with Claude Code, Aug 2026)
        density_boundaryRestricted_mPerMm3 = totalLength_m / volume_boundaryRestricted_mm3;

        % Written by Kira Shaw with Claude Code, Aug 2026. Mean tortuosity
        % across branches (see extractBranches) - reported the same way as
        % density, one headline number for the whole stack.
        if isempty(branches)
            tortuosity_mean = NaN;
        else
            tortuosity_mean = mean([branches.tortuosity], 'omitnan');
        end

        % sample tissue-to-vessel distances for the histogram (background
        % voxels only - vessel interior reads 0 and isn't meaningful here);
        % subsample if huge, purely so the histogram computes quickly.
        % Restricted to the same tissue mask used for the volume when slant
        % correction is on (Written by Kira Shaw with Claude Code, Aug
        % 2026) - otherwise density used a corrected (smaller) tissue
        % volume while this still sampled "distance to nearest vessel" from
        % every background voxel in the full box, including the black/
        % non-tissue ones the correction had just excluded - inconsistent,
        % and would inflate/skew these percentiles in exactly the stacks
        % where the correction matters most.
        if slantCorrected
            tissueDist = distMap(~BW & tissueMask);
        else
            tissueDist = distMap(~BW);
        end
        if numel(tissueDist) > 2e6
            tissueDist = tissueDist(randperm(numel(tissueDist), 2e6));
        end

        % Written by Kira Shaw with Claude Code, Aug 2026. Same idea,
        % restricted to the boundary-restricted mask instead - a second,
        % independent distance-to-vessel sample using the OTHER volume
        % definition, for consistency with density_boundaryRestricted.
        tissueDist_boundaryRestricted = distMap(~BW & boundaryMask);
        if numel(tissueDist_boundaryRestricted) > 2e6
            tissueDist_boundaryRestricted = tissueDist_boundaryRestricted( ...
                randperm(numel(tissueDist_boundaryRestricted), 2e6));
        end

        % Written by Kira Shaw with Claude Code, Aug 2026.
        % A single mm^3/um^3 number is hard to sanity-check at a glance;
        % showing the actual H x W x Z extent in microns is what you'd
        % actually compare against the acquisition, so display that instead
        % (mm^3 is still computed above and used for the density figure,
        % and is still what gets exported in the data files). Stashed in
        % state so cb_zExportFig's sgtitle can match the live display.
        height_um = round(nY*pxsz_um);
        width_um  = round(nX*pxsz_um);
        depth_um  = round(origNZ*zstep_um);

        % Written by Kira Shaw with Claude Code, Aug 2026. 50th/95th
        % percentile tissue-to-vessel distance (cf. Nature Comms 2021
        % 10.1038/s41467-021-23508-y, fig 7) - a couple of headline numbers
        % alongside the full histogram already shown below.
        distP50_um = pctileLocal(tissueDist, 50);
        distP95_um = pctileLocal(tissueDist, 95);
        % boundary-restricted equivalents (Written by Kira Shaw with Claude
        % Code, Aug 2026) - second, independent measure; not shown in the
        % main results text/plots by default, but kept for export/writing
        % up (see the RHS of the results box, though, for the headline
        % numbers - just visually distinguished from the primary ones)
        distP50_boundaryRestricted_um = pctileLocal(tissueDist_boundaryRestricted, 50);
        distP95_boundaryRestricted_um = pctileLocal(tissueDist_boundaryRestricted, 95);

        s.zBranches        = branches;
        s.zVolume_mm3       = volume_mm3;
        s.zVolumeHWZ_um     = [height_um, width_um, depth_um];
        s.zDensity_mPerMm3  = density_mPerMm3;
        s.zTortuosity_mean  = tortuosity_mean;
        s.zSlantCorrected   = slantCorrected;
        s.zDistVals_um      = tissueDist;
        s.zDistP50_um       = distP50_um;
        s.zDistP95_um       = distP95_um;
        s.zVolume_boundaryRestricted_mm3   = volume_boundaryRestricted_mm3;
        s.zDensity_boundaryRestricted_mPerMm3 = density_boundaryRestricted_mPerMm3;
        s.zDistVals_boundaryRestricted_um  = tissueDist_boundaryRestricted;
        s.zDistP50_boundaryRestricted_um   = distP50_boundaryRestricted_um;
        s.zDistP95_boundaryRestricted_um   = distP95_boundaryRestricted_um;
        s.zBoundaryRestrictApplied = boundaryRestrictApplied;  % whether this run computed it
        s.zBoundaryCoords   = boundaryCoords;  % per-frame outline, original grid - for export/overlay
        s.zBoundaryMaskVol  = boundaryMask;  % cached for the export figure's boundary overlay
        s.zSkelVol          = skel;      % cached for the "stacked slices" export view
        s.zDistMapVol       = distMap;
        s.zAnalysisRun      = true;
        setappdata(fig, 'state', s);

        % ---- display ---------------------------------------------------------
        % Written by Kira Shaw with Claude Code, Aug 2026. Both sides of
        % the results box now follow the exact same 4-line, always-labelled
        % structure, so LHS and RHS read as one standardised box rather
        % than two differently-formatted ones: (1) a title naming which
        % volume definition this side is, (2) density + tortuosity (shown
        % on both sides - tortuosity itself doesn't depend on which volume
        % definition is used, it's the same skeleton either way), (3) the
        % total volume that density was computed over, (4) tissue-to-
        % vessel distance percentiles. Slant-correction is flagged on the
        % density line since it's the one number that tag actually
        % qualifies.
        if slantCorrected
            densityLine = sprintf('Density: %.3g m/mm^3 (slant-corrected)   |   Tortuosity: %.3g', ...
                density_mPerMm3, tortuosity_mean);
        else
            densityLine = sprintf('Density: %.3g m/mm^3   |   Tortuosity: %.3g', ...
                density_mPerMm3, tortuosity_mean);
        end
        lblDensity.Text = { ...
            'Full tissue:', ...
            densityLine, ...
            sprintf('Total volume: %.4g mm^3', volume_mm3), ...
            sprintf('Distance to nearest vessel: 50th pct %.3g um   |   95th pct %.3g um', ...
                distP50_um, distP95_um)};

        % Boundary-restricted, RHS of the same box (Written by Kira Shaw
        % with Claude Code, Aug 2026) - opt-in (the "Vessel boundary" tick
        % under Slant-correct:); when it wasn't ticked for this run, say so
        % plainly rather than showing NaN-filled numbers, but keep the same
        % title line either way.
        if boundaryRestrictApplied
            lblDensityBoundary.Text = { ...
                'Boundary restricted:', ...
                sprintf('Density: %.3g m/mm^3   |   Tortuosity: %.3g', ...
                    density_boundaryRestricted_mPerMm3, tortuosity_mean), ...
                sprintf('Total volume: %.4g mm^3', volume_boundaryRestricted_mm3), ...
                sprintf('Distance to nearest vessel: 50th pct %.3g um   |   95th pct %.3g um', ...
                    distP50_boundaryRestricted_um, distP95_boundaryRestricted_um)};
        else
            lblDensityBoundary.Text = { ...
                'Boundary restricted:', ...
                'Not computed ("Vessel boundary" not ticked', ...
                'for this run)', ''};
        end

        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Max-projection across the whole stack, not a single slice - a
        % vessel network is rarely evenly spread through every z-slice, so
        % "frame 1" specifically could easily land somewhere sparse/empty
        % and look like the skeleton failed even when it didn't. Projecting
        % is a more reliable sanity check regardless of where the actual
        % vasculature sits.
        skelProj = squeeze(any(skel, 1));
        distProj = squeeze(max(distMap, [], 1));

        cla(axSkel);
        imagesc(axSkel, skelProj);
        colormap(axSkel, [1 1 1; 0 0 0]);
        axis(axSkel, 'image');  axSkel.XTick = [];  axSkel.YTick = [];
        title(axSkel, 'Skeleton  (max projection)');

        cla(axDist);
        imagesc(axDist, distProj);
        colormap(axDist, 'parula');
        axis(axDist, 'image');  axDist.XTick = [];  axDist.YTick = [];
        cbD = colorbar(axDist);  ylabel(cbD, 'um');
        cbD.Direction = 'reverse';  % 0 (near a vessel) at the top, not the bottom
        title(axDist, 'Distance to nearest vessel  (max projection, um)');

        % ---- diameter, length & tortuosity by depth, as scatter plots,
        % each titled with n (full mean/SD/range in the exported figure) --
        cla(axDiamDepth);
        cla(axLengthDepth);
        cla(axTortDepth);
        if ~isempty(branches)
            diamVals   = [branches.diam_um];
            lengthVals = [branches.length_um];
            depthVals  = [branches.depth_um];
            tortVals   = [branches.tortuosity];

            % short n-only subtitle here (was mean/SD/range) - the full
            % stats line is more useful in the exported figure, where
            % there's room for it (Written by Kira Shaw with Claude Code,
            % Aug 2026; see cb_zExportFig)
            msk_cap = diamVals < 7;
            msk_int = diamVals >= 7 & diamVals < 12;
            msk_art = diamVals >= 12;
            hold(axDiamDepth, 'on');
            if any(msk_cap), scatter(axDiamDepth, depthVals(msk_cap), diamVals(msk_cap), 12, [0.15 0.65 0.25], 'filled', 'DisplayName', 'Capillaries (<7um)');       end
            if any(msk_int), scatter(axDiamDepth, depthVals(msk_int), diamVals(msk_int), 12, [0.92 0.48 0.65], 'filled', 'DisplayName', 'Intermediate (7-12um)');    end
            if any(msk_art), scatter(axDiamDepth, depthVals(msk_art), diamVals(msk_art), 12, [0.20 0.45 0.80], 'filled', 'DisplayName', 'Arterioles (>=12um)');      end
            hold(axDiamDepth, 'off');
            legend(axDiamDepth, 'Location', 'best', 'FontSize', 7);
            title(axDiamDepth, {'Diameter by depth', nLine(diamVals, 'nVess=')});

            scatter(axLengthDepth, depthVals, lengthVals, 10, [0.90 0.20 0.20], 'filled');
            title(axLengthDepth, {'Length by depth', nLine(lengthVals, 'nVess=')});

            % Written by Kira Shaw with Claude Code, Aug 2026. Per-branch
            % tortuosity (see extractBranches) - NaN for a degenerate
            % zero-chord branch, so scatter just skips plotting those.
            scatter(axTortDepth, depthVals, tortVals, 10, [0.55 0.30 0.75], 'filled');
            title(axTortDepth, {'Tortuosity by depth', nLine(tortVals, 'nVess=')});
        else
            title(axDiamDepth, 'Diameter by depth');
            title(axLengthDepth, 'Length by depth');
            title(axTortDepth, 'Tortuosity by depth');
        end
        xlabel(axDiamDepth, 'Depth (um)');    ylabel(axDiamDepth, 'Diameter (um)');
        xlabel(axLengthDepth, 'Depth (um)');  ylabel(axLengthDepth, 'Length (um)');
        xlabel(axTortDepth, 'Depth (um)');    ylabel(axTortDepth, 'Tortuosity');

        % ---- distance-to-nearest-vessel histogram, binned, as % of tissue --
        cla(axDistHist);
        nBins = 40;
        [counts, edges] = histcounts(tissueDist, nBins);
        pctVals   = 100 * counts / max(sum(counts), 1);
        binCtrs   = edges(1:end-1) + diff(edges)/2;
        bar(axDistHist, binCtrs, pctVals, 1, ...
            'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
        xlabel(axDistHist, 'Distance (um)');  ylabel(axDistHist, '% of tissue');
        title(axDistHist, {'Distance to nearest vessel', nLine(tissueDist, 'nVox=')});

        % results grid was blank until now (see resetDensityDisplay) -
        % reveal it now it's actually populated
        for h = zstackResultsH, h.Visible = 'on'; end

        btnExport.Enable    = 'on';
        btnExportFig.Enable = 'on';
        postUpdate(sprintf('Density calculated: %.3g m/mm^3 across %d branches.', ...
            density_mPerMm3, numel(branches)));
    end

    % =========================================================================
    function cb_zExport()
        % Written by Kira Shaw with Claude Code, Aug 2026.
        s = getappdata(fig, 'state');
        if ~s.zAnalysisRun
            postUpdate('User needs to extract data first');
            return;
        end

        choice = uiconfirm(fig, 'Choose export format:', 'Export', ...
            'Options',       {'MAT file', 'Excel (.xlsx)', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end

        pxsz_um  = str2double(efPxsz.Value);
        fps      = str2double(efFPS.Value);
        zstep_um = str2double(efZstep.Value);

        nVessels = numel(s.zBranches);
        if nVessels > 0
            length_um  = [s.zBranches.length_um]';
            diam_um    = [s.zBranches.diam_um]';
            depth_um   = [s.zBranches.depth_um]';
            tortuosity = [s.zBranches.tortuosity]';
        else
            length_um = zeros(0,1);  diam_um = zeros(0,1);  depth_um = zeros(0,1);
            tortuosity = zeros(0,1);
        end
        dist_um = s.zDistVals_um(:);
        dist_boundaryRestricted_um = s.zDistVals_boundaryRestricted_um(:);

        % ---- tissue-to-vessel distance percentiles, 5th-95th in 2.5% steps
        % (Written by Kira Shaw with Claude Code, Aug 2026; cf. Nature
        % Comms 2021 10.1038/s41467-021-23508-y, fig 7)
        pct_pct    = (5:2.5:95)';
        pct_um     = pctileLocal(dist_um, pct_pct);   % column, same shape as pct_pct
        pct_boundaryRestricted_um = pctileLocal(dist_boundaryRestricted_um, pct_pct);

        % ---- preprocessing/thresholding settings, for the paper's methods
        % section (Written by Kira Shaw with Claude Code, Aug 2026) - read
        % straight off the live controls, same values cb_zAnalyze itself used.
        thresholdMethod   = currentMethodName();
        smoothingOn       = chkSmooth.Value;
        smoothingSigma_px = efSmoothSigma.Value;
        pruneLength_vox   = efPruneLen.Value;

        if strcmp(choice, 'MAT file')
            % ---- everything in one .mat, grouped into structures ------------
            [fn, fp] = uiputfile('*.mat', 'Save MAT file', ...
                fullfile(s.expDir, 'MAPS_zstackresults.mat'));
            if isequal(fn,0), return; end

            results.summary.density_mPerMm3    = s.zDensity_mPerMm3;
            results.summary.tortuosity_mean    = s.zTortuosity_mean;
            results.summary.volumeSlantCorrected = s.zSlantCorrected;
            results.summary.volume_mm3      = s.zVolume_mm3;
            results.summary.volume_um3      = s.zVolume_mm3 * 1000^3;
            results.summary.pxsz_um         = pxsz_um;
            results.summary.fps             = fps;
            results.summary.zStep_um        = zstep_um;
            results.summary.distP50_um      = s.zDistP50_um;
            results.summary.distP95_um      = s.zDistP95_um;

            % boundaryRestricted: 2nd density measure, per-frame convex
            % hull of the vessel mask rather than a bounding box or
            % raw-intensity black test (Written by Kira Shaw with Claude
            % Code, Aug 2026) - not shown in the plots, kept here for
            % writing up/exploring alongside the primary numbers.
            results.summary.boundaryRestrictApplied            = s.zBoundaryRestrictApplied;
            results.summary.density_boundaryRestricted_mPerMm3 = s.zDensity_boundaryRestricted_mPerMm3;
            results.summary.volume_boundaryRestricted_mm3      = s.zVolume_boundaryRestricted_mm3;
            results.summary.distP50_boundaryRestricted_um      = s.zDistP50_boundaryRestricted_um;
            results.summary.distP95_boundaryRestricted_um      = s.zDistP95_boundaryRestricted_um;

            % per-frame boundary outline coordinates, original (unresampled)
            % pixel grid - one [x y] array per frame, empty where that
            % frame had no vessel signal to draw a hull around. Only
            % meaningful when boundaryRestrictApplied is true (Written by
            % Kira Shaw with Claude Code, Aug 2026).
            results.boundaryRestricted.applied = s.zBoundaryRestrictApplied;
            results.boundaryRestricted.coords  = s.zBoundaryCoords;

            results.vessels.vesselID   = (1:nVessels)';
            results.vessels.length_um  = length_um;
            results.vessels.diam_um    = diam_um;
            results.vessels.depth_um   = depth_um;
            results.vessels.tortuosity = tortuosity;

            results.distanceToVessel.dist_um       = dist_um;
            results.distanceToVessel.percentile_pct = pct_pct;
            results.distanceToVessel.percentile_um  = pct_um;
            results.distanceToVessel.boundaryRestricted_dist_um       = dist_boundaryRestricted_um;
            results.distanceToVessel.boundaryRestricted_percentile_um = pct_boundaryRestricted_um;

            results.segments = s.zSegments;

            % preprocessing/thresholding settings, for methods write-up
            results.processing.thresholdMethod   = thresholdMethod;
            results.processing.smoothingOn       = smoothingOn;
            results.processing.smoothingSigma_px = smoothingSigma_px;
            results.processing.pruneLength_vox   = pruneLength_vox;

            save(fullfile(fp,fn), 'results', '-v7.3');
            postUpdate(['Saved: ' fullfile(fp,fn)]);

        else
            % ---- Excel: one file per category, as requested -----------------
            [fn, fp] = uiputfile('*.xlsx', 'Save Excel files (base name)', ...
                fullfile(s.expDir, 'MAPS_zstackresults.xlsx'));
            if isequal(fn,0), return; end
            [~, baseName, ext] = fileparts(fn);

            summaryFn = fullfile(fp, sprintf('%s_summary%s', baseName, ext));
            Tsum = table(s.zDensity_mPerMm3, s.zTortuosity_mean, s.zSlantCorrected, ...
                s.zVolume_mm3, s.zVolume_mm3*1000^3, pxsz_um, fps, zstep_um, ...
                s.zDistP50_um, s.zDistP95_um, ...
                s.zBoundaryRestrictApplied, ...
                s.zDensity_boundaryRestricted_mPerMm3, s.zVolume_boundaryRestricted_mm3, ...
                s.zDistP50_boundaryRestricted_um, s.zDistP95_boundaryRestricted_um, ...
                'VariableNames', ...
                {'Density_mPerMm3', 'Tortuosity_mean', 'VolumeSlantCorrected', ...
                 'Volume_mm3', 'Volume_um3', ...
                 'PixelSize_um', 'FrameRate_Hz', 'ZStep_um', ...
                 'DistanceToVessel_P50_um', 'DistanceToVessel_P95_um', ...
                 'BoundaryRestrictApplied', ...
                 'Density_boundaryRestricted_mPerMm3', 'Volume_boundaryRestricted_mm3', ...
                 'DistanceToVessel_boundaryRestricted_P50_um', ...
                 'DistanceToVessel_boundaryRestricted_P95_um'});
            if isfile(summaryFn), delete(summaryFn); end
            writetable(Tsum, summaryFn);

            vesselsFn = fullfile(fp, sprintf('%s_vessels%s', baseName, ext));
            Tves = table((1:nVessels)', length_um, diam_um, depth_um, tortuosity, ...
                'VariableNames', {'VesselID', 'Length_um', 'Diameter_um', 'Depth_um', ...
                'Tortuosity'});
            if isfile(vesselsFn), delete(vesselsFn); end
            writetable(Tves, vesselsFn);

            distFn = fullfile(fp, sprintf('%s_distanceToVessel%s', baseName, ext));
            % Written by Kira Shaw with Claude Code, Aug 2026. dist_um can
            % have up to 2,000,000 rows (see the subsample cap where
            % zDistVals_um is built) - fine for the .mat export and for
            % computing the histogram/percentiles, but an Excel sheet can
            % only hold 1,048,576 rows including the header, so writing it
            % straight through was erroring out ("exceeds the sheet
            % boundaries"). Excel isn't really the place for a raw list
            % this long anyway (that's what the .mat export and the
            % _distancePercentiles file are for) - subsample further,
            % safely under the sheet limit, purely for a spot-check/
            % distribution overview in Excel.
            excelDistCap = 500000;
            dist_um_excel = dist_um;
            if numel(dist_um_excel) > excelDistCap
                dist_um_excel = dist_um_excel(randperm(numel(dist_um_excel), excelDistCap));
            end
            Tdist = table(dist_um_excel, 'VariableNames', {'Distance_um'});
            if isfile(distFn), delete(distFn); end
            writetable(Tdist, distFn);

            % boundaryRestricted raw distances, same Excel row cap as above
            % (Written by Kira Shaw with Claude Code, Aug 2026)
            distBoundaryFn = fullfile(fp, sprintf('%s_distanceToVessel_boundaryRestricted%s', baseName, ext));
            dist_boundaryRestricted_excel = dist_boundaryRestricted_um;
            if numel(dist_boundaryRestricted_excel) > excelDistCap
                dist_boundaryRestricted_excel = dist_boundaryRestricted_excel( ...
                    randperm(numel(dist_boundaryRestricted_excel), excelDistCap));
            end
            TdistBoundary = table(dist_boundaryRestricted_excel, 'VariableNames', {'Distance_um'});
            if isfile(distBoundaryFn), delete(distBoundaryFn); end
            writetable(TdistBoundary, distBoundaryFn);

            % ---- distance-to-vessel percentiles, 5th-95th in 2.5% steps,
            % both volume definitions side by side (Written by Kira Shaw
            % with Claude Code, Aug 2026; cf. Nature Comms 2021
            % 10.1038/s41467-021-23508-y, fig 7)
            distPctFn = fullfile(fp, sprintf('%s_distancePercentiles%s', baseName, ext));
            Tpct = table(pct_pct, pct_um, pct_boundaryRestricted_um, 'VariableNames', ...
                {'Percentile', 'Distance_um', 'Distance_boundaryRestricted_um'});
            if isfile(distPctFn), delete(distPctFn); end
            writetable(Tpct, distPctFn);

            % ---- thresholding/preprocessing settings (Written by Kira Shaw
            % with Claude Code, Aug 2026) - the per-frame-range segments
            % table plus the smoothing/pruning settings, for the paper's
            % methods section. General settings are repeated on every row
            % so the whole thing stays one flat, self-contained sheet.
            settingsFn = fullfile(fp, sprintf('%s_thresholdSettings%s', baseName, ext));
            nSeg = numel(s.zSegments);
            if nSeg > 0
                segStart = [s.zSegments.startF]';
                segEnd   = [s.zSegments.endF]';
                segMode  = {s.zSegments.mode}';
                segVal   = [s.zSegments.value]';
            else
                segStart = zeros(0,1);  segEnd  = zeros(0,1);
                segMode  = cell(0,1);   segVal  = zeros(0,1);
            end
            Tset = table(segStart, segEnd, segMode, segVal, ...
                repmat({thresholdMethod}, nSeg, 1), repmat(smoothingOn, nSeg, 1), ...
                repmat(smoothingSigma_px, nSeg, 1), repmat(pruneLength_vox, nSeg, 1), ...
                'VariableNames', {'SegmentStartFrame', 'SegmentEndFrame', ...
                'SegmentMode', 'SegmentThresholdValue', 'ThresholdMethod', ...
                'SmoothingOn', 'SmoothingSigma_px', 'PruneLength_vox'});
            if isfile(settingsFn), delete(settingsFn); end
            writetable(Tset, settingsFn);

            % ---- boundary-restricted per-frame outline coordinates, only
            % written when that measure was actually computed this run
            % (Written by Kira Shaw with Claude Code, Aug 2026) - long
            % format, one row per boundary point per frame, on the
            % original (unresampled) pixel grid.
            if s.zBoundaryRestrictApplied
                boundaryCoordFn = fullfile(fp, sprintf('%s_boundaryCoordinates%s', baseName, ext));
                frameCol = zeros(0,1); xCol = zeros(0,1); yCol = zeros(0,1);
                for fIdx = 1:numel(s.zBoundaryCoords)
                    xy = s.zBoundaryCoords{fIdx};
                    if isempty(xy), continue; end
                    frameCol = [frameCol; repmat(fIdx, size(xy,1), 1)]; %#ok<AGROW>
                    xCol     = [xCol; xy(:,1)]; %#ok<AGROW>
                    yCol     = [yCol; xy(:,2)]; %#ok<AGROW>
                end
                Tbound = table(frameCol, xCol, yCol, ...
                    'VariableNames', {'Frame', 'X_px', 'Y_px'});
                if isfile(boundaryCoordFn), delete(boundaryCoordFn); end
                writetable(Tbound, boundaryCoordFn);

                postUpdate(sprintf('Saved 7 files: %s, %s, %s, %s, %s, %s, %s', ...
                    summaryFn, vesselsFn, distFn, distBoundaryFn, distPctFn, ...
                    settingsFn, boundaryCoordFn));
            else
                postUpdate(sprintf('Saved 6 files: %s, %s, %s, %s, %s, %s', ...
                    summaryFn, vesselsFn, distFn, distBoundaryFn, distPctFn, settingsFn));
            end
        end
    end

    % =========================================================================
    function cb_zExportFig()
        s = getappdata(fig, 'state');
        if ~s.zAnalysisRun
            postUpdate('User needs to extract data first');
            return;
        end

        % Written by Kira Shaw with Claude Code, Aug 2026. Two different
        % tissue-volume definitions now exist (the usual bounding-box
        % based one, and the boundary-restricted per-frame convex-hull
        % one) - ask which this figure's headline numbers (and the
        % skeleton/distance-map boundary overlay, if boundary-restricted)
        % should reflect, rather than picking one silently. Boundary
        % restriction is now opt-in (the "Vessel boundary" tick under
        % Slant-correct:), so only offer it here if that measure was
        % actually computed on the run these results came from - otherwise
        % there's nothing to show and it would just be NaNs.
        if s.zBoundaryRestrictApplied
            volChoice = uiconfirm(fig, ...
                'Which tissue volume definition should this figure use?', ...
                'Export figure', ...
                'Options',       {'Full tissue', 'Boundary-restricted', 'Cancel'}, ...
                'DefaultOption', 1, 'CancelOption', 3);
            if strcmp(volChoice, 'Cancel'), return; end
            useBoundary = strcmp(volChoice, 'Boundary-restricted');
        else
            volChoice   = 'Full tissue';
            useBoundary = false;
        end

        expFig = figure('Name', 'MAPS — Vascular Density Export', 'Color', 'w', ...
            'Position', [60 40 1400 900]);

        % ---- recompute full stats independently of the live GUI's axes -----
        % Written by Kira Shaw with Claude Code, Aug 2026. The live titles
        % now show n only (less crowded there); this figure gets the full
        % mean/SD/range line, so it's built here from the underlying data
        % rather than copied from the (now-shortened) live title strings.
        if ~isempty(s.zBranches)
            diamVals   = [s.zBranches.diam_um];
            lengthVals = [s.zBranches.length_um];
            depthVals  = [s.zBranches.depth_um];
            tortVals   = [s.zBranches.tortuosity];
        else
            diamVals = []; lengthVals = []; depthVals = []; tortVals = [];
        end
        % Written by Kira Shaw with Claude Code, Aug 2026. Everything
        % volume/distance-dependent below is pulled from whichever
        % definition was chosen above.
        if useBoundary
            tissueDist   = s.zDistVals_boundaryRestricted_um;
            densityVal   = s.zDensity_boundaryRestricted_mPerMm3;
            volumeVal    = s.zVolume_boundaryRestricted_mm3;
            distP50Val   = s.zDistP50_boundaryRestricted_um;
            distP95Val   = s.zDistP95_boundaryRestricted_um;
        else
            tissueDist   = s.zDistVals_um;
            densityVal   = s.zDensity_mPerMm3;
            volumeVal    = s.zVolume_mm3;
            distP50Val   = s.zDistP50_um;
            distP95Val   = s.zDistP95_um;
        end

        % ---- manual 2-row grid: 3 columns on top, 4 on bottom (Written by
        % Kira Shaw with Claude Code, Aug 2026 - rejigged from subplot(2,3)
        % to fit tortuosity-by-depth in alongside the other 3 bottom
        % plots). Plain normalized-figure-unit positions rather than
        % subplot(), since subplot doesn't support a different column
        % count per row.
        figL = 0.045;  figR = 0.985;  figTop = 0.87;  figBot = 0.07;
        rowGap = 0.10;
        rowH   = (figTop - figBot - rowGap) / 2;
        row1Y  = figBot + rowH + rowGap;
        row2Y  = figBot;
        colGap3 = 0.035;  col3W = (figR - figL - 2*colGap3) / 3;
        colGap4 = 0.030;  col4W = (figR - figL - 3*colGap4) / 4;
        pos1 = @(c) [figL + (c-1)*(col3W+colGap3), row1Y, col3W, rowH];
        pos2 = @(c) [figL + (c-1)*(col4W+colGap4), row2Y, col4W, rowH];

        % ---- top row: skeleton, distance map (~10 layered, angled example
        % slices - rather than a single frame, as shown live), and
        % thresholding/preprocessing settings (moved here from the bottom
        % row - Written by Kira Shaw with Claude Code, Aug 2026) ------------
        ax1 = axes('Parent', expFig, 'Position', pos1(1));
        idx1 = plotStackedSlices(ax1, s.zSkelVol, [1 1 1; 0 0 0]);
        title(ax1, 'Skeleton  (every slice)');
        % Flatter/more from-above than the default angled view (Written by
        % Kira Shaw with Claude Code, Aug 2026) - the shallowest slices are
        % where pial vessels sit, and a more top-down angle on this plot
        % shows that surface layer more clearly than the standard oblique
        % angle does.
        view(ax1, -37.5, 50);

        ax2 = axes('Parent', expFig, 'Position', pos1(2));
        idx2 = plotStackedSlices(ax2, s.zDistMapVol, parula(256));
        title(ax2, 'Distance to nearest vessel  (10 example slices, um)');
        cbD2 = colorbar(ax2);  ylabel(cbD2, 'Distance to vessel (um)');
        cbD2.Direction = 'reverse';  % 0 (near a vessel) at the top, matching axSkel/ax1's depth axis

        % ---- boundary-restricted outline overlay (Written by Kira Shaw
        % with Claude Code, Aug 2026) - only drawn when that's the chosen
        % definition, on both stacks, at the same slices each was already
        % drawn at, so it visibly shows what "boundary-restricted" is
        % actually restricting to.
        if useBoundary && ~isempty(s.zBoundaryMaskVol)
            overlayBoundary(ax1, s.zBoundaryMaskVol, idx1);
            overlayBoundary(ax2, s.zBoundaryMaskVol, idx2);
        end

        % ---- shared z-depth reference (Written by Kira Shaw with Claude
        % Code, Aug 2026) - a real depth (um) axis on the skeleton plot's
        % Z axis. It sits right between the two 3D plots (ax1 is to ax2's
        % left), so both can be read against this one reference rather
        % than duplicating it on both - and it's what makes the different
        % slice sampling obvious: the skeleton's ticks land far closer
        % together for the same physical depth than the distance map's,
        % since it's plotting every slice against every 10th.
        nZskel   = size(s.zSkelVol, 1);
        depth_um = s.zVolumeHWZ_um(3);
        nTicksZ  = min(6, nZskel);
        zTickIdx = round(linspace(1, nZskel, nTicksZ));
        if nZskel > 1
            zTickDepth = (zTickIdx - 1) / (nZskel - 1) * depth_um;
        else
            zTickDepth = 0;
        end
        ax1.ZTick      = zTickIdx;
        ax1.ZTickLabel = arrayfun(@(v) sprintf('%.0f', v), zTickDepth, 'UniformOutput', false);
        zlabel(ax1, 'Depth (um)');

        % thresholding/preprocessing settings, as plain text - so the
        % methods this figure came from are documented alongside it, in
        % case they're needed when writing the paper up.
        ax3 = axes('Parent', expFig, 'Position', pos1(3));
        axis(ax3, 'off');
        title(ax3, 'Thresholding settings');
        segLines = cell(numel(s.zSegments), 1);
        for i = 1:numel(s.zSegments)
            seg = s.zSegments(i);
            segLines{i} = sprintf('Frames %d-%d: %s = %.4g', ...
                seg.startF, seg.endF, seg.mode, seg.value);
        end
        if chkSmooth.Value
            smoothLine = sprintf('Smoothing: on (Gaussian sigma %.3g px)', efSmoothSigma.Value);
        else
            smoothLine = 'Smoothing: off';
        end
        settingsTxt = [{sprintf('Threshold method: %s', currentMethodName())}; ...
            segLines; ...
            {smoothLine}; ...
            {sprintf('Skeleton pruning: MinBranchLength = %.4g vox', efPruneLen.Value)}; ...
            {sprintf('Pixel size: %.4g um   Z-step: %.4g um', ...
                str2double(efPxsz.Value), str2double(efZstep.Value))}];
        text(ax3, 0, 1, settingsTxt, 'Units', 'normalized', ...
            'VerticalAlignment', 'top', 'FontSize', 10, 'Interpreter', 'none');

        % ---- bottom row: diameter-by-depth, length-by-depth, distance
        % histogram, tortuosity-by-depth (Written by Kira Shaw with Claude
        % Code, Aug 2026) ----------------------------------------------------
        ax4 = axes('Parent', expFig, 'Position', pos2(1));
        msk_cap = diamVals < 7;
        msk_int = diamVals >= 7 & diamVals < 12;
        msk_art = diamVals >= 12;
        hold(ax4, 'on');
        if any(msk_cap), scatter(ax4, depthVals(msk_cap), diamVals(msk_cap), 12, [0.15 0.65 0.25], 'filled', 'DisplayName', 'Capillaries (<7um)');       end
        if any(msk_int), scatter(ax4, depthVals(msk_int), diamVals(msk_int), 12, [0.92 0.48 0.65], 'filled', 'DisplayName', 'Intermediate (7-12um)');    end
        if any(msk_art), scatter(ax4, depthVals(msk_art), diamVals(msk_art), 12, [0.20 0.45 0.80], 'filled', 'DisplayName', 'Arterioles (>=12um)');      end
        hold(ax4, 'off');
        legend(ax4, 'Location', 'best', 'FontSize', 8);
        xlabel(ax4, 'Depth (um)');  ylabel(ax4, 'Diameter (um)');
        title(ax4, {'Diameter by depth', statsLine(diamVals, 'um', 'nVess=')});
        grid(ax4, 'on');

        ax5 = axes('Parent', expFig, 'Position', pos2(2));
        scatter(ax5, depthVals, lengthVals, 10, [0.90 0.20 0.20], 'filled');
        xlabel(ax5, 'Depth (um)');  ylabel(ax5, 'Length (um)');
        title(ax5, {'Length by depth', statsLine(lengthVals, 'um', 'nVess=')});
        grid(ax5, 'on');

        % tortuosity by depth (Written by Kira Shaw with Claude Code, Aug
        % 2026 - swapped with the histogram below, so this sits at slot 3)
        ax6 = axes('Parent', expFig, 'Position', pos2(3));
        scatter(ax6, depthVals, tortVals, 10, [0.55 0.30 0.75], 'filled');
        xlabel(ax6, 'Depth (um)');  ylabel(ax6, 'Tortuosity');
        title(ax6, {'Tortuosity by depth', statsLine(tortVals, '', 'nVess=')});
        grid(ax6, 'on');

        ax7 = axes('Parent', expFig, 'Position', pos2(4));
        nBins = 40;
        [counts, edges] = histcounts(tissueDist, nBins);
        pctVals = 100 * counts / max(sum(counts), 1);
        binCtrs = edges(1:end-1) + diff(edges)/2;
        bar(ax7, binCtrs, pctVals, 1, 'FaceColor', [0.20 0.45 0.75], 'EdgeColor', 'none');
        xlabel(ax7, 'Distance (um)');  ylabel(ax7, '% of tissue');
        title(ax7, {'Distance to nearest vessel', statsLine(tissueDist, 'um', 'nVox=')});
        % 50th/95th percentile markers (Written by Kira Shaw with Claude
        % Code, Aug 2026) - dotted lines at the values already shown in the
        % results box/sgtitle, so the histogram shows where they fall.
        hold(ax7, 'on');
        xline(ax7, distP50Val, ':', sprintf('50th pct: %.3g um', distP50Val), ...
            'Color', [0.10 0.35 0.10], 'LineWidth', 1.3, ...
            'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'left');
        xline(ax7, distP95Val, ':', sprintf('95th pct: %.3g um', distP95Val), ...
            'Color', [0.55 0.10 0.10], 'LineWidth', 1.3, ...
            'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'left');
        hold(ax7, 'off');

        % four lines (was three) - Written by Kira Shaw with Claude Code,
        % Aug 2026 - so it doesn't run into the row of subplot titles
        % directly beneath it, and matches the live results box (density,
        % tortuosity, volume, distance percentiles). Reflects whichever
        % volume definition was chosen at the start of this function - see
        % useBoundary.
        % Written by Kira Shaw with Claude Code, Aug 2026. "Total volume"
        % leads every branch now, matching the live results box wording -
        % the H x W x Z bounding-box breakdown stays here only (there's
        % room for it in the export figure title), for the two cases where
        % it actually applies; boundary-restricted has no such box (it's a
        % per-frame convex hull, not a single bounding box) so it's just
        % the number.
        if useBoundary
            densityTitle = sprintf('Density: %.3g m/mm^3 (boundary-restricted)   |   Mean tortuosity: %.3g', ...
                densityVal, s.zTortuosity_mean);
            volumeTitle = sprintf('Total volume: %.4g mm^3 (boundary-restricted tissue)', volumeVal);
        elseif s.zSlantCorrected
            densityTitle = sprintf('Density: %.3g m/mm^3 (slant-corrected)   |   Mean tortuosity: %.3g', ...
                densityVal, s.zTortuosity_mean);
            volumeTitle = sprintf(['Total volume: %.4g mm^3 (%d um (H) x %d um (W) x %d um (Z) ' ...
                'box, tissue-slant corrected)'], ...
                volumeVal, s.zVolumeHWZ_um(1), s.zVolumeHWZ_um(2), s.zVolumeHWZ_um(3));
        else
            densityTitle = sprintf('Density: %.3g m/mm^3   |   Mean tortuosity: %.3g', ...
                densityVal, s.zTortuosity_mean);
            volumeTitle = sprintf('Total volume: %.4g mm^3 (%d um (H) x %d um (W) x %d um (Z) box)', ...
                volumeVal, s.zVolumeHWZ_um(1), s.zVolumeHWZ_um(2), s.zVolumeHWZ_um(3));
        end
        sgtitle(expFig, { ...
            densityTitle, ...
            volumeTitle, ...
            sprintf('Distance to nearest vessel: 50th pct %.3g um   |   95th pct %.3g um', ...
                distP50Val, distP95Val)});

        % Written by Kira Shaw with Claude Code, Aug 2026. Flag which
        % volume definition this figure used right in the default
        % filename, so saving both a full-tissue and a boundary-restricted
        % figure for the same stack doesn't overwrite one with the other.
        if useBoundary
            defaultName = 'VascDensity_figure_boundaryRestricted';
        else
            defaultName = 'VascDensity_figure';
        end
        [fn, fp] = uiputfile( ...
            {'*.png','PNG image'; '*.pdf','PDF'; '*.fig','MATLAB figure'}, ...
            'Save figure', fullfile(s.expDir, defaultName));
        if ~isequal(fn, 0)
            saveas(expFig, fullfile(fp, fn));
            postUpdate(['Figure saved: ' fullfile(fp, fn)]);
        end
    end

    % =========================================================================
    function idx = plotStackedSlices(ax, vol, cmap)
        % Render layered, angled slices of vol at their true depth - a
        % pseudo-3D "light-sheet" view for the export figure (the live GUI
        % just shows frame 1, to keep things responsive while stepping
        % through the stack).
        nZ = size(vol, 1);

        % Written by Kira Shaw with Claude Code, Aug 2026. A sparse binary
        % volume (the skeleton) is >99% background; a flat FaceAlpha
        % stacks near-opaque background sheets that wash out to solid
        % white well before the front layer, hiding every slice's skeleton
        % points except the very last one drawn. Making alpha follow the
        % data itself (0 = fully transparent background, 1 = opaque
        % skeleton point) instead of a fixed value fixes that - a
        % continuous map like the distance transform doesn't have this
        % problem (no large flat region to wash out), so it keeps the
        % uniform alpha it already looked fine with.
        %
        % Slice sampling also differs by kind (Kira's call, Aug 2026): ~10
        % evenly-spaced slices reads fine for the distance map, but the
        % skeleton is sparse enough that even every 2nd slice wasn't
        % enough to make out - now every single slice.
        isBinary = islogical(vol);
        if isBinary
            idx = 1:nZ;
        else
            idx = unique(round(linspace(1, nZ, min(10, nZ))));
        end

        [Xg, Yg] = meshgrid(1:size(vol,3), 1:size(vol,2));
        hold(ax, 'on');
        for k = 1:numel(idx)
            zIdx  = idx(k);
            sliceImg = double(squeeze(vol(zIdx,:,:)));
            Zg = zIdx * ones(size(Xg));
            if isBinary
                surface(ax, Xg, Yg, Zg, sliceImg, ...
                    'EdgeColor', 'none', 'FaceColor', 'texturemap', ...
                    'FaceAlpha', 'texturemap', 'AlphaData', sliceImg, ...
                    'AlphaDataMapping', 'none');
            else
                surface(ax, Xg, Yg, Zg, sliceImg, ...
                    'EdgeColor', 'none', 'FaceColor', 'texturemap', 'FaceAlpha', 0.92);
            end
        end
        hold(ax, 'off');
        colormap(ax, cmap);
        set(ax, 'YDir', 'reverse');   % match image (row 1 = top) orientation
        % Written by Kira Shaw with Claude Code, Aug 2026 - Z increases
        % upward by default, which put frame 1 (0 depth/shallowest) at the
        % BOTTOM and the deepest slice at the top: upside down relative to
        % how a stack actually sits. Reversed so 0 depth reads at the top.
        set(ax, 'ZDir', 'reverse');
        view(ax, -37.5, 30);
        axis(ax, 'tight');
        ax.XTick = [];  ax.YTick = [];  ax.ZTick = [];
        box(ax, 'off');
    end

    % =========================================================================
    function overlayBoundary(ax, boundaryMaskVol, idx)
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Draws the boundary-restricted mask's per-frame outline (its
        % convex hull - see computeBoundaryRestrictedVolume) as a 3D line
        % at each slice plotStackedSlices already drew, on top of it, so
        % it's visible which region is actually being restricted to.
        % Dotted + semi-transparent (4th "alpha" element of Color, an
        % undocumented-but-supported Line property) yellow, matching
        % lblDensityBoundary's BOUNDARY_YELLOW results-box colour.
        hold(ax, 'on');
        for k = 1:numel(idx)
            z = idx(k);
            slice = squeeze(boundaryMaskVol(z,:,:));
            if any(slice(:))
                B = bwboundaries(slice);
                for bIdx = 1:numel(B)
                    outline = B{bIdx};   % [row col] = [y x]
                    plot3(ax, outline(:,2), outline(:,1), z*ones(size(outline,1),1), ...
                        'Color', [0.80 0.65 0.00 0.65], 'LineStyle', ':', 'LineWidth', 1.5);
                end
            end
        end
        hold(ax, 'off');
    end

    % =========================================================================
    function cb_generateSkeleton()
        s = getappdata(fig, 'state');
        if isempty(s.rawVess)
            uialert(fig, 'Load data first.', 'No data');  return;
        end

        nB = round(efNBranch.Value);
        newSkels = cell(nB, 1);

        % show vessel frame in greyscale so skeleton overlay colour is visible
        cla(dispAx);
        imagesc(dispAx, s.frame50);
        colormap(dispAx, 'gray');
        axis(dispAx, 'image');
        dispAx.XTick = [];  dispAx.YTick = [];

        for b = 1:nB
            col = BC{mod(b-1,5)+1};
            postUpdate(sprintf(['Branch %d of %d: draw the vessel skeleton ' ...
                'outline on the image, then double-click to finish.'], b, nB));

            uiconfirm(fig, ...
                sprintf(['Branch %d of %d\n\nDraw the skeleton outline ' ...
                'on the image below.\nClick points to build a polygon, ' ...
                'then double-click to close it.'], b, nB), ...
                'Draw skeleton', 'Options', {'Ready to draw'}, ...
                'DefaultOption', 1);

            roi = drawpolygon(dispAx, 'Color', col, 'LineWidth', 1.5);
            wait(roi);

            pos  = roi.Position;
            imSz = size(s.frame50);
            skelMask = poly2mask(pos(:,1), pos(:,2), imSz(1), imSz(2));
            delete(roi);

            % thin to skeleton
            ttt  = bwmorph(skelMask, 'close', Inf);
            ttt  = bwmorph(ttt, 'thin',  Inf);
            skel = bwmorph(ttt, 'bridge');
            newSkels{b} = skel;

            % overlay skeleton in branch colour
            hold(dispAx, 'on');
            [sy, sx] = find(skel);
            scatter(dispAx, sx, sy, 2, repmat(col, numel(sx), 1), 'filled');
            hold(dispAx, 'off');
        end

        s.skeletons = newSkels;
        s.skelDrawn = true;
        setappdata(fig, 'state', s);
        lblSkelTick.Text = char(10003);  % tick
        postUpdate('Skeleton(s) drawn.  Now draw branch ROI box(es).');
    end

    % =========================================================================
    function cb_drawBranch()
        s = getappdata(fig, 'state');
        if ~s.skelDrawn
            uialert(fig, 'Generate skeleton first.', 'No skeleton');  return;
        end

        nB = round(efNBranch.Value);
        newMasks = cell(nB, 1);
        imSz = size(s.frame50);

        for b = 1:nB
            col = BC{mod(b-1,5)+1};
            postUpdate(sprintf(['Branch %d of %d: draw a box around the ' ...
                'vessel branch, then double-click to finish.'], b, nB));

            uiconfirm(fig, ...
                sprintf(['Branch %d of %d\n\nDraw a polygon/box around ' ...
                'the vessel branch on the image.\n' ...
                'Click points then double-click to close.'], b, nB), ...
                'Draw branch ROI', 'Options', {'Ready to draw'}, ...
                'DefaultOption', 1);

            roi  = drawpolygon(dispAx, 'Color', col, 'LineWidth', 2.5);
            wait(roi);
            pos  = roi.Position;
            mask = poly2mask(pos(:,1), pos(:,2), imSz(1), imSz(2));
            delete(roi);

            newMasks{b} = mask;

            % show ROI boundary on display
            hold(dispAx, 'on');
            bnd = bwboundaries(mask);
            if ~isempty(bnd)
                plot(dispAx, bnd{1}(:,2), bnd{1}(:,1), '-', ...
                    'Color', col, 'LineWidth', 2.5);
            end
            hold(dispAx, 'off');
        end

        s.masks         = newMasks;
        s.branchesDrawn = true;
        setappdata(fig, 'state', s);
        lblBranchTick.Text = char(10003);
        postUpdate('Branch ROIs drawn.  Press GO to run analysis.');
    end

    % -------------------------------------------------------------------------
    function applyCaLayout(enabled)
    % applyCaLayout  Shows/hides + resizes the calcium trace plot (caAx) and
    % grows/shrinks heatAx/traceAx to match, so the calcium panel costs
    % screen space only while it's actually in use - unticked, xyDiam's
    % right-hand plots are exactly the size/position they were before the
    % calcium feature existed (Written by Kira Shaw with Claude Code, Aug
    % 2026). Called from cb_perivascularCaChanged (tick/untick) and
    % cb_analysisChanged (so switching back into xyDiam mode restores
    % whichever layout the checkbox currently calls for).
        if enabled
            heatAx.Position    = P(RX,509,RW,197);
            lblTrace.Position  = P(RX,481,350,18);
            traceAx.Position   = P(RX,282,RW,197);
            lblCaTrace.Visible = 'on';
            caAx.Visible       = 'on';
        else
            heatAx.Position    = P(RX,415,RW,290);
            lblTrace.Position  = P(RX,393,350,18);
            traceAx.Position   = P(RX,55,RW,335);
            lblCaTrace.Visible = 'off';
            caAx.Visible       = 'off';
        end
    end

    % -------------------------------------------------------------------------
    function cb_perivascularCaChanged(src)
    % Ticking prompts for a second TIF (perivascular calcium) to associate
    % with this recording; the FWHM-edge sampling + dF/F0 pipeline (see
    % cb_go) then runs on it once GO is pressed. Unticking clears the
    % stored path rather than leaving it stale for a re-tick (Kira Shaw
    % with Claude Code, Aug 2026).
        s = getappdata(fig, 'state');
        if ~src.Value
            s.perivascularCaPath = '';
            setappdata(fig, 'state', s);
            cla(caAx);  title(caAx, 'Perivascular Calcium (not enabled)');
            applyCaLayout(false);
            return;
        end
        startDir = s.expDir;
        if isempty(startDir) || ~isfolder(startDir)
            startDir = pwd;
        end
        if isempty(startDir) || ~isfolder(startDir)
            startDir = '';
        end
        [tifName, tifFolder] = uigetfile( ...
            {'*.tif;*.tiff', 'TIF / OME-TIF files (*.tif, *.tiff, *.ome.tif, *.ome.tiff)'}, ...
            'Select perivascular calcium TIF file', startDir);
        if isequal(tifName, 0)
            src.Value = false;   % cancelled - revert the tick
            applyCaLayout(false);
            return;
        end
        s.perivascularCaPath = fullfile(tifFolder, tifName);
        setappdata(fig, 'state', s);
        % Clear the "(not enabled)" placeholder as soon as a file is
        % actually selected, rather than leaving it up until GO is pressed
        % - it read as if the tick hadn't taken effect (Kira Shaw with
        % Claude Code, Aug 2026).
        title(caAx, '');
        applyCaLayout(true);
        postUpdate(['Perivascular calcium TIF selected: ' s.perivascularCaPath]);
    end

    % =========================================================================
    function cb_go()
        s = getappdata(fig, 'state');
        if isempty(s.rawVess)
            uialert(fig, 'Load data first.',         'No data');     return; end
        if ~s.skelDrawn
            uialert(fig, 'Generate skeleton first.',  'No skeleton'); return; end
        if ~s.branchesDrawn
            uialert(fig, 'Draw branch ROIs first.',   'No ROIs');    return; end

        % parse pixel size and fps
        pxsz_um = str2double(efPxsz.Value);
        fps_val  = str2double(efFPS.Value);
        if isnan(pxsz_um) || pxsz_um <= 0
            pxsz_um  = 1;  diamUnit = 'pixels';  diamDisplay = 'pixels';
        else
            diamUnit = '\mum';  diamDisplay = 'microns';  % word, not TeX, for display
        end
        if isnan(fps_val) || fps_val <= 0
            fps_val  = 1;  timeUnit = 'frames';
        else
            timeUnit = 's';
        end

        nB         = numel(s.skeletons);
        nFrames    = size(s.rawVess, 1);
        imH        = size(s.rawVess, 2);
        imW        = size(s.rawVess, 3);

        s.cont_diams   = cell(nB, 1);
        s.nanInds      = cell(nB, 1);
        s.times        = cell(nB, 1);
        s.perpEndpts   = cell(nB, 1);
        s.cont_calcium        = cell(nB, 1);
        s.cont_calcium_bg     = cell(nB, 1);
        s.cont_calcium_bgcorr = cell(nB, 1);
        s.cont_calcium_dFF    = cell(nB, 1);
        % export-fig only: representative-frame calcium sample pixels, kept
        % as two separate per-edge lists (not merged) so the export figure
        % can draw the two short edge segments separately - see Phase B
        % below (Kira Shaw with Claude Code, Aug 2026).
        s.caEdge1Locs = cell(nB, 1);
        s.caEdge2Locs = cell(nB, 1);
        s.caMeanImg    = [];
        s.caSigBgCorr  = nan(nB, 1);   % per-branch signal<->background ring corr (QC)
        s.caBgKeptFrac = nan(nB, 1);   % per-branch fraction of BG ring inside image/ROI (QC)

        cla(heatAx);  cla(traceAx);  hold(traceAx, 'on');

        % ---- optional perivascular calcium channel (Written by Kira Shaw with
        % Claude Code, Aug 2026) - ported from FWHM_diam_perivascCa_adapted.m's
        % insidePx/outsidePx expansion either side of each FWHM vessel edge.
        % Loaded once here (not per branch) since it's the same TIF for every
        % branch in this recording; skipped with a posted reason rather than
        % erroring out if the box isn't ticked, no file was chosen, or the
        % calcium TIF doesn't match the vessel TIF's dimensions.
        caEnabled = chkPerivascularCa.Value && ~isempty(s.perivascularCaPath) ...
            && isfile(s.perivascularCaPath);
        % In / Out / BG ring are entered in MICRONS; convert to pixels here
        % using the pixel size (Written by Kira Shaw with Claude Code, Aug
        % 2026). A fixed pixel width would mean a different physical distance
        % at every zoom, which at high magnification can put the background
        % ring on top of labelled perivascular processes. A 1 um guard gap
        % (caGuardPx, min 1 px) is inserted between the signal ring and the
        % BG ring so the PSF tail / edge-tracking jitter doesn't leak signal
        % straight into the background estimate. If no pixel size is set, the
        % field values are used as pixels (old behaviour) and this is flagged.
        caInsideUm  = efCaInsidePx.Value;
        caOutsideUm = efCaOutsidePx.Value;
        caBgRingUm  = efCaBgRingPx.Value;
        caGuardUm   = 1;    % guard gap (microns) between the signal ring and the BG ring
        if isfield(s,'caGuardUm') && ~isempty(s.caGuardUm) && s.caGuardUm >= 0
            caGuardUm = s.caGuardUm;
        end
        if ~strcmp(diamUnit, 'pixels')
            caInsidePx  = max(1, round(caInsideUm  / pxsz_um));
            caOutsidePx = max(1, round(caOutsideUm / pxsz_um));
            caBgRingPx  = max(1, round(caBgRingUm  / pxsz_um));
            caGuardPx   = max(1, round(caGuardUm   / pxsz_um));
        else
            caInsidePx  = max(1, round(caInsideUm));
            caOutsidePx = max(1, round(caOutsideUm));
            caBgRingPx  = max(1, round(caBgRingUm));
            caGuardPx   = 1;
            if caEnabled
                postUpdate(['Perivascular calcium: no pixel size set - ' ...
                    'treating In/Out/BG ring values as pixels, not microns.']);
            end
        end
        caBgCoeff   = efCaBgCoeff.Value;
        caBaselineSec = efCaBaselineSec.Value;
        rawCa = [];
        caDarkFloor = NaN;
        if caEnabled
            postUpdate('Loading perivascular calcium TIF...');
            drawnow;
            rawCa = loadTifFileIn2Mat(s.perivascularCaPath);
            if ~isequal(size(rawCa), size(s.rawVess))
                postUpdate(sprintf(['Perivascular calcium TIF is %d x %d x %d but the ' ...
                    'vessel TIF is %d x %d x %d - skipping calcium analysis.'], ...
                    size(rawCa,1), size(rawCa,2), size(rawCa,3), nFrames, imH, imW));
                caEnabled = false;
            else
                % ---- dark-offset floor (Written by Kira Shaw with Claude
                % Code, Aug 2026) - raw PMT/detector counts are rarely
                % true-zero at rest; a robust low percentile of the WHOLE
                % recording (every pixel, every frame - not per-ROI, not
                % per-frame) estimates that fixed floor and is subtracted
                % here, before any background-ring/dF-F0 math downstream.
                % Left uncorrected, a leftover offset dominates F0's
                % denominator and dF/F0 comes out artificially tiny
                % regardless of genuine signal changes (same pctileLocal
                % helper already used for linescan's raw-line normalisation
                % in cb_loadData, so this is a proven-scale operation).
                postUpdate('Estimating perivascular calcium dark-offset floor...');
                drawnow;
                caDarkFloor = pctileLocal(double(rawCa(:)), 1);
                rawCa = double(rawCa) - caDarkFloor;
                rawCa(rawCa < 0) = 0;  % the floor estimate can slightly overshoot on some frames
            end
        elseif chkPerivascularCa.Value
            postUpdate('Perivascular Calcium ticked but no valid TIF is selected - skipping calcium analysis.');
        end
        if caEnabled
            % export-fig only: mean projection of the raw (unmasked) calcium
            % channel, so the popout figure can show it the same way meanVess
            % is shown for the vessel channel (Kira Shaw with Claude Code,
            % Aug 2026).
            s.caMeanImg = squeeze(mean(double(rawCa), 1));
        end
        cla(caAx);  hold(caAx, 'on');
        if caEnabled
            % dF/F0 (background-ring subtracted, sliding-baseline normalised -
            % see the Suite2p-style computation in Phase B below) is the trace
            % actually shown live/in the popout figure - it's the one that
            % answers "how much brighter than its own resting level is this
            % branch right now", which raw AU alone can't (Kira Shaw with
            % Claude Code, Aug 2026). Raw/background/background-corrected are
            % still all kept in the data export.
            xlabel(caAx, 'Frame');  ylabel(caAx, 'Perivascular \DeltaF/F_0');
            title(caAx, '');
        else
            title(caAx, 'Perivascular Calcium (not enabled)');
        end

        % mean vessel image doesn't depend on branch — compute once, not per-branch
        meanVess = squeeze(mean(double(s.rawVess), 1));

        for b = 1:nB
            col      = BC{mod(b-1,5)+1};
            skeleton = s.skeletons{b};
            mask     = s.masks{b};

            % ---- apply mask, get rough diameter -----------------------------
            postUpdate(sprintf('Branch %d / %d:  masking frames...', b, nB));
            drawnow;

            rawVess_mask = applyMask(s.rawVess, mask);

            skeleton(~mask) = 0;
            fr10 = squeeze(rawVess_mask(min(10,nFrames), :, :));
            [threshIm, ~] = thresholdVesselIm(fr10, prefs);
            skelSum = max(1, sum(skeleton(:)));
            roughdiam = max(5, sum(threshIm(:)) / skelSum);  % min 5 px fallback

            % ---- skeleton contour -------------------------------------------
            [xend, yend] = find(bwmorph(skeleton, 'endpoints'));
            if isempty(xend)
                postUpdate(sprintf('Branch %d: no skeleton endpoints found — skipping.', b));
                continue;
            end
            cSkel    = bwtraceboundary(skeleton, [xend(1) yend(1)], 'NW');
            nSkelPts = floor(size(cSkel,1)/2 - 1);
            if nSkelPts < 2
                postUpdate(sprintf('Branch %d: skeleton too short — skipping.', b));
                continue;
            end

            % ---- smooth skeleton coordinates --------------------------------
            smWin = prefs.skelLineLength * 2;
            nWP   = min(nSkelPts + prefs.skelLineLength, size(cSkel,1));
            cSkel(1:nWP,1) = movmean(cSkel(1:nWP,1), smWin);
            cSkel(1:nWP,2) = movmean(cSkel(1:nWP,2), smWin);

            % ---- compute perpendicular lines (atan2) -------------------------
            postUpdate(sprintf('Branch %d / %d:  computing perpendicular lines...', b, nB));
            drawnow;

            nLines     = nSkelPts - prefs.skelLineLength;
            normlength = ceil(roughdiam) * 2;
            prevAngle  = NaN;

            % ---- mask vessel (and, if enabled, calcium) for intensity --------
            maskVess = zeros(size(s.rawVess), 'single');
            if caEnabled
                maskCa = zeros(size(rawCa), 'single');
            end
            for i = 1:nFrames
                fr = single(squeeze(s.rawVess(i,:,:)));
                fr(~mask) = NaN;
                maskVess(i,:,:) = fr;
                if caEnabled
                    frCa = single(squeeze(rawCa(i,:,:)));
                    frCa(~mask) = NaN;
                    maskCa(i,:,:) = frCa;
                end
            end

            % ===================================================================
            %  PHASE A — geometry pass (skeleton-point loop, no frame data)
            %  Works out the perpendicular scan line for every skeleton point.
            %  Purely spatial — independent of frame — so it's fast, and lets
            %  us sanity-check the scan geometry (is the line tracking the
            %  vessel properly?) on dispAx before the slow per-frame FWHM
            %  crunching starts.
            % ===================================================================
            cont_diam   = nan(nLines, nFrames, 'single');
            perpEndpts  = nan(nLines, 4);   % [x1 y1 x2 y2] for export figure
            perpSampAll = cell(nLines, 1);  % ordered [x y] samples, 1 px apart, per perp line

            postUpdate(sprintf('Branch %d / %d:  checking scan geometry...', b, nB));

            % draw vessel + full skeleton + ROI once; perp lines added below,
            % same style as the export figure (skeleton, ROI, subsampled lines)
            cla(dispAx);
            imagesc(dispAx, meanVess);
            colormap(dispAx, 'gray');
            axis(dispAx, 'image');
            dispAx.XTick = [];  dispAx.YTick = [];
            hold(dispAx, 'on');
            [sy, sx] = find(skeleton);
            scatter(dispAx, sx, sy, 2, repmat(col, numel(sx), 1), 'filled');
            bnd = bwboundaries(mask);
            if ~isempty(bnd)
                plot(dispAx, bnd{1}(:,2), bnd{1}(:,1), '-', 'Color', col, 'LineWidth', 2);
            end
            title(dispAx, sprintf('Branch %d — scan geometry', b));

            nLinesEff = nLines;
            for k = 1:nLines
                skelb4    = k;
                skelafter = k + prefs.skelLineLength - 1;
                midIdx    = k + round(prefs.skelLineLength / 2);
                if midIdx > size(cSkel,1), nLinesEff = k-1; break; end

                xc = cSkel(midIdx, 2);  yc = cSkel(midIdx, 1);
                xw = cSkel(skelb4:skelafter, 2);
                yw = cSkel(skelb4:skelafter, 1);

                dxv = xw(end)-xw(1);  dyv = yw(end)-yw(1);
                if dxv==0 && dyv==0
                    if isnan(prevAngle), continue; end
                    pa = prevAngle;
                else
                    pa = atan2(dyv, dxv) + pi/2;
                    prevAngle = pa;
                end

                % Sample the perpendicular at uniform 1-pixel arc-length
                % steps, keeping the samples in order from one end of the
                % line to the other. Consecutive samples are then exactly one
                % pixel apart along the line, so (i2-i1)*pxsz is a true FWHM
                % at any vessel orientation - not only for perpendiculars
                % that happen to run along a pixel axis.
                tline = -normlength:normlength;
                normx = xc + tline .* cos(pa);
                normy = yc + tline .* sin(pa);

                % clip to image bounds then ROI mask
                bad = normx<1 | normx>imW | normy<1 | normy>imH;
                normx(bad)=[]; normy(bad)=[];
                if ~isempty(normx)
                    inMask = mask(sub2ind([imH imW], round(normy), round(normx)));
                    normx  = normx(inMask);
                    normy  = normy(inMask);
                end

                if ~isempty(normx)
                    perpEndpts(k,:) = [normx(1) normy(1) normx(end) normy(end)];
                    perpSampAll{k}  = [normx(:), normy(:)];
                end

                % sanity-check overlay: add every 10th perp line (as in export fig)
                if mod(k,10)==0 || k==nLines
                    if ~isempty(normx)
                        plot(dispAx, [normx(1) normx(end)], [normy(1) normy(end)], ...
                            '-', 'Color', [col 0.55], 'LineWidth', 1.2);
                    end
                    postUpdate(sprintf('Branch %d / %d:  geometry pt %d / %d', ...
                        b, nB, k, nLines));
                    drawnow limitrate;
                end
            end
            hold(dispAx, 'off');

            % ===================================================================
            %  PHASE B — frame pass: FWHM for every skeleton point, one frame
            %  at a time. Looping frame-outer means each frame's masked image
            %  is extracted once (previously re-extracted per skeleton point —
            %  the real cost for long scans). Heatmap/trace now genuinely fill
            %  in per frame, left to right, instead of jumping to full width.
            % ===================================================================
            postUpdate(sprintf('Branch %d / %d:  scanning frames...', b, nB));

            hHeat = imagesc(heatAx, cont_diam);
            xlim(heatAx, [0.5, 1.5]);
            xlabel(heatAx, 'Frame');  ylabel(heatAx, 'Skeleton pt');

            frameVec = 1:nFrames;   % live display is always in frames, never time
            traceY   = nan(1, nFrames);
            hTrace   = plot(traceAx, frameVec, traceY, '-', ...
                'Color', col, 'LineWidth', 1.8, ...
                'DisplayName', sprintf('Branch %d', b));
            xlabel(traceAx, 'Frame');
            ylabel(traceAx, ['Avg diam (' diamDisplay ')']);
            legend(traceAx, 'Location', 'best');

            % ---- perivascular calcium: same [skeleton pt x frame] shape as
            % cont_diam, sampled caInsidePx/caOutsidePx either side of each
            % FWHM edge (see the loop below) - only allocated/plotted when
            % the feature is actually enabled for this run.
            if caEnabled
                cont_calcium    = nan(nLines, nFrames, 'single');
                cont_calcium_bg = nan(nLines, nFrames, 'single');
                caY  = nan(1, nFrames);
                hCa  = plot(caAx, frameVec, caY, '-', ...
                    'Color', col, 'LineWidth', 1.8, ...
                    'DisplayName', sprintf('Branch %d', b));
                legend(caAx, 'Location', 'best');
                % export-fig only: the actual sampled pixel locations, frozen
                % at one representative frame (same frame roughdiam used
                % above), kept as two separate per-edge lists rather than
                % merged - lets the popout figure draw the two short edge
                % segments separately, without having to store this every
                % frame (Kira Shaw with Claude Code, Aug 2026).
                caEdge1Locs = cell(nLines, 1);
                caEdge2Locs = cell(nLines, 1);
                repFrame    = min(10, nFrames);
                % QC counters: how much of the BG ring survived clipping to
                % the image / branch ROI, this branch (see the warning after
                % the frame loop).
                caBgTotal = 0;
                caBgKept  = 0;
            end

            frameStep = max(1, round(nFrames/100));   % ~100 display refreshes total

            for i = 1:nFrames
                ImVess = squeeze(maskVess(i,:,:));   % once per frame, not per skel pt
                if caEnabled
                    ImCa = squeeze(maskCa(i,:,:));
                end
                for k = 1:nLinesEff
                    XY = perpSampAll{k};
                    if isempty(XY), continue; end
                    prof   = interp2(ImVess, XY(:,1), XY(:,2), 'nearest');
                    valid  = ~isnan(prof);
                    prof   = prof(valid);
                    if numel(prof) < 2, continue; end
                    hm = (min(prof) + max(prof)) / 2;
                    i1 = find(prof >= hm, 1, 'first');
                    i2 = find(prof >= hm, 1, 'last');
                    if ~isempty(i1) && ~isempty(i2)
                        cont_diam(k,i) = (i2 - i1) * pxsz_um;   % samples are 1 px apart

                        % ---- perivascular calcium (Written by Kira Shaw with
                        % Claude Code, Aug 2026) - same edge-expansion as
                        % FWHM_diam_perivascCa_adapted.m: caOutsidePx out to
                        % caInsidePx in around edge 1, mirrored around edge 2.
                        if caEnabled
                            % XYnz: the same ordered, 1-px-spaced sample
                            % points that survived 'valid', so i1/i2 index
                            % straight into them (Kira Shaw with Claude Code).
                            XYnz = XY(valid,:);
                            lineInd1 = (i1-caOutsidePx):(i1+caInsidePx);
                            lineInd2 = (i2-caInsidePx):(i2+caOutsidePx);
                            lineInd1(lineInd1 < 1 | lineInd1 > size(XYnz,1)) = [];
                            lineInd2(lineInd2 < 1 | lineInd2 > size(XYnz,1)) = [];
                            lineInd = [lineInd1, lineInd2];
                            if ~isempty(lineInd)
                                cont_calcium(k,i) = mean(interp2(ImCa, ...
                                    XYnz(lineInd,1), XYnz(lineInd,2), 'nearest'), 'omitnan');
                                if i == repFrame
                                    if ~isempty(lineInd1)
                                        caEdge1Locs{k} = sub2ind([imH imW], ...
                                            round(XYnz(lineInd1,2)), round(XYnz(lineInd1,1)));
                                    end
                                    if ~isempty(lineInd2)
                                        caEdge2Locs{k} = sub2ind([imH imW], ...
                                            round(XYnz(lineInd2,2)), round(XYnz(lineInd2,1)));
                                    end
                                end
                            end

                            % ---- background ring (Written by Kira Shaw with
                            % Claude Code, Aug 2026) - Suite2p-style: a further
                            % -out annulus used as a common-mode background
                            % reference (see cont_calcium_bgcorr/dF-F0 below).
                            % It starts caGuardPx pixels PAST the end of the
                            % Out ring - a guard gap so the PSF tail / edge
                            % jitter doesn't leak real signal into the
                            % background estimate - and is caBgRingPx wide.
                            bgOff = caOutsidePx + caGuardPx;
                            bgIndFull = [(i1-bgOff-caBgRingPx):(i1-bgOff-1), ...
                                         (i2+bgOff+1):(i2+bgOff+caBgRingPx)];
                            bgInd = bgIndFull(bgIndFull >= 1 & bgIndFull <= size(XYnz,1));
                            caBgTotal = caBgTotal + numel(bgIndFull);
                            caBgKept  = caBgKept  + numel(bgInd);
                            if ~isempty(bgInd)
                                cont_calcium_bg(k,i) = mean(interp2(ImCa, ...
                                    XYnz(bgInd,1), XYnz(bgInd,2), 'nearest'), 'omitnan');
                            end
                        end
                    end
                end
                traceY(i) = nanmean(cont_diam(:,i));
                if caEnabled
                    caY(i) = nanmean(cont_calcium(:,i));
                end

                if mod(i,frameStep)==0 || i==nFrames
                    postUpdate(sprintf('Branch %d / %d:  frame %d / %d', b, nB, i, nFrames));
                    set(hHeat, 'CData', cont_diam);
                    xlim(heatAx, [0.5, i+0.5]);
                    set(hTrace, 'YData', traceY);
                    if caEnabled
                        set(hCa, 'YData', caY);
                    end
                    drawnow limitrate;
                end
            end

            s.perpEndpts{b} = perpEndpts;
            if caEnabled
                s.caEdge1Locs{b} = caEdge1Locs;
                s.caEdge2Locs{b} = caEdge2Locs;
            end

            % ---- remove all-NaN skeleton rows, build time vector ------------
            nanInd = find(all(isnan(cont_diam), 2));
            cont_diam(nanInd,:) = [];
            time = (0 : size(cont_diam,2)-1) / fps_val;

            s.cont_diams{b} = cont_diam;
            s.nanInds{b}    = nanInd;
            s.times{b}      = time;
            if caEnabled
                % same rows removed as cont_diam, so the two stay aligned
                % skeleton-pt-for-skeleton-pt (see export functions)
                cont_calcium(nanInd,:)    = [];
                cont_calcium_bg(nanInd,:) = [];
                s.cont_calcium{b}    = cont_calcium;
                s.cont_calcium_bg{b} = cont_calcium_bg;

                % ---- background-subtract, then dF/F0 (Written by Kira Shaw
                % with Claude Code, Aug 2026) - Suite2p-style: F_bgcorr =
                % F - r*F_bg, then F0 = a sliding 'maximin' baseline (Gaussian
                % -smooth, sliding min, sliding max, all over the baseline
                % window) of F_bgcorr, then dF/F0 = (F_bgcorr-F0)/F0. Done
                % once per branch here (not per-frame above) since the
                % sliding baseline needs the whole trace, not just frames
                % seen so far - see slidingBaseline() at the bottom of this
                % file.
                cont_calcium_bgcorr = cont_calcium - caBgCoeff * cont_calcium_bg;
                winFrames = max(3, round(caBaselineSec * fps_val));
                F0        = slidingBaseline(cont_calcium_bgcorr, winFrames);
                % dF/F0 itself is allowed to go slightly negative - normal
                % noise around a resting baseline, seen throughout the
                % calcium-imaging literature (a maximin baseline is a local
                % minimum estimate, not a hard floor, so F dipping just
                % below it briefly is expected and shouldn't be censored;
                % doing so would asymmetrically discard only the negative
                % half of ordinary noise and bias the reported mean
                % upward). What DOES get excluded (Written by Kira Shaw with
                % Claude Code, Aug 2026): frames/skeleton points where F0
                % itself is <=0 - background-ring subtraction can legitimately
                % push the background-corrected trace (and so its own
                % baseline) non-positive for a stretch, at which point F0 is
                % no longer a valid resting-fluorescence reference and
                % dividing by it gives a huge, not-meaningfully-signed
                % number rather than a real percentage change - same class
                % of physical-floor guard as the linescan velocity noise
                % floor elsewhere in this file.
                cont_calcium_dFF = (cont_calcium_bgcorr - F0) ./ F0;
                cont_calcium_dFF(F0 <= 0) = NaN;

                s.cont_calcium_bgcorr{b} = cont_calcium_bgcorr;
                s.cont_calcium_dFF{b}    = cont_calcium_dFF;

                % ---- background-ring QC (Written by Kira Shaw with Claude
                % Code, Aug 2026). The background subtraction assumes the BG
                % ring carries no perivascular-cell signal. Two cheap checks:
                %  (1) if the branch-mean signal and background traces are
                %      very highly correlated the BG ring is probably picking
                %      up cell signal, so F - r*F_bg is over-subtracting and
                %      dF/F0 is under-reported - widen In/Out or move the ring
                %      out, or lower r;
                %  (2) if much of the BG ring fell outside the image / branch
                %      ROI it is being sampled from a biased sliver - draw a
                %      larger ROI or reduce the ring widths.
                sigTr = mean(double(cont_calcium),    1, 'omitnan');
                bgTr  = mean(double(cont_calcium_bg), 1, 'omitnan');
                okTr  = isfinite(sigTr) & isfinite(bgTr);
                rSB = NaN;
                if nnz(okTr) >= 10 && std(sigTr(okTr)) > 0 && std(bgTr(okTr)) > 0
                    cc  = corrcoef(sigTr(okTr), bgTr(okTr));
                    rSB = cc(1,2);
                end
                keptFrac = caBgKept / max(1, caBgTotal);
                s.caSigBgCorr(b)  = rSB;
                s.caBgKeptFrac(b) = keptFrac;
                if isfinite(rSB) && rSB > 0.9
                    postUpdate(sprintf(['Branch %d: perivascular signal and ' ...
                        'background rings are highly correlated (r = %.2f) - the ' ...
                        'background subtraction may be over-correcting dF/F0. ' ...
                        'Consider widening In/Out or lowering r.'], b, rSB));
                end
                if caBgTotal > 0 && keptFrac < 0.7
                    postUpdate(sprintf(['Branch %d: only %.0f%% of the background ' ...
                        'ring fell inside the image / ROI - draw a larger branch ROI ' ...
                        'or reduce the ring widths for a reliable background.'], ...
                        b, 100*keptFrac));
                end
            end

            % ---- finalize heatmap + trace for this branch (exact values) ----
            set(hHeat, 'CData', cont_diam);
            xlim(heatAx, [0.5, nFrames+0.5]);
            ylim(heatAx, [0.5, size(cont_diam,1)+0.5]);
            title(heatAx, sprintf('Branch %d', b));

            set(hTrace, 'XData', frameVec, 'YData', nanmean(cont_diam, 1));
            xlim(traceAx, [1, nFrames]);
            if caEnabled
                % dF/F0 is the "best" trace to show live (see the ylabel note
                % above) - the raw/running caY shown during the frame loop was
                % only ever a placeholder, since dF/F0 needs the complete
                % trace before its baseline can be computed.
                set(hCa, 'XData', frameVec, 'YData', nanmean(cont_calcium_dFF, 1));
                xlim(caAx, [1, nFrames]);
            end
            drawnow;

        end % branch loop

        s.caInsideUm    = caInsideUm;    % as entered (microns)
        s.caOutsideUm   = caOutsideUm;
        s.caBgRingUm    = caBgRingUm;
        s.caGuardUm     = caGuardUm;
        s.caInsidePx    = caInsidePx;    % resolved to pixels for this recording
        s.caOutsidePx   = caOutsidePx;
        s.caBgRingPx    = caBgRingPx;
        s.caGuardPx     = caGuardPx;
        s.caBgCoeff     = caBgCoeff;
        s.caBaselineSec = caBaselineSec;
        s.caDarkFloor   = caDarkFloor;

        % Restore display to vessel + all overlays after scan finishes
        refreshDisplay(s, s.skeletons, s.masks);

        s.pxsz_um     = pxsz_um;
        s.fps         = fps_val;
        s.diamUnit    = diamUnit;
        s.timeUnit    = timeUnit;
        s.analysisRun = true;
        setappdata(fig, 'state', s);

        btnExport.Enable    = 'on';
        btnExportFig.Enable = 'on';
        postUpdate('Analysis complete — ready to export.');
    end

    % =========================================================================
    function cb_export()
        if strcmp(ddAnalysis.Value, 'zstack')
            cb_zExport();
            return;
        end
        if strcmp(ddAnalysis.Value, 'linescan')
            cb_lsExport();
            return;
        end

        s = getappdata(fig, 'state');
        if ~s.analysisRun
            postUpdate('User needs to extract data first');  return;
        end

        choice = uiconfirm(fig, 'Choose export format:', 'Export', ...
            'Options',       {'MAT file', 'Excel (.xlsx)', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end

        nB = numel(s.cont_diams);

        if strcmp(choice, 'MAT file')
            [fn, fp] = uiputfile('*.mat', 'Save MAT file', ...
                fullfile(s.expDir, 'MAPS_results.mat'));
            if isequal(fn,0), return; end
            results.cont_diams   = s.cont_diams;
            results.times        = s.times;
            results.nanInds      = s.nanInds;
            results.pxsz_um      = s.pxsz_um;
            results.fps          = s.fps;
            results.diamUnit     = s.diamUnit;
            results.timeUnit     = s.timeUnit;
            % Perivascular calcium - every stage of the pipeline kept, not
            % just the dF/F0 shown live (empty cells/NaN if the feature
            % wasn't used for this run). Written by Kira Shaw with Claude
            % Code, Aug 2026 - see cb_go for how each is derived.
            results.cont_calcium        = s.cont_calcium;         % raw AU
            results.cont_calcium_bg     = s.cont_calcium_bg;      % background ring, AU
            results.cont_calcium_bgcorr = s.cont_calcium_bgcorr;  % background-subtracted, AU
            results.cont_calcium_dFF    = s.cont_calcium_dFF;     % dF/F0 (shown live)
            for fld = {'caInsideUm','caOutsideUm','caBgRingUm','caGuardUm', ...
                       'caInsidePx','caOutsidePx','caBgRingPx','caGuardPx', ...
                       'caBgCoeff','caBaselineSec','caDarkFloor', ...
                       'caSigBgCorr','caBgKeptFrac'}
                if isfield(s, fld{1}), results.(fld{1}) = s.(fld{1}); end
            end
            save(fullfile(fp,fn), 'results', '-v7.3');
            postUpdate(['Saved: ' fullfile(fp,fn)]);

        else  % Excel
            [fn, fp] = uiputfile('*.xlsx', 'Save Excel file', ...
                fullfile(s.expDir, 'MAPS_results.xlsx'));
            if isequal(fn,0), return; end
            [~, baseName, ext] = fileparts(fn);

            % one file per branch, not one sheet per branch — writetable's
            % multi-sheet handling proved unreliable, this sidesteps it
            % entirely (each file only ever has a single default sheet)
            savedFiles = cell(nB, 1);

            for b = 1:nB
                cd_b    = double(s.cont_diams{b});
                t_b     = s.times{b}(:);
                nFr     = size(cd_b, 2);
                nSk     = size(cd_b, 1);
                frmVec  = (1:nFr)';
                avgDiam = nanmean(cd_b, 1)';

                % time column: seconds if fps known, blank (NaN) if not
                if strcmp(s.timeUnit, 'frames')
                    timeSec = nan(nFr, 1);
                else
                    timeSec = t_b;
                end

                % diameter unit label — avoid LaTeX in spreadsheet headers
                if strcmp(s.diamUnit, '\mum')
                    diamLabel = 'microns';
                else
                    diamLabel = s.diamUnit;
                end

                isPixelsAlready = strcmp(s.diamUnit, 'pixels') || s.pxsz_um == 1;
                if isPixelsAlready
                    % primary column is already pixels — a second "pixels"
                    % column would just duplicate it (and its own header)
                    colNames = [{'Frame'}, {'Time (seconds)'}, ...
                        {['Avg diam (' diamLabel ')']}, ...
                        arrayfun(@(n) sprintf('SkelPt%02d_diam', n), 1:nSk, ...
                        'UniformOutput', false)];
                    data = [frmVec, timeSec, avgDiam, cd_b'];
                else
                    diamPx = avgDiam ./ s.pxsz_um;
                    colNames = [{'Frame'}, {'Time (seconds)'}, ...
                        {['Avg diam (' diamLabel ')']}, {'Avg diam (pixels)'}, ...
                        arrayfun(@(n) sprintf('SkelPt%02d_diam', n), 1:nSk, ...
                        'UniformOutput', false)];
                    data = [frmVec, timeSec, avgDiam, diamPx, cd_b'];
                end

                % ---- perivascular calcium columns, if this branch has them
                % (Written by Kira Shaw with Claude Code, Aug 2026) - every
                % stage of the pipeline (raw / background ring / background-
                % subtracted / dF/F0), not just the dF/F0 shown live, so
                % nothing here is only recoverable by rerunning the analysis.
                % All aligned row-for-row with the diameter skeleton points
                % above, since cb_go removes the same all-NaN rows from all
                % of them.
                if ~isempty(s.cont_calcium) && b <= numel(s.cont_calcium) ...
                        && ~isempty(s.cont_calcium{b})
                    caStages = { 'calcium',        'perivascular Ca (AU)',            s.cont_calcium{b};
                                 'calciumBg',       'perivascular Ca bg ring (AU)',    s.cont_calcium_bg{b};
                                 'calciumBgCorr',   'perivascular Ca bg-corrected (AU)', s.cont_calcium_bgcorr{b};
                                 'calciumDFF',      'perivascular Ca dF/F0',           s.cont_calcium_dFF{b} };
                    for r = 1:size(caStages,1)
                        ca_b = double(caStages{r,3});
                        if isempty(ca_b), continue; end
                        avgCa = nanmean(ca_b, 1)';
                        stageTag = caStages{r,1};
                        colNames = [colNames, {['Avg ' caStages{r,2}]}, ...
                            arrayfun(@(n) sprintf('SkelPt%02d_%s', n, stageTag), ...
                            1:nSk, 'UniformOutput', false)];
                        data = [data, avgCa, ca_b'];
                    end
                end

                T = array2table(data, 'VariableNames', colNames);

                branchFn = fullfile(fp, sprintf('%s_Branch%d%s', baseName, b, ext));
                if isfile(branchFn)
                    delete(branchFn);
                end
                writetable(T, branchFn);
                savedFiles{b} = branchFn;
            end
            postUpdate(['Saved ' num2str(nB) ' file(s), e.g. ' savedFiles{1}]);
        end
    end

    % =========================================================================
    function cb_exportFig()
        if strcmp(ddAnalysis.Value, 'zstack')
            cb_zExportFig();
            return;
        end
        if strcmp(ddAnalysis.Value, 'linescan')
            cb_lsExportFig();
            return;
        end

        s = getappdata(fig, 'state');
        if ~s.analysisRun
            postUpdate('User needs to extract data first');  return;
        end

        nB       = numel(s.cont_diams);
        diamLbl  = strrep(s.diamUnit, '\mum', 'microns');
        meanVess = squeeze(mean(double(s.rawVess), 1));
        imH      = size(s.rawVess, 2);
        imW      = size(s.rawVess, 3);

        % Perivascular calcium was actually run for at least one branch this
        % time (Written by Kira Shaw with Claude Code, Aug 2026) - only then
        % does the figure grow a 4th panel for it, so exporting without the
        % feature looks exactly as it always has.
        caPresent = ~isempty(s.cont_calcium) && any(~cellfun(@isempty, s.cont_calcium));

        % ---- create export figure -------------------------------------------
        expFig = figure('Name', 'MAPS — Export', 'Color', 'w', ...
            'Position', [80 80 1300 780]);

        % Layout: without calcium, left column = vessel image (tall), right
        % column = diameter heatmap (top) / trace (bottom) - unchanged from
        % before the calcium feature existed.
        %
        % With calcium (Written by Kira Shaw with Claude Code, Aug 2026):
        % image diagnostics live in the main GUI, only the export figure -
        % there's no room for a second live image display next to dispAx, so
        % this is the one place the calcium channel and exactly which pixels
        % fed its trace can be checked. One image only (not two - the earlier
        % separate "calcium + full perp lines" panel was redundant with ax1,
        % which already shows those lines on the vessel channel), so a 6x2
        % grid: left column = two images (vessel, each spanning 3 of 6 rows);
        % right column = the three matching plots (diameter heatmap, diameter
        % trace, calcium trace), each spanning 2 of 6 rows.
        if caPresent
            ax1  = subplot(6, 2, [1 3 5],  'Parent', expFig);
            axCa = subplot(6, 2, [7 9 11], 'Parent', expFig);
            ax2  = subplot(6, 2, [2 4],    'Parent', expFig);
            ax3  = subplot(6, 2, [6 8],    'Parent', expFig);
            ax4  = subplot(6, 2, [10 12],  'Parent', expFig);
        else
            ax1 = subplot(2, 3, [1 4], 'Parent', expFig);
            ax2 = subplot(2, 3, [2 3], 'Parent', expFig);
            ax3 = subplot(2, 3, [5 6], 'Parent', expFig);
        end

        % ---- ax1: mean vessel + skeletons + ROIs + subsampled perp lines ----
        imagesc(ax1, meanVess);
        colormap(ax1, 'gray');
        axis(ax1, 'image');
        ax1.XTick = [];  ax1.YTick = [];
        title(ax1, 'Mean vessel  |  skeleton  |  ROI  |  perp lines (subsample)');
        hold(ax1, 'on');

        for b = 1:nB
            col = BC{mod(b-1,5)+1};

            % skeleton pixels
            if b <= numel(s.skeletons) && ~isempty(s.skeletons{b})
                [sy, sx] = find(s.skeletons{b});
                plot(ax1, sx, sy, '.', 'Color', col, 'MarkerSize', 3);
            end

            % ROI boundary
            if b <= numel(s.masks) && ~isempty(s.masks{b})
                bnd = bwboundaries(s.masks{b});
                if ~isempty(bnd)
                    plot(ax1, bnd{1}(:,2), bnd{1}(:,1), '-', ...
                        'Color', col, 'LineWidth', 2);
                end
            end

            % subsampled perpendicular lines (~15 evenly spaced)
            if b <= numel(s.perpEndpts) && ~isempty(s.perpEndpts{b})
                ep   = s.perpEndpts{b};
                nLn  = size(ep, 1);
                step = max(1, floor(nLn / 15));
                for k = 1:step:nLn
                    if any(isnan(ep(k,:))), continue; end
                    plot(ax1, [ep(k,1) ep(k,3)], [ep(k,2) ep(k,4)], '-', ...
                        'Color', [col 0.55], 'LineWidth', 1.0);
                end
            end
        end
        hold(ax1, 'off');

        % ---- axCa: calcium channel + the actual edge-sample pixels (only if
        % run). Written by Kira Shaw with Claude Code, Aug 2026 - one panel,
        % not two (ax1 already shows the full perp lines, on the vessel
        % channel, so repeating them here on the calcium channel just added
        % a redundant second image). Each edge's sample is drawn as a single
        % short line segment - from one extreme sampled pixel to the other,
        % projected onto that skeleton point's own perpendicular direction
        % (perpEndpts) so the segment is correctly oriented even though the
        % underlying pixel list itself isn't in walk-along-the-line order -
        % rather than a scatter dot per pixel, which at caInsidePx/
        % caOutsidePx's usual scale (~10-30 px) read as a dense smear
        % covering most of the ROI once several skeleton points were
        % overlaid. Two segments per skeleton point, with a gap between them
        % over the vessel interior - matching the original script's own
        % example figure (calcium sampled only in a ring either side of each
        % edge, not across the whole line).
        if caPresent
            imagesc(axCa, s.caMeanImg);
            colormap(axCa, 'gray');
            axis(axCa, 'image');
            axCa.XTick = [];  axCa.YTick = [];
            title(axCa, 'Mean perivascular calcium  |  ROI  |  calcium sample pixels (subsample)');
            hold(axCa, 'on');
            for b = 1:nB
                col = BC{mod(b-1,5)+1};
                if b <= numel(s.masks) && ~isempty(s.masks{b})
                    bnd = bwboundaries(s.masks{b});
                    if ~isempty(bnd)
                        plot(axCa, bnd{1}(:,2), bnd{1}(:,1), '-', ...
                            'Color', col, 'LineWidth', 2);
                    end
                end
                if b > numel(s.perpEndpts) || isempty(s.perpEndpts{b}), continue; end
                ep = s.perpEndpts{b};
                if b > numel(s.caEdge1Locs) || isempty(s.caEdge1Locs{b}), continue; end
                e1 = s.caEdge1Locs{b};
                e2 = s.caEdge2Locs{b};
                nLn  = numel(e1);
                step = max(1, floor(nLn / 15));
                for k = 1:step:nLn
                    if k > size(ep,1) || any(isnan(ep(k,:))), continue; end
                    dirVec = [ep(k,3)-ep(k,1), ep(k,4)-ep(k,2)];
                    nrm    = norm(dirVec);
                    if nrm < eps, continue; end
                    dirVec = dirVec / nrm;
                    for edgeCell = {e1{k}, e2{k}}
                        locs_e = edgeCell{1};
                        if isempty(locs_e), continue; end
                        [py, px] = ind2sub([imH imW], locs_e);
                        proj = (double(px)-ep(k,1))*dirVec(1) + (double(py)-ep(k,2))*dirVec(2);
                        [~, iMin] = min(proj);
                        [~, iMax] = max(proj);
                        plot(axCa, [px(iMin) px(iMax)], [py(iMin) py(iMax)], '-', ...
                            'Color', col, 'LineWidth', 2.5);
                    end
                end
            end
            hold(axCa, 'off');
        end

        % ---- ax2: diameter heatmap (all branches stacked) -------------------
        allDiam = vertcat(s.cont_diams{:});
        imagesc(ax2, double(allDiam));
        colormap(ax2, 'parula');
        xlim(ax2, [0.5, size(allDiam,2)+0.5]);
        ylim(ax2, [0.5, size(allDiam,1)+0.5]);
        cb2 = colorbar(ax2);
        ylabel(cb2, ['Diam (' diamLbl ')']);
        xlabel(ax2, 'Frame');
        ylabel(ax2, 'Skeleton pt');
        title(ax2, 'Diameter map  (all branches stacked)');

        % ---- ax3: average diameter traces -----------------------------------
        hold(ax3, 'on');
        for b = 1:nB
            if isempty(s.cont_diams{b}), continue; end
            col       = BC{mod(b-1,5)+1};
            frameVecB = 1:size(s.cont_diams{b}, 2);   % figure is always in frames
            plot(ax3, frameVecB, nanmean(s.cont_diams{b}, 1), '-', ...
                'Color', col, 'LineWidth', 2, ...
                'DisplayName', sprintf('Branch %d', b));
        end
        hold(ax3, 'off');
        xlim(ax3, [1, size(allDiam,2)]);
        xlabel(ax3, 'Frame');
        ylabel(ax3, ['Avg diam (' diamLbl ')']);
        legend(ax3, 'Location', 'best');
        title(ax3, 'Average diameter');
        grid(ax3, 'on');

        % ---- ax4: average perivascular calcium dF/F0 (only if run) ----------
        % Written by Kira Shaw with Claude Code, Aug 2026 - same branch-by-
        % branch colour coding as ax3, mirroring the live GUI's caAx. Shows
        % dF/F0 (background-ring subtracted, sliding-baseline normalised),
        % same choice as the live plot - raw/background/background-corrected
        % are all still in the data export, just not plotted here.
        if caPresent
            hold(ax4, 'on');
            for b = 1:nB
                if b > numel(s.cont_calcium_dFF) || isempty(s.cont_calcium_dFF{b}), continue; end
                col       = BC{mod(b-1,5)+1};
                frameVecB = 1:size(s.cont_calcium_dFF{b}, 2);
                plot(ax4, frameVecB, nanmean(s.cont_calcium_dFF{b}, 1), '-', ...
                    'Color', col, 'LineWidth', 2, ...
                    'DisplayName', sprintf('Branch %d', b));
            end
            hold(ax4, 'off');
            xlabel(ax4, 'Frame');
            ylabel(ax4, 'Perivascular \DeltaF/F_0');
            legend(ax4, 'Location', 'best');
            title(ax4, 'Average perivascular calcium (\DeltaF/F_0)');
            grid(ax4, 'on');
        end

        % ---- save dialog ----------------------------------------------------
        [fn, fp] = uiputfile( ...
            {'*.png','PNG image'; '*.pdf','PDF'; '*.fig','MATLAB figure'}, ...
            'Save figure', fullfile(s.expDir, 'MAPS_figure'));
        if ~isequal(fn, 0)
            saveas(expFig, fullfile(fp, fn));
            postUpdate(['Figure saved: ' fullfile(fp, fn)]);
        end
    end

    % -------------------------------------------------------------------------
    function cb_reset()
    % Resets the GUI back to the state it's in when first launched: discards
    % all loaded/analysed data across all three analysis modes. Genuinely
    % relaunches a fresh instance rather than hand-resetting every field/
    % control individually, which would risk silently missing one as the
    % app grows - relaunching guarantees exact parity with a fresh launch,
    % with no drift risk (Kira Shaw with Claude Code, Aug 2026).
        choice = uiconfirm(fig, ...
            'Reset the GUI? This discards all loaded/analysed data for every tab.', ...
            'Reset MAPS', 'Options', {'Reset', 'Cancel'}, ...
            'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning');
        if ~strcmp(choice, 'Reset'), return; end
        oldFig = fig;
        MAPS();
        close(oldFig);
    end

    % =========================================================================
    %  HELPERS
    % =========================================================================
    function postUpdate(msg)
        lblUpdatesError.Visible = 'off';   % clear any standing red-bold error
        txaUpdates.Value = msg;
        drawnow;
    end

    function postError(msg)
    % Red bold error in the Processing updates area (uitextarea can't do
    % rich text itself, so this is an overlay label shown in its place
    % until the next postUpdate()) - Kira Shaw with Claude Code, Aug 2026.
        lblUpdatesError.Text    = msg;
        lblUpdatesError.Visible = 'on';
        drawnow;
    end

    function refreshDisplay(s, skels, masks)
        % show frame50, overlay any drawn skeletons + ROI boundaries
        if isempty(s.frame50), return; end
        cla(dispAx);
        imagesc(dispAx, s.frame50);
        colormap(dispAx, 'gray');
        axis(dispAx, 'image');
        dispAx.XTick = [];  dispAx.YTick = [];

        if isempty(skels) && isempty(masks)
            dispAx.Title.String = 'pending processing';
            dispAx.Title.Color  = [0.55 0.55 0.55];
        else
            dispAx.Title.String = '';
        end

        hold(dispAx, 'on');
        for b = 1:numel(skels)
            col = BC{mod(b-1,5)+1};
            [sy, sx] = find(skels{b});
            scatter(dispAx, sx, sy, 2, repmat(col, numel(sx),1), 'filled');
        end
        for b = 1:numel(masks)
            col = BC{mod(b-1,5)+1};
            bnd = bwboundaries(masks{b});
            if ~isempty(bnd)
                plot(dispAx, bnd{1}(:,2), bnd{1}(:,1), '-', ...
                    'Color', col, 'LineWidth', 2.5);
            end
        end
        hold(dispAx, 'off');
    end

    % =========================================================================
    %  ZSTACK HELPERS  (Written by Kira Shaw with Claude Code, Aug 2026)
    % =========================================================================
    function renderZFrame(s, fastMode)
        % Show the current z-slice, thresholded if the frame falls inside a
        % segment, raw otherwise.
        %
        % Written by Kira Shaw with Claude Code, Aug 2026. fastMode (true
        % while actively dragging either slider) skips the mask cleanup
        % and skeleton preview below - running that morphology + bwskel on
        % every tick of a drag was what made both sliders feel slow and
        % made it hard to judge a threshold value while moving the slider.
        % A full-quality render (cleanup + skeleton) always follows once
        % the slider settles (ValueChangedFcn on both sliders).
        if nargin < 2, fastMode = false; end
        if isempty(s.zRaw), return; end
        frame = squeeze(s.zRaw(s.zCurrentFrame, :, :));

        idx = getActiveSegmentIdx(s.zSegments, s.zCurrentFrame);
        cla(dispAx);
        if isempty(idx)
            imagesc(dispAx, frame);
            colormap(dispAx, 'gray');
            dispAx.Title.String = sprintf('Frame %d / %d  (raw)', ...
                s.zCurrentFrame, s.zNumFrames);
        else
            seg = s.zSegments(idx);
            % Written by Kira Shaw with Claude Code, Aug 2026. While a
            % range is pending (Start range clicked, End range not yet)
            % and Manual threshold is ticked, preview the SLIDER's live
            % value instead of the stored segment's - the segment itself
            % is deliberately left untouched during this phase (see
            % cb_manualThreshChanged/cb_manualSliderChanging), specifically
            % so dragging the slider while defining a new range can't leak
            % into whatever's left over once the range is actually applied.
            if ~isempty(s.zRangeStart) && chkManualThresh.Value
                threshVal  = sldManualThresh.Value;
                threshMode = 'manual (pending)';
            else
                threshVal  = seg.value;
                threshMode = seg.mode;
            end
            % preview from zWorkVol (not zRaw) so this matches what
            % buildBinaryVolume will actually threshold when smoothing is on
            workFrame = squeeze(s.zWorkVol(s.zCurrentFrame, :, :));
            BW2D = workFrame >= threshVal;

            % ---- clean up the mask before displaying/skeletonising
            % (Written by Kira Shaw with Claude Code, Aug 2026) - mirrors
            % the 3D pipeline's cleanup (buildBinaryVolume's imfill/
            % bwareaopen, plus the morphological open/close in
            % cb_zAnalyze). Without it, a raw per-frame threshold is too
            % speckled/fragmented for bwskel to trace a clean line down a
            % vessel - it spirals through/fills the noisy blob instead,
            % which is exactly what was showing up in the "Skeleton
            % preview" overlay. Also makes the displayed threshold preview
            % itself a more honest match for what "Process Stack" will
            % actually build from, not just the skeleton overlay. Skipped
            % in fastMode - see note above.
            if ~fastMode && any(BW2D(:))
                BW2D = imfill(BW2D, 'holes');
                BW2D = bwareaopen(BW2D, 6, 8);
                pxsz_preview = str2double(efPxsz.Value);
                if ~isnan(pxsz_preview) && pxsz_preview > 0
                    smoothRadiusPx = max(1, round(2 / pxsz_preview));  % same 2 um default as the 3D pipeline
                    se2D = strel('disk', smoothRadiusPx);
                    BW2D = imclose(BW2D, se2D);
                    BW2D = imopen(BW2D, se2D);
                end
            end

            imagesc(dispAx, BW2D);
            dispAx.CLim = [0 1];
            colormap(dispAx, [0 0 0; 1 1 1]);
            % kept short - Written by Kira Shaw with Claude Code, Aug 2026
            % - this sits right above a fairly narrow display and was
            % getting cut off when the skeleton-preview detail used to be
            % appended here too; that detail now goes to the "Processing
            % updates" bar instead (see below), which is much wider.
            titleStr = sprintf('Frame %d / %d  (%s threshold %.4g)', ...
                s.zCurrentFrame, s.zNumFrames, threshMode, threshVal);

            % ---- live skeleton preview overlay (Written by Kira Shaw with
            % Claude Code, Aug 2026) - a quick 2D skeleton of just this
            % frame's binarised image, so nudging Prune length shows its
            % effect immediately without running the full 3D pipeline.
            % Approximate (2D, this one frame only) - not a substitute for
            % "Process Stack", just a fast visual guide for tuning pruning.
            % Skipped in fastMode, and only posts to the RHS status bar on
            % a full render - not on every tick while dragging.
            if ~fastMode && isfield(s, 'zSkelPreview') && s.zSkelPreview
                pruneVox = efPruneLen.Value;
                if isnan(pruneVox) || pruneVox < 0, pruneVox = 0; end
                skel2D = bwskel(BW2D, 'MinBranchLength', pruneVox);
                hold(dispAx, 'on');
                [sy, sx] = find(skel2D);
                plot(dispAx, sx, sy, '.', 'Color', [1 0.15 0.15], 'MarkerSize', 4);
                hold(dispAx, 'off');
                postUpdate(sprintf(['Frame %d / %d  |  %s threshold %.4g  |  ' ...
                    'skeleton preview, prune %.3g vox'], ...
                    s.zCurrentFrame, s.zNumFrames, threshMode, threshVal, pruneVox));
            end

            % ---- live boundary-restricted outline preview (Written by
            % Kira Shaw with Claude Code, Aug 2026) - when "Vessel
            % boundary" is ticked, show this frame's convex hull (the same
            % per-frame boundary computeBoundaryRestrictedVolume uses) as a
            % dotted, semi-transparent yellow line, matching
            % lblDensityBoundary's BOUNDARY_YELLOW results-box colour, so
            % it's obvious while previewing which region "Process Stack"
            % will restrict the 2nd density/distance measure to. 2D, this
            % frame only - a quick visual guide, not the actual per-frame
            % computation (that only runs, on the original unresampled
            % mask, inside "Process Stack").
            if ~fastMode && chkBoundaryRestrict.Value && any(BW2D(:))
                hullBW = bwconvhull(BW2D);
                Bhull = bwboundaries(hullBW);
                hold(dispAx, 'on');
                for bIdx = 1:numel(Bhull)
                    outline = Bhull{bIdx};   % [row col] = [y x]
                    plot(dispAx, outline(:,2), outline(:,1), ...
                        'Color', [0.80 0.65 0.00 0.65], 'LineStyle', ':', 'LineWidth', 1.5);
                end
                hold(dispAx, 'off');
            end
            dispAx.Title.String = titleStr;
        end
        axis(dispAx, 'image');
        dispAx.XTick = [];  dispAx.YTick = [];
        dispAx.Title.Color = [0.45 0.45 0.45];
    end

    function idx = getActiveSegmentIdx(segments, frameIdx)
        % Index of the segment covering frameIdx, or [] if none (no threshold).
        idx = [];
        for i = 1:numel(segments)
            if frameIdx >= segments(i).startF && frameIdx <= segments(i).endF
                idx = i;
                return;
            end
        end
    end

    function val = computeThreshold(s, region, method)
        % Auto threshold on region, in the stack's own raw units. Normalised
        % against the WHOLE working volume's min/max (not just region's own)
        % so thresholds computed for different frame-ranges stay comparable.
        % Uses zWorkVol (raw, or Gaussian-smoothed if smoothing is on) so
        % the threshold is computed on the same data it will be applied to.
        lo = min(s.zWorkVol(:));
        hi = max(s.zWorkVol(:));
        if hi <= lo
            val = lo;
            return;
        end
        normRegion = (double(region) - lo) / (hi - lo);

        switch method
            case 'IsoData'
                level = isoDataThreshold(normRegion);
            case 'Triangle'
                level = triangleThreshold(normRegion);
            otherwise   % 'Otsu (recommended)'
                level = graythresh(normRegion);
        end
        val = level * (hi - lo) + lo;
    end

    function method = currentMethodName()
        % strip the "(recommended)" suffix shown in the dropdown, for
        % passing to computeThreshold / for messages
        method = strtrim(regexprep(ddThreshMethod.Value, '\(recommended\)', ''));
    end

    function refreshSegmentsTable(s)
        n = numel(s.zSegments);
        data = cell(n, 4);
        for i = 1:n
            data{i,1} = s.zSegments(i).startF;
            data{i,2} = s.zSegments(i).endF;
            data{i,3} = s.zSegments(i).mode;
            data{i,4} = s.zSegments(i).value;
        end
        tblSegments.Data = data;
    end

    function txt = statsLine(vals, unit, nLabel)
        % One-line "mean (SD ...), nLabel=count" summary for a plot title -
        % range dropped, n labelled by what it's actually counting rather
        % than a bare "n=" (Written by Kira Shaw with Claude Code, Aug
        % 2026) - e.g. 'nVess=' for a per-branch stat, 'nVox=' for the
        % distance-to-vessel sample, so it's clear at a glance without
        % having to know which plot counts what.
        vals = vals(:);
        vals = vals(~isnan(vals));
        if isempty(vals)
            txt = sprintf('%s0', nLabel);
            return;
        end
        if isempty(unit)
            txt = sprintf('mean %.3g (SD %.3g), %s%d', mean(vals), std(vals), nLabel, numel(vals));
        else
            txt = sprintf('mean %.3g %s (SD %.3g), %s%d', mean(vals), unit, std(vals), nLabel, numel(vals));
        end
    end

    function txt = nLine(vals, nLabel)
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Just the count - for the live GUI's plot titles, which are
        % narrower than the exported figure's and get crowded by the full
        % mean/SD summary (see statsLine, used for the export figure).
        % Labelled by what it's counting (nLabel, e.g. 'nVess=' or
        % 'nVox='), not a bare "n=", per Kira's request - it wasn't
        % obvious at a glance whether a given plot's n was vessels or
        % voxels.
        vals = vals(:);
        txt = sprintf('%s%d', nLabel, sum(~isnan(vals)));
    end

    function resetDensityDisplay()
        lblDensity.Text = {'Full tissue:', 'run "Process Stack" first'};
        lblDensityBoundary.Text = {'Boundary restricted:', ''};
        cla(axSkel);  cla(axDist);  cla(axDiamDepth);  cla(axLengthDepth);
        cla(axDistHist);  cla(axTortDepth);
        title(axSkel, 'Skeleton  (max projection)');
        title(axDist, 'Distance to nearest vessel  (max projection, um)');
        title(axDiamDepth, 'Diameter by depth');
        title(axLengthDepth, 'Length by depth');
        title(axDistHist, 'Distance to nearest vessel');
        title(axTortDepth, 'Tortuosity by depth');
        % blank until the next successful "Process Stack" -
        % see zstackResultsH (Written by Kira Shaw with Claude Code, Aug 2026)
        for h = zstackResultsH, h.Visible = 'off'; end
    end

    function BW = buildBinaryVolume(s)
        % Apply each segment's threshold to its own frame range, producing
        % one logical volume the same size as s.zRaw. Thresholds against
        % zWorkVol (raw, or Gaussian-smoothed if smoothing is on).
        BW = false(size(s.zRaw));
        for i = 1:numel(s.zSegments)
            seg = s.zSegments(i);
            BW(seg.startF:seg.endF, :, :) = ...
                s.zWorkVol(seg.startF:seg.endF, :, :) >= seg.value;
        end

        % ---- clean up the thresholded mask before it's skeletonised ---------
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % A raw voxel-wise threshold leaves small holes and salt-and-pepper
        % speckle in the mask; bwskel's medial-axis estimate follows that
        % raggedness rather than the vessel centre. imfill only ADDS voxels
        % (fills fully-enclosed background), so it can't lose vessel - safe
        % unconditionally. bwareaopen REMOVES whole connected components
        % below the given size, which is a much bigger risk here than the
        % "3x3x3 speck" it sounds like: z-slices are often several microns
        % apart while xy pixels are under a micron, so a thin real vessel's
        % per-slice cross-sections can easily fail to be 26-connected
        % across z and end up as many small components, each under even a
        % modest voxel count - an earlier, too-high cutoff (27) wiped out
        % entire vessel networks this way. Kept small (6 vox - true
        % single/couple-voxel noise only) and guarded: if it still removes
        % most of the mask, skip it and use the filled-only mask instead of
        % silently handing bwskel a near-empty volume.
        if any(BW(:))
            BW = imfill(BW, 'holes');
            nBefore = nnz(BW);
            BWclean = bwareaopen(BW, 6, 26);
            if nnz(BWclean) < 0.5 * nBefore
                postUpdate(['Despeckle step skipped (would have removed too much ' ...
                    'of the thresholded mask) - using filled mask as-is.']);
            else
                BW = BWclean;
            end
        end
    end

    function s = refreshZWorkVol(s)
        % Written by Kira Shaw with Claude Code, Aug 2026.
        % Rebuilds zWorkVol - the volume threshold/skeleton logic reads
        % from - as double(zRaw), Gaussian-smoothed (imgaussfilt3) if
        % smoothing is on. zRaw itself is never touched, so "raw" display
        % always shows the true data regardless of this setting.
        if isempty(s.zRaw)
            s.zWorkVol = [];
        elseif s.zSmooth
            sigma = max(0.1, s.zSmoothSigma);
            s.zWorkVol = imgaussfilt3(double(s.zRaw), sigma);
        else
            s.zWorkVol = double(s.zRaw);
        end
    end

    % =========================================================================
    %  LINESCAN CALLBACKS  (Written by Kira Shaw with Claude Code, Aug 2026)
    %
    %  DATA CONVENTION (matches original extractLinescanVelocity.m):
    %  rawLine = [nSp x (nT*nF)]
    %    rows  = spatial pixels along the scan line  (Y-axis, portrait, many)
    %    cols  = scan-line repetitions / time        (X-axis, few per frame)
    %  Frame f occupies columns (f-1)*nT+1 : f*nT.
    %  Window w occupies columns (w-1)*stepPx+1 : (w-1)*stepPx+winPx.
    %  For Radon (expects [time x spatial]), always pass win_data' (transpose).
    % =========================================================================

    % -------------------------------------------------------------------------
    function renderLsFrame(s)
    % Show current frame in dispAx: rows=time (Y, top→bottom), cols=spatial (X).
    % Binary frame shown simultaneously in lsBinaryAx at same orientation.
    % Window = horizontal yellow band on both images.
        if isempty(s.lsRawLine), return; end
        nT = s.lsNumTime;    % scan reps per frame → rows in display
        nSp = s.lsNumSpatial;% spatial pixels  → cols in display
        nF = s.lsNumFrames;
        f  = max(1, min(nF, s.lsCurrentFrame));
        c0 = (f-1)*nT + 1;
        c1 = f*nT;
        % Transpose: rawLine is [nSp × nT], display wants [nT × nSp]
        frame_data = s.lsRawLine(:, c0:c1)';  % [nT × nSp]: time on Y, space on X

        imagesc(dispAx, frame_data);
        colormap(dispAx, 'gray');
        axis(dispAx, 'image');
        % Row 1 (earliest time) must render at the TOP. Reverted back to
        % 'reverse' - the intervening switch to 'normal' was disproven by
        % an actual rendered/exported test image (a known-gradient frame
        % with this exact imagesc+rectangle code: 'normal' put row 1 at the
        % BOTTOM, confirmed both by the gradient shading and by Kira Shaw's
        % screenshot of window 1 sitting at the bottom right after Load
        % Data), while the same test with 'reverse' put row 1 exactly at
        % the top. The slider's inverted sync/drag formulas were already
        % the correct pairing for 'reverse' and are untouched here (Kira
        % Shaw with Claude Code, Aug 2026).
        dispAx.YDir = 'reverse';
        xlabel(dispAx, 'Spatial pixel');
        ylabel(dispAx, 'Scan line (time ↓)');
        title(dispAx, sprintf('Raw  —  frame %d / %d', f, nF));
        % Match lsBinaryAx's title size (set once at its declaration) - dispAx
        % otherwise falls back to uiaxes' larger default title font, making
        % "Raw" and "Binary" look like mismatched-size panels even though
        % the axes themselves are already the same size (Kira Shaw with
        % Claude Code, Aug 2026).
        dispAx.Title.FontSize = F(9);

        % Window indicator: horizontal band (spans all X, covers window rows in Y)
        winPx  = s.lsWindowSz_px;
        stepPx = s.lsStepSz_px;
        w      = s.lsCurrentWin;
        abs_c0 = 1 + (w-1)*stepPx;   % absolute time-col start of window
        abs_c1 = abs_c0 + winPx - 1;
        % map to frame-local row in the transposed display (row = time step)
        lr0 = abs_c0 - c0 + 1;
        lr1 = abs_c1 - c0 + 1;
        if lr1 >= 1 && lr0 <= nT
            y0 = max(1, lr0) - 0.5;
            y1 = min(nT, lr1) + 0.5;
            hold(dispAx, 'on');
            rectangle(dispAx, 'Position', [0.5 y0 nSp y1-y0], ...
                'EdgeColor', [1 0.8 0], 'LineWidth', 2, 'LineStyle', '--');
            hold(dispAx, 'off');
        end

        % Sync the per-frame vertical window slider, and its live value
        % readout (1 at top, maxLr at bottom). INVERTED mapping restored -
        % the dispAx.YDir flip above was the only change actually needed to
        % fix the rectangle's direction; the slider is a separate widget
        % with its own native min=bottom/max=top convention, independent of
        % any axes' YDir, so removing ITS inversion too was a second,
        % unneeded flip that put the slider (and the window it feeds to the
        % preview/RBC detection) out of sync with the now-correct rectangle
        % - confirmed by Kira Shaw: box direction fixed, but slider resting
        % position and RBC counts were then wrong. Restored to match the
        % rectangle again (Kira Shaw with Claude Code, Aug 2026).
        if winPx > 0 && nT > 0
            maxLr = max(2, nT - winPx + 1);
            lsWinVertSlider.Limits = [1, maxLr];
            lr0_clamped = max(1, min(maxLr, lr0));
            lsWinVertSlider.Value = max(1, min(maxLr, maxLr - lr0_clamped + 1));
            lblLsWinVertVal.Text = sprintf('%d/%d', lr0_clamped, maxLr);
        end

        % Update binary panel to match this frame
        ls_refreshBinaryDisplay(s);
    end

    % -------------------------------------------------------------------------
    function renderLsWindow(s)
    % Show current window in lsWinAx: rows=time (Y, top→bottom), cols=spatial (X).
    % Same orientation as the frame display above. Overlays angle line / RBC dots.
        if isempty(s.lsRawLine), return; end
        winPx  = s.lsWindowSz_px;
        stepPx = s.lsStepSz_px;
        w      = s.lsCurrentWin;
        c0     = 1 + (w-1)*stepPx;
        c1     = c0 + winPx - 1;
        nTot   = size(s.lsRawLine, 2);
        c1     = min(c1, nTot);
        if c0 > nTot || c0 >= c1, return; end

        % Transpose to [winPx × nSp]: time on Y, spatial on X
        win_data = s.lsRawLine(:, c0:c1)';
        imagesc(lsWinAx, win_data);
        colormap(lsWinAx, 'gray');
        axis(lsWinAx, 'image');
        lsWinAx.YDir = 'reverse';   % row 1 (earliest time) at top - see dispAx above
        xlabel(lsWinAx, 'Spatial pixel');
        ylabel(lsWinAx, 'Scan line (time ↓)');
        title(lsWinAx, sprintf('Window %d  (lines %d-%d)', w, c0, c0+size(win_data,1)-1));

        % Angle line: in display X=spatial, Y=time.
        % Radon coarse_angle is measured from the Y-axis (time axis).
        % streak direction: dx_spatial = sin(coarse_angle), dy_time = cos(coarse_angle).
        if s.lsAngleChecked && ~isempty(lblLsAngleResult.UserData)
            raw_angle = lblLsAngleResult.UserData;
            nR = size(win_data, 1);   % winPx (time, Y)
            nC = size(win_data, 2);   % nSp   (spatial, X)
            xc = nC/2;  yc = nR/2;
            L  = min(nR, nC) * 0.40;
            dx = L * sind(raw_angle);
            dy = L * cosd(raw_angle);
            hold(lsWinAx, 'on');
            plot(lsWinAx, [xc-dx xc+dx], [yc-dy yc+dy], 'r-', 'LineWidth', 2);
            hold(lsWinAx, 'off');
        end

        % RBC count — count dark/light transitions along thin strips at BOTH
        % the left and right edges of the window, rather than a whole-window
        % 2D blob count. RBCs cross the window as diagonal dark streaks
        % (space vs time), so a 2D connected-component count is fragile: a
        % single streak can come out as several small disconnected blobs
        % (killed by the area-floor filter, as happened here - 2 or 3
        % clearly visible streaks scored as 0) or several streaks can touch
        % and merge into one blob. Sampling an edge instead - exactly like
        % the batch flux calculation in cb_lsGo already does at the centre
        % column - turns each streak into one clean dark run. Using BOTH
        % edges (widened from 3 to 5 px each) and averaging their counts
        % rather than just the right edge: a streak that's faint or exits
        % the window's top/bottom before reaching one edge can still be
        % caught by the other, and closely-spaced streaks that blur together
        % on one edge often separate cleanly on the other (Kira Shaw with
        % Claude Code, Aug 2026).
        if s.lsRBCActive && s.lsBinarised && ~isempty(s.lsBinaryLine)
            binWin = s.lsBinaryLine(:, c0:min(c1, size(s.lsBinaryLine,2)))';  % [winPx x nSp]
            nC = size(binWin, 2);
            edgeW = min(5, max(1, floor(nC/2)));   % a few px each side, widened from 3

            [nRBC_R, rs_R, re_R] = countEdgeDarkRuns(binWin(:, end-edgeW+1:end));
            [nRBC_L, rs_L, re_L] = countEdgeDarkRuns(binWin(:, 1:edgeW));
            nRBC = round((nRBC_R + nRBC_L) / 2);

            if ~isempty(rs_R)
                cy = (rs_R + re_R) / 2;  cx = repmat(nC - (edgeW-1)/2, numel(rs_R), 1);
                hold(lsWinAx, 'on');  plot(lsWinAx, cx, cy, 'r.', 'MarkerSize', 18);  hold(lsWinAx, 'off');
            end
            if ~isempty(rs_L)
                cy = (rs_L + re_L) / 2;  cx = repmat((edgeW+1)/2, numel(rs_L), 1);
                hold(lsWinAx, 'on');  plot(lsWinAx, cx, cy, 'm.', 'MarkerSize', 18);  hold(lsWinAx, 'off');
            end

            lblLsRBCResult.FontColor = [0.08 0.45 0.08];
            lblLsRBCResult.Text = sprintf(...
                'RBCs in window: %d  (L=%d magenta, R=%d red, avg)', nRBC, nRBC_L, nRBC_R);
            lblLsRBCResult.Visible = 'on';
        end
    end

    % -------------------------------------------------------------------------
    function cb_lsFrameSlider(value, fastMode)
        if nargin < 2, fastMode = false; end
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine), return; end
        f = max(1, min(s.lsNumFrames, round(value)));
        s.lsCurrentFrame = f;
        lblLsFrame.Text  = sprintf('%d / %d', f, s.lsNumFrames);
        % Keep window at the same vertical position within the frame
        % (read from the per-frame vert slider rather than jumping to centre)
        nT     = s.lsNumTime;
        winPx  = s.lsWindowSz_px;
        stepPx = s.lsStepSz_px;
        maxLr  = max(1, nT - winPx + 1);
        slVal  = lsWinVertSlider.Value;
        lr0 = max(1, min(maxLr, maxLr - round(slVal) + 1));  % inverted - see renderLsFrame sync
        abs_c0 = (f-1)*nT + lr0;
        w = max(1, min(s.lsNumWins, round((abs_c0-1)/stepPx) + 1));
        s.lsCurrentWin    = w;
        lsWinSlider.Value = min(w, lsWinSlider.Limits(2));
        lblLsWin.Text     = sprintf('Win %d / %d', w, s.lsNumWins);
        % Any angle-check result on screen was for a different window - clear
        % it rather than leave it shown as if still valid; the window preview
        % (image + RBC dots) always refreshes below, on every slide tick
        % (this used to be skipped during dragging, and for this slider
        % specifically skipped on release too, which was the reported "window
        % display doesn't update" bug - Kira Shaw with Claude Code, Aug 2026).
        s.lsAngleChecked      = false;
        lblLsAngleResult.Text = '';
        lblLsAngleRight.Text  = '';
        setappdata(fig, 'state', s);
        renderLsFrame(s);
        renderLsWindow(s);
    end

    % -------------------------------------------------------------------------
    function cb_lsWinSlider(value, fastMode)
        if nargin < 2, fastMode = false; end
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine), return; end
        w = max(1, min(s.lsNumWins, round(value)));
        s.lsCurrentWin = w;
        lblLsWin.Text  = sprintf('Win %d / %d', w, s.lsNumWins);
        % update frame to the one that contains this window centre
        nT         = s.lsNumTime;
        win_c_abs  = 1 + (w-1)*s.lsStepSz_px + round(s.lsWindowSz_px/2);
        f = max(1, min(s.lsNumFrames, floor((win_c_abs-1)/nT) + 1));
        s.lsCurrentFrame    = f;
        lsFrameSlider.Value = f;
        lblLsFrame.Text     = sprintf('%d / %d', f, s.lsNumFrames);
        s.lsAngleChecked      = false;
        lblLsAngleResult.Text = '';
        lblLsAngleRight.Text  = '';
        setappdata(fig, 'state', s);
        renderLsFrame(s);
        renderLsWindow(s);
    end

    % -------------------------------------------------------------------------
    function cb_lsWinSzChanged()
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine), return; end
        winMs_new = efLsWinSz.Value;
        if isnan(winMs_new) || winMs_new <= 0
            efLsWinSz.Value = s.lsWindowSz_ms;
            return;
        end
        % Window size (ms) must be divisible by 4, so the derived pixel
        % window/step (winPx, winPx/4) stay whole numbers - flagged in red
        % bold rather than silently rounded, and reverts to the last valid
        % value (Kira Shaw with Claude Code, Aug 2026).
        if mod(winMs_new, 4) ~= 0
            postError('Window size must be divisible by 4.');
            efLsWinSz.Value = s.lsWindowSz_ms;
            return;
        end
        if ~isnan(s.lsMspline) && s.lsMspline > 0
            winPx_new = round((winMs_new / s.lsMspline) / 4) * 4;
        else
            winPx_new = round(winMs_new / 4) * 4;
        end
        winPx_new = max(4, winPx_new);
        stepPx_new = max(1, round(0.25 * winPx_new));
        nTot = size(s.lsRawLine, 2);   % total time columns
        nWins_new = max(1, floor(nTot / stepPx_new) - 3);
        s.lsWindowSz_ms = winMs_new;
        s.lsWindowSz_px = winPx_new;
        s.lsStepSz_px   = stepPx_new;
        s.lsNumWins     = nWins_new;
        s.lsCurrentWin  = min(s.lsCurrentWin, nWins_new);
        lsWinSlider.Limits = [1, max(2, nWins_new)];
        lsWinSlider.Value  = s.lsCurrentWin;
        lblLsWin.Text = sprintf('Win %d / %d', s.lsCurrentWin, nWins_new);
        setappdata(fig, 'state', s);
        renderLsFrame(s);
        renderLsWindow(s);
    end

    % -------------------------------------------------------------------------
    function cb_lsWinVertSlider(value, fastMode)
    % Vertical slider on the left of the linescan display: moves the yellow window
    % band up/down within the current frame without changing the frame.
    % Inverted mapping (slider top/high value = window at top of frame) -
    % see the matching restoration note in renderLsFrame's sync block
    % (Kira Shaw with Claude Code, Aug 2026).
        if nargin < 2, fastMode = false; end
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine), return; end
        nT     = s.lsNumTime;
        winPx  = s.lsWindowSz_px;
        stepPx = s.lsStepSz_px;
        f      = s.lsCurrentFrame;
        maxLr  = max(1, nT - winPx + 1);
        lr0 = max(1, min(maxLr, maxLr - round(value) + 1));  % inverted - see renderLsFrame sync
        % convert local row in frame to absolute time column, then to window index
        abs_c0 = (f-1)*nT + lr0;
        w = max(1, min(s.lsNumWins, round((abs_c0-1)/stepPx) + 1));
        s.lsCurrentWin    = w;
        lsWinSlider.Value = min(w, lsWinSlider.Limits(2));
        lblLsWin.Text     = sprintf('Win %d / %d', w, s.lsNumWins);
        s.lsAngleChecked      = false;
        lblLsAngleResult.Text = '';
        lblLsAngleRight.Text  = '';
        setappdata(fig, 'state', s);
        renderLsFrame(s);
        renderLsWindow(s);
    end

    % -------------------------------------------------------------------------
    function cb_lsCheckAngle()
    % Quick Radon on current window to detect scan direction and signal quality.
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine)
            uialert(fig, 'Load a linescan file first.', 'No data');
            return;
        end
        % Angle-check is a one-shot per-window computation, not auto-recomputed
        % on slide (the radon transform here is too expensive to run on every
        % drag tick) - the slider callbacks clear the result as soon as the
        % user moves away from this window, so re-click here for wherever
        % they land (Kira Shaw with Claude Code, Aug 2026).
        c0 = 1 + (s.lsCurrentWin-1)*s.lsStepSz_px;
        c1 = min(c0+s.lsWindowSz_px-1, size(s.lsRawLine,2));
        win_data = s.lsRawLine(:, c0:c1);   % [nSp x winPx]

        % For Radon, transpose to [winPx x nSp] (time in rows) then apply
        % two-way mean subtraction
        wd = win_data';   % [winPx x nSp]
        wd = wd - mean(wd,1) - mean(wd,2) + mean(wd(:));

        if var(wd(:)) < eps
            msg = 'Window is uniform — no signal to analyse.';
            lblLsAngleResult.Text = msg;
            lblLsAngleRight.Text  = msg;
            postUpdate(['Angle check: ' msg]);
            return;
        end

        % Coarse then fine Radon
        R_c = radon(wd, 0:179);
        all_var = var(R_c);
        [~, idx_c] = max(all_var);
        coarse_angle = idx_c - 1;
        R_f = radon(wd, coarse_angle + (-3:0.1:3));
        [~, idx_f] = max(var(R_f));
        fine_total   = coarse_angle + (-3:0.1:3);
        fine_total   = fine_total(idx_f);
        theta        = -1*(fine_total - 90);

        % Signal quality: peak/median variance ratio
        snr = max(all_var) / max(median(all_var), eps);

        if snr < 3
            direction = 'noisy';
            dirTxt    = 'NOISY — do not proceed with analysis';
            postUpdate(sprintf('Angle check: SNR=%.1f (too low). Check imaging quality.', snr));
        elseif theta > 2
            direction = 'retrograde';
            % Slant description + correction recommendation confirmed
            % empirically against this exact Radon pipeline, then set by
            % Kira Shaw's own rule from direct RBC-slant observation:
            % higher-LHS/lower-RHS <-> positive theta/vel_app <-> this
            % 'retrograde' branch <-> correction recommended (Aug 2026).
            dirTxt = sprintf(['Retrograde scan  (%.1f deg, SNR=%.0f)   ' ...
                char(8600) ' RBC slant: higher-LHS, lower-RHS - Vscan ' ...
                'correction RECOMMENDED (Chaigneau & Charpak, 2022)'], theta, snr);
        elseif theta < -2
            direction = 'anterograde';
            dirTxt = sprintf(['Anterograde/wrong-way scan  (%.1f deg, SNR=%.0f)   ' ...
                char(8599) ' RBC slant: lower-LHS, higher-RHS - Vscan ' ...
                'correction NOT recommended'], theta, snr);
        else
            direction = 'uncertain';
            dirTxt    = sprintf('Direction uncertain  (|theta|<2 deg, SNR=%.0f)', snr);
        end

        lblLsAngleResult.UserData = coarse_angle;
        lblLsAngleResult.Text     = dirTxt;
        lblLsAngleRight.Text      = ['Direction: ' dirTxt];
        s.lsAngleChecked = ~strcmp(direction, 'noisy');
        setappdata(fig, 'state', s);
        renderLsWindow(s);
    end

    % -------------------------------------------------------------------------
    function cb_lsBinarise()
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine)
            uialert(fig, 'Load a linescan file first.', 'No data');
            return;
        end
        thresh         = sldLsThresh.Value;
        s.lsThresh     = thresh;
        s.lsBinaryLine = s.lsRawLine >= thresh;   % true=bright (plasma)
        s.lsBinarised  = true;
        setappdata(fig, 'state', s);
        % Refresh both panels from the same state together (renderLsFrame
        % redraws dispAx and, at its own end, calls ls_refreshBinaryDisplay
        % too) rather than just the binary one - the raw panel's window
        % rectangle was reported jumping out of sync with the (unaffected)
        % slider on Binarise, and this guarantees the two panels can't
        % desync regardless of the exact cause (Kira Shaw with Claude
        % Code, Aug 2026).
        renderLsFrame(s);
        sldLsThresh.Enable = 'on';
        btnLsRBC.Enable    = 'on';
    end

    % -------------------------------------------------------------------------
    function ls_refreshBinaryDisplay(s)
    % Show binarised frame in lsBinaryAx at same orientation as dispAx:
    % rows=time (Y top→bottom), cols=spatial (X). Also draws the window band.
        if isempty(s.lsBinaryLine), return; end
        nT  = s.lsNumTime;
        nSp = s.lsNumSpatial;
        f   = s.lsCurrentFrame;
        c0  = (f-1)*nT + 1;
        c1  = min(f*nT, size(s.lsBinaryLine, 2));
        if c0 > size(s.lsBinaryLine, 2), return; end
        frame_bin = double(s.lsBinaryLine(:, c0:c1))';  % [nT × nSp]
        imagesc(lsBinaryAx, frame_bin, [0 1]);
        colormap(lsBinaryAx, 'gray');
        axis(lsBinaryAx, 'image');
        lsBinaryAx.YDir = 'reverse';   % matches dispAx above - see its comment
        title(lsBinaryAx, sprintf('Binary  (thresh=%.2f)', s.lsThresh));
        xlabel(lsBinaryAx, 'Spatial pixel');
        ylabel(lsBinaryAx, 'Scan line (time ↓)');

        % Matching window band
        winPx  = s.lsWindowSz_px;
        stepPx = s.lsStepSz_px;
        w      = s.lsCurrentWin;
        abs_c0 = 1 + (w-1)*stepPx;
        lr0    = abs_c0 - c0 + 1;
        lr1    = lr0 + winPx - 1;
        if lr1 >= 1 && lr0 <= nT
            y0 = max(1, lr0) - 0.5;
            y1 = min(nT, lr1) + 0.5;
            hold(lsBinaryAx, 'on');
            rectangle(lsBinaryAx, 'Position', [0.5 y0 nSp y1-y0], ...
                'EdgeColor', [1 0.8 0], 'LineWidth', 2, 'LineStyle', '--');
            hold(lsBinaryAx, 'off');
        end
    end

    % -------------------------------------------------------------------------
    function cb_lsThreshSlider(value, fastMode)
        if nargin < 2, fastMode = false; end
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine), return; end
        s.lsThresh     = value;
        s.lsBinaryLine = s.lsRawLine >= value;
        s.lsBinarised  = true;
        setappdata(fig, 'state', s);
        if ~fastMode
            renderLsFrame(s);   % refreshes both panels together - see cb_lsBinarise
            renderLsWindow(s);
        end
    end

    % -------------------------------------------------------------------------
    function cb_lsRBCToggle()
    % "Detect individual RBCs" is a toggle button (was a checkbox), so its
    % on/off state lives in s.lsRBCActive rather than a .Value property.
    % Toggling it on also updates immediately on the current window, and
    % (since renderLsWindow is what the frame/window sliders call on every
    % slide) keeps updating live as the user moves through the data - same
    % as the angle check (Kira Shaw with Claude Code, Aug 2026).
        s = getappdata(fig, 'state');
        if ~s.lsRBCActive && ~s.lsBinarised
            uialert(fig, 'Binarise the image first before detecting individual RBCs.', ...
                'Binarise First');
            return;
        end
        s.lsRBCActive = ~s.lsRBCActive;
        setappdata(fig, 'state', s);
        if s.lsRBCActive
            lblLsRBCStatus.Text      = 'On';
            lblLsRBCStatus.FontColor = [0.08 0.45 0.08];
        else
            lblLsRBCStatus.Text      = 'Off';
            lblLsRBCStatus.FontColor = [0.45 0.45 0.45];
            lblLsRBCResult.Text      = '';
            lblLsRBCResult.Visible   = 'off';
        end
        renderLsWindow(s);
    end

    % -------------------------------------------------------------------------
    function s = regenLsRawLine(s)
    % Rebuild s.lsRawLine (and dependent counts) from the untouched s.lsRaw,
    % applying s.lsCropRange (spatial px, in ORIGINAL coordinates) if set.
    % Mirrors the rawLine-construction block in the linescan file-load path
    % above; kept in sync with it deliberately (same reshape/normalise
    % steps) so crop/reset never drifts from what a fresh load would give.
    % Only the spatial (width) dimension is ever cropped - time/height is
    % untouched, so mspline/lps/winPx/stepPx/nWins all stay valid as-is
    % (Kira Shaw with Claude Code, Aug 2026).
        if isempty(s.lsCropRange)
            vol = s.lsRaw;
        else
            x0 = s.lsCropRange(1);  x1 = s.lsCropRange(2);
            vol = s.lsRaw(:, x0:x1, :);
        end
        nF  = size(vol, 1);
        nSp = size(vol, 2);
        nT  = size(vol, 3);
        volP = permute(double(vol), [2 3 1]);
        rawLine = reshape(volP, [nSp, nT*nF]);
        p_lo = pctileLocal(rawLine(:), 1);
        p_hi = pctileLocal(rawLine(:), 99);
        if p_hi > p_lo
            rawLine = (rawLine - p_lo) / (p_hi - p_lo);
        end
        rawLine = max(0, min(1, rawLine));
        s.lsRawLine    = rawLine;
        s.lsNumSpatial = nSp;
        s.lsNumFrames  = nF;
        s.lsNumTime    = nT;
    end

    % -------------------------------------------------------------------------
    function cb_lsCropToggle()
    % Width-only crop, optional. Button is a 3-state toggle:
    %   idle    -> start drawing a crop line on the raw display (dispAx)
    %   drawing -> discard the in-progress line, start drawing again
    %              ("redo this if they decide its wrong")
    %   applied -> reset to full width AND immediately start drawing again
    %              ("click the button and repeat should they wish")
    % Only the line's X-extent is used (start/end of crop); Y is ignored,
    % since height encodes time and must never be cropped (Kira Shaw with
    % Claude Code, Aug 2026).
        s = getappdata(fig, 'state');
        if isempty(s.lsRaw)
            uialert(fig, 'Load a linescan file first.', 'No data');
            return;
        end
        if isfield(s,'lsCropROI') && ~isempty(s.lsCropROI) && isvalid(s.lsCropROI)
            delete(s.lsCropROI);
        end
        switch s.lsCropPhase
            case 'applied'
                s.lsCropRange = [];
                s = regenLsRawLine(s);
                s.lsBinarised     = false;  s.lsBinaryLine = [];
                s.lsAngleChecked  = false;
                s.lsRBCActive     = false;
                sldLsThresh.Enable = 'off';
                btnLsRBC.Enable    = 'off';
                lblLsRBCStatus.Text      = 'Off';
                lblLsRBCStatus.FontColor = [0.45 0.45 0.45];
                lblLsRBCResult.Text      = '';
                lblLsRBCResult.Visible   = 'off';
                lblLsAngleResult.Text = '';
                lblLsAngleRight.Text  = '';
                lblLsCropStatus.Text  = 'Not cropped';
                cla(lsBinaryAx);  lsBinaryAx.Title.String = 'Binary (not yet computed)';
                setappdata(fig, 'state', s);
                renderLsFrame(s);
                renderLsWindow(s);
                postUpdate('Crop reset to full width. Draw a new crop line on the raw image, then double-click it to confirm.');
            case 'drawing'
                postUpdate('Redraw the crop line on the raw image, then double-click it to confirm.');
            otherwise % 'idle'
                postUpdate('Draw a line across the width to crop, on the raw (left) image, then double-click it to confirm.');
        end
        roi = drawline(dispAx, 'Color', [1 0.4 0], 'LineWidth', 1.5);
        roi.DoubleClickedFcn = @(src,~) cb_lsCropConfirm(src);
        s.lsCropROI   = roi;
        s.lsCropPhase = 'drawing';
        btnLsCrop.Text = 'Drawing... (dbl-click line)';
        setappdata(fig, 'state', s);
    end

    % -------------------------------------------------------------------------
    function cb_lsCropConfirm(roi)
    % DoubleClickedFcn of the crop ROI: reads its X-extent, applies the crop
    % across the whole dataset, and regenerates raw/binary from it.
        s = getappdata(fig, 'state');
        pos = roi.Position;         % [x1 y1; x2 y2], axes (data) coordinates
        xs  = sort(pos(:,1));
        nSpOrig = size(s.lsRaw, 2);
        x0 = max(1,       round(xs(1)));
        x1 = min(nSpOrig, round(xs(2)));
        delete(roi);
        if (x1 - x0) < 4
            s.lsCropPhase = 'idle';
            s.lsCropROI   = [];
            btnLsCrop.Text = 'Crop (width)';
            setappdata(fig, 'state', s);
            postUpdate('Crop region too small - ignored. Click Crop to try again.');
            return;
        end
        s.lsCropRange = [x0 x1];
        s = regenLsRawLine(s);
        s.lsCropPhase     = 'applied';
        s.lsCropROI       = [];
        s.lsBinarised     = false;  s.lsBinaryLine = [];
        s.lsAngleChecked  = false;
        s.lsRBCActive     = false;
        s.lsCurrentWin    = min(s.lsCurrentWin, s.lsNumWins);
        sldLsThresh.Enable = 'off';
        btnLsRBC.Enable    = 'off';
        lblLsRBCStatus.Text      = 'Off';
        lblLsRBCStatus.FontColor = [0.45 0.45 0.45];
        lblLsRBCResult.Text      = '';
        lblLsRBCResult.Visible   = 'off';
        lblLsAngleResult.Text = '';
        lblLsAngleRight.Text  = '';
        btnLsCrop.Text = 'Crop applied (click to redo)';
        lblLsCropStatus.Text = sprintf('Cropped to px %d-%d of %d', x0, x1, nSpOrig);
        cla(lsBinaryAx);  lsBinaryAx.Title.String = 'Binary (not yet computed)';
        setappdata(fig, 'state', s);
        renderLsFrame(s);
        renderLsWindow(s);
        postUpdate(sprintf(['Crop applied: spatial px %d-%d (of %d original). ' ...
            'Raw/binary regenerated - re-binarise before running analysis.'], x0, x1, nSpOrig));
    end

    % -------------------------------------------------------------------------
    function cb_lsGo()
    % Full sliding-window linescan analysis: velocity, haematocrit, RBC flux.
    % Runs live: resets the LHS to frame 1 / window 1, then steps the raw/
    % binary/window displays through the data in sync with the loop while
    % the three RHS traces grow window-by-window - same live pattern as the
    % xyDiam analysis in cb_go (Kira Shaw with Claude Code, Aug 2026).
        s = getappdata(fig, 'state');
        if isempty(s.lsRawLine)
            uialert(fig, 'Load a linescan file first.', 'No data'); return;
        end
        if ~s.lsBinarised || isempty(s.lsBinaryLine)
            uialert(fig, 'Binarise the image first (click Binarise).', 'Binarise First');
            return;
        end

        % Lock every interactive LHS control for the run: this function calls
        % drawnow repeatedly (for the live view), and drawnow processes any
        % QUEUED UI event - a leftover slider-drag callback fired reentrantly
        % mid-run would call setappdata with its own (stale) state, silently
        % overwriting the current window/frame this loop just set, right in
        % the middle of the analysis. That reentrancy is what produced the
        % "window label says 1, but the rectangle/frame title are somewhere
        % else" symptom seen on screen - disabling inputs for the duration
        % removes the trigger rather than chasing the exact interleaving.
        % Re-enabled in the 'restore' block once the run finishes (Kira Shaw
        % with Claude Code, Aug 2026).
        lsCtrls = [lsFrameSlider, lsWinVertSlider, lsWinSlider, btnLsCheckAngle, ...
            btnLsBinarise, btnLsCrop, btnLsRBC, sldLsThresh, efLsWinSz, ...
            chkLsCharpak, btnLsGo];
        for h = lsCtrls, h.Enable = 'off'; end
        cleanupCtrls = onCleanup(@() set(lsCtrls, 'Enable', 'on'));

        RL      = s.lsRawLine;          % [nSp x (nT*nF)]
        BL      = double(~s.lsBinaryLine);  % 1=dark (RBC), 0=plasma
        winPx   = s.lsWindowSz_px;
        stepPx  = s.lsStepSz_px;
        nWins   = s.lsNumWins;
        mspline = s.lsMspline;           % ms per scan line
        nSp     = s.lsNumSpatial;        % spatial pixels
        nT      = s.lsNumTime;           % scan reps per frame (LHS frame sync)
        pxsz    = s.lsPxsz;

        % deltax: total spatial extent of one scan line in mm (used for
        % Vscan, which is a whole-line rate: total width / total line time)
        if ~isnan(pxsz) && pxsz > 0
            deltax = (nSp-1) * pxsz / 1000;
            pxsz_mm = pxsz / 1000;   % per-pixel spatial size, mm
        else
            deltax = (nSp-1) * 1e-3;
            pxsz_mm = 1e-3;
        end

        Vscan = NaN;
        if ~isnan(mspline) && mspline > 0
            Vscan = deltax / (mspline/1000);
        end

        vel_app  = NaN(nWins, 1);
        hct      = NaN(nWins, 1);
        flux_rbc = NaN(nWins, 1);
        nTotCols = size(RL, 2);

        % Time axis is purely a function of window index/step/mspline (not of
        % the pixel data), so the full X vector is known upfront - like
        % frameVec in cb_go, only the Y values fill in live below.
        kk     = (1:nWins)';
        c0v    = 1 + (kk-1)*stepPx;
        time_s = (c0v + winPx/2 - 1) * mspline / 1000;

        % ---- reset LHS back to frame 1 / window 1 before the run starts ----
        s.lsCurrentFrame = 1;
        s.lsCurrentWin   = 1;
        lsFrameSlider.Value = 1;
        lblLsFrame.Text     = sprintf('1 / %d', s.lsNumFrames);
        lsWinSlider.Value   = 1;
        lblLsWin.Text       = sprintf('Win 1 / %d', nWins);
        % clear any stale angle-check line (was for a since-moved-away-from
        % window) before it starts stepping through - same reasoning as the
        % slider callbacks (Kira Shaw with Claude Code, Aug 2026)
        s.lsAngleChecked      = false;
        lblLsAngleResult.Text = '';
        lblLsAngleRight.Text  = '';
        renderLsFrame(s);
        % The live run specifically needs the OTHER axis direction to sweep
        % correctly - confirmed working before, then broken again when the
        % pre-Run/idle state's direction was fixed separately (both call
        % the same renderLsFrame, which can only set one direction at a
        % time) - Kira Shaw was explicit this is purely a live-display
        % request, scoped only to the run, and that the pre-Run state
        % (fixed via renderLsFrame's own default) should stay as it is.
        % Overridden here, right after every renderLsFrame call for the
        % duration of the run, rather than in renderLsFrame itself (Kira
        % Shaw with Claude Code, Aug 2026).
        dispAx.YDir     = 'normal';
        lsBinaryAx.YDir = 'normal';
        renderLsWindow(s);

        % ---- pre-create the three live trace lines (NaN Y, full X) ---------
        % Line traces only, no per-point markers; NaN values (noisy/skipped
        % windows) naturally break the line rather than being interpolated.
        for h = linescanResultsH, h.Visible = true; end

        cla(lsVelAx);
        hVel = plot(lsVelAx, time_s, NaN(nWins,1), '-', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.3);
        xlabel(lsVelAx, 'Time (s)');  ylabel(lsVelAx, 'Velocity (mm/s)');
        title(lsVelAx, 'Red Blood Cell Velocity  (running...)');
        grid(lsVelAx, 'on');

        cla(lsHctAx);
        hHct = plot(lsHctAx, time_s, NaN(nWins,1), '-', 'Color', [0.55 0.10 0.65], 'LineWidth', 1.3);
        xlabel(lsHctAx, 'Time (s)');  ylabel(lsHctAx, 'Haematocrit (%)');
        title(lsHctAx, 'Haematocrit');
        grid(lsHctAx, 'on');

        cla(lsFluxAx);
        hFlux = plot(lsFluxAx, time_s, NaN(nWins,1), 'g-', 'LineWidth', 1.3);
        xlabel(lsFluxAx, 'Time (s)');  ylabel(lsFluxAx, 'Flux (RBC/s)');
        title(lsFluxAx, 'RBC Flux');
        grid(lsFluxAx, 'on');

        postUpdate('Running linescan analysis — please wait...');
        drawnow;

        winStep = max(1, round(nWins/100));   % ~100 live refreshes total

        % Near-vertical Radon streaks (theta close to 0) give cot(theta) huge
        % apparent-velocity values of either sign - these are almost always
        % noise, not genuine ultra-fast readings, but the old guard
        % (abs(sin(theta))>=1e-6) let essentially everything through. Left
        % unfiltered, one such outlier could dominate the plot's Y-axis scale
        % and, after the retrograde/anterograde correction below, sometimes
        % land as a large NEGATIVE value - which is what made the trace
        % appear to vanish/flip to a negative axis. A realistic degree floor
        % rejects these at the source (Kira Shaw with Claude Code, Aug 2026).
        thetaFloorDeg = 0.5;

        for k = 1:nWins
            c0 = 1 + (k-1)*stepPx;
            c1 = c0 + winPx - 1;
            if c1 > nTotCols, break; end

            % Velocity: Radon on [winPx x nSp] (transpose from rawLine convention)
            wd = double(RL(:, c0:c1))';  % [winPx x nSp]: time x spatial
            if var(wd(:)) >= eps
                wd = wd - mean(wd,1) - mean(wd,2) + mean(wd(:));

                R_c = radon(wd, 0:179);
                [~, idx_c] = max(var(R_c));
                coarse = idx_c - 1;
                R_f = radon(wd, coarse + (-3:0.1:3));
                [~, idx_f] = max(var(R_f));
                fine_ang   = coarse + (-3 + (idx_f-1)*0.1);
                theta      = -1*(fine_ang - 90);

                if abs(theta) >= thetaFloorDeg
                    % theta (from radon on the raw PIXEL matrix) relates rows
                    % to COLUMNS, i.e. cot(theta) is "rows per pixel-column" -
                    % converting to a physical velocity needs the PER-PIXEL
                    % spatial size (pxsz_mm), not the total line width
                    % (deltax). Using deltax here was a longstanding bug
                    % inflating every velocity by a factor of ~nSp (confirmed
                    % against a synthetic streak of known true velocity - a
                    % 300-pixel-wide test window came back within ~1-6% of
                    % the true value once corrected, vs ~260-300x too high
                    % before). Kira Shaw with Claude Code, Aug 2026.
                    vel_app(k) = cot(theta*pi/180) * pxsz_mm / (mspline/1000);
                end
            end

            % Haematocrit: % dark pixels in window
            bw = BL(:, c0:c1);
            hct(k) = 100 * sum(bw(:)) / numel(bw);

            % Flux: transitions along centre spatial row (counting RBC passages)
            ctr_row     = BL(round(nSp/2), c0:c1);
            transitions = sum(diff(ctr_row) ~= 0);
            win_dur_s   = winPx * mspline / 1000;
            flux_rbc(k) = (transitions / 2) / max(win_dur_s, eps);

            if mod(k, winStep) == 0 || k == nWins
                % LHS: step raw/binary/window displays through the data as
                % it's analysed (mirrors xyDiam's live per-frame view)
                s.lsCurrentWin   = k;
                win_c_abs        = c0 + round(winPx/2);
                s.lsCurrentFrame = max(1, min(s.lsNumFrames, floor((win_c_abs-1)/nT) + 1));
                lsFrameSlider.Value = s.lsCurrentFrame;
                lblLsFrame.Text     = sprintf('%d / %d', s.lsCurrentFrame, s.lsNumFrames);
                lsWinSlider.Value   = min(k, lsWinSlider.Limits(2));
                lblLsWin.Text       = sprintf('Win %d / %d', k, nWins);
                setappdata(fig, 'state', s);  % keep appdata in step with the
                                               % loop, not just the pre-run
                                               % snapshot (Kira Shaw with
                                               % Claude Code, Aug 2026)
                renderLsFrame(s);
                dispAx.YDir     = 'normal';   % live-run direction override - see the
                lsBinaryAx.YDir = 'normal';   % note by the reset block above cb_lsGo's loop
                renderLsWindow(s);

                % RHS: grow the three traces with values computed so far
                set(hVel,  'YData', vel_app);
                set(hHct,  'YData', hct);
                set(hFlux, 'YData', flux_rbc);
                postUpdate(sprintf('Running linescan analysis: window %d / %d', k, nWins));
                drawnow limitrate;
            end
        end

        % Scan direction is established from the (now correctly pixel-scaled
        % - see thetaFloorDeg/pxsz_mm above) apparent velocity's sign; the
        % Charpak magnitude correction itself is OPT-IN via chkLsCharpak
        % (default off/"parked") since its physical validity for this
        % acquisition is unverified and it can legitimately NaN out most of
        % the trace when Vscan isn't comfortably larger than the true
        % velocity - see the conversation with Kira Shaw, Aug 2026, for the
        % synthetic-streak validation that found/fixed the pixel-scaling bug
        % and left the correction's own validity an open question.
        fv = vel_app(isfinite(vel_app) & ~isnan(vel_app));
        if isempty(fv)
            scan_dir = 'undetermined';
        elseif median(fv) < 0
            scan_dir = 'anterograde';  vel_app = -vel_app;
        elseif median(fv) > 0
            scan_dir = 'retrograde';
        else
            scan_dir = 'undetermined';
        end

        applyCharpak = chkLsCharpak.Value;

        % vel_corr_filtered: the scan-velocity correction WITH the Vscan-
        % validity clamp (a window where vel_app>=Vscan is physically
        % un-recoverable from this formula, so it's dropped) - this is the
        % number actually reported when the correction is on. vel_corr_raw:
        % the SAME formula WITHOUT that clamp, kept purely as a comparison
        % trace showing what the correction does before invalid windows are
        % removed (Kira Shaw with Claude Code, Aug 2026).
        vel_corr_filtered = vel_app;
        vel_corr_raw      = vel_app;
        if applyCharpak && ~isnan(Vscan)
            switch scan_dir
                case 'retrograde'
                    vel_corr_raw      = vel_app .* Vscan ./ max(Vscan - vel_app, eps);
                    vel_corr_filtered = vel_corr_raw;
                    vel_corr_filtered(vel_app >= Vscan) = NaN;
                case 'anterograde'
                    vel_corr_raw      = vel_app .* Vscan ./ (Vscan + vel_app);
                    vel_corr_filtered = vel_corr_raw;
                otherwise
                    % 'undetermined' - no established direction to correct
            end
        end
        % Once a scan direction is established, an individual window reading
        % the opposite sign is a noisy/wrong outlier, not a real negative
        % velocity. Velocity also can never be zero or below the noise
        % floor - both enforced on every trace that gets reported/plotted
        % (Kira Shaw with Claude Code, Aug 2026).
        if any(strcmp(scan_dir, {'retrograde','anterograde'}))
            vel_corr_filtered(vel_corr_filtered < 0) = NaN;
        end
        vel_corr_filtered(vel_corr_filtered < 0.1) = NaN;
        vel_app(vel_app < 0.1) = NaN;

        if applyCharpak
            % Can legitimately NaN out most of the trace when Vscan isn't
            % comfortably larger than the true velocity (see the checkbox's
            % tooltip) - rather than silently report a near-empty result,
            % fall back to the uncorrected apparent velocity when that
            % happens, and say so on screen (Kira Shaw with Claude Code,
            % Aug 2026).
            nFiniteApp  = nnz(~isnan(vel_app));
            nFiniteCorr = nnz(~isnan(vel_corr_filtered));
            correctionCollapsed = nFiniteApp > 0 && nFiniteCorr < 0.2 * nFiniteApp;
        else
            correctionCollapsed = false;
        end
        % "Main" reported/exported value - the filtered correction when
        % it's on and hasn't collapsed, otherwise the raw apparent velocity;
        % this is also what the title's mean/SD/range describe, even when
        % the extra comparison traces below are also plotted.
        if applyCharpak && ~correctionCollapsed
            vel_display = vel_corr_filtered;
        else
            vel_display = vel_app;
        end

        s.lsVelocity     = vel_display;
        s.lsHct          = hct;
        s.lsFlux         = flux_rbc;
        s.lsTime         = time_s;
        % Kept alongside the main reported value purely so Export data can
        % also offer the raw/uncorrected velocity when the scan-velocity
        % correction is on (Kira Shaw with Claude Code, Aug 2026).
        s.lsVelApp        = vel_app;
        s.lsApplyCharpak  = applyCharpak;
        s.lsWinLineStart  = c0v;   % absolute start line index of each window
        s.lsAnalysisRun  = true;
        setappdata(fig, 'state', s);

        % --- Finalize plots ---------------------------------------------------
        % Light smoothing for the final display only (linescan data is
        % noisy window-to-window) - a 5-window moving mean, NaN-aware so
        % gaps (noisy/rejected windows) don't spread. The stored/exported
        % values (s.lsVelocity/lsHct/lsFlux, set above) stay the raw
        % per-window numbers - only what's drawn on screen is smoothed, and
        % the title's mean/SD/range are computed from those same raw values,
        % not the smoothed display line (Kira Shaw with Claude Code, Aug 2026).
        smoothWin   = 5;
        vel_smooth  = smoothdata(vel_app,  'movmean', smoothWin, 'omitnan');  % red - always the raw apparent velocity
        hct_smooth  = smoothdata(hct,      'movmean', smoothWin, 'omitnan');
        flux_smooth = smoothdata(flux_rbc, 'movmean', smoothWin, 'omitnan');

        statsStr = @(x) sprintf('mean=%.2f   SD=%.2f   range=[%.2f, %.2f]', ...
            mean(x,'omitnan'), std(x,'omitnan'), min(x,[],'omitnan'), max(x,[],'omitnan'));

        set(hVel, 'YData', vel_smooth);
        set(hHct,  'YData', hct_smooth);
        title(lsHctAx, {'Haematocrit', statsStr(hct)});
        set(hFlux, 'YData', flux_smooth);
        title(lsFluxAx, {'RBC Flux', statsStr(flux_rbc)});

        % When the scan-velocity correction is on, add the corrected traces
        % alongside the raw one for direct comparison: yellow = corrected
        % WITHOUT the Vscan-validity filter (shows what the formula does
        % before invalid windows are removed), blue = corrected WITH that
        % filter (the number actually reported/exported). cla(lsVelAx) at
        % the top of this function already clears any from a previous run.
        if applyCharpak
            vel_corr_raw_smooth      = smoothdata(vel_corr_raw,      'movmean', smoothWin, 'omitnan');
            vel_corr_filtered_smooth = smoothdata(vel_corr_filtered, 'movmean', smoothWin, 'omitnan');
            hold(lsVelAx, 'on');
            plot(lsVelAx, time_s, vel_corr_raw_smooth, '-', ...
                'Color', [0.85 0.65 0.05], 'LineWidth', 1.1);
            plot(lsVelAx, time_s, vel_corr_filtered_smooth, '-', ...
                'Color', [0.10 0.35 0.85], 'LineWidth', 1.5);
            hold(lsVelAx, 'off');
            legend(lsVelAx, {'Apparent (uncorrected)', 'Vscan-corrected (unfiltered)', ...
                'Vscan-corrected (filtered)'}, 'Location', 'best', 'FontSize', F(7));
        else
            legend(lsVelAx, 'off');
        end
        title(lsVelAx, {'Red Blood Cell Velocity', statsStr(vel_display)});
        drawnow;

        % Slant description + correction recommendation, shown alongside the
        % Direction readout - confirmed empirically against this exact
        % Radon pipeline (higher-LHS/lower-RHS slant <-> positive theta/
        % vel_app <-> this 'retrograde' branch), then set by Kira Shaw's
        % own rule from direct RBC-slant observation: correction
        % recommended when the slant is higher-LHS/lower-RHS (Aug 2026).
        switch scan_dir
            case 'retrograde'
                corrNote = [char(8600) ' higher-LHS, lower-RHS - Vscan correction ' ...
                    'RECOMMENDED (Chaigneau & Charpak, 2022)'];
            case 'anterograde'
                corrNote = [char(8599) ' lower-LHS, higher-RHS - Vscan correction NOT recommended'];
            otherwise
                corrNote = 'direction undetermined - correction not meaningful here';
        end
        lblLsAngleRight.Text    = sprintf('Direction: %s scan   %s', scan_dir, corrNote);
        lblLsAngleRight.Visible = 'on';

        btnExportFig.Enable = 'on';
        btnExport.Enable    = 'on';

        if correctionCollapsed
            postUpdate(sprintf(['Linescan analysis complete: %d windows, scan direction = %s, ' ...
                'Vscan = %.0f mm/s. Scan-velocity correction left only %d/%d windows valid ' ...
                '(Vscan too close to measured velocity) - reporting uncorrected apparent ' ...
                'velocity instead.'], nWins, scan_dir, Vscan, nFiniteCorr, nFiniteApp));
        else
            postUpdate(sprintf(['Linescan analysis complete: %d windows, ' ...
                'scan direction = %s, Vscan = %.0f mm/s'], ...
                nWins, scan_dir, Vscan));
        end
    end

    % -------------------------------------------------------------------------
    function cb_lsExport()
    % Export data for linescan: MAT file or Excel, matching the pattern of
    % cb_export/cb_zExport. Includes alignment columns (absolute line index,
    % window index, derived frame index, time) plus raw and 5-window-
    % smoothed traces for velocity/haematocrit/flux. If the scan-velocity
    % correction was on for this run, also includes the uncorrected
    % apparent velocity alongside the (corrected) main value (Kira Shaw
    % with Claude Code, Aug 2026).
        s = getappdata(fig, 'state');
        if ~s.lsAnalysisRun
            postUpdate('User needs to extract data first');  return;
        end

        choice = uiconfirm(fig, 'Choose export format:', 'Export', ...
            'Options',       {'MAT file', 'Excel (.xlsx)', 'Cancel'}, ...
            'DefaultOption', 1, 'CancelOption', 3);
        if strcmp(choice, 'Cancel'), return; end

        nWins   = numel(s.lsTime);
        nT      = s.lsNumTime;
        winPx   = s.lsWindowSz_px;
        lineNo   = s.lsWinLineStart(:);
        windowNo = (1:nWins)';
        winCentreAbs = lineNo + round(winPx/2);
        frameNo = max(1, min(s.lsNumFrames, floor((winCentreAbs-1)/nT) + 1));
        timeS   = s.lsTime(:);

        smoothWin   = 5;
        vel_smooth  = smoothdata(s.lsVelocity, 'movmean', smoothWin, 'omitnan');
        hct_smooth  = smoothdata(s.lsHct,      'movmean', smoothWin, 'omitnan');
        flux_smooth = smoothdata(s.lsFlux,     'movmean', smoothWin, 'omitnan');

        % Column name reflects what the "main" value actually is - avoids an
        % ambiguous "RBCV_mm_s" that would silently mean different things
        % depending on whether the correction was on for this run.
        if s.lsApplyCharpak
            velColName   = 'RBCV_VscanCorrected_mm_s';
            velAppSmooth = smoothdata(s.lsVelApp, 'movmean', smoothWin, 'omitnan');
        else
            velColName = 'RBCV_mm_s';
        end

        if strcmp(choice, 'MAT file')
            [fn, fp] = uiputfile('*.mat', 'Save MAT file', ...
                fullfile(s.expDir, 'MAPS_linescan_results.mat'));
            if isequal(fn,0), return; end
            results.lineNo   = lineNo;
            results.windowNo = windowNo;
            results.frameNo  = frameNo;
            results.time_s   = timeS;
            results.(velColName)                = s.lsVelocity(:);
            results.([velColName '_smoothed5'])  = vel_smooth(:);
            results.Haematocrit_pct              = s.lsHct(:);
            results.Haematocrit_pct_smoothed5    = hct_smooth(:);
            results.Flux_RBC_s                   = s.lsFlux(:);
            results.Flux_RBC_s_smoothed5         = flux_smooth(:);
            if s.lsApplyCharpak
                results.RBCV_uncorrected_mm_s           = s.lsVelApp(:);
                results.RBCV_uncorrected_mm_s_smoothed5 = velAppSmooth(:);
            end
            results.windowSize_ms        = s.lsWindowSz_ms;
            results.pixelSize_um         = s.lsPxsz;
            results.applyVscanCorrection = s.lsApplyCharpak;
            save(fullfile(fp,fn), 'results', '-v7.3');
            postUpdate(['Saved: ' fullfile(fp,fn)]);

        else  % Excel
            [fn, fp] = uiputfile('*.xlsx', 'Save Excel file', ...
                fullfile(s.expDir, 'MAPS_linescan_results.xlsx'));
            if isequal(fn,0), return; end

            colNames = [{'Line_number'}, {'Window_number'}, {'Frame_number'}, {'Time_s'}, ...
                {velColName}, {[velColName '_smoothed5']}, ...
                {'Haematocrit_pct'}, {'Haematocrit_pct_smoothed5'}, ...
                {'Flux_RBC_s'}, {'Flux_RBC_s_smoothed5'}];
            data = [lineNo, windowNo, frameNo, timeS, ...
                s.lsVelocity(:), vel_smooth(:), s.lsHct(:), hct_smooth(:), ...
                s.lsFlux(:), flux_smooth(:)];

            if s.lsApplyCharpak
                colNames = [colNames, {'RBCV_uncorrected_mm_s'}, {'RBCV_uncorrected_mm_s_smoothed5'}];
                data = [data, s.lsVelApp(:), velAppSmooth(:)];
            end

            T = array2table(data, 'VariableNames', colNames);
            outFn = fullfile(fp, fn);
            if isfile(outFn)
                delete(outFn);
            end
            writetable(T, outFn);
            postUpdate(['Saved: ' outFn]);
        end
    end

    % -------------------------------------------------------------------------
    function cb_lsExportFig()
    % Pops the three linescan result graphs out into a standalone,
    % savable figure - same pattern as cb_exportFig/cb_zExportFig for the
    % other two analysis types (Kira Shaw with Claude Code, Aug 2026).
        s = getappdata(fig, 'state');
        if ~s.lsAnalysisRun
            postUpdate('User needs to extract data first');  return;
        end

        statsStr = @(x) sprintf('mean=%.2f   SD=%.2f   range=[%.2f, %.2f]', ...
            mean(x,'omitnan'), std(x,'omitnan'), min(x,[],'omitnan'), max(x,[],'omitnan'));
        smoothWin = 5;

        expFig = figure('Name', 'MAPS — Linescan Export', 'Color', 'w', ...
            'Position', [80 80 1100 850]);

        ax1 = subplot(3, 1, 1, 'Parent', expFig);
        plot(ax1, s.lsTime, smoothdata(s.lsVelocity, 'movmean', smoothWin, 'omitnan'), ...
            '-', 'Color', [0.85 0.10 0.10], 'LineWidth', 1.5);
        xlabel(ax1, 'Time (s)');  ylabel(ax1, 'Velocity (mm/s)');
        title(ax1, {'Red Blood Cell Velocity', statsStr(s.lsVelocity)});
        grid(ax1, 'on');

        ax2 = subplot(3, 1, 2, 'Parent', expFig);
        plot(ax2, s.lsTime, smoothdata(s.lsHct, 'movmean', smoothWin, 'omitnan'), ...
            '-', 'Color', [0.55 0.10 0.65], 'LineWidth', 1.5);
        xlabel(ax2, 'Time (s)');  ylabel(ax2, 'RBC density (%)');
        title(ax2, {'Haematocrit', statsStr(s.lsHct)});
        grid(ax2, 'on');

        ax3 = subplot(3, 1, 3, 'Parent', expFig);
        plot(ax3, s.lsTime, smoothdata(s.lsFlux, 'movmean', smoothWin, 'omitnan'), ...
            '-', 'Color', [0.10 0.55 0.10], 'LineWidth', 1.5);
        xlabel(ax3, 'Time (s)');  ylabel(ax3, 'Flux (RBC/s)');
        title(ax3, {'RBC Flux', statsStr(s.lsFlux)});
        grid(ax3, 'on');

        [fn, fp] = uiputfile( ...
            {'*.png','PNG image'; '*.pdf','PDF'; '*.fig','MATLAB figure'}, ...
            'Save figure', fullfile(s.expDir, 'MAPS_linescan_figure'));
        if ~isequal(fn, 0)
            saveas(expFig, fullfile(fp, fn));
            postUpdate(['Figure saved: ' fullfile(fp, fn)]);
        end
    end

end % MAPS

% =============================================================================
%  LOCAL FUNCTION  (outside the main function — no closure needed)
% =============================================================================
function out = applyMask(rawVess, mask)
% Apply binary mask to every frame; background set to 0 or 2^15.
    out = zeros(size(rawVess), 'like', rawVess);
    for i = 1:size(rawVess,1)
        fr = squeeze(rawVess(i,:,:));
        if mean(fr(:)) < 2^15
            fr(~mask) = 0;
        else
            fr(~mask) = 2^15;
        end
        out(i,:,:) = fr;
    end
end

% Written by Kira Shaw with Claude Code, Aug 2026.
function segs = insertSegment(segs, newSeg)
% insertSegment  Insert newSeg into segs (a struct array of frame-range
% threshold segments - fields startF, endF, mode, value), splitting/
% trimming any existing segment(s) it overlaps so the segments always
% partition the stack with no gaps or overlaps.
    kept = struct('startF', {}, 'endF', {}, 'mode', {}, 'value', {});
    for i = 1:numel(segs)
        sg = segs(i);
        if sg.endF < newSeg.startF || sg.startF > newSeg.endF
            kept(end+1) = sg; %#ok<AGROW> - no overlap, keep as-is
        else
            if sg.startF < newSeg.startF
                left = sg;  left.endF = newSeg.startF - 1;
                kept(end+1) = left; %#ok<AGROW>
            end
            if sg.endF > newSeg.endF
                right = sg;  right.startF = newSeg.endF + 1;
                kept(end+1) = right; %#ok<AGROW>
            end
        end
    end
    kept(end+1) = newSeg;
    [~, ord] = sort([kept.startF]);
    segs = kept(ord);
end

% Written by Kira Shaw with Claude Code, Aug 2026.
% Written by Kira Shaw with Claude Code, Aug 2026.
function [volume_mm3, boundaryMask, boundaryCoords] = ...
    computeBoundaryRestrictedVolume(BW, pxsz_um, zstep_um)
% computeBoundaryRestrictedVolume  A second, alternative tissue volume
% estimate ("boundaryRestricted" throughout the exports), per Kira's
% request. Uses the actual binarised (auto/manual-thresholded) vessel
% mask itself to bound each frame, rather than a raw-intensity black/
% not-black test (computeSlantCorrectedVolume) or the plain bounding box.
%
% For each frame independently: if it has any vessel signal, that frame's
% "tissue" extent is the convex hull of its vessel-positive pixels
% (bwconvhull) - the region a vessel network was actually detected
% spanning in that frame, not just the pixels that are themselves vessel.
% A frame with no vessel signal at all contributes zero. This is a
% different assumption to the slant correction (which reasons from raw
% intensity, in 10um z-bins) - this one reasons from the thresholded
% vessel mask itself, per individual frame.
%
%INPUTS
% BW       : binarised vessel volume, frames x H x W - the STRAIGHT
%            thresholded mask (before any resampling/mask-smoothing)
% pxsz_um  : xy pixel size, microns
% zstep_um : z-step, microns (this volume's true per-frame thickness)
%OUTPUTS
% volume_mm3     : boundary-restricted tissue volume estimate, mm^3
% boundaryMask   : logical, same size as BW - the per-frame convex hull
% boundaryCoords : cell array, one cell per frame - each an Nx2 [x,y]
%                  matrix of that frame's boundary outline (pixel
%                  coordinates), or empty if that frame had no signal.
%                  Written by Kira Shaw with Claude Code, Aug 2026 - so
%                  the boundary itself can be exported/re-plotted, not
%                  just the area/volume it works out to.

nZ = size(BW, 1);
volume_mm3 = 0;
boundaryMask = false(size(BW));
boundaryCoords = cell(nZ, 1);
for z = 1:nZ
    frameBW = squeeze(BW(z,:,:));
    if any(frameBW(:))
        hull = bwconvhull(frameBW);
        boundaryMask(z,:,:) = hull;
        volume_mm3 = volume_mm3 + nnz(hull) * (pxsz_um^2) * zstep_um / 1000^3;
        B = bwboundaries(hull);
        if ~isempty(B)
            % bwboundaries returns [row col] = [y x]; store as [x y] for
            % the more conventional plotting/export order
            boundaryCoords{z} = [B{1}(:,2), B{1}(:,1)];
        end
    end
end

end

function [volume_mm3, tissueMask] = computeSlantCorrectedVolume(zRaw, pxsz_um, zstep_um)
% computeSlantCorrectedVolume  Tissue volume estimate that accounts for a
% stack imaged at a slight angle to the tissue surface, where a plain
% rectangular W x H x D box overstates the true volume - part of that box,
% at some depths, is genuinely outside the tissue (black/empty), not
% background tissue, so treating the whole box as tissue understates
% density.
%
% Bins the stack into ~10 micron z-slabs (rounded to the nearest whole
% frame using the stack's own z-step, so this behaves consistently
% whatever the step size happened to be for a given session). Within each
% slab, an xy pixel counts as "in tissue" if it has any signal above a
% near-zero floor in ANY frame of that slab; a pixel that never rises
% above that floor for the WHOLE slab is judged to be outside the tissue
% for that depth range - real tissue background/noise essentially never
% reads at exactly the stack's minimum across many consecutive frames the
% way a padded/unscanned region would.
%
% Also returns the full 3D tissue mask (Written by Kira Shaw with Claude
% Code, Aug 2026) - not just the volume number - so the caller can apply
% the SAME "what counts as tissue" definition to other stats (the tissue-
% to-vessel distance percentiles/histogram, in particular) rather than
% having density be slant-corrected while everything else still samples
% from the full uncorrected box.
%
%INPUTS
% zRaw     : raw z-stack, frames x H x W
% pxsz_um  : xy pixel size, microns
% zstep_um : z-step, microns
%OUTPUTS
% volume_mm3 : corrected tissue volume estimate, mm^3
% tissueMask : logical, same size as zRaw - true where a voxel's xy
%              location was judged "in tissue" for its z-slab

nZ = size(zRaw, 1);
binFrames = max(1, round(10 / zstep_um));   % ~10 um per bin

loVal = min(zRaw(:));
hiVal = max(zRaw(:));
% tolerance above the true minimum - real signal essentially never reads
% exactly the minimum across a whole bin's worth of frames, so a small
% margin catches noise right at the floor without also catching dim but
% real tissue
blackThresh = loVal + 0.02 * (hiVal - loVal);

volume_mm3 = 0;
tissueMask = false(size(zRaw));
startF = 1;
while startF <= nZ
    endF = min(nZ, startF + binFrames - 1);
    slab = zRaw(startF:endF, :, :);
    inTissue = squeeze(any(slab > blackThresh, 1));   % H x W logical
    slabThick_um = (endF - startF + 1) * zstep_um;
    volume_mm3 = volume_mm3 + nnz(inTissue) * (pxsz_um^2) * slabThick_um / 1000^3;
    nFramesInSlab = endF - startF + 1;
    tissueMask(startF:endF, :, :) = repmat(reshape(inTissue, [1, size(inTissue)]), ...
        nFramesInSlab, 1, 1);
    startF = endF + 1;
end

end

% Written by Kira Shaw with Claude Code, Aug 2026.
function branches = extractBranches(skel, distMap, voxSize)
% extractBranches  Approximate per-branch length/diameter/depth from a 3D
% skeleton - a simplified stand-in for Fiji's AnalyzeSkeleton_ graph (which
% has no MATLAB equivalent to call directly).
%
% Junction voxels (skeleton voxels with >=3 26-connected skeleton
% neighbours) are removed; each remaining 26-connected component is one
% branch. This leaves the junction voxel itself out of each branch's
% length - a small underestimate versus Fiji's edge-based accounting -
% but keeps the algorithm tractable without a full voxel graph across the
% whole skeleton.
%
% Length/depth (Written by Kira Shaw with Claude Code, Aug 2026, replacing
% a plain minimum-spanning-tree sum): bwskel's medial axis on a "fat"
% vessel (large diameter relative to its length, or to voxel size) isn't
% one well-defined line - small surface bumps nudge it off-centre from
% one cross-section to the next, giving a swirl rather than a straight
% path, most visible on large vessels. A raw MST length just sums that
% swirl. Instead: build the same 26-connectivity graph, walk it end to
% end (the graph's diameter - the shortest path between its two most
% distant voxels, found via a standard double-BFS/Dijkstra), giving an
% ORDERED sequence of points along the branch, then smooth that sequence
% (moving average) before summing consecutive distances for length and
% averaging depth. Diameter isn't path-dependent, so it's untouched -
% still the mean local radius (distMap) over every voxel in the branch.
%
% Tortuosity (Written by Kira Shaw with Claude Code, Aug 2026): the
% smoothed skeleton path IS the actual route (length_um above); "as the
% crow flies" is the straight-line distance between that same smoothed
% path's start and end points. tortuosity = actual / straight-line - 1.0
% is perfectly straight, higher is more tortuous. NaN if the two ends
% coincide (degenerate/zero-length chord).
%
%INPUTS
% skel    : 3D logical skeleton (Z x Y x X), one voxel wide
% distMap : 3D distance-to-nearest-vessel map, same size, in microns
% voxSize : [zSize, ySize, xSize] physical voxel size, microns (post any
%           isotropic resampling done by the caller)
%OUTPUTS
% branches : struct array, one element per branch: length_um, diam_um,
%            depth_um (mean z position, physical, from the smoothed
%            centreline), tortuosity, nVoxels

nbrCount  = convn(double(skel), ones(3,3,3), 'same') - 1;
junction  = skel & (nbrCount >= 3);
segVoxels = skel & ~junction;

CC      = bwconncomp(segVoxels, 26);
nBranch = CC.NumObjects;
maxStep = sqrt(sum(voxSize.^2));   % longest possible single 26-conn voxel step

branches = struct('length_um', {}, 'diam_um', {}, 'depth_um', {}, ...
    'tortuosity', {}, 'nVoxels', {});
for i = 1:nBranch
    idx = CC.PixelIdxList{i};
    if numel(idx) < 2
        continue;   % single isolated voxel - not a measurable segment
    end
    [zz, yy, xx] = ind2sub(size(skel), idx);
    coordsPhys = double([zz, yy, xx]) .* voxSize;   % Nx3, physical microns

    % ---- 26-connectivity graph over this branch's voxels -----------------
    n  = numel(idx);
    dx = coordsPhys(:,1) - coordsPhys(:,1)';
    dy = coordsPhys(:,2) - coordsPhys(:,2)';
    dz = coordsPhys(:,3) - coordsPhys(:,3)';
    D  = sqrt(dx.^2 + dy.^2 + dz.^2);

    adjMask  = (D > 0) & (D <= maxStep + 1e-6);
    [ii, jj] = find(triu(adjMask));

    if isempty(ii)
        % no 26-connectivity edges at all (shouldn't happen for a
        % bwconncomp-connected component, but stay safe) - fall back to
        % the raw voxel set, unsmoothed
        length_um  = 0;
        depth_um   = mean(coordsPhys(:,1));
        tortuosity = NaN;
    else
        w = D(sub2ind([n n], ii, jj));
        G = graph(ii, jj, w, n);

        % walk the graph's diameter (double-BFS/Dijkstra: farthest node
        % from an arbitrary start, then farthest node from THAT one) to
        % get the two most distant voxels, then the ordered path between
        % them - this is the "unroll the branch into a line" step
        distFrom1      = distances(G, 1);
        [~, endA]      = max(distFrom1);
        distFromEndA   = distances(G, endA);
        [~, endB]      = max(distFromEndA);
        pathNodes      = shortestpath(G, endA, endB);

        pathCoords = coordsPhys(pathNodes, :);
        if size(pathCoords, 1) >= 3
            winSize      = min(7, size(pathCoords, 1));
            smoothCoords = smoothdata(pathCoords, 1, 'movmean', winSize);
        else
            smoothCoords = pathCoords;
        end

        segLen    = sqrt(sum(diff(smoothCoords, 1, 1).^2, 2));
        length_um = sum(segLen);
        depth_um  = mean(smoothCoords(:,1));   % z = depth

        % tortuosity: actual (skeleton) path length / straight-line chord
        % between the same path's start and end
        chordLength = norm(smoothCoords(end,:) - smoothCoords(1,:));
        if chordLength > 0
            tortuosity = length_um / chordLength;
        else
            tortuosity = NaN;
        end
    end

    branches(end+1).length_um  = length_um; %#ok<AGROW>
    branches(end).diam_um      = 2 * mean(distMap(idx));
    branches(end).depth_um     = depth_um;
    branches(end).tortuosity   = tortuosity;
    branches(end).nVoxels      = n;
end

end

% Written by Kira Shaw with Claude Code, Aug 2026.
function [n, runStart, runEnd] = countEdgeDarkRuns(edgeBlock)
% countEdgeDarkRuns  Count RBC crossings of a linescan window edge.
% edgeBlock: [winPx x edgeW] binary block (true=bright/plasma) taken from
% one edge (left or right) of a binarised space-time window. Majority-votes
% across the edgeW columns per row to get one bright/dark value per time
% row, then counts contiguous dark runs - each run = one RBC crossing.
% Runs touching row 1 or the last row are kept regardless of length (they're
% truncated by the window boundary, not necessarily short); interior runs
% need >=2 rows to reject single-pixel salt noise.
%OUTPUTS
% n                : number of qualifying dark runs
% runStart, runEnd : row indices (into edgeBlock) of each run's start/end
    edgeBright = mean(double(edgeBlock), 2) >= 0.5;
    dark = ~edgeBright;
    d = diff([0; dark; 0]);
    runStart = find(d == 1);
    runEnd   = find(d == -1) - 1;
    touchesEdge = (runStart == 1) | (runEnd == numel(dark));
    keep = touchesEdge | (runEnd - runStart + 1) >= 2;
    runStart = runStart(keep);  runEnd = runEnd(keep);
    n = numel(runStart);
end

function p = pctileLocal(x, pct)
% pctileLocal  Percentile(s) of x via linear interpolation on the empirical
% CDF (same convention as MATLAB's own prctile) - written locally so this
% doesn't pull in the Statistics and Machine Learning Toolbox just for
% this one thing.
%INPUTS
% x   : data vector (NaNs ignored)
% pct : percentile(s) wanted, in [0,100] - scalar or vector
%OUTPUTS
% p   : percentile value(s), same size as pct
    x = sort(x(~isnan(x)));
    n = numel(x);
    if n == 0
        p = nan(size(pct));
        return;
    end
    if n == 1
        p = repmat(x, size(pct));
        return;
    end
    posK = 100*((1:n) - 0.5) / n;
    p = interp1(posK, x, pct, 'linear', 'extrap');
    p = min(max(p, x(1)), x(end));   % extrap can slightly overshoot past the ends
end

function F0 = slidingBaseline(F, winFrames)
% slidingBaseline  Suite2p-style 'maximin' baseline for dF/F0 (Written by
% Kira Shaw with Claude Code, Aug 2026) - see suite2p.readthedocs.io,
% Settings ('baseline' = 'maximin'): Gaussian-smooth the trace, then a
% sliding minimum filter, then a sliding maximum filter, both over the
% same window. The min-then-max ("opening") tracks the local resting
% level without the raw sliding-min's floor being dragged down by single
% noisy low frames, and - unlike a single global min/max over the whole
% recording (see calcium_norm in FWHM_diam_perivascCa_adapted.m) - it
% tracks slow drift (bleaching, focus) rather than being set by one
% outlier frame anywhere in the recording.
%INPUTS
% F         : [skeleton pt x frame] trace(s) to baseline, one row each
% winFrames : baseline window, in frames (caBaselineSec * fps, see cb_go)
%OUTPUTS
% F0        : same size as F, the sliding baseline for each row
    sigmaFrames = max(1, round(winFrames / 15));   % light smoothing, not user-facing
    Fs   = smoothdata(F, 2, 'gaussian', sigmaFrames);
    Fmin = movmin(Fs, winFrames, 2);
    F0   = movmax(Fmin, winFrames, 2);
end

% Written by Kira Shaw with Claude Code, Aug 2026.
function level = isoDataThreshold(I)
% isoDataThreshold  Classic iterative intermeans (Ridler-Calvard) threshold
% on I (values in [0,1]). Close to ImageJ's "Default" method. Returns a
% level in [0,1].
    counts     = histcounts(I(:), 256, 'BinLimits', [0 1]);
    binCenters = linspace(1/512, 1-1/512, 256);

    T = mean(I(:));
    for it = 1:100   % fixed iteration cap in case convergence is never reached
        below = binCenters <= T;
        if ~any(below) || all(below)
            break;
        end
        m1 = sum(binCenters(below)  .* counts(below))  / max(sum(counts(below)),  eps);
        m2 = sum(binCenters(~below) .* counts(~below)) / max(sum(counts(~below)), eps);
        newT = (m1 + m2) / 2;
        if abs(newT - T) < 1e-4
            T = newT;
            break;
        end
        T = newT;
    end
    level = T;
end

% Written by Kira Shaw with Claude Code, Aug 2026.
function level = triangleThreshold(I)
% triangleThreshold  Zack/Rogers/Latt "triangle" threshold on I (values in
% [0,1]): draws a line from the histogram's peak to its far tail and picks
% the bin with the greatest perpendicular distance from that line. Returns
% a level in [0,1].
    counts     = histcounts(I(:), 256, 'BinLimits', [0 1]);
    binCenters = linspace(1/512, 1-1/512, 256);

    [peakVal, peakIdx] = max(counts);
    nz      = find(counts > 0);
    firstNZ = nz(1);
    lastNZ  = nz(end);

    if (peakIdx - firstNZ) > (lastNZ - peakIdx)
        endIdx   = firstNZ;
        rangeIdx = endIdx:peakIdx;
    else
        endIdx   = lastNZ;
        rangeIdx = peakIdx:endIdx;
    end

    x1 = peakIdx;  y1 = peakVal;
    x2 = endIdx;   y2 = counts(endIdx);

    xr = rangeIdx;
    yr = counts(rangeIdx);
    dists = abs((y2-y1).*xr - (x2-x1).*yr + x2*y1 - y2*x1) ./ ...
        sqrt((y2-y1)^2 + (x2-x1)^2 + eps);

    [~, mi]  = max(dists);
    thrIdx   = rangeIdx(mi);
    level    = binCenters(thrIdx);
end
