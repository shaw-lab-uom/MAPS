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
    'Text',       'Vessel diameter analysis from two-photon imaging', ...
    'FontSize',   F(11), 'FontColor', [0.40 0.40 0.40]);

% thin separator line below header
uipanel(fig, 'Position', P(0,782,1430,2), 'BackgroundColor', [0.7 0.7 0.75], ...
    'BorderType', 'none');

% =============================================================================
%  LEFT PANEL  (x = 8, width = 415)
% =============================================================================
LX = 8;   LW = 415;

% ---- Load Data + analysis dropdown ------------------------------------------
btnLoad = uibutton(fig, ...
    'Position',        P(LX,749,128,28), ...
    'Text',            'Load Data', ...
    'FontWeight',      'bold', ...
    'BackgroundColor', [0.20 0.45 0.75], ...
    'FontColor',       [1 1 1], ...
    'ButtonPushedFcn', @(~,~) cb_loadData());

uilabel(fig, 'Position', P(145,754,68,20), 'Text', 'Analysis:', ...
    'FontColor', [0.25 0.25 0.25]);
ddAnalysis = uidropdown(fig, ...
    'Position', P(213,749,130,28), ...
    'Items',    {'xyDiam', 'zstack', 'linescan'}, ...
    'Value',    'xyDiam', 'FontSize', F(12));

% ---- Vessel display axes ----------------------------------------------------
uilabel(fig, 'Position', P(LX,729,250,18), ...
    'Text', 'Vessel display  (frame ~50)', ...
    'FontSize', F(10), 'FontColor', [0.35 0.35 0.35]);

dispAx = uiaxes(fig, 'Position', P(LX,320,LW,406));
dispAx.XTick = []; dispAx.YTick = [];
dispAx.Box   = 'off';
dispAx.Color = [0.88 0.88 0.90];
dispAx.Title.String = 'Pending vessel display';
dispAx.Title.Color  = [0.45 0.45 0.45];
axis(dispAx, 'equal');

% ---- Processing options section ---------------------------------------------
uilabel(fig, 'Position', P(LX,300,200,18), ...
    'Text', 'Processing options', ...
    'FontSize', F(12), 'FontWeight', 'bold', 'FontColor', [0.15 0.15 0.15]);

btnSkel = uibutton(fig, ...
    'Position',        P(LX,265,172,28), ...
    'Text',            'Generate skeleton', ...
    'ButtonPushedFcn', @(~,~) cb_generateSkeleton());

lblSkelTick = uilabel(fig, 'Position', P(188,263,30,30), ...
    'Text', '', 'FontSize', F(20), 'FontColor', [0.10 0.70 0.20]);

btnBranch = uibutton(fig, ...
    'Position',        P(LX,228,210,28), ...
    'Text',            'Draw around vessel branch', ...
    'ButtonPushedFcn', @(~,~) cb_drawBranch());

lblBranchTick = uilabel(fig, 'Position', P(226,226,30,30), ...
    'Text', '', 'FontSize', F(20), 'FontColor', [0.10 0.70 0.20]);

% ---- Parameters panel -------------------------------------------------------
pnl = uipanel(fig, ...
    'Position',        P(LX,52,LW,170), ...
    'Title',           'Parameters', ...
    'FontWeight',      'bold', ...
    'BackgroundColor', [1 1 1]);

uilabel(pnl, 'Position', P(10,115,115,22), 'Text', 'No. of branches:');
efNBranch = uieditfield(pnl, 'numeric', ...
    'Position', P(130,115,55,22), 'Value', 1, 'Limits', [1 5]);

uilabel(pnl, 'Position', P(10,80,115,22), 'Text', 'Pixel size (microns):');
efPxsz = uieditfield(pnl, 'text', ...
    'Position', P(130,80,100,22), 'Value', '', 'Placeholder', 'blank = pixels');

