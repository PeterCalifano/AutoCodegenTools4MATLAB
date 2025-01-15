function [o_objMODEL_Sfcn] = SLX_AUTOCD_SETUPGEN(i_chModelName, ...
    i_CfgParamsFile, ...
    i_chBuildPath, ...
    i_bBUILD_Sfcn, ...
    i_bCODE_ONLY, ...
    i_bPIL_TEST, ...
    i_cTargetHWname)
arguments
    i_chModelName char
    i_CfgParamsFile {mustBeA(i_CfgParamsFile, ["char", "configset"])} = 'SLX_AUTOCD_config.mat'
    i_chBuildPath char = '.'
    i_bBUILD_Sfcn logical = false
    i_bCODE_ONLY logical = false
    i_bPIL_TEST logical = false
    i_cTargetHWname char = 'Raspberry Pi'
end
%% PROTOTYPE
% [o_objMODEL_Sfcn] = SLX_AUTOCD_SETUPGEN(i_chModelName, ...
%     i_CfgParamsFile, ...
%     i_chBuildPath, ...
%     i_bBUILD_Sfcn, ...
%     i_bCODE_ONLY, ...
%     i_bPIL_TEST, ...
%     i_cTargetHWname);
% arguments
%     i_chModelName char
%     i_CfgParamsFile {mustBeA(i_CfgParamsFile, ["char", "configset"])} = 'SLX_AUTOCD_config.mat'
%     i_chBuildPath char = '.'
%     i_bBUILD_Sfcn logical = false
%     i_bCODE_ONLY logical = false
%     i_bPIL_TEST logical = false
%     i_cTargetHWname char = 'Raspberry Pi'
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
% i_chModelName char
% i_ConfigParams {mustBeA(i_ConfigParams, ["char", "configset"])}
% i_chBuildPath char = '.'
% i_bBUILD_Sfcn logical = false
% i_bCODE_ONLY logical = false
% i_bPIL_TEST logical = false
% i_cHWboardName char = 'Raspberry Pi'
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% o_objMODEL_Sfcn: S-function object for the top model if selected
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
fprintf('LOADED CONFIG: %s\n', i_CfgParamsFile);

if ischar(i_CfgParamsFile)

    % Load mat file with configSet
    tmpObj = load(i_CfgParamsFile, 'AUTOCDconfig');
    slxConfigParams = tmpObj.(i_CfgParamsFile); 

elseif isobject(i_CfgParamsFile)
    slxConfigParams = i_CfgParamsFile;
else
    error('\nConfigSet neither ConfigSet object nor char')
end

%% Load system model
load_system(i_chModelName);
ismodel_loaded = bdIsLoaded(i_chModelName);

if ismodel_loaded == 1
    fprintf('\nMODEL %s LOADING: COMPLETED\n', i_chModelName)
else
    error(strcat('\nMODEL', i_chModelName, 'LOADING: FAILED \n'));
end


%% Check if model uses loaded configSet, else force it
disp('Checking Model configuration parameters...')
currentConfigSet = getActiveConfigSet(i_chModelName);

if ~strcmp(currentConfigSet.Name, slxConfigParams.Name)
    setActiveConfigSet(i_chModelName, slxConfigParams);
    disp('Model configuration set forced as input configuration.')
else
    disp('Model configuration set already matching input configuration')
end

if not(exist('i_chBuildPath', 'dir'))
    mkdir(i_chBuildPath)
end

%% PIL HW board setting
if i_bPIL_TEST == true    
    try
        set_param(i_chModelName, 'HardwareBoard', i_cTargetHWname)
        isPIL_SETUP_FAILED = false;
    catch ME
        warning(strcat('Error encountered in setting Hardware Target architecture\n: ', ME.message));
        isPIL_SETUP_FAILED = true;     
    end
end

if or(isPIL_SETUP_FAILED, not(i_bPIL_TEST))
% Set computer architecture as default
% WORK IN PROGESS
warning('NOT READY YET')
end

%% Try to set parallel building for Model references
try
    parPool = gcp('nocreate');
    if not(isempty(parPool))
        set_param(i_chModelName, 'EnableParallelModelReferenceBuilds', true)
    else
        set_param(i_chModelName, 'EnableParallelModelReferenceBuilds', false)
    end
catch
    % No parallel Toolbox available
    set_param(i_chModelName, 'EnableParallelModelReferenceBuilds', false)
end


%% Check for model references in top model
mdlRef = find_system(i_chModelName, 'BlockType', 'ModelReference');
if not(isempty(mdlRef))
    % Propagate configuration reference to all reference models
    [isPropagated, convertedModels] = Simulink.BlockDiagram.propagateConfigSet(i_chModelName);
    % Check for propagation errors
    if isPropagated == 0
        error(strcat('Configuration Reference propagation failed for models: ', convertedModels(isPropagated == 0)));
    else

        fprintf('\n')
        for modelID = 1:length(convertedModels)
            fprintf('Config. Ref. propagation to %s: DONE\n', convertedModels{modelID});
        end
        % Save system 
        if strcmp(get_param(i_chModelName, 'Dirty'),'on')
            save_system(i_chModelName, 'SaveDirtyReferencedModels', 'on');
        end
    end
end


%% Open model
open(i_chModelName);

% Change directory to BUILD
currentDir = pwd;
cd(i_chBuildPath)

%% Call slbuild to build model
if i_bBUILD_Sfcn == true
    o_objMODEL_Sfcn = slbuild(i_chModelName, ...
        'UpdateThisModelReferenceTarget', 'IfOutOfDate', ...
        'GenerateCodeOnly', i_bCODE_ONLY, ...
        'OpenBuildStatusAutomatically', true);
else
    slbuild(i_chModelName, ...
        'UpdateThisModelReferenceTarget', 'IfOutOfDate', ...
        'GenerateCodeOnly', i_bCODE_ONLY, ...
        'OpenBuildStatusAutomatically', true);
end

% Go back to top directory and addpath
cd(currentDir);
addpath(genpath(strcat(i_chBuildPath, 'slprj/ert')));

