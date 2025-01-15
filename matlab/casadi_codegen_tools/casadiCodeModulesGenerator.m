close all
clear
clc

import casadi.*

%% SCRIPT NAME
% Casadi-based automatic Time/Observation Update functions generation
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 30-12-2023    Pietro Califano     Early version prototype
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades


%% ----------------------------------------------- USER OPTIONS -----------------------------------------------
% SCRIPT BRANCH SELECTION
bGEN_MeasUp_MODULE = true;
bGEN_TimeUp_MODULE = false;


% AUTOMATIC CODE GEN
OUTPUT_TYPE = 'mex'; % Supported: mex, c, cpp, sfcn
BUILD_PATH = 'srcCode'; % Define where generated files are put
compilerOflag = '-03';


%% --------------------------------------------- USER DEFINITIONS ---------------------------------------------

% TO DO: 
% 1) Define interface for symbolic variables creation with their name (cell
%    containing the names of the variables?)
% 2) Define interface to pass function as MATLAB handle?
% 3) Define interface to say to the function the following things:
%         Which are the inputs in (1) wrt the jacobian must be computed
%         Names of the jacobian functions and outputs
% 4) I/O format for automatic generation of functions and jacobians (cells?)
% 

if bGEN_MeasUp_MODULE == true
    % Input symbolic variables definition (all function inputs)


    namesCell = {'i_dKcam'; 'i_dqCAMwrtIN'; 'i_dxSC'; 'i_dPosPoint_IN'};
    varSizeCell = {[3, 3]; [4, 1]; [3, 1]; [3, 1]};


    % Possible way to pass the function: no need for correct name, just
    % of placeholders to avoid overlycomplicated things to call it
    fcnHandle = @(x1, x2, x3, x4) pinholeProjectSymHP(x1, x2, x3, x4);
    % And feval? the fcnHandle alone does not solve the problem

    % Select ID (progressive from 1 in definition orded) of symbolic
    % variables wrt which the Jacobian of the fuction is computed.
    JwrtVarIDs = [3];

    % DEVNOTE: BELOW HERE IS TO MOVE DOWN/IN FUNCTIONS
%     i_dKcam = SX.sym('i_dKcam', [3, 3]);
%     i_dqCAMwrtIN = SX.sym('i_dqCAMwrtIN', 4, 1);
%     i_drCAM_IN = SX.sym('i_dxSC', 3, 1);
%     i_dPosPoint_IN = SX.sym('i_dPosPoint_IN', 3, 1);


    varsCell{idN} = SX.sym(inputCell{idN, 1}, inputCell{idN, 2});

    % Call casadi-compatible function providing symbolic inputs
    [o_dUVpixCoord, o_dDCM_fromINtoCAM] = pinholeProjectSymHP(i_dKcam, i_dqCAMwrtIN, i_drCAM_IN, i_dPosPoint_IN);
     
    jac1 = jacobian(o_dUVpixCoord, i_drCAM_IN);

    fcnJac1 = Function('dUVdr', {i_dKcam, i_dqCAMwrtIN, i_drCAM_IN, i_dPosPoint_IN}, {jac1}, ...
        {'i_dKcam', 'i_dqCAMwrtIN', 'i_drCAM_IN', 'i_dPosPoint_IN'}, 'test');


    % Assert to check definition consistency

    % Define boolean array to select variables wrt computing the jacobians
    isJacReq = false(length(namesCell), 1);
    isJacReq(JwrtVarIDs) = true;
    
    % Package data into inputCell
    inputCell = cell(length(namesCell), 3);

    for idN = 1:length(namesCell)
        inputCell{idN, 1} = namesCell{idN};
        inputCell{idN, 2} = varSizeCell{idN};
        inputCell{idN, 3} = isJacReq(idN);
    end

    % Fill cell with jacobians
    [fcnsCell, jacCell] = getCasadiSymFcnJac(inputCell);

elseif bGEN_TimeUp_MODULE == true








end



%% ----------------------------------- AUTOMATIC CASADI FCN GENERATION -----------------------------------------

if bGEN_MeasUp_MODULE == true








elseif bGEN_TimeUp_MODULE == true








end

%% ------------------------------------ AUTOMATIC CODE GENERATION ------------------------------------------
 
% casadiFcnCodegen(casadiFunObj, OUTPUT_TYPE, BUILD_PATH, compilerOflag)




















