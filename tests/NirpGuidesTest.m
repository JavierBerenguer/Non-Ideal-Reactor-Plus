classdef NirpGuidesTest < matlab.unittest.TestCase
    % NirpGuidesTest verifies the navigable user-guide pages and assets.
    % =====================================================================
    % Javier Berenguer Sabater
    % Created: October 17, 2026. Last update: October 22, 2026
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

        function localGuideLinksStayWithinTheirOwnSet(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            [pageSets, setNames] = guidePageSets(root) ;
            assetsRoot = canonicalPath(fullfile(root, 'docs', 'assets')) ;
            assetsPrefix = [assetsRoot filesep] ;
            for setIndex = 1:numel(pageSets)
                pages = pageSets{setIndex} ;
                allowedTargets = string(cellfun(@canonicalPath, pages, ...
                    'UniformOutput', false)) ;
                for pageIndex = 1:numel(pages)
                    page = pages{pageIndex} ;
                    html = fileread(page) ;
                    tokens = regexp(html, 'href="([^"]+)"', 'tokens', ...
                        'ignorecase') ;
                    for linkIndex = 1:numel(tokens)
                        reference = string(tokens{linkIndex}{1}) ;
                        if contains(reference, ':') || startsWith(reference, '//')
                            continue
                        end
                        parts = split(reference, '#') ;
                        relative = parts(1) ;
                        if strlength(relative) == 0
                            target = canonicalPath(page) ;
                        else
                            target = canonicalPath(fullfile(fileparts(page), ...
                                strrep(char(relative), '/', filesep))) ;
                        end
                        isAsset = strcmp(target, assetsRoot) || ...
                            startsWith(target, assetsPrefix) ;
                        testCase.verifyTrue(isAsset || ...
                            any(string(target) == allowedTargets), sprintf( ...
                            '%s page %s links outside its guide set: %s', ...
                            setNames(setIndex), page, reference)) ;
                    end
                end
            end
        end

        function legacyEntriesPointToTheirOwnGuides(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;

            idealLegacy = fileread(fullfile(root, 'docs', 'guides', ...
                'ideal-reactor-app.html')) ;
            flowLegacy = fileread(fullfile(root, 'docs', 'guides', ...
                'simulink-flowsheet.html')) ;
            testCase.verifySubstring(string(idealLegacy), '../IdealGuide.html') ;
            testCase.verifySubstring(string(flowLegacy), '../FlowsheetGuide.html') ;
        end

        function convolutionIsDocumentedAsTabSix(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            userGuide = string(fileread(fullfile(root, 'docs', 'UserGuide.html'))) ;
            convolutionPath = fullfile(root, 'docs', 'guides', ...
                'tab-6-convolution.html') ;
            convolutionGuide = string(fileread(convolutionPath)) ;
            tabOneGuide = string(fileread(fullfile(root, 'docs', 'guides', ...
                'tab-1-rtd-analysis.html'))) ;

            testCase.verifyTrue(isfile(convolutionPath)) ;
            testCase.verifyFalse(isfile(fullfile(root, 'docs', 'guides', ...
                'tab-convolution.html'))) ;
            testCase.verifySubstring(userGuide, ...
                'href="guides/tab-6-convolution.html"') ;
            testCase.verifySubstring(convolutionGuide, 'Tab 6 - Convolution') ;
            testCase.verifySubstring(convolutionGuide, ...
                'Previous: Tab 5 - Design &amp; Optimization') ;
            testCase.verifySubstring(tabOneGuide, 'RTD from Tab 6') ;
        end

        function convolutionGuideCoversFinalIndependentWorkflows(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            page = fullfile(root, 'docs', 'guides', ...
                'tab-6-convolution.html') ;
            html = string(fileread(page)) ;

            requiredAnchors = ["before-start", "signals", "convolution", ...
                "deconvolution", "regularization", "results", "reuse"] ;
            for anchor = requiredAnchors
                testCase.verifySubstring(html, "id=""" + anchor + """") ;
                testCase.verifySubstring(html, "href=""#" + anchor + """") ;
            end

            requiredTopics = ["SECT01", "SECT02", "Add row", ...
                "Remove row", "Import Experimental Data", "Display units", ...
                "&Delta;t<sub>common</sub>", "&tau;<sub>min</sub>", ...
                "&tau;<sub>max</sub>", "Tikhonov", "Auto (L-curve)", ...
                "Reconvolution check", "Relative residual", ...
                "Peclet number Pe", ...
                "Use C<sub>out</sub> as tracer response in Tab 1", ...
                "Use Ê(t) as RTD in Tab 1"] ;
            for topic = requiredTopics
                testCase.verifySubstring(html, topic) ;
            end

            expectedImages = ["tab6-convolution-sect01.png", ...
                "tab6-deconvolution-sect02.png", ...
                "tab6-tikhonov-lcurve-sect02.png"] ;
            imageSources = extractImageSources(html) ;
            for expectedImage = expectedImages
                testCase.verifyTrue(any(endsWith(imageSources, expectedImage)), ...
                    sprintf('Tab 6 guide does not use %s', expectedImage)) ;
            end
            testCase.verifyEqual(numel(unique(imageSources)), 3) ;

            localLinks = regexp(html, 'href="([^"]+)"', 'tokens') ;
            linkedTargets = string(cellfun(@(value) value{1}, localLinks, ...
                'UniformOutput', false)) ;
            testCase.verifyFalse(any(contains(linkedTargets, 'flowsheet'))) ;
        end

        function topicBreadcrumbsStartAtTheirOwnHome(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            cases = { ...
                'ideal-*.html', ['<div class="crumbs"><a ' ...
                    'href="../IdealGuide.html">Ideal Reactor App Guide</a>'] ; ...
                'flowsheet-*.html', ['<div class="crumbs"><a ' ...
                    'href="../FlowsheetGuide.html">Flowsheet Guide</a>']} ;
            for caseIndex = 1:size(cases, 1)
                pages = dir(fullfile(root, 'docs', 'guides', ...
                    cases{caseIndex, 1})) ;
                for pageIndex = 1:numel(pages)
                    page = fullfile(pages(pageIndex).folder, ...
                        pages(pageIndex).name) ;
                    html = string(fileread(page)) ;
                    if contains(html, 'class="crumbs"')
                        testCase.verifySubstring(html, cases{caseIndex, 2}, page) ;
                    end
                end
            end
        end

        function commonOpenerValidatesBeforeUsingTestOverride(testCase)
            openedPath = "" ;
            setappdata(groot, 'NirpGuideOpenOverride', @recordGuidePath) ;
            testCase.addTeardown(@() clearGuideOverride()) ;
            expected = "guides/flowsheet-reactors.html#pfr" ;
            openNirpGuide(expected) ;
            testCase.verifyEqual(openedPath, expected) ;
            testCase.verifyError(@() openNirpGuide('missing.html'), ...
                'openNirpGuide:MissingGuide') ;

            function recordGuidePath(relativePath)
                openedPath = string(relativePath) ;
            end
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
                exclusions = legacyLinkTextExclusions(legacyPath) ;
                fragments(ismember(fragments, exclusions)) = [] ;
                for fragment = fragments
                    testCase.verifySubstring(combined, fragment, sprintf( ...
                        'Legacy text from %s is missing: %s', legacyPath, fragment)) ;
                end
                legacyImages = extractImageSources(legacyHtml) ;
                legacyImages(ismember(legacyImages, ...
                    legacyImageExclusions(legacyPath))) = [] ;
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

function clearGuideOverride()
    if isappdata(groot, 'NirpGuideOpenOverride')
        rmappdata(groot, 'NirpGuideOpenOverride') ;
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

function [sets, names] = guidePageSets(root)
    docs = fullfile(root, 'docs') ;
    guides = fullfile(docs, 'guides') ;
    nonIdeal = {fullfile(docs, 'UserGuide.html'), ...
        fullfile(docs, 'TechnicalChapter.html')} ;
    nonIdeal = [nonIdeal, matchingPages(guides, 'tab-*.html'), ...
        matchingPages(guides, 'appendix-*.html')] ;
    ideal = [{fullfile(docs, 'IdealGuide.html')}, ...
        matchingPages(guides, 'ideal-*.html')] ;
    flowsheet = [{fullfile(docs, 'FlowsheetGuide.html')}, ...
        matchingPages(guides, 'flowsheet-*.html'), ...
        {fullfile(guides, 'simulink-flowsheet.html')}] ;
    sets = {nonIdeal, ideal, flowsheet} ;
    names = ["Non-ideal", "Ideal", "Flowsheet"] ;
end

function pages = matchingPages(folder, pattern)
    entries = dir(fullfile(folder, pattern)) ;
    pages = cell(1, numel(entries)) ;
    for index = 1:numel(entries)
        pages{index} = fullfile(entries(index).folder, entries(index).name) ;
    end
end

function path = canonicalPath(path)
    path = char(java.io.File(path).getCanonicalPath()) ;
end

function fragments = legacyLinkTextExclusions(relativePath)
    if relativePath == "docs/guides/ideal-reactor-app.html"
        fragments = ["Back to the general user guide", ...
            "Open this page directly from Ideal Reactor App guide in the new Guides group."] ;
    else
        fragments = strings(0) ;
    end
end

function images = legacyImageExclusions(relativePath)
    if relativePath == "docs/guides/ideal-reactor-app.html"
        images = "../assets/ideal/launcher-guides.png" ;
    else
        images = strings(0) ;
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
