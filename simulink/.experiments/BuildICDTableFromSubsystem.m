function T = BuildICDTableFromSubsystem(subsysPath)
% buildIcdTableWithBusSpecs  ICD table including bus element specs
%
%   T = buildIcdTableWithBusSpecs('myModel/MyBlock')
%
% Output columns:
%   ParentBus      – for bus elements, the name of the top-level bus ("" for primitives)
%   SignalName     – line name (or '<unnamed>' / '<unconnected>')
%   Dimension      – mat2str of CompiledPortDimensions
%   DataType       – element.DataType or CompiledPortDataType
%   Telemetry      – DataLogging=='on'
%   Initialization – true for Inports, or InitialOutput~='0' for Outports
%   Description    – block Description parameter
%   Notes          – block Notes parameter

    arguments
        subsysPath (1,:) char
    end

    % 1) Compile the model so CompiledPort* works :contentReference[oaicite:0]{index=0}
    mdl = bdroot(subsysPath);
    load_system(mdl);

    % 2) Find all top-level ports
    inP  = find_system(subsysPath,'SearchDepth',1,'BlockType','Inport');
    outP = find_system(subsysPath,'SearchDepth',1,'BlockType','Outport');
    ports = [inP; outP];

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
            
            busName = strtrim(cdt(5:end));
            % get the bus object (must be in base workspace) :contentReference[oaicite:1]{index=1}
            busObj = Simulink.Bus.getBusObject(busName);
            elems  = busObj.Elements;

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

end
