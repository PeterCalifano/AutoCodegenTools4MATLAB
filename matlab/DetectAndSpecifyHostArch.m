function [objCoderConfig] = DetectAndSpecifyHostArch(objCoderConfig)
arguments
    objCoderConfig (1,1) {mustBeA(objCoderConfig, ["coder.EmbeddedCodeConfig", ...
                              "coder.CodeConfig", "coder.MexCodeConfig"])}
end

try
    if strcmpi(objCoderConfig.ProdHWDeviceType, 'Generic->MATLAB Host Computer')
        arch = computer('arch');
    
        fprintf('\nFound architecture: %s\n', string(arch));
        bHasChanged = true;
        
        % Choose explicit hardware type
        if contains(arch, 'glnxa64', 'ignorecase', true)
            objCoderConfig.ProdHWDeviceType = 'Intel->x86-64 (Linux 64)';

        elseif contains(arch, 'win64', 'ignorecase', true)
            objCoderConfig.ProdHWDeviceType = 'Intel->x86-64 (Windows64)';
        
        elseif contains(arch, 'maci64', 'ignorecase', true)
            objCoderConfig.ProdHWDeviceType = 'Intel->x86-64 (Mac OS X)';
        
        elseif contains(arch, 'maca64', 'ignorecase', true)
            % Apple Silicon → stay generic since ARM target differs
            objCoderConfig.ProdHWDeviceType = 'Generic->MATLAB Host Computer';
            warning('Apple Silicon detected. Keeping Generic target.');

        else
            objCoderConfig.ProdHWDeviceType = 'Generic->MATLAB Host Computer';
            bHasChanged = false;
        end
    
        if bHasChanged
            fprintf('Hardware setting changed: Generic->MATLAB Host Computer --> %s\n', string(objCoderConfig.ProdHWDeviceType));
        end
    end

catch ME
    warning('Failed to set HardwareImplementation: %s', string(ME.message) );
end


end
