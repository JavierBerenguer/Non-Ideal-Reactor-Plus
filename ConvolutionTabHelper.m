classdef ConvolutionTabHelper < handle
% ConvolutionTabHelper - UI and state for tracer convolution workflows.
% All times passed to nirp.conv are expressed in seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    properties (SetAccess = private)
        Tab
    end

    properties (Access = private)
        GetRTD
        SetRTD
        SetStatus
        ModeGroup
        TimeUnit
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
                'timeUnit', obj.TimeUnit.Value, 'dt', obj.DtField.Value, ...
                'signals', struct(), 'lastSignals', obj.LastSignals, ...
                'lastResult', obj.LastResult, 'lastInfo', obj.LastInfo) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                ui = obj.Signals.(names{k}) ;
                snapshot.signals.(names{k}) = struct( ...
                    'source', ui.Source.Value, 'tableData', {ui.Table.Data}, ...
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
            obj.setDropdown(obj.TimeUnit, obj.getField(snapshot, 'timeUnit', 's')) ;
            obj.DtField.Value = obj.getField(snapshot, 'dt', 0) ;
            storedSignals = obj.getField(snapshot, 'signals', struct()) ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                name = names{k} ;
                if ~isfield(storedSignals, name), continue, end
                state = storedSignals.(name) ;
                ui = obj.Signals.(name) ;
                obj.setDropdown(ui.Source, obj.getField(state, 'source', 'Table')) ;
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
            obj.TimeUnit.Value = 's' ;
            obj.DtField.Value = 0 ;
            names = fieldnames(obj.Signals) ;
            for k = 1:numel(names)
                ui = obj.Signals.(names{k}) ;
                ui.Source.Value = 'Table' ;
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

            controls = uigridlayout(root, [5 1], ...
                'RowHeight', {54, 32, '1x', 34, 34}, 'Padding', [0 0 0 0]) ;
            modePanel = uipanel(controls, 'Title', 'Mode') ;
            obj.ModeGroup = uibuttongroup(modePanel, 'Position', [4 2 414 27], ...
                'SelectionChangedFcn', @(~,~) obj.modeChanged(), 'Tag', 'ConvModeGroup') ;
            labels = {'Convolution', 'Deconvolution', 'Series composition'} ;
            x = [8 137 276] ;
            for k = 1:3
                uiradiobutton(obj.ModeGroup, 'Text', labels{k}, ...
                    'Position', [x(k) 3 135 22]) ;
            end

            common = uigridlayout(controls, [1 4], ...
                'ColumnWidth', {65, 70, 150, '1x'}, 'Padding', [0 0 0 0]) ;
            uilabel(common, 'Text', 'Time unit') ;
            obj.TimeUnit = uidropdown(common, 'Items', {'s', 'min'}, ...
                'Value', 's', 'Tag', 'ConvTimeUnit') ;
            uilabel(common, 'Text', 'Common dt (0 = auto)') ;
            obj.DtField = uieditfield(common, 'numeric', 'Value', 0, ...
                'Limits', [0 Inf], 'Tag', 'ConvDt') ;

            obj.SignalTabs = uitabgroup(controls, 'Tag', 'ConvSignalTabs') ;
            obj.createSignalEditor('Cin', 'C_in', false) ;
            obj.createSignalEditor('Cout', 'C_out', false) ;
            obj.createSignalEditor('E', 'E', true) ;
            obj.createSignalEditor('E1', 'E1', false) ;
            obj.createSignalEditor('E2', 'E2', false) ;

            computeButton = uibutton(controls, 'Text', 'Compute', ...
                'FontWeight', 'bold', 'Tag', 'ConvCompute', ...
                'ButtonPushedFcn', @(~,~) obj.compute()) ;
            computeButton.Layout.Row = 4 ;
            buttons = uigridlayout(controls, [1 2], 'ColumnWidth', {'1x', '1x'}, ...
                'Padding', [0 0 0 0]) ;
            obj.ExportButton = uibutton(buttons, 'Text', 'Export to workspace', ...
                'Enable', 'off', 'Tag', 'ConvExport', ...
                'ButtonPushedFcn', @(~,~) obj.export()) ;
            obj.UseRTDButton = uibutton(buttons, 'Text', 'Use as RTD in tab 1', ...
                'Enable', 'off', 'Tag', 'ConvUseAsRTD', ...
                'ButtonPushedFcn', @(~,~) obj.useAsRTD()) ;

            results = uigridlayout(root, [4 1], ...
                'RowHeight', {'2x', '1x', 120, 50}, 'Padding', [0 0 0 0]) ;
            obj.Axes = uiaxes(results, 'Tag', 'ConvAxes') ;
            title(obj.Axes, 'Tracer signals') ; xlabel(obj.Axes, 'Time (s)') ;
            ylabel(obj.Axes, 'Signal') ; grid(obj.Axes, 'on') ;
            obj.ResultTable = uitable(results, 'ColumnName', {'t [s]', 'C'}, ...
                'ColumnEditable', [false false], 'Tag', 'ConvResultTable') ;
            obj.MomentsTable = uitable(results, ...
                'ColumnName', {'Signal', 'Area', 'Mean [s]', 'Variance [s^2]'}, ...
                'ColumnEditable', false(1, 4), 'Tag', 'ConvMomentsTable') ;
            obj.DiagnosticsLabel = uilabel(results, 'Text', 'No result.', ...
                'WordWrap', 'on', 'Tag', 'ConvDiagnostics') ;
            obj.modeChanged() ;
        end

        function createSignalEditor(obj, name, titleText, allowRTD)
            tab = uitab(obj.SignalTabs, 'Title', titleText, 'Tag', ['ConvSignal' name]) ;
            grid = uigridlayout(tab, [8 2], ...
                'RowHeight', {28, 115, 28, 100, 28, 28, 28, '1x'}, ...
                'ColumnWidth', {125, '1x'}, 'Padding', [5 5 5 5]) ;
            uilabel(grid, 'Text', 'Source') ;
            items = {'Table', 'Piecewise', 'Function'} ;
            if allowRTD
                items = [items {'RTD from tab 1', 'Model'}] ;
            end
            source = uidropdown(grid, 'Items', items, 'Value', 'Table', ...
                'Tag', ['ConvSource' name], ...
                'ValueChangedFcn', @(~,~) obj.sourceChanged(name)) ;
            tableInput = uitable(grid, 'Data', cell(3, 2), ...
                'ColumnName', {'t', 'C'}, 'ColumnEditable', [true true], ...
                'Tag', ['ConvTable' name]) ;
            tableInput.Layout.Row = 2 ; tableInput.Layout.Column = [1 2] ;
            pieceLabel = uilabel(grid, 'Text', 'From / To / expression in t', ...
                'Visible', 'off') ; pieceLabel.Layout.Row = 3 ; pieceLabel.Layout.Column = [1 2] ;
            pieceTable = uitable(grid, 'Data', cell(3, 3), ...
                'ColumnName', {'From t', 'To t', 'Expression in t'}, ...
                'ColumnEditable', [true true true], 'Visible', 'off', ...
                'Tag', ['ConvPiecewise' name]) ;
            pieceTable.Layout.Row = 4 ; pieceTable.Layout.Column = [1 2] ;
            functionLabel = uilabel(grid, 'Text', 'Expression in t', 'Visible', 'off') ;
            functionExpression = uieditfield(grid, 'text', 'Value', 'exp(-t)', ...
                'Visible', 'off', 'Tag', ['ConvFunction' name]) ;
            rangeGrid = uigridlayout(grid, [1 6], ...
                'ColumnWidth', {35, '1x', 30, '1x', 32, '1x'}, ...
                'Padding', [0 0 0 0], 'Visible', 'off') ;
            rangeGrid.Layout.Row = 6 ; rangeGrid.Layout.Column = [1 2] ;
            uilabel(rangeGrid, 'Text', 'Start') ;
            functionStart = uieditfield(rangeGrid, 'numeric', 'Value', 0, ...
                'Tag', ['ConvFunctionStart' name]) ;
            uilabel(rangeGrid, 'Text', 'End') ;
            functionEnd = uieditfield(rangeGrid, 'numeric', 'Value', 10, ...
                'Tag', ['ConvFunctionEnd' name]) ;
            uilabel(rangeGrid, 'Text', 'Step') ;
            functionStep = uieditfield(rangeGrid, 'numeric', 'Value', 1, ...
                'Limits', [eps Inf], 'Tag', ['ConvFunctionStep' name]) ;
            modelGrid = uigridlayout(grid, [2 4], ...
                'ColumnWidth', {50, '1x', 50, '1x'}, 'Padding', [0 0 0 0], ...
                'Visible', 'off') ;
            modelGrid.Layout.Row = [7 8] ; modelGrid.Layout.Column = [1 2] ;
            uilabel(modelGrid, 'Text', 'Model') ;
            model = uidropdown(modelGrid, ...
                'Items', {'CSTR', 'PFR', 'Tanks-in-Series', 'Dispersion'}, ...
                'ValueChangedFcn', @(~,~) obj.modelChanged(name), ...
                'Tag', ['ConvModel' name]) ;
            uilabel(modelGrid, 'Text', 'Tau') ;
            tau = uieditfield(modelGrid, 'numeric', 'Value', 5, 'Limits', [eps Inf], ...
                'Tag', ['ConvTau' name]) ;
            uilabel(modelGrid, 'Text', 'N') ;
            n = uieditfield(modelGrid, 'numeric', 'Value', 2, 'Limits', [1 Inf], ...
                'RoundFractionalValues', 'on', 'Tag', ['ConvN' name]) ;
            uilabel(modelGrid, 'Text', 'Bo') ;
            bo = uieditfield(modelGrid, 'numeric', 'Value', 0.1, 'Limits', [eps Inf], ...
                'Tag', ['ConvBo' name]) ;
            obj.Signals.(name) = struct('Tab', tab, 'Source', source, ...
                'Table', tableInput, 'PieceLabel', pieceLabel, ...
                'PiecewiseTable', pieceTable, 'FunctionLabel', functionLabel, ...
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
            scale = obj.timeScale() ;
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
            requestedDt = obj.DtField.Value * scale ;
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
            scale = obj.timeScale() ;
            switch ui.Source.Value
                case 'Table'
                    values = obj.numericTable(ui.Table.Data, 2, name) ;
                    signal = nirp.conv.signal(values(:, 1)' * scale, values(:, 2)') ;
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
                    signal = nirp.conv.fromFunction(@(seconds) f(seconds / scale), t) ;
                case 'Piecewise'
                    signal = obj.buildPiecewise(ui.PiecewiseTable.Data, scale, targetDt, name) ;
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

        function signal = buildPiecewise(obj, data, scale, targetDt, name)
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
                    'handle', @(seconds) userHandle(seconds / scale)) ; %#ok<AGROW>
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
            scale = obj.timeScale() ;
            mode = obj.ModeGroup.SelectedObject.Text ;
            resultValues = result.C ;
            if ~strcmp(mode, 'Convolution'), resultValues = resultValues * scale ; end
            obj.ResultTable.ColumnName = {['t [' obj.TimeUnit.Value ']'], 'C'} ;
            obj.ResultTable.Data = [result.t(:) / scale, resultValues(:)] ;
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
                    plotValues = plotValues * scale ;
                end
                plot(obj.Axes, signal.t / scale, plotValues, ...
                    'DisplayName', obj.displayName(name)) ;
                moments = obj.displayMoments(signal, isRTD, scale) ;
                momentRows(end + 1, :) = {obj.displayName(name), moments.area, ...
                    moments.mean, moments.variance} ; %#ok<AGROW>
            end
            if strcmp(mode, 'Convolution')
                plot(obj.Axes, result.t / scale, resultValues, 'LineWidth', 1.6, ...
                    'DisplayName', 'Result') ;
                moments = obj.displayMoments(result, false, scale) ;
                momentRows(end + 1, :) = {'Result', moments.area, ...
                    moments.mean, moments.variance} ; %#ok<AGROW>
            end
            hold(obj.Axes, 'off') ; legend(obj.Axes, 'show', 'Location', 'best') ;
            xlabel(obj.Axes, ['Time (' obj.TimeUnit.Value ')']) ;
            obj.MomentsTable.ColumnName = {'Signal', 'Area', ...
                ['Mean [' obj.TimeUnit.Value ']'], ...
                ['Variance [' obj.TimeUnit.Value '^2]']} ;
            obj.MomentsTable.Data = momentRows ;
            if strcmp(mode, 'Deconvolution')
                obj.DiagnosticsLabel.Text = sprintf( ...
                    'Residual norm: %.6g | Integral E: %.6g | Mass ratio: %.6g', ...
                    obj.LastInfo.residualNorm, obj.LastInfo.areaE, obj.LastInfo.massBalance) ;
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

        function scale = timeScale(obj)
            scale = 1 ; if strcmp(obj.TimeUnit.Value, 'min'), scale = 60 ; end
        end

        function values = displayMoments(~, signal, isRTD, scale)
            values = nirp.conv.moments(signal) ;
            if ~isRTD
                values.area = values.area / scale ;
            end
            values.mean = values.mean / scale ;
            values.variance = values.variance / scale^2 ;
        end

        function value = FunctionStepFallback(obj, scale)
            value = obj.DtField.Value * scale ;
            if value <= 0, value = scale ; end
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
