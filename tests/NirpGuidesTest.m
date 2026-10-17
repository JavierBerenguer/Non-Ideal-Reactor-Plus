classdef NirpGuidesTest < matlab.unittest.TestCase
    % NirpGuidesTest verifies the navigable user-guide pages and assets.
    % =====================================================================
    % Javier Berenguer Sabater
    % Created: October 17, 2026. Last update: October 17, 2026
    % =====================================================================

    methods (Test)
        function allNewPagesUseValidLocalLinksAndUserLanguage(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            pages = guidePages(root) ;
            for index = 1:numel(pages)
                page = pages{index} ;
                html = fileread(page) ;
                testCase.verifySubstring(string(html), 'guide.css', page) ;
                forbidden = ["nirp.", string('.m"'), "data:image"] ;
                for token = forbidden
                    testCase.verifyFalse(contains(string(html), token), ...
                        sprintf('%s contains forbidden text: %s', page, token)) ;
                end
                verifyReferences(testCase, page, html) ;
            end
        end

        function blockPagesContainDialogImages(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            names = ["flowsheet-streams.html", "flowsheet-reactors.html", ...
                "flowsheet-units.html", "flowsheet-recycle-adjust.html"] ;
            for name = names
                page = fullfile(root, 'docs', 'guides', name) ;
                html = fileread(page) ;
                testCase.verifyNotEmpty(regexp(html, ...
                    '<img[^>]+src="[^"]+"', 'once'), char(name)) ;
            end
        end

        function requiredFlowsheetAnchorsExist(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            expected = { ...
                'flowsheet-streams.html', 'stream' ; ...
                'flowsheet-reactors.html', 'cstr' ; ...
                'flowsheet-reactors.html', 'pfr' ; ...
                'flowsheet-reactors.html', 'jacket' ; ...
                'flowsheet-units.html', 'mixer' ; ...
                'flowsheet-units.html', 'splitter' ; ...
                'flowsheet-units.html', 'separator' ; ...
                'flowsheet-units.html', 'heater' ; ...
                'flowsheet-recycle-adjust.html', 'recycle' ; ...
                'flowsheet-recycle-adjust.html', 'adjust'} ;
            for index = 1:size(expected, 1)
                page = fullfile(root, 'docs', 'guides', expected{index, 1}) ;
                html = fileread(page) ;
                expression = ['id="' expected{index, 2} '"'] ;
                testCase.verifySubstring(string(html), expression, ...
                    sprintf('Missing #%s in %s', expected{index, 2}, page)) ;
            end
        end

        function homesAndLegacyEntriesPointToNewGuides(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            index = fileread(fullfile(root, 'docs', 'UserGuide.html')) ;
            testCase.verifySubstring(string(index), 'href="IdealGuide.html"') ;
            testCase.verifySubstring(string(index), 'href="FlowsheetGuide.html"') ;

            idealLegacy = fileread(fullfile(root, 'docs', 'guides', ...
                'ideal-reactor-app.html')) ;
            flowLegacy = fileread(fullfile(root, 'docs', 'guides', ...
                'simulink-flowsheet.html')) ;
            testCase.verifySubstring(string(idealLegacy), '../IdealGuide.html') ;
            testCase.verifySubstring(string(flowLegacy), '../FlowsheetGuide.html') ;
        end

        function legacyGuideContentIsPreserved(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            pages = guidePages(root) ;
            combined = "" ;
            imageSources = strings(0) ;
            for index = 1:numel(pages)
                html = fileread(pages{index}) ;
                combined = combined + " " + normalizeVisibleText(html) ;
                imageSources = [imageSources; extractImageSources(html)] ; %#ok<AGROW>
            end

            legacyPaths = ["docs/guides/ideal-reactor-app.html", ...
                "docs/guides/simulink-flowsheet.html"] ;
            for legacyPath = legacyPaths
                legacyHtml = readBaseGuide(root, legacyPath) ;
                fragments = extractVisibleFragments(legacyHtml) ;
                for fragment = fragments
                    testCase.verifySubstring(combined, fragment, sprintf( ...
                        'Legacy text from %s is missing: %s', legacyPath, fragment)) ;
                end
                legacyImages = extractImageSources(legacyHtml) ;
                for image = legacyImages'
                    testCase.verifyTrue(any(imageSources == image), sprintf( ...
                        'Legacy image from %s is missing: %s', legacyPath, image)) ;
                end
            end
        end

        function topicPagesHaveCompleteNavigationAndStructure(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            names = ["ideal-main-window.html", "ideal-reactive-system.html", ...
                "ideal-streams.html", "ideal-reactors.html", ...
                "ideal-optimization.html", "ideal-utilities.html", ...
                "ideal-worked-example.html", "flowsheet-getting-started.html", ...
                "flowsheet-reactive-system.html", "flowsheet-streams.html", ...
                "flowsheet-reactors.html", "flowsheet-units.html", ...
                "flowsheet-recycle-adjust.html", "flowsheet-specifications.html", ...
                "flowsheet-running-results.html", "flowsheet-examples.html"] ;
            required = ["hero-grid", "aside class=""toc""", ...
                "Before You Start", "Previous", "Next"] ;
            for name = names
                page = fullfile(root, 'docs', 'guides', name) ;
                html = string(fileread(page)) ;
                for token = required
                    testCase.verifySubstring(html, token, sprintf( ...
                        '%s is missing required topic structure: %s', page, token)) ;
                end
            end
        end
    end
end

function html = readBaseGuide(root, relativePath)
    baseCommit = '67da22c' ;
    command = sprintf('git -C "%s" show %s:%s', root, baseCommit, relativePath) ;
    [status, html] = system(command) ;
    assert(status == 0, 'NirpGuidesTest:BaseGuideUnavailable', ...
        'Could not read %s from base commit %s. Git said: %s', ...
        relativePath, baseCommit, html) ;
end

function fragments = extractVisibleFragments(html)
    matches = regexp(html, ...
        '(?s)<(?:p|li|td|figcaption)\b[^>]*>(.*?)</(?:p|li|td|figcaption)>', ...
        'tokens', 'ignorecase') ;
    fragments = strings(1, numel(matches)) ;
    for index = 1:numel(matches)
        fragments(index) = normalizeVisibleText(matches{index}{1}) ;
    end
    fragments(fragments == "") = [] ;
end

function text = normalizeVisibleText(html)
    text = regexprep(string(html), '<[^>]+>', ' ') ;
    text = strtrim(regexprep(text, '\s+', ' ')) ;
end

function sources = extractImageSources(html)
    matches = regexp(html, '<img[^>]+src="([^"]+)"', 'tokens', 'ignorecase') ;
    sources = strings(numel(matches), 1) ;
    for index = 1:numel(matches)
        sources(index) = string(matches{index}{1}) ;
    end
end

function pages = guidePages(root)
    guides = dir(fullfile(root, 'docs', 'guides', 'ideal-*.html')) ;
    guides = [guides; dir(fullfile(root, 'docs', 'guides', ...
        'flowsheet-*.html'))] ;
    pages = {fullfile(root, 'docs', 'IdealGuide.html'), ...
        fullfile(root, 'docs', 'FlowsheetGuide.html')} ;
    for index = 1:numel(guides)
        pages{end + 1} = fullfile(guides(index).folder, ...
            guides(index).name) ; %#ok<AGROW>
    end
end

function verifyReferences(testCase, page, html)
    tokens = regexp(html, '(?:href|src)="([^"]+)"', 'tokens') ;
    for index = 1:numel(tokens)
        reference = string(tokens{index}{1}) ;
        if contains(reference, ':')
            continue
        end
        parts = split(reference, '#') ;
        relative = parts(1) ;
        if strlength(relative) == 0
            target = page ;
        else
            target = fullfile(fileparts(page), ...
                strrep(char(relative), '/', filesep)) ;
        end
        testCase.verifyTrue(isfile(target), sprintf( ...
            'Missing local resource %s linked from %s', target, page)) ;
        if numel(parts) > 1 && strlength(parts(2)) > 0 && isfile(target)
            targetHtml = fileread(target) ;
            expression = ['id="' char(parts(2)) '"'] ;
            testCase.verifySubstring(string(targetHtml), expression, ...
                sprintf('Missing anchor #%s in %s', parts(2), target)) ;
        end
    end
end
