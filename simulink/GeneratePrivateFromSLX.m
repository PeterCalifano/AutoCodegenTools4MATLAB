function [cellRequiredVars] = GeneratePrivateFromSLX(charModelTargetName, charPrivateModelExportFolder_, kwargs)
arguments
    charModelTargetName (1,:) char {mustBeText}
    charPrivateModelExportFolder_ (1,:) char {mustBeText} = fullfile(pwd, "export", "private")
end
arguments
    kwargs.enumMode {mustBeMember(kwargs.enumMode, ["Simulation", "CodeGeneration"])} = "CodeGeneration"
    kwargs.bCreateReport  (1,1) logical = true
    kwargs.bObfuscateCode (1,1) logical = true
end % TODO add other options

% Input checks
if isfile(charModelTargetName)
    error('File not found: %s', charModelTargetName);
end

if not(isfolder(charPrivateModelExportFolder_))
    mkdir(charPrivateModelExportFolder_);
end

% Run geneneration
[~, cellRequiredVars] = Simulink.ModelReference.protect(charModelTargetName, ...
                                                        "Mode", "CodeGeneration", ...
                                                        "Path", charPrivateModelExportFolder_, ...
                                                        "Report", kwargs.bCreateReport, ...
                                                        "ObfuscateCode", kwargs.bObfuscateCode, ...
                                                        'Harness', true, ...
                                                        'Project', true, ...
                                                        "Webview", false, ...
                                                        "CodeInterface", "Top model");

end

