function [bSuccessfulExport] = ExportSLXToTargetVersion(charSlxModelNameSrc, ...
                                                    charYearVerMATLAB, ...
                                                    charVariantVerMATLAB, ...
                                                    charExportPath, ...
                                                    charSlxModelNameTarget, ...
                                                    bCloseSystemAfterExport, ...
                                                    bUseDestructiveModelReplace)
arguments
    charSlxModelNameSrc         (1,:) char
    charYearVerMATLAB           (1,:) char {mustBeMember(charYearVerMATLAB, ["2019", "2020", "2021", "2022", "2023", "2024"])}
    charVariantVerMATLAB        (1,1) char {mustBeMember(charVariantVerMATLAB, ["a", "b"])}
    charExportPath              (1,:) char = "./converted_models/"
    charSlxModelNameTarget      (1,:) char = ""
    bCloseSystemAfterExport     (1,1) logical = true
    bUseDestructiveModelReplace    (1,1) logical = false
end

% Initialize
bSuccessfulExport = false;

try
    % Compose and validate version name
    charTargetVerMATLAB = strcat("R", charYearVerMATLAB + charVariantVerMATLAB);
    
    % Compose export name if not given
    if isempty(charSlxModelNameTarget) || strcmpi(charSlxModelNameTarget, "")
        charSlxModelNameTarget = strcat(charSlxModelNameSrc, "_" + charTargetVerMATLAB + ".slx");
    end

    % Load system if not already loaded
    if ~bdIsLoaded(charSlxModelNameSrc)
        fprintf("Model not loaded. Loading system %s...\n", charSlxModelNameSrc);
        load_system(charSlxModelNameSrc);
    end

    % Print info
    fprintf("\nExporting model %s to target version %s as %s...\n", ...
        charSlxModelNameSrc, charTargetVerMATLAB, charSlxModelNameTarget);

    % Export to target version
    save_system(charSlxModelNameSrc, charSlxModelNameTarget, "ExportToVersion", charTargetVerMATLAB);
    
    if bCloseSystemAfterExport == true
        fprintf("Closing model %s...\n", charSlxModelNameSrc);
        % Close system without saving changes
        close_system(charSlxModelNameSrc, 0);
    end

    if not(bUseDestructiveModelReplace)
        % Move exported file to target folder
        if ~isfolder(charExportPath)
            mkdir(charExportPath);
        end
        
        movefile(charSlxModelNameTarget, fullfile(charExportPath, charSlxModelNameTarget));
    else
        warning("Destructive model replace is enabled. Export path ignored. The exported model will overwrite the source model.");
        movefile(charSlxModelNameTarget, charSlxModelNameSrc);
    end

    bSuccessfulExport = true;
    fprintf("Export successful. Exported model saved to %s\n", fullfile(charExportPath, charSlxModelNameTarget));
    return;
    
catch ME
    fprintf("ERROR: Could not export model %s to target version %s. Error message: %s\n", ...
        charSlxModelNameSrc, charTargetVerMATLAB, string(ME.getReport()));
    bSuccessfulExport = false;
    return;
end