function [pxsz_um, fps, zstep_um, pxSource, fpsSource] = autoDetectAcqParams(tifPath, expDir)
% autoDetectAcqParams  Try to recover pixel size (microns), frame rate (Hz)
% and z-step (microns) for a vessel TIF without asking the user to type
% them in.
%
% Written by Kira Shaw with Claude Code, Aug 2026. zstep_um added when the
% zstack analysis mode was brought into the GUI. OME-XML branch added Aug
% 2026 to support OME-TIFF output from modern microscopes.
%
% Checks, in order, stopping as soon as both pixel size and fps are found:
%   1a. OME-XML in the TIF's ImageDescription (OME-TIFF from microscope).
%       PhysicalSizeX/Z give pixel/z-step; TimeIncrement gives fps.
%       Checked first because it is explicit and unit-tagged.
%   1b. ImageJ-style XResolution + ImageDescription tags (unit=...,
%       finterval=..., spacing=...) written by Fiji.
%   2.  A .ini file anywhere under expDir (Scientifica / SciScan rig).
%   3.  A .xml file anywhere under expDir (ThorLabs rig).
% Whatever isn't found is left as NaN so the GUI falls back to asking
% the user.
%
%INPUTS
% tifPath : full path to the vessel tif file (TIF or OME-TIFF)
% expDir  : experiment directory (folder containing the tif)
%OUTPUTS
% pxsz_um   : pixel size in microns, or NaN if not found anywhere
% fps       : frame rate in Hz, or NaN if not found anywhere
% zstep_um  : z-step in microns (z-stacks only), or NaN
% pxSource  : where pxsz_um came from
% fpsSource : where fps came from

pxsz_um   = NaN;
fps       = NaN;
zstep_um  = NaN;
pxSource  = '';
fpsSource = '';

%% 1) the tif's own metadata --------------------------------------------------
try
    info1 = imfinfo(tifPath);
    info1 = info1(1);

    descr = '';
    if isfield(info1, 'ImageDescription') && ischar(info1.ImageDescription)
        descr = info1.ImageDescription(:)';  % ensure row char vector
    end

    % --- 1a: OME-XML (OME-TIFF written by confocal/2P microscopes) ----------
    % OME-TIFF embeds OME-XML in the ImageDescription of the first IFD.
    % PhysicalSize attributes are explicit and carry their own unit tag, so
    % this is more reliable than inferring from XResolution below.
    if ~isempty(regexpi(descr, '<OME|ome\.xsd|openmicroscopy\.org', 'once'))

        % pixel size (PhysicalSizeX; OME requires square pixels so X == Y)
        tok = regexpi(descr, 'PhysicalSizeX\s*=\s*"([^"]+)"', 'tokens', 'once');
        if ~isempty(tok)
            unitTok = regexpi(descr, 'PhysicalSizeXUnit\s*=\s*"([^"]+)"', 'tokens', 'once');
            v = omeToUm(str2double(tok{1}), unitTok);
            if v > 0
                pxsz_um  = v;
                pxSource = 'OME-XML';
            end
        end

        % z-step (PhysicalSizeZ)
        tok = regexpi(descr, 'PhysicalSizeZ\s*=\s*"([^"]+)"', 'tokens', 'once');
        if ~isempty(tok)
            unitTok = regexpi(descr, 'PhysicalSizeZUnit\s*=\s*"([^"]+)"', 'tokens', 'once');
            v = omeToUm(str2double(tok{1}), unitTok);
            if v > 0, zstep_um = v; end
        end

        % frame / plane rate (TimeIncrement = seconds per plane → fps = 1/ti)
        tok = regexpi(descr, 'TimeIncrement\s*=\s*"([^"]+)"', 'tokens', 'once');
        if ~isempty(tok)
            ti = str2double(tok{1});
            unitTok = regexpi(descr, 'TimeIncrementUnit\s*=\s*"([^"]+)"', 'tokens', 'once');
            if ~isempty(unitTok)
                u = strtrim(unitTok{1});
                if ~isempty(regexpi(u, '^ms',  'once')), ti = ti / 1000; end
                if ~isempty(regexpi(u, '^min', 'once')), ti = ti * 60;   end
            end
            if ti > 0
                fps       = 1 / ti;
                fpsSource = 'OME-XML';
            end
        end
    end

    % --- 1b: ImageJ-style XResolution + description tags --------------------
    % XResolution can be stored as a 2-element rational [num den] in some
    % TIFFs; take the first element (the computed value) to keep comparisons
    % scalar and avoid the && / || non-scalar error.
    xres = NaN;
    if isfield(info1, 'XResolution') && ~isempty(info1.XResolution)
        xres = double(info1.XResolution(1));
    end
    if isnan(pxsz_um) && xres > 0
        if ~isempty(regexpi(descr, 'unit\s*=\s*micron', 'once')) || ...
           ~isempty(regexpi(descr, 'unit\s*=\s*um\b',    'once'))
            pxsz_um  = 1 / xres;
            pxSource = 'TIF metadata';
        elseif isfield(info1, 'ResolutionUnit')
            switch info1.ResolutionUnit
                case 2
                    pxsz_um  = 25400 / xres;
                    pxSource = 'TIF metadata (inch)';
                case 3
                    pxsz_um  = 10000 / xres;
                    pxSource = 'TIF metadata (cm)';
            end
        end
    end

    % frame rate: ImageJ's finterval is seconds between frames
    if isnan(fps)
        tok = regexpi(descr, 'finterval\s*=\s*([\d.eE+-]+)', 'tokens', 'once');
        if ~isempty(tok)
            fi = str2double(tok{1});
            if fi > 0
                fps       = 1 / fi;
                fpsSource = 'TIF metadata';
            end
        end
    end

    % z-step: ImageJ's "spacing" field (z-stacks only)
    if isnan(zstep_um)
        tok = regexpi(descr, 'spacing\s*=\s*([\d.eE+-]+)', 'tokens', 'once');
        if ~isempty(tok)
            zs = str2double(tok{1});
            if zs > 0, zstep_um = zs; end
        end
    end

