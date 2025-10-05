function compareStructures(struct1, struct2)
    % Get the field names of both structures
    fields1 = fieldnames(struct1);
    fields2 = fieldnames(struct2);
    
    % Ensure both structures have the same fields
    assert(isequal(fields1, fields2), 'Structures have different field names.');

    % Loop over each field and compare their properties
    for i = 1:numel(fields1)
        field = fields1{i};
        
        % Compare the data type
        type1 = class(struct1.(field));
        type2 = class(struct2.(field));
        assert(isequal(type1, type2), ['Field ', field, ' has different data types: ', type1, ' vs ', type2]);

        % Compare the size
        size1 = size(struct1.(field));
        size2 = size(struct2.(field));
        assert(isequal(size1, size2), ['Field ', field, ' has different sizes: ', mat2str(size1), ' vs ', mat2str(size2)]);
        
        % Compare the content if both fields are not structs or arrays

        if isstruct(struct1.(field))
            % Recursively compare sub-structs
            compareStructures(struct1.(field), struct2.(field));
        else
            % Compare the content
            assert(isequal(struct1.(field), struct2.(field)), ...
                ['Field mismatch for: ', field]);
        end
    end
end
