function [] = MakeCodegen(charTargetFcnName, cellInputArgs, objCoderConfig, kwargs)
arguments
    charTargetFcnName  {mustBeText, mustBeA(charTargetFcnName, ["char", "string"])}
    cellInputArgs      {mustBeA(cellInputArgs, "cell")}
    objCoderConfig     {mustBeValidCodegenConfig(objCoderConfig)} = "mex";
end
arguments
    kwargs.charOutputDirectory string {mustBeA(kwargs.charOutputDirectory, ["string", "char"])} = './codegen'
    kwargs.bUseCmakeToolchain (1,1) logical = false;
end
%% PROTOTYPE
% [] = MakeCodegen(charTargetFcnName, cellInputArgs, objCoderConfig, kwargs)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Automatic code generation maker for mex, lib and programs.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% charTargetFcnName  {mustBeText, mustBeA(charTargetFcnName, ["char", "string"])}
% cellInputArgs      {mustBeA(cellInputArgs, "cell")}
% objCoderConfig     {mustBeValidCodegenConfig(objCoderConfig)} = "mex";
% kwargs.charOutputDirectory string {mustBeA(kwargs.charOutputDirectory, ["string", "char"])} = './codegen'
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% [-]
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 21-04-2024    Pietro Califano     First version. Very basic codegen call.
% 17-06-2024    Pietro Califano     Extended capability to lib, exe, dll.
% 23-12-2024    Pietro Califano     Bug fixes due to mex config.
% 02-04-2025    Pietro Califano     Minor reworking for basic usage.
% 31-07-2025    Pietro Califano     Fix errors in validation function; upgrade with kwargs.
% 20-08-2025    Pietro Califano     Improve handling of target paths (-d arg); add cmake toolchain flag.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------

%% Handle inputs
if not(isfolder(kwargs.charOutputDirectory))
    mkdir(kwargs.charOutputDirectory)
else
    % Cleanup folder recursively
    rmdir(kwargs.charOutputDirectory, 's');
    mkdir(kwargs.charOutputDirectory)
end
mustBeFolder(kwargs.charOutputDirectory);

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
        otherwise
            error('Invalid or unsupported configuration type %s.', objCoderConfig);
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
ui32NumOfOutputs = nargout(charTargetFcnName);
fprintf('Generating src or compiled code from function %s...\n', string(charTargetFcnName));

% Extract filename and add MEX indication
[~, charTargetFcnName, ~] = fileparts(fullfile(charTargetFcnName));
if not(strcmpi(charBuildType, "lib"))
    charOutputFcnName = strcat(charTargetFcnName, '_', upper(charBuildType));
else
    charOutputFcnName = strcat(lower(charBuildType), charTargetFcnName);
end

%% CODEGEN CALL
fprintf("---------------------- CODE GENERATION EXECUTION: STARTED ---------------------- \n\n")

% Ensure that output folder exists
mustBeFolder(kwargs.charOutputDirectory);

% Replace by absolute path if any relative is given
charWorkDir = cd(kwargs.charOutputDirectory);
kwargs.charOutputDirectory = pwd; 
% Cleanup target folder before starting
system('rm -rf *');
cd(charWorkDir);

% Change toolchain to CMake
if kwargs.bUseCmakeToolchain
    objCoderConfig.Toolchain = 'CMake';
    objCoderConfig.GenCodeOnly = true;
end

% Execute code generation
codegenCommands = {strcat(charTargetFcnName,'.m'), ...
                    "-v", ...
                    "-o", charOutputFcnName, ...
                    '-report',...
                    '-d', char(kwargs.charOutputDirectory), ...
                    "-config", objCoderConfig,...
                    "-args", cellInputArgs, ...
                    "-nargout", ui32NumOfOutputs};

codegen(codegenCommands{:});

% Copy tmwtypes.h from /usr/local/MATLAB/RXXXX/extern/include to target folder
copyfile(fullfile(matlabroot, "extern/include/tmwtypes.h"), kwargs.charOutputDirectory);

% Call postprocessor of CMakeLists.txt


fprintf("---------------------- CODE GENERATION EXECUTION: COMPLETED ----------------------\n")
end

% AUXILIARY FUNCTIONS
%%% Validation function
function [bValidInput] = mustBeValidCodegenConfig(inputVariable)

mustBeA(inputVariable, ["string", "char", "coder.MexCodeConfig", "coder.EmbeddedCodeConfig", "coder.CodeConfig"]);
if isstring(inputVariable) || ischar(inputVariable)
    mustBeMember(inputVariable, ["mex", "lib", "exe", "dll"]);
end
bValidInput = true;

end

