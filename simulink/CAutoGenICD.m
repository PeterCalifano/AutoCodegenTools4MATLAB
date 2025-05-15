classdef CAutoGenICD < handle
    %% DESCRIPTION
    % CAutoGenICD class automatically generates ICDs for Simulink subsystems. Loads a model, runs an init 
    % script, compiles the model, extracts I/O data for specified subsystems, and generates. 
    % Excel ICD files with standardized naming conventions.
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 15-05-2025    Pietro Califano & o4-mini-high    First prototype implementation.
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

    properties
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
                if length(string(cellSubsystemPaths)) == 1
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
                % if contains(struct2array(ver), 'Simulink Report Generator')
                    % strModelData.(charKey) = self.extractSubsysData_(charSubsysPath);
                % else
                    strModelData.(charKey) = self.extractSubsysDataManual_(charSubsysPath);
                % end
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
                kwargs.enumOutFormat (1,1) string {mustBeMember(kwargs.enumOutFormat, ["xslx", "csv", "dat", "xml"])} = "csv"
            end
            % Method to build and export ICD file for each subsystem in strICDData

            if isempty(fieldnames(self.strICDData))
                self.getICDDataFromModel();
            end

            if ~exist(charOutputFolder, 'dir')
                mkdir(charOutputFolder);
            end

            % Determine format type
            if strcmpi(kwargs.enumOutFormat, "xslx")
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
                    'Delimiter',',', ...
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

            % Load model and compile (populate compiled port data)
            load_system(self.charModelName);
            % Equivalent to selecting Format->Port Data Types
        end



        function tableICD = extractSubsysData_(self, charSubsysPath)
            arguments (Input)
                self
                charSubsysPath (1,:) char
            end
            arguments (Output)
                tableICD table
            end

            % Use SystemIO reporter for summary
            import slreportgen.report.SystemIO

            objSysIO = SystemIO(charSubsysPath);

            % Compile this subsystem
            set_param(bdroot(charSubsysPath), 'SimulationCommand', 'update');

            % Fetch input/output summary tables
            tableIn  = objSysIO.getInputSummaryTable();
            tableOut = objSysIO.getOutputSummaryTable();

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
            handlesIn  = objSysIO.InputPortHandles;
            handlesOut = objSysIO.OutputPortHandles;
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
                initVal = get_param(blkPath, initParam);
                rows{idx,5} = ~(isempty(initVal) || strcmp(initVal, '0'));
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
end
