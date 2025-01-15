function [outputArg1,outputArg2] = getCasadiSymFlowSTM(casadiDynFun)
arguments
    casadiDynFun (1,1) casadi.Function
end
%% PROTOTYPE
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% in1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% Name4                     []
% Name5                     []
% Name6                     []
% Name7                     []
% Name8                     []
% Name9                     []
% Name10                    []
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% Name4                     []
% Name5                     []
% Name6                     []
% Name7                     []
% Name8                     []
% Name9                     []
% Name10                    []
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% DD-MM-YYYY        Pietro Califano         Modifications
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

% Get casadi dynamics function object properties
InputVarN = casadiDynFun.n_in;
OutputVarOut = casadiDynFun.n_out;

% Get sizes of inputs and outputs
InputSizes = zeros(InputVarN, 2);
OutputSizes = zeros(OutputVarOut, 2);

for idIn = 1:InputVarN
    InputSizes(idIn, :) = casadiDynFun.size_in(idIn);
end
for idOut = 1:OutputVarOut
    OutputSizes(idOut, :) = casadiDynFun.size_out(idOut);
end

% Get names
InputNames = casadiDynFun.name_in;
OutpuName = casadiDynFun.name_out;



% Generate flow propagation function
RK4_autoDiff



% Compute STM by derivation



end
