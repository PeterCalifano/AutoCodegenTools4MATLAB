classdef CCodegenHelper < handle
    %% DESCRIPTION
    % Helper class to streamline the automatic code generation process for mex and lib with MATLAB, Simulink
    % and Embedder Coder. This helper calls codegen given a predefined set of inputs, while exposing the
    % most important configuration settings the coder accepts. It is a key component of the more generic
    % framework to integrate MATLAB code in C/C++ programs.
    % -------------------------------------------------------------------------------------------------------------
    %% CHANGELOG
    % 02-04-2025    Pietro Califano    Initialized from legacy makeCodegen function. 
    % -------------------------------------------------------------------------------------------------------------
    %% METHODS
    % Method1: Description
    % -------------------------------------------------------------------------------------------------------------
    %% PROPERTIES
    % Property1: Description, dtype, nominal size
    % -------------------------------------------------------------------------------------------------------------
    %% DEPENDENCIES
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    %% Future upgrades
    % [-]
    % -------------------------------------------------------------------------------------------------------------
    properties (SetAccess = protected, GetAccess = public)
        enumToolchain {mustBeMember(enumToolchain, ["matlab", "casadi"])} = "matlab";
    end

    methods (Access = public)
        % CONSTRUCTOR
        function self = CCodegenHelper(kwargs)
            arguments
            
            end
            arguments
                kwargs.enumToolchain {mustBeMember(kwargs.enumToolchain, ["matlab", "casadi"])} = "matlab";
            end

            % Store properties
            self.enumToolchain = kwargs.enumToolchain;
        end

        % GETTERS

        % SETTERS

        % METHODS

        function [] = makeCodegen(self)



            switch self.enumToolchain
                case "matlab"
                    % Call matlab makeCodegen static function

                case "casadi"
                    % Call casadi codegen toolchain
                
                otherwise
                    error('Invalid toolchain selected: must be "matlab" or "casadi".')
            end
        end


    end

    methods (Access = protected)


    end


    methods (Access = public, Static)

        function [charOutputFcnName, charOutputFolder] = makeCodegenStatic(charTargetFcnName, cellInputArgs, objCoderConfig, kwargs)
            arguments
                charTargetFcnName       {mustBeA(charTargetFcnName, ["char", "string"])}
                cellInputArgs           {mustBeA(cellInputArgs, "cell")}
                objCoderConfig          {CCodegenHelper.mustBeValidCodegenConfig(objCoderConfig)} = "mex";
            end
            arguments 
                kwargs.bStrictEmbedded      (1,1) logical {islogical, isscalar} = false
                kwargs.charOutputFcnName    (1,:) string {mustBeA(kwargs.charOutputFcnName, ["char", "string"])} = charTargetFcnName
            
            end

            ui32NumOfInputs = nargin(charTargetFcnName);
            assert(ui32NumOfInputs == length(cellInputArgs), ...
                sprintf("ERROR: incorrect input arguments cell. Target function expects %d inputs, but %d were specified.", ui32NumOfInputs, length(cellInputArgs)));

            % Determine configuration object
            if isstring(objCoderConfig) || ischar(objCoderConfig) || nargin < 3
                [objCoderConfig] = getDefaultCoderConfig(objCoderConfig); 
            end

            % TODO add modifiers of configuration

            % Target function details
            % Get number of outputs
            ui32NumOfOutputs = nargout(charTargetFcnName);
            fprintf('\nGenerating src or compiled code from function %s...\n', string(charTargetFcnName));

            % Make codegen call
            [charOutputFcnName] = CCodegenHelper.callCodegen(charTargetFcnName, ...
                                                            cellInputArgs, ...
                                                            objCoderConfig, ...
                                                            ui32NumOfOutputs, ...
                                                            "charOutputFcnName", kwargs.charOutputFcnName);

        end

        function [charOutputFcnName] = callCodegen(charTargetFcnName, cellInputArgs, objCoderConfig, ui32NumOfOutputs, kwargs)
            arguments
                charTargetFcnName  {mustBeA(charTargetFcnName, ["char", "string"])}
                cellInputArgs      {mustBeA(cellInputArgs, "cell")}
                objCoderConfig     {mustBeA(objCoderConfig, "coder_config")};
                ui32NumOfOutputs   (1,1) {isscalar}
            end
            arguments
                kwargs.charOutputFcnName  (1,:) string {mustBeA(kwargs.charOutputFcnName, ["char", "string"])} = charTargetFcnName
            end

            % Get build type
            if not(isa(objCoderConfig, 'coder.MexCodeConfig'))
                charBuildType = lower(objCoderConfig.OutputType);
            else
                charBuildType = 'mex';
            end

            % Extract filename and append build type
            [~, kwargs.charOutputFcnName, ~] = fileparts(fullfile(kwargs.charOutputFcnName));
            charOutputFcnName = strcat(kwargs.charOutputFcnName, '_', lower(charBuildType));

            % CODEGEN CALL
            fprintf("---------------------- CODE GENERATION EXECUTION: BEGIN ---------------------- \n\n")
            % Execute code generation
            codegenCommands = {strcat(charTargetFcnName,'.m'), "-config", objCoderConfig,...
                "-args", cellInputArgs, "-nargout", ui32NumOfOutputs, "-o", charOutputFcnName};
            codegen(codegenCommands{:});
            fprintf("\n---------------------- CODE GENERATION EXECUTION: END ----------------------\n")

        end

        function [objCoderConfig] = getDefaultCoderConfig(enumCoderConfig)
            arguments
                enumCoderConfig (1,:) string {mustBeMember(enumCoderConfig, ["mex", "lib", "exe", "dll"])}
            end

            % TODO consider to add common in one single call, and only specify those important for the specific one
            switch lower(enumCoderConfig)
                case 'mex'
                    fprintf("\nCODER CONFIG: MEX with default configuration...\n")

                    objCoderConfig = coder.config('mex', 'ecoder', true);
                    objCoderConfig.TargetLang = 'C++';
                    objCoderConfig.GenerateReport = true;
                    objCoderConfig.LaunchReport = true;
                    objCoderConfig.EnableJIT = false;
                    objCoderConfig.MATLABSourceComments = true;

                case 'lib'
                    fprintf("\nCODER CONFIG: LIB with default configuration...\n")

                    objCoderConfig = coder.config('lib', 'ecoder', true);
                    objCoderConfig.TargetLang = 'C++';
                    objCoderConfig.GenerateReport = true;
                    objCoderConfig.LaunchReport = true;
                    objCoderConfig.MATLABSourceComments = true;

                case 'exe'
                    fprintf("\nCODER CONFIG: LIB with default configuration...\n")

                    objCoderConfig = coder.config('exe', 'ecoder', true);
                    objCoderConfig.TargetLang = 'C++';
                    objCoderConfig.GenerateReport = true;
                    objCoderConfig.LaunchReport = true;
                    objCoderConfig.MATLABSourceComments = true;
                otherwise
                    error('Invalid or unknwon configuration type.')
            end
        end


        % Method to assert validity of code generation input setting or type
        function [bValidInput] = mustBeValidCodegenConfig(inputVariable)

            bValidInput = mustBeA(inputVariable, ["string", "char", "coder_config"]) || ...
                ( (isstring || ischar) && mustBeMember(inputVariable, ["mex", "lib", "exe", "dll"]) );

        end

    end




end
