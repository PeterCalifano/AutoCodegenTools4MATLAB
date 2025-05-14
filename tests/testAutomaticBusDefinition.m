close all
clear
clc

% TEST SETUP
strTestStruct.bFlag = true;
strTestStruct.dSigmaValue = 10;
strTestStruct.strAttitudeData.ui8PolyDeg = uint8(8);
strTestStruct.strAttitudeData.dPolyCoeff = zeros(4,10);
strTestStruct.ui32MaxNumOfFrames = uint32(50);


%% test_GenerateBusDefinitionFile
charOutputFolder    = "./bus_autodefs";
charBusName         = "testBus";
strInput            = strTestStruct;

GenerateBusDefinitionFile(strInput, charBusName, charOutputFolder);

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

