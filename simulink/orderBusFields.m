function [objBus] = orderBusFields(objBus)

% Get elements from Bus
elements = objBus.Elements;

% Get the names of the elements
elementNames = {elements.Name};

% Sort the names alphabetically (same as orderfields behavior)
[~, sortIdx] = sort(elementNames);

% Reorder the elements
objBus.Elements = elements(sortIdx);

end
