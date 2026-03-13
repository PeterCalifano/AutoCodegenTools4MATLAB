function [charBuildInfoPath, objHandleCfg, charPackageFilePath] = GenerateCodeFromSLX(charModelPath, kwargs)
arguments
    charModelPath (1,:) char {mustBeText}
end
arguments
    kwargs.enumPackageType (1,:) char {mustBeMember(kwargs.enumPackageType, ["flat", "hierarchical"])} = "flat"
    kwargs.bPackagedBuild   (1,1) logical = false
    kwargs.enumTargetArch   %(1,:) string {mustBeText, mustBeMember(kwargs.enumTargetArch, [""])}
    kwargs.enumTargetType   (1,:) string {mustBeText, mustBeMember(kwargs.enumTargetType, ["ert", "grt"])}
    kwargs.charBuildDir     (1,:) char {mustBeText} = fullfile(pwd(), "build")
    kwargs.bVerbose         (1,1) logical = true
    kwargs.bGenerateReport  (1,1) logical = true
    kwargs.bGenCodeOnly     (1,1) logical = false
    kwargs.charToolchain    (1,:) char {mustBeText, validateToolchain_(kwargs.charToolchain)} = "CMake"
    kwargs.objConfigSet     {mustBeA(kwargs.objConfigSet, ["double", "Simulink.ConfigSet", "Simulink.ConfigSetRef"])} = []
    kwargs.bGenerateMakefile   (1,1) logical = true
    kwargs.bGenerateSampleMain (1,1) logical = true
    kwargs.bCheckMdlBeforeBuild (1,1) logical = true    
end
%% SIGNATURE
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% in1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 25-09-2025    Pietro Califano     First prototype implementation (initialized by GPT)
% 26-09-2025    Pietro Califano     Bug fixes, extend functionalities to handle configsets, add packaging
%                                   functionalities for standalone output
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------

%% Function code

% Generate C code from a .slx without GUI.
% Usage (CLI):
%   matlab -batch "generate_slx_code('myModel.slx', 'Target','ert', 'BuildDir','build')"

% License check
[bLicenseAvailable] = license('test','Simulink');
if ~bLicenseAvailable
    error('Simulink license required. %s', charErrMsg); 
end

% Decompose path to model
[~, charMdlName, charExt] = fileparts(charModelPath);

% Check if model has slx extension
if ~strcmpi(charExt,'.slx')
    error('Input must be a .slx file.'); 
end

if not(isfile(charModelPath))
    error('Target file not found: %s', charModelPath); 
end

if not(isfolder(kwargs.charBuildDir))
    warning('Build folder not found. Creating it...');
    mkdir(kwargs.charBuildDir);
end

% File-gen folder definition
charCacheDir = fullfile(kwargs.charBuildDir, 'cache');
if not(isfolder(charCacheDir))
    mkdir(charCacheDir);
end

% Set code generation folders
Simulink.fileGenControl('set', ...
                        'CodeGenFolder', kwargs.charBuildDir, ...
                        'CacheFolder',   charCacheDir, ...
                        'createDir',     true);

% Load model in memory
load_system(charModelPath);

% Choose target 
enumTargetType = lower(string(kwargs.enumTargetType));

if strcmpi(enumTargetType, "ert") && ~license('test', 'RTW_Embedded_Coder')
    warning('Embedded Coder not available. Falling back to grt...');
    enumTargetType = "grt";
end

% Define output filename
charSysTlc = strcat(enumTargetType, ".tlc");

fprintf('\nUpdating configuration parameters of simulink models...\n')
if isempty(kwargs.objConfigSet)
    %%% Try to get config and set params from system

    % Get currently active configset
    objHandleCfg = getActiveConfigSet(charMdlName);

    % If config reference, try to resolve loaded config set object from base workspace
    try
        if isa(objHandleCfg, 'Simulink.ConfigSetRef')
            charCfgFromBase = get_param(objHandleCfg, 'SourceName');
            objHandleCfg = evalin('base', charCfgFromBase);
        end
    catch ME
        error('SLX model %s uses a config. set reference %s. Resolution from base workspace failed with error: %s.', ...
            charMdlName, charCfgFromBase, string(ME.message) );
    end

    % Set codegen config in configset
    ApplyConfigParams_(objHandleCfg, charSysTlc, kwargs);

    % Activate config set
    setActiveConfigSet(charMdlName, objHandleCfg.Name);

elseif isa(kwargs.objConfigSet, "Simulink.ConfigSetRef") || isa(kwargs.objConfigSet, "Simulink.ConfigSet")
    %%% Inject configset from configset reference into model
    % DEVNOTE: untested branch

    if isa(kwargs.objConfigSet, "Simulink.ConfigSetRef")
        charCfgFromBase = get_param(kwargs.objConfigSet, 'SourceName');
        objHandleCfg = evalin('base', charCfgFromBase);
    else
        objHandleCfg = kwargs.objConfigSet;
    end

    % Edit the referenced ConfigSet
    ApplyConfigParams_(objHandleCfg, charSysTlc, kwargs);

    % Set and activate config set
    try
        setActiveConfigSet(charMdlName, objHandleCfg.Name);
    catch
        attachConfigSet(charMdlName, objHandleCfg);
        setActiveConfigSet(charMdlName, objHandleCfg.Name);
    end

