function GenerateBusDefinitionFile(strInput, charBusName, charOutputFolder, kwargs)
arguments
    strInput         {isstruct}
    charBusName      (1,1) string {mustBeA(charBusName, ["string", "char"])}
    charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])} = './bus_autodefs'
end
arguments
    kwargs.bStoreDefaultValues          {islogical, isscalar} = true
    kwargs.bDefineBusesInPlace          {islogical, isscalar} = false;
    kwargs.charHeaderDescription string {mustBeA(kwargs.charHeaderDescription, ["string", "char"])} = ""
end
%% DESCRIPTION
% Code generator function for bus definition files with default values definition and in-place evaluation.
% Given an input struct, it automatically generates a function defining the corresponding bus. Nested
% structures are handled by recursive calls. The top-level definition automatically calls the
% dependencies. The function provides bus definition object and default values if requested.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% arguments
%     strInput         {isstruct}
%     charBusName      (1,1) string {mustBeA(charBusName, ["string", "char"])}
%     charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])} = './bus_autodefs'
% end
% arguments
%     kwargs.bStoreDefaultValues          {islogical, isscalar} = true
%     kwargs.bDefineBusesInPlace          {islogical, isscalar} = false;
%     kwargs.charHeaderDescription string {mustBeA(kwargs.charHeaderDescription, ["string", "char"])} = ""
% end
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% [-]
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 13-05-2025    Pietro Califano & o4-mini-high      First prototype version.
% 14-05-2025    Pietro Califano                     Upgrade to support in-place definition of buses and
%                                                   examples, casting of default values, better header file. 
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

% Create output folder if needed
if ~isfolder(charOutputFolder)
    mkdir(charOutputFolder);
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
    varStruct        {isstruct}
    charBusName      (1,1) string {mustBeA(charBusName, ["string", "char"])}
    charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])}
    objDefinedFieldsMap
    kwargs
end
% arguments
%     kwargs.bStoreDefaultValues          {islogical, isscalar} = true
%     kwargs.bDefineBusesInPlace          {islogical, isscalar} = false;
%     kwargs.charHeaderDescription string {mustBeA(kwargs.charHeaderDescription, ["string", "char"])} = ""
% end

% Avoid regenerating the same bus
if objDefinedFieldsMap.isKey(charBusName)
    return
end

objDefinedFieldsMap(charBusName) = true;

% Alphabetically sorted fields
cellFieldNames = fieldnames(orderfields(varStruct));

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

    if isstruct(varVal) || isobject(varVal)

        charSubBus = sprintf('%s_%s', charBusName, charField);

        % Recurse to generate sub-bus
        strTmpKwargs = kwargs;
        strTmpKwargs.bIsRecursive = true;

        WriteBusFile(varVal, ...
            charSubBus, ...
            charOutputFolder, ...
            objDefinedFieldsMap, ...
            strTmpKwargs);

        % Write call to bus definition % TODO add an eval to move bus definition to workspace of "top
        % caller"
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
fprintf(i32Fid, '\n');
%%% Build the BusElement list
fprintf(i32Fid, '\n%% Define %s bus object\n', charBusName);
fprintf(i32Fid, 'elems = Simulink.BusElement.empty;\n\n');

for ui32Idx = 1:numel(cellFieldNames)
    charField = cellFieldNames{ui32Idx};
    varVal    = varStruct.(charField);

    fprintf(i32Fid, '%% Bus element %s definition\n', charField);
    fprintf(i32Fid, 'elem = Simulink.BusElement;\n');
    fprintf(i32Fid, 'elem.Name = ''%s'';\n', charField);

    if isstruct(varVal) || isobject(varVal)
        charSubBus = sprintf('%s_%s', charBusName, charField);
        fprintf(i32Fid, 'elem.DataType = ''Bus: bus_%s'';\n', charSubBus);
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

%%% Create the bus object
fprintf(i32Fid, 'Bus = Simulink.Bus;\n');
fprintf(i32Fid, 'Bus.Elements = elems;\n\n');

%%% Optional example struct
if kwargs.bStoreDefaultValues
    fprintf(i32Fid, '%% Default struct initialization\n');
    fprintf(i32Fid, 'strDefault = struct();\n');
    for ui32Idx = 1:numel(cellFieldNames)
        charField = cellFieldNames{ui32Idx};
        varVal    = varStruct.(charField);

        if isstruct(varVal) || isobject(varVal)
            charSubBus = sprintf('%s_%s', charBusName, charField);
            fprintf(i32Fid, 'strDefault.%s = default_%s;\n', charField, charSubBus);
        else
            charDatatype = class(varVal);
            charValStr = FormatValue(varVal);
            fprintf(i32Fid, 'strDefault.%s = cast(%s, ''%s'');\n', charField, charValStr, charDatatype);
        end
    end
    fprintf(i32Fid, '\n');
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
elseif islogical(varVal) || (~isempty(varVal) && isnumeric(varVal))
    charVal = mat2str(varVal);
else
    charVal = '[]';
end
end

% Bus loading function
