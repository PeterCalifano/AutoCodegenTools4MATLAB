function varOut = EvalTernaryIf(bCond, varA , varB) %#codegen
arguments
    bCond (1,1) logical
    varA
    varB
end

if bCond
    varOut = varA;
else
    varOut = varB;
end

end
