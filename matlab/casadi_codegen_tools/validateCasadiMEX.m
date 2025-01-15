function [o_bEquivalencyFlags, o_cellOutputResidual] = validateCasadiMEX(casadiFunObj, casadiFunMEX, varargin)
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
% 29-12-2023      Pietro Califano       First function prototype. To test
%                                       as part of the toolchain.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

% TODO1: check if nargout works also with casadi functions
% TODO2: check how to pass inputs to functions to exercise them

% Inputs assert
        assert(isa(casadiFunObj, 'casadi.Function') || isa(casadiFunObj, 'function_handle'), ...
            'Input 1 must be a casadi or MATLAB function!');
        assert(isa(casadiFunMEX, 'funtion_handle'), 'Input 2 must be a function!')

% Check number of functions outputs and preparat output data
numOutputMex = nargout(casadiFunMEX);

if isa(casadiFunObj, 'casadi.Function')
    numOutputFcn = casadiFunObj.numel_out;
else
    numOutputMex = nargout(casadiFunObj);
end

assert(numOutputMex == numOutputFcn, 'Casadi function and generated MEX do not have same number of output!')
o_bEquivalencyFlags = false(1, numOutputMex);
o_cellOutputResidual = cell(1, numOutputMex);

% Exercise casadi function object
outCellFcn = cell(1, numOutputFcn);
[outCellFcn{:}] = casadiFunObj(varargin);

% Exercise casadi function MEX
outCellMex = cell(1, numOutputMex);
[outCellMex{:}] = casadiFunMEX(varargin);

% Compare outputs for numerical equivalency
for idOut = 1:numOutputMex
    % Check size of outputs
    assert(sum(size(outCellMex{idOut}) - size(outCellFcn{idOut})) == 0, strcat("Size mismatch in output number: ", idOut) );

    % Compute difference
    outputResidual = outCellMex{idOut} - outCellFcn{idOut};
    o_cellOutputResidual{idOut} = outputResidual;

    % Check for equivalency depending on datatype
    if isa(outputResidual, 'double')
        if all(outputResidual < 1.1*eps('double'))
            o_bEquivalencyFlags(idOut) = true;
        end

    elseif isa(outputResidual, 'single')
        if all(outputResidual < 1.1*eps('single'))
            o_bEquivalencyFlags(idOut) = true;
        end

    elseif isa(outputResidual, 'integer') || isa(outputResidual, 'logical')
        if outputResidual == 0
            o_bEquivalencyFlags(idOut) = true;
        end

    else
        warning('Output datatype not handled!')
        o_cellOutputResidual{idOut} = nan;
    end

end




