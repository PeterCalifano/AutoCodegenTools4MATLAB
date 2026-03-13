function GenerateBusDefinitionFile(strInput, charBusName, charOutputFolder, kwargs)
arguments
    strInput         (1,:) struct
    charBusName      (1,1) string {mustBeA(charBusName, ["string", "char"])}
    charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])} = './bus_autodefs'
end
arguments
    kwargs.bCleanupBeforeGeneration     (1,1) logical = false
    kwargs.bStoreDefaultValues          (1,1) logical = true
    kwargs.bDefineBusesInPlace          (1,1) logical = false;
    kwargs.charHeaderDescription        string {mustBeA(kwargs.charHeaderDescription, ["string", "char"])} = ""
    kwargs.bStrictMode                  (1,1) logical = true;
end
%% DESCRIPTION
% Code generator function for bus definition files with default values definition and in-place evaluation.
% Given an input struct, it automatically generates a function defining the corresponding bus. Nested
% structures are handled by recursive calls. The top-level definition automatically calls the
% dependencies. The function provides bus definition object and default values if requested.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% arguments
%     strInput         (1,:) struct
%     charBusName      (1,1) string {mustBeA(charBusName, ["string", "char"])}
%     charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])} = './bus_autodefs'
% end
% arguments
%     kwargs.bStoreDefaultValues          (1,1) logical = true
%     kwargs.bDefineBusesInPlace          (1,1) logical = false;
%     kwargs.charHeaderDescription        string {mustBeA(kwargs.charHeaderDescription, ["string", "char"])} = ""
% end
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% [-]
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 13-05-2025    Pietro Califano & o4-mini-high      First prototype version.
% 14-05-2025    Pietro Califano                     Upgrade to support in-place definition of buses and
%                                                   examples, casting of default values, better header file. 
% 16-05-2025    Pietro Califano                     [MAJOR] Fix in-place definition and assignment of multi-nested
%                                                   buses (top must assign all buses to caller). Extend to fully 
%                                                   support struct arrays with defaults
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------


%% Function code

% Create output folder if needed
if ~isfolder(charOutputFolder)
    mkdir(charOutputFolder);
elseif kwargs.bCleanupBeforeGeneration
    try
        rmdir(charOutputFolder, "s");
        mkdir(charOutputFolder);
    catch ME
        warning('Cleanup of output folder failed with error: %s.', string(ME.message));
    end
end

% Track which buses have been generated using a map
objDefinedFieldsMap = containers.Map();

% Write definition for top-level bus (recursively defining nested structs)
kwargs.bIsRecursive = false;
WriteBusFile(strInput, charBusName, charOutputFolder, objDefinedFieldsMap, kwargs);

if kwargs.bDefineBusesInPlace
    % Ensure generated files are on path
    addpath(charOutputFolder);
    charCmd = sprintf('[~, ~] = BusDef_%s();', charBusName);

    % Call top-level generated file
    evalin("caller", charCmd);
end

end

%% Core function: bus definition code-generator
function WriteBusFile(varStruct, charBusName, charOutputFolder, objDefinedFieldsMap, kwargs)
arguments
    varStruct        struct
    charBusName      (1,1) string {mustBeA(charBusName, ["string", "char"])}
    charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])}
    objDefinedFieldsMap
    kwargs
end

% Avoid regenerating the same bus
if objDefinedFieldsMap.isKey(charBusName)
    return
end

objDefinedFieldsMap(charBusName) = true;

% Alphabetically sorted fields
cellFieldNames = fieldnames(orderfields(varStruct));

% Detect struct array and prevent fields elimination if any is not empty
bIsStructArray = numel(varStruct) > 1;

% Open definition file
charFcnPrefix = "BusDef";
charFilePath = fullfile(charOutputFolder, strcat(charFcnPrefix, '_', charBusName, '.m'));
i32Fid = fopen(charFilePath, 'w');
if i32Fid == -1
    error("Cannot open '%s' for writing.", charFilePath)
end

