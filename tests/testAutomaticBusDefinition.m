close all
clear
clc

cd( fileparts(mfilename("fullpath")) );
addpath('..');
SetupPaths_AutoCodegenTools4MATLAB;

% TEST SETUP
strTestStruct.bFlag = true;
strTestStruct.dSigmaValue = 10;
strTestStruct.strAttitudeData.ui8PolyDeg = uint8(8);
strTestStruct.strAttitudeData.dPolyCoeff = zeros(4,10);
strTestStruct.ui32MaxNumOfFrames = uint32(50);

strStructArray = struct();
strStructArray(1).dRandomVar = randn(3,1);
strStructArray(2).dRandomVar = randn(3,1);
strStructArray(3).dRandomVar = randn(3,1);
strStructArray(3).dAdditionalVarToTryToBreak = 0.0;

strTestStructWithStructArray = struct();
strTestStructWithStructArray.strStructArray = strStructArray;
strTestStructWithStructArray.bAnotherBool = true;
return

%% test_GenerateBusDefinitionFile_basic
charOutputFolder    = "./bus_autodefs";
charBusName         = "testBus";

GenerateBusDefinitionFile(strTestStruct, ...
                        charBusName, ...
                        charOutputFolder, ...
                        "bCleanupBeforeGeneration", true, ...
                        "bDefineBusesInPlace", true);

% Call bus definition to check usage
run(sprintf('%s/BusDef_%s.m', charOutputFolder, charBusName));

return
%% test_GenerateBusDefinitionFile_withStructArray
charOutputFolder    = "./bus_autodefs_struct_array";
charBusName         = "testBusWithStructArray";

GenerateBusDefinitionFile(strTestStructWithStructArray, ...
                        charBusName, ...
                        charOutputFolder, ...
                        "bCleanupBeforeGeneration", true, ...
                        "bDefineBusesInPlace", true);

run(sprintf('%s/BusDef_%s.m', charOutputFolder, charBusName));

return
%% test_GenerateBusDefinitionFile_withDefaults
charOutputFolder    = "./bus_autodefs";
charBusName         = "testBusWithExample";
strInput            = strTestStruct;
charTestDescript    = "This is a sample description for the header.";

GenerateBusDefinitionFile(strInput, ...
    charBusName, ...
    charOutputFolder, ...
    "bStoreDefaultValues", true, ...
    "bDefineBusesInPlace", true, ...
    "charHeaderDescription", charTestDescript);

strInput.strAttitudeData = orderfields(strInput.strAttitudeData); % Order fields of nested struct
compareStructures(testBusWithExample, orderfields(strInput));

return

%% test_GenerateBusDefinitionFile_withDefaults_structArrays
addpath("/home/peterc/devDir/projects-DART/rcs-1-gnc-simulator/script/config");
load("test_data/test_data_bus_definition.mat")

charOutputFolder    = "./bus_autodefs";
charBusName         = "testBusWithExample";
strInput            = strTestStruct;
charTestDescript    = "This is a sample description for the header.";

[strFilterMutabConfig, strDynParams, strMeasModelParams, strMeasBus] = configure_filter_RCS1(strFilterConstConfig, ...
                                                                                        gnc_configuration_bus, ...
                                                                                        gnc_data_input_bus, ...
                                                                                        "bWriteBusDefs", true, ...
                                                                                        "bStrictMode", false);

% Test call of strDynParams bus definition function
[objBusDef, strDefault] = BusDef_strDynParams();


return
