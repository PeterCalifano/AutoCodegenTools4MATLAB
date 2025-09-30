classdef SCodegenConfigForSLX
    %% DESCRIPTION
    % 
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 15-05-2025    Pietro Califano & o4-mini-high    First prototype implementation.
    % -------------------------------------------------------------------------------------------------------------
    %% METHODS
    % See methods()
    % -------------------------------------------------------------------------------------------------------------
    %% PROPERTIES
    % See properties()
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % Simulink Report toolbox.
    % -------------------------------------------------------------------------------------------------------------
    %% TODO
    % [-]
    % -------------------------------------------------------------------------------------------------------------

    properties
        Property1
    end
    
    methods
        function obj = SCodegenConfigForSLX(inputArg1,inputArg2)
            %SCODEGENCONFIGFORSLX Construct an instance of this class
            %   Detailed explanation goes here
            obj.Property1 = inputArg1 + inputArg2;
        end
        
        function outputArg = method1(obj,inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            outputArg = obj.Property1 + inputArg;
        end
    end
end