% Write function signature
fprintf(i32Fid, 'function [Bus');
if kwargs.bStoreDefaultValues
    fprintf(i32Fid, ', strDefault');
end
fprintf(i32Fid, '] = %s_%s()\n', charFcnPrefix, charBusName);

%%% Write file header
% --- Generation metadata ---
charDate   = datetime("now", "Format", 'yyyy-MM-dd hh:mm:ss');
[~, charHostname] = system("hostname");
charAuthor = strcat(getenv('USERNAME'), "@", charHostname);
charSystem = computer();
[charMatVer] = version; % MATLAB release string
[bOutStatus, charGitCommitHashOut] = system('git rev-parse --short HEAD'); % Git commit
if bOutStatus == 0
    charCommit = strtrim(charGitCommitHashOut);
else
    charCommit = 'N/A';
end

% Parse additional description if provided
charDescription = 'Not provided';
bValidFile = false;
if not(strcmpi(kwargs.charHeaderDescription, ""))
    [~, ~, charExt] = fileparts(kwargs.charHeaderDescription); % Check if file

    % Remove dot from extention
    charExt = strrep(charExt, '.', '');

    if strcmpi(charExt, 'txt') && isfile(kwargs.charHeaderDescription)
        bValidFile = true;
    end

    if bValidFile
        % Fetch description from file
        charDescription = fileread(kwargs.charHeaderDescription);

    elseif not(bValidFile)
        % Parse directly as string
        charDescription = sprintf(" %s", kwargs.charHeaderDescription);
    else
        warning('Invalid description input. Must be a .txt file or a string. Custom description will not be included in the definition header.')
    end

end

% Build header string
charHeaderDef = sprintf([ ...
    '%%%%%% -------- Auto-generated Simulink.Bus definition for %s --------\n' ...
    '%% Date: %s\n'                         ...
    '%% MATLAB Version: %s\n'               ...
    '%% Commit reference: %s\n'              ...
    '%% Description: %s\n'                  ...
    '%% Author: %s\n'                       ...
    '%% System: %s\n' ...
    '%% --------------------------------------------------------------------\n\n'],                 ...
    charBusName, charDate, charMatVer, charCommit, charDescription, charAuthor, charSystem);

fprintf(i32Fid, '%s', charHeaderDef);

% ------------------------------------

% TODO: add error if field is a cell or something else (not supported)

%%% Define nested buses (struct) by recursion
for ui32Idx = 1:numel(cellFieldNames)

    charField = cellFieldNames{ui32Idx};
    varVal    = varStruct.(charField);

    if numel(varStruct) > 1
        [~, ~, varVal] = DetectNonEmptyInStructArray(varStruct, charField, varVal, kwargs);
    end

    if isstruct(varVal) || isobject(varVal)

        charSubBus = sprintf('%s_%s', charBusName, charField);

        % Recurse to generate sub-bus
        strTmpKwargs = kwargs;
        strTmpKwargs.bIsRecursive = true;

        % Add skip for struct arrays
        if numel(varStruct) > 1
            strTmpKwargs.strParentStruct = varStruct;
            bIsStructArray = true;
        end

        WriteBusFile(varVal, ...
                    charSubBus, ...
                    charOutputFolder, ...
                    objDefinedFieldsMap, ...
                    strTmpKwargs);

        % Write call to bus definition 
        if not(isfield(kwargs, "bStoreDefaultValues"))
            kwargs.bStoreDefaultValues = true;
        end

        if kwargs.bStoreDefaultValues
            fprintf(i32Fid, '[Bus_%s, default_%s] = %s_%s();\n\n', ...
                charSubBus, charSubBus, charFcnPrefix, charSubBus);
            fprintf(i32Fid, 'assignin("caller", "bus_%s", Bus_%s);\n', charSubBus, charSubBus);
            fprintf(i32Fid, 'assignin("caller", "%s", default_%s);\n', charSubBus, charSubBus);
        else
            fprintf(i32Fid, '%s = BusDef_%s();\n', charSubBus, charSubBus);
            fprintf(i32Fid, 'assignin("caller", "bus_%s", Bus_%s);', charSubBus, charSubBus);
        end

    end
