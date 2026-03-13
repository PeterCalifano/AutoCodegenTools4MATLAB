function strLast = ExtractLastTimeFromTimeseries(strDataTimeSeries)
% ExtractLastTimeFromTimeseries Extracts the Data array at the last time instant for each timeseries in a struct
% Recursively processes nested structs of timeseries objects
% Adds check: only extract last sample when time dimension matches data length
%
%   INPUT
%       strDataTimeSeries (1,1) struct : each field is either a timeseries object or a struct
%   OUTPUT
%       strLast          (1,1) struct : same fields but each the Data array at the final time or nested struct

arguments
    strDataTimeSeries (1,1) struct
end

% Initialize output struct
strLast = struct();

% Get all field names
cellFieldNames = fieldnames(strDataTimeSeries);

% Loop over each field
for iIdx = 1:numel(cellFieldNames)
    charFieldName = cellFieldNames{iIdx};
    tmpField      = strDataTimeSeries.(charFieldName);

    if isstruct(tmpField)
        % Recursive call for nested struct
        strLast.(charFieldName) = ExtractLastTimeFromTimeseries(tmpField);
    elseif isa(tmpField, 'timeseries')
        % Process timeseries object
        tmpData   = tmpField.Data;
        tmpTime   = tmpField.Time;

        % Determine dimensions
        nDims     = ndims(tmpData);
        sizeDims  = size(tmpData);
        sizeTime  = size(tmpTime);

        % If time length matches last data dimension, extract last sample
        if sizeTime(1) == sizeDims(nDims)
            idxLast = sizeDims(nDims);
            subs    = repmat({':'}, 1, nDims);
            subs{nDims} = idxLast;
            tmpLast = tmpData(subs{:});
        else
            % Otherwise return full data array
            tmpLast = tmpData;
        end

        % Squeeze singleton dimensions
        strLast.(charFieldName) = squeeze(tmpLast);
    else
        error('ExtractLastTimeFromTimeseries:InvalidField', ...
            'Field "%s" must be a timeseries object or struct.', charFieldName);
    end
end
end



