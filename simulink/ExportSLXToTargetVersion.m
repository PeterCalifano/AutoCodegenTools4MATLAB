function [bSuccessfulExport] = ExportSLXToTargetVersion(charSlxModelNameSrc, ...
                                                    charYearVerMATLAB, ...
                                                    charVariantVerMATLAB, ...
                                                    charExportPath, ...
                                                    charSlxModelNameTarget)
arguments
    charSlxModelNameSrc     (1,:) char
    charYearVerMATLAB       (1,:) char {mustBeMember(charYearVerMATLAB, ["2019", "2020", "2021", "2022", "2023", "2024"])}
    charVariantVerMATLAB    (1,1) char {mustBeMember(charVariantVerMATLAB, ["a", "b"])}
    charExportPath          (1,:) char = "./converted_models/"
    charSlxModelNameTarget  (1,:) char = ""
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
    
    % Load system
    load_system(charSlxModelNameSrc);
    
    % Export to target version
    save_system(charSlxModelNameSrc, charSlxModelNameTarget, "ExportToVersion", charTargetVerMATLAB);
    
    % Close system without saving changes
    close_system(charSlxModelNameSrc, 0);
    
    % Move exported file to target folder
    if ~isfolder(charExportPath)
        mkdir(charExportPath);
    end
    
    movefile(charSlxModelNameTarget, fullfile(charExportPath, charSlxModelNameTarget));
    
    bSuccessfulExport = true;
    return;
    
catch ME
    fprintf("ERROR: Could not export model %s to target version %s. Error message: %s\n", ...
        charSlxModelNameSrc, charTargetVerMATLAB, string(ME.getReport()));
    bSuccessfulExport = false;
    return;
end