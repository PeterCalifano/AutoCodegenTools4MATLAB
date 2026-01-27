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
    charTargetVerMATLAB = strcat("R", charYearVerMATLAB, charVariantVerMATLAB);
    
    % Assert that current MATLAB version is newer than target
    charCurrentVerMATLAB = char(matlabRelease.Release);

    % Extract year and variant from current version
    charCurrentYearMATLAB = extractBetween(charCurrentVerMATLAB, 2, 5);
    charCurrentVariantMATLAB = extractAfter(charCurrentVerMATLAB, 5);

    % Compare versions
    if str2double(charCurrentVerMATLAB) < str2double(charYearVerMATLAB)
        error('Current MATLAB version %s is older than target version %s. Export not possible.', ...
            charCurrentVerMATLAB, charYearVerMATLAB);
    
    elseif str2double(charCurrentVerMATLAB) == str2double(charYearVerMATLAB)
        % Compare variant
        if int32(lower(charCurrentVariantMATLAB)) < int32(lower(charVariantVerMATLAB))
            error('Current MATLAB variant %s is older than target variant %s for year %s. Export not possible.', ...
                charCurrentVariantMATLAB, charVariantVerMATLAB, charYearVerMATLAB);
        end

    end

    
    % Compose export name if not given
    if isempty(charSlxModelNameTarget) || strcmpi(charSlxModelNameTarget, "")
        charSlxModelNameTarget = strcat(charSlxModelNameSrc, "_" + charTargetVerMATLAB + ".slx");
    end

    if ~isfolder(charExportPath)
        mkdir(charExportPath);
    end

    % Compose target and src files
    charSlxModelSrcPath    = which(charSlxModelNameSrc);
    charSlxModelTargetPath = fullfile(charExportPath, strcat(charSlxModelNameTarget, '.slx') );

    % Load system if not already loaded
    if ~bdIsLoaded(charSlxModelNameSrc)
        fprintf("Model not loaded. Loading system %s...\n", charSlxModelNameSrc);
        load_system(charSlxModelNameSrc);
    end

    % Print info
    fprintf("\nExporting model %s to target version %s as %s...\n", ...
        charSlxModelNameSrc, charTargetVerMATLAB, charSlxModelNameTarget);

    % Export to target version
    save_system(charSlxModelNameSrc, charSlxModelTargetPath, "ExportToVersion", charTargetVerMATLAB);
    
    if bCloseSystemAfterExport == true
        fprintf("Closing model %s...\n", charSlxModelNameSrc);
        % Close system without saving changes
        close_system(charSlxModelNameSrc, 0);
    end

    if bUseDestructiveModelReplace
        % Replace existing source model as well
        warning("Destructive model replace is enabled. Export path ignored. The exported model will overwrite the source model.");
        if isfile(charSlxModelSrcPath)
            warning('Existing file with same target name %s found. Deleting it...', charSlxModelNameTarget);
        end

        copyfile(charSlxModelTargetPath, charSlxModelSrcPath);
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
