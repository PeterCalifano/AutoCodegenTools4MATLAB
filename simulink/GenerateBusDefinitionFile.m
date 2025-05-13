function GenerateBusDefinitionFile(strInput, charBusName, charOutputFolder, kwargs)
arguments
    strInput
    charBusName
    charOutputFolder
end
arguments
    kwargs.bStoreExampleValues {islogical, isscalar} = false
end
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% in1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 13-05-2025    Pietro Califano & o4-mini-high      First prototype version.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

% Create output folder if needed
if ~exist(charOutputFolder, 'dir')
    mkdir(charOutputFolder);
end

% Track which buses have been generated
mapVisited = containers.Map();
WriteBusFile(strInput, charBusName, charOutputFolder, mapVisited, kwargs);
end

%%% Core function: bus definition code-generator
function WriteBusFile(varStruct, charBusName, charOutputFolder, objDefinedFieldsMap, kwargs)
% Avoid regenerating the same bus
if objDefinedFieldsMap.isKey(charBusName)
    return
end

objDefinedFieldsMap(charBusName) = true;

% Alphabetically sorted fields
cellFieldNames = fieldnames(orderfields(varStruct));

% Open definition file
charFilePath = fullfile(charOutputFolder, strcat('Define_', charBusName, '.m'));
i32Fid = fopen(charFilePath, 'w');
if i32Fid == -1
    error("Cannot open '%s' for writing.", charFilePath)
end

% Write function signature
fprintf(i32Fid, 'function [Bus');
if kwargs.bStoreExampleValues
    fprintf(i32Fid, ', Example');
end
fprintf(i32Fid, '] = Define_%s()\n', charBusName);
% Write file header
fprintf(i32Fid, '%% Auto-generated Simulink.Bus definition for %s\n\n', charBusName); 
% TODO add details such as data, author and system

% TODO: add error if field is a cell or something else (not supported)

%%% Define nested buses (struct) by recursion
for ui32Idx = 1:numel(cellFieldNames)

    charField = cellFieldNames{ui32Idx};
    varVal    = varStruct.(charField);

    if isstruct(varVal) || isobject(varVal)

        charSubBus = sprintf('%s_%s', charBusName, charField);

        % Recurse to generate sub-bus
        WriteBusFile(varVal, charSubBus, charOutputFolder, objDefinedFieldsMap, kwargs);
        
        % Write call to bus definition % TODO add an eval to move bus definition to workspace of "top
        % caller"
        if kwargs.bStoreExampleValues
            fprintf(i32Fid, '[Bus_%s, Example_%s] = Define_%s();\n', ...
                charSubBus, charSubBus, charSubBus);
            fprintf(i32Fid, 'evalin("base", "Bus_%s");\n', charSubBus);
            fprintf(i32Fid, 'evalin("base", "Example_%s");\n', charSubBus);
        else
            fprintf(i32Fid, 'Bus_%s = Define_%s();\n', charSubBus, charSubBus);
            fprintf(i32Fid, 'evalin("base", "Bus_%s");', charSubBus);
        end

    end

end
fprintf(i32Fid, '\n');

%% Build the BusElement list
fprintf(i32Fid, 'elems = Simulink.BusElement.empty;\n\n');
for ui32Idx = 1:numel(cellFieldNames)
    charField = cellFieldNames{ui32Idx};
    varVal    = varStruct.(charField);

    fprintf(i32Fid, 'elem = Simulink.BusElement;\n');
    fprintf(i32Fid, 'elem.Name = ''%s'';\n', charField);

    if isstruct(varVal) || isobject(varVal)
        charSubBus = sprintf('%s_%s', charBusName, charField);
        fprintf(i32Fid, 'elem.DataType = ''Bus: %s'';\n', charSubBus);
        fprintf(i32Fid, 'elem.Dimensions = 1;\n');
    else
        dDims = size(varVal);
        if ischar(varVal)
            dDims = [1, numel(varVal)];
        end
        fprintf(i32Fid, 'elem.DataType = ''%s'';\n', class(varVal));
        fprintf(i32Fid, 'elem.Dimensions = %s;\n', mat2str(dDims));
    end

    fprintf(i32Fid, 'elems(end+1) = elem;\n\n');
end

%% Create the bus object
fprintf(i32Fid, 'Bus = Simulink.Bus;\n');
fprintf(i32Fid, 'Bus.Elements = elems;\n\n');

%% Optional example struct
if kwargs.bStoreExampleValues
    fprintf(i32Fid, '%% Example struct initialization\n');
    fprintf(i32Fid, 'Example = struct();\n');
    for ui32Idx = 1:numel(cellFieldNames)
        charField = cellFieldNames{ui32Idx};
        varVal    = varStruct.(charField);

        if isstruct(varVal) || isobject(varVal)
            charSubBus = sprintf('%s_%s', charBusName, charField);
            fprintf(i32Fid, 'Example.%s = Example_%s;\n', charField, charSubBus);
        else
            charValStr = FormatValue(varVal);
            fprintf(i32Fid, 'Example.%s = %s;\n', charField, charValStr);
        end
    end
    fprintf(i32Fid, '\n');
end

fprintf(i32Fid, 'end\n');
fclose(i32Fid);

fprintf('Generated: %s\n', charFilePath);


end

%% Auxiliary functions
% Value formatting function
function charVal = FormatValue(varVal)
if ischar(varVal)
    charVal = ['''' varVal ''''];
elseif islogical(varVal) || (~isempty(varVal) && isnumeric(varVal))
    charVal = mat2str(varVal);
else
    charVal = '[]';
end
end

% Bus loading function
