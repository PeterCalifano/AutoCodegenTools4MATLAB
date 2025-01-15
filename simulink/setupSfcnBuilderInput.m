close all
clear
clc

%% AUTOMATIC SETUP FOR S-FUNCTION BUILDER
% Created by PeterC 18-12-2023 

%% TODO:
% 1) Convert to MATLAB function
% 2) Add specification of custom paths and include libs


%% USER-INPUTS
fileName = "testDAsource";
outLibName = "test";
EXTENSION = ".cpp";

COMPILE_AS_LIB = true;

% LOAD DACE
LOAD_DACE = true;
% NOTE: Make sure DACE headers and lib file is installed in the referenced
% directories (machine-dependent)
daceHeadersPath = fullfile("C:\devDir\codeRepoPeterC\c_cpp\DACE_2.0\include\dace");
daceLibPath = fullfile("C:\devDir\codeRepoPeterC\c_cpp\DACE_2.0\lib");

libIncludeCmd = strcat(" -ldace_s ", " -L ", daceLibPath);
headerIncludeCmd = strcat(" -I", daceHeadersPath);

% Create copy of daceDLL in build folder
if not(exist('dace.dll', 'file'))
    copyfile(strcat(daceLibPath, "\dace.dll"), ".");
end
% -------------------------------------------------------------------------

% Generate filenames 
srcFilename = strcat(fileName, EXTENSION);
headerFilename = strcat(fileName, ".h");

libFileName = strcat(outLibName, ".lib");
outputObjFilename = strcat(fileName, ".o");

% CALL COMPILER
% Determine compiler to call
if strcmp(EXTENSION, '.c')
    compilerNameCall = "gcc ";
    mex -setup C

elseif strcmp(EXTENSION, '.cpp')
    compilerNameCall = "g++ ";
    mex -setup C++

else
    error('Unrecognized source file EXTENSION');
end

% Determine CMD construction
if COMPILE_AS_LIB == true
    addFlags = strcat(" -c -v -O3 -Wl,--enable-auto-import ");
elseif COMPILE_AS_LIB == false
    addFlags = strcat( " -v -O3 -Wl,--enable-auto-import ");
end

if LOAD_DACE == false
    createObjFilesCMD = strcat(compilerNameCall, srcFilename, " ", headerFilename, addFlags, "-o ", outputObjFilename);

elseif LOAD_DACE == true
    createObjFilesCMD = strcat(compilerNameCall, libIncludeCmd, headerIncludeCmd, " ",...
        srcFilename, " ", headerFilename, addFlags, "-o ", outputObjFilename);
end

system(createObjFilesCMD);

% CALL ARCHIVE
if COMPILE_AS_LIB == true
    if LOAD_DACE == false
        createLibFilesCMD = strcat("ar rc ", libFileName, " ", outputObjFilename);

    elseif LOAD_DACE == true
        createLibFilesCMD = strcat("ar rc ", libFileName, " ", outputObjFilename);

    end
    system(createLibFilesCMD) % Call ar

end