else
    error('Invalid configuration: you must provide a valid config set or no configset at all.')
end

% Ensure configset is propagated to referenced models
objMdlRef = find_system(charMdlName, 'BlockType', 'ModelReference');
if not(isempty(objMdlRef))

    [bIsPropagated, cellMdlRefs] = Simulink.BlockDiagram.propagateConfigSet(charMdlName);
    if ~bIsPropagated
        error("Configuration Reference propagation failed for: %s", strjoin(cellMdlRefs, ", "));
    else
        for modelID = 1:length(cellMdlRefs)
            fprintf('Config. reference propagation to %s: DONE\n', cellMdlRefs{modelID});
        end

        % Save system
        if strcmp(get_param(charMdlName, 'Dirty'),'on')
            % save_system(cellParent_{:}, 'SaveDirtyReferencedModels', 'on');
        end
    end
end
fprintf('\n')

% Ensure model updates without opening UI
set_param(charMdlName, 'SimulationCommand', 'update');

% Build model
slbuild(charMdlName);

% Get output directory
objCfg = Simulink.fileGenControl('getConfig');
charBuildInfoPath = fullfile(objCfg.CodeGenFolder, ...
    sprintf('%s_%s_rtw', charMdlName, char(enumTargetType)));

if isfolder(charBuildInfoPath)
    fprintf('\nCode generated in folder: %s\n', charBuildInfoPath);
else
    warning('Expected output folder not found. Check build logs.');
end

if kwargs.bPackagedBuild && isfolder(charBuildInfoPath)
    % Compose path to file
    charPackageFilePath = fullfile(charBuildInfoPath, '..', sprintf('%s_standalone_pkg.zip', charMdlName));

    % Pack all sources, headers, makefiles, and libs into one folder/zip
    packNGo(charBuildInfoPath, ...
            'fileName', charPackageFilePath, ...
            'minimalHeaders', true, ...
            'includeReport', true, ...
            'packType', kwargs.enumPackageType);

elseif kwargs.bPackagedBuild
    warning('Packaging failed because build folder is not found!');
else
    charPackageFilePath = "";
end

% Cleanup and close system
close_system(charMdlName, 0);
end

%% Auxiliary functions
function ApplyConfigParams_(objConfigSet, charSysTlc, kwargs)
arguments
    objConfigSet {mustBeA(objConfigSet, ["double", "Simulink.ConfigSet", "Simulink.ConfigSetRef"])}
    charSysTlc
    kwargs
end
% Function to apply configuration params modifications

if strcmpi(charSysTlc, 'ert.tlc')
    set_param(objConfigSet, ...
            'GenCodeOnly', EvalTernaryIf(kwargs.bGenCodeOnly, 'on', 'off'), ...
            'RTWVerbose',     EvalTernaryIf(kwargs.bVerbose, 'on', 'off'), ...
            'SystemTargetFile', charSysTlc, ...
            'Toolchain',        kwargs.charToolchain, ...
            'GenerateReport',   EvalTernaryIf(kwargs.bGenerateReport, 'on', 'off'), ...
            'GenerateMakefile', EvalTernaryIf(kwargs.bGenerateMakefile, 'on', 'off'), ...
            'CheckMdlBeforeBuild', EvalTernaryIf(kwargs.bCheckMdlBeforeBuild, 'warning', 'off'), ...
            'GenerateSampleERTMain', EvalTernaryIf(kwargs.bGenerateSampleMain, 'on', 'off') ...
            );

else
    set_param(objConfigSet, ...
            'GenCodeOnly', EvalTernaryIf(kwargs.bGenCodeOnly, 'on', 'off'), ...
            'RTWVerbose',     EvalTernaryIf(kwargs.bVerbose, 'on', 'off'), ...
            'SystemTargetFile', charSysTlc, ...
            'Toolchain',        kwargs.charToolchain, ...
            'GenerateReport',   EvalTernaryIf(kwargs.bGenerateReport, 'on', 'off'), ...
            'GenerateMakefile', EvalTernaryIf(kwargs.bGenerateMakefile, 'on', 'off'), ...
            'CheckMdlBeforeBuild', EvalTernaryIf(kwargs.bCheckMdlBeforeBuild, 'on (proceed with warnings)', 'off'), ...
            'ProdHWDeviceType', kwargs.enumTargetArch);
end

end

function validateToolchain_(charToolchain)
arguments
    charToolchain (1,:) char {mustBeText}
end
try
    % Function to validate toolchain selection
    cellAvailableToolchains = coder.make.getToolchains();

    if not(strcmpi(charToolchain, "Automatically locate an installed toolchain"))
        mustBeMember(charToolchain, [arrayfun( @(tlchain) tlchain{:}, cellAvailableToolchains, 'uni', false)]);
    end

catch ME
    error('Invalid toolchain selection. Got \n %s', string(ME.message) );
end

end
