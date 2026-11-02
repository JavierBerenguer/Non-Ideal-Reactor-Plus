classdef NirpLauncherTest < matlab.uitest.TestCase
    % NirpLauncherTest verifies the main launcher and startup feedback.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 16, 2026. Last update: October 22, 2026
    % =========================================================================

    methods (TestMethodSetup)
        function prepareCleanDesktop(testCase)
            closeAllUi() ;
            testCase.addTeardown(@() closeAllUi()) ;
        end
    end

    methods (Test)
        function launcherShowsActionsAndCredits(testCase)
            launcher = NonIdealReactorPlus('Visible','off') ;
            testCase.addTeardown(@() deleteIfValid(launcher)) ;
            figureHandle = launcher.UIFigure ;
            buttons = findall(figureHandle, 'Type', 'uibutton') ;
            testCase.verifyEqual(sort(string({buttons.Text})), sort([ ...
                "Ideal Reactor App", "Non-Ideal Reactor App", ...
                "Open block library", "Open example...", ...
                "New flowsheet...", ...
                "Open block library", "Open example...", ...
                "New flowsheet..."])) ; % ideal and tracer flowsheet groups (T-191)
            panels = findall(figureHandle, 'Type', 'uipanel') ;
            testCase.verifyFalse(any(string({panels.Title}) == "Guides")) ;
            labels = findall(figureHandle, 'Type', 'uilabel') ;
            labelText = strings(0, 1) ;
            for i = 1:numel(labels)
                labelText = [labelText; string(labels(i).Text(:))] ; %#ok<AGROW>
            end
            testCase.verifyTrue(any(contains(labelText, 'Isabela Fons'))) ;
        end

    end

    methods (Test, TestTags = {'Interactive'})
        function nonIdealButtonKeepsLauncherIndependent(testCase)
            launcher = NonIdealReactorPlus() ;
            testCase.addTeardown(@() deleteIfValid(launcher)) ;
            testCase.press(button(launcher.UIFigure, 'Non-Ideal Reactor App')) ;
            drawnow ;
            mainFigure = findall(groot, 'Type', 'Figure', ...
                'Name', 'Non-Ideal Reactor Analysis') ;
            testCase.verifyNumElements(mainFigure, 1) ;
            testCase.verifyTrue(isvalid(launcher.UIFigure)) ;
            testCase.verifyTrue(all(string({findall(launcher.UIFigure, ...
                'Type', 'uibutton').Enable}) == "on")) ;
            delete(launcher) ;
            testCase.verifyTrue(isvalid(mainFigure)) ;
        end

        function nonIdealProgressIsOrderedAndAdvisory(testCase)
            fractions = zeros(0, 1) ;
            messages = strings(0, 1) ;
            figureExists = false(0, 1) ;
            figureVisibility = strings(0, 1) ;
            app = NonIdealReactorApp('ProgressFcn', @recordAndFail) ;
            testCase.addTeardown(@() deleteIfValid(app)) ;

            testCase.verifyEqual(numel(fractions), 8) ;
            testCase.verifyEqual(fractions, [[0:6] / 7 1].', ...
                'AbsTol', eps) ;
            testCase.verifyGreaterThanOrEqual(diff(fractions), 0) ;
            testCase.verifyTrue(all(figureExists)) ;
            testCase.verifyTrue(all(figureVisibility(1:7) == "off")) ;
            testCase.verifyEqual(figureVisibility(8), "on") ;
            testCase.verifyEqual(messages(8), "Ready") ;
            expectedSteps = ["RTD Analysis", "Prediction", ...
                "Tanks in Series", "Dispersion", ...
                "Design & Optimization", "Convolution", "Final layout"] ;
            for i = 1:numel(expectedSteps)
                testCase.verifySubstring(messages(i), expectedSteps(i)) ;
            end
            figureHandle = findall(groot, 'Type', 'Figure', ...
                'Name', 'Non-Ideal Reactor Analysis') ;
            testCase.verifyEqual(string(figureHandle.Visible), "on") ;

            function recordAndFail(fraction, message)
                fractions(end + 1, 1) = fraction ;
                messages(end + 1, 1) = string(message) ;
                figureHandle = findall(groot, 'Type', 'Figure', ...
                    'Name', 'Non-Ideal Reactor Analysis') ;
                figureExists(end + 1, 1) = ~isempty(figureHandle) ;
                if isempty(figureHandle)
                    figureVisibility(end + 1, 1) = "missing" ;
                else
                    figureVisibility(end + 1, 1) = string(figureHandle(1).Visible) ;
                end
                error('NirpLauncherTest:ProgressFailure', ...
                    'A progress callback failure is advisory.') ;
            end
        end

    end

    methods (Test)
        function directLaunchRemovesLoadingWindow(testCase)
            app = NonIdealReactorApp('Visible','off') ;
            testCase.addTeardown(@() deleteIfValid(app)) ;
            figures = findall(groot, 'Type', 'Figure') ;
            testCase.verifyFalse(any(startsWith(string({figures.Name}), ...
                'Loading'))) ;
        end

        function resizeEventsAreCoalescedAndApplyLastSize(testCase)
            app = NonIdealReactorApp('ProgressFcn', @(~,~) [], ...
                'Visible','off') ;
            testCase.addTeardown(@() deleteIfValid(app)) ;
            figureHandle = findall(groot, 'Type', 'Figure', ...
                'Name', 'Non-Ideal Reactor Analysis') ;
            tabGroup = findall(figureHandle, 'Type', 'uitabgroup') ;
            statusBar = findall(figureHandle, 'Type', 'uilabel', ...
                'Text', '  Ready') ;
            resizeFcn = figureHandle.SizeChangedFcn ;

            for i = 1:40
                figureHandle.Position(3:4) = [1200 + 10 * i, 750 + 5 * i] ;
                resizeFcn(figureHandle, []) ;
            end
            resizeTimers = timerfindall('Tag', ...
                'NonIdealReactorAppResizeTimer') ;
            testCase.verifyNumElements(resizeTimers, 1) ;

            testCase.verifyTrue(waitFor(@() ...
                isequal(tabGroup(1).Position, [0 22 1600 928]), 2)) ;
            testCase.verifyEqual(statusBar(1).Position, [0 0 1600 22]) ;
        end

    end

    methods (Test, TestTags = {'Interactive'})
        function idealButtonOpensOriginalApp(testCase)
            launcher = NonIdealReactorPlus() ;
            testCase.addTeardown(@() deleteIfValid(launcher)) ;
            testCase.press(button(launcher.UIFigure, 'Ideal Reactor App')) ;
            drawnow ;
            idealFigure = findall(groot, 'Type', 'Figure', 'Name', 'UI Figure') ;
            testCase.verifyNumElements(idealFigure, 1) ;
        end

        function idealHelpButtonOpensIdealGuide(testCase)
            openedPath = "" ;
            setappdata(groot, 'NirpGuideOpenOverride', @recordGuidePath) ;
            testCase.addTeardown(@() clearGuideOverride()) ;
            app = ReactorApp() ;
            testCase.addTeardown(@() deleteIfValid(app)) ;
            testCase.press(button(app.UIFigure, 'Help')) ;
            testCase.verifyEqual(openedPath, "IdealGuide.html") ;

            function recordGuidePath(relativePath)
                openedPath = string(relativePath) ;
            end
        end

    end

    methods (Test)
        function nonIdealUserGuideUsesCommonOpener(testCase)
            openedPath = "" ;
            setappdata(groot, 'NirpGuideOpenOverride', @recordGuidePath) ;
            testCase.addTeardown(@() clearGuideOverride()) ;
            app = NonIdealReactorApp('ProgressFcn', @(~,~) [], ...
                'Visible','off') ;
            testCase.addTeardown(@() deleteIfValid(app)) ;
            figureHandle = findall(groot, 'Type', 'Figure', ...
                'Name', 'Non-Ideal Reactor Analysis') ;
            userGuide = findall(figureHandle, 'Type', 'uimenu', ...
                'Text', 'User Guide') ;
            feval(userGuide.MenuSelectedFcn, userGuide, []) ;
            testCase.verifyEqual(openedPath, "UserGuide.html") ;

            function recordGuidePath(relativePath)
                openedPath = string(relativePath) ;
            end
        end

        function idealGuideUsesExistingImagesAndUserLanguage(testCase)
            rootDir = fileparts(fileparts(mfilename('fullpath'))) ;
            guidePath = fullfile(rootDir, 'docs', 'IdealGuide.html') ;
            testCase.verifyTrue(isfile(guidePath)) ;
            guideText = fileread(guidePath) ;
            imageTokens = regexp(guideText, ...
                '<img[^>]+src="([^"]+)"', 'tokens') ;
            testCase.verifyNotEmpty(imageTokens) ;
            guideDir = fileparts(guidePath) ;
            for i = 1:numel(imageTokens)
                imagePath = fullfile(guideDir, imageTokens{i}{1}) ;
                testCase.verifyTrue(isfile(imagePath), imagePath) ;
            end

            testCase.verifyNotEmpty(strfind(guideText, ...
                ['ReactorApp was developed by Isabela Fons ' ...
                '(University of Alicante)'])) ; %#ok<STREMP>
            textWithoutRequiredCredit = strrep(guideText, ...
                'ReactorApp was developed by Isabela Fons', ...
                'The original ideal-reactor application was developed') ;
            forbiddenNames = {'ReactorApp', 'defineReactionSysApp', ...
                'defineStreamApp', 'defineReactorApp', ...
                'dialogHysysStreamApp', 'UtilitiesApp', ...
                'unitConverterApp'} ;
            for i = 1:numel(forbiddenNames)
                testCase.verifyEmpty(strfind(textWithoutRequiredCredit, ...
                    forbiddenNames{i})) ; %#ok<STREMP>
            end
            testCase.verifyEmpty(strfind(guideText, 'nirp.')) ; %#ok<STREMP>
            testCase.verifyEmpty(strfind(guideText, '.m"')) ; %#ok<STREMP>
            testCase.verifyEmpty(strfind(guideText, '()')) ; %#ok<STREMP>
            testCase.verifyEmpty(strfind(guideText, 'data:image')) ; %#ok<STREMP>
        end

    end

    methods (Test, TestTags = {'Interactive'})
        function libraryButtonLoadsLibrary(testCase)
            launcher = NonIdealReactorPlus() ;
            testCase.addTeardown(@() deleteIfValid(launcher)) ;
            testCase.press(button(launcher.UIFigure, 'Open block library')) ;
            drawnow ;
            testCase.verifyTrue(bdIsLoaded('NirpLibrary')) ;
        end

        function failedActionAlertsAndRestoresButtons(testCase)
            launcher = NonIdealReactorPlus() ;
            testCase.addTeardown(@() deleteIfValid(launcher)) ;
            launcher.TestActionOverrides.Ideal = @failAction ;
            testCase.press(button(launcher.UIFigure, 'Ideal Reactor App')) ;
            drawnow ;
            testCase.dismissAlertDialog(launcher.UIFigure) ;
            buttons = findall(launcher.UIFigure, 'Type', 'uibutton') ;
            testCase.verifyTrue(all(string({buttons.Enable}) == "on")) ;
        end
    end
end

function value = waitFor(predicate, timeout)
    started = tic ;
    value = predicate() ;
    while ~value && toc(started) < timeout
        pause(0.02) ;
        drawnow ;
        value = predicate() ;
    end
end

function value = button(figureHandle, text)
    values = findall(figureHandle, 'Type', 'uibutton', 'Text', text) ;
    value = values(1) ;
end

function failAction()
    error('NirpLauncherTest:SyntheticFailure', ...
        'Synthetic launcher failure.') ;
end

function closeAllUi()
    clearGuideOverride() ;
    bdclose('all') ;
    figures = findall(groot, 'Type', 'Figure') ;
    if ~isempty(figures), delete(figures) ; end
    resizeTimers = timerfindall('Tag', 'NonIdealReactorAppResizeTimer') ;
    if ~isempty(resizeTimers), stop(resizeTimers) ; delete(resizeTimers) ; end
end

function clearGuideOverride()
    if isappdata(groot, 'NirpGuideOpenOverride')
        rmappdata(groot, 'NirpGuideOpenOverride') ;
    end
end

function deleteIfValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
