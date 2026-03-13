function [objMODEL_Sfcn] = SLX_AUTOCD_SETUPGEN(chModelName, ...
    CfgParamsFile, ...
    chBuildPath, ...
    bBUILD_Sfcn, ...
    bCODE_ONLY, ...
    bPIL_TEST, ...
    cTargetHWname)
arguments
    chModelName char
    CfgParamsFile {mustBeA(CfgParamsFile, ["char", "Simulink.ConfigS6et"])} = 'SLX_AUTOCD_config.mat'
    chBuildPath char = '.'
    bBUILD_Sfcn logical = false
    bCODE_ONLY logical = false
    bPIL_TEST logical = false
    cTargetHWname char = 'Raspberry Pi'
end
%% PROTOTYPE
% [objMODEL_Sfcn] = SLX_AUTOCD_SETUPGEN(chModelName, ...
%     CfgParamsFile, ...
%     chBuildPath, ...
%     bBUILD_Sfcn, ...
%     bCODE_ONLY, ...
%     bPIL_TEST, ...
%     cTargetHWname);
% arguments
%     chModelName char
%     CfgParamsFile {mustBeA(CfgParamsFile, ["char", "configset"])} = 'SLX_AUTOCD_config.mat'
%     chBuildPath char = '.'
%     bBUILD_Sfcn logical = false
%     bCODE_ONLY logical = false
%     bPIL_TEST logical = false
%     cTargetHWname char = 'Raspberry Pi'
% end
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Function for automatic setup, configuration parameters loading and code
% generation run for generic SLX models with/without Model reference
% blocks. Functionalities enabled by flags:
% 1) S-function/Executable of the model can be generated if supported.
% 2) Target Hardware board setting for PIL test
% 3) Parallel toolbox is used to accelerate generation if pool is available
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% chModelName char
% ConfigParams {mustBeA(ConfigParams, ["char", "configset"])}
% chBuildPath char = '.'
% bBUILD_Sfcn logical = false
% bCODE_ONLY logical = false
% bPIL_TEST logical = false
% cHWboardName char = 'Raspberry Pi'
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% objMODEL_Sfcn: S-function object for the top model if selected
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 07-12-2023    Pietro Califano     Enhanced version of prototype function coded for 6S cubesat.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% 1) Simulink, MATLAB and Embedded coder
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% 1) ADD CONFIG CHECKS for critical options in config parameters
% 2) Setting of device architecture for Hardware implementation
% -------------------------------------------------------------------------------------------------------------

% TODO: 
% 1) ADD CONFIG CHECKS for critical options in config parameters
% 2) Code for PIL testing architecture setup


% Load configuration parameters 
fprintf('LOADED CONFIG: %s\n', CfgParamsFile);

if ischar(CfgParamsFile)

    % Load mat file with configSet
    tmpObj = load(CfgParamsFile, 'AUTOCDconfig');
    slxConfigParams = tmpObj.(CfgParamsFile); 

elseif isobject(CfgParamsFile)
    slxConfigParams = CfgParamsFile;
else
    error('\nConfigSet neither ConfigSet object nor char')
end

%% Load system model
load_system(chModelName);
ismodel_loaded = bdIsLoaded(chModelName);

if ismodel_loaded == 1
    fprintf('\nMODEL %s LOADING: COMPLETED\n', chModelName)
else
    error(strcat('\nMODEL', chModelName, 'LOADING: FAILED \n'));
end


%% Check if model uses loaded configSet, else force it
disp('Checking Model configuration parameters...')
currentConfigSet = getActiveConfigSet(chModelName);

if ~strcmp(currentConfigSet.Name, slxConfigParams.Name)
    setActiveConfigSet(chModelName, slxConfigParams);
    disp('Model configuration set forced as input configuration.')
else
    disp('Model configuration set already matching input configuration')
end

if not(exist('chBuildPath', 'dir'))
    mkdir(chBuildPath)
end

%% PIL HW board setting
if bPIL_TEST == true    
    try
        set_param(chModelName, 'HardwareBoard', cTargetHWname)
        isPIL_SETUP_FAILED = false;
    catch ME
        warning(strcat('Error encountered in setting Hardware Target architecture\n: ', ME.message));
        isPIL_SETUP_FAILED = true;     
    end
end

if or(isPIL_SETUP_FAILED, not(bPIL_TEST))
% Set computer architecture as default
% WORK IN PROGESS
warning('NOT READY YET')
end

%% Try to set parallel building for Model references
try
    parPool = gcp('nocreate');
    if not(isempty(parPool))
        set_param(chModelName, 'EnableParallelModelReferenceBuilds', true)
    else
        set_param(chModelName, 'EnableParallelModelReferenceBuilds', false)
    end
catch
    % No parallel Toolbox available
    set_param(chModelName, 'EnableParallelModelReferenceBuilds', false)
end


%% Check for model references in top model
mdlRef = find_system(chModelName, 'BlockType', 'ModelReference');
if not(isempty(mdlRef))
    % Propagate configuration reference to all reference models
    [isPropagated, convertedModels] = Simulink.BlockDiagram.propagateConfigSet(chModelName);
    % Check for propagation errors
    if isPropagated == 0
        error(strcat('Configuration Reference propagation failed for models: ', convertedModels(isPropagated == 0)));
    else

        fprintf('\n')
        for modelID = 1:length(convertedModels)
            fprintf('Config. Ref. propagation to %s: DONE\n', convertedModels{modelID});
        end
        % Save system 
        if strcmp(get_param(chModelName, 'Dirty'),'on')
            save_system(chModelName, 'SaveDirtyReferencedModels', 'on');
        end
    end
end


%% Open model
open(chModelName);

% Change directory to BUILD
currentDir = pwd;
cd(chBuildPath)

%% Call slbuild to build model
if bBUILD_Sfcn == true
    objMODEL_Sfcn = slbuild(chModelName, ...
        'UpdateThisModelReferenceTarget', 'IfOutOfDate', ...
        'GenerateCodeOnly', bCODE_ONLY, ...
        'OpenBuildStatusAutomatically', true);
else
    slbuild(chModelName, ...
        'UpdateThisModelReferenceTarget', 'IfOutOfDate', ...
        'GenerateCodeOnly', bCODE_ONLY, ...
        'OpenBuildStatusAutomatically', true);
end

% Go back to top directory and addpath
cd(currentDir);
addpath(genpath(strcat(chBuildPath, 'slprj/ert')));

