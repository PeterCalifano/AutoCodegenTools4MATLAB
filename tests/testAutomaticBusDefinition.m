close all
clear
clc

% TEST SETUP
strTestStruct.bFlag = true;
strTestStruct.dSigmaValue = true;
strTestStruct.strAttitudeData.ui8PolyDeg = uint8(8);
strTestStruct.strAttitudeData.dPolyCoeff = zeros(4,10);
strTestStruct.ui32MaxNumOfFrames = uint32(50);


%% test_GenerateBusDefinitionFile
charOutputFolder    = ".";
charBusName         = "testBus";
strInput            = strTestStruct;

GenerateBusDefinitionFile(strInput, charBusName, charOutputFolder);

%% test_GenerateBusDefinitionFile_withDefaults
charOutputFolder    = ".";
charBusName         = "testBusWithExample";
strInput            = strTestStruct;

GenerateBusDefinitionFile(strInput, ...
    charBusName, ...
    charOutputFolder, ...
    "bStoreExampleValues", true);

