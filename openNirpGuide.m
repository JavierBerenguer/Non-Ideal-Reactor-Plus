function openNirpGuide(relativePath)
% openNirpGuide Open a NIRP HTML guide from the docs directory.
%   openNirpGuide(RELATIVEPATH) accepts a path relative to docs, optionally
%   followed by an HTML anchor (for example, "guides/page.html#section"), in a
%   window of its own.
%
%   Tests can avoid opening the guide window by setting the root-appdata entry
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

    % A window of its own, like the former help windows. The viewer in docs/ shows the page in a frame,
    % so pages in docs/guides can still load docs/assets (uihtml only reads its own folder tree).
    viewerPath = fullfile(docsDirectory, 'GuideViewer.html') ;
    try
        guideFigure = uifigure('Name', 'Non-Ideal Reactor Plus - Guide', ...
            'Position', [120 60 1100 780], 'Resize', 'on') ;
        guideGrid = uigridlayout(guideFigure, [1 1], 'Padding', [0 0 0 0]) ;
        uihtml(guideGrid, 'HTMLSource', viewerPath, 'Data', char(relativePath)) ;
    catch windowException
        try
            web(guidePath, '-browser') ;
        catch systemBrowserException
            windowException = addCause(windowException, systemBrowserException) ;
            rethrow(windowException) ;
        end
    end
end