uilabel(pnl, 'Position', P(10,46,115,22), 'Text', 'Frame rate (Hz):');
efFPS = uieditfield(pnl, 'text', ...
    'Position', P(130,46,100,22), 'Value', '', 'Placeholder', 'blank = frames');

uilabel(pnl, 'Position', P(10,12,LW-20,28), ...
    'Text',      'Leave blank to output diameter in pixels / time in frames.', ...
    'FontSize',  F(9), 'FontColor', [0.50 0.50 0.50], ...
    'WordWrap',  'on');

% ---- GO button --------------------------------------------------------------
btnGo = uibutton(fig, ...
    'Position',        P(LX,14,LW,33), ...
    'Text',            'GO', ...
    'FontSize',        F(15), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.12 0.55 0.20], ...
    'FontColor',       [1 1 1], ...
    'ButtonPushedFcn', @(~,~) cb_go());

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

% ---- Diameter heatmap axes --------------------------------------------------
uilabel(fig, 'Position', P(RX,708,350,18), ...
    'Text', 'Diameter map', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25]);
heatAx = uiaxes(fig, 'Position', P(RX,415,RW,290));
heatAx.Color   = [0.97 0.97 0.97];
heatAx.XColor  = [0.30 0.30 0.30];
heatAx.YColor  = [0.30 0.30 0.30];
colormap(heatAx, 'parula');
xlabel(heatAx, 'Frame');  ylabel(heatAx, 'Skeleton pt');

% ---- Average diameter trace axes --------------------------------------------
uilabel(fig, 'Position', P(RX,393,350,18), ...
    'Text', 'Average diameter  (mean across skeleton pts)', ...
    'FontSize', F(10), 'FontWeight', 'bold', 'FontColor', [0.25 0.25 0.25]);
traceAx = uiaxes(fig, 'Position', P(RX,55,RW,335));
traceAx.Color  = [0.97 0.97 0.97];
traceAx.XColor = [0.30 0.30 0.30];
traceAx.YColor = [0.30 0.30 0.30];
hold(traceAx, 'on');

% ---- Export buttons (data and figure, side by side) -------------------------
btnW2 = floor((RW-10)/2);   % width of each button
btnExport = uibutton(fig, ...
    'Position',        P(RX,14,btnW2,33), ...
    'Text',            'Export data', ...
    'FontSize',        F(13), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.15 0.25 0.68], ...
    'FontColor',       [1 1 1], ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) cb_export());

btnExportFig = uibutton(fig, ...
    'Position',        P(RX+btnW2+10,14,btnW2,33), ...
    'Text',            'Export figure', ...
    'FontSize',        F(13), 'FontWeight', 'bold', ...
    'BackgroundColor', [0.35 0.20 0.55], ...
    'FontColor',       [1 1 1], ...
    'Enable',          'off', ...
    'ButtonPushedFcn', @(~,~) cb_exportFig());

% ---- credit line, bottom-right corner --------------------------------------
uilabel(fig, ...
    'Position',            P(RX+RW-140,1,140,12), ...
    'Text',                'Shaw (2026)', ...
    'FontSize',            F(9), 'FontColor', [0.40 0.40 0.40], ...
    'HorizontalAlignment', 'right');

% =============================================================================
%  INITIAL STATE
% =============================================================================
state.rawVess       = [];
state.expDir        = '';
state.frame50       = [];
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
setappdata(fig, 'state', state);

