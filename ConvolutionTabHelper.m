classdef ConvolutionTabHelper < handle
% ConvolutionTabHelper - UI and state for tracer convolution workflows.
% All times passed to nirp.conv are expressed in seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 18, 2026
% =========================================================================

    properties (SetAccess = private)
        Tab
    end

    properties (Access = private)
        GetRTD
        SetRTD
        SetStatus
        ModeGroup
        DtUnit
        OutputTimeUnit
        OutputConcentrationUnit
        DtField
        SignalTabs
        Signals = struct()
        Axes
        ResultTable
        MomentsTable
        DiagnosticsLabel
        ExportButton
        UseRTDButton
        LastSignals = struct()
        LastResult = []
        LastInfo = struct()
    end

    methods
        function obj = ConvolutionTabHelper(parent, getRTD, setRTD, setStatus)
            obj.GetRTD = getRTD ;
            obj.SetRTD = setRTD ;
            obj.SetStatus = setStatus ;
            obj.buildUI(parent) ;
        end

        function snapshot = buildSnapshot(obj)
            snapshot = struct('mode', obj.ModeGroup.SelectedObject.Text, ...
                'timeUnit', obj.OutputTimeUnit.Value, ...
                'dtUnit', obj.DtUnit.Value, 'dt', obj.DtField.Value, ...
                'outputTimeUnit', obj.OutputTimeUnit.Value, ...
                'outputConcentrationUnit', obj.OutputConcentrationUnit.Value, ...
                'signals', struct(), 'lastSignals', obj.LastSignals, ...
                'lastResult', obj.LastResult, 'lastInfo', obj.LastInfo) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                ui = obj.Signals.(names{k}) ;
                snapshot.signals.(names{k}) = struct( ...
                    'source', ui.Source.Value, 'timeUnit', ui.TimeUnit.Value, ...
                    'concentrationUnit', ui.ConcentrationUnit.Value, ...
                    'tableData', {ui.Table.Data}, ...
                    'piecewiseData', {ui.PiecewiseTable.Data}, ...
                    'functionExpression', ui.FunctionExpression.Value, ...
                    'functionStart', ui.FunctionStart.Value, ...
                    'functionEnd', ui.FunctionEnd.Value, ...
                    'functionStep', ui.FunctionStep.Value, ...
                    'model', ui.Model.Value, 'tau', ui.Tau.Value, ...
                    'n', ui.N.Value, 'bo', ui.Bo.Value) ;
            end
        end

        function applySnapshot(obj, snapshot)
            if ~isstruct(snapshot) || isempty(fieldnames(snapshot))
                obj.reset() ;
                return
            end
            obj.selectMode(obj.getField(snapshot, 'mode', 'Convolution')) ;
            legacyTimeUnit = obj.getField(snapshot, 'timeUnit', 's') ;
            obj.setDropdown(obj.DtUnit, obj.getField(snapshot, 'dtUnit', legacyTimeUnit)) ;
            obj.setDropdown(obj.OutputTimeUnit, ...
                obj.getField(snapshot, 'outputTimeUnit', legacyTimeUnit)) ;
            obj.setDropdown(obj.OutputConcentrationUnit, ...
                obj.getField(snapshot, 'outputConcentrationUnit', 'mol/m^3')) ;
            obj.DtField.Value = obj.getField(snapshot, 'dt', 0) ;
            storedSignals = obj.getField(snapshot, 'signals', struct()) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                name = names{k} ;
                if ~isfield(storedSignals, name), continue, end
                state = storedSignals.(name) ;
                ui = obj.Signals.(name) ;
                obj.setDropdown(ui.Source, obj.getField(state, 'source', 'Table')) ;
                obj.setDropdown(ui.TimeUnit, obj.getField(state, 'timeUnit', legacyTimeUnit)) ;
                obj.setDropdown(ui.ConcentrationUnit, ...
                    obj.getField(state, 'concentrationUnit', 'mol/m^3')) ;
                ui.Table.Data = obj.getField(state, 'tableData', ui.Table.Data) ;
                ui.PiecewiseTable.Data = obj.getField(state, 'piecewiseData', ui.PiecewiseTable.Data) ;
                ui.FunctionExpression.Value = char(string(obj.getField(state, 'functionExpression', 'exp(-t)'))) ;
                ui.FunctionStart.Value = obj.getField(state, 'functionStart', 0) ;
                ui.FunctionEnd.Value = obj.getField(state, 'functionEnd', 10) ;
                ui.FunctionStep.Value = obj.getField(state, 'functionStep', 1) ;
                obj.setDropdown(ui.Model, obj.getField(state, 'model', 'CSTR')) ;
                ui.Tau.Value = obj.getField(state, 'tau', 5) ;
                ui.N.Value = obj.getField(state, 'n', 2) ;
                ui.Bo.Value = obj.getField(state, 'bo', 0.1) ;
                obj.sourceChanged(name) ;
            end
            obj.LastSignals = obj.getField(snapshot, 'lastSignals', struct()) ;
            obj.LastResult = obj.getField(snapshot, 'lastResult', []) ;
            obj.LastInfo = obj.getField(snapshot, 'lastInfo', struct()) ;
            obj.modeChanged() ;
            if isstruct(obj.LastResult) && isfield(obj.LastResult, 't')
                obj.showResults() ;
            else
                obj.clearResults() ;
            end
        end

        function reset(obj)
            obj.selectMode('Convolution') ;
            obj.DtUnit.Value = 's' ;
            obj.OutputTimeUnit.Value = 's' ;
            obj.OutputConcentrationUnit.Value = 'mol/m^3' ;
            obj.DtField.Value = 0 ;
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

            controls = uigridlayout(root, [6 1], ...
                'RowHeight', {54, 32, '1x', 34, 68, 34}, ...
                'RowSpacing', 4, 'Padding', [0 0 0 0]) ;
            modePanel = uipanel(controls, 'Title', 'Mode') ;
            obj.ModeGroup = uibuttongroup(modePanel, 'Position', [4 2 414 27], ...
                'SelectionChangedFcn', @(~,~) obj.modeChanged(), 'Tag', 'ConvModeGroup') ;
            labels = {'Convolution', 'Deconvolution', 'Series composition'} ;
            x = [8 137 276] ;
            for k = 1:3
                uiradiobutton(obj.ModeGroup, 'Text', labels{k}, ...
                    'Position', [x(k) 3 135 22], ...
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
            uilabel(common, 'Text', 'Unit:') ;
            obj.DtUnit = uidropdown(common, 'Items', UnitConverterHelper.getUnits('Time'), ...
                'Value', 's', 'Tag', 'ConvDtUnit', ...
                'Tooltip', 'Time unit of the common calculation step.') ;
            commonLabel.Tooltip = obj.DtField.Tooltip ;

            obj.SignalTabs = uitabgroup(controls, 'Tag', 'ConvSignalTabs') ;
            obj.createSignalEditor('Cin', 'C_in', false) ;
            obj.createSignalEditor('Cout', 'C_out', false) ;
            obj.createSignalEditor('E', 'E', true) ;
            obj.createSignalEditor('E1', 'E1', false) ;
            obj.createSignalEditor('E2', 'E2', false) ;

            computeButton = uibutton(controls, 'Text', 'Compute', ...
                'FontWeight', 'bold', 'BackgroundColor', [0.3 0.6 0.9], ...
                'FontColor', 'white', 'Tag', 'ConvCompute', ...
                'Tooltip', 'Run the selected tracer-signal workflow and update all results.', ...
                'ButtonPushedFcn', @(~,~) obj.compute()) ;
            computeButton.Layout.Row = 4 ;
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
            buttons = uigridlayout(controls, [1 2], 'ColumnWidth', {'1.25x', '0.75x'}, ...
                'Padding', [0 0 0 0]) ;
            obj.ExportButton = uibutton(buttons, 'Text', 'Export convolutionResult to Workspace', ...
                'Enable', 'off', 'Tag', 'ConvExport', ...
                'Tooltip', 'Export inputs, SI result, diagnostics, mode, and selected units as convolutionResult.', ...
                'ButtonPushedFcn', @(~,~) obj.export()) ;
            obj.UseRTDButton = uibutton(buttons, 'Text', 'Use as RTD in tab 1', ...
                'Enable', 'off', 'Tag', 'ConvUseAsRTD', ...
                'Tooltip', 'Load the deconvolved E(t) into RTD Analysis.', ...
                'ButtonPushedFcn', @(~,~) obj.useAsRTD()) ;

            results = uigridlayout(root, [4 1], ...
                'RowHeight', {'2x', '1x', 120, 50}, 'Padding', [0 0 0 0]) ;
            obj.Axes = uiaxes(results, 'Tag', 'ConvAxes') ;
            title(obj.Axes, 'Tracer signals', 'Interpreter', 'latex') ;
            xlabel(obj.Axes, '$t$ [s]', 'Interpreter', 'latex') ;
            ylabel(obj.Axes, 'Signal', 'Interpreter', 'latex') ; grid(obj.Axes, 'on') ;
            obj.ResultTable = uitable(results, 'ColumnName', {'t [s]', 'C'}, ...
                'ColumnEditable', [false false], 'Tag', 'ConvResultTable', ...
                'Tooltip', 'Computed result in the selected display units.') ;
            obj.MomentsTable = uitable(results, ...
                'ColumnName', {'Signal', 'Area', 'Mean [s]', 'Variance [s^2]'}, ...
                'ColumnEditable', false(1, 4), 'Tag', 'ConvMomentsTable', ...
                'Tooltip', 'Trapezoidal area, mean time, and variance for each displayed signal.') ;
            obj.DiagnosticsLabel = uilabel(results, 'Text', 'No result.', ...
                'WordWrap', 'on', 'Tag', 'ConvDiagnostics', ...
                'Tooltip', 'Numerical diagnostics and tracer-mass balance for the latest calculation.') ;
            obj.modeChanged() ;
        end

        function createSignalEditor(obj, name, titleText, allowRTD)
            tab = uitab(obj.SignalTabs, 'Title', titleText, 'Tag', ['ConvSignal' name]) ;
            grid = uigridlayout(tab, [10 2], ...
                'RowHeight', {26, 26, 76, 26, 24, 66, 24, 26, 26, '1x'}, ...
                'RowSpacing', 3, 'ColumnWidth', {125, '1x'}, 'Padding', [4 4 4 4]) ;
            sourceLabel = uilabel(grid, 'Text', 'Source') ;
            items = {'Table', 'Piecewise', 'Function'} ;
            if allowRTD
                items = [items {'RTD from tab 1', 'Model'}] ;
            end
            source = uidropdown(grid, 'Items', items, 'Value', 'Table', ...
                'Tag', ['ConvSource' name], ...
                'Tooltip', 'Choose how this signal is entered.', ...
                'ValueChangedFcn', @(~,~) obj.sourceChanged(name)) ;
            sourceLabel.Tooltip = source.Tooltip ;
            unitsGrid = uigridlayout(grid, [1 4], ...
                'ColumnWidth', {45, '1x', 45, '1x'}, 'Padding', [0 0 0 0]) ;
            unitsGrid.Layout.Row = 2 ; unitsGrid.Layout.Column = [1 2] ;
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
                'CellSelectionCallback', @(src,event) obj.rememberSelection(src, event), ...
                'Tooltip', 'Enter time and signal value pairs; headers and incomplete imported rows are ignored.', ...
                'Tag', ['ConvTable' name]) ;
            tableInput.Layout.Row = 3 ; tableInput.Layout.Column = [1 2] ;
            tableButtons = uigridlayout(grid, [1 3], ...
                'ColumnWidth', {'1x', '1x', '1x'}, 'Padding', [0 0 0 0]) ;
            tableButtons.Layout.Row = 4 ; tableButtons.Layout.Column = [1 2] ;
            addRow = uibutton(tableButtons, 'Text', 'Add row', ...
                'BackgroundColor', [0.85 0.95 0.85], 'Tag', ['ConvAddRow' name], ...
                'Tooltip', 'Append one empty row to the active manual-input table.', ...
                'ButtonPushedFcn', @(~,~) obj.addRow(name)) ;
            removeRow = uibutton(tableButtons, 'Text', 'Remove row', ...
                'BackgroundColor', [0.95 0.85 0.85], 'Tag', ['ConvRemoveRow' name], ...
                'Tooltip', 'Remove the selected row, or the last row when none is selected; one row is always kept.', ...
                'ButtonPushedFcn', @(~,~) obj.removeRow(name)) ;
            importButton = uibutton(tableButtons, 'Text', 'Import file...', ...
                'Tag', ['ConvImport' name], ...
                'Tooltip', 'Import the first two numeric columns from Excel, CSV, or TSV into this signal.', ...
                'ButtonPushedFcn', @(~,~) obj.importTable(name)) ;
            pieceLabel = uilabel(grid, 'Text', 'From / To / expression in t', ...
                'Visible', 'off', 'Tooltip', 'Define consecutive signal expressions over intervals in the selected time unit.') ;
            pieceLabel.Layout.Row = 5 ; pieceLabel.Layout.Column = [1 2] ;
            pieceTable = uitable(grid, 'Data', cell(3, 3), ...
                'ColumnName', {'From t', 'To t', 'Expression in t'}, ...
                'ColumnEditable', [true true true], 'Visible', 'off', ...
                'CellSelectionCallback', @(src,event) obj.rememberSelection(src, event), ...
                'Tooltip', 'Enter interval bounds and a MATLAB expression in t for each segment.', ...
                'Tag', ['ConvPiecewise' name]) ;
            pieceTable.Layout.Row = 6 ; pieceTable.Layout.Column = [1 2] ;
            functionLabel = uilabel(grid, 'Text', 'Expression in t', 'Visible', 'off') ;
            functionExpression = uieditfield(grid, 'text', 'Value', 'exp(-t)', ...
                'Visible', 'off', 'Tag', ['ConvFunction' name], ...
                'Tooltip', 'MATLAB expression for this signal, using t in the selected input time unit.') ;
            functionLabel.Tooltip = functionExpression.Tooltip ;
            rangeGrid = uigridlayout(grid, [1 6], ...
                'ColumnWidth', {35, '1x', 30, '1x', 32, '1x'}, ...
                'Padding', [0 0 0 0], 'Visible', 'off') ;
            rangeGrid.Layout.Row = 8 ; rangeGrid.Layout.Column = [1 2] ;
            uilabel(rangeGrid, 'Text', 'Start') ;
            functionStart = uieditfield(rangeGrid, 'numeric', 'Value', 0, ...
                'Tag', ['ConvFunctionStart' name], ...
                'Tooltip', 'First time evaluated for the function source.') ;
            uilabel(rangeGrid, 'Text', 'End') ;
            functionEnd = uieditfield(rangeGrid, 'numeric', 'Value', 10, ...
                'Tag', ['ConvFunctionEnd' name], ...
                'Tooltip', 'Last time evaluated for the function source.') ;
            uilabel(rangeGrid, 'Text', 'Step') ;
            functionStep = uieditfield(rangeGrid, 'numeric', 'Value', 1, ...
                'Limits', [eps Inf], 'Tag', ['ConvFunctionStep' name]) ;
            functionStep.Tooltip = 'Sampling step for the function source.' ;
            modelGrid = uigridlayout(grid, [2 4], ...
                'ColumnWidth', {50, '1x', 50, '1x'}, 'Padding', [0 0 0 0], ...
                'Visible', 'off') ;
            modelGrid.Layout.Row = [9 10] ; modelGrid.Layout.Column = [1 2] ;
            uilabel(modelGrid, 'Text', 'Model') ;
            model = uidropdown(modelGrid, ...
                'Items', {'CSTR', 'PFR', 'Tanks-in-Series', 'Dispersion'}, ...
                'ValueChangedFcn', @(~,~) obj.modelChanged(name), ...
                'Tag', ['ConvModel' name], ...
                'Tooltip', 'Analytical RTD model used to generate E(t).') ;
            uilabel(modelGrid, 'Text', 'Tau') ;
            tau = uieditfield(modelGrid, 'numeric', 'Value', 5, 'Limits', [eps Inf], ...
                'Tag', ['ConvTau' name], ...
                'Tooltip', 'Mean residence time in this signal''s selected time unit.') ;
            uilabel(modelGrid, 'Text', 'N') ;
            n = uieditfield(modelGrid, 'numeric', 'Value', 2, 'Limits', [1 Inf], ...
                'RoundFractionalValues', 'on', 'Tag', ['ConvN' name]) ;
            n.Tooltip = 'Number of tanks used by the tanks-in-series RTD model.' ;
            uilabel(modelGrid, 'Text', 'Bo') ;
            bo = uieditfield(modelGrid, 'numeric', 'Value', 0.1, 'Limits', [eps Inf], ...
                'Tag', ['ConvBo' name]) ;
            bo.Tooltip = 'Axial dispersion number used by the dispersion RTD model.' ;
            obj.Signals.(name) = struct('Tab', tab, 'Source', source, ...
                'TimeUnit', timeUnit, 'ConcentrationUnit', concentrationUnit, ...
                'Table', tableInput, 'PieceLabel', pieceLabel, ...
                'PiecewiseTable', pieceTable, 'FunctionLabel', functionLabel, ...
                'TableButtons', tableButtons, 'AddRow', addRow, ...
                'RemoveRow', removeRow, 'ImportButton', importButton, ...
                'FunctionExpression', functionExpression, 'RangeGrid', rangeGrid, ...
                'FunctionStart', functionStart, 'FunctionEnd', functionEnd, ...
                'FunctionStep', functionStep, 'ModelGrid', modelGrid, ...
                'Model', model, 'Tau', tau, 'N', n, 'Bo', bo) ;
        end

        function modeChanged(obj)
            mode = obj.ModeGroup.SelectedObject.Text ;
            visibleNames = {'Cin', 'E'} ;
            if strcmp(mode, 'Deconvolution')
                visibleNames = {'Cin', 'Cout'} ;
            elseif strcmp(mode, 'Series composition')
                visibleNames = {'E1', 'E2'} ;
            end
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                obj.Signals.(names{k}).Tab.Parent = obj.SignalTabs ;
                obj.Signals.(names{k}).Tab.UserData = struct( ...
                    'activeForMode', any(strcmp(names{k}, visibleNames))) ;
            end
            obj.SignalTabs.SelectedTab = obj.Signals.(visibleNames{1}).Tab ;
            obj.UseRTDButton.Enable = obj.onOff(strcmp(mode, 'Deconvolution') && ...
                isstruct(obj.LastResult) && isfield(obj.LastResult, 't')) ;
        end

        function sourceChanged(obj, name)
            ui = obj.Signals.(name) ;
            source = ui.Source.Value ;
            ui.Table.Visible = obj.onOff(strcmp(source, 'Table')) ;
            ui.TableButtons.Visible = obj.onOff(any(strcmp(source, {'Table', 'Piecewise'}))) ;
            ui.ImportButton.Visible = obj.onOff(strcmp(source, 'Table')) ;
            ui.PieceLabel.Visible = obj.onOff(strcmp(source, 'Piecewise')) ;
            ui.PiecewiseTable.Visible = obj.onOff(strcmp(source, 'Piecewise')) ;
            isFunction = strcmp(source, 'Function') ;
            ui.FunctionLabel.Visible = obj.onOff(isFunction) ;
            ui.FunctionExpression.Visible = obj.onOff(isFunction) ;
            ui.RangeGrid.Visible = obj.onOff(isFunction) ;
            ui.ModelGrid.Visible = obj.onOff(strcmp(source, 'Model')) ;
            obj.modelChanged(name) ;
        end

        function modelChanged(obj, name)
            ui = obj.Signals.(name) ;
            ui.N.Enable = obj.onOff(strcmp(ui.Model.Value, 'Tanks-in-Series')) ;
            ui.Bo.Enable = obj.onOff(strcmp(ui.Model.Value, 'Dispersion')) ;
        end

        function compute(obj)
            try
                obj.SetStatus('Computing convolution workflow...') ;
                mode = obj.ModeGroup.SelectedObject.Text ;
                if strcmp(mode, 'Convolution')
                    names = {'Cin', 'E'} ;
                elseif strcmp(mode, 'Deconvolution')
                    names = {'Cin', 'Cout'} ;
                else
                    names = {'E1', 'E2'} ;
                end
                [signals, dt, wasResampled] = obj.buildSignals(names) ;
                if strcmp(mode, 'Convolution')
                    [obj.LastResult, obj.LastInfo] = nirp.conv.convolve(signals.E, signals.Cin) ;
                elseif strcmp(mode, 'Deconvolution')
                    nE = numel(signals.Cout.C) - numel(signals.Cin.C) + 1 ;
                    [obj.LastResult, obj.LastInfo] = nirp.conv.deconvolve( ...
                        signals.Cin, signals.Cout, nE) ;
                    signals.E = obj.LastResult ;
                    signals.Reconvolved = obj.LastInfo.reconvolved ;
                else
                    obj.LastResult = nirp.conv.series(signals.E1, signals.E2) ;
                    firstMoments = nirp.conv.moments(signals.E1) ;
                    secondMoments = nirp.conv.moments(signals.E2) ;
                    resultMoments = nirp.conv.moments(obj.LastResult) ;
                    obj.LastInfo = struct('massBalance', resultMoments.area / ...
                        (firstMoments.area * secondMoments.area)) ;
                    signals.E = obj.LastResult ;
                end
                obj.LastSignals = signals ;
                obj.showResults() ;
                if wasResampled
                    obj.SetStatus(sprintf('Ready - signals resampled to dt = %.6g s.', dt)) ;
                else
                    obj.SetStatus(sprintf('Ready - common dt = %.6g s.', dt)) ;
                end
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

        function [signals, dt, wasResampled] = buildSignals(obj, names)
            raw = struct() ; steps = [] ;
            for k = 1:numel(names)
                name = names{k} ;
                if any(strcmp(obj.Signals.(name).Source.Value, {'Model', 'RTD from tab 1'}))
                    continue
                end
                raw.(name) = obj.buildRawSignal(name, []) ;
                differences = diff(raw.(name).t) ;
                steps(end + 1) = min(differences) ; %#ok<AGROW>
            end
            requestedDt = obj.DtField.Value * ...
                UnitConverterHelper.factorToSI('Time', obj.DtUnit.Value) ;
            if requestedDt > 0
                dt = requestedDt ;
            elseif ~isempty(steps)
                dt = min(steps) ;
            else
                error('NonIdealReactorApp:ConvolutionMissingStep', ...
                    'A positive common time step is required.') ;
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
                    f = obj.expressionHandle(ui.FunctionExpression.Value) ;
                    startTime = ui.FunctionStart.Value * scale ;
                    endTime = ui.FunctionEnd.Value * scale ;
                    step = ui.FunctionStep.Value * scale ;
                    if endTime <= startTime
                        error('NonIdealReactorApp:ConvolutionRange', ...
                            'Function end time must be greater than start time.') ;
                    end
                    t = startTime:step:endTime ;
                    if t(end) < endTime, t(end + 1) = endTime ; end %#ok<AGROW>
                    signal = nirp.conv.fromFunction( ...
                        @(seconds) f(seconds / scale) * valueScale, t) ;
                case 'Piecewise'
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
                        '%s piecewise rows require To t > From t.', name) ;
                end
                userHandle = obj.expressionHandle(values{row, 3}) ;
                segments(end + 1) = struct('first', first, 'last', last, ...
                    'handle', @(seconds) userHandle(seconds / scale) * valueScale) ; %#ok<AGROW>
            end
            if isempty(segments)
                error('NonIdealReactorApp:ConvolutionEmptyPiecewise', ...
                    '%s requires at least one complete piecewise row.', name) ;
            end
            [~, order] = sort([segments.first]) ; segments = segments(order) ;
            edges = segments(1).first ; handles = {} ;
            for k = 1:numel(segments)
                if segments(k).first < edges(end)
                    error('NonIdealReactorApp:ConvolutionOverlap', ...
                        '%s piecewise segments cannot overlap.', name) ;
                elseif segments(k).first > edges(end)
                    edges(end + 1) = segments(k).first ; %#ok<AGROW>
                    handles{end + 1} = @(t) zeros(size(t)) ; %#ok<AGROW>
                end
                edges(end + 1) = segments(k).last ; %#ok<AGROW>
                handles{end + 1} = segments(k).handle ; %#ok<AGROW>
            end
            if isempty(targetDt)
                targetDt = obj.FunctionStepFallback(scale) ;
            end
            t = edges(1):targetDt:edges(end) ;
            if numel(t) < 2 || t(end) < edges(end), t(end + 1) = edges(end) ; end %#ok<AGROW>
            signal = nirp.conv.piecewise(edges, handles, t) ;
        end

        function showResults(obj)
            result = obj.LastResult ;
            timeScale = UnitConverterHelper.factorToSI('Time', obj.OutputTimeUnit.Value) ;
            concentrationScale = UnitConverterHelper.factorToSI( ...
                'Concentration', obj.OutputConcentrationUnit.Value) ;
            mode = obj.ModeGroup.SelectedObject.Text ;
            resultValues = result.C ;
            resultIsRTD = ~strcmp(mode, 'Convolution') ;
            if resultIsRTD
                resultValues = resultValues * timeScale ;
                valueHeading = ['E [1/' obj.OutputTimeUnit.Value ']'] ;
            else
                resultValues = resultValues / concentrationScale ;
                valueHeading = ['C [' obj.OutputConcentrationUnit.Value ']'] ;
            end
            obj.ResultTable.ColumnName = {['t [' obj.OutputTimeUnit.Value ']'], valueHeading} ;
            obj.ResultTable.Data = [result.t(:) / timeScale, resultValues(:)] ;
            cla(obj.Axes) ; hold(obj.Axes, 'on') ;
            names = fieldnames(obj.LastSignals) ;
            momentRows = cell(0, 4) ;
            for k = 1:numel(names)
                name = names{k} ;
                signal = obj.LastSignals.(name) ;
                if ~isstruct(signal) || ~all(isfield(signal, {'t', 'C'})), continue, end
                plotValues = signal.C ;
                isRTD = any(strcmp(name, {'E', 'E1', 'E2'})) ;
                if isRTD
                    plotValues = plotValues * timeScale ;
                else
                    plotValues = plotValues / concentrationScale ;
                end
                plot(obj.Axes, signal.t / timeScale, plotValues, ...
                    'DisplayName', obj.displayName(name)) ;
                moments = obj.displayMoments(signal, isRTD, timeScale, concentrationScale) ;
                momentRows(end + 1, :) = {obj.displayName(name), moments.area, ...
                    moments.mean, moments.variance} ; %#ok<AGROW>
            end
            if strcmp(mode, 'Convolution')
                plot(obj.Axes, result.t / timeScale, resultValues, 'LineWidth', 1.6, ...
                    'DisplayName', 'Result') ;
                moments = obj.displayMoments(result, false, timeScale, concentrationScale) ;
                momentRows(end + 1, :) = {'Result', moments.area, ...
                    moments.mean, moments.variance} ; %#ok<AGROW>
            end
            hold(obj.Axes, 'off') ; legend(obj.Axes, 'show', 'Location', 'best') ;
            xlabel(obj.Axes, ['$t$ [' obj.OutputTimeUnit.Value ']'], 'Interpreter', 'latex') ;
            ylabel(obj.Axes, 'Signal (see legend)', 'Interpreter', 'latex') ;
            obj.MomentsTable.ColumnName = {'Signal', 'Trapezoidal area', ...
                ['Mean [' obj.OutputTimeUnit.Value ']'], ...
                ['Variance [' obj.OutputTimeUnit.Value '^2]']} ;
            obj.MomentsTable.Data = momentRows ;
            if strcmp(mode, 'Deconvolution')
                displayedArea = nirp.conv.moments(obj.LastResult) ;
                obj.DiagnosticsLabel.Text = sprintf( ...
                    'Residual norm: %.6g | Trapezoidal area of E: %.6g | Mass ratio: %.6g', ...
                    obj.LastInfo.residualNorm, displayedArea.area, obj.LastInfo.massBalance) ;
            elseif isfield(obj.LastInfo, 'massBalance')
                obj.DiagnosticsLabel.Text = sprintf( ...
                    'Mass balance (area out / area in / area E): %.12g', ...
                    obj.LastInfo.massBalance) ;
            else
                obj.DiagnosticsLabel.Text = 'Series RTD composition complete.' ;
            end
            obj.ExportButton.Enable = 'on' ;
            obj.UseRTDButton.Enable = obj.onOff(strcmp(mode, 'Deconvolution')) ;
        end

        function clearResults(obj)
            cla(obj.Axes) ; obj.ResultTable.Data = [] ; obj.MomentsTable.Data = {} ;
            obj.DiagnosticsLabel.Text = 'No result.' ; obj.ExportButton.Enable = 'off' ;
            obj.UseRTDButton.Enable = 'off' ;
        end

        function export(obj)
            exported = obj.LastSignals ;
            exported.result = obj.LastResult ;
            exported.info = obj.LastInfo ;
            exported.mode = obj.ModeGroup.SelectedObject.Text ;
            exported.units = struct('time', obj.OutputTimeUnit.Value, ...
                'concentration', obj.OutputConcentrationUnit.Value) ;
            assignin('base', 'convolutionResult', exported) ;
            obj.SetStatus('Exported convolutionResult to the base workspace.') ;
        end

        function useAsRTD(obj)
            if ~strcmp(obj.ModeGroup.SelectedObject.Text, 'Deconvolution') || ...
                    ~isstruct(obj.LastResult) || ~isfield(obj.LastResult, 't')
                return
            end
            obj.SetRTD(obj.LastResult) ;
            obj.SetStatus('Deconvolved E loaded as the tab 1 RTD.') ;
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
            value = isempty(raw) ;
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

        function value = FunctionStepFallback(obj, scale)
            value = obj.DtField.Value * ...
                UnitConverterHelper.factorToSI('Time', obj.DtUnit.Value) ;
            if value <= 0, value = scale ; end
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
            value = any(strcmp(name, {'E', 'E1', 'E2'})) ;
        end

        function rememberSelection(~, tableControl, event)
            selectedRow = [] ;
            if ~isempty(event.Indices), selectedRow = event.Indices(1, 1) ; end
            tableControl.UserData = struct('selectedRow', selectedRow) ;
        end

        function addRow(obj, name)
            tableControl = obj.activeManualTable(name) ;
            data = obj.cellTable(tableControl.Data, numel(tableControl.ColumnName)) ;
            data(end + 1, 1:size(data, 2)) = {''} ;
            tableControl.Data = data ;
            tableControl.UserData = struct('selectedRow', []) ;
        end

        function removeRow(obj, name)
            tableControl = obj.activeManualTable(name) ;
            columns = numel(tableControl.ColumnName) ;
            data = obj.cellTable(tableControl.Data, columns) ;
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
            tableControl.Data = data ;
            tableControl.UserData = struct('selectedRow', []) ;
        end

        function tableControl = activeManualTable(obj, name)
            ui = obj.Signals.(name) ;
            if strcmp(ui.Source.Value, 'Piecewise')
                tableControl = ui.PiecewiseTable ;
            else
                tableControl = ui.Table ;
            end
        end

        function importTable(obj, name)
            [file, path] = uigetfile( ...
                {'*.xlsx;*.xls;*.csv;*.tsv', 'Data files (*.xlsx, *.xls, *.csv, *.tsv)'; ...
                 '*.*', 'All files (*.*)'}, 'Select tracer signal data file') ;
            if isequal(file, 0), return, end
            try
                data = readmatrix(fullfile(path, file)) ;
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
            names = struct('Cin', 'C_{in}', 'Cout', 'C_{out}', 'E', 'E', ...
                'E1', 'E_1', 'E2', 'E_2', 'Reconvolved', 'Reconvolved') ;
            name = fieldName ; if isfield(names, fieldName), name = names.(fieldName) ; end
        end
    end
end
