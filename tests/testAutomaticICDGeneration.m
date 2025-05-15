close all
clear
clc

addpath("../simulink/")
% Instantiate class
charInitScript = "testSampleInit.m"; % Init script or .mat to load
charModelName = "testSampleModel";
cellTargetSubsys = "testSampleModelRef";

objICDgenerator = CAutoGenICD( charModelName, cellTargetSubsys, charInitScript);

% Fetch data from model
run(charInitScript)
eval(sprintf('%s([],[],[],''compile'');', charModelName));
strModelData = objICDgenerator.getICDDataFromModel();
eval(sprintf('%s([],[],[],''term'');', charModelName));

% Export document
objICDgenerator.exportICD("enumOutFormat", "xslx");