% =============================================================================
%  NESTED CALLBACKS  (share fig, BC, prefs, dispAx, etc. via closure)
% =============================================================================

    % =========================================================================
    function cb_loadData()
        [tifName, tifFolder] = uigetfile( ...
            {'*.tif;*.tiff', 'TIF files (*.tif, *.tiff)'}, ...
            'Select vessel TIF file', cd);
        if isequal(tifName, 0), return; end
        tifPath = fullfile(tifFolder, tifName);
        expDir  = tifFolder;

        postUpdate('Loading TIF — please wait...');
        rawVess = loadTifFileIn2Mat(tifPath);

        s             = getappdata(fig, 'state');
        s.rawVess     = rawVess;
        s.expDir      = expDir;
        s.frame50     = squeeze(rawVess(min(50, size(rawVess,1)), :, :));
        s.skeletons   = {};  s.masks     = {};
        s.perpEndpts  = {};  s.cont_diams = {};
        s.skelDrawn   = false;  s.branchesDrawn = false;
        s.analysisRun = false;
        setappdata(fig, 'state', s);

        % show frame in display axes
        refreshDisplay(s, {}, {});

        lblSkelTick.Text    = '';
        lblBranchTick.Text  = '';
        btnExport.Enable    = 'off';
        btnExportFig.Enable = 'off';
        cla(heatAx);  cla(traceAx);  hold(traceAx, 'on');

        % ---- try to auto-fill pixel size / fps -------------------------
        % Checks the TIF's own metadata first, then falls back to an
        % accompanying .ini (Scientifica) or Experiment.xml (ThorLabs) in
        % expDir. Anything not found is left blank for manual entry, same
        % as before.
        [pxsz_auto, fps_auto, pxSrc, fpsSrc] = autoDetectAcqParams(tifPath, expDir);

        msgParts = {sprintf('Loaded: %s   (%d frames, %d x %d px)', ...
            tifName, size(rawVess,1), size(rawVess,2), size(rawVess,3))};

        if ~isnan(pxsz_auto)
            efPxsz.Value = num2str(pxsz_auto, '%.4g');
            msgParts{end+1} = sprintf('Pixel size auto-filled: %.4g um (%s).', pxsz_auto, pxSrc);
        else
            efPxsz.Value = '';
            msgParts{end+1} = 'Pixel size not found in TIF/ini/xml - enter manually.';
        end

        if ~isnan(fps_auto)
            efFPS.Value = num2str(fps_auto, '%.4g');
            msgParts{end+1} = sprintf('Frame rate auto-filled: %.4g Hz (%s).', fps_auto, fpsSrc);
        else
            efFPS.Value = '';
            msgParts{end+1} = 'Frame rate not found in TIF/ini/xml - enter manually.';
        end

        postUpdate(strjoin(msgParts, '  '));
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

        s.cont_diams = cell(nB, 1);
        s.nanInds    = cell(nB, 1);
        s.times      = cell(nB, 1);
        s.perpEndpts = cell(nB, 1);

        cla(heatAx);  cla(traceAx);  hold(traceAx, 'on');

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

            % ---- mask vessel for intensity -----------------------------------
            maskVess = zeros(size(s.rawVess), 'single');
            for i = 1:nFrames
                fr = single(squeeze(s.rawVess(i,:,:)));
                fr(~mask) = NaN;
                maskVess(i,:,:) = fr;
            end

            % ===================================================================
            %  PHASE A — geometry pass (skeleton-point loop, no frame data)
            %  Works out the perpendicular scan line for every skeleton point.
            %  Purely spatial — independent of frame — so it's fast, and lets
            %  us sanity-check the scan geometry (is the line tracking the
            %  vessel properly?) on dispAx before the slow per-frame FWHM
            %  crunching starts.
            % ===================================================================
            cont_diam  = nan(nLines, nFrames, 'single');
            perpEndpts = nan(nLines, 4);   % [x1 y1 x2 y2] for export figure
            locsAll    = cell(nLines, 1);  % linear pixel indices along each perp line

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

                t     = linspace(-normlength, normlength, 10000);
                normx = xc + t .* cos(pa);
                normy = yc + t .* sin(pa);

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
                    xt = round(normx);  yt = round(normy);
                    locsAll{k} = unique(sub2ind([imH imW], yt, xt));
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

            frameStep = max(1, round(nFrames/100));   % ~100 display refreshes total

            for i = 1:nFrames
                ImVess = squeeze(maskVess(i,:,:));   % once per frame, not per skel pt
                for k = 1:nLinesEff
                    locs = locsAll{k};
                    if isempty(locs), continue; end
                    prof = ImVess(locs);
                    prof = prof(~isnan(prof));
                    if numel(prof) < 2, continue; end
                    hm = (min(prof) + max(prof)) / 2;
                    i1 = find(prof >= hm, 1, 'first');
                    i2 = find(prof >= hm, 1, 'last');
                    if ~isempty(i1) && ~isempty(i2)
                        cont_diam(k,i) = (i2 - i1) * pxsz_um;
                    end
                end
                traceY(i) = nanmean(cont_diam(:,i));

                if mod(i,frameStep)==0 || i==nFrames
                    postUpdate(sprintf('Branch %d / %d:  frame %d / %d', b, nB, i, nFrames));
                    set(hHeat, 'CData', cont_diam);
                    xlim(heatAx, [0.5, i+0.5]);
                    set(hTrace, 'YData', traceY);
                    drawnow limitrate;
                end
            end

            s.perpEndpts{b} = perpEndpts;

            % ---- remove all-NaN skeleton rows, build time vector ------------
            nanInd = find(all(isnan(cont_diam), 2));
            cont_diam(nanInd,:) = [];
            time = (0 : size(cont_diam,2)-1) / fps_val;

            s.cont_diams{b} = cont_diam;
            s.nanInds{b}    = nanInd;
            s.times{b}      = time;

            % ---- finalize heatmap + trace for this branch (exact values) ----
            set(hHeat, 'CData', cont_diam);
            xlim(heatAx, [0.5, nFrames+0.5]);
            ylim(heatAx, [0.5, size(cont_diam,1)+0.5]);
            title(heatAx, sprintf('Branch %d', b));

            set(hTrace, 'XData', frameVec, 'YData', nanmean(cont_diam, 1));
            xlim(traceAx, [1, nFrames]);
            drawnow;

        end % branch loop

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
        s = getappdata(fig, 'state');
        if ~s.analysisRun
            uialert(fig, 'Run analysis first.', 'No results');  return;
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
            results.cont_diams = s.cont_diams;
            results.times      = s.times;
            results.nanInds    = s.nanInds;
            results.pxsz_um    = s.pxsz_um;
            results.fps        = s.fps;
            results.diamUnit   = s.diamUnit;
            results.timeUnit   = s.timeUnit;
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
        s = getappdata(fig, 'state');
        if ~s.analysisRun
            uialert(fig, 'Run analysis first.', 'No results');  return;
        end

        nB       = numel(s.cont_diams);
        diamLbl  = strrep(s.diamUnit, '\mum', 'microns');
        meanVess = squeeze(mean(double(s.rawVess), 1));

        % ---- create export figure -------------------------------------------
        expFig = figure('Name', 'MAPS — Export', 'Color', 'w', ...
            'Position', [80 80 1300 780]);

        % Layout: left column = vessel image (tall)
        %         top-right  = diameter heatmap
        %         bot-right  = average diameter trace
        ax1 = subplot(2, 3, [1 4], 'Parent', expFig);
        ax2 = subplot(2, 3, [2 3], 'Parent', expFig);
        ax3 = subplot(2, 3, [5 6], 'Parent', expFig);

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

        % ---- save dialog ----------------------------------------------------
        [fn, fp] = uiputfile( ...
            {'*.png','PNG image'; '*.pdf','PDF'; '*.fig','MATLAB figure'}, ...
            'Save figure', fullfile(s.expDir, 'MAPS_figure'));
        if ~isequal(fn, 0)
            saveas(expFig, fullfile(fp, fn));
            postUpdate(['Figure saved: ' fullfile(fp, fn)]);
        end
    end

    % =========================================================================
    %  HELPERS
    % =========================================================================
    function postUpdate(msg)
        txaUpdates.Value = msg;
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