end

% Write line to assign all children bus_<object> (dependency) to the caller workspace
fprintf(i32Fid, "\nstrBusVars = whos('bus_*');\nfor id = 1:numel(strBusVars)\n\tassignin('caller', strBusVars(id).name, eval(strBusVars(id).name));\nend\n");
if kwargs.bStoreDefaultValues
    % Write default structs as well
    fprintf(i32Fid, "\nstrDefaultsVars = whos('str*');\nfor id = 1:numel(strDefaultsVars)\n\tassignin('caller', strDefaultsVars(id).name, eval(strDefaultsVars(id).name));\nend\n");
end

fprintf(i32Fid, '\n');
%%% Build the BusElement list
fprintf(i32Fid, '\n%% Define %s bus object\n', charBusName);
fprintf(i32Fid, 'elems = Simulink.BusElement.empty;\n\n');

for ui32Idx = 1:numel(cellFieldNames)

    charField = cellFieldNames{ui32Idx};
    varVal    = varStruct.(charField);

    if bIsStructArray
        % Detect if any struct of the array has a value for the field
        [~, ~, varVal] = DetectNonEmptyInStructArray(varStruct, charField, varVal, kwargs);
    end

    if not(isempty(varVal))
        fprintf(i32Fid, '%% Bus element %s definition\n', charField);
        fprintf(i32Fid, 'elem = Simulink.BusElement;\n');
        fprintf(i32Fid, 'elem.Name = ''%s'';\n', charField);

        if (isstruct(varVal) || isobject(varVal))
            charSubBus = sprintf('%s_%s', charBusName, charField);
            fprintf(i32Fid, 'elem.DataType = ''Bus: bus_%s'';\n', charSubBus);
            fprintf(i32Fid, 'elem.Dimensions = %s;\n', num2str(numel(varVal)));

        else
            dDims = size(varVal);
            if ischar(varVal)
                dDims = [1, numel(varVal)];
            end

            charDatatype = class(varVal);
            if strcmpi(charDatatype, "logical")
                charDatatype = "boolean"; % Handle different typename logical <-> boolean
            end

            fprintf(i32Fid, 'elem.DataType = ''%s'';\n', charDatatype);
            fprintf(i32Fid, 'elem.Dimensions = %s;\n', mat2str(dDims));
        end
    else
        fprintf(i32Fid, '%% Empty bus element detected: %s definition skipped.\n\n', charField);
    end

    if not(isempty(varVal))
        fprintf(i32Fid, 'elems(end+1) = elem;\n\n');
    end
end

%%% Create the bus object
fprintf(i32Fid, 'Bus = Simulink.Bus;\n');
fprintf(i32Fid, 'Bus.Elements = elems;\n\n');

