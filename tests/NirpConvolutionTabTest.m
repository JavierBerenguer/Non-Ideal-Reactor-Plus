classdef NirpConvolutionTabTest < matlab.uitest.TestCase
    % NirpConvolutionTabTest verifies the app integration of nirp.conv.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 21, 2026
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
            testCase.Figure.Visible = 'on' ;
            testCase.addTeardown(@() closeFigures()) ;
        end
    end

    methods (Test)
        function tabIsSixthAfterDesignWorkspace(testCase)
            group = findall(testCase.Figure, 'Type', 'uitabgroup') ;
            mainGroup = group(arrayfun(@(g) any(strcmp({g.Children.Title}, ...
                'RTD Analysis')), group)) ;
            titles = string({mainGroup(1).Children.Title}) ;
            convolutionIndex = find(titles == "Convolution", 1) ;
            designIndex = find(titles == "Design & Optimization", 1) ;
            testCase.verifyEqual(titles, ["RTD Analysis", "Prediction Models", ...
                "Tanks-in-Series", "Dispersion Model", ...
                "Design & Optimization", "Convolution"]) ;
            testCase.verifyEqual(convolutionIndex, designIndex + 1) ;
        end

        function activeConvolutionTabRoundTripsByTitle(testCase)
            group = findall(testCase.Figure, 'Type', 'uitabgroup') ;
            mainGroup = group(arrayfun(@(g) any(strcmp({g.Children.Title}, ...
                'RTD Analysis')), group)) ;
            convolutionTab = mainGroup(1).Children(strcmp( ...
                {mainGroup(1).Children.Title}, 'Convolution')) ;
            mainGroup(1).SelectedTab = convolutionTab ;
            saved = fullfile(testCase.Folder, 'active-tab.mat') ;
            testCase.App.saveSessionToFile(saved, 'active-tab') ;
            mainGroup(1).SelectedTab = mainGroup(1).Children(1) ;

            testCase.App.loadSessionFromFile(saved) ;

            testCase.verifyEqual(mainGroup(1).SelectedTab.Title, 'Convolution') ;
        end

        function manualTableUsesAvailableEditorHeight(testCase)
            tableControl = testCase.control('ConvTableCin') ;
            testCase.verifyEqual(tableControl.Parent.RowHeight{4}, '1x') ;
            testCase.verifyEqual(tableControl.Layout.Row, 4) ;
        end

        function functionButtonsMatchTablePositionBelowEditor(testCase)
            tableControl = testCase.control('ConvTableCin') ;
            addButton = testCase.control('ConvAddRowCin') ;
            buttonsGrid = addButton.Parent ;
            testCase.verifyEqual(tableControl.Layout.Row, 4) ;
            testCase.verifyEqual(buttonsGrid.Layout.Row, 5) ;
            drawnow ;
            tableButtonPosition = buttonsGrid.Position ;

            testCase.choose(testCase.control('ConvSourceCin'), 'Function') ;
            functionTable = testCase.control('ConvFunctionTableCin') ;
            functionGrid = functionTable.Parent ;
            drawnow ;

            testCase.verifyEqual(functionGrid.Layout.Row, 4) ;
            testCase.verifyEqual(buttonsGrid.Layout.Row, 5) ;
            testCase.verifyEqual(buttonsGrid.Position, tableButtonPosition, 'AbsTol', 1) ;
            testCase.verifyGreaterThan(functionGrid.Position(2), buttonsGrid.Position(2)) ;
        end

        function modeShowsOnlyItsDescriptiveSignalTabs(testCase)
            tabs = testCase.control('ConvSignalTabs') ;
            testCase.verifyEqual(sort(string({tabs.Children.Title})), ...
                sort(["Inlet signal Cᵢₙ(t)", "RTD E(t)"])) ;
            testCase.verifyEqual(char(testCase.control('ConvVerificationAxes').Visible), 'off') ;
            testCase.verifyEqual(char(testCase.control('ConvUseAsRTD').Visible), 'off') ;

            testCase.selectMode('Deconvolution') ;
            testCase.verifyEqual(sort(string({tabs.Children.Title})), ...
                sort(["Inlet signal Cᵢₙ(t)", "Outlet signal Cₒᵤₜ(t)"])) ;
            testCase.verifyEqual(char(testCase.control('ConvVerificationAxes').Visible), 'on') ;
            testCase.verifyEqual(char(testCase.control('ConvUseAsRTD').Visible), 'on') ;
            testCase.verifyEqual(char(testCase.control('ConvUseAsRTD').Enable), 'off') ;

            testCase.selectMode('Series composition') ;
            testCase.verifyEqual(sort(string({tabs.Children.Title})), ...
                sort(["RTD vessel 1 E₁(t)", "RTD vessel 2 E₂(t)"])) ;
            testCase.verifyEqual(char(testCase.control('ConvVerificationAxes').Visible), 'off') ;
            testCase.verifyEqual(char(testCase.control('ConvUseAsRTD').Visible), 'off') ;
            saved = fullfile(testCase.Folder, 'series-active-signals.mat') ;
            testCase.App.saveSessionToFile(saved, 'series-active-signals') ;
            stored = load(saved, 'sessionData') ;
            testCase.verifyEqual(sort(string(fieldnames( ...
                stored.sessionData.convolution.signals))), sort(["E1"; "E2"])) ;
        end

        function supportedTextUsesLatex(testCase)
            testCase.verifyEqual(testCase.control('ConvDescriptionCin').Interpreter, 'latex') ;
            testCase.verifySubstring(testCase.control('ConvDescriptionCin').Text, ...
                'C_{\mathrm{in}}(t)') ;
            axesControl = testCase.control('ConvAxes') ;
            testCase.verifyEqual(axesControl.XLabel.Interpreter, 'latex') ;
            testCase.verifyEqual(axesControl.YLabel.Interpreter, 'latex') ;
            testCase.verifyEqual(axesControl.Title.Interpreter, 'latex') ;
            testCase.verifyEqual(testCase.control('ConvDiagnostics').Interpreter, 'latex') ;
        end

        function functionIsTheOnlyExpressionSource(testCase)
            source = testCase.control('ConvSourceCin') ;
            testCase.verifyEqual(string(source.Items), ["Table" "Function"]) ;
            testCase.verifyFalse(any(string(source.Items) == "Piecewise")) ;
            testCase.verifyEmpty(findall(testCase.Figure, 'Tag', 'ConvFunctionCin')) ;
            testCase.verifyEmpty(findall(testCase.Figure, 'Tag', 'ConvFunctionStartCin')) ;
            testCase.verifyEmpty(findall(testCase.Figure, 'Tag', 'ConvFunctionEndCin')) ;
            testCase.verifyEmpty(findall(testCase.Figure, 'Tag', 'ConvFunctionStepCin')) ;
            testCase.choose(source, 'Function') ;
            description = testCase.control('ConvFunctionDescriptionCin') ;
            testCase.verifySubstring(description.Tooltip, 'one or more intervals') ;
            testCase.verifyEqual(char(testCase.control('ConvFunctionTableCin').Visible), 'on') ;
        end

        function oneIntervalFunctionUsesCommonStep(testCase)
            testCase.setDropdown('ConvSourceCin', 'Function') ;
            testCase.control('ConvFunctionTableCin').Data = {0 2 't'} ;
            testCase.control('ConvTableE').Data = [0 0; 1 1; 2 0] ;
            testCase.control('ConvDt').Value = 1 ;

            testCase.press(testCase.control('ConvCompute')) ;

            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 1).', 0:4, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(result(:, 2).', [0 0 1 2 0], 'AbsTol', 1e-12) ;
        end

        function twoIntervalFunctionUsesEveryExpression(testCase)
            testCase.setDropdown('ConvSourceCin', 'Function') ;
            testCase.control('ConvFunctionTableCin').Data = ...
                {0 1 't'; 1 2 '2.*t'} ;
            testCase.control('ConvTableE').Data = [0 0; 1 1; 2 0] ;
            testCase.control('ConvDt').Value = 1 ;

            testCase.press(testCase.control('ConvCompute')) ;

            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 1).', 0:4, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(result(:, 2).', [0 0 2 4 0], 'AbsTol', 1e-12) ;
        end

        function automaticStepUsesTableBeforeBuildingFunction(testCase)
            testCase.selectMode('Deconvolution') ;
            testCase.setDropdown('ConvSourceCin', 'Function') ;
            testCase.control('ConvFunctionTableCin').Data = ...
                {4 13 't.*exp(-t./2)'} ;
            testCase.control('ConvTableCout').Data = ...
                [(4:13).', [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5].'] ;
            testCase.control('ConvDt').Value = 1 ;
            testCase.press(testCase.control('ConvCompute')) ;
            expected = testCase.control('ConvResultTable').Data ;

            testCase.control('ConvDt').Value = 0 ;
            testCase.press(testCase.control('ConvCompute')) ;

            actual = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(actual, expected, 'AbsTol', 1e-12) ;
        end

        function automaticStepDefaultsAcrossFunctionDomain(testCase)
            testCase.setDropdown('ConvSourceCin', 'Function') ;
            testCase.setDropdown('ConvSourceE', 'Function') ;
            testCase.control('ConvFunctionTableCin').Data = {0 2 '1'} ;
            testCase.control('ConvFunctionTableE').Data = {0 2 'exp(-t)'} ;
            testCase.control('ConvDt').Value = 0 ;

            testCase.press(testCase.control('ConvCompute')) ;

            testCase.verifyNotEmpty(testCase.control('ConvResultTable').Data) ;
            labels = findall(testCase.Figure, 'Type', 'uilabel') ;
            testCase.verifyTrue(any(contains(string({labels.Text}), ...
                'automatic default dt'))) ;
        end

        function topicExampleOneUsesAddedTableRows(testCase)
            Cin = [0:4; 0 8 4 6 0].' ;
            E = [2:6; 0 .05 .5 .35 0].' ;
            testCase.press(testCase.control('ConvAddRowCin')) ;
            testCase.press(testCase.control('ConvAddRowCin')) ;
            testCase.press(testCase.control('ConvAddRowE')) ;
            testCase.press(testCase.control('ConvAddRowE')) ;
            testCase.typeTable('ConvTableCin', Cin) ;
            testCase.typeTable('ConvTableE', E) ;

            cinData = testCase.asCells(testCase.control('ConvTableCin').Data) ;
            eData = testCase.asCells(testCase.control('ConvTableE').Data) ;
            testCase.verifyTrue(all(cellfun( ...
                @(value) isnumeric(value) && isscalar(value), cinData), 'all')) ;
            testCase.verifyTrue(all(cellfun( ...
                @(value) isnumeric(value) && isscalar(value), eData), 'all')) ;
            testCase.verifyEqual(cell2mat(cinData), Cin) ;
            testCase.verifyEqual(cell2mat(eData), E) ;

            testCase.press(testCase.control('ConvCompute')) ;

            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 1).', 2:10, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(result(:, 2).', ...
                [0 0 .4 4.2 5.1 4.4 2.1 0 0], 'AbsTol', 1e-12) ;
            resultsText = testCase.control('ConvResultValue1').Text ;
            testCase.verifySubstring(resultsText, ...
                '[0,\;0,\;0.4,\;4.2,\;5.1,\;4.4,\;2.1,\;0,\;0]') ;
            testCase.verifySubstring(resultsText, '\mathrm{mol/m^3}') ;
            testCase.verifyEqual(testCase.control('ConvResultTable').ColumnName{2}, ...
                'Cₒᵤₜ(t) [mol/m^3]') ;
            testCase.verifyEqual(char(testCase.control('ConvDiagnostics').Visible), 'off') ;

            axesControl = testCase.control('ConvAxes') ;
            meanLines = findall(axesControl, 'Type', 'ConstantLine') ;
            testCase.verifyNumElements(meanLines, 3) ;
            testCase.verifyEqual(sort([meanLines.Value]), ...
                sort([1.8889 4.3333 6.2222]), 'AbsTol', 5e-5) ;
            testCase.verifyEqual(string({meanLines.LineStyle}), repmat("--", 1, 3)) ;
            curves = findall(axesControl, 'Type', 'Line') ;
            testCase.verifyEqual(sort(vertcat(meanLines.Color), 1), ...
                sort(vertcat(curves.Color), 1), 'AbsTol', 1e-12) ;

            testCase.choose(testCase.control('ConvOutputTimeUnit'), 'min') ;

            minuteLines = findall(axesControl, 'Type', 'ConstantLine') ;
            testCase.verifyNumElements(minuteLines, 3) ;
            testCase.verifyEqual(sort([minuteLines.Value]), ...
                sort([1.8889 4.3333 6.2222] / 60), 'AbsTol', 1e-6) ;
        end

        function excelImportMatchesRTDAnalysisAndStoresNumbers(testCase)
            imported = [0 0; 1 8; 2 4; 3 6; 4 0] ;
            file = fullfile(testCase.Folder, 'tracer.xlsx') ;
            writematrix(imported, file) ;

            button = testCase.control('ConvImportCin') ;
            testCase.verifyEqual(button.Text, 'Import Experimental Data') ;
            button.UserData = file ;
            testCase.press(button) ;

            data = testCase.control('ConvTableCin').Data ;
            testCase.verifyClass(data, 'double') ;
            testCase.verifyEqual(data, imported) ;
        end

        function removeRowUsesSelectionAndKeepsOneRow(testCase)
            tableControl = testCase.control('ConvTableCin') ;
            testCase.press(testCase.control('ConvAddRowCin')) ;
            testCase.type(tableControl, [2 1], '17') ;
            testCase.press(testCase.control('ConvRemoveRowCin')) ;
            testCase.verifySize(tableControl.Data, [3 2]) ;
            containsSeventeen = cellfun(@(v) isequal(v, 17) || isequal(v, '17'), ...
                testCase.asCells(tableControl.Data)) ;
            testCase.verifyFalse(any(containsSeventeen, 'all')) ;
            testCase.press(testCase.control('ConvRemoveRowCin')) ;
            testCase.press(testCase.control('ConvRemoveRowCin')) ;
            testCase.press(testCase.control('ConvRemoveRowCin')) ;
            testCase.verifySize(tableControl.Data, [1 2]) ;

            testCase.choose(testCase.control('ConvSourceCin'), 'Function') ;
            testCase.press(testCase.control('ConvAddRowCin')) ;
            functionTable = testCase.control('ConvFunctionTableCin') ;
            testCase.verifySize(functionTable.Data, [4 3]) ;
            testCase.press(testCase.control('ConvRemoveRowCin')) ;
            testCase.verifySize(functionTable.Data, [3 3]) ;
        end

        function modelCstrAndCurrentRTDAreAvailable(testCase)
            testCase.control('ConvTableCin').Data = [0:10; ones(1, 11)].' ;
            testCase.setDropdown('ConvSourceE', 'Model') ;
            testCase.setDropdown('ConvModelE', 'CSTR') ;
            testCase.control('ConvTauE').Value = 5 ;
            testCase.press(testCase.control('ConvCompute')) ;
            lines = findall(testCase.control('ConvAxes'), 'Type', 'Line') ;
            eLine = lines(strcmp({lines.DisplayName}, '$E(t)$')) ;
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
            testCase.press(testCase.control('ConvCompute')) ;
            lines = findall(testCase.control('ConvAxes'), 'Type', 'Line') ;
            eLine = lines(strcmp({lines.DisplayName}, '$E(t)$')) ;
            expected = nirp.conv.fromRTD(expectedRTD, 1) ;
            testCase.verifyEqual(eLine.XData, expected.t, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(eLine.YData, expected.C, 'AbsTol', 1e-12) ;
        end

        function deconvolutionFunctionMatchesCourseAndLoadsTabOne(testCase)
            testCase.configureCourseDeconvolution('min') ;

            testCase.press(testCase.control('ConvCompute')) ;

            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 1).', 4:9, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(result(:, 2).', [1.79 2.33 2.58 0 1.24 0], ...
                'AbsTol', 2e-2) ;
            testCase.verifyEqual(testCase.control('ConvResultTable').ColumnName{2}, ...
                'Ê(t) [min⁻¹]') ;
            testCase.verifyEqual(testCase.control('ConvResultLabel5').Text, '$\|r\|_2$') ;
            testCase.verifyNotEmpty(testCase.control('ConvResultValue5').Text) ;
            testCase.verifyEqual(char(testCase.control('ConvDiagnostics').Visible), 'on') ;
            testCase.verifyEqual(char(testCase.control('ConvVerificationAxes').Visible), 'on') ;
            testCase.verifyEqual(char(testCase.control('ConvUseAsRTD').Enable), 'on') ;
            testCase.verifyNumElements(findall(testCase.control('ConvAxes'), ...
                'Type', 'ConstantLine'), 1) ;
            testCase.verifyNumElements(findall(testCase.control('ConvVerificationAxes'), ...
                'Type', 'ConstantLine'), 2) ;
            testCase.press(testCase.control('ConvUseAsRTD')) ;
            saved = fullfile(testCase.Folder, 'deconvolved.mat') ;
            testCase.App.saveSessionToFile(saved, 'deconvolved') ;
            session = load(saved, 'sessionData') ;
            testCase.verifyEqual(session.sessionData.rtd.source, 'Tabular Input') ;
            testCase.verifyEqual(session.sessionData.shared.rtd.source, 'deconvolution') ;
            testCase.verifyEqual(session.sessionData.shared.rtd.t, (4:9) * 60, ...
                'AbsTol', 1e-12) ;
        end

        function seriesCompositionHasDedicatedResults(testCase)
            testCase.selectMode('Series composition') ;
            testCase.control('ConvTableE1').Data = [0 0; 1 1; 2 0] ;
            testCase.control('ConvTableE2').Data = [0 0; 1 1; 2 0] ;

            testCase.press(testCase.control('ConvCompute')) ;

            resultTable = testCase.control('ConvResultTable') ;
            testCase.verifyEqual(resultTable.ColumnName{2}, 'E₁₂(t) [s⁻¹]') ;
            testCase.verifyEqual(testCase.control('ConvResultLabel1').Text, '$\tau_{12}$') ;
            testCase.verifyEqual(testCase.control('ConvResultLabel3').Text, '$\sigma_{12}^2$') ;
            testCase.verifyEqual(char(testCase.control('ConvDiagnostics').Visible), 'off') ;
            lines = findall(testCase.control('ConvAxes'), 'Type', 'Line') ;
            testCase.verifyEqual(sort(string({lines.DisplayName})), ...
                sort(["$E_1(t)$", "$E_2(t)$", "$E_{12}(t)$"])) ;
            meanLines = findall(testCase.control('ConvAxes'), 'Type', 'ConstantLine') ;
            testCase.verifyNumElements(meanLines, 3) ;
            testCase.verifyEqual(sort([meanLines.Value]), [1 1 2], 'AbsTol', 1e-12) ;
        end

        function momentsUseSelectedTimeUnit(testCase)
            testCase.configureCourseDeconvolution('min') ;
            testCase.press(testCase.control('ConvCompute')) ;

            minuteTable = testCase.control('ConvMomentsTable') ;
            testCase.verifyEqual(minuteTable.ColumnName(:), ...
                {'Signal'; 'Area'; 'τ [min]'; 'σ² [min²]'}) ;
            minuteData = minuteTable.Data ;
            minuteE = minuteData(strcmp(minuteData(:, 1), 'Estimated E'), 2:4) ;
            tCin = (0:4) * 60 ;
            cin = nirp.conv.signal(tCin, (0:4) .* exp(-(0:4) / 2)) ;
            cout = nirp.conv.signal((4:13) * 60, ...
                [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5]) ;
            [expectedE, expectedInfo] = nirp.conv.deconvolve(cin, cout) ;
            eMoments = nirp.conv.moments(expectedE) ;
            testCase.verifyEqual([minuteE{:}], ...
                [eMoments.area, eMoments.mean / 60, eMoments.variance / 60^2], ...
                'RelTol', 1e-12) ;
            testCase.verifyEqual(minuteE{2}, 5.8, 'AbsTol', 0.1) ;
            minuteTau = testCase.control('ConvResultValue2').Text ;
            expectedDisplayedArea = nirp.conv.moments(expectedE) ;
            testCase.verifyEqual(testCase.control('ConvResultLabel1').Text, '$A_E$') ;
            testCase.verifySubstring(testCase.control('ConvResultValue1').Text, ...
                sprintf('%.6g', expectedDisplayedArea.area)) ;
            testCase.verifyEqual(testCase.control('ConvResultLabel4').Text, '$\sigma_\theta^2$') ;
            testCase.verifySubstring(testCase.control('ConvDiagnostics').Text, 'Warning') ;
            testCase.verifyNotEqual(expectedInfo.areaE, expectedDisplayedArea.area, ...
                'The fixture must distinguish rectangular and trapezoidal areas.') ;

            testCase.configureCourseDeconvolution('s') ;
            testCase.press(testCase.control('ConvCompute')) ;

            secondTable = testCase.control('ConvMomentsTable') ;
            testCase.verifyEqual(secondTable.ColumnName(:), ...
                {'Signal'; 'Area'; 'τ [s]'; 'σ² [s²]'}) ;
            secondData = secondTable.Data ;
            secondE = secondData(strcmp(secondData(:, 1), 'Estimated E'), 2:4) ;
            testCase.verifyEqual(secondE{1}, minuteE{1}, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondE{2}, minuteE{2} * 60, 'RelTol', 1e-12) ;
            testCase.verifyEqual(secondE{3}, minuteE{3} * 60^2, 'RelTol', 1e-12) ;
            testCase.verifyNotEqual(testCase.control('ConvResultValue2').Text, minuteTau) ;
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

        function convolutionStateRoundTripsAllUnits(testCase)
            input = [0 0; 1 2; 2 0] ;
            testCase.control('ConvTableCin').Data = input ;
            testCase.choose(testCase.control('ConvTimeUnitCin'), 'min') ;
            testCase.choose(testCase.control('ConvConcentrationUnitCin'), 'mol/L') ;
            testCase.choose(testCase.control('ConvTimeUnitE'), 'h') ;
            testCase.choose(testCase.control('ConvDtUnit'), 'min') ;
            testCase.choose(testCase.control('ConvOutputTimeUnit'), 'h') ;
            testCase.choose(testCase.control('ConvOutputConcentrationUnit'), 'mmol/L') ;
            testCase.control('ConvDt').Value = 0.25 ;
            saved = fullfile(testCase.Folder, 'convolution-session.mat') ;
            testCase.App.saveSessionToFile(saved, 'convolution-session') ;

            testCase.control('ConvTableCin').Data = cell(3, 2) ;
            testCase.choose(testCase.control('ConvTimeUnitCin'), 's') ;
            testCase.choose(testCase.control('ConvConcentrationUnitCin'), 'mol/m^3') ;
            testCase.choose(testCase.control('ConvOutputTimeUnit'), 's') ;
            testCase.control('ConvDt').Value = 0 ;
            testCase.App.loadSessionFromFile(saved) ;

            testCase.verifyEqual(testCase.control('ConvTableCin').Data, input) ;
            testCase.verifyEqual(testCase.control('ConvTimeUnitCin').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvConcentrationUnitCin').Value, 'mol/L') ;
            testCase.verifyEqual(testCase.control('ConvTimeUnitE').Value, 'h') ;
            testCase.verifyEqual(testCase.control('ConvDtUnit').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvOutputTimeUnit').Value, 'h') ;
            testCase.verifyEqual(testCase.control('ConvOutputConcentrationUnit').Value, 'mmol/L') ;
            testCase.verifyEqual(testCase.control('ConvDt').Value, 0.25) ;
        end

        function equivalentInputUnitsAndPresentationOnlyOutputUnits(testCase)
            testCase.choose(testCase.control('ConvTimeUnitCin'), 'min') ;
            testCase.choose(testCase.control('ConvConcentrationUnitCin'), 'mol/L') ;
            testCase.choose(testCase.control('ConvTimeUnitE'), 'min') ;
            testCase.press(testCase.control('ConvAddRowCin')) ;
            testCase.press(testCase.control('ConvAddRowCin')) ;
            testCase.press(testCase.control('ConvAddRowE')) ;
            testCase.press(testCase.control('ConvAddRowE')) ;
            testCase.typeTable('ConvTableCin', [(0:4).' / 60 [0 8 4 6 0].']) ;
            testCase.typeTable('ConvTableE', [(2:6).' / 60 [0 .05 .5 .35 0].' * 60]) ;
            testCase.press(testCase.control('ConvCompute')) ;

            secondsResult = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(secondsResult(:, 1).', 2:10, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(secondsResult(:, 2).', ...
                [0 0 .4 4.2 5.1 4.4 2.1 0 0] * 1000, 'AbsTol', 1e-9) ;
            testCase.control('ConvTableCin').Data = [0 99; 1 99] ;
            testCase.choose(testCase.control('ConvOutputTimeUnit'), 'min') ;
            testCase.choose(testCase.control('ConvOutputConcentrationUnit'), 'mol/L') ;
            converted = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(converted(:, 1).', (2:10) / 60, 'AbsTol', 1e-12) ;
            testCase.verifyEqual(converted(:, 2).', ...
                [0 0 .4 4.2 5.1 4.4 2.1 0 0], 'AbsTol', 1e-12) ;
        end

        function legacySnapshotAppliesOneTimeUnitEverywhere(testCase)
            saved = fullfile(testCase.Folder, 'legacy-convolution.mat') ;
            testCase.App.saveSessionToFile(saved, 'legacy-convolution') ;
            loaded = load(saved, 'sessionData') ;
            loaded.sessionData.convolution.timeUnit = 'min' ;
            loaded.sessionData.convolution = rmfield(loaded.sessionData.convolution, ...
                {'dtUnit', 'outputTimeUnit', 'outputConcentrationUnit'}) ;
            names = fieldnames(loaded.sessionData.convolution.signals) ;
            for k = 1:numel(names)
                state = loaded.sessionData.convolution.signals.(names{k}) ;
                state = rmfield(state, {'timeUnit', 'concentrationUnit'}) ;
                loaded.sessionData.convolution.signals.(names{k}) = state ;
            end
            sessionData = loaded.sessionData ; %#ok<NASGU>
            save(saved, 'sessionData') ;
            testCase.App.loadSessionFromFile(saved) ;
            testCase.verifyEqual(testCase.control('ConvOutputTimeUnit').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvDtUnit').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvTimeUnitCin').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvTimeUnitE').Value, 'min') ;
            testCase.verifyEqual(testCase.control('ConvConcentrationUnitCin').Value, 'mol/m^3') ;
            testCase.verifyEqual(testCase.control('ConvOutputConcentrationUnit').Value, 'mol/m^3') ;
        end

        function legacyFunctionSessionLoadsAsOneRowAndCalculates(testCase)
            saved = fullfile(testCase.Folder, 'legacy-function.mat') ;
            testCase.control('ConvTableE').Data = [0 0; 1 1; 2 0] ;
            testCase.control('ConvDt').Value = 1 ;
            testCase.App.saveSessionToFile(saved, 'legacy-function') ;
            loaded = load(saved, 'sessionData') ;
            state = loaded.sessionData.convolution.signals.Cin ;
            state.source = 'Function' ;
            state.functionExpression = 't' ;
            state.functionStart = 0 ;
            state.functionEnd = 2 ;
            state.functionStep = 0.25 ;
            loaded.sessionData.convolution.signals.Cin = state ;
            sessionData = loaded.sessionData ; %#ok<NASGU>
            save(saved, 'sessionData') ;

            testCase.App.loadSessionFromFile(saved) ;
            testCase.verifyEqual(testCase.control('ConvSourceCin').Value, 'Function') ;
            testCase.verifyEqual(testCase.control('ConvFunctionTableCin').Data, {0 2 't'}) ;
            testCase.press(testCase.control('ConvCompute')) ;
            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 2).', [0 0 1 2 0], 'AbsTol', 1e-12) ;
        end

        function legacyPiecewiseSessionLoadsAsFunctionAndCalculates(testCase)
            saved = fullfile(testCase.Folder, 'legacy-piecewise.mat') ;
            testCase.control('ConvTableE').Data = [0 0; 1 1; 2 0] ;
            testCase.control('ConvDt').Value = 1 ;
            testCase.App.saveSessionToFile(saved, 'legacy-piecewise') ;
            loaded = load(saved, 'sessionData') ;
            state = loaded.sessionData.convolution.signals.Cin ;
            state.source = 'Piecewise' ;
            state.piecewiseData = {0 1 't'; 1 2 '2.*t'} ;
            loaded.sessionData.convolution.signals.Cin = state ;
            sessionData = loaded.sessionData ; %#ok<NASGU>
            save(saved, 'sessionData') ;

            testCase.App.loadSessionFromFile(saved) ;
            testCase.verifyEqual(testCase.control('ConvSourceCin').Value, 'Function') ;
            testCase.verifyEqual(testCase.control('ConvFunctionTableCin').Data, ...
                {0 1 't'; 1 2 '2.*t'}) ;
            testCase.press(testCase.control('ConvCompute')) ;
            result = testCase.control('ConvResultTable').Data ;
            testCase.verifyEqual(result(:, 2).', [0 0 2 4 0], 'AbsTol', 1e-12) ;
        end
    end

    methods (Access = private)
        function value = control(testCase, tag)
            values = findall(testCase.Figure, 'Tag', tag) ;
            testCase.assertNumElements(values, 1, ['Missing control: ' tag]) ;
            value = values(1) ;
            current = value ;
            while ~isempty(current) && isvalid(current) && isprop(current, 'Parent')
                current = current.Parent ;
                if isa(current, 'matlab.ui.container.Tab') && ...
                        isa(current.Parent, 'matlab.ui.container.TabGroup')
                    current.Parent.SelectedTab = current ;
                end
            end
            drawnow ;
        end

        function setDropdown(testCase, tag, value)
            testCase.choose(testCase.control(tag), value) ;
        end

        function selectMode(testCase, label)
            group = testCase.control('ConvModeGroup') ;
            buttons = group.Children ;
            testCase.press(buttons(strcmp({buttons.Text}, label))) ;
        end

        function typeTable(testCase, tag, values)
            tableControl = testCase.control(tag) ;
            for row = 1:size(values, 1)
                for column = 1:size(values, 2)
                    testCase.type(tableControl, [row column], ...
                        sprintf('%.15g', values(row, column))) ;
                end
            end
            drawnow ;
        end

        function cells = asCells(~, data)
            if isnumeric(data), cells = num2cell(data) ; else, cells = data ; end
        end

        function configureCourseDeconvolution(testCase, unit)
            testCase.selectMode('Deconvolution') ;
            testCase.setDropdown('ConvTimeUnitCin', unit) ;
            testCase.setDropdown('ConvTimeUnitCout', unit) ;
            testCase.setDropdown('ConvDtUnit', unit) ;
            testCase.setDropdown('ConvOutputTimeUnit', unit) ;
            testCase.setDropdown('ConvSourceCin', 'Function') ;
            output = [.9 1.8 2.1 5.2 3.6 4.5 1.7 .8 .7 .5].' ;
            if strcmp(unit, 'min')
                testCase.control('ConvDt').Value = 1 ;
                testCase.control('ConvFunctionTableCin').Data = ...
                    {0 4 't.*exp(-t/2)'} ;
                testCase.control('ConvTableCout').Data = [(4:13).', output] ;
            else
                testCase.control('ConvDt').Value = 60 ;
                testCase.control('ConvFunctionTableCin').Data = ...
                    {0 240 '(t/60).*exp(-(t/60)/2)'} ;
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
