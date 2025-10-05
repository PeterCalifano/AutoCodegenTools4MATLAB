function strOutputStruct = CleanAndSortStructFields(strInputStruct)
    %CLEANSORTSTRUCTFIELDS Recursively remove empty fields from a struct and sort fields
    %   strOutputStruct = CLEANSORTSTRUCTFIELDS(strInputStruct) takes a struct strInputStruct
    %   (possibly nested) and returns strOutputStruct where any field whose value is empty is removed.
    %   All nested structs are cleaned recursively, and their fields are sorted alphabetically.

    arguments
        strInputStruct (1,:) struct   % Input struct to clean and sort
    end

    % Initialize output as a copy of the input
    strOutputStruct = strInputStruct;

    % Retrieve all field names (cell array of char)
    cellFieldNames = fieldnames(strInputStruct);

    % Loop through each field using a index
    for dIdx = 1:numel(cellFieldNames)
        charFieldName = cellFieldNames{dIdx};
        bEmpty = false(1, numel(strInputStruct));  % Track empties for this field

        % Generalized struct array handling
        for idS = 1:numel(strInputStruct)
            varTmpFieldValue   = strInputStruct(idS).(charFieldName);

            if isstruct(varTmpFieldValue)
                % Recursive cleaning for nested struct
                strCleanedStruct = CleanAndSortStructFields(varTmpFieldValue);

                % Remove field if nested struct is empty
                if isempty(fieldnames(strCleanedStruct))
                    % Keep struct schema, mark empty
                    strOutputStruct(idS).(charFieldName) = [];
                    bEmpty(idS) = true;
                else
                    strOutputStruct(idS).(charFieldName) = strCleanedStruct;
                end

            elseif isempty(varTmpFieldValue)
                % Remove field if its value is empty
                strOutputStruct(idS).(charFieldName) = [];
                bEmpty(idS) = true;
            end
            
        end

        % If ALL elements are empty for this field, remove it once, uniformly
        if all(bEmpty)
            strOutputStruct = rmfield(strOutputStruct, charFieldName);
        end

    end

    % After cleaning, sort remaining fields alphabetically
    if ~isempty(strOutputStruct) && isstruct(strOutputStruct)
        try
            % Use MATLAB's built-in orderfields (R2017b+)
            strOutputStruct = orderfields(strOutputStruct);
        catch
            % Fallback for older MATLAB versions
            cellSortedFieldNames = sort(fieldnames(strOutputStruct));
            strReorderedStruct  = struct();
            for dIdx2 = 1:numel(cellSortedFieldNames)
                charSortedName = cellSortedFieldNames{dIdx2};
                strReorderedStruct.(charSortedName) = strOutputStruct.(charSortedName);
            end
            strOutputStruct = strReorderedStruct;
        end
    end
end
