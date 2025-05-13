function [objBus] = OrderBusFields(objBus)
arguments
    objBus {mustBeA(objBus, "Simulink.Bus")}
end

% Get elements from Bus
objElems = objBus.Elements;

% Get the names of the elements
cellElemNames = {objElems.Name};

% Sort the names alphabetically (same as orderfields behavior)
[~, ui32SortIdx] = sort(cellElemNames);

% Reorder the elements
objBus.Elements = objElems(ui32SortIdx);

end
