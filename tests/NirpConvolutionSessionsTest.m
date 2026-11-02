classdef NirpConvolutionSessionsTest < matlab.unittest.TestCase
    % NirpConvolutionSessionsTest verifies the saved convolution examples.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 21, 2026. Last update: October 22, 2026
    % =========================================================================

    properties
        App
        Figure
        Root
    end

    methods (TestMethodSetup)
        function openApp(testCase)
            testCase.Root = fileparts(fileparts(mfilename('fullpath'))) ;
            testCase.App = NonIdealReactorApp('ProgressFcn',@(~,~) [], ...
                'Visible','off') ;
            figures = findall(groot, 'Type', 'Figure', ...
                'Name', 'Non-Ideal Reactor Analysis') ;
            testCase.Figure = figures(1) ;
            testCase.Figure.Visible = 'off' ;
            testCase.addTeardown(@() closeFigures()) ;
        end
    end

    methods (Test)
        function savedSessionsLoadAndComputeTheirReferences(testCase)
            names = ["SECT01" "SECT02" "SECT03" ...
                "SEC02" "SEC03" "SEC04" "SEC05" "SEC06" ...
                "SEC07" "SEC08" "SEC09"] ;
            for k = 1:numel(names)
                file = fullfile(testCase.Root, 'saves', names(k) + ".mat") ;
                testCase.assertTrue(isfile(file), char(names(k))) ;
                saved = load(file, 'sessionData') ;
                reference = saved.sessionData.convolution.referenceTable ;

                testCase.App.loadSessionFromFile(file) ;
                drawnow ;
                testCase.verifyEqual(testCase.mainTabs().SelectedTab.Title, ...
                    'Convolution', char(names(k))) ;
                compute = testCase.control('ConvCompute') ;
                feval(compute.ButtonPushedFcn,compute,[]) ;
                drawnow ;

                actual = testCase.control('ConvResultTable').Data ;
                tolerance = 1e-9 * max(1, max(abs(reference), [], 'all')) ;
                testCase.verifyEqual(actual, reference, 'AbsTol', tolerance, ...
                    char(names(k))) ;
            end
        end
    end

    methods (Access = private)
        function control = control(testCase, tag)
            control = findall(testCase.Figure, 'Tag', tag) ;
            testCase.assertNumElements(control, 1, tag) ;
            control = control(1) ;
        end

        function group = mainTabs(testCase)
            groups = findall(testCase.Figure, 'Type', 'uitabgroup') ;
            selected = arrayfun(@(g) any(strcmp({g.Children.Title}, ...
                'RTD Analysis')), groups) ;
            group = groups(selected) ;
            testCase.assertNumElements(group, 1) ;
        end
    end
end

function closeFigures()
figures = findall(groot, 'Type', 'Figure') ;
if ~isempty(figures)
    delete(figures) ;
end
end
