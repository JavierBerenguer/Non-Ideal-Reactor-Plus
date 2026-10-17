classdef NirpConvolutionTabTest < matlab.unittest.TestCase
    % NirpConvolutionTabTest verifies the app integration of nirp.conv.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        App
        Figure
        Folder
        Root
    end

    methods (TestMethodSetup)
        function openHiddenApp(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            testCase.Root = fileparts(fileparts(mfilename('fullpath'))) ;
            testCase.App = NonIdealReactorApp() ;
            figures = findall(groot, 'Type', 'Figure', ...
                'Name', 'Non-Ideal Reactor Analysis') ;
            testCase.Figure = figures(1) ;
            testCase.Figure.Visible = 'off' ;
            testCase.addTeardown(@() closeFigures()) ;
        end
    end

    methods (Test)
        function tabExistsImmediatelyAfterRTD(testCase)
            group = findall(testCase.Figure, 'Type', 'uitabgroup') ;
            mainGroup = group(arrayfun(@(g) any(strcmp({g.Children.Title}, ...
                'RTD Analysis')), group)) ;
            titles = string({mainGroup(1).Children.Title}) ;
            rtdIndex = find(titles == "RTD Analysis", 1) ;
            convolutionIndex = find(titles == "Convolution", 1) ;
            testCase.verifyEqual(convolutionIndex, rtdIndex + 1) ;
        end

        function tableProblemThreeMatchesCore(testCase)
            Cin = [0:11; 0 0 8 6 4 5 6 3 1 0 0 0].' ;
            E = [0:5; 0 .05 .5 .35 .1 0].' ;
            testCase.control('ConvTableCin').Data = Cin ;
            testCase.control('ConvTableE').Data = E ;

            testCase.press('ConvCompute') ;

            expected = nirp.conv.convolve( ...
                nirp.conv.signal(E(:, 1), E(:, 2)), ...
                nirp.conv.signal(Cin(:, 1), Cin(:, 2))) ;
            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 1).', expected.t, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(result(:, 2).', expected.C, 'AbsTol', 1e-12) ;
        end

        function modelCstrAndCurrentRTDAreAvailable(testCase)
            testCase.control('ConvTableCin').Data = [0:10; ones(1, 11)].' ;
            testCase.setDropdown('ConvSourceE', 'Model') ;
            testCase.setDropdown('ConvModelE', 'CSTR') ;
            testCase.control('ConvTauE').Value = 5 ;
            testCase.press('ConvCompute') ;
            lines = findall(testCase.control('ConvAxes'), 'Type', 'Line') ;
            eLine = lines(strcmp({lines.DisplayName}, 'E')) ;
            expected = nirp.conv.fromRTD(RTD.ideal_cstr(5), 1) ;
            testCase.verifyEqual(eLine.YData, expected.C, 'AbsTol', 1e-12) ;

            testCase.App.loadSessionFromFile(fullfile(testCase.Root, 'saves', 'SE51.mat')) ;
            copiedSession = fullfile(testCase.Folder, 'se51-copy.mat') ;
            testCase.App.saveSessionToFile(copiedSession, 'se51-copy') ;
            stored = load(copiedSession, 'sessionData') ;
            expectedRTD = RTD(stored.sessionData.shared.rtd.t, ...
                stored.sessionData.shared.rtd.Et) ;
            testCase.control('ConvTableCin').Data = [0:10; ones(1, 11)].' ;
            testCase.setDropdown('ConvSourceE', 'RTD from tab 1') ;
            testCase.press('ConvCompute') ;
            lines = findall(testCase.control('ConvAxes'), 'Type', 'Line') ;
            eLine = lines(strcmp({lines.DisplayName}, 'E')) ;
            expected = nirp.conv.fromRTD(expectedRTD, 1) ;
            testCase.verifyEqual(eLine.XData, expected.t, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(eLine.YData, expected.C, 'AbsTol', 1e-12) ;
        end

        function deconvolutionFunctionMatchesCourseAndLoadsTabOne(testCase)
            testCase.configureCourseDeconvolution('min') ;

            testCase.press('ConvCompute') ;

            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 1).', 4:9, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(result(:, 2).', [1.79 2.33 2.58 0 1.24 0], ...
                'AbsTol', 2e-2) ;
            testCase.press('ConvUseAsRTD') ;
            saved = fullfile(testCase.Folder, 'deconvolved.mat') ;
            testCase.App.saveSessionToFile(saved, 'deconvolved') ;
            session = load(saved, 'sessionData') ;
            testCase.verifyEqual(session.sessionData.rtd.source, 'Tabular Input') ;
            testCase.verifyEqual(session.sessionData.shared.rtd.source, 'deconvolution') ;
            testCase.verifyEqual(session.sessionData.shared.rtd.t, (4:9) * 60, ...
                'AbsTol', 1e-12) ;
        end

        function momentsUseSelectedTimeUnit(testCase)
            testCase.configureCourseDeconvolution('min') ;
            testCase.press('ConvCompute') ;

            minuteTable = testCase.control('ConvMomentsTable') ;
            testCase.verifyEqual(minuteTable.ColumnName(:), ...
                {'Signal'; 'Area'; 'Mean [min]'; 'Variance [min^2]'}) ;
            minuteData = minuteTable.Data ;
            minuteCin = minuteData(strcmp(minuteData(:, 1), 'C_{in}'), 2:4) ;
            minuteE = minuteData(strcmp(minuteData(:, 1), 'E'), 2:4) ;
            tCin = (0:4) * 60 ;
            cin = nirp.conv.signal(tCin, (0:4) .* exp(-(0:4) / 2)) ;
            cout = nirp.conv.signal((4:13) * 60, ...
                [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]) ;
            [expectedE, expectedInfo] = nirp.conv.deconvolve(cin, cout) ;
            cinMoments = nirp.conv.moments(cin) ;
            eMoments = nirp.conv.moments(expectedE) ;
            testCase.verifyEqual([minuteCin{:}], ...
                [cinMoments.area / 60, cinMoments.mean / 60, ...
                cinMoments.variance / 60^2], 'RelTol', 1e-12) ;
            testCase.verifyEqual([minuteE{:}], ...
                [eMoments.area, eMoments.mean / 60, eMoments.variance / 60^2], ...
                'RelTol', 1e-12) ;
            testCase.verifyEqual(minuteE{2}, 5.8, 'AbsTol', 0.1) ;
            minuteDiagnostics = testCase.control('ConvDiagnostics').Text ;
            testCase.verifyEqual(expectedInfo.areaE, 7.95, 'AbsTol', 0.01) ;
            testCase.verifySubstring(minuteDiagnostics, ...
                sprintf('Integral E: %.6g', expectedInfo.areaE)) ;

            testCase.configureCourseDeconvolution('s') ;
            testCase.press('ConvCompute') ;

            secondTable = testCase.control('ConvMomentsTable') ;
            testCase.verifyEqual(secondTable.ColumnName(:), ...
                {'Signal'; 'Area'; 'Mean [s]'; 'Variance [s^2]'}) ;
            secondData = secondTable.Data ;
            secondCin = secondData(strcmp(secondData(:, 1), 'C_{in}'), 2:4) ;
            secondE = secondData(strcmp(secondData(:, 1), 'E'), 2:4) ;
            testCase.verifyEqual(secondCin{1}, minuteCin{1} * 60, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondCin{2}, minuteCin{2} * 60, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondCin{3}, minuteCin{3} * 60^2, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondE{1}, minuteE{1}, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondE{2}, minuteE{2} * 60, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondE{3}, minuteE{3} * 60^2, 'RelTol', 1e-12) ;
            testCase.verifyEqual(testCase.control('ConvDiagnostics').Text, ...
                minuteDiagnostics) ;
        end

        function oldSessionsLoadWithoutNewWarnings(testCase)
            files = dir(fullfile(testCase.Root, 'saves', 'SE*.mat')) ;
            testCase.verifyGreaterThanOrEqual(numel(files), 10) ;
            for k = 1:numel(files)
                lastwarn('') ;
                testCase.App.loadSessionFromFile(fullfile(files(k).folder, files(k).name)) ;
                [message, identifier] = lastwarn() ;
                testCase.verifyEmpty(message, files(k).name) ;
                testCase.verifyEmpty(identifier, files(k).name) ;
                testCase.verifyEmpty(testCase.control('ConvResultTable').Data) ;
            end
        end

        function convolutionStateRoundTrips(testCase)
            input = [0 0; 1 2; 2 0] ;
            testCase.control('ConvTableCin').Data = input ;
            testCase.setDropdown('ConvTimeUnit', 'min') ;
            testCase.control('ConvDt').Value = 0.25 ;
            saved = fullfile(testCase.Folder, 'convolution-session.mat') ;
            testCase.App.saveSessionToFile(saved, 'convolution-session') ;

            testCase.control('ConvTableCin').Data = cell(3, 2) ;
            testCase.setDropdown('ConvTimeUnit', 's') ;
            testCase.control('ConvDt').Value = 0 ;
            testCase.App.loadSessionFromFile(saved) ;

            testCase.verifyEqual(testCase.control('ConvTableCin').Data, input) ;
            testCase.verifyEqual(testCase.control('ConvTimeUnit').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvDt').Value, 0.25) ;
        end
    end

    methods (Access = private)
        function value = control(testCase, tag)
            values = findall(testCase.Figure, 'Tag', tag) ;
            testCase.assertNumElements(values, 1, ['Missing control: ' tag]) ;
            value = values(1) ;
        end

        function setDropdown(testCase, tag, value)
            dropdown = testCase.control(tag) ; dropdown.Value = value ;
            if ~isempty(dropdown.ValueChangedFcn)
                feval(dropdown.ValueChangedFcn, dropdown, []) ;
            end
        end

        function selectMode(testCase, label)
            group = testCase.control('ConvModeGroup') ;
            buttons = group.Children ;
            group.SelectedObject = buttons(strcmp({buttons.Text}, label)) ;
            if ~isempty(group.SelectionChangedFcn)
                feval(group.SelectionChangedFcn, group, []) ;
            end
        end

        function press(testCase, tag)
            button = testCase.control(tag) ;
            feval(button.ButtonPushedFcn, button, []) ; drawnow ;
        end

        function configureCourseDeconvolution(testCase, unit)
            testCase.selectMode('Deconvolution') ;
            testCase.setDropdown('ConvTimeUnit', unit) ;
            testCase.setDropdown('ConvSourceCin', 'Function') ;
            output = [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5].' ;
            if strcmp(unit, 'min')
                testCase.control('ConvFunctionCin').Value = 't.*exp(-t/2)' ;
                testCase.control('ConvFunctionStartCin').Value = 0 ;
                testCase.control('ConvFunctionEndCin').Value = 4 ;
                testCase.control('ConvFunctionStepCin').Value = 1 ;
                testCase.control('ConvTableCout').Data = [(4:13).', output] ;
            else
                testCase.control('ConvFunctionCin').Value = ...
                    '(t/60).*exp(-(t/60)/2)' ;
                testCase.control('ConvFunctionStartCin').Value = 0 ;
                testCase.control('ConvFunctionEndCin').Value = 240 ;
                testCase.control('ConvFunctionStepCin').Value = 60 ;
                testCase.control('ConvTableCout').Data = [(240:60:780).', output] ;
            end
        end
    end
end

function closeFigures()
    figures = findall(groot, 'Type', 'Figure') ;
    if ~isempty(figures), delete(figures) ; end
    evalin('base', 'clear convolutionResult') ;
end