%%% Optional example struct
if kwargs.bStoreDefaultValues

    fprintf(i32Fid, '%% Default struct initialization\n');
    fprintf(i32Fid, 'try\n');
    fprintf(i32Fid, '\tstrDefault = struct();\n');

    for ui32Idx = 1:numel(cellFieldNames)
        
        charField = cellFieldNames{ui32Idx};
    
        % Check if parent is an array
        if isfield(kwargs, "strParentStruct") || numel(varStruct) > 1
            if isfield(kwargs, "strParentStruct")
                ui32ArraySize = length(kwargs.strParentStruct);
            else
                ui32ArraySize = numel(varStruct);
            end
        else
            ui32ArraySize = 1;
            varVal    = varStruct.(charField);
        end

        for idArray = 1:ui32ArraySize
            % Get value from the corresponding struct
            if ui32ArraySize > 1

                if isfield(kwargs, "strParentStruct")
                    charCurrentStructFieldName = split(charBusName, '_');
                    charCurrentStructFieldName = charCurrentStructFieldName(end);
                    varVal    = kwargs.strParentStruct(idArray).(charCurrentStructFieldName).(charField);
                else
                    varVal = varStruct(idArray).(charField);
                end
            end
        
            if not(isempty(varVal))

                if isstruct(varVal) || isobject(varVal)
                    charSubBus = sprintf('%s_%s', charBusName, charField);

                    if isscalar(varVal)
                        fprintf(i32Fid, '\tstrDefault(%d).%s = default_%s;\n', idArray, charField, charSubBus);

                    elseif numel(varVal) > 1
                        % Handle struct arrays defaults
                        for idVal = 1:numel(varVal)
                            fprintf(i32Fid, '\tstrDefault(%d).%s(%d) = default_%s;\n', idArray, charField, idVal, sprintf('%s(%d)', charSubBus, idVal) );
                        end

                    else
                        error('Invalid number of objects.')
                    end

                else
                    charDatatype = class(varVal);
                    charValStr = FormatValue(varVal);
                    fprintf(i32Fid, '\tstrDefault(%d).%s = cast(%s, ''%s'');\n', idArray, charField, charValStr, charDatatype);
                end
            else
                fprintf(i32Fid, '\tstrDefault(%d).%s = [];\n', idArray, charField);
            end
        end
    end

    % Order fields
    fprintf(i32Fid, '\tstrDefault = orderfields(strDefault);\n');

    % Catch
    fprintf(i32Fid, 'catch ME\n');
    fprintf(i32Fid, '\twarning("Automatic default assignment failed due to error: %s", ME.message);\n', "%s");
    fprintf(i32Fid, '\n');
    fprintf(i32Fid, 'end\n');

end

% Generate assignin call to evaluate to caller
if not(kwargs.bIsRecursive)
    fprintf(i32Fid, sprintf('assignin("caller", "bus_%s", Bus);\n', charBusName) );
    if kwargs.bStoreDefaultValues
        fprintf(i32Fid, sprintf('assignin("caller", "%s", strDefault);\n', charBusName) );
    end
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

    elseif islogical(varVal)
        charVal = mat2str(varVal);

    elseif isnumeric(varVal)
        dDims = ndims(varVal);

        if dDims <= 2
            charVal = mat2str(varVal);
        else
            % Handle 3D (or higher) numeric arrays
            ui32Dims    = size(varVal);
            varLinVec   = varVal(:)';
            charVal     = sprintf('reshape(%s, %s)', mat2str(varLinVec), mat2str(ui32Dims));
        end
    else
        charVal = '[]';
    end
end

% Non empty value detection in struct arrays
function [bIsStructArray, bIsFieldEmpty, varVal] = DetectNonEmptyInStructArray(varStruct, charField, varVal, kwargs)
arguments
    varStruct
    charField (1,:) char {mustBeText}
    varVal 
    kwargs    (1,1) struct
end
bIsStructArray = true;
bIsFieldEmpty = false(1, numel(varStruct));

dSizeToEnforce = [];
dTypeToEnforce = [];

for idS = 1:numel(varStruct)
    varFieldValue = varStruct(idS).(charField);
    bIsFieldEmpty(idS) = isempty(varFieldValue);

    if not(isempty(dSizeToEnforce))
        % Enforce type and size uniqueness
        assert( all(dSizeToEnforce == size(varFieldValue)) || (isempty(varFieldValue) && not(kwargs.bStrictMode) ), ...
            'ERROR: detected heterogeneous field value in struct array field. Not allowed for C/C++ code generation.');
    elseif not(bIsFieldEmpty(idS))
        % Else get first non empty
        dSizeToEnforce = size(varVal);
    end

    if not(isempty(dTypeToEnforce))
        % Enforce type uniqueness
        assert( strcmpi(dTypeToEnforce, class(varFieldValue)) || (isempty(varFieldValue) && not(kwargs.bStrictMode)), ...
            'ERROR: detected heterogeneous data type in struct array field. Not allowed for C/C++ code generation.');
    elseif not(bIsFieldEmpty(idS))
        % Else get first non empty
        dTypeToEnforce = class(varVal);
    end

    % Get representative value if not empty
    if not(bIsFieldEmpty(idS))
        varVal = varFieldValue;
    end
end

end
% Bus loading function
