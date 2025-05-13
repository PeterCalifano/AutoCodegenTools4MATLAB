function [cellBuses] = GenerateBusDefinitionFile(charDefFilename, cellDataStructs)
arguments
    charDefFilename (:,1) string
    cellDataStructs (:,1) cell = {}
end

if isempty(cellDataStructs)
    disp('Input data is an empty cell. No file will be generated.')
    cellBuses = {};
    return;
end

% Open file to write 
% file = open(charDefFilename, 'w');

% Get number of buses to define
ui32NumOfBuses = size(cellDataStructs, 1);

for idInst = 1:ui32NumOfBuses

    % GenerateBusDefinition(cellDataStructs{idInst});
end

%% LOCAL function
    function [charBusDefinition] = GenerateBusDefinition(busInput)
        % arguments
        %     strBusInput (1,1) struct {isscalar}
        % end

        % TODO: check if any of the fields is a struct
        % If yes --> perform recursive calls

        if isa(busInput, 'struct')
            % Generate Simulink bus object from struct
            objSimulinkBus; 
            
        elseif isa(busInput, 'Simulink.Bus')
            objSimulinkBus = busInput;
        else
            error('Invalid input object: must be a struct or a Simulink.Bus!')
        end

        % Get fields of bus and data to write
        % Example: 
        % Bus with properties:
        %
        %                 Description: ''
        %                   DataScope: 'Auto'
        %                  HeaderFile: ''
        %                   Alignment: -1
        %   PreserveElementDimensions: 0
        %                    Elements: [0×0 Simulink.BusElement]

        cellFields = fieldnames(objSimulinkBus);
        % cellData;

        % Print definition to char array
        % TODO

    end

end

