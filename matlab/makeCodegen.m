function [] = makeCodegen(charTargetFcnName, cellInputArgs, objCoderConfig)
arguments
    charTargetFcnName  {mustBeText, mustBeA(charTargetFcnName, ["char", "string"])}
    cellInputArgs      {mustBeA(cellInputArgs, "cell")}
    objCoderConfig     {mustBeValidCodegenConfig(objCoderConfig)} = "mex";
end
%% PROTOTYPE
% [] = makeCodegen(charTargetFcnName, cellInputArgs, objCoderConfig)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Automatic code generation makers for mex and lib
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% charTargetFcnName  {mustBeText, mustBeA(charTargetFcnName, ["char", "string"])}
% cellInputArgs      {mustBeA(cellInputArgs, "cell")}
% objCoderConfig     {mustBeValidCodegenConfig(objCoderConfig)} = "mex";
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% [-]
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 21-04-2024    Pietro Califano     First version. Very basic codegen call.
% 17-06-2024    Pietro Califano     Extended capability to lib, exe, dll.
% 23-12-2024    Pietro Califano     Bug fixes due to mex config.
% 02-04-2025    Pietro Califano     Minor reworking for basic usage.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------

%% Coder settings

if isstring(objCoderConfig) || ischar(objCoderConfig) || nargin < 3

    % TODO consider to add common in one single call, and only specify those important for the specific one
    switch lower(objCoderConfig)
        case 'mex'
            fprintf("\nCODER CONFIG: MEX with default configuration...\n")

            objCoderConfig = coder.config('mex', 'ecoder', true);
            objCoderConfig.TargetLang = 'C++';
            objCoderConfig.GenerateReport = true;
            objCoderConfig.LaunchReport = true;
            objCoderConfig.EnableJIT = false;
            objCoderConfig.MATLABSourceComments = true;

        case 'lib'
            fprintf("\nCODER CONFIG: LIB with default configuration...\n")

            objCoderConfig = coder.config('lib', 'ecoder', true);
            objCoderConfig.TargetLang = 'C++';
            objCoderConfig.GenerateReport = true;
            objCoderConfig.LaunchReport = true;
            objCoderConfig.MATLABSourceComments = true;

        case 'exe'
            fprintf("\nCODER CONFIG: LIB with default configuration...\n")

            objCoderConfig = coder.config('exe', 'ecoder', true);
            objCoderConfig.TargetLang = 'C++';
            objCoderConfig.GenerateReport = true;
            objCoderConfig.LaunchReport = true;
            objCoderConfig.MATLABSourceComments = true;
    end

end

% Get build type
if not(isa(objCoderConfig, 'coder.MexCodeConfig'))
    charBuildType = lower(objCoderConfig.OutputType);
else
    charBuildType = 'mex';
end

% IF PARALLEL REQUIRED
% coder_config.EnableAutoParallelization = true;
% coder_config.EnableOpenMP = true;

%% Target function details
% Get number of outputs
numOutputs = nargout(charTargetFcnName);
fprintf('\nGenerating src or compiled code from function %s...\n', string(charTargetFcnName));

% Extract filename and add MEX indication
[~, charTargetFcnName, ~] = fileparts(fullfile(charTargetFcnName));
outputFcnName = strcat(charTargetFcnName, '_', upper(charBuildType));

% numOfInputs; % ADD ASSERT to size of args_cell from specification functions

%% CODEGEN CALL
fprintf("---------------------- CODE GENERATION EXECUTION: STARTED ---------------------- \n\n")
% Execute code generation
codegenCommands = {strcat(charTargetFcnName,'.m'), "-config", objCoderConfig,...
    "-args", cellInputArgs, "-nargout", numOutputs, "-o", outputFcnName};
codegen(codegenCommands{:});
fprintf("\n---------------------- CODE GENERATION EXECUTION: COMPLETED ----------------------\n")
end

%% Validation function
function [bValidInput] = mustBeValidCodegenConfig(inputVariable)

bValidInput = mustBeA(inputVariable, ["string", "char", "coder_config"]) || ...
    ( (isstring || ischar) && mustBeMember(inputVariable, ["mex", "lib", "exe", "dll"]) );

end

