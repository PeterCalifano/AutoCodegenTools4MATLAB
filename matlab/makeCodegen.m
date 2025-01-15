function [] = makeCodegen(targetFcnName, args_cell, coder_config)
%% PROTOTYPE
% [] = makeCodegen(targetFcnName, args_cell, coder_config)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Automatic code generation makers for mex and lib
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% in1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% Name4                     []
% Name5                     []
% Name6                     []
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% Name4                     []
% Name5                     []
% Name6                     []
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 21-04-2024    Pietro Califano    First version. Very basic codegen call.
% 17-06-2024    Pietro Califano    Extended capability to lib, exe, dll
% 23-12-2024    Pietro Califano    Bug fixes due to mex config
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

% assert(strcmpi(coder_config.Name, 'MexCodeConfig'), 'Only MEX config is currently supported!')

%% Coder settings
bUSE_DEFAULT = false;
allowedConfigTypes = ["mex", "lib", "exe", "dll"];

if isstring(coder_config) || ischar(coder_config) || nargin < 3
    bUSE_DEFAULT = true;
    coder_config = lower(coder_config);
end

if bUSE_DEFAULT

    if nargin < 3
        % No coder config --> assume MEX
        fprintf("No coder configuration object specified. Using default configuration...\n")
        coder_config = coder.config('mex');
        coder_config.TargetLang = 'C++';
        coder_config.GenerateReport = true;
        coder_config.LaunchReport = true;
        coder_config.EnableJIT = false;
        coder_config.MATLABSourceComments = true;

    else
        % Specified default name --> Use default config for specified build type
        for configType = allowedConfigTypes
            if strcmpi(coder_config, configType) 
                break;
            end
        end
    

    if strcmpi(configType, 'mex')
        % DEFAULT CONFIG: MEX
        fprintf("CODER CONFIG: MEX with default configuration...\n")

        coder_config = coder.config('mex', 'ecoder', true);
        coder_config.TargetLang = 'C++';
        coder_config.GenerateReport = true;
        coder_config.LaunchReport = true;
        coder_config.EnableJIT = false;
        coder_config.MATLABSourceComments = true;

    elseif strcmpi(configType, 'lib')
        % DEFAULT CONFIG: LIB
        fprintf("CODER CONFIG: LIB with default configuration...\n")

        coder_config = coder.config('lib', 'ecoder', true);
        coder_config.TargetLang = 'C++';
        coder_config.GenerateReport = true;
        coder_config.LaunchReport = true;
        coder_config.MATLABSourceComments = true;

    elseif strcmpi(configType, 'exe')
        % DEFAULT CONFIG: EXE
        fprintf("CODER CONFIG: EXE with default configuration...\n")

        coder_config = coder.config('exe', 'ecoder', true);
        coder_config.TargetLang = 'C++';
        coder_config.GenerateReport = true;
        coder_config.LaunchReport = true;
        coder_config.MATLABSourceComments = true;

    elseif strcmpi(configType, 'dll')
        % DEFAULT CONFIG: DLL
        fprintf("cODER CONFIG: DLL with default configuration...\n")

        coder_config = coder.config('dll', 'ecoder', true);
        coder_config.TargetLang = 'C++';
        coder_config.GenerateReport = true;
        coder_config.LaunchReport = true;
        coder_config.MATLABSourceComments = true;

    end
    end
end % END OF USE_DEFAULT

% Get build type
if not(isa(coder_config, 'coder.MexCodeConfig'))
    buildType = lower(coder_config.OutputType);
else
    buildType = 'mex';
end



% IF PARALLEL REQUIRED
% coder_config.EnableAutoParallelization = true;
% coder_config.EnableOpenMP = true;

%% Target function details
% Get number of outputs
numOutputs = nargout(targetFcnName);
fprintf('\nGenerating src or compiled code from function %s...\n', string(targetFcnName));

% Extract filename and add MEX indication
[~, targetFcnName, ~] = fileparts(fullfile(targetFcnName));
outputFcnName = strcat(targetFcnName, '_', upper(buildType));

% numOfInputs; % ADD ASSERT to size of args_cell from specification functions

%% CODEGEN CALL
fprintf("---------------------- CODE GENERATION EXECUTION: STARTED ---------------------- \n\n")
% Execute code generation
codegenCommands = {strcat(targetFcnName,'.m'), "-config", coder_config,...
    "-args", args_cell, "-nargout", numOutputs, "-o", outputFcnName};
codegen(codegenCommands{:});
fprintf("\n---------------------- CODE GENERATION EXECUTION: COMPLETED ----------------------\n")
end

%% LOCAL FUNCTION


