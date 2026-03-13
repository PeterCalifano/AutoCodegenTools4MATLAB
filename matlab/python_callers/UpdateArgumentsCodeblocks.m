function [bStatus, charCmdOut] = UpdateArgumentsCodeblocks(charTargetFolderPath, enumMode, kwargs)
arguments
    charTargetFolderPath (1,:) {mustBeFolder}
    enumMode             (1,:) string {mustBeMember(enumMode, ["disable", "enable"])}
end
arguments
    kwargs.charLibRoot      (1,:) char
    kwargs.bDryRun          (1,1) logical = false
    kwargs.bBackup          (1,1) logical = false
    kwargs.bCheck           (1,1) logical = false
    kwargs.charPythonExe    (1,:) string {mustBeText} = ""
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
% kwargs.charPythonExe (1,:) string {mustBeText} = ""
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% status  (1,1) double  System command exit status.
% cmdOut  (1,:) char    System command output.
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 09-01-2026    Pietro Califano     Initial implementation.
% 16-01-2026    Pietro Califano     Fix minor issues
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% update_arguments_codeblocks.py
% -------------------------------------------------------------------------------------------------------------

% Default outputs
bStatus = false;
charCmdOut ='';

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
charScriptPath = fullfile(charLibRoot, "python", "update_arguments_codeblocks.py");

if not(isfile(charScriptPath))
    error('Python script not found at: %s', charScriptPath);
end

% Resolve python executable (prefer explicit, else pyenv, else system python)
[ bPythonAvailable, charPyExe, charPyInfo ] = ResolvePythonEnv_(kwargs.charPythonExe);
assert(bPythonAvailable, 'ERROR: python interpreter is required to run this module. %s', charPyInfo);

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
% Compose command (quoted)
charAllArgs = [string(charPyExe), string(charScriptPath), charArgs];
charQuoted = arrayfun(@AddQuoteArg_, charAllArgs);
charCmdIn = strjoin(charQuoted, " ");

% Execute
[dExitStatus, charCmdOut] = system(char(charCmdIn));

% Print command out
fprintf("System call returned command output:\n\t%s\n", charCmdOut);

% Determine exit flag
bStatus = (dExitStatus == 0);

end

%% AUXILIARY FUNCTIONS
%%%
function charRepoRoot = GetRepoRoot_()
% Resolve name of root repository
charThisScriptPath = fileparts(mfilename('fullpath'));
charRepoRoot = fullfile(fileparts(charThisScriptPath), "..");

cd(charRepoRoot);
charTestPath = pwd();
cd(charThisScriptPath);

% Check repo name
[~, charTestName] = fileparts(charTestPath);

if not(strcmpi(charTestName, "autocodegentools4matlab"))
    warning('Root directory has name %s but expected %s', lower(charTestName), "autocodegentools4matlab")
end

end

%%%
function [bPythonAvailable, charPyExe, charInfo] = ResolvePythonEnv_(charPythonExe)
arguments
    charPythonExe {mustBeText} = ""
end

bPythonAvailable = false;
charPyExe = '';
charInfo = '';

% 1) If user explicitly provided an executable, use it
if strlength(charPythonExe) > 0
    charPyExe = char(charPythonExe);
    [dStatus, charOut] = system([AddQuoteArg_(string(charPyExe)) + " -c ""import sys; print(sys.executable)"""]);
    if dStatus ~= 0
        charInfo = sprintf('Failed to execute provided python executable: %s. Output: %s', charPyExe, charOut);
        return;
    end
    bPythonAvailable = true;
    return;
end

% Try pyenv executable (if configured / loaded)
try
    objPyEnv = pyenv;
    if strlength(string(objPyEnv.Executable)) > 0
        charPyExe = char(string(objPyEnv.Executable));
        [dStatus, charOut] = system([AddQuoteArg_(string(charPyExe)) + " -c ""import sys; print(sys.executable)"""]);
        if dStatus == 0
            bPythonAvailable = true;
            return;
        end
        charInfo = sprintf('pyenv python failed to run. Output: %s', charOut);
    end
catch ME
    charInfo = sprintf('pyenv query failed: %s', ME.message);
end

% Fallback to system python on PATH
charPyExe = 'python';
[dStatus, charOut] = system('python -c "import sys; print(sys.executable)"');
if dStatus == 0
    bPythonAvailable = true;
else
    charInfo = sprintf('No usable python found (pyenv not usable and system python failed). Output: %s', charOut);
end
end

%%%
function strOut = AddQuoteArg_(strArg)
% Quote for shell usage, preserving spaces in paths/args
strArg = string(strArg);

% Escape double quotes inside the argument
strArg = replace(strArg, """", "\""");

% Wrap in double quotes
strOut = """" + strArg + """";
end
