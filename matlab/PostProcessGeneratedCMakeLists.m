function [] = PostProcessGeneratedCMakeLists(charTargetFolder, kwargs)
arguments
    charTargetFolder
end
arguments
    kwargs.bPrepareAsStandaloneBuild (1,1) {islogical} = true
end

% TODO operations
% 1) Remove set(MATLAB_ROOT)
% 2) Remove BUILD_INTERFACE and INSTALL_INTERFACE with hardcoded paths
% 3) For non standalone builds: remove project setup, leaving only add_library

if not(isunix)
    warning('This function is not supported on non-Unix systems.')
    return
end

% Common post-processing
if kwargs.bPrepareAsStandaloneBuild

    return
end

% Remove all commands not necessary for standalone builds

end

