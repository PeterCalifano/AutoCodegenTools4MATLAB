function [outFileName, fullBUILD_PATH] = casadiFcnCodegen(casadiFunObj, OUTPUT_TYPE, BUILD_PATH, compilerOflag)
    arguments
        casadiFunObj (1,1) casadi.Function
        OUTPUT_TYPE = 'mex'; % Default: mex file
        BUILD_PATH = '.' % Default: build in the same folder
        compilerOflag = '-O3' % Default: max optimization
    end
%% PROTOTYPE
% [outFileName] = casadiFcnCodegen(casadiFunObj, OUTPUT_TYPE, BUILD_PATH, compilerOflag)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% in1 [dim] description
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 07-12-2023    Pietro Califano     Code adapted from casadi forum
% 18-12-2023    Pietro Califano     Reworked for enchanced functionalities
%                                   and S-function generation.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% Casadi package
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------

%% SETTINGS SETUP
import casadi.*
EXTENSION = 'c';
casadiCodeGenOpts = struct;

if strcmpi(OUTPUT_TYPE, 'mex')
    % MEX BUILD
    casadiCodeGenOpts.main = true;
    casadiCodeGenOpts.mex = true;
    casadiCodeGenOpts.verbose = true;

elseif strcmpi(OUTPUT_TYPE, 'c')
    % C SOURCE ONLY BUILD
    casadiCodeGenOpts.main = true;
    casadiCodeGenOpts.with_header = true;
    casadiCodeGenOpts.verbose = true;

elseif strcmpi(OUTPUT_TYPE, 'cpp')
    % C++ SOURCE ONLY BUILD
    casadiCodeGenOpts.main = true;
    casadiCodeGenOpts.with_header = true;
    casadiCodeGenOpts.verbose = true;

    EXTENSION = 'cpp';

elseif strcmpi(OUTPUT_TYPE, 'sfcn')
    % BUILD FOR S-FUNCTION GENERATION
    casadiCodeGenOpts.main = true;
    casadiCodeGenOpts.with_header = true;
%     casadiCodeGenOpts.casadi_real = 'real_T';
%     casadiCodeGenOpts.casadi_int = 'int_T';
    casadiCodeGenOpts.verbose = true;
    
elseif strcmpi(OUTPUT_TYPE, 'exe')
    % TODO;
end

% Define filename
outFileName = strcat(casadiFunObj.name, '_MEX');
mainSourceName = [casadiFunObj.name, '.', EXTENSION]; % [BUILD_PATH, '/', casadiFunObj.name, '.c'];

% Get current directory absolute path
currentDir = pwd;

%% START PROCESS
if ~strcmp(BUILD_PATH, currentDir) && not(exist(BUILD_PATH, 'dir'))
    mkdir(BUILD_PATH)
end

%% CODE GENERATOR CALL
cd(BUILD_PATH); % Change working directory to BUILD_PATH

% Generate C source code from Casadi function in BUILT_PATH
codegenObj = CodeGenerator(casadiFunObj.name, casadiCodeGenOpts);
codegenObj.add(casadiFunObj); % Add main file

if strcmpi(OUTPUT_TYPE, 'sfcn')
    codegenObj.add_include('simstruc.h'); % Add main file
end

codegenObj.generate();

% DIRECT GENERATION FROM FUN OBJECT
% casadiFunObj.generate(fullPathName, casadiCodeGenOpts);


%% MEX COMPILATION
if strcmpi(OUTPUT_TYPE, 'mex')
    disp(['Compiling with -Oflag:', compilerOflag])

    % CALL MEX API for building
    mex(mainSourceName, '-largeArrayDims', strcat('COPTIMFLAGS="',compilerOflag,'"'), '-output', outFileName);
end

%% END PROCESS
cd(currentDir); % Go back to starting directory
fullBUILD_PATH = BUILD_PATH;

end


