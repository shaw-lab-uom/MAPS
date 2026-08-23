function [pxsz_um, fps, zstep_um, pxSource, fpsSource] = autoDetectAcqParams(tifPath, expDir)
% autoDetectAcqParams  Try to recover pixel size (microns), frame rate (Hz)
% and z-step (microns) for a vessel TIF without asking the user to type
% them in.
%
% Written by Kira Shaw with Claude Code, Aug 2026. zstep_um added when the
% zstack analysis mode was brought into the GUI - only the TIF-metadata
% path below can supply it (neither the .ini nor .xml branches carry a
% z-step field).
%
% Checks, in order, stopping as soon as both pixel size and fps are found:
%   1. The TIF's own metadata - XResolution + the ImageJ-style
%      ImageDescription block (unit=..., finterval=..., spacing=...) that
%      Fiji writes when it saves a calibrated (hyper)stack.
%   2. A .ini file anywhere under expDir (Scientifica / SciScan rig).
%   3. A .xml file anywhere under expDir (ThorLabs rig).
% Neither the .ini nor .xml step assumes a filename - both search expDir
% (recursively) by extension, so renaming the accompanying metadata file
% doesn't break detection.
% Whatever isn't found is left as NaN so the GUI can fall back to asking
% the user, same as before.
%
%INPUTS
% tifPath : full path to the vessel tif file
% expDir  : experiment directory (folder containing the tif)
%OUTPUTS
% pxsz_um   : pixel size in microns, or NaN if not found anywhere
% fps       : frame rate in Hz, or NaN if not found anywhere
% zstep_um  : z-step in microns (only present for a z-stack tif), or NaN
% pxSource  : where pxsz_um came from - 'TIF metadata' / 'ini file' /
%             'xml file' / 'not found'
% fpsSource : same, for fps

pxsz_um   = NaN;
fps       = NaN;
zstep_um  = NaN;
pxSource  = '';
fpsSource = '';

%% 1) the tif's own metadata -------------------------------------------------
try
    info1 = imfinfo(tifPath);
    info1 = info1(1);

    descr = '';
    if isfield(info1, 'ImageDescription')
        descr = info1.ImageDescription;
    end

    % --- pixel size: XResolution is px/unit, "unit" is stated in descr -----
    if isfield(info1, 'XResolution') && info1.XResolution > 0
        if ~isempty(regexpi(descr, 'unit\s*=\s*micron', 'once')) || ...
           ~isempty(regexpi(descr, 'unit\s*=\s*um\b',    'once'))
            pxsz_um  = 1 / info1.XResolution;      % px/um -> um/px
            pxSource = 'TIF metadata';
        elseif isfield(info1, 'ResolutionUnit')
            % no explicit "unit=micron" - fall back to the TIFF standard
            % ResolutionUnit tag (2 = inch, 3 = centimeter)
            switch info1.ResolutionUnit
                case 2
                    pxsz_um  = 25400 / info1.XResolution;
                    pxSource = 'TIF metadata (inch)';
                case 3
                    pxsz_um  = 10000 / info1.XResolution;
                    pxSource = 'TIF metadata (cm)';
            end
        end
    end

    % --- frame rate: ImageJ's finterval is the time between frames (s) -----
    tok = regexpi(descr, 'finterval\s*=\s*([\d.eE+-]+)', 'tokens', 'once');
    if ~isempty(tok)
        fi = str2double(tok{1});
        if fi > 0
            fps       = 1 / fi;
            fpsSource = 'TIF metadata';
        end
    end

    % --- z-step: ImageJ's "spacing" field, microns (z-stacks only) ---------
    tok = regexpi(descr, 'spacing\s*=\s*([\d.eE+-]+)', 'tokens', 'once');
    if ~isempty(tok)
        zs = str2double(tok{1});
        if zs > 0
            zstep_um = zs;
        end
    end
catch ME
    disp(['autoDetectAcqParams: could not read TIF metadata (' ME.message ')']);
end

if ~isnan(pxsz_um) && ~isnan(fps)
    return;
end

%% 2) a Scientifica / SciScan .ini file somewhere under expDir ---------------
if isnan(pxsz_um) || isnan(fps)
    try
        iniFiles = findFolders(expDir, '*.ini');
        if ~isempty(iniFiles)
            ini_file = ini2struct(iniFiles{1});
            % NOTE: field names below match SciScan .ini output. If your
            % rig writes a .ini file with different variable names, edit
            % the two field names below to match (see ini_file in the
            % workspace to check what they're actually called).
            if isnan(pxsz_um) && isfield(ini_file,'x_') && ...
                    isfield(ini_file.x_,'x0x2epixel0x2esz')
                v = str2double(ini_file.x_.x0x2epixel0x2esz) * 1e6; % m -> um
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
% Written by Kira Shaw with Claude Code, Aug 2026. Was hardcoded to only
% look for a file literally named "Experiment.xml" directly in expDir -
% renaming or moving that file (e.g. into a subfolder, or to something
% like "metaData.xml") would silently fail this check and fall through to
% "not found" with no error. Now searches for any .xml file anywhere under
% expDir instead, the same way the .ini branch above already does, so the
% filename/location isn't assumed.
if isnan(pxsz_um) || isnan(fps)
    try
        xmlFiles = findFolders(expDir, '*.xml');
        if ~isempty(xmlFiles)
            S = readstruct(xmlFiles{1});
            % NOTE: as above, edit the field paths below if your rig's
            % xml file is laid out differently.
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
