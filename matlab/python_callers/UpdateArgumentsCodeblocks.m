function [bStatus, charCmdOut] = UpdateArgumentsCodeblocks(charTargetFolderPath, enumMode, kwargs)
arguments
    charTargetFolderPath (1,:) {mustBeFolder}
    enumMode             (1,:) string {mustBeMember(enumMode, ["disable", "enable"])}
end
arguments
    kwargs.charLibRoot      (1,1) char
    kwargs.bDryRun          (1,1) logical = false
    kwargs.bBackup          (1,1) logical = false
    kwargs.bCheck           (1,1) logical = false
    kwargs.charPythonExe    (1,:) string {mustBeA(kwargs.charPythonExe, ["string", "char"])} = ""
end
%% PROTOTYPE
% [bStatus, charCmdOut] = UpdateArgumentsCodeblocks(charTargetFolderPath, enumMode, kwargs)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Call the update_arguments_codeblocks.py script through MATLAB's pyenv configuration.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% charTargetFolderPath (1,:) string {mustBeA(charTargetFolderPath, ["string", "char"])} = ""
% enumMode (1,:) string {mustBeMember(enumMode, ["disable", "enable"])} = "disable"
% kwargs.bDryRun (1,1) logical = false
% kwargs.bBackup (1,1) logical = false
% kwargs.bCheck (1,1) logical = false
% kwargs.charPythonExe (1,:) string {mustBeA(kwargs.charPythonExe, ["string", "char"])} = ""
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% status  (1,1) double  System command exit status.
% cmdOut  (1,:) char    System command output.
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 09-01-2026    Pietro Califano     Initial implementation.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% update_arguments_codeblocks.py
% -------------------------------------------------------------------------------------------------------------

% Resolve root folder
if not(isfield(kwargs, "charLibRoot"))
    charLibRoot = GetRepoRoot_();
else
    charLibRoot = kwargs.charLibRoot;
end

if not(isfolder(charTargetFolderPath))
    error('Root folder does not exist: %s', charTargetFolderPath);
end

% Compose python script path
charScriptPath = fullfile(charLibRoot, "lib", "autocodegentools4matlab", "python", "update_arguments_codeblocks.py");

if not(isfile(charScriptPath))
    error('Python script not found at: %s', charScriptPath);
end

% Get python executabòe
charPyExe = ResolvePythonEnv_(kwargs.charPythonExe);

charArgs = ["--root", string(charTargetFolderPath), "--mode", enumMode];
if kwargs.bDryRun
    charArgs = [charArgs, "--dry-run"]; 
end
if kwargs.bBackup
    charArgs = [charArgs, "--backup"]; 
end
if kwargs.bCheck
    charArgs = [charArgs, "--check"]; 
end

% Compose command
charAllArgs = [string(charPyExe), string(charScriptPath), charArgs];
charQuoted = arrayfun(@AddQuoteArg_, charAllArgs);
charCmdIn = strjoin(charQuoted, " ");

% Call python through bash
[bStatus, charCmdOut] = system(char(charCmdIn));

end

% AUXILIARY FUNCTIONS
%%%
function charRepoRoot = GetRepoRoot_()
charRepoRoot = mfilename('fullpath');


charRepoRoot = fileparts(charRepoRoot);

end

%%%
function charPyExe = ResolvePythonEnv_(charPythonExe)

objPyEnv = pyenv;

if strlength(charPythonExe) > 0
    if objPyEnv.Status == "Loaded"
        if not(strcmp(string(objPyEnv.Executable), string(charPythonExe)))
            error('Python already loaded with a different executable: %s', objPyEnv.Executable);
        end
    else
        objPyEnv = pyenv("Version", char(charPythonExe));
    end
end

% Get path
charPyExe = string(objPyEnv.Executable);

if strlength(charPyExe) == 0
    error('No Python executable found by pyenv.');
end

end

%%%
function charOut = AddQuoteArg_(charArg)
charArg = string(charArg);
charOut = "\"" + arg + "\"";
end
