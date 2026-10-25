classdef ConvolutionTabHelper < handle
% ConvolutionTabHelper - UI and state for tracer convolution workflows.
% All times passed to nirp.conv are expressed in seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 26, 2026
% =========================================================================

    properties (SetAccess = private)
        Tab
    end

    properties (Access = private)
        GetRTD
        SetRTD
        SetTracer
        SetStatus
        ModeGroup
        DtUnit
        OutputTimeUnit
        OutputConcentrationUnit
        DtField
        SupportPanel
        SupportMin
        SupportMax
        SupportUnit
        SupportIsDefault = true
        Regularization
        Smoothing
        LambdaMode
        LambdaValue
        LowerPlot
        SignalTabs
        HiddenSignalTabs
        Signals = struct()
        Axes
        VerificationAxes
        ResultsGrid
        ResultTable
        MomentsTable
        ResultsPanel
        ResultsDescription
        ResultLabels = {}
        ResultValues = {}
        DiagnosticsLabel
        ExportButton
        UseRTDButton
        LastSignals = struct()
        LastResult = []
        LastInfo = struct()
    end

    methods
        function obj = ConvolutionTabHelper(parent, getRTD, setRTD, setTracer, setStatus)
            obj.GetRTD = getRTD ;
            obj.SetRTD = setRTD ;
            obj.SetTracer = setTracer ;
            obj.SetStatus = setStatus ;
            obj.buildUI(parent) ;
        end

        function snapshot = buildSnapshot(obj)
            snapshot = struct('mode', obj.ModeGroup.SelectedObject.Text, ...
                'timeUnit', obj.OutputTimeUnit.Value, ...
                'dtUnit', obj.DtUnit.Value, 'dt', obj.DtField.Value, ...
                'supportMin', obj.SupportMin.Value, ...
                'supportMax', obj.SupportMax.Value, ...
                'supportUnit', obj.SupportUnit.Value, ...
                'supportIsDefault', obj.SupportIsDefault, ...
                'regularization', obj.Regularization.Value, ...
                'smoothing', obj.Smoothing.Value, ...
                'lambdaMode', obj.LambdaMode.Value, ...
                'lambdaValue', obj.LambdaValue.Value, ...
                'lowerPlot', obj.LowerPlot.Value, ...
                'outputTimeUnit', obj.OutputTimeUnit.Value, ...
                'outputConcentrationUnit', obj.OutputConcentrationUnit.Value, ...
                'signals', struct(), 'lastSignals', obj.LastSignals, ...
                'lastResult', obj.LastResult, ...
                'lastInfo', obj.portableInfo()) ;
            names = obj.activeSignalNames(obj.ModeGroup.SelectedObject.Text) ;
            for k = 1:numel(names)
                ui = obj.Signals.(names{k}) ;
                snapshot.signals.(names{k}) = struct( ...
                    'source', ui.Source.Value, 'timeUnit', ui.TimeUnit.Value, ...
                    'concentrationUnit', ui.ConcentrationUnit.Value, ...
                    'tableData', {ui.Table.Data}, ...
                    'piecewiseData', {ui.PiecewiseTable.Data}, ...
                    'model', ui.Model.Value, 'tau', ui.Tau.Value, ...
                    'n', ui.N.Value, 'bo', ui.Bo.Value) ;
            end
        end

        function applySnapshot(obj, snapshot)
            if ~isstruct(snapshot) || isempty(fieldnames(snapshot))
                obj.reset() ;
                return
            end
            storedMode = obj.getField(snapshot, 'mode', 'Convolution') ;
            seriesCompositionMoved = strcmp(storedMode, 'Series composition') ;
            if seriesCompositionMoved
                storedMode = 'Convolution' ;
                obj.reset() ;
            end
            obj.selectMode(storedMode) ;
            legacyTimeUnit = obj.getField(snapshot, 'timeUnit', 's') ;
            obj.setDropdown(obj.DtUnit, obj.getField(snapshot, 'dtUnit', legacyTimeUnit)) ;
            obj.setDropdown(obj.OutputTimeUnit, ...
                obj.getField(snapshot, 'outputTimeUnit', legacyTimeUnit)) ;
            obj.setDropdown(obj.OutputConcentrationUnit, ...
                obj.getField(snapshot, 'outputConcentrationUnit', 'mol/m^3')) ;
            obj.DtField.Value = obj.getField(snapshot, 'dt', 0) ;
            obj.SupportMin.Value = obj.getField(snapshot, 'supportMin', 0) ;
            obj.SupportMax.Value = obj.getField(snapshot, 'supportMax', 10) ;
            obj.setDropdown(obj.SupportUnit, ...
                obj.getField(snapshot, 'supportUnit', legacyTimeUnit)) ;
            obj.SupportIsDefault = obj.getField(snapshot, 'supportIsDefault', true) ;
            obj.setDropdown(obj.Regularization, ...
                obj.getField(snapshot, 'regularization', 'None')) ;
            obj.setDropdown(obj.Smoothing, ...
                obj.getField(snapshot, 'smoothing', 'second difference')) ;
            obj.setDropdown(obj.LambdaMode, ...
                obj.getField(snapshot, 'lambdaMode', 'Auto (L-curve)')) ;
            obj.LambdaValue.Value = obj.getField(snapshot, 'lambdaValue', 0.01) ;
            obj.setDropdown(obj.LowerPlot, ...
                obj.getField(snapshot, 'lowerPlot', 'Reconvolution check')) ;
            obj.regularizationChanged(false) ;
            storedSignals = obj.getField(snapshot, 'signals', struct()) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                name = names{k} ;
                if ~isfield(storedSignals, name), continue, end
                state = storedSignals.(name) ;
                ui = obj.Signals.(name) ;
                source = obj.getField(state, 'source', 'Table') ;
                piecewiseData = obj.getField(state, 'piecewiseData', ui.PiecewiseTable.Data) ;
                if strcmp(source, 'Piecewise')
                    source = 'Function' ;
                elseif strcmp(source, 'Function') && ...
                        all(isfield(state, {'functionExpression', 'functionStart', 'functionEnd'}))
                    piecewiseData = {obj.getField(state, 'functionStart', 0), ...
                        obj.getField(state, 'functionEnd', 10), ...
                        char(string(obj.getField(state, 'functionExpression', 'exp(-t)')))} ;
                end
                obj.setDropdown(ui.Source, source) ;
                obj.setDropdown(ui.TimeUnit, obj.getField(state, 'timeUnit', legacyTimeUnit)) ;
                obj.setDropdown(ui.ConcentrationUnit, ...
                    obj.getField(state, 'concentrationUnit', 'mol/m^3')) ;
                storedTableData = obj.getField(state, 'tableData', ui.Table.Data) ;
                if isnumeric(storedTableData)
                    ui.Table.Data = double(storedTableData) ;
                else
                    ui.Table.Data = obj.numericEditorData(storedTableData, 2) ;
                end
                ui.PiecewiseTable.Data = piecewiseData ;
                obj.setDropdown(ui.Model, obj.getField(state, 'model', 'CSTR')) ;
                ui.Tau.Value = obj.getField(state, 'tau', 5) ;
                ui.N.Value = obj.getField(state, 'n', 2) ;
                ui.Bo.Value = obj.getField(state, 'bo', 0.1) ;
                obj.sourceChanged(name) ;
            end
            obj.LastSignals = obj.getField(snapshot, 'lastSignals', struct()) ;
            obj.LastResult = obj.getField(snapshot, 'lastResult', []) ;
            obj.LastInfo = obj.getField(snapshot, 'lastInfo', struct()) ;
            if seriesCompositionMoved
                obj.LastSignals = struct() ;
                obj.LastResult = [] ;
                obj.LastInfo = struct() ;
            end
            obj.modeChanged() ;
            if isstruct(obj.LastResult) && isfield(obj.LastResult, 't')
                obj.showResults() ;
            else
                obj.clearResults() ;
            end
            if seriesCompositionMoved
                message = ['Series composition is now available in the non-ideal ' ...
                    'tracer flowsheet. See the equivalent tracer_sec01_series example.'] ;
                warning('NonIdealReactorApp:SeriesCompositionMoved', '%s', message) ;
                obj.SetStatus(message) ;
            end
        end

        function reset(obj)
            obj.selectMode('Convolution') ;
            obj.DtUnit.Value = 's' ;
            obj.OutputTimeUnit.Value = 's' ;
            obj.OutputConcentrationUnit.Value = 'mol/m^3' ;
            obj.DtField.Value = 0 ;
            obj.SupportMin.Value = 0 ;
            obj.SupportMax.Value = 10 ;
            obj.SupportUnit.Value = 's' ;
            obj.SupportIsDefault = true ;
            obj.Regularization.Value = 'None' ;
            obj.Smoothing.Value = 'second difference' ;
            obj.LambdaMode.Value = 'Auto (L-curve)' ;
            obj.LambdaValue.Value = 0.01 ;
            obj.LowerPlot.Value = 'Reconvolution check' ;
            obj.regularizationChanged(false) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                ui = obj.Signals.(names{k}) ;
                ui.Source.Value = 'Table' ;
                ui.TimeUnit.Value = 's' ;
                if ~obj.isRTDName(names{k})
                    ui.ConcentrationUnit.Value = 'mol/m^3' ;
                end
                ui.Table.Data = cell(3, 2) ;
                ui.PiecewiseTable.Data = cell(3, 3) ;
                obj.sourceChanged(names{k}) ;
            end
            obj.LastSignals = struct() ;
            obj.LastResult = [] ;
            obj.LastInfo = struct() ;
            obj.modeChanged() ;
            obj.clearResults() ;
        end
    end

    methods (Access = private)
        function buildUI(obj, parent)
            obj.Tab = uitab(parent, 'Title', 'Convolution', 'Tag', 'ConvolutionTab') ;
            root = uigridlayout(obj.Tab, [1 2], 'ColumnWidth', {430, '1x'}, ...
                'Padding', [8 8 8 8], 'ColumnSpacing', 10) ;

            controls = uigridlayout(root, [7 1], ...
                'RowHeight', {54, 32, '1x', 0, 34, 68, 34}, ...
                'RowSpacing', 4, 'Padding', [0 0 0 0]) ;
            modePanel = uipanel(controls, 'Title', 'Mode') ;
            obj.ModeGroup = uibuttongroup(modePanel, 'Position', [4 2 414 27], ...
                'SelectionChangedFcn', @(~,~) obj.modeChanged(true), 'Tag', 'ConvModeGroup') ;
            labels = {'Convolution', 'Deconvolution'} ;
            x = [8 210] ;
            for k = 1:numel(labels)
                uiradiobutton(obj.ModeGroup, 'Text', labels{k}, ...
                    'Position', [x(k) 3 180 22], ...
                    'Tooltip', 'Choose the tracer-signal calculation mode.') ;
            end

            common = uigridlayout(controls, [1 5], ...
                'ColumnWidth', {150, '1x', 45, 52, 52}, 'Padding', [0 0 0 0]) ;
            commonLabel = uilabel(common, ...
                'Text', '$\Delta t_{\mathrm{common}}\;(0=\mathrm{auto})$', ...
                'Interpreter', 'latex') ;
            obj.DtField = uieditfield(common, 'numeric', 'Value', 0, ...
                'Limits', [0 Inf], 'Tag', 'ConvDt', ...
                'Tooltip', 'Common calculation step. Zero uses the finest input step.') ;
            uilabel(common, 'Text', '$\mathrm{Unit:}$', 'Interpreter', 'latex') ;
            obj.DtUnit = uidropdown(common, 'Items', UnitConverterHelper.getUnits('Time'), ...
                'Value', 's', 'Tag', 'ConvDtUnit', ...
                'Tooltip', 'Time unit of the common calculation step.') ;
            commonLabel.Tooltip = obj.DtField.Tooltip ;

            obj.SignalTabs = uitabgroup(controls, 'Tag', 'ConvSignalTabs') ;
            hiddenPanel = uipanel(obj.Tab, 'Visible', 'off', 'Position', [0 0 1 1]) ;
            obj.HiddenSignalTabs = uitabgroup(hiddenPanel, 'Visible', 'off', ...
                'Tag', 'ConvHiddenSignalTabs') ;
            obj.createSignalEditor('Cin', 'Inlet signal Cᵢₙ(t)', false) ;
            obj.createSignalEditor('Cout', 'Outlet signal Cₒᵤₜ(t)', false) ;
            obj.createSignalEditor('E', 'RTD E(t)', true) ;

            obj.SupportPanel = uipanel(controls, 'Title', 'Deconvolution settings', ...
                'Visible', 'off', 'Tag', 'ConvSupportPanel', ...
                'Tooltip', ['Delays used as deconvolution unknowns. Defaults to the ' ...
                'largest support compatible with the stated signal windows.']) ;
            obj.SupportPanel.Layout.Row = 4 ;
            supportGrid = uigridlayout(obj.SupportPanel, [6 7], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x', 'fit', 58, 64}, ...
                'RowHeight', {22, 18, 22, 22, 22, 18}, 'Padding', [6 1 6 1], ...
                'RowSpacing', 0) ;
            uilabel(supportGrid, 'Text', '$\tau_{\min}$:', 'Interpreter', 'latex') ;
            obj.SupportMin = uieditfield(supportGrid, 'numeric', 'Value', 0, ...
                'Limits', [0 Inf], 'Tag', 'ConvSupportMin', ...
                'ValueChangedFcn', @(~,~) obj.supportEdited()) ;
            uilabel(supportGrid, 'Text', '$\tau_{\max}$:', 'Interpreter', 'latex') ;
            obj.SupportMax = uieditfield(supportGrid, 'numeric', 'Value', 10, ...
                'Limits', [0 Inf], 'Tag', 'ConvSupportMax', ...
                'ValueChangedFcn', @(~,~) obj.supportEdited()) ;
            uilabel(supportGrid, 'Text', '$\mathrm{Unit:}$', 'Interpreter', 'latex') ;
            obj.SupportUnit = uidropdown(supportGrid, ...
                'Items', UnitConverterHelper.getUnits('Time'), 'Value', 's', ...
                'Tag', 'ConvSupportUnit', ...
                'ValueChangedFcn', @(~,~) obj.supportEdited()) ;
            uibutton(supportGrid, 'Text', 'Suggest', ...
                'Tag', 'ConvSuggestSupport', ...
                'Tooltip', ['Suggest the widest E support compatible with the ' ...
                'current C_in and C_out windows. The suggested values remain editable.'], ...
                'ButtonPushedFcn', @(~,~) obj.suggestSupport()) ;
            supportDescription = uilabel(supportGrid, ...
                'Text', 'Default: widest support compatible with the data.', ...
                'FontSize', 10, 'Tag', 'ConvSupportDescription') ;
            supportDescription.Layout.Row = 2 ;
            supportDescription.Layout.Column = [1 7] ;
            regularizationLabel = uilabel(supportGrid, 'Text', 'Regularization:') ;
            obj.Regularization = uidropdown(supportGrid, ...
                'Items', {'None', 'Tikhonov'}, 'Value', 'None', ...
                'Tag', 'ConvRegularization', ...
                'Tooltip', 'None preserves the unregularized NNLS result; Tikhonov suppresses noise.', ...
                'ValueChangedFcn', @(~,~) obj.regularizationChanged()) ;
            smoothingLabel = uilabel(supportGrid, 'Text', 'Smoothing:') ;
            obj.Smoothing = uidropdown(supportGrid, ...
                'Items', {'second difference', 'identity'}, ...
                'Value', 'second difference', 'Tag', 'ConvSmoothing', ...
                'Tooltip', 'Second difference penalizes curvature; identity penalizes the RTD magnitude.') ;
            regularizationLabel.Layout.Row = 3 ;
            regularizationLabel.Layout.Column = 1 ;
            obj.Regularization.Layout.Row = 3 ;
            obj.Regularization.Layout.Column = [2 3] ;
            smoothingLabel.Layout.Row = 3 ;
            smoothingLabel.Layout.Column = 4 ;
            obj.Smoothing.Layout.Row = 3 ;
            obj.Smoothing.Layout.Column = [5 7] ;
            lowerPlotLabel = uilabel(supportGrid, 'Text', 'Lower plot:') ;
            obj.LowerPlot = uidropdown(supportGrid, ...
                'Items', {'Reconvolution check', 'L-curve'}, ...
                'Value', 'Reconvolution check', 'Tag', 'ConvLowerPlot', ...
                'Tooltip', 'Switch the lower graph between data fit and regularization diagnostics.', ...
                'ValueChangedFcn', @(~,~) obj.refreshPresentation()) ;
            lambdaLabel = uilabel(supportGrid, 'Text', '$\lambda$:', 'Interpreter', 'latex') ;
            obj.LambdaMode = uidropdown(supportGrid, ...
                'Items', {'Auto (L-curve)', 'Manual'}, 'Value', 'Auto (L-curve)', ...
                'Tag', 'ConvLambdaMode', ...
                'Tooltip', 'Auto selects the maximum-curvature L-curve point; Manual uses the entered value.', ...
                'ValueChangedFcn', @(~,~) obj.regularizationChanged()) ;
            valueLabel = uilabel(supportGrid, 'Text', 'Value:') ;
            obj.LambdaValue = uieditfield(supportGrid, 'numeric', ...
                'Value', 0.01, 'Limits', [0 Inf], 'Tag', 'ConvLambdaValue', ...
                'Tooltip', 'Manual nonnegative Tikhonov parameter in the augmented NNLS system.') ;
            lambdaLabel.Layout.Row = 4 ;
            lambdaLabel.Layout.Column = 1 ;
            obj.LambdaMode.Layout.Row = 4 ;
            obj.LambdaMode.Layout.Column = [2 3] ;
            valueLabel.Layout.Row = 4 ;
            valueLabel.Layout.Column = 4 ;
            obj.LambdaValue.Layout.Row = 4 ;
            obj.LambdaValue.Layout.Column = [5 7] ;
            lowerPlotLabel.Layout.Row = 5 ;
            lowerPlotLabel.Layout.Column = 1 ;
            obj.LowerPlot.Layout.Row = 5 ;
            obj.LowerPlot.Layout.Column = [2 7] ;
            regularizationDescription = uilabel(supportGrid, ...
                'Text', 'Auto scans 40 logarithmic values from 10^{-6} to 10^{2} times ||A||_2.', ...
                'Interpreter', 'tex', 'FontSize', 10, ...
                'Tag', 'ConvRegularizationDescription') ;
            regularizationDescription.Layout.Row = 6 ;
            regularizationDescription.Layout.Column = [1 7] ;

            computeButton = uibutton(controls, 'Text', 'Compute', ...
                'FontWeight', 'bold', 'BackgroundColor', [0.3 0.6 0.9], ...
                'FontColor', 'white', 'Tag', 'ConvCompute', ...
                'Tooltip', 'Run the selected tracer-signal workflow and update all results.', ...
                'ButtonPushedFcn', @(~,~) obj.compute()) ;
            computeButton.Layout.Row = 5 ;
            displayPanel = uipanel(controls, 'Title', 'Display units') ;
            displayGrid = uigridlayout(displayPanel, [1 4], ...
                'ColumnWidth', {55, '1x', 92, '1x'}, 'Padding', [6 4 6 4]) ;
            timeLabel = uilabel(displayGrid, 'Text', '$t$:', 'Interpreter', 'latex') ;
            obj.OutputTimeUnit = uidropdown(displayGrid, ...
                'Items', UnitConverterHelper.getUnits('Time'), 'Value', 's', ...
                'Tag', 'ConvOutputTimeUnit', ...
                'ValueChangedFcn', @(~,~) obj.refreshPresentation(), ...
                'Tooltip', 'Choose the result time unit. This changes presentation only.') ;
            concentrationLabel = uilabel(displayGrid, 'Text', '$C$:', 'Interpreter', 'latex') ;
            obj.OutputConcentrationUnit = uidropdown(displayGrid, ...
                'Items', UnitConverterHelper.getUnits('Concentration'), 'Value', 'mol/m^3', ...
                'Tag', 'ConvOutputConcentrationUnit', ...
                'ValueChangedFcn', @(~,~) obj.refreshPresentation(), ...
                'Tooltip', 'Choose the result concentration unit. This changes presentation only.') ;
            timeLabel.Tooltip = obj.OutputTimeUnit.Tooltip ;
            concentrationLabel.Tooltip = obj.OutputConcentrationUnit.Tooltip ;
            buttons = uigridlayout(controls, [1 2], 'ColumnWidth', {145, '1x'}, ...
                'Padding', [0 0 0 0]) ;
            obj.ExportButton = uibutton(buttons, 'Text', 'Export to Workspace', ...
                'Enable', 'off', 'Tag', 'ConvExport', ...
                'Tooltip', 'Export inputs, SI result, diagnostics, mode, and selected units as convolutionResult.', ...
                'ButtonPushedFcn', @(~,~) obj.export()) ;
            obj.UseRTDButton = uibutton(buttons, 'Text', 'Use as RTD in Tab 1', ...
                'Enable', 'off', 'Tag', 'ConvUseAsRTD', ...
                'Tooltip', 'Load the deconvolved E(t) into RTD Analysis.', ...
                'ButtonPushedFcn', @(~,~) obj.useAsRTD()) ;

            obj.ResultsGrid = uigridlayout(root, [5 1], ...
                'RowHeight', {'2x', 0, '1x', 120, 112}, 'Padding', [0 0 0 0]) ;
            obj.Axes = uiaxes(obj.ResultsGrid, 'Tag', 'ConvAxes') ;
            title(obj.Axes, '$\mathrm{Tracer\ signals}$', 'Interpreter', 'latex') ;
            xlabel(obj.Axes, '$t$ [s]', 'Interpreter', 'latex') ;
            ylabel(obj.Axes, '$\mathrm{Signal}$', 'Interpreter', 'latex') ; grid(obj.Axes, 'on') ;
            obj.VerificationAxes = uiaxes(obj.ResultsGrid, ...
                'Tag', 'ConvVerificationAxes', 'Visible', 'off') ;
            grid(obj.VerificationAxes, 'on') ;
            obj.ResultTable = uitable(obj.ResultsGrid, 'ColumnName', {'t [s]', 'C'}, ...
                'ColumnEditable', [false false], 'Tag', 'ConvResultTable', ...
                'Tooltip', 'Computed result in the selected display units.') ;
            obj.MomentsTable = uitable(obj.ResultsGrid, ...
                'ColumnName', {'Signal', 'Area', 'τ [s]', 'σ² [s²]'}, ...
                'ColumnEditable', false(1, 4), 'Tag', 'ConvMomentsTable', ...
                'Tooltip', 'Trapezoidal area, mean time, and variance for each displayed signal.') ;
            obj.ResultsPanel = uipanel(obj.ResultsGrid, 'Title', 'Results', ...
                'Tag', 'ConvResultsPanel') ;
            results = uigridlayout(obj.ResultsPanel, [5 6], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x', 'fit', '1x'}, ...
                'RowHeight', {34, 20, 20, 0, 0}, ...
                'RowSpacing', 2, 'ColumnSpacing', 5, 'Padding', [6 3 6 3], ...
                'Scrollable', 'off', ...
                'Tag', 'ConvResultsRows') ;
            obj.ResultsDescription = uilabel(results, 'Text', '', ...
                'Interpreter', 'latex', 'WordWrap', 'on', ...
                'Tag', 'ConvResultsDescription') ;
            obj.ResultsDescription.Layout.Row = 1 ;
            obj.ResultsDescription.Layout.Column = [1 6] ;
            for k = 1:7
                label = uilabel(results, 'Text', '', 'Interpreter', 'latex', ...
                    'HorizontalAlignment', 'right', ...
                    'Tag', sprintf('ConvResultLabel%d', k)) ;
                value = uilabel(results, 'Text', '', 'Interpreter', 'latex', ...
                    'Tag', sprintf('ConvResultValue%d', k)) ;
                initialIndex = min(k, 6) ;
                initialRow = 1 + ceil(initialIndex / 3) ;
                initialColumn = 1 + 2 * mod(initialIndex - 1, 3) ;
                label.Layout.Row = initialRow ;
                label.Layout.Column = initialColumn ;
                value.Layout.Row = initialRow ;
                value.Layout.Column = initialColumn + 1 ;
                obj.ResultLabels{k} = label ;
                obj.ResultValues{k} = value ;
            end
            obj.DiagnosticsLabel = uilabel(results, 'Text', '', ...
                'Interpreter', 'latex', 'FontColor', [0.75 0.1 0.1], ...
                'WordWrap', 'on', 'Tag', 'ConvDiagnostics', ...
                'Tooltip', 'Warning shown when the estimated RTD area differs materially from one.') ;
            obj.DiagnosticsLabel.Layout.Row = 5 ;
            obj.DiagnosticsLabel.Layout.Column = [1 6] ;
            obj.modeChanged() ;
        end

        function createSignalEditor(obj, name, titleText, allowRTD)
            tab = uitab(obj.SignalTabs, 'Title', titleText, 'Tag', ['ConvSignal' name]) ;
            grid = uigridlayout(tab, [9 2], ...
                'RowHeight', {38, 26, 26, '1x', 26, 0, 0, 0, 0}, ...
                'RowSpacing', 3, 'ColumnWidth', {125, '1x'}, 'Padding', [4 4 4 4]) ;
            description = uilabel(grid, 'Text', obj.signalDescription(name), ...
                'Interpreter', 'latex', 'WordWrap', 'on', 'Tag', ['ConvDescription' name], ...
                'Tooltip', obj.signalDescription(name)) ;
            description.Layout.Row = 1 ; description.Layout.Column = [1 2] ;
            sourceLabel = uilabel(grid, 'Text', '$\mathrm{Source}$', 'Interpreter', 'latex') ;
            sourceLabel.Layout.Row = 2 ;
            items = {'Table', 'Function'} ;
            if allowRTD
                items = [items {'RTD from tab 1', 'Model'}] ;
            end
            source = uidropdown(grid, 'Items', items, 'Value', 'Table', ...
                'Tag', ['ConvSource' name], ...
                'Tooltip', 'Choose how this signal is entered.', ...
                'ValueChangedFcn', @(~,~) obj.sourceChanged(name)) ;
            source.Layout.Row = 2 ;
            sourceLabel.Tooltip = source.Tooltip ;
            unitsGrid = uigridlayout(grid, [1 4], ...
                'ColumnWidth', {45, '1x', 45, '1x'}, 'Padding', [0 0 0 0]) ;
            unitsGrid.Layout.Row = 3 ; unitsGrid.Layout.Column = [1 2] ;
            timeLabel = uilabel(unitsGrid, 'Text', '$t$:', 'Interpreter', 'latex') ;
            timeUnit = uidropdown(unitsGrid, 'Items', UnitConverterHelper.getUnits('Time'), ...
                'Value', 's', 'Tag', ['ConvTimeUnit' name], ...
                'Tooltip', 'Time unit used by this signal input.') ;
            concentrationLabel = uilabel(unitsGrid, 'Text', '$C$:', 'Interpreter', 'latex') ;
            concentrationUnit = uidropdown(unitsGrid, ...
                'Items', UnitConverterHelper.getUnits('Concentration'), ...
                'Value', 'mol/m^3', 'Tag', ['ConvConcentrationUnit' name], ...
                'Tooltip', 'Concentration unit used by this signal input.') ;
            if obj.isRTDName(name)
                concentrationLabel.Text = '$E(t)$:' ;
                concentrationUnit.Items = {'1 / selected time unit'} ;
                concentrationUnit.Value = '1 / selected time unit' ;
                concentrationUnit.Enable = 'off' ;
                concentrationUnit.Tooltip = 'E(t) is interpreted as the reciprocal of this signal''s time unit.' ;
            end
            timeLabel.Tooltip = timeUnit.Tooltip ; concentrationLabel.Tooltip = concentrationUnit.Tooltip ;
            valueSymbol = 'C' ;
            if obj.isRTDName(name), valueSymbol = 'E' ; end
            tableInput = uitable(grid, 'Data', cell(3, 2), ...
                'ColumnName', {'t', valueSymbol}, 'ColumnEditable', [true true], ...
                'CellEditCallback', @(src,event) obj.tableCellEdited(src, event), ...
                'CellSelectionCallback', @(src,event) obj.rememberSelection(src, event), ...
                'Tooltip', 'Enter time and signal value pairs; headers and incomplete imported rows are ignored.', ...
                'Tag', ['ConvTable' name]) ;
            tableInput.Layout.Row = 4 ; tableInput.Layout.Column = [1 2] ;
            tableButtons = uigridlayout(grid, [1 3], ...
                'ColumnWidth', {100, 120, '1x'}, 'Padding', [0 0 0 0]) ;
            tableButtons.Layout.Row = 5 ; tableButtons.Layout.Column = [1 2] ;
            addRow = uibutton(tableButtons, 'Text', 'Add row', ...
                'BackgroundColor', [0.85 0.95 0.85], 'Tag', ['ConvAddRow' name], ...
                'Tooltip', 'Append one empty row to the active manual-input table.', ...
                'ButtonPushedFcn', @(~,~) obj.addRow(name)) ;
            removeRow = uibutton(tableButtons, 'Text', 'Remove row', ...
                'BackgroundColor', [0.95 0.85 0.85], 'Tag', ['ConvRemoveRow' name], ...
                'Tooltip', 'Remove the selected row, or the last row when none is selected; one row is always kept.', ...
                'ButtonPushedFcn', @(~,~) obj.removeRow(name)) ;
            importButton = uibutton(tableButtons, 'Text', 'Import Experimental Data', ...
                'Tag', ['ConvImport' name], ...
                'Tooltip', 'Import the first two numeric columns from Excel, CSV, or TSV into this signal.', ...
                'ButtonPushedFcn', @(src,~) obj.importTable(name, src.UserData)) ;
            functionGrid = uigridlayout(grid, [2 1], ...
                'RowHeight', {38, '1x'}, 'Padding', [0 0 0 0], ...
                'RowSpacing', 3, 'Visible', 'off') ;
            functionGrid.Layout.Row = 4 ; functionGrid.Layout.Column = [1 2] ;
            pieceLabel = uilabel(functionGrid, ...
                'Text', '$\mathrm{Function:~expression~of~}t\mathrm{~on~one~or~more~intervals}$', ...
                'Interpreter', 'latex', ...
                'Tag', ['ConvFunctionDescription' name], ...
                'Tooltip', 'Define an expression of t on one or more intervals in the selected time unit.') ;
            pieceLabel.Layout.Row = 1 ;
            pieceTable = uitable(functionGrid, 'Data', cell(3, 3), ...
                'ColumnName', {'From t', 'To t', 'Expression in t'}, ...
                'ColumnEditable', [true true true], ...
                'CellSelectionCallback', @(src,event) obj.rememberSelection(src, event), ...
                'Tooltip', 'Enter interval bounds and a MATLAB expression in t for each interval.', ...
                'Tag', ['ConvFunctionTable' name]) ;
            pieceTable.Layout.Row = 2 ;
            modelGrid = uigridlayout(grid, [2 4], ...
                'ColumnWidth', {50, '1x', 50, '1x'}, 'Padding', [0 0 0 0], ...
                'Visible', 'off') ;
            modelGrid.Layout.Row = [8 9] ; modelGrid.Layout.Column = [1 2] ;
            uilabel(modelGrid, 'Text', '$\mathrm{Model}$', 'Interpreter', 'latex') ;
            model = uidropdown(modelGrid, ...
                'Items', {'CSTR', 'PFR', 'Tanks-in-Series', 'Dispersion'}, ...
                'ValueChangedFcn', @(~,~) obj.modelChanged(name), ...
                'Tag', ['ConvModel' name], ...
                'Tooltip', 'Analytical RTD model used to generate E(t).') ;
            uilabel(modelGrid, 'Text', '$\tau$', 'Interpreter', 'latex') ;
            tau = uieditfield(modelGrid, 'numeric', 'Value', 5, 'Limits', [eps Inf], ...
                'Tag', ['ConvTau' name], ...
                'Tooltip', 'Mean residence time in this signal''s selected time unit.') ;
            uilabel(modelGrid, 'Text', '$N$', 'Interpreter', 'latex') ;
            n = uieditfield(modelGrid, 'numeric', 'Value', 2, 'Limits', [1 Inf], ...
                'RoundFractionalValues', 'on', 'Tag', ['ConvN' name]) ;
            n.Tooltip = 'Number of tanks used by the tanks-in-series RTD model.' ;
            uilabel(modelGrid, 'Text', '$Bo$', 'Interpreter', 'latex') ;
            bo = uieditfield(modelGrid, 'numeric', 'Value', 0.1, 'Limits', [eps Inf], ...
                'Tag', ['ConvBo' name]) ;
            bo.Tooltip = 'Axial dispersion number used by the dispersion RTD model.' ;
            obj.Signals.(name) = struct('Tab', tab, 'Grid', grid, ...
                'Description', description, 'Source', source, ...
                'TimeUnit', timeUnit, 'ConcentrationUnit', concentrationUnit, ...
                'Table', tableInput, 'PieceLabel', pieceLabel, ...
                'FunctionGrid', functionGrid, 'PiecewiseTable', pieceTable, ...
                'TableButtons', tableButtons, 'AddRow', addRow, ...
                'RemoveRow', removeRow, 'ImportButton', importButton, ...
                'ModelGrid', modelGrid, ...
                'Model', model, 'Tau', tau, 'N', n, 'Bo', bo) ;
        end

        function modeChanged(obj, clearPrevious)
            if nargin < 2, clearPrevious = false ; end
            mode = obj.ModeGroup.SelectedObject.Text ;
            visibleNames = obj.activeSignalNames(mode) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                if any(strcmp(names{k}, visibleNames))
                    obj.Signals.(names{k}).Tab.Parent = obj.SignalTabs ;
                else
                    obj.Signals.(names{k}).Tab.Parent = obj.HiddenSignalTabs ;
                end
                obj.Signals.(names{k}).Description.Text = obj.signalDescription(names{k}) ;
            end
            obj.SignalTabs.SelectedTab = obj.Signals.(visibleNames{1}).Tab ;
            isDeconvolution = strcmp(mode, 'Deconvolution') ;
            obj.SupportPanel.Visible = obj.onOff(isDeconvolution) ;
            controls = obj.SupportPanel.Parent ;
            if isDeconvolution
                controls.RowHeight{4} = 168 ;
            else
                controls.RowHeight{4} = 0 ;
            end
            obj.configureResultLayout(mode) ;
            obj.ResultsDescription.Text = obj.resultDescription(mode) ;
            obj.configureUseButton(mode) ;
            if clearPrevious
                obj.LastSignals = struct() ;
                obj.LastResult = [] ;
                obj.LastInfo = struct() ;
                obj.clearResults() ;
            end
        end

        function sourceChanged(obj, name)
            ui = obj.Signals.(name) ;
            source = ui.Source.Value ;
            ui.Table.Visible = obj.onOff(strcmp(source, 'Table')) ;
            ui.TableButtons.Visible = obj.onOff(any(strcmp(source, {'Table', 'Function'}))) ;
            ui.ImportButton.Visible = obj.onOff(strcmp(source, 'Table')) ;
            isFunction = strcmp(source, 'Function') ;
            ui.FunctionGrid.Visible = obj.onOff(isFunction) ;
            ui.ModelGrid.Visible = obj.onOff(strcmp(source, 'Model')) ;
            if strcmp(source, 'Table')
                ui.Grid.RowHeight = {38, 26, 26, '1x', 26, 0, 0, 0, 0} ;
            elseif strcmp(source, 'Function')
                ui.Grid.RowHeight = {38, 26, 26, '1x', 26, 0, 0, 0, 0} ;
            elseif strcmp(source, 'Model')
                ui.Grid.RowHeight = {38, 26, 26, 0, 0, 0, 0, '1x', '1x'} ;
            else
                ui.Grid.RowHeight = {38, 26, 26, 0, 0, 0, 0, 0, 0} ;
            end
            obj.modelChanged(name) ;
        end

        function modelChanged(obj, name)
            ui = obj.Signals.(name) ;
            ui.N.Enable = obj.onOff(strcmp(ui.Model.Value, 'Tanks-in-Series')) ;
            ui.Bo.Enable = obj.onOff(strcmp(ui.Model.Value, 'Dispersion')) ;
        end

        function supportEdited(obj)
            obj.SupportIsDefault = false ;
        end

        function suggestSupport(obj)
            previousValues = [obj.SupportMin.Value obj.SupportMax.Value] ;
            try
                [signals, dt] = obj.buildSignals({'Cin', 'Cout'}) ;
                support = obj.widestCompatibleSupport(signals, dt) ;
                scale = UnitConverterHelper.factorToSI( ...
                    'Time', obj.SupportUnit.Value) ;
                obj.SupportMin.Value = support(1) / scale ;
                obj.SupportMax.Value = support(2) / scale ;
                obj.SupportIsDefault = false ;
                obj.SetStatus(sprintf( ...
                    'Suggested E support: tau_min = %.6g %s, tau_max = %.6g %s. Values remain editable.', ...
                    obj.SupportMin.Value, obj.SupportUnit.Value, ...
                    obj.SupportMax.Value, obj.SupportUnit.Value)) ;
            catch exception
                obj.SupportMin.Value = previousValues(1) ;
                obj.SupportMax.Value = previousValues(2) ;
                obj.SetStatus(['Cannot suggest E support: ' exception.message]) ;
            end
        end

        function regularizationChanged(obj,refresh)
            if nargin < 2, refresh = true ; end
            enabled = strcmp(obj.Regularization.Value,'Tikhonov') ;
            obj.Smoothing.Enable = obj.onOff(enabled) ;
            obj.LambdaMode.Enable = obj.onOff(enabled) ;
            obj.LambdaValue.Enable = obj.onOff(enabled && ...
                strcmp(obj.LambdaMode.Value,'Manual')) ;
            obj.LowerPlot.Enable = obj.onOff(enabled && ...
                strcmp(obj.LambdaMode.Value,'Auto (L-curve)')) ;
            if ~enabled || strcmp(obj.LambdaMode.Value,'Manual')
                obj.LowerPlot.Value = 'Reconvolution check' ;
            end
            if refresh, obj.refreshPresentation() ; end
        end

        function options = deconvolutionRegularization(obj)
            options = struct('lambda',0,'smoothing',obj.Smoothing.Value) ;
            if ~strcmp(obj.Regularization.Value,'Tikhonov'), return, end
            if strcmp(obj.LambdaMode.Value,'Auto (L-curve)')
                options.lambda = 'auto' ;
            else
                options.lambda = obj.LambdaValue.Value ;
            end
        end

        function support = deconvolutionSupport(obj, signals, dt)
            scale = UnitConverterHelper.factorToSI('Time', obj.SupportUnit.Value) ;
            if obj.SupportIsDefault
                support = obj.widestCompatibleSupport(signals, dt) ;
                obj.SupportMin.Value = support(1) / scale ;
                obj.SupportMax.Value = support(2) / scale ;
            else
                support = [obj.SupportMin.Value obj.SupportMax.Value] * scale ;
            end
            if support(2) < support(1)
                error('NonIdealReactorApp:ConvolutionSupport', ...
                    'E support requires tau_max >= tau_min.') ;
            end
            intervals = (support(2)-support(1))/dt ;
            if abs(intervals-round(intervals)) > 1e-9*max(1,abs(intervals))
                error('NonIdealReactorApp:ConvolutionSupport', ...
                    'E support endpoints must lie on the common time-step grid.') ;
            end
        end

        function support = widestCompatibleSupport(~, signals, dt)
            supportMin = max(0, signals.Cout.t(1) - signals.Cin.t(end)) ;
            supportMax = signals.Cout.t(end) - signals.Cin.t(1) ;
            if supportMax < supportMin
                error('NonIdealReactorApp:ConvolutionSupport', ...
                    'The signal windows do not define a nonnegative E support.') ;
            end
            intervals = (supportMax - supportMin) / dt ;
            tolerance = 1e-9 * max(1, abs(intervals)) ;
            if abs(intervals - round(intervals)) <= tolerance
                intervalCount = round(intervals) ;
            else
                intervalCount = floor(intervals) ;
            end
            adjustedMax = supportMin + intervalCount * dt ;
            support = [supportMin min(adjustedMax, supportMax)] ;
        end

        function configureUseButton(obj, mode)
            hasResult = isstruct(obj.LastResult) && isfield(obj.LastResult, 't') ;
            if strcmp(mode, 'Convolution')
                obj.UseRTDButton.Visible = 'on' ;
                obj.UseRTDButton.Enable = obj.onOff(hasResult) ;
                obj.UseRTDButton.Text = 'Use C_out as tracer response in Tab 1' ;
                obj.UseRTDButton.Tooltip = ['C_out is the response to the given C_in; ' ...
                    'it equals the RTD only if C_in is an ideal pulse.'] ;
            elseif strcmp(mode, 'Deconvolution')
                obj.UseRTDButton.Visible = 'on' ;
                obj.UseRTDButton.Text = 'Use Ê(t) as RTD in Tab 1' ;
                [qualityPassed, tooltip] = obj.deconvolutionRTDQuality() ;
                obj.UseRTDButton.Enable = obj.onOff(hasResult && qualityPassed) ;
                obj.UseRTDButton.Tooltip = tooltip ;
            end
        end

        function compute(obj)
            try
                obj.SetStatus('Computing convolution workflow...') ;
                mode = obj.ModeGroup.SelectedObject.Text ;
                if strcmp(mode, 'Convolution')
                    names = {'Cin', 'E'} ;
                elseif strcmp(mode, 'Deconvolution')
                    names = {'Cin', 'Cout'} ;
                end
                [signals, dt, wasResampled, usedDefaultStep] = obj.buildSignals(names) ;
                if strcmp(mode, 'Convolution')
                    [obj.LastResult, obj.LastInfo] = nirp.conv.convolve(signals.E, signals.Cin) ;
                elseif strcmp(mode, 'Deconvolution')
                    support = obj.deconvolutionSupport(signals, dt) ;
                    [obj.LastResult, obj.LastInfo] = nirp.conv.deconvolve( ...
                        signals.Cin, signals.Cout, support, ...
                        obj.deconvolutionRegularization()) ;
                    obj.LastInfo.relativeResidual = obj.LastInfo.residualNorm / ...
                        max(norm(signals.Cout.C), eps) ;
                    signals.E = obj.LastResult ;
                    signals.Reconvolved = obj.LastInfo.reconvolved ;
                    if obj.LastInfo.lambdaSelectedAutomatically
                        obj.LowerPlot.Value = 'L-curve' ;
                    end
                end
                obj.LastSignals = signals ;
                obj.showResults() ;
                if usedDefaultStep
                    status = sprintf( ...
                        'Ready - automatic default dt = %.6g s (200 intervals over the Function domain).', ...
                        dt) ;
                elseif wasResampled
                    status = sprintf('Ready - signals resampled to dt = %.6g s.', dt) ;
                else
                    status = sprintf('Ready - common dt = %.6g s.', dt) ;
                end
                if strcmp(mode, 'Deconvolution') && obj.LastInfo.underdetermined
                    status = sprintf(['%s Underdetermined problem: %d E samples ' ...
                        'from %d measured values; review the E support.'], status, ...
                        obj.LastInfo.numberOfUnknowns, obj.LastInfo.numberOfEquations) ;
                end
                obj.SetStatus(status) ;
            catch exception
                obj.SetStatus(['Convolution error: ' exception.message]) ;
                ancestorFigure = ancestor(obj.Tab, 'figure') ;
                if strcmp(ancestorFigure.Visible, 'on')
                    uialert(ancestorFigure, exception.message, 'Convolution Error') ;
                else
                    rethrow(exception) ;
                end
            end
        end

        function [signals, dt, wasResampled, usedDefaultStep] = buildSignals(obj, names)
            raw = struct() ; steps = [] ;
            for k = 1:numel(names)
                name = names{k} ;
                if ~strcmp(obj.Signals.(name).Source.Value, 'Table')
                    continue
                end
                raw.(name) = obj.buildRawSignal(name, []) ;
                differences = diff(raw.(name).t) ;
                steps(end + 1) = min(differences) ; %#ok<AGROW>
            end
            requestedDt = obj.DtField.Value * ...
                UnitConverterHelper.factorToSI('Time', obj.DtUnit.Value) ;
            usedDefaultStep = false ;
            if requestedDt > 0
                dt = requestedDt ;
            elseif ~isempty(steps)
                dt = min(steps) ;
            else
                dt = obj.defaultFunctionStep(names) ;
                usedDefaultStep = true ;
            end
            signals = struct() ; wasResampled = false ;
            for k = 1:numel(names)
                name = names{k} ;
                if isfield(raw, name)
                    signal = raw.(name) ;
                else
                    signal = obj.buildRawSignal(name, dt) ;
                end
                differences = diff(signal.t) ;
                tolerance = 1e-9 * max(1, dt) ;
                needsResample = any(abs(differences - dt) > tolerance) ;
                if needsResample
                    signal = nirp.conv.resample(signal, dt) ;
                    wasResampled = true ;
                end
                signals.(name) = signal ;
            end
        end

        function signal = buildRawSignal(obj, name, targetDt)
            ui = obj.Signals.(name) ;
            scale = UnitConverterHelper.factorToSI('Time', ui.TimeUnit.Value) ;
            valueScale = obj.inputValueScale(name, ui, scale) ;
            switch ui.Source.Value
                case 'Table'
                    values = obj.numericTable(ui.Table.Data, 2, name) ;
                    signal = nirp.conv.signal(values(:, 1)' * scale, ...
                        values(:, 2)' * valueScale) ;
                case 'Function'
                    signal = obj.buildPiecewise(ui.PiecewiseTable.Data, scale, ...
                        valueScale, targetDt, name) ;
                case 'RTD from tab 1'
                    rtd = obj.GetRTD() ;
                    if isempty(rtd) || ~isa(rtd, 'RTD')
                        error('NonIdealReactorApp:ConvolutionMissingRTD', ...
                            'Generate or load an RTD in tab 1 first.') ;
                    end
                    signal = nirp.conv.fromRTD(rtd, targetDt) ;
                case 'Model'
                    tau = ui.Tau.Value * scale ;
                    switch ui.Model.Value
                        case 'CSTR'
                            rtd = RTD.ideal_cstr(tau) ;
                        case 'PFR'
                            rtd = RTD.ideal_pfr(tau) ;
                        case 'Tanks-in-Series'
                            rtd = RTD.tanks_in_series(round(ui.N.Value), tau) ;
                        otherwise
                            rtd = RTD.dispersion_closed(ui.Bo.Value, tau) ;
                    end
                    signal = nirp.conv.fromRTD(rtd, targetDt) ;
                otherwise
                    error('NonIdealReactorApp:ConvolutionSource', 'Unknown signal source.') ;
            end
        end

        function signal = buildPiecewise(obj, data, scale, valueScale, targetDt, name)
            values = obj.cellTable(data, 3) ;
            segments = struct('first', {}, 'last', {}, 'handle', {}) ;
            for row = 1:size(values, 1)
                if all(cellfun(@(v) obj.isBlank(v), values(row, :)))
                    continue
                end
                first = obj.parseScalar(values{row, 1}) * scale ;
                last = obj.parseScalar(values{row, 2}) * scale ;
                if last <= first
                    error('NonIdealReactorApp:ConvolutionPiecewiseRange', ...
                        '%s Function rows require To t > From t.', name) ;
                end
                userHandle = obj.expressionHandle(values{row, 3}) ;
                segments(end + 1) = struct('first', first, 'last', last, ...
                    'handle', @(seconds) userHandle(seconds / scale) * valueScale) ; %#ok<AGROW>
            end
            if isempty(segments)
                error('NonIdealReactorApp:ConvolutionEmptyPiecewise', ...
                    '%s requires at least one complete Function row.', name) ;
            end
            [~, order] = sort([segments.first]) ; segments = segments(order) ;
            edges = segments(1).first ; handles = {} ;
            for k = 1:numel(segments)
                if segments(k).first < edges(end)
                    error('NonIdealReactorApp:ConvolutionOverlap', ...
                        '%s Function intervals cannot overlap.', name) ;
                elseif segments(k).first > edges(end)
                    edges(end + 1) = segments(k).first ; %#ok<AGROW>
                    handles{end + 1} = @(t) zeros(size(t)) ; %#ok<AGROW>
                end
                edges(end + 1) = segments(k).last ; %#ok<AGROW>
                handles{end + 1} = segments(k).handle ; %#ok<AGROW>
            end
            if isempty(targetDt), targetDt = (edges(end) - edges(1)) / 200 ; end
            t = edges(1):targetDt:edges(end) ;
            if numel(t) < 2 || t(end) < edges(end), t(end + 1) = edges(end) ; end
            signal = nirp.conv.piecewise(edges, handles, t) ;
        end

        function showResults(obj)
            result = obj.LastResult ;
            timeScale = UnitConverterHelper.factorToSI('Time', obj.OutputTimeUnit.Value) ;
            concentrationScale = UnitConverterHelper.factorToSI( ...
                'Concentration', obj.OutputConcentrationUnit.Value) ;
            mode = obj.ModeGroup.SelectedObject.Text ;
            timeUnit = obj.OutputTimeUnit.Value ;
            concentrationUnit = obj.OutputConcentrationUnit.Value ;
            resultValues = result.C ;
            resultIsRTD = strcmp(mode, 'Deconvolution') ;
            if resultIsRTD
                resultValues = resultValues * timeScale ;
                valueHeading = ['Ê(t) [' timeUnit '⁻¹]'] ;
            else
                resultValues = resultValues / concentrationScale ;
                valueHeading = ['Cₒᵤₜ(t) [' concentrationUnit ']'] ;
            end
            obj.ResultTable.ColumnName = {['t [' timeUnit ']'], valueHeading} ;
            obj.ResultTable.Data = [result.t(:) / timeScale, resultValues(:)] ;
            obj.configureResultLayout(mode) ;
            obj.clearMeanTimes() ;
            cla(obj.Axes) ; cla(obj.VerificationAxes) ;
            if strcmp(mode, 'Convolution')
                hold(obj.Axes, 'on') ;
                cinLine = obj.plotSignal(obj.Axes, obj.LastSignals.Cin, false, ...
                    timeScale, concentrationScale, '$C_{\mathrm{in}}(t)$') ;
                eLine = obj.plotSignal(obj.Axes, obj.LastSignals.E, true, ...
                    timeScale, concentrationScale, '$E(t)$') ;
                coutLine = obj.plotSignal(obj.Axes, result, false, timeScale, ...
                    concentrationScale, '$C_{\mathrm{out}}(t)$', 1.6) ;
                obj.plotMeanTime(obj.Axes, obj.LastSignals.Cin, timeScale, ...
                    cinLine.Color, '$\bar{t}_{\mathrm{in}}$') ;
                obj.plotMeanTime(obj.Axes, obj.LastSignals.E, timeScale, ...
                    eLine.Color, '$\tau_E$') ;
                obj.plotMeanTime(obj.Axes, result, timeScale, ...
                    coutLine.Color, '$\bar{t}_{\mathrm{out}}$') ;
                hold(obj.Axes, 'off') ;
                momentRows = obj.momentRows( ...
                    {'Cᵢₙ', 'E', 'Cₒᵤₜ'}, ...
                    {obj.LastSignals.Cin, obj.LastSignals.E, result}, ...
                    [false true false], timeScale, concentrationScale) ;
                displayedResult = strrep(mat2str(resultValues, 6), ' ', ',\;') ;
                obj.setResultRows({ ...
                    '$C_{\mathrm{out}}(t)$', ...
                    '$m_{\mathrm{out}}/(m_{\mathrm{in}}A_E)$'}, { ...
                    ['$' displayedResult '\;\mathrm{' ...
                    obj.latexUnit(concentrationUnit) '}$'], ...
                    ['$' sprintf('%.6g', obj.LastInfo.massBalance) '$']}) ;
            elseif strcmp(mode, 'Deconvolution')
                hold(obj.Axes, 'on') ;
                eLine = obj.plotSignal(obj.Axes, result, true, timeScale, ...
                    concentrationScale, '$\widehat{E}(t)$', 1.6) ;
                obj.plotMeanTime(obj.Axes, result, timeScale, eLine.Color, ...
                    '$\tau_{\widehat{E}}$') ;
                hold(obj.Axes, 'off') ;
                obj.plotDeconvolutionCheck(timeScale,concentrationScale) ;
                momentRows = {} ;
                moments = nirp.conv.moments(result) ;
                relativeResidual = obj.relativeResidual() ;
                sigmaTheta = moments.variance / max(moments.mean^2, eps) ;
                equivalentTanks = 1 / max(sigmaTheta, eps) ;
                if relativeResidual < 0.05
                    fitReading = 'good fit' ;
                elseif relativeResidual <= 0.15
                    fitReading = 'acceptable' ;
                else
                    fitReading = 'check data or E support' ;
                end
                warnings = {} ;
                if abs(moments.area - 1) > 0.05
                    warnings{end + 1} = ['$\mathbf{Warning:\ A_E\ne1;}\ ' ...
                        '\mathrm{RTD\ not\ normalized;\ Tab\ 1\ normalizes\ it.}$'] ;
                end
                if obj.LastInfo.underdetermined
                    warnings{end + 1} = ['$\mathbf{Underdetermined:}\ ' ...
                        num2str(obj.LastInfo.numberOfUnknowns) ...
                        '\ \mathrm{E\ samples,}\ ' ...
                        num2str(obj.LastInfo.numberOfEquations) ...
                        '\ \mathrm{measurements;}\ ' ...
                        '\mathrm{review\ the\ E\ support.}$'] ;
                end
                selectedLambda = obj.getField(obj.LastInfo,'lambda',0) ;
                selectedAutomatically = obj.getField( ...
                    obj.LastInfo,'lambdaSelectedAutomatically',false) ;
                lambdaReading = sprintf('%.6g',selectedLambda) ;
                if selectedAutomatically
                    lambdaReading = [lambdaReading ' (L-curve)'] ;
                end
                resultLabels = { ...
                    '$A_E$', '$\tau$', '$\sigma^2$', '$\sigma_\theta^2$', ...
                    '$N\simeq1/\sigma_\theta^2$'} ;
                resultValues = { ...
                    ['$' sprintf('%.6g', moments.area) '$'], ...
                    ['$' sprintf('%.6g', moments.mean / timeScale) ...
                    '\;\mathrm{' obj.latexUnit(timeUnit) '}$'], ...
                    ['$' sprintf('%.6g', moments.variance / timeScale^2) ...
                    '\;\mathrm{' obj.latexUnit(timeUnit) '^2}$'], ...
                    ['$' sprintf('%.6g', sigmaTheta) '$'], ...
                    ['$' sprintf('%.6g', equivalentTanks) '$']} ;
                if strcmp(obj.Regularization.Value, 'Tikhonov')
                    resultLabels{end + 1} = '$\lambda$' ;
                    resultValues{end + 1} = ['$' lambdaReading '$'] ;
                end
                resultLabels{end + 1} = '$\mathrm{Relative\ residual}$' ;
                resultValues{end + 1} = ...
                    ['$' sprintf('%.2f', relativeResidual * 100) '\%$'] ;
                obj.setResultRows(resultLabels, resultValues, ...
                    strjoin(warnings, newline)) ;
                if strcmp(obj.Regularization.Value, 'Tikhonov')
                    lambdaIndex = 6 ;
                    obj.ResultValues{lambdaIndex}.Interpreter = 'none' ;
                    obj.ResultValues{lambdaIndex}.Text = ['= ' lambdaReading] ;
                end
                residualIndex = numel(resultLabels) ;
                obj.ResultLabels{residualIndex}.Layout.Row = 4 ;
                obj.ResultLabels{residualIndex}.Layout.Column = 1 ;
                obj.ResultValues{residualIndex}.Layout.Row = 4 ;
                obj.ResultValues{residualIndex}.Layout.Column = [2 6] ;
                obj.ResultValues{residualIndex}.Interpreter = 'none' ;
                obj.ResultValues{residualIndex}.Text = sprintf('= %.2f%% (%s)', ...
                    relativeResidual * 100, fitReading) ;
                obj.ResultLabels{1}.Parent.RowHeight{4} = 20 ;
            end
            obj.decorateAxes(mode, timeUnit) ;
            obj.MomentsTable.ColumnName = {'Signal', 'Area', ...
                ['τ [' timeUnit ']'], ['σ² [' timeUnit '²]']} ;
            obj.MomentsTable.Data = momentRows ;
            obj.ExportButton.Enable = 'on' ;
            obj.configureUseButton(mode) ;
        end

        function clearResults(obj)
            obj.clearMeanTimes() ;
            cla(obj.Axes) ; cla(obj.VerificationAxes) ;
            obj.ResultTable.Data = [] ; obj.MomentsTable.Data = {} ;
            obj.setResultRows({'$\mathrm{Status}$'}, {'$\mathrm{No\ result.}$'}) ;
            obj.ExportButton.Enable = 'off' ;
            obj.UseRTDButton.Enable = 'off' ;
        end

        function export(obj)
            exported = obj.LastSignals ;
            exported.result = obj.LastResult ;
            exported.info = obj.portableInfo() ;
            exported.mode = obj.ModeGroup.SelectedObject.Text ;
            exported.units = struct('time', obj.OutputTimeUnit.Value, ...
                'concentration', obj.OutputConcentrationUnit.Value) ;
            assignin('base', 'convolutionResult', exported) ;
            obj.SetStatus('Exported convolutionResult to the base workspace.') ;
        end

        function useAsRTD(obj)
            if ~isstruct(obj.LastResult) || ~isfield(obj.LastResult, 't')
                return
            end
            mode = obj.ModeGroup.SelectedObject.Text ;
            if strcmp(mode, 'Convolution')
                obj.SetTracer(obj.LastResult) ;
                obj.SetStatus(['C_out loaded as the Tab 1 pulse-response data. ' ...
                    'It is an RTD only for an ideal-pulse C_in.']) ;
            elseif strcmp(mode, 'Deconvolution')
                [qualityPassed, tooltip, quality] = obj.deconvolutionRTDQuality() ;
                if ~qualityPassed
                    obj.UseRTDButton.Enable = 'off' ;
                    obj.UseRTDButton.Tooltip = tooltip ;
                    return
                end
                if ~obj.confirmEstimatedRTD(quality)
                    return
                end
                obj.SetRTD(obj.LastResult, mode) ;
                obj.SetStatus(['Estimated RTD loaded: estimated by deconvolution ' ...
                    '(Tab 6), normalized and treated as the Tab 1 RTD.']) ;
            end
        end

        function [passed, tooltip, quality] = deconvolutionRTDQuality(obj)
            quality = struct('area', NaN, 'relativeResidual', NaN, ...
                'support', [NaN NaN], 'usedTikhonov', false, 'lambda', NaN) ;
            if ~isstruct(obj.LastResult) || ~isfield(obj.LastResult, 't') || ...
                    ~isstruct(obj.LastSignals) || ~isfield(obj.LastSignals, 'Cout') || ...
                    ~strcmp(obj.ModeGroup.SelectedObject.Text, 'Deconvolution')
                passed = false ;
                tooltip = ['Compute a deconvolution before loading the estimated ' ...
                    'E(t) into RTD Analysis.'] ;
                return
            end

            moments = nirp.conv.moments(obj.LastResult) ;
            quality.area = moments.area ;
            quality.relativeResidual = obj.relativeResidual() ;
            quality.support = obj.getField(obj.LastInfo, 'support', ...
                obj.LastResult.t([1 end])) ;
            quality.lambda = obj.getField(obj.LastInfo, 'lambda', 0) ;
            quality.usedTikhonov = isfinite(quality.lambda) && quality.lambda > 0 ;
            areaPassed = isfinite(quality.area) && abs(quality.area - 1) <= 0.05 ;
            residualPassed = isfinite(quality.relativeResidual) && ...
                quality.relativeResidual <= 0.15 ;
            passed = areaPassed && residualPassed ;
            if passed
                tooltip = sprintf(['Quality checks passed: A_E = %.6g and relative ' ...
                    'reconvolution residual = %.2f%%. Confirm to normalize the ' ...
                    'estimate and load it into RTD Analysis.'], quality.area, ...
                    100 * quality.relativeResidual) ;
                return
            end

            failures = {} ;
            if ~areaPassed
                failures{end + 1} = sprintf( ...
                    'A_E = %.6g (requires |A_E - 1| <= 5%%)', quality.area) ; %#ok<AGROW>
            end
            if ~residualPassed
                failures{end + 1} = sprintf( ...
                    ['relative reconvolution residual = %.2f%% ' ...
                    '(requires <= 15%%)'], 100 * quality.relativeResidual) ; %#ok<AGROW>
            end
            tooltip = ['Cannot use estimated E(t): ' strjoin(failures, '; ') '.'] ;
        end

        function confirmed = confirmEstimatedRTD(obj, quality)
            if quality.usedTikhonov
                tikhonov = sprintf('Yes (lambda = %.6g)', quality.lambda) ;
            else
                tikhonov = 'No' ;
            end
            message = sprintf([ ...
                'A_E = %.6g\n' ...
                'Relative reconvolution residual = %.2f%%\n' ...
                'Support [tau_min, tau_max] = [%.6g, %.6g] s\n' ...
                'Tikhonov used: %s\n\n' ...
                'Ê is an estimate; it will be normalized and treated as the Tab 1 RTD.'], ...
                quality.area, 100 * quality.relativeResidual, quality.support(1), ...
                quality.support(2), tikhonov) ;
            overrideName = 'NirpDeconvolutionRTDConfirmOverride' ;
            if isappdata(groot, overrideName)
                override = getappdata(groot, overrideName) ;
                if ~isa(override, 'function_handle')
                    error('ConvolutionTabHelper:InvalidConfirmationOverride', ...
                        'The deconvolution RTD confirmation override must be a function handle.') ;
                end
                choice = override(message) ;
            else
                choice = uiconfirm(ancestor(obj.Tab, 'figure'), message, ...
                    'Use estimated RTD in Tab 1?', ...
                    'Options', {'Use RTD', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, 'Icon', 'warning') ;
            end
            confirmed = strcmp(char(string(choice)), 'Use RTD') ;
        end

        function values = numericTable(obj, data, columns, name)
            cells = obj.cellTable(data, columns) ; values = zeros(0, columns) ;
            for row = 1:size(cells, 1)
                if all(cellfun(@(v) obj.isBlank(v), cells(row, :)))
                    continue
                end
                parsed = zeros(1, columns) ;
                for column = 1:columns
                    parsed(column) = obj.parseScalar(cells{row, column}) ;
                end
                values(end + 1, :) = parsed ; %#ok<AGROW>
            end
            if size(values, 1) < 2
                error('NonIdealReactorApp:ConvolutionTable', ...
                    '%s table requires at least two complete numeric rows.', name) ;
            end
        end

        function cells = cellTable(~, data, columns)
            if istable(data), data = table2cell(data) ; end
            if isnumeric(data), data = num2cell(data) ; end
            if ~iscell(data), data = cell(0, columns) ; end
            if size(data, 2) < columns, data(:, end + 1:columns) = {''} ; end
            cells = data(:, 1:columns) ;
        end

        function value = parseScalar(~, raw)
            if isnumeric(raw) && isscalar(raw), value = double(raw) ;
            else, value = InputLayerHelper.parseArithmeticExpression(char(string(raw))) ; end
            if ~isfinite(value)
                error('NonIdealReactorApp:ConvolutionNumber', 'Signal values must be finite.') ;
            end
        end

        function value = isBlank(~, raw)
            value = isempty(raw) || (isnumeric(raw) && isscalar(raw) && isnan(raw)) ;
            if ~value && (ischar(raw) || isstring(raw))
                value = strlength(strtrim(string(raw))) == 0 ;
            end
        end

        function f = expressionHandle(~, expression)
            expression = strtrim(char(string(expression))) ;
            if isempty(expression)
                error('NonIdealReactorApp:ConvolutionExpression', ...
                    'Signal expressions cannot be empty.') ;
            end
            try
                f = str2func(['@(t) ' expression]) ;
                probe = f([0 1]) ;
                if ~(isnumeric(probe) && isreal(probe) && all(isfinite(probe(:))))
                    error('Expression returned invalid values.') ;
                end
            catch exception
                error('NonIdealReactorApp:ConvolutionExpression', ...
                    'Invalid expression in t: %s', exception.message) ;
            end
        end

        function values = displayMoments(~, signal, isRTD, timeScale, concentrationScale)
            values = nirp.conv.moments(signal) ;
            if ~isRTD
                values.area = values.area / (timeScale * concentrationScale) ;
            end
            values.mean = values.mean / timeScale ;
            values.variance = values.variance / timeScale^2 ;
        end

        function configureResultLayout(obj, mode)
            obj.VerificationAxes.Visible = obj.onOff(strcmp(mode, 'Deconvolution')) ;
            if strcmp(mode, 'Deconvolution')
                obj.ResultsGrid.RowHeight = {'1x', '1x', '0.7x', 0, 190} ;
                obj.MomentsTable.Visible = 'off' ;
            else
                obj.ResultsGrid.RowHeight = {'2x', 0, '1x', 104, 156} ;
                obj.MomentsTable.Visible = 'on' ;
            end
        end

        function setResultRows(obj, labels, values, warningText)
            if nargin < 4, warningText = '' ; end
            grid = obj.ResultLabels{1}.Parent ;
            pairRows = max(1, ceil(numel(labels) / 3)) ;
            for k = 1:numel(obj.ResultLabels)
                visible = k <= numel(labels) ;
                obj.ResultLabels{k}.Visible = obj.onOff(visible) ;
                obj.ResultValues{k}.Visible = obj.onOff(visible) ;
                if visible
                    obj.ResultLabels{k}.Text = labels{k} ;
                    obj.ResultValues{k}.Interpreter = 'latex' ;
                    obj.ResultValues{k}.Text = ['$=\;' values{k}(2:end)] ;
                    pairRow = 1 + ceil(k / 3) ;
                    pairColumn = 1 + 2 * mod(k - 1, 3) ;
                    obj.ResultLabels{k}.Layout.Row = pairRow ;
                    obj.ResultLabels{k}.Layout.Column = pairColumn ;
                    obj.ResultValues{k}.Layout.Row = pairRow ;
                    obj.ResultValues{k}.Layout.Column = pairColumn + 1 ;
                else
                    obj.ResultLabels{k}.Text = '' ;
                    obj.ResultValues{k}.Text = '' ;
                end
            end
            hasWarning = ~isempty(warningText) ;
            obj.DiagnosticsLabel.Text = warningText ;
            obj.DiagnosticsLabel.Visible = obj.onOff(hasWarning) ;
            grid.RowHeight = [{34}, repmat({20}, 1, pairRows), ...
                repmat({0}, 1, 3 - pairRows), {0}] ;
            if hasWarning, grid.RowHeight{5} = 44 ; end
        end

        function text = resultDescription(~, mode)
            if strcmp(mode, 'Convolution')
                text = ['$\mathrm{Areas\ check\ the\ tracer\ balance}\ ' ...
                    '(A_{\mathrm{out}}=A_{\mathrm{in}}A_E);\ ' ...
                    '\bar{t}_{\mathrm{out}}=\bar{t}_{\mathrm{in}}+\tau_E\ ' ...
                    '\mathrm{and}\ \sigma_{\mathrm{out}}^2=' ...
                    '\sigma_{\mathrm{in}}^2+\sigma_E^2\ ' ...
                    '\mathrm{verify\ the\ result.}$'] ;
            elseif strcmp(mode, 'Deconvolution')
                text = ['$A_E\ \mathrm{is\ area,}\ \tau\ \mathrm{is\ mean\ time,}\ ' ...
                    '\sigma^2\ \mathrm{is\ variance,\ and}\ \sigma_\theta^2\ ' ...
                    '\mathrm{gives}\ N\simeq1/\sigma_\theta^2;\ ' ...
                    '\mathrm{the\ residual\ rates\ the\ fit\ in\ the\ measured\ window.}$'] ;
            end
        end

        function value = relativeResidual(obj)
            value = obj.getField(obj.LastInfo, 'relativeResidual', []) ;
            if ~isempty(value), return, end
            residual = obj.getField(obj.LastInfo, 'residual', []) ;
            value = norm(residual) / max(norm(obj.LastSignals.Cout.C), eps) ;
        end

        function info = portableInfo(obj)
            info = obj.LastInfo ;
            if ~strcmp(obj.ModeGroup.SelectedObject.Text, 'Deconvolution') || ...
                    ~isstruct(info) || isempty(fieldnames(info))
                return
            end
            info.relativeResidual = obj.relativeResidual() ;
            obsolete = intersect(fieldnames(info), ...
                {'residualNorm'; 'massBalance'; 'regularizationMatrix'}) ;
            if ~isempty(obsolete), info = rmfield(info, obsolete) ; end
        end

        function line = plotSignal(~, axesControl, signal, isRTD, timeScale, ...
                concentrationScale, displayName, lineWidth)
            if nargin < 9, lineWidth = 1 ; end
            values = signal.C ;
            if isRTD
                values = values * timeScale ;
            else
                values = values / concentrationScale ;
            end
            line = plot(axesControl, signal.t / timeScale, values, ...
                'LineWidth', lineWidth, 'DisplayName', displayName) ;
        end

        function plotDeconvolutionCheck(obj,timeScale,concentrationScale)
            legendInterpreter = 'latex' ;
            if strcmp(obj.LowerPlot.Value,'L-curve') && ...
                    isfield(obj.LastInfo,'lCurve') && ...
                    ~isempty(obj.LastInfo.lCurve.lambda)
                curve = obj.LastInfo.lCurve ;
                loglog(obj.VerificationAxes,curve.residualNorm,curve.seminorm, ...
                    '-o','LineWidth',1,'MarkerSize',3, ...
                    'DisplayName','L-curve') ;
                hold(obj.VerificationAxes,'on') ;
                selected = curve.selectedIndex ;
                loglog(obj.VerificationAxes,curve.residualNorm(selected), ...
                    curve.seminorm(selected),'rp','MarkerSize',12, ...
                    'MarkerFaceColor','r','DisplayName', ...
                    sprintf('λ = %.3g',obj.LastInfo.lambda)) ;
                hold(obj.VerificationAxes,'off') ;
                obj.VerificationAxes.XScale = 'log' ;
                obj.VerificationAxes.YScale = 'log' ;
                title(obj.VerificationAxes,'L-curve','Interpreter','none') ;
                xlabel(obj.VerificationAxes,'$\|A\widehat{e}-c_{\mathrm{out}}\|_2$', ...
                    'Interpreter','latex') ;
                ylabel(obj.VerificationAxes,'$\|L\widehat{e}\|_2$', ...
                    'Interpreter','latex') ;
                legendInterpreter = 'none' ;
            else
                hold(obj.VerificationAxes, 'on') ;
                measuredLine = obj.plotSignal(obj.VerificationAxes, ...
                    obj.LastSignals.Cout, false, timeScale, concentrationScale, ...
                    '$C_{\mathrm{out,measured}}(t)$') ;
                measuredLine.LineStyle = 'none' ;
                measuredLine.Marker = 'o' ;
                obj.plotSignal(obj.VerificationAxes, ...
                    obj.LastSignals.Reconvolved, false, timeScale, ...
                    concentrationScale, '$C_{\mathrm{out,reconvolved}}(t)$', 1.6) ;
                residualValues = obj.LastInfo.residual / concentrationScale ;
                bar(obj.VerificationAxes, obj.LastSignals.Cout.t / timeScale, ...
                    residualValues, 0.35, ...
                    'DisplayName', '$C_{\mathrm{measured}}-C_{\mathrm{fit}}$', ...
                    'FaceAlpha', 0.35, 'EdgeColor', 'none') ;
                xlim(obj.VerificationAxes, ...
                    obj.LastSignals.Cout.t([1 end]) / timeScale) ;
                hold(obj.VerificationAxes, 'off') ;
                title(obj.VerificationAxes, ...
                    '$\mathrm{Reconvolution\ check}$', 'Interpreter', 'latex') ;
                xlabel(obj.VerificationAxes, ['$t\;[\mathrm{' ...
                    obj.latexUnit(obj.OutputTimeUnit.Value) '}]$'], ...
                    'Interpreter', 'latex') ;
                ylabel(obj.VerificationAxes, ['$C_{\mathrm{out}}\;[\mathrm{' ...
                    obj.latexUnit(obj.OutputConcentrationUnit.Value) '}]$'], ...
                    'Interpreter', 'latex') ;
            end
            legend(obj.VerificationAxes, 'show', 'Location', 'best', ...
                'Interpreter', legendInterpreter) ;
        end

        function plotMeanTime(~, axesControl, signal, timeScale, color, label)
            moments = nirp.conv.moments(signal) ;
            xline(axesControl, moments.mean / timeScale, '--', label, ...
                'Color', color, 'HandleVisibility', 'off', ...
                'Interpreter', 'latex', 'LineWidth', 1, ...
                'LabelOrientation', 'horizontal', 'FontSize', 10) ;
        end

        function clearMeanTimes(obj)
            delete(findall(obj.Axes, 'Type', 'ConstantLine')) ;
            delete(findall(obj.VerificationAxes, 'Type', 'ConstantLine')) ;
        end

        function rows = momentRows(obj, labels, signals, isRTD, ...
                timeScale, concentrationScale)
            if isscalar(isRTD), isRTD = repmat(isRTD, 1, numel(signals)) ; end
            rows = cell(numel(signals), 4) ;
            for k = 1:numel(signals)
                moments = obj.displayMoments(signals{k}, isRTD(k), ...
                    timeScale, concentrationScale) ;
                rows(k, :) = {labels{k}, moments.area, moments.mean, moments.variance} ;
            end
        end

        function decorateAxes(obj, mode, timeUnit)
            if strcmp(mode, 'Convolution')
                title(obj.Axes, ...
                    '$C_{\mathrm{out}}(t)=\int E(t^\prime)C_{\mathrm{in}}(t-t^\prime)\,dt^\prime$', ...
                    'Interpreter', 'latex') ;
                ylabel(obj.Axes, '$C(t),\ E(t)$', 'Interpreter', 'latex') ;
            elseif strcmp(mode, 'Deconvolution')
                title(obj.Axes, '$\mathrm{Estimated\ RTD}\ \widehat{E}(t)$', ...
                    'Interpreter', 'latex') ;
                ylabel(obj.Axes, ['$\widehat{E}(t)\;[\mathrm{' ...
                    obj.latexUnit(timeUnit) '^{-1}}]$'], 'Interpreter', 'latex') ;
                % The lower axes are decorated by plotDeconvolutionCheck.
            end
            xlabel(obj.Axes, ['$t\;[\mathrm{' obj.latexUnit(timeUnit) '}]$'], ...
                'Interpreter', 'latex') ;
            legend(obj.Axes, 'show', 'Location', 'best', 'Interpreter', 'latex') ;
        end

        function value = latexUnit(~, unit)
            value = strrep(char(string(unit)), '_', '\_') ;
        end

        function dt = defaultFunctionStep(obj, names)
            first = [] ; last = [] ;
            for k = 1:numel(names)
                ui = obj.Signals.(names{k}) ;
                if ~strcmp(ui.Source.Value, 'Function'), continue, end
                scale = UnitConverterHelper.factorToSI('Time', ui.TimeUnit.Value) ;
                values = obj.cellTable(ui.PiecewiseTable.Data, 3) ;
                for row = 1:size(values, 1)
                    if all(cellfun(@(v) obj.isBlank(v), values(row, :))), continue, end
                    first(end + 1) = obj.parseScalar(values{row, 1}) * scale ; %#ok<AGROW>
                    last(end + 1) = obj.parseScalar(values{row, 2}) * scale ; %#ok<AGROW>
                end
            end
            if isempty(first) || any(last <= first)
                error('NonIdealReactorApp:ConvolutionMissingStep', ...
                    'Automatic time step requires a valid Table or Function interval.') ;
            end
            dt = (max(last) - min(first)) / 200 ;
            if ~isfinite(dt) || dt <= 0
                error('NonIdealReactorApp:ConvolutionMissingStep', ...
                    'Automatic time step requires a positive Function domain.') ;
            end
        end

        function refreshPresentation(obj)
            if isstruct(obj.LastResult) && isfield(obj.LastResult, 't')
                obj.showResults() ;
            end
        end

        function scale = inputValueScale(obj, name, ui, timeScale)
            if obj.isRTDName(name)
                scale = 1 / timeScale ;
            else
                scale = UnitConverterHelper.factorToSI( ...
                    'Concentration', ui.ConcentrationUnit.Value) ;
            end
        end

        function value = isRTDName(~, name)
            value = strcmp(name, 'E') ;
        end

        function names = activeSignalNames(~, mode)
            names = {'Cin', 'E'} ;
            if strcmp(mode, 'Deconvolution')
                names = {'Cin', 'Cout'} ;
            end
        end

        function rememberSelection(~, tableControl, event)
            selectedRow = [] ;
            if ~isempty(event.Indices), selectedRow = event.Indices(1, 1) ; end
            tableControl.UserData = struct('selectedRow', selectedRow) ;
        end

        function addRow(obj, name)
            tableControl = obj.activeManualTable(name) ;
            columns = numel(tableControl.ColumnName) ;
            if tableControl == obj.Signals.(name).Table
                data = obj.cellTable(obj.numericEditorData( ...
                    tableControl.Data, columns), columns) ;
                data(end + 1, 1:columns) = {''} ;
            else
                data = obj.cellTable(tableControl.Data, columns) ;
                data(end + 1, 1:columns) = {''} ;
            end
            tableControl.Data = data ;
            tableControl.UserData = struct('selectedRow', []) ;
        end

        function removeRow(obj, name)
            tableControl = obj.activeManualTable(name) ;
            columns = numel(tableControl.ColumnName) ;
            isNumericEditor = tableControl == obj.Signals.(name).Table ;
            if isNumericEditor
                data = obj.cellTable(obj.numericEditorData( ...
                    tableControl.Data, columns), columns) ;
            else
                data = obj.cellTable(tableControl.Data, columns) ;
            end
            if size(data, 1) <= 1
                data = cell(1, columns) ;
            else
                selectedRow = [] ;
                if isstruct(tableControl.UserData) && isfield(tableControl.UserData, 'selectedRow')
                    selectedRow = tableControl.UserData.selectedRow ;
                end
                if isempty(selectedRow) || selectedRow < 1 || selectedRow > size(data, 1)
                    selectedRow = size(data, 1) ;
                end
                data(selectedRow, :) = [] ;
            end
            if isNumericEditor
                data = obj.numericEditorData(data, columns) ;
            end
            tableControl.Data = data ;
            tableControl.UserData = struct('selectedRow', []) ;
        end

        function tableControl = activeManualTable(obj, name)
            ui = obj.Signals.(name) ;
            if strcmp(ui.Source.Value, 'Function')
                tableControl = ui.PiecewiseTable ;
            else
                tableControl = ui.Table ;
            end
        end

        function importTable(obj, name, selectedFile)
            if nargin < 3 || isempty(selectedFile)
                [file, path] = uigetfile( ...
                    {'*.xlsx;*.xls;*.csv;*.tsv', 'Data files (*.xlsx, *.xls, *.csv, *.tsv)'; ...
                     '*.*', 'All files (*.*)'}, 'Select experimental data file') ;
                if isequal(file, 0), return, end
                fullPath = fullfile(path, file) ;
            else
                fullPath = char(string(selectedFile)) ;
                [~, baseName, extension] = fileparts(fullPath) ;
                file = [baseName extension] ;
            end
            try
                [~, ~, extension] = fileparts(file) ;
                switch lower(extension)
                    case {'.xlsx', '.xls'}
                        data = readmatrix(fullPath) ;
                    case '.csv'
                        data = readmatrix(fullPath, 'Delimiter', ',') ;
                    case '.tsv'
                        data = readmatrix(fullPath, 'Delimiter', '\t') ;
                    otherwise
                        data = readmatrix(fullPath) ;
                end
                if size(data, 2) < 2
                    error('NonIdealReactorApp:ConvolutionImportColumns', ...
                        'The file must have at least two columns (time and value).') ;
                end
                data = data(~any(isnan(data(:, 1:2)), 2), 1:2) ;
                if isempty(data)
                    error('NonIdealReactorApp:ConvolutionImportEmpty', ...
                        'The file contains no complete numeric time/value rows.') ;
                end
                obj.Signals.(name).Table.Data = data ;
                obj.SetStatus(sprintf('Imported %s: %d rows from %s.', ...
                    obj.displayName(name), size(data, 1), file)) ;
            catch exception
                ancestorFigure = ancestor(obj.Tab, 'figure') ;
                if strcmp(ancestorFigure.Visible, 'on')
                    uialert(ancestorFigure, exception.message, 'Import Error') ;
                else
                    rethrow(exception) ;
                end
            end
        end

        function tableCellEdited(obj, tableControl, event)
            cells = obj.cellTable(tableControl.Data, ...
                numel(tableControl.ColumnName)) ;
            row = event.Indices(1) ;
            column = event.Indices(2) ;
            try
                cells{row, column} = obj.parseScalar(event.NewData) ;
            catch exception
                cells{row, column} = event.PreviousData ;
                obj.SetStatus(['Invalid table value: ' exception.message]) ;
            end
            tableControl.Data = obj.numericEditorData(cells, ...
                numel(tableControl.ColumnName)) ;
        end

        function data = numericEditorData(obj, raw, columns)
            cells = obj.cellTable(raw, columns) ;
            values = nan(size(cells, 1), columns) ;
            blank = false(size(cells, 1), columns) ;
            for row = 1:size(cells, 1)
                for column = 1:columns
                    blank(row, column) = obj.isBlank(cells{row, column}) ;
                    if ~blank(row, column)
                        values(row, column) = obj.parseScalar(cells{row, column}) ;
                    end
                end
            end
            data = num2cell(values) ;
            data(blank) = {''} ;
        end

        function description = signalDescription(~, name)
            switch name
                case 'Cin'
                    description = ['$\mathrm{Inlet\ tracer\ concentration}\ ' ...
                        'C_{\mathrm{in}}(t)\mathrm{,\ used\ in\ convolution\ and\ deconvolution.}$'] ;
                case 'Cout'
                    description = ['$\mathrm{Measured\ outlet\ concentration}\ ' ...
                        'C_{\mathrm{out}}(t)\mathrm{,\ used\ to\ estimate}\ E(t).$'] ;
                case 'E'
                    description = ['$\mathrm{Residence\!\!\!-time\ distribution}\ ' ...
                        'E(t)\mathrm{,\ used\ in\ convolution.}$'] ;
            end
        end

        function selectMode(obj, mode)
            buttons = obj.ModeGroup.Children ;
            for k = 1:numel(buttons)
                if strcmp(buttons(k).Text, char(string(mode)))
                    obj.ModeGroup.SelectedObject = buttons(k) ; return
                end
            end
        end

        function setDropdown(~, dropdown, value)
            value = char(string(value)) ;
            if any(strcmp(cellstr(dropdown.Items), value)), dropdown.Value = value ; end
        end

        function value = getField(~, state, name, fallback)
            value = fallback ; if isstruct(state) && isfield(state, name), value = state.(name) ; end
        end

        function value = onOff(~, condition)
            value = 'off' ; if condition, value = 'on' ; end
        end

        function name = displayName(~, fieldName)
            names = struct('Cin', 'Input', 'Cout', 'Output', 'E', 'E', ...
                'Reconvolved', 'Reconvolved') ;
            name = fieldName ; if isfield(names, fieldName), name = names.(fieldName) ; end
        end
    end
end