catch ME
    disp(['autoDetectAcqParams: could not read TIF metadata (' ME.message ')']);
end

if ~isnan(pxsz_um) && ~isnan(fps)
    if isempty(pxSource),  pxSource  = 'not found'; end
    if isempty(fpsSource), fpsSource = 'not found'; end
    return;
end

%% 2) a Scientifica / SciScan .ini file somewhere under expDir ---------------
if isnan(pxsz_um) || isnan(fps)
    try
        iniFiles = findFolders(expDir, '*.ini');
        if ~isempty(iniFiles)
            ini_file = ini2struct(iniFiles{1});
            if isnan(pxsz_um) && isfield(ini_file,'x_') && ...
                    isfield(ini_file.x_,'x0x2epixel0x2esz')
                v = str2double(ini_file.x_.x0x2epixel0x2esz) * 1e6;
                if v > 0
                    pxsz_um  = v;
                    pxSource = 'ini file';
                end
            end
            if isnan(fps) && isfield(ini_file,'x_') && ...
                    isfield(ini_file.x_,'frames0x2ep0x2esec')
                v = str2double(ini_file.x_.frames0x2ep0x2esec);
                if v > 0
                    fps       = v;
                    fpsSource = 'ini file';
                end
            end
        end
    catch ME
        disp(['autoDetectAcqParams: could not read ini file (' ME.message ')']);
    end
end

%% 3) a ThorLabs-style *.xml file anywhere under expDir ----------------------
if isnan(pxsz_um) || isnan(fps)
    try
        xmlFiles = findFolders(expDir, '*.xml');
        if ~isempty(xmlFiles)
            S = readstruct(xmlFiles{1});
            if isnan(pxsz_um) && isfield(S,'LSM') && isfield(S.LSM,'pixelSizeUMAttribute')
                v = S.LSM.pixelSizeUMAttribute;
                if v > 0
                    pxsz_um  = v;
                    pxSource = 'xml file';
                end
            end
            if isnan(fps) && isfield(S,'LSM') && isfield(S.LSM,'frameRateAttribute')
                v = S.LSM.frameRateAttribute;
                if v > 0
                    fps       = v;
                    fpsSource = 'xml file';
                end
            end
        end
    catch ME
        disp(['autoDetectAcqParams: could not read xml file (' ME.message ')']);
    end
end

if isempty(pxSource),  pxSource  = 'not found'; end
if isempty(fpsSource), fpsSource = 'not found'; end

end

% ---- local helper -----------------------------------------------------------
function um = omeToUm(val, unitCell)
% Convert an OME PhysicalSize value to microns.
% OME default unit is microns when PhysicalSizeXUnit is absent.
    um = val;
    if isempty(unitCell), return; end
    u = strtrim(unitCell{1});
    if     ~isempty(regexpi(u, 'nm',       'once')), um = val / 1000;
    elseif ~isempty(regexpi(u, 'mm',       'once')), um = val * 1000;
    elseif ~isempty(regexpi(u, 'cm',       'once')), um = val * 10000;
    elseif ~isempty(regexpi(u, '^m$',      'once')), um = val * 1e6;
    % µm / um / μm all map to identity — default, no conversion needed
    end
end
