function [busObject] = CreateSLXbusFromVariables(inVarsCell, charBusDescription)
arguments
    inVarsCell (:,:) cell
    charBusDescription (1, :) string = ""
end
%% SIGNATURE
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% What the function does
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% in1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% out1 [dim] description
% Name1                     []
% Name2                     []
% Name3                     []
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 13-05-2025    Pietro Califano     First prototype implementation
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Function code

% Define elements struct
ui32NumOfBusElements = length(inVarsCell);
busElems(ui32NumOfBusElements) = Simulink.BusElement;

bWithDescription = false;
if size(inVarsCell, 2) > 1
    bWithDescription = true;
end

for idEl = 1:ui32NumOfBusElements
    
    inputVariable = inputVariable{idEl, 1};

    % Add description if provided
    if bWithDescription
        try
            charDescription = inputVariable{idEl, 2};
        catch
            charDescription = "";
        end
    end

    % Build element
    busElems(idEl) = buildBusElement(inputVariable, charDescription);
end

% Define bus object
busObject = Simulink.Bus;
busObject.Elements = busElems;
busObject.Description = charBusDescription;

end

% LOCAL FUNCTION (used for recursion
function busElem = buildBusElement(inputVariable, charDescription)

% Handle struct using recursive calls
if isstruct(inputVariable)

    % TODO


elseif not(isstruct(inputVariable)) && not(iscell(inputVariable))
    
    if isreal(inputVariable)
        charComplexity = 'real';
    else
        charComplexity = 'complex';
    end

    busElem = Simulink.BusElement;
    busElem.Name = "";
    busElem.Complexity = charComplexity;
    busElem.Dimensions = [size(inputVariable)];
    busElem.DataType = 'int32'; % Get from input type
    busElem.DimensionsMode = 'Fixed';
    busElem.Unit = '';
    busElem.Description = charDescription;

else

end

end
