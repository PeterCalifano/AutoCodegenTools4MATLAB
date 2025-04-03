function [profData] = ProfileFcn(charFcnName, varargs, options)
arguments
    charFcnName (1,:) string {mustBeA(charFcnName, ["string", "char"])}
end
arguments (Repeating)
    varargs % Inputs of function to call
end
arguments
    options.ui32NumOfCalls  (1,1) uint32 {isscalar, isnumeric} = 1
    options.bSaveData       (1,1) logical {isscalar, islogical} = true
end
%% SIGNATURE
% [profData] = ProfileFcn(charFcnName, varargs, options)
% -------------------------------------------------------------------------------------------------------------
%% DESCRIPTION
% Function implementing automatic profiling tool with averaging capability, exploiting MATLAB profiler.
% -------------------------------------------------------------------------------------------------------------
%% INPUT
% arguments
%     charFcnName (1,:) string {mustBeA(charFcnName, ["string", "char"])}
% end
% arguments (Repeating)
%     varargs % Inputs of function to call
% end
% arguments
%     options.ui32NumOfCalls  (1,1) uint32 {isscalar, isnumeric} = 1
%     options.bSaveData       (1,1) logical {isscalar, islogical} = true
% end
% -------------------------------------------------------------------------------------------------------------
%% OUTPUT
% profData
% -------------------------------------------------------------------------------------------------------------
%% CHANGELOG
% 31-01-2025    Pietro Califano     First implementation of simple automatic profiling tool.
% -------------------------------------------------------------------------------------------------------------
%% DEPENDENCIES
% [-]
% -------------------------------------------------------------------------------------------------------------
%% Future upgrades
% [-]
% -------------------------------------------------------------------------------------------------------------

assert(isfile("charFcnName"), 'Specified function not found.')

% Clear profiler data
profile clear;
profile on;

for idC = 1:ui32NumOfCalls
    profile resume; % Resume profiling for each run

    % Dynamically call the function with input arguments
    feval(charFcnName, varargs{:}); 

    profile pause; % Pause profiling to separate runs
end

profile off;
% Get profiling data
profData = profile('info');

if options.bSaveData
    profsave(profData, sprintf('profiling_%s', charFcnName));
end

if options.ui32NumOfCalls > 1

    % Print averaged results if applicable
    ui32NumOfFunctions = length(profData.FunctionTable);
    
    % Initialize storage for averaging
    dAvgTimes = zeros(ui32NumOfFunctions, 1);
    
    for idC = 1:ui32NumOfFunctions
        dAvgTimes(idC) = 1000 * profData.FunctionTable(idC).TotalTime / options.ui32NumOfCalls;
    end
    
    % Print averaged results
    fprintf('Averaged Profiling Results:\n');
    for idC = 1:ui32NumOfFunctions
        fprintf('Call: %s, Avg Time: %4.6f ms\n', ...
            profData.FunctionTable(idC).FunctionName, ...
            dAvgTimes(idC));
    end

end

end

