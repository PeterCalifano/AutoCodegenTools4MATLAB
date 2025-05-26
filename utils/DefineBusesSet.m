function DefineBusesSet(strBusDefs, charOutputFolder) %#codegen
arguments
    strBusDefs {isstruct}
    charOutputFolder (1,:) string {mustBeA(charOutputFolder, ["string", "char"])} = "./bus_autodefs"
end
%%% Conveniency function to define a set of buses assuming a struct with the

for idBus = 1:numel(strBusDefs)

    charBusName      = strBusDefs(idBus).Name;
    charTestDescript = strBusDefs(idBus).Description;
    strInput         = strBusDefs(idBus).Value;

    GenerateBusDefinitionFile(strInput, ...
        charBusName, ...
        charOutputFolder, ...
        "bStoreDefaultValues", true, ...
        "bDefineBusesInPlace", true, ...
        "charHeaderDescription", charTestDescript);
end

end

