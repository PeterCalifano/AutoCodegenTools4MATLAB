close all
clear
clc


%% How to load and compile model references
% 1) Load the top-level model onto the MATLAB path (but don’t open its window)
load_system(cellTargetSubsys);

% 2) Find _and_ load every referenced model in the hierarchy
[ cellModelschar, cellModelBlkschar ] = ...
    find_mdlrefs(cellTargetSubsys, KeepModelsLoaded=true);

% (Optional) 3) If you want to _open_ each model window:
for idx = 1:numel(cellModelschar)
    load_system(cellModelschar{idx});
    evalin('base', sprintf('%s([],[],[],"compile");', cellModelschar{:}));
end

%%
% load_system(mdl);

% tab = buildIcdTableFromSubsystem(cellTargetSubsys);

% for idx = 1:numel(cellModelschar)
%
%     evalin('base', sprintf('%s([],[],[],"term");', cellModelschar{:}));
% end

subsysPath = cellModelschar;

% 1) Compile the model so CompiledPort* works :contentReference[oaicite:0]{index=0}
mdl = bdroot(subsysPath);
load_system(mdl);
load_system("testSampleModel");

% 2) Find all top-level ports
inP  = find_system(subsysPath,'SearchDepth',1,'BlockType','Inport');
outP = find_system(subsysPath,'SearchDepth',1,'BlockType','Outport');
ports = [inP; outP];

% To get handles to blocks
% inporth = find_system(subsysPath{1},'FindAll','on','BlockType','Inport')

% To get handles to lines exiting from that port
% TOOD

% To get handles to lines
linesh = find_system(subsysPath{1},'FindAll','on','Type','line');


rows = {};  % will collect variable‐width rows

for k = 1:numel(ports)
    blk = ports{k};
    ph  = get_param(blk,'PortHandles');
    blkType = get_param(blk,'BlockType');

    % pick the correct port handle for compiled props
    if strcmp(blkType,'Inport')
        h = ph.Outport;
    else
        h = ph.Inport;
    end

    % --- inspect for bus vs. primitive ---
    cdt = get_param(h,'CompiledPortDataType');

    if contains(cdt,"bus_")  % bus detected


        handle = get_param(h, 'Element');
        % TODO I need to take the handle to the signal bus
        elem = get_param(handle,'Element');

        % set_param(handle,'Element','');
        bustype = get_param(getSimulinkBlockHandle(inP(1)),'OutDataTypeStr')

        set_param(handle,'Element',elem);
        parentBusObject = get_param(h, 'Parent');
        busDataType = get(parentBusObject, 'Name');

        % busName = strtrim(cdt(5:end));
        % get the bus object (must be in base workspace) :contentReference[oaicite:1]{index=1}
        % busObj = Simulink.Bus.getBusObject(busName);
        % elems  = busObj.Elements;

        for e = 1:numel(elems)
            rows(end+1,:) = { ...
                busName, ...                               % ParentBus
                elems(e).Name, ...                         % SignalName
                mat2str(elems(e).Dimensions), ...          % Dimension
                elems(e).DataType, ...                     % DataType
                strcmp(get_param(h,'DataLogging'),'on'), ... % Telemetry
                true, ...                                  % Inports & bus elems default init
                elems(e).Description, ...                  % Description
                ''};                                       % Notes
        end

    else

        % primitive
        % signal name
        lineH = get_param(h,'Line');
        if isempty(lineH)
            nm = '<unconnected>';
        else
            nm = get_param(lineH,'Name');
        end
        if isempty(nm), nm = '<unnamed>'; end

        % init flag
        if strcmp(blkType,'Outport')
            ioVal = get_param(blk,'InitialOutput');
            initFlag = ~(isempty(ioVal) || strcmp(ioVal,'0'));
        else
            initFlag = true;
        end

        rows(end+1,:) = { ...
            "", ...                                    % ParentBus
            nm, ...
            mat2str(get_param(h,'CompiledPortDimensions')), ...   % Dimension
            cdt, ...
            strcmp(get_param(h,'DataLogging'),'on'), ...        % Telemetry
            initFlag, ...
            get_param(blk,'Description'), ...                   % Description
            ''};                                                % Notes
    end
end

% 3) Build final table
T = cell2table(rows, ...
    'VariableNames',{'ParentBus','SignalName','Dimension','DataType', ...
    'Telemetry','Initialization','Description','Notes'});


return

%% Try to directly write the report using SLX toolbox
import mlreportgen.report.*    % Exposes Chapter, Section, etc.
import slreportgen.report.*    % Exposes Report, SystemIO, etc.

% Use SystemIO reporter for summary
objModelDefsIO = SystemIO(cellTargetSubsys);

% Compile this subsystem
% set_param(bdroot(charSubsysPath), 'SimulationCommand', 'update');

charDocType = 'pdf';
objReport = slreportgen.report.Report("./testAutoICD.pdf", charDocType);
open(objReport);

% Add a chapter (optional, for structure)
objICDchapter  = Chapter("Interface Control Document");
add(objReport, objICDchapter);

% Add system I/O definitions
add(objReport, objModelDefsIO);

close(objReport);
rptview(objReport);   % Open in Word or specified viewer
