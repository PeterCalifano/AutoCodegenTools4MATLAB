function ValidateInputBus(strInputToModel, objExpectedBusDefinition)
arguments
   strInputToModel          (1,1) {isstruct}
   objExpectedBusDefinition (1,1) {isa(objExpectedBusDefinition, 'Simulink.Bus')}
end
%% SIGNATURE
% ValidateInputBus(strInputToModel, objExpectedBusDefinition)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Function performing validation of input structures to SLX models against Bus objects definitions.
% The following checks are performed: 1) Fields name, 2) Fields type, 3) Fields ordering.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% strInputToModel          (1,1) {isstruct}
% objExpectedBusDefinition (1,1) {isa(objExpectedBusDefinition, 'Simulink.Bus')}
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% [-]
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 06-01-2025    Pietro Califano     First implementation.
% -------------------------------------------------------------------------------------------------------------

% Create temporary bus from struct
objInputBus = Simulink.Bus.createObject(strInputToModel);

% Get field names and dtypes
cellInputFields = {objInputBus.Elements.Name};
cellInputTypes  = {objInputBus.Elements.DataType};

cellExpectedFields = {objExpectedBusDefinition.Elements.Name};
cellExpectedTypes  = {objExpectedBusDefinition.Elements.DataType};

% Initialize arrays for mismatches
cellMismatchedFields        = {};
cellExpectedTypesMismatch   = {};
cellActualTypesMismatch     = {};
bOrderingMismatch           = false; % Flag for ordering issues

% Check for missing or extra fields
missingFields   = setdiff(cellExpectedFields, cellInputFields);
extraFields     = setdiff(cellInputFields, cellExpectedFields);

% Check data type consistency
for i = 1:length(cellExpectedFields)

    charExpectedField = cellExpectedFields{i};
    idx = find(strcmp(cellInputFields, charExpectedField), 1);

    if isempty(idx)
        % Missing field
        continue; % Already logged in `missingFields`

    elseif ~strcmp(cellInputTypes{idx}, cellExpectedTypes{i})
        % Type mismatch
        cellMismatchedFields{end+1}         = charExpectedField; %#ok<AGROW>
        cellExpectedTypesMismatch{end+1}    = cellExpectedTypes{i}; %#ok<AGROW>
        cellActualTypesMismatch{end+1}      = cellInputTypes{idx}; %#ok<AGROW>
    end
end

% Create a report of mismatches
if ~isempty(missingFields) || ~isempty(extraFields) || ~isempty(cellMismatchedFields) || bOrderingMismatch
    disp('Validation failed. See details below:');

    % Missing fields
    if ~isempty(missingFields)
        fprintf('\nMissing fields in input structure:\n');
        disp(missingFields');
    end

    % Extra fields
    if ~isempty(extraFields)
        fprintf('\nExtra fields in input structure:\n');
        disp(extraFields');
    end

    % Type mismatches
    if ~isempty(cellMismatchedFields)
        fprintf('\nType mismatches in fields:\n');
        mismatchTable = table(cellMismatchedFields', cellExpectedTypesMismatch', cellActualTypesMismatch', ...
            'VariableNames', {'Field', 'ExpectedType', 'ActualType'});
        disp(mismatchTable);
    end

    % Field ordering mismatch
    if bOrderingMismatch == true
        fprintf('\nField ordering mismatch detected:\n');
        fprintf('Expected order: %s\n', strjoin(cellExpectedFields, ', '));
        fprintf('Actual order: %s\n', strjoin(cellInputFields, ', '));
    end

    error('Input structure validation failed.');
else
    disp('Validation successful.');
end
end


