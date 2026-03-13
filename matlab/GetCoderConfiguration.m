function [objCoderCfg] = GetCoderConfiguration(options)
arguments
    options.bUseEmbeddedCoder       (1,1) logical = true;
    options.bAutocodeForPlatformARM (1,1) logical = true;
end

% Define coder configuration object
objCoderCfg = coder.config('lib', 'ecoder', options.bUseEmbeddedCoder);
objCoderCfg.TargetLang = 'C++';
objCoderCfg.GenerateReport = true;
objCoderCfg.LaunchReport = true;
objCoderCfg.Toolchain = "CMake";
objCoderCfg.CodeFormattingTool = 'Auto';

if strcmpi(objCoderCfg.Name, 'MexCodeConfig')
    objCoderCfg.EnableJIT = false;
    
elseif strcmpi(objCoderCfg.Name, 'Embedded')
    objCoderCfg.EnableJIT = true;

end

objCoderCfg.MATLABSourceComments = true;
objCoderCfg.InstructionSetExtensions = 'None';

if options.bAutocodeForPlatformARM == true
    objCoderCfg.HardwareImplementation.ProdHWDeviceType = 'ARM Compatible->ARM 8'; % DEVNOTE: codegen uses production hardware as reference
end
objCoderCfg.EnableAutoParallelization = false;
objCoderCfg.EnableOpenMP = false;
objCoderCfg.TargetLangStandard = "C++11 (ISO)";

try
    objCoderCfg.UsePrecompiledLibraries = 'Avoid';
catch
    warning('Coder option: UsePrecompiledLibraries may not be available. This has been introduced in version R2024b.')
end

end

