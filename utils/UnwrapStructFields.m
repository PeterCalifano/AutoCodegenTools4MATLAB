function UnwrapStructFields(strInputData)
arguments
    strInputData (1,1) {isstruct}
end

% For every field in the struct, assign it into the caller workspace
cellFieldNames = fieldnames(strInputData);
for idF = 1:numel(cellFieldNames)
    assignin('caller', cellFieldNames{idF}, strInputData.(cellFieldNames{idF}));
end

end
