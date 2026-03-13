function strOutputStruct = CleanAndSortStructFields(strInputStruct)
%CLEANSORTSTRUCTFIELDS Recursively remove empty fields from a struct and sort fields
%   strOutputStruct = CLEANSORTSTRUCTFIELDS(strInputStruct) takes a struct strInputStruct
%   (possibly nested) and returns strOutputStruct where any field whose value is empty is removed.
%   All nested structs are cleaned recursively, and their fields are sorted alphabetically.

arguments
    strInputStruct struct   % Input struct to clean and sort
end

% Initialize output as a copy of the input
strOutputStruct = strInputStruct;

% Retrieve all field names (cell array of char)
cellFieldNames = fieldnames(strInputStruct);

% Loop through each field using a double-index
for dIdx = 1:numel(cellFieldNames)
    % Get field content
    charFieldName = cellFieldNames{dIdx};
    tmpFieldValue   = strInputStruct.(charFieldName);

    if isstruct(tmpFieldValue)
        
        % Recursive cleaning for nested struct
        ui32NumStructs = length(tmpFieldValue);

        if ui32NumStructs == 1
            strCleanedStruct = CleanAndSortStructFields(tmpFieldValue);
            % Remove field if nested struct is empty
            if isscalar(strOutputStruct)
                if isempty(fieldnames(strCleanedStruct))
                    strOutputStruct = rmfield(strOutputStruct, charFieldName);
                else
                    strOutputStruct.(charFieldName) = strCleanedStruct;
                end
            else
                % Apply to all structs
                
            end

        else
            % Handle struct arrays
            cellCleanedStruct = cell(1, ui32NumStructs);
            cellFieldNames_All = cell(1, ui32NumStructs);
            for idS = 1:ui32NumStructs
                cellCleanedStruct{idS} = CleanAndSortStructFields(tmpFieldValue(idS));
                cellFieldNames_All{idS} = fieldnames(cellCleanedStruct{idS});
            end

            % Process cell to rebuild struct array
            % Find the union of all field names
            charAllCommonFields = unique( vertcat( cellFieldNames_All{:} ) );

            % For each cleaned struct, add missing fields as empty
            for idS = 1:ui32NumStructs

                charThisNames   = cellFieldNames_All{idS};
                bMissingMask    = ~ismember(charAllCommonFields, charThisNames);
                
                for charEmptyFieldName = charAllCommonFields(bMissingMask).'
                    cellCleanedStruct{idS}.(charEmptyFieldName{1}) = [];
                end
            end
            strOutputStruct.(charFieldName) = orderfields([cellCleanedStruct{:}]);
        end

    elseif isempty(tmpFieldValue)
        % Remove field if its value is empty
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

