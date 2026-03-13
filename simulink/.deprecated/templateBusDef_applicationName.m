function [] = templateBusDef_applicationName()

size1 = 1;
size2 = 2;

%% INPUT BUS: strStateBus
% i_dxState, ...
% i_dPxState, ...
% i_dDeltaTime, ...
% i_dStateTimetag, 

elem(1) = Simulink.BusElement;
elem(1).Name = "name";
elem(1).Complexity = 'real';
elem(1).Dimensions = [size1, size2];
elem(1).DataType = 'dtype';
elem(1).DimensionsMode = 'Fixed';
elem(1).Unit = '';
elem(1).Description = "Description";


% Define input bus
strTemplateBus = Simulink.Bus;
strTemplateBus.Elements = elem;
strTemplateBus.Alignment = -1; % To force specific memory alignment if required
strTemplateBus.PreserveElementDimensions = false; % To preserve multi-dim array shape in generated code
strTemplateBus.DataScope = 'Auto'; % Auto, Imported, Exported. 

% Re-order fields in alphabetical order like orderfields to ease definition
[strTemplateBus] = orderBusFields(strTemplateBus);

% NOTE from doc: To prevent ill-formed header file inclusions in generated code, a Simulink.Bus object must specify DataScope 
% as 'Exported' and HeaderFile as a C header file when the Simulink. Bus object has at least one nested Simulink.
% Bus object that specifies DataScope as 'Exported' and HeaderFile as a C header file.

clear elem
assignin("base", "strStateBus", strTemplateBus)

end
