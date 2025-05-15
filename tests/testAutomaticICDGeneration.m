close all
clear
clc

addpath("../simulink/")
% Instantiate class
charInitScript = "testSampleInit.m"; % Init script or .mat to load
charModelName = "testSampleModel";
cellTargetSubsys = "";

objICDgenerator = CAutoGenICD( charModelName, cellTargetSubsys, charInitScript);

% Fetch data from model
strModelData = objICDgenerator.getICDDataFromModel();

% Export document
objICDgenerator.exportICD("enumOutFormat", "xslx");
