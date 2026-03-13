classdef CAutoGenICD < handle
    %% DESCRIPTION
    % CAutoGenICD class automatically generates ICDs for Simulink subsystems. Loads a model, runs an init 
    % script, compiles the model, extracts I/O data for specified subsystems, and generates. 
    % Excel ICD files with standardized naming conventions.
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 15-05-2025    Pietro Califano & o4-mini-high    First prototype implementation.
    % 04-10-2025    Pietro Califano & GPT-5           [MAJOR] Add methods to define table of variables from 
    %                                                 bus definitions, apply a fixed template and export to 
    %                                                 tabular format file
    % -------------------------------------------------------------------------------------------------------------
    %% METHODS
    % See methods()
    % -------------------------------------------------------------------------------------------------------------
    %% PROPERTIES
    % See properties()
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % Simulink Report toolbox.
    % -------------------------------------------------------------------------------------------------------------
    %% TODO
    % [-]
    % -------------------------------------------------------------------------------------------------------------

    properties (SetAccess = protected, GetAccess = public)
        charModelName       % SLX model file or model name (char)
        cellSubsystemPaths  % Cell array of subsystem paths (cell)
        charInitScript      % Initialization script path (char)
        strICDData          % Struct of extracted ICD tables (struct)
    end

    methods (Access = public)
        % CONSTRUCTOR
        function self = CAutoGenICD(charModelPath, cellSubsystemPaths, charInitScript)
            arguments
                charModelPath      (1,1) string {mustBeA(charModelPath, ["string", "char"])}
                cellSubsystemPaths {mustBeA(cellSubsystemPaths, ["cell", "string", "char"])}
                charInitScript     (1,1) string {mustBeA(charInitScript, ["string", "char"])}
            end

            % Handle string case (convert to cell)
            if not(iscell(cellSubsystemPaths)) 
                if isscalar(string(cellSubsystemPaths))
                    cellSubsystemPaths = {cellSubsystemPaths};
                else
                    error('Please provide a cell variable to specify multiple target subsystems.')
                end
            end

            % Assert validity of target subsystem
            for idTarget = 1:length(cellSubsystemPaths)
                if strcmpi(cellSubsystemPaths{idTarget}, "")
                    error('Invalid target subsystem "%s": cannot be empty path.', cellSubsystemPaths{idTarget})
                end
            end
            
            % Assert model and init script exist
            [charDirPath, charModelPath_noExt] = fileparts(charModelPath); % Strip extension
            if isfile(fullfile(charDirPath, charModelPath_noExt))
                error('Model file %s not found!', charModelPath);
            end

            [charDirPath, charInitScript_noExt] = fileparts(charInitScript); % Strip extension
            if isfile(fullfile(charDirPath, charInitScript_noExt))
                error('Initialization script %s not found!', charInitScript);
            end

            if isempty(cellSubsystemPaths)
                warning('No subsystem specified. You should specify at least one subsystem to generate an interface control document.')
            end

            % Store model, subsystems, and init script
            self.charModelName      = charModelPath;
            self.cellSubsystemPaths = cellSubsystemPaths;
            self.charInitScript     = charInitScript;

            % Initialize ICDData
            self.strICDData = struct();
        end

        % PUBLIC METHODS
        function [strModelData] = getICDDataFromModel(self)
            % Compile model and extract ICD data for each subsystem
            self.compileModel_();
            strModelData = struct();

            for dIdx = 1:numel(self.cellSubsystemPaths)

                % Get path to subsystem
                charSubsysPath = self.cellSubsystemPaths{dIdx};
                % Get valid name of subsystem to name field
                charKey = matlab.lang.makeValidName(strrep(charSubsysPath, '/', '_'));

                % Get data from SLX model
                if contains(struct2array(ver), 'Simulink Report Generator')
                    strModelData.(charKey) = self.extractSubsysData_(charSubsysPath);
                else
                    strModelData.(charKey) = self.extractSubsysDataManual_(charSubsysPath);
                end
            end

            % Assign data for each subsystem
            self.strICDData = strModelData;
            
        end

        function tableOut = exportICD(self, charOutputFolder, kwargs)
            arguments
                self
                charOutputFolder (1,1) string {mustBeA(charOutputFolder, ["string", "char"])} = "./autogenerated_ICD"
            end
            arguments
                kwargs.enumOutFormat (1,1) string {mustBeMember(kwargs.enumOutFormat, ["xlsx", "csv", "dat", "xml"])} = "csv"
            end
            % Method to build and export ICD file for each subsystem in strICDData

            if isempty(fieldnames(self.strICDData))
                self.getICDDataFromModel();
            end

            if ~exist(charOutputFolder, 'dir')
                mkdir(charOutputFolder);
            end

            % Determine format type
            if strcmpi(kwargs.enumOutFormat, "xlsx")
                charFormatType = "spreadsheet";
            elseif strcmpi(kwargs.enumOutFormat, "xml")
                charFormatType = "xml";
            else
                charFormatType = "text";
            end

            % Get keys of ICD datastruct
            cellKeys = fieldnames(self.strICDData);
    
            % For each datastruct, write a document
            for dIdx = 1:numel(cellKeys)
    
                % Collect formatted data
                charKey = cellKeys{dIdx};
                tableICD = self.strICDData.(charKey);

                if nargout > 0
                    tableOut(idX) = tableICD;
                end

                % Write table
                charFilename = fullfile( charOutputFolder, strcat(charKey, '_ICD.', kwargs.enumOutFormat) );
                writetable(tableICD, charFilename, ...
                        "FileType", charFormatType, ...
                        'Sheet', 1, ...
                        'WriteVariableNames', true, ...
                        "WriteRowNames",true, ...
                        "AutoFitWidth", true, ...
                        'PreserveFormat',true);

                fprintf('Generated ICD for "%s" system to file "%s"\n', charKey, charFilename);
            end

        end
    end

    % PROTECTED METHODS
    methods (Access = protected)

        function compileModel_(self)
            % compileModel Load init data into model workspace and compile model
            arguments
                self;
            end

            % Import initialization data
            % TODO this is required to evaluate the initialization script to the base workspace. Apparently
            % SLX is limited in that bus defs must be in the base workspace or passed as data dictionaries.
            % if ~isempty(self.charInitScript)
            %
            %     [~,~,charExt] = fileparts(self.charInitScript);
            %     objModelWS = get_param(self.charModelName, 'ModelWorkspace');
            %
            %     switch lower(charExt)
            %
            %         case '.m'
            %             % Run script in base workspace
            %             evalin('caller', sprintf('run(''%s'');', self.charInitScript));
            %             % Save base variables to temporary MAT
            %             tmpMat = fullfile(tempdir, strcat(matlab.lang.makeValidName(self.charModelName), '_init.mat') );
            %             evalin('caller', sprintf('save(''%s'');', tmpMat));
            %             objModelWS.evalin("base", sprintf('load(''%s'');', tmpMat));
            %
            %         case '.mat'
            %             % Load MAT directly into model workspace
            %             objModelWS.evalin("base", sprintf('load(''%s'');', self.charInitScript));
            %         otherwise
            %             error('Initialization file must be a .m script or .mat file');
            %     end
            % end

            % Load model and compile (populates compiled port data)
            self.loadAllModels_(self, self.charModelName);

        end

        function loadAllModels_(self, charTopModelName)
            arguments
                self                    % your class instance
                charTopModelName char    % name of the .slx (without “.slx”)
            end

            % Load the top-level model
            load_system(charTopModelName);

            % Find _and_ load every referenced model in the hierarchy
            [ cellModelschar, cellModelBlkschar ] = ...
                find_mdlrefs(charTopModelName, KeepModelsLoaded=true);

            % Load all referenced models
            for idx = 1:numel(cellModelschar)
                load_system(cellModelschar{idx});
            end
        end

        function tableICD = extractSubsysData_(self, charSubsysPath)
            arguments (Input)
                self
                charSubsysPath (1,:) char
            end
            arguments (Output)
                tableICD table
            end

            import mlreportgen.report.*    % Exposes Chapter, Section, etc.
            import slreportgen.report.*    % Exposes Report, SystemIO, etc.

            % Use SystemIO reporter for summary
            objModelDefsIO = SystemIO(charSubsysPath);

            % Compile this subsystem
            % set_param(bdroot(charSubsysPath), 'SimulationCommand', 'update');

            charDocType = 'pdf';
            objReport = slreportgen.report.Report("./testAutoICD.pdf", charDocType);
            open(objReport);

            % Add a chapter (optional, for structure)
            objICDchapter  = Chapter("Interface Control Document");
            add(objReport, objICDchapter);

            % Add system I/O definitions
            objModelDefsIO = slreportgen.report.SystemIO(charSubsysPath);
            add(objReport, objModelDefsIO);

            close(objReport);
            rptview(objReport);   % Open in Word or specified viewer

            % Fetch input/output summary tables
            tableIn  = objModelDefsIO.getInputSummaryTable();
            tableOut = objModelDefsIO.getOutputSummaryTable();

            % Combine and ensure Description column
            tableICD = [tableIn; tableOut];

            % Add empty description if not present
            if ~ismember('Description', tableICD.Properties.VariableNames)
                tableICD.Description = repmat({''}, height(tableICD), 1);
            end

            % Select and rename columns
            tableICD = tableICD(:, {'Name', 'Dimensions', 'DataType', 'Description'});
            tableICD.Properties.VariableNames = {'Signal Name', 'Dimension', 'Data Type', 'Description'};

            % Prepare additional columns
            dNum = height(tableICD);
            cellTelemetry       = false(dNum, 1);
            cellInitialization  = false(dNum, 1);
            cellNotes           = repmat({''}, dNum, 1);

            % Retrieve port handles
            handlesIn  = objModelDefsIO.InputPortHandles;
            handlesOut = objModelDefsIO.OutputPortHandles;
            handlesAll = [handlesIn; handlesOut];

            % Loop each signal
            for i = 1:dNum

                tmpHandle = handlesAll(i);

                % Telemetry flag
                cellTelemetry(i) = strcmp(get_param(tmpHandle, 'DataLogging'), 'on');

                % Initialization for outports
                if ismember(tmpHandle, handlesOut)
                    blkHandle = get_param(tmpHandle, 'DstBlockHandle');
                    valInit = get_param(blkHandle, 'InitialOutput');
                    cellInitialization(i) = ~(isempty(valInit) || strcmp(valInit, '0'));
                else
                    cellInitialization(i) = true;
                end

                % Notes from block
                try
                    blkPath = getfullname(get_param(tmpHandle, 'DstBlockHandle'));
                    cellNotes{i} = get_param(blkPath, 'Notes');
                catch
                    cellNotes{i} = '';
                end
            end

            % Append to table
            tableICD.Telemetry      = cellTelemetry;
            tableICD.Initialization = cellInitialization;
            tableICD.Notes          = cellNotes;
        end

        % Manual method if Simulink Report Generator is not available
        function tableICD = extractSubsysDataManual_(self, charSubsysPath)
            % Extract I/O data for one subsystem:
            % [Signal Name, Dimension, Data Type, Telemetry,
            %  Initialization, Description, Notes]

            % Compile model data for this subsystem
            charBDRoot = bdroot(charSubsysPath);
            self.compileModel_();
            % charSubsysPath(charSubsysPath,[],[],'compile');
            evalin("caller", sprintf('%s([],[],[],''compile'');', self.charModelName));

            % Find inport/outport blocks
            cellInPorts  = find_system(charSubsysPath, 'SearchDepth', 1, 'BlockType', 'Inport');
            cellOutPorts = find_system(charSubsysPath, 'SearchDepth', 1, 'BlockType', 'Outport');
            cellAllPorts = [cellInPorts; cellOutPorts];
            dNumPorts    = numel(cellAllPorts);

            % objTmpLineHandles = find_system( ...
            %     charSubsysPath, ...
            %     'FindAll',    'on', ...
            %     'type',       'line');

            % Preallocate rows
            cellRows = cell(dNumPorts, 7);
            objModelWorkspace = get_param(charBDRoot, 'ModelWorkspace');
            dRow = 0;

            % Loop over ports
            for idx = 1:dNumPorts

                blkPath = cellAllPorts{idx};
                ph = get_param(blkPath, 'PortHandles');
                blkType = get_param(blkPath, 'BlockType');
                % Select port handle and init parameter
                switch blkType
                    case 'Inport'
                        portH = ph.Outport;
                        initParam = 'InitialValue';
                    case 'Outport'
                        portH = ph.Inport;
                        initParam = 'InitialOutput';
                    otherwise
                        continue;
                end
                % Signal name
                lineH = get_param(portH, 'Line');
                sigName = get_param(lineH, 'Name');
                if isempty(sigName), sigName = '<unnamed>'; end
                rows{idx,1} = sigName;
                % Dimension
                dims = get_param(portH, 'CompiledPortDimensions');
                rows{idx,2} = mat2str(dims);
                % Data Type
                rows{idx,3} = get_param(portH, 'CompiledPortDataType');
                % Telemetry flag
                rows{idx,4} = strcmp(get_param(portH, 'DataLogging'), 'on');
                % Initialization flag
                % initVal = get_param(blkPath, initParam);
                % rows{idx,5} = ~(isempty(initVal) || strcmp(initVal, '0'));
                % Description
                try
                    desc = get_param(blkPath, 'Description');
                catch
                    desc = '';
                end
                rows{idx,6} = desc;
                % Notes
                try
                    note = get_param(blkPath, 'Notes');
                catch
                    note = '';
                end
                rows{idx,7} = note;
            end

            % Build table and set column names
            % DEVNOTE: this define the template for the output file. You should change it if another
            % template is required.
            tableICD = cell2table(cellRows, ...
                'VariableNames', {'SignalName','Dimension','DataType', ...
                'Telemetry','Initialization','Description','Notes'});

            % Rename for Excel headers
            tableICD.Properties.VariableNames = { ...
                'Signal Name','Dimension','Data Type', ...
                'Telemetry','Initialization','Description','Notes'};
        end

    end

    % STATIC METHODS
    methods (Static, Access = public)
        function tableICD = BuildTableFromBus(varBusSource, kwargs)
            arguments (Input)
                varBusSource             {mustBeNonempty, CAutoGenICD.validateInputBusSource_(varBusSource)}
                kwargs.bIncludeDefaults   (1,1) logical  = true
                kwargs.charRootLabel      (1,1) string {mustBeText} = "none"
                kwargs.objBusRegistry                    = []
            end
            arguments (Output)
                tableICD (:,:) table
            end

            % Inputs -> local, prefix-consistent
            bIncludeDefaults   = kwargs.bIncludeDefaults;
            charRootLabel      = string(kwargs.charRootLabel);

            % Shared bus registry
            objBusRegistry = containers.Map('KeyType','char','ValueType','any');

            % Populate registry if one is provided
            if isa(kwargs.objBusRegistry, 'containers.Map')
                CAutoGenICD.PopulateBusRegistry_(objBusRegistry, kwargs.objBusRegistry);

            elseif isstruct(kwargs.objBusRegistry) && ~isempty(fieldnames(kwargs.objBusRegistry))
                CAutoGenICD.PopulateBusRegistry_(objBusRegistry, kwargs.objBusRegistry);

            elseif ~isempty(kwargs.objBusRegistry)
                error('CAutoGenICD:buildICDTableFromBus:InvalidRegistry', ...
                    'kwargs.objBusRegistry must be a containers.Map or struct of Simulink.Bus objects.');
            end

            % Defaults carrier
            strDefaultStruct = struct();

            % Define label name of root bus
            if strcmpi(kwargs.charRootLabel, "none")
                charRootLabel = "none";

            elseif strlength(charRootLabel) == 0
                charTmpName = inputname(1); % Try to get name from the input variable
                if isempty(charTmpName)
                    charRootLabel = "RootBus";
                else
                    charRootLabel = string(charTmpName);
                end
            end

            % Resolve source
            if isa(varBusSource, 'Simulink.Bus')
                objBus = varBusSource;

            elseif ischar(varBusSource) || isstring(varBusSource)

                % Load bus definition from file
                [objBus, strDefaultStruct, charInferredRoot, objRegistryFromFile] = ...
                    CAutoGenICD.LoadBusDefinitionFile_(char(varBusSource), bIncludeDefaults);

                % Build registry
                CAutoGenICD.PopulateBusRegistry_(objBusRegistry, objRegistryFromFile);

                % Assign name if needed
                if (not(strcmpi(charRootLabel, "none")) || not(strcmpi(charRootLabel, "RootBus"))) ...
                        && strcmpi(kwargs.charRootLabel, "none")
                    charRootLabel = string(charInferredRoot);
                end
            else
                error('CAutoGenICD:buildICDTableFromBus:UnsupportedSource', ...
                    'busSource must be a Simulink.Bus object or a path to a bus definition file.');
            end

            % Define rows template
            strEmptyRow = struct( ...
                'Hierarchy',      "", ...
                'SignalName',     "", ...
                'DataType',       "", ...
                'Dimensions',     "", ...
                'DimensionsMode', "", ...
                'Unit',           "[N/D]", ...
                'Complexity',     "", ...
                'SamplingMode',   "", ...
                'SampleTime',     "", ...
                'Min',            "", ...
                'Max',            "", ...
                'Description',    "", ...
                'DefaultValue',   "", ...
                'IsBus',          false, ...
                'ReferencedBus',  "" ...
                );

            % Traverse hierarchy to fill rows
            strRows = CAutoGenICD.TraverseBus_(objBus, ...
                                            charRootLabel, ...
                                            strDefaultStruct, ...
                                            "", ...
                                            string.empty, ...
                                            bIncludeDefaults, ...
                                            objBusRegistry, ...
                                            strEmptyRow);

            % Build output table
            if isempty(strRows)
                % Handle empty case
                cellVarNames = fieldnames(strEmptyRow);
                cellVarTypes = repmat("string", 1, numel(cellVarNames));
                cellVarTypes(strcmp(cellVarNames, 'IsBus')) = "logical";

                tableICD = table('Size', [0 numel(cellVarNames)], ...
                                'VariableTypes', cellVarTypes, ...
                                'VariableNames', cellVarNames);

            else
                % Check if all fields of hierarchy and SignalName are identical. If true, prune hierarchy
                bAllHierarchySignalsEqual = true;
                for idS = 1:numel(strRows)
                    if not(strcmpi(strRows(idS).Hierarchy, strRows(idS).SignalName))
                        bAllHierarchySignalsEqual = false;
                    end
                end

                if bAllHierarchySignalsEqual
                    strRows = rmfield(strRows, 'Hierarchy');
                end

                % Convert struct to table and sort alphabetically
                tableICD = struct2table(strRows, "AsArray", true);
                tableICD = sortrows(tableICD, 'SignalName');

            end
        end

        function cellTablesICD = ApplyTableTemplate(varTablesICD, enumColumns)
            arguments 
                varTablesICD {mustBeA(varTablesICD, ["table", "cell"])}
                enumColumns (1,:) EnumColumnICD = [EnumColumnICD.SignalName, ...
                                                    EnumColumnICD.Dimensions, ...
                                                    EnumColumnICD.DataType, ...
                                                    EnumColumnICD.Telemetry, ...
                                                    EnumColumnICD.DefaultValue, ...
                                                    EnumColumnICD.Description, ...
                                                    EnumColumnICD.Notes];
            end
            
            if not(iscell(varTablesICD))
                varTablesICD = {varTablesICD};
            end

            % Initialize output
            cellTablesICD = varTablesICD;
            
            % Process each table separately
            for idC = 1:length(varTablesICD)

                tableTmp_ = cellTablesICD{idC};

                % Build new table with the enumColumns input
                dNumRows = height(tableTmp_);
                cellInCols = string(tableTmp_.Properties.VariableNames);

                % Create ordered output with only requested columns
                tableTmpOut = table();

                for dIdx = 1:numel(enumColumns)

                    % Get name of column from enumeration entry
                    charColName = string(enumColumns(dIdx));

                    if ismember(charColName, cellInCols)
                        % Preserve existing column
                        tableTmpOut.(char(charColName)) = tableTmp_.(char(charColName));
                    else
                        % Add missing column initialized with empty field
                        tableTmpOut.(char(charColName)) = EnumColumnICD.GetDefaultValue(char(charColName), dNumRows);
                    end

                end

                % Return table with requested columns in order
                cellTablesICD{idC} = tableTmpOut;
            end
        end

        function charOutFile = ExportTablesToFile(charOutFile, ...
                                                  varTables, ...
                                                  varSheetNames, ...
                                                  kwargs)
            arguments
                charOutFile             (1,1) string {mustBeText}
                varTables               {mustBeA(varTables, ["cell", "struct", "table"])}  % cell<tables> | struct of tables | table
                varSheetNames           {mustBeA(varSheetNames, ["cell", "string", "double"])} = []  % string array | cellstr | []
                kwargs.bOverwriteFile   (1,1) logical    = true
                kwargs.charExtension    (1,:) char {mustBeMember(kwargs.charExtension, "xlsx")} = "xlsx"
            end
            % Create an .xlsx with one sheet per table, preserving column order.
            % Sheets are named from varSheetNames (sanitized to Excel rules).
            %
            % Usage:
            %   CAutoGenICD.ExportTablesToWorkbook("icd.xlsx", {tableA, tableB}, ["State","Data"])
            %   CAutoGenICD.ExportTablesToWorkbook("icd.xlsx", struct('State',tableA,'Data',tableB))

            if not(istable(varTables) || iscell(varTables) || isstruct(varTables))
                error('CAutoGenICD:ExportTablesToWorkbook:UnsupportedTables', ...
                    'varTables must be a table, cell array of tables, or a struct of tables.');
            end

            % Handle missing extension of invalid extension
            [charDirPath, charFilename, charExt] = fileparts(charOutFile);
            
            if strcmpi(charExt, "")
                charOutFile = fullfile(charDirPath, strcat(charFilename, ".", kwargs.charExtension));
            else
                if not(strcmpi(charExt, ".xlsx"))
                    warning('This implementation currently supports xlsx only. Got extension %s. Exiting...', charExt)
                    return
                end
            end
            
            if not(isfolder(charDirPath))
                warning('Folder %s does not exist. Creating it...', charDirPath)
                mkdir(charDirPath)
            end
            
            % Normalize input into aligned cell arrays
            if istable(varTables)
                % Single table
                cellTables     = {varTables};
                % Ensure all names of sheets are valid
                cellSheetNames = CAutoGenICD.MakeValidSheetNames_(string( ternary_if(isempty(varSheetNames), ...
                                                                                    "Sheet1", ...
                                                                                    string(varSheetNames))) ...
                                                                  );
            
            elseif iscell(varTables)
                % Cell of tables
                cellTables = varTables;

                % Assert check on all cell entries
                assert(all(cellfun(@istable, cellTables)), ...
                    'CAutoGenICD:ExportTablesToWorkbook:InvalidInput', ...
                    'All items in varTables must be tables.');
                
                % Ensure all names of sheets are valid
                if isempty(varSheetNames)
                    cellSheetNames = CAutoGenICD.MakeValidSheetNames_("Sheet" + string(1:numel(cellTables)));
                else
                    cellSheetNames = CAutoGenICD.MakeValidSheetNames_(string(varSheetNames));
                end
            
            elseif isstruct(varTables)
                % Handle struct of tables

                if isempty(varSheetNames)
                    % Fields are used as names
                    cellSheetNames = CAutoGenICD.MakeValidSheetNames_(string(fieldnames(varTables))');
                else
                    cellSheetNames = CAutoGenICD.MakeValidSheetNames_(string(varSheetNames));
                end
                
                % Convert to cell of tables
                cellTables     = cellfun(@(f) varTables.(f), ...
                                              cellstr(cellSheetNames), ...
                                              'UniformOutput', false);
            
            end

            % Validate lengths
            assert(numel(cellTables) == numel(cellSheetNames), ...
                'CAutoGenICD:ExportTablesToWorkbook:NameCountMismatch', ...
                'Number of tables and sheet names must match.');

            % Enforce unique sheet names (Excel requires uniqueness, max 31 chars)
            cellSheetNames = CAutoGenICD.MakeUniqueSheetNames_(cellSheetNames);

            % Overwrite handling
            if kwargs.bOverwriteFile && exist(charOutFile, 'file') == 2
                delete(charOutFile);
            end

            % Write each table
            for dIdx = 1:numel(cellTables)

                tableTmp_ = cellTables{dIdx};

                % Ensure table variable names are valid for Excel header
                tableTmp_.Properties.VariableNames = matlab.lang.makeValidName(tableTmp_.Properties.VariableNames, ...
                                                                              'ReplacementStyle','delete');
                writetable(tableTmp_, ...
                    char(charOutFile), ...
                    'Sheet', char(cellSheetNames(dIdx)), ...
                    'WriteMode', 'overwritesheet');

            end
        end
    end

    methods (Static, Access = protected)
        %%% Arguments validation
        function bValid = validateInputBusSource_(varBusSource)
            bValid = isa(varBusSource, 'Simulink.Bus') || (ischar(varBusSource) || isstring(varBusSource) && isfile(varBusSource));
        end

        %%% Helper functions
        function strRowsOut = TraverseBus_(objBus_, ...
                                        charParentLabel, ...
                                        strDefaultCtx, ...
                                        charCurrentBusName, ...
                                        cellActiveStack, ...
                                        bIncludeDefaults, ...
                                        objBusRegistry, ...
                                        strEmptyRow)
            arguments
                objBus_           (1,1) {mustBeA(objBus_, "Simulink.Bus")}
                charParentLabel   {mustBeText}
                strDefaultCtx
                charCurrentBusName
                cellActiveStack
                bIncludeDefaults
                objBusRegistry
                strEmptyRow
            end

            if nargin < 5 || isempty(cellActiveStack)
                cellActiveStack = string.empty;
            end
            if nargin < 4 || isempty(charCurrentBusName)
                charCurrentBusName = "";
            end

            charCurrentBusName = string(charCurrentBusName);
            if strlength(charCurrentBusName) > 0
                cellActiveStack = [cellActiveStack, charCurrentBusName];
            end

            objElems    = objBus_.Elements;
            strRowsOut  = repmat(strEmptyRow, 0, 1);

            for dIdx = 1:numel(objElems)
                objElem = objElems(dIdx);

                charHierarchy     = CAutoGenICD.JoinHierarchyName_(charParentLabel, objElem.Name);
                bIsBusElement     = startsWith(string(objElem.DataType), "Bus:");
                charReferencedBus = "";
                strNestedDefaults = [];
                charDefaultString = "";

                if bIncludeDefaults
                    [charDefaultString, strNestedDefaults] = CAutoGenICD.ResolveDefaultValue_(strDefaultCtx, objElem.Name, bIncludeDefaults);
                end

                strRow = strEmptyRow;
                strRow.Hierarchy      = charHierarchy;
                strRow.SignalName     = string(objElem.Name);
                strRow.DataType       = string(objElem.DataType);
                strRow.Dimensions     = CAutoGenICD.FormatValue_(objElem.Dimensions);
                strRow.DimensionsMode = string(objElem.DimensionsMode);
                strRow.Unit           = string(objElem.Unit);
                strRow.Complexity     = string(objElem.Complexity);
                strRow.SamplingMode   = string(objElem.SamplingMode);
                strRow.SampleTime     = CAutoGenICD.FormatValue_(objElem.SampleTime);
                strRow.Min            = CAutoGenICD.FormatValue_(objElem.Min);
                strRow.Max            = CAutoGenICD.FormatValue_(objElem.Max);
                strRow.Description    = string(objElem.Description);
                strRow.DefaultValue   = charDefaultString;
                strRow.IsBus          = bIsBusElement;
                strRow.ReferencedBus  = "";

                if bIsBusElement
                    charReferencedBus = strip(replace(string(objElem.DataType), "Bus:", ""));
                    strRow.ReferencedBus = charReferencedBus;

                    bIsRecursive = any(cellActiveStack == charReferencedBus);
                    if bIsRecursive
                        strRow.Description = strtrim(strcat(strRow.Description, " (recursive reference omitted)"));
                    end
                end

                strRowsOut(end+1,1) = strRow; %#ok<AGROW>

                if bIsBusElement && strlength(charReferencedBus) > 0 && ~any(cellActiveStack == charReferencedBus)
                    objNestedBus  = CAutoGenICD.ResolveBusObject_(char(charReferencedBus), objBusRegistry);
                    strNestedRows = CAutoGenICD.TraverseBus_(objNestedBus, charHierarchy, strNestedDefaults, ...
                        charReferencedBus, cellActiveStack, ...
                        bIncludeDefaults, objBusRegistry, strEmptyRow);
                    strRowsOut    = [strRowsOut; strNestedRows]; %#ok<AGROW>
                end
            end
        end

        function [charDefaultOut, strNestedDefaultsOut] = ResolveDefaultValue_(strDefaultCtx_, ...
                                                                            charFieldName, ...
                                                                            bIncludeDefaults)
            charDefaultOut       = "";
            strNestedDefaultsOut = [];
            if ~bIncludeDefaults || isempty(strDefaultCtx_)
                return;
            end
            try
                varTmpVal = strDefaultCtx_;
                if numel(varTmpVal) > 1
                    varTmpVal = varTmpVal(1);
                end
                varTmpVal = varTmpVal.(charFieldName);
            catch
                return;
            end
            if isstruct(varTmpVal)
                strNestedDefaultsOut = varTmpVal;
            else
                charDefaultOut = CAutoGenICD.FormatValue_(varTmpVal);
            end
        end

        function objNestedBus = ResolveBusObject_(charBusName, objBusRegistry)
            charKey = char(charBusName);

            if objBusRegistry.isKey(charKey)
                objNestedBus = objBusRegistry(charKey);
                return;
            end

            objNestedBus = [];
            try
                objNestedBus = eval(charKey);
            catch
            end

            if isa(objNestedBus, 'Simulink.Bus')
                objBusRegistry(charKey) = objNestedBus;
                return;
            end

            try
                objNestedBus = evalin('base', charKey);
            catch
                objNestedBus = [];
            end

            if isa(objNestedBus, 'Simulink.Bus')
                objBusRegistry(charKey) = objNestedBus;
                return;
            end

            error('CAutoGenICD:buildICDTableFromBus:MissingBus', ...
                'Referenced bus "%s" not found. Provide it through kwargs.objBusRegistry or load it before calling this method.', charKey);
        end

        function charOut = JoinHierarchyName_(charParent, charChild)
            arguments
                charParent (1,:) string {mustBeText}
                charChild  (1,:) string {mustBeText}
            end
            % Function to join name of the hierarchy

            charParent = string(charParent);
            charChild  = string(charChild);

            if strlength(charParent) == 0 || strcmpi(charParent, "none")
                charOut = charChild;
            else
                charOut = charParent + "." + charChild;
            end
        end

        function charOut = FormatValue_(varVal)
            arguments
                varVal
            end

            if isa(varVal, 'string')
                charOut = strjoin(varVal, ", ");

            elseif ischar(varVal)
                charOut = string(varVal);

            elseif isnumeric(varVal)

                if isempty(varVal)
                    charOut = "";
                else
                    charOut = string(mat2str(varVal));
                end
                
            elseif islogical(varVal)

                if isscalar(varVal)
                    charOut = string(varVal);
                else
                    charOut = string(mat2str(varVal));
                end

            elseif isa(varVal, 'Simulink.Parameter')
                charOut = CAutoGenICD.FormatValue_(varVal.Value);

            elseif iscell(varVal)

                try
                    charOut = string(jsonencode(varVal));
                catch
                    charOut = string(strtrim(evalc('disp(varVal)')));
                end
                
            elseif isempty(varVal)
                charOut = "";
            else
                charOut = string(class(varVal));
            end
        end

        function PopulateBusRegistry_(objDest, varSrc)
            arguments
                objDest {mustBeA(objDest, "containers.Map")}
                varSrc  {mustBeA(varSrc, ["struct", "containers.Map"])}
            end

            % Store data into registry
            if isa(varSrc, 'containers.Map')
                % Using map as source
                cellKeys = varSrc.keys;

                for id = 1:numel(cellKeys)
                    objDest(cellKeys{id}) = varSrc(cellKeys{id});
                end

            elseif isstruct(varSrc)
                % Using struct
                cellNames = fieldnames(varSrc);

                for id = 1:numel(cellNames)
                    varVal = varSrc.(cellNames{id});
                    
                    if isa(varVal, 'Simulink.Bus')
                        objDest(cellNames{id}) = varVal;
                    end
                end
            end

        end

        function [objBusOut, strDefaultOut, charRootName, objRegistryOut] = LoadBusDefinitionFile_(charFile, ...
                                                                                                   bDefineDefaults)
            arguments
                charFile        (1,:) char {mustBeText}
                bDefineDefaults (1,1) logical = false
            end
            % Function to load bus object (definition) from definition file (assumed generated by other
            % tools of the library)

            if exist(charFile, 'file') ~= 2
                error('CAutoGenICD:buildICDTableFromBus:MissingDefinition', ...
                    'Bus definition file "%s" not found.', charFile);
            end

            % Get directory and filename
            [charFolder, charFcnName, ~] = fileparts(charFile);

            if strlength(charFolder) > 0
                addpath(charFolder);
                objCleanupPath = onCleanup(@() rmpath(charFolder)); 
            end

            % Get function handle to call bus definition
            fcnHandle   = str2func(charFcnName);
            dNumOutputs = nargout(fcnHandle);

            try
                if bDefineDefaults && dNumOutputs ~= 1
                    [objBusOut, strDefaultOut] = fcnHandle();
                else
                    objBusOut     = fcnHandle();
                    strDefaultOut = struct();
                end

            catch ME
                error('CAutoGenICD:buildICDTableFromBus:DefinitionExecutionFailed', ...
                    'Failed to evaluate "%s": %s', charFcnName, ME.message);
            end

            % Assumes "bus_" prefix
            objRegistryOut = containers.Map('KeyType','char','ValueType','any');
            cellBusVars    = who('bus_*');

            if isempty(cellBusVars)
                error('No bus definition found. Buses are assumed to have prefix "bus_<busname>"');
            end

            for id = 1:numel(cellBusVars)
                objRegistryOut(cellBusVars{id}) = eval(cellBusVars{id}); 
            end

            % Get root name from function name
            charRootName = regexprep(charFcnName, '^BusDef_', '');
            if isempty(charRootName)
                charRootName = charFcnName;
            end
        end

        function cellOut = MakeValidSheetNames_(strNames)
            % Remove invalid characters and limit to 31 chars as per Excel rules.
            % Invalid: : \ / ? * [ ]
            arguments
                strNames (1,:) string
            end

            % Accept string | char | cellstr. Return cellstr of valid Excel sheet names.
            strNames = string(strNames(:)).';

            % Remove invalid Excel chars: : \ / ? * [ ]
            strNames = regexprep(strNames, '[:\\/\?\*\[\]]', '');

            % Trim and default blanks
            strNames = strtrim(strNames);
            strNames(strlength(strNames) == 0) = "Sheet";

            % Excel limit 31 chars
            bIsTooLong = strlength(strNames) > 31;
            if any(bIsTooLong)
                strNames(bIsTooLong) = extractBefore(strNames(bIsTooLong), 32);
            end

            cellOut  = cellstr(strNames);
        end

        function cellOut = MakeUniqueSheetNames_(cellIn)
            arguments
                cellIn (1,:) cell
            end
            % Check sheet names and ensure uniqueness with numeric suffixes where needed.

            objMapSeenNames = containers.Map('KeyType','char','ValueType','double');
            cellOut = cell(size(cellIn));
            
            for idk = 1:numel(cellIn)
                charName = char(cellIn{idk});

                if ~isKey(objMapSeenNames, charName)
                    % Add key and name
                    objMapSeenNames(charName) = 1;
                    cellOut{idk} = charName;

                else

                    % Update count of existing names
                    dExistCount = objMapSeenNames(charName) + 1;
                    objMapSeenNames(charName) = dExistCount;

                    % Truncate base to keep total <=31 including suffix
                    charSuffix  = sprintf(' (%d)', dExistCount);
                    dMaxBaseLen = 31 - length(charSuffix);
                    charBase    = charName;

                    if length(charBase) > dMaxBaseLen
                        charBase = charBase(1:dMaxBaseLen);
                    end

                    charUnique = [charBase charSuffix];
                    
                    % If still collides, loop until free
                    while isKey(objMapSeenNames, charUnique)

                        % Update count
                        dExistCount = dExistCount + 1;
                        objMapSeenNames(charName) = dExistCount;
                        
                        charSuffix = sprintf(' (%d)', dExistCount);
                        dMaxBaseLen = 31 - length(charSuffix);
                        charBase = charName;
                        
                        if length(charBase) > dMaxBaseLen
                            charBase = charBase(1:dMaxBaseLen);
                        end
                        
                        charUnique = [charBase charSuffix];
                    end

                    objMapSeenNames(charUnique) = 1;
                    cellOut{idk} = charUnique;
                end
            end
        end

        %%% Utility: inline ternary
        function out = ternary_if(cond, a, b)
            if cond, out = a; else, out = b; end
        end
    
    end
end
