function openNirpGuide(relativePath)
% openNirpGuide Open a NIRP HTML guide from the docs directory.
%   openNirpGuide(RELATIVEPATH) accepts a path relative to docs, optionally
%   followed by an HTML anchor (for example, "guides/page.html#section").
%
%   Tests can avoid opening a browser by setting the root-appdata entry
%   NirpGuideOpenOverride to a function handle. The handle is called with
%   the validated relative path, including its anchor. Tests must remove
%   the appdata entry during teardown.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 17, 2026. Last update: October 17, 2026
% =========================================================================

    arguments
        relativePath (1, 1) string
    end

    pathParts = split(relativePath, '#') ;
    guideRelativePath = pathParts(1) ;
    if strlength(guideRelativePath) == 0
        error('openNirpGuide:MissingGuide', ...
            'A guide path relative to the docs directory is required.') ;
    end

    docsDirectory = fullfile(fileparts(mfilename('fullpath')), 'docs') ;
    guidePath = fullfile(docsDirectory, ...
        strrep(char(guideRelativePath), '/', filesep)) ;
    if ~isfile(guidePath)
        error('openNirpGuide:MissingGuide', ...
            'Guide file not found: %s', guidePath) ;
    end

    overrideName = 'NirpGuideOpenOverride' ;
    if isappdata(groot, overrideName)
        override = getappdata(groot, overrideName) ;
        if ~isa(override, 'function_handle')
            error('openNirpGuide:InvalidOverride', ...
                'The test guide opener override must be a function handle.') ;
        end
        override(relativePath) ;
        return
    end

    guideLocation = string(guidePath) ;
    if numel(pathParts) > 1
        guideLocation = guideLocation + "#" + strjoin(pathParts(2:end), '#') ;
    end
    try
        web(char(guideLocation)) ;
    catch matlabBrowserException
        try
            web(char(guideLocation), '-browser') ;
        catch systemBrowserException
            matlabBrowserException = addCause( ...
                matlabBrowserException, systemBrowserException) ;
            rethrow(matlabBrowserException) ;
        end
    end
end
