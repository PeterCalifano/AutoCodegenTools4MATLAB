close all
clear
clc

%% Setup sample model
% Define target model
charModelName = 'testSampleModel';
charSubsysPath = fullfile(charModelName, 'testSampleModelRef');  

strDataBus = struct();
strDataBus.dDoubleScalar        = 42;
strDataBus.ui8Integer           = uint8(9);

strDataBus.strDoubleNestStruct  = struct();
strDataBus.strDoubleNestStruct.dNestedDouble    = 42;
strDataBus.strDoubleNestStruct.ui32NestedInt    = uint32(32);
strDataBus.strDoubleNestStruct.i16NestedInt     = int16(16);

% Define input data (buses)
charBusName       = "strCustomBus";
charOutputFolder  = "bus_autodefs";

GenerateBusDefinitionFile(strDataBus, ...
                          charBusName, ...
                          charOutputFolder, ...
                          "bStoreExampleValues", true);

return

%% Report generation
% Build model using the active configset
Simulink.BlockDiagram.buildActiveConfigSet(charModelName);

% Create report
charDocType = 'pdf';
objReport = slreportgen.report.Report("./testAutoICD.pdf", charDocType);  
open(objReport);

% Add a chapter (optional, for structure)
objICDchapter  = Chapter("Interface Control Document");
add(objReport, objICDchapter);

% Add system I/O definitions
objModelDefsIO = SystemIO(charSubsysPath);
add(objReport, objModelDefsIO);

close(objReport);
rptview(objReport);   % Open in Word or specified viewer
