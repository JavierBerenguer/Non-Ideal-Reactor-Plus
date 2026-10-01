classdef NonIdealReactorApp < handle
% NonIdealReactorApp - GUI for non-ideal reactor analysis
% This app provides tools for RTD analysis, conversion prediction using
% segregation and maximum mixedness models, tanks-in-series, dispersion,
% and a design & optimization workspace for non-ideal reactors.
%
% Launch: app = NonIdealReactorApp ;
%
% =========================================================================
% Javier Berenguer Sabater
% Created: March 21, 2026. Last update: July 7, 2026
% =========================================================================

    properties (Access = private)
        % Main UI
        UIFigure
        TabGroup
        StatusBar               % Status bar label at bottom of figure

        % Shared state
        rtd                 % Current RTD object (shared across tabs)
        DisplayControls = struct()
        DisplayCache = struct()

        % ---- Tab 1: RTD Analysis ----
        RTDTab
        RTD_SourceDropdown
        RTD_TauField
        RTD_NField
        RTD_NLabel
        RTD_BoField
        RTD_BoLabel
        RTD_BoundaryDropdown
        RTD_BoundaryLabel
        RTD_ExpTVarField
        RTD_ExpTUnitDropdown
        RTD_ExpTVarLabel
        RTD_ExpCVarField
        RTD_ExpCVarLabel
        RTD_ExpC0Field
        RTD_ExpC0Label
        RTD_ImportButton
        RTD_ImportLabel
        RTD_EqTable
        RTD_EqTimeUnitLabel
        RTD_EqTimeUnitDropdown
        RTD_EqNptsLabel
        RTD_EqNptsField
        RTD_EqRow7Grid          % Sub-grid: time unit + N points (C(t) Equation)
        RTD_EqRow8Grid          % Sub-grid: data type + C0 (C(t) Equation)
        RTD_EqDataTypeLabel
        RTD_EqDataTypeDropdown  % Dropdown: 'Pulse C(t)' or 'Step C(t)' for C(t) Equation
        RTD_EqC0Label
        RTD_EqC0Field           % Step height C0 for C(t) Equation (same units as C(t))
        RTD_GenerateButton
        RTD_ExportButton
        RTD_ExportNameField
        RTD_ExportCounter = 1    % Auto-increment counter for export names
        RTD_RSNameField
        RTD_RSDefineButton
        RTD_RSEditButton
        RTD_RSLoadButton
        RTD_RSStatusLabel
        RTD_RS
        RTD_StreamNameField
        RTD_StreamDefineButton
        RTD_StreamEditButton
        RTD_StreamLoadButton
        RTD_StreamStatusLabel
        RTD_feedStream
        RTD_FQueryPanel
        RTD_FQueryInputField
        RTD_FQueryValueLabel
        RTD_FQueryComplementLabel
        RTD_FQueryPointHandle = []
        RTD_FQueryVerticalHandle = []
        RTD_FQueryHorizontalHandle = []
        RTD_EtSigmaBandHandle = []
        RTD_EtSigmaCenterHandle = []
        RTD_EtSigmaLowerHandle = []
        RTD_EtSigmaUpperHandle = []
        RTD_EthetaSigmaBandHandle = []
        RTD_EthetaSigmaCenterHandle = []
        RTD_EthetaSigmaLowerHandle = []
        RTD_EthetaSigmaUpperHandle = []
        RTD_EtSigmaLabelHandles = gobjects(0)
        RTD_EthetaSigmaLabelHandles = gobjects(0)
        RTD_QvLabel
        RTD_QvField
        RTD_ResultTau
        RTD_ResultTauLabel
        RTD_ResultSigma2
        RTD_ResultSigma2Label
        RTD_ResultSigma2Theta
        RTD_ResultS3
        RTD_ResultN
        RTD_ResultVeff
        RTD_ResultVeffLabel
        RTD_DataTable           % uitable for direct data entry
        RTD_AddRowButton        % Button to add a row
        RTD_RemoveRowButton     % Button to remove last row
        RTD_DataTypeDropdown    % Dropdown: 'Pulse C(t)' or 'Step C(t)'
        RTD_DataTypeLabel
        RTD_AxesEt
        RTD_AxesFt
        RTD_AxesEtheta

        % ---- Tab 2: Prediction Models ----
        PredTab
        Pred_InputMethodDropdown
        Pred_RefreshButton
        Pred_RTDStatusLabel
        Pred_StreamNameField    % Name of feed Stream in workspace
        Pred_StreamDefineButton % Launches defineStreamApp
        Pred_StreamEditButton   % Launches defineStreamApp with loaded stream
        Pred_StreamLoadButton   % Loads Stream from workspace
        Pred_StreamStatusLabel  % Shows loaded Stream info
        Pred_feedStream         % Loaded feed Stream object
        Pred_RSNameField        % Name of ReactionSys in workspace
        Pred_RSDefineButton     % Launches defineReactionSysApp (new)
        Pred_RSEditButton       % Launches defineReactionSysApp with loaded RS
        Pred_RSLoadButton       % Loads RS from workspace
        Pred_RSStatusLabel      % Shows loaded RS info
        Pred_RS                 % Loaded ReactionSys object
        Pred_ComputeButton
        Pred_ResultSegLabel
        Pred_ResultMMLabel
        Pred_ResultBoundsLabel
        Pred_C_exitPanel
        Pred_C_exitLabel
        Pred_C_exitTable        % UITable: outlet concentrations per component
        Pred_MixingEffectPanel
        Pred_MixingEffectLabel
        Pred_MixingEffectAxes
        Pred_AxesXbatch
        Pred_AxesIntegrand
        Pred_SharedLegend

        % Stored model objects
        seg_model               % SegregationModel object
        mm_model                % MaxMixednessModel object

        % ---- Tab 3: Tanks-in-Series ----
        TISTab
        TIS_NMethodDropdown
        TIS_NField
        TIS_NLabel
        TIS_RTDStatusLabel
        TIS_tauField
        TIS_tauLabel
        TIS_StreamNameField     % Name of feed Stream in workspace
        TIS_StreamDefineButton  % Launches defineStreamApp
        TIS_StreamEditButton    % Launches defineStreamApp with loaded stream
        TIS_StreamLoadButton    % Loads Stream from workspace
        TIS_StreamStatusLabel   % Shows loaded Stream info
        TIS_feedStream          % Loaded feed Stream object
        TIS_RSNameField         % Name of ReactionSys in workspace
        TIS_RSDefineButton      % Launches defineReactionSysApp (new)
        TIS_RSEditButton        % Launches defineReactionSysApp with loaded RS
        TIS_RSLoadButton        % Loads RS from workspace
        TIS_RSStatusLabel       % Shows loaded RS info
        TIS_RS                  % Loaded ReactionSys object
        TIS_ComputeButton
        TIS_ResultXtis
        TIS_ResultXcstr
        TIS_ResultXpfr
        TIS_ResultNused
        TIS_RefreshButton
        TIS_C_exitPanel
        TIS_C_exitLabel
        TIS_C_exitTable         % UITable: outlet concentrations per component
        TIS_AxesEt
        TIS_EtSigmaBandHandle = []
        TIS_EtSigmaCenterHandle = []
        TIS_EtSigmaLowerHandle = []
        TIS_EtSigmaUpperHandle = []
        TIS_EtSigmaLabelHandles = gobjects(0)
        TIS_AxesXvsN
        TIS_AxesComparison

        % ---- Tab 4: Dispersion Model ----
        DispTab
        Disp_InputMethodDropdown
        Disp_RTDStatusLabel
        Disp_BoField
        Disp_BoLabel
        Disp_PeLabel
        Disp_BCDropdown
        Disp_BCLabel
        Disp_tauField
        Disp_tauLabel
        Disp_RSDefineButton     % Launches defineReactionSysApp (new)
        Disp_RSEditButton       % Launches defineReactionSysApp with loaded RS
        Disp_RSNameField        % Name of ReactionSys in workspace
        Disp_RSLoadButton       % Loads RS from workspace
        Disp_RSStatusLabel      % Shows loaded RS info
        Disp_RS                 % Loaded ReactionSys object
        Disp_StreamNameField    % Name of feed Stream in workspace
        Disp_StreamDefineButton % Launches defineStreamApp
        Disp_StreamEditButton   % Launches defineStreamApp with loaded stream
        Disp_StreamLoadButton   % Loads Stream from workspace
        Disp_StreamStatusLabel  % Shows loaded Stream info
        Disp_feedStream         % Loaded feed Stream object
        Disp_C_exitPanel
        Disp_C_exitLabel
        Disp_C_exitTable        % UITable: outlet concentrations per component
        Disp_ComputeButton
        Disp_RefreshButton
        Disp_AxesEt
        Disp_EtSigmaBandHandle = []
        Disp_EtSigmaCenterHandle = []
        Disp_EtSigmaLowerHandle = []
        Disp_EtSigmaUpperHandle = []
        Disp_EtSigmaLabelHandles = gobjects(0)
        Disp_AxesXvsBo
        Disp_AxesComparison

        % Stored dispersion model
        disp_reactor            % DispersionReactor object

        % ---- Tab 5: Design & Optimization Workspace ----
        DesignTab
        DesignUI = struct()
        DesignState = struct()
        RestartInProgress = false
    end

    methods (Access = public)

        %% ============== CONSTRUCTOR ==============
        function app = NonIdealReactorApp()

            % Create main figure
            app.UIFigure = uifigure('Name', 'Non-Ideal Reactor Analysis', ...
                'Position', [100 100 1200 750], ...
                'Resize', 'on', ...
                'AutoResizeChildren', 'off') ;

            % Menu bar
            mFile = uimenu(app.UIFigure, 'Text', 'File') ;
            uimenu(mFile, 'Text', 'New', ...
                'MenuSelectedFcn', @(~,~) NonIdealReactorApp()) ;
            uimenu(mFile, 'Text', 'Guardar', ...
                'MenuSelectedFcn', @(~,~) app.saveSession()) ;
            uimenu(mFile, 'Text', 'Cargar', ...
                'MenuSelectedFcn', @(~,~) app.loadSession()) ;
            uimenu(mFile, 'Text', 'Restart', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) app.restartApp()) ;
            uimenu(mFile, 'Text', 'Exit', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) delete(app.UIFigure)) ;
            mTools = uimenu(app.UIFigure, 'Text', 'Tools') ;
            uimenu(mTools, 'Text', 'Unit Converter', ...
                'MenuSelectedFcn', @(~,~) UnitConverterHelper.launch()) ;
            mHelp = uimenu(app.UIFigure, 'Text', 'Help') ;
            uimenu(mHelp, 'Text', 'User Guide', ...
                'MenuSelectedFcn', @(~,~) app.showHelp()) ;
            uimenu(mHelp, 'Text', 'Technical Guide', ...
                'MenuSelectedFcn', @(~,~) app.showTechnicalGuide()) ;
            uimenu(mHelp, 'Text', 'About', ...
                'MenuSelectedFcn', @(~,~) app.showAbout()) ;
            uimenu(mHelp, 'Text', 'Hard Restart (Debug)', ...
                'Separator', 'on', ...
                'MenuSelectedFcn', @(~,~) app.hardRestartDebug()) ;

            % Status bar at bottom
            app.StatusBar = uilabel(app.UIFigure, ...
                'Text', '  Ready', ...
                'Position', [0 0 1200 22], ...
                'BackgroundColor', [0.94 0.94 0.94], ...
                'FontSize', 11, ...
                'FontColor', [0.3 0.3 0.3]) ;

            % Create tab group (above status bar)
            app.TabGroup = uitabgroup(app.UIFigure, ...
                'Position', [0 22 1200 728]) ;

            % Build tabs
            app.createRTDTab() ;
            app.createPredictionTab() ;
            app.createTISTab() ;
            app.createDispersionTab() ;
            app.createDesignTemplatesTab() ;
            app.RTD_updateFQuery() ;
            app.Pred_inputMethodChanged() ;

            % Assign resize callback AFTER all UI components exist
            app.UIFigure.SizeChangedFcn = @(~,~) app.onFigureResize() ;

            % Show figure
            app.UIFigure.Visible = 'on' ;
        end

        function saveSessionToFile(app, fullPath, sessionName)
            if nargin < 2 || isempty(fullPath)
                error('A valid destination path is required.') ;
            end
            if nargin < 3 || isempty(sessionName)
                [~, sessionName] = fileparts(fullPath) ;
            end

            sessionData = app.buildSessionSnapshot(sessionName) ;
            save(fullPath, 'sessionData', '-mat') ;
        end

        function loadSessionFromFile(app, fullPath)
            if nargin < 2 || isempty(fullPath)
                error('A valid session file path is required.') ;
            end

            loadedData = load(fullPath, 'sessionData') ;
            if ~isfield(loadedData, 'sessionData') || ~isstruct(loadedData.sessionData)
                error('The selected file does not contain a valid session snapshot.') ;
            end

            app.applySessionSnapshot(loadedData.sessionData) ;
        end

    end

    methods (Access = private)

        %% ============== RESPONSIVE RESIZE (T6) ==============

        function onFigureResize(app)
            pos = app.UIFigure.Position ;
            w = pos(3) ; h = pos(4) ;

            % Tab group fills figure above status bar
            app.TabGroup.Position = [0 22 w h - 22] ;

            % Status bar stretches full width at bottom
            app.StatusBar.Position = [0 0 w 22] ;
        end

        function restartApp(app)
            app.requestAppRestart(false) ;
        end

        function hardRestartDebug(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return
            end

            choice = uiconfirm(app.UIFigure, ...
                ['Use this only if the app is stuck and normal Restart does not work.' newline newline ...
                 'Hard Restart closes the app, clears loaded app class/function definitions, and tries to reopen it automatically.' newline ...
                 'The MATLAB workspace is preserved, but project objects already stored there may need to be reloaded.'], ...
                'Hard Restart (Debug)', ...
                'Options', {'Continue', 'Cancel'}, ...
                'DefaultOption', 2, ...
                'CancelOption', 2, ...
                'Icon', 'warning') ;
            if ~strcmp(choice, 'Continue')
                return
            end

            app.requestAppRestart(true) ;
        end

        function requestAppRestart(app, hardMode)
            if app.RestartInProgress
                return
            end

            app.RestartInProgress = true ;
            try
                app.scheduleRestartCommand(hardMode) ;
                app.closeFigureForRestart() ;
            catch ME
                app.RestartInProgress = false ;
                if hardMode
                    app.showDetailedError(ME, 'Hard Restart Error') ;
                else
                    app.showDetailedError(ME, 'Restart Error') ;
                end
            end
        end

        function closeFigureForRestart(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                fig = app.UIFigure ;
                try
                    fig.SizeChangedFcn = [] ;
                catch
                end
                try
                    delete(fig) ;
                catch
                end
            end
            drawnow ;
            pause(0.05) ;
            drawnow ;
        end

        function scheduleRestartCommand(app, hardMode)
            restartTag = 'NonIdealReactorAppRestartTimer' ;
            try
                staleTimers = timerfindall('Tag', restartTag) ;
                if ~isempty(staleTimers)
                    stop(staleTimers) ;
                    delete(staleTimers) ;
                end
            catch
            end

            restartTimer = timer( ...
                'ExecutionMode', 'singleShot', ...
                'StartDelay', 0.05, ...
                'Tag', restartTag, ...
                'TimerFcn', @(src,~) nonIdealReactorAppRestartTimerFcn(src, app.getAppRoot(), hardMode, restartTag), ...
                'StopFcn', @(src,~) delete(src)) ;
            start(restartTimer) ;
        end

        function rootDir = getAppRoot(~)
            appPath = which('NonIdealReactorApp') ;
            if isempty(appPath)
                rootDir = pwd ;
            else
                rootDir = fileparts(appPath) ;
            end
        end

        function savesDir = getSavesDirectory(app)
            savesDir = fullfile(app.getAppRoot(), 'saves') ;
        end

        function controlHandle = getDisplayControl(app, groupName, primaryFieldName, varargin)
            controlHandle = [] ;
            if ~isstruct(app.DisplayControls) || ~isfield(app.DisplayControls, groupName)
                return
            end

            groupControls = app.DisplayControls.(groupName) ;
            if ~isstruct(groupControls)
                return
            end

            candidateFields = [{primaryFieldName}, varargin] ;
            for k = 1:numel(candidateFields)
                fieldName = candidateFields{k} ;
                if isfield(groupControls, fieldName)
                    controlHandle = groupControls.(fieldName) ;
                    return
                end
            end
        end

        function value = getControlValue(~, controlHandle, defaultValue)
            value = defaultValue ;
            if isempty(controlHandle) || ~isvalid(controlHandle)
                return
            end

            try
                value = controlHandle.Value ;
            catch
            end
        end

        function snapshot = serializeValueObject(~, obj)
            snapshot = [] ;
            if isempty(obj)
                return
            end
            if isstruct(obj)
                snapshot = obj ;
                return
            end

            className = class(obj) ;
            switch className
                case 'RTD'
                    snapshot = struct( ...
                        'object_class', 'RTD', ...
                        't', obj.t, ...
                        'Et', obj.Et, ...
                        'source', obj.source, ...
                        'modelInfo', obj.modelInfo) ;
                    return
            end

            snapshot = struct('object_class', className) ;
            propNames = properties(obj) ;
            for k = 1:numel(propNames)
                propName = propNames{k} ;
                try
                    snapshot.(propName) = obj.(propName) ;
                catch
                end
            end
        end

        function obj = deserializeValueObject(~, snapshot, className)
            obj = [] ;
            if isempty(snapshot)
                return
            end
            if isa(snapshot, className)
                obj = snapshot ;
                return
            end
            if ~isstruct(snapshot)
                return
            end

            storedClass = '' ;
            if isfield(snapshot, 'object_class')
                storedClass = char(snapshot.object_class) ;
            elseif isfield(snapshot, '__class__')
                storedClass = char(snapshot.('__class__')) ;
            end
            if ~isempty(storedClass) && ~strcmp(storedClass, className)
                return
            end

            switch className
                case 'RTD'
                    t = [] ;
                    Et = [] ;
                    if isfield(snapshot, 't'), t = snapshot.t ; end
                    if isfield(snapshot, 'Et'), Et = snapshot.Et ; end
                    if isempty(t) || isempty(Et)
                        obj = RTD() ;
                    else
                        obj = RTD(t, Et) ;
                    end
                    if isfield(snapshot, 'source')
                        obj.source = snapshot.source ;
                    end
                    if isfield(snapshot, 'modelInfo') && isstruct(snapshot.modelInfo)
                        obj.modelInfo = snapshot.modelInfo ;
                    end
                    return
            end

            obj = feval(className) ;
            fieldNames = fieldnames(snapshot) ;
            for k = 1:numel(fieldNames)
                fieldName = fieldNames{k} ;
                if any(strcmp(fieldName, {'__class__', 'object_class'})) || ~isprop(obj, fieldName)
                    continue
                end
                try
                    obj.(fieldName) = snapshot.(fieldName) ;
                catch
                end
            end
        end

        function state = captureFieldWithUnit(~, field)
            state = struct('value', field.Value) ;
            if isstruct(field.UserData) && isfield(field.UserData, 'unitDropdown') && ...
                    ~isempty(field.UserData.unitDropdown) && isvalid(field.UserData.unitDropdown)
                state.unit = field.UserData.unitDropdown.Value ;
            end
        end

        function applyFieldWithUnit(~, field, state)
            if isempty(field) || ~isvalid(field) || ~isstruct(state)
                return
            end

            if isfield(state, 'unit') && isstruct(field.UserData) && ...
                    isfield(field.UserData, 'unitDropdown') && ...
                    ~isempty(field.UserData.unitDropdown) && isvalid(field.UserData.unitDropdown)
                dd = field.UserData.unitDropdown ;
                if any(strcmp(cellstr(dd.Items), char(string(state.unit))))
                    dd.Value = char(string(state.unit)) ;
                end
            end

            if isfield(state, 'value')
                try
                    field.Value = state.value ;
                catch
                end
            end
        end

        function state = captureLabelState(~, labelHandle)
            state = struct( ...
                'text', labelHandle.Text, ...
                'fontColor', labelHandle.FontColor, ...
                'visible', labelHandle.Visible) ;
        end

        function applyLabelState(~, labelHandle, state)
            if isempty(labelHandle) || ~isvalid(labelHandle) || ~isstruct(state)
                return
            end

            if isfield(state, 'text')
                labelHandle.Text = state.text ;
            end
            if isfield(state, 'fontColor')
                labelHandle.FontColor = state.fontColor ;
            end
            if isfield(state, 'visible')
                labelHandle.Visible = state.visible ;
            end
        end

        function values = captureListboxSelection(~, listbox)
            values = [] ;
            if isempty(listbox) || ~isvalid(listbox)
                return
            end
            if isnumeric(listbox.Value)
                values = reshape(listbox.Value, 1, []) ;
            end
        end

        function restoreListboxSelection(~, listbox, selectedValues)
            if isempty(listbox) || ~isvalid(listbox) || ~isnumeric(listbox.ItemsData)
                return
            end

            itemValues = reshape(listbox.ItemsData, 1, []) ;
            if isempty(selectedValues)
                listbox.Value = [] ;
                return
            end

            validValues = intersect(itemValues, reshape(selectedValues, 1, []), 'stable') ;
            if isempty(validValues)
                listbox.Value = itemValues ;
            else
                listbox.Value = validValues ;
            end
        end

        function value = getStructField(~, S, fieldName, defaultValue)
            value = defaultValue ;
            if isstruct(S) && isfield(S, fieldName)
                value = S.(fieldName) ;
            end
        end

        function setDropdownValueIfValid(~, dropdown, value)
            if isempty(dropdown) || ~isvalid(dropdown) || isempty(value)
                return
            end
            if any(strcmp(cellstr(dropdown.Items), char(string(value))))
                dropdown.Value = char(string(value)) ;
            end
        end

        function state = enableStateForObject(~, obj)
            state = 'off' ;
            if ~isempty(obj)
                state = 'on' ;
            end
        end

        function restoreChemicalSelectors(app, RS, C0, reactantListbox, reactantSelection, speciesListbox, speciesSelection)
            if isempty(RS)
                return
            end

            speciesInfo = app.getPredictionSpeciesInfo(RS) ;
            if ~isempty(speciesListbox) && isvalid(speciesListbox)
                app.ensurePredictionSpeciesSelector(speciesListbox, speciesInfo) ;
                app.restoreListboxSelection(speciesListbox, speciesSelection) ;
            end

            if nargin < 4 || isempty(reactantListbox) || isempty(C0)
                return
            end

            reactantInfo = app.getPredictionReactantInfo(RS, C0) ;
            if isvalid(reactantListbox)
                app.ensurePredictionReactantSelector(reactantListbox, reactantInfo) ;
                app.restoreListboxSelection(reactantListbox, reactantSelection) ;
            end
        end

        function data = defaultRTDEquationTableData(~)
            data = {
                '5*exp(-2.5*t)', '0', '10'
                '', '', ''
                '', '', ''} ;
        end

        function data = normalizeRTDEquationTableData(app, rawData)
            defaultData = app.defaultRTDEquationTableData() ;

            if nargin < 2 || isempty(rawData)
                data = defaultData ;
                return
            end

            if istable(rawData)
                rawData = table2cell(rawData) ;
            elseif ~iscell(rawData)
                rawData = num2cell(rawData) ;
            end

            if isempty(rawData)
                data = defaultData ;
                return
            end

            nRows = size(rawData, 1) ;
            nCols = min(size(rawData, 2), 3) ;
            data = cell(max(nRows, 1), 3) ;
            data(:, :) = {''} ;
            data(:, 1:nCols) = rawData(:, 1:nCols) ;

            hasContent = false ;
            for iRow = 1:size(data, 1)
                for iCol = 1:3
                    value = data{iRow, iCol} ;
                    if isnumeric(value) && ~isempty(value)
                        hasContent = true ;
                        break
                    end
                    if ischar(value) || isstring(value)
                        if strlength(strtrim(string(value))) > 0
                            hasContent = true ;
                            break
                        end
                    end
                end
                if hasContent
                    break
                end
            end

            if ~hasContent
                data = defaultData ;
            end
        end

        function data = getRTDEquationTableDataFromSnapshot(app, rtdSnapshot)
            data = app.getStructField(rtdSnapshot, 'equationTable', []) ;
            if ~isempty(data)
                data = app.normalizeRTDEquationTableData(data) ;
                return
            end

            eqExpr = app.getStructField(rtdSnapshot, 'equation', '5*exp(-2.5*t)') ;
            eqTStart = app.getStructField(rtdSnapshot, 'equationTStart', '0') ;
            eqTEnd = app.getStructField(rtdSnapshot, 'equationTEnd', '10') ;
            data = app.defaultRTDEquationTableData() ;
            data(1, :) = {eqExpr, eqTStart, eqTEnd} ;
        end

        function [tUser, cData] = buildRTDEquationSignal(app)
            rawData = app.normalizeRTDEquationTableData(app.RTD_EqTable.Data) ;
            nPtsTotal = max(10, round(app.RTD_EqNptsField.Value)) ;

            segments = struct('expr', {}, 'tStart', {}, 'tEnd', {}) ;
            for iRow = 1:size(rawData, 1)
                exprValue = rawData{iRow, 1} ;
                tStartValue = rawData{iRow, 2} ;
                tEndValue = rawData{iRow, 3} ;

                exprText = strtrim(char(string(exprValue))) ;
                tStartText = strtrim(char(string(tStartValue))) ;
                tEndText = strtrim(char(string(tEndValue))) ;
                isBlankRow = isempty(exprText) && isempty(tStartText) && isempty(tEndText) ;
                if isBlankRow
                    continue
                end
                if isempty(exprText) || isempty(tStartText) || isempty(tEndText)
                    error('Each piecewise C(t) row must define C(t), t start, and t end.') ;
                end

                tStart = InputLayerHelper.parseArithmeticExpression(tStartText) ;
                tEnd = InputLayerHelper.parseArithmeticExpression(tEndText) ;
                if ~isfinite(tStart) || ~isfinite(tEnd)
                    error('Piecewise C(t) limits must be finite numbers.') ;
                end
                if tEnd <= tStart
                    error('Each piecewise C(t) segment must satisfy t end > t start.') ;
                end

                segments(end + 1) = struct( ...
                    'expr', exprText, ...
                    'tStart', tStart, ...
                    'tEnd', tEnd) ; %#ok<AGROW>
            end

            if isempty(segments)
                error('Add at least one valid C(t) segment before generating the RTD.') ;
            end

            [~, sortIdx] = sort([segments.tStart]) ;
            segments = segments(sortIdx) ;

            for iSeg = 2:numel(segments)
                if segments(iSeg).tStart < segments(iSeg - 1).tEnd
                    error('Piecewise C(t) segments cannot overlap. Check t start and t end values.') ;
                end
            end

            fullSpan = segments(end).tEnd - segments(1).tStart ;
            if fullSpan <= 0
                error('The piecewise C(t) definition must span a positive time interval.') ;
            end

            tUser = [] ;
            cData = [] ;
            previousEnd = [] ;
            for iSeg = 1:numel(segments)
                if ~isempty(previousEnd) && segments(iSeg).tStart > previousEnd
                    gapSpan = segments(iSeg).tStart - previousEnd ;
                    gapPts = max(2, round(nPtsTotal * gapSpan / fullSpan)) ;
                    gapT = linspace(previousEnd, segments(iSeg).tStart, gapPts) ;
                    gapC = zeros(size(gapT)) ;
                    [tUser, cData] = app.appendRTDSignalChunk(tUser, cData, gapT, gapC) ;
                end

                segSpan = segments(iSeg).tEnd - segments(iSeg).tStart ;
                segPts = max(2, round(nPtsTotal * segSpan / fullSpan)) ;
                t = linspace(segments(iSeg).tStart, segments(iSeg).tEnd, segPts) ;
                exprText = segments(iSeg).expr ;
                try
                    cSegment = eval(exprText) ;
                catch evalErr
                    error('Error evaluating piecewise equation "%s": %s', ...
                        exprText, evalErr.message) ;
                end

                if isnumeric(cSegment) && isscalar(cSegment)
                    cSegment = repmat(cSegment, size(t)) ;
                end
                if ~isnumeric(cSegment)
                    error('Each piecewise C(t) equation must return numeric values.') ;
                end

                cSegment = cSegment(:).' ;
                if numel(cSegment) ~= numel(t)
                    error(['Each piecewise C(t) equation must return a scalar or a vector ' ...
                        'with the same size as t. Use element-wise operators (.*  ./  .^).']) ;
                end

                [tUser, cData] = app.appendRTDSignalChunk(tUser, cData, t, cSegment) ;
                previousEnd = segments(iSeg).tEnd ;
            end

            cData = max(cData, 0) ;
        end

        function [tData, cData] = appendRTDSignalChunk(~, tData, cData, tChunk, cChunk)
            tChunk = reshape(tChunk, 1, []) ;
            cChunk = reshape(cChunk, 1, []) ;
            if isempty(tChunk)
                return
            end

            if ~isempty(tData)
                tol = max(1e-12, 1e-9 * max(1, abs(tData(end)))) ;
                if abs(tChunk(1) - tData(end)) <= tol
                    tChunk = tChunk(2:end) ;
                    cChunk = cChunk(2:end) ;
                end
            end

            tData = [tData, tChunk] ;
            cData = [cData, cChunk] ;
        end

        function assignExperimentalWorkspaceData(app, rtdSnapshot)
            expData = app.getStructField(rtdSnapshot, 'experimentalWorkspaceData', struct()) ;
            if ~isstruct(expData)
                return
            end

            tData = app.getStructField(expData, 'tData', []) ;
            cData = app.getStructField(expData, 'cData', []) ;
            if isempty(tData) || isempty(cData)
                return
            end

            tVarName = strtrim(app.RTD_ExpTVarField.Value) ;
            cVarName = strtrim(app.RTD_ExpCVarField.Value) ;
            if ~isvarname(tVarName)
                tVarName = 't_exp_session' ;
                app.RTD_ExpTVarField.Value = tVarName ;
            end
            if ~isvarname(cVarName)
                cVarName = 'C_exp_session' ;
                app.RTD_ExpCVarField.Value = cVarName ;
            end

            assignin('base', tVarName, tData) ;
            assignin('base', cVarName, cData) ;
        end

        function snapshot = buildSessionSnapshot(app, sessionName)
            if nargin < 2 || isempty(sessionName)
                sessionName = sprintf('session_%s', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))) ;
            end

            selectedTabTitle = '' ;
            if ~isempty(app.TabGroup.SelectedTab) && isvalid(app.TabGroup.SelectedTab)
                selectedTabTitle = app.TabGroup.SelectedTab.Title ;
            end

            rtdTimeControl = app.getDisplayControl('RTD', 'time') ;
            rtdVolumeControl = app.getDisplayControl('RTD', 'volume') ;
            predConcentrationControl = app.getDisplayControl('Prediction', 'concentration') ;
            predReactantControl = app.getDisplayControl('Prediction', 'reactant') ;
            predSpeciesControl = app.getDisplayControl('Prediction', 'species') ;
            tisTimeControl = app.getDisplayControl('TIS', 'time') ;
            tisConcentrationControl = app.getDisplayControl('TIS', 'concentration') ;
            tisReactantControl = app.getDisplayControl('TIS', 'reactant') ;
            tisSpeciesControl = app.getDisplayControl('TIS', 'component', 'species') ;
            dispTimeControl = app.getDisplayControl('Dispersion', 'time') ;
            dispConcentrationControl = app.getDisplayControl('Dispersion', 'concentration') ;
            dispReactantControl = app.getDisplayControl('Dispersion', 'reactant') ;
            dispSpeciesControl = app.getDisplayControl('Dispersion', 'species', 'component') ;

            expWorkspaceData = struct('tData', [], 'cData', []) ;
            if any(strcmp(app.RTD_SourceDropdown.Value, {'Experimental Pulse', 'Experimental Step'}))
                try
                    expWorkspaceData.tData = evalin('base', app.RTD_ExpTVarField.Value) ;
                catch
                end
                try
                    expWorkspaceData.cData = evalin('base', app.RTD_ExpCVarField.Value) ;
                catch
                end
            end

            snapshot = struct() ;
            snapshot.session_version = 2 ;
            snapshot.saved_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')) ;
            snapshot.session_name = sessionName ;
            snapshot.selected_tab_title = selectedTabTitle ;

            snapshot.shared = struct( ...
                'rtd', app.serializeValueObject(app.rtd)) ;

            snapshot.rtd = struct() ;
            snapshot.rtd.source = app.RTD_SourceDropdown.Value ;
            snapshot.rtd.tauField = app.captureFieldWithUnit(app.RTD_TauField) ;
            snapshot.rtd.qvField = app.captureFieldWithUnit(app.RTD_QvField) ;
            snapshot.rtd.nValue = app.RTD_NField.Value ;
            snapshot.rtd.boValue = app.RTD_BoField.Value ;
            snapshot.rtd.expTVar = app.RTD_ExpTVarField.Value ;
            snapshot.rtd.expTUnit = app.RTD_ExpTUnitDropdown.Value ;
            snapshot.rtd.expCVar = app.RTD_ExpCVarField.Value ;
            snapshot.rtd.expC0Field = app.captureFieldWithUnit(app.RTD_ExpC0Field) ;
            snapshot.rtd.equationTable = app.RTD_EqTable.Data ;
            snapshot.rtd.equationTimeUnit = app.RTD_EqTimeUnitDropdown.Value ;
            snapshot.rtd.equationNpts = app.RTD_EqNptsField.Value ;
            snapshot.rtd.equationDataType = app.RTD_EqDataTypeDropdown.Value ;
            snapshot.rtd.equationC0 = app.RTD_EqC0Field.Value ;
            snapshot.rtd.dataType = app.RTD_DataTypeDropdown.Value ;
            snapshot.rtd.dataTable = app.RTD_DataTable.Data ;
            snapshot.rtd.exportName = app.RTD_ExportNameField.Value ;
            snapshot.rtd.exportCounter = app.RTD_ExportCounter ;
            snapshot.rtd.displayTimeUnit = app.getControlValue(rtdTimeControl, 's') ;
            snapshot.rtd.displayVolumeUnit = app.getControlValue(rtdVolumeControl, 'm^3') ;
            snapshot.rtd.fQueryValue = app.RTD_FQueryInputField.Value ;
            snapshot.rtd.rs = app.serializeValueObject(app.RTD_RS) ;
            snapshot.rtd.rsName = app.RTD_RSNameField.Value ;
            snapshot.rtd.feedStream = app.serializeValueObject(app.RTD_feedStream) ;
            snapshot.rtd.streamName = app.RTD_StreamNameField.Value ;
            snapshot.rtd.experimentalWorkspaceData = expWorkspaceData ;
            snapshot.rtd.importLabel = app.captureLabelState(app.RTD_ImportLabel) ;
            snapshot.rtd.rsStatus = app.captureLabelState(app.RTD_RSStatusLabel) ;
            snapshot.rtd.streamStatus = app.captureLabelState(app.RTD_StreamStatusLabel) ;

            snapshot.prediction = struct( ...
                'inputMethod', app.Pred_InputMethodDropdown.Value, ...
                'rs', app.serializeValueObject(app.Pred_RS), ...
                'rsName', app.Pred_RSNameField.Value, ...
                'feedStream', app.serializeValueObject(app.Pred_feedStream), ...
                'streamName', app.Pred_StreamNameField.Value, ...
                'displayConcentrationUnit', app.getControlValue(predConcentrationControl, 'mol/m^3'), ...
                'reactantSelection', app.captureListboxSelection(predReactantControl), ...
                'speciesSelection', app.captureListboxSelection(predSpeciesControl), ...
                'rtdStatus', app.captureLabelState(app.Pred_RTDStatusLabel), ...
                'rsStatus', app.captureLabelState(app.Pred_RSStatusLabel), ...
                'streamStatus', app.captureLabelState(app.Pred_StreamStatusLabel)) ;

            snapshot.tis = struct( ...
                'inputMethod', app.TIS_NMethodDropdown.Value, ...
                'nValue', app.TIS_NField.Value, ...
                'tauField', app.captureFieldWithUnit(app.TIS_tauField), ...
                'rs', app.serializeValueObject(app.TIS_RS), ...
                'rsName', app.TIS_RSNameField.Value, ...
                'feedStream', app.serializeValueObject(app.TIS_feedStream), ...
                'streamName', app.TIS_StreamNameField.Value, ...
                'displayTimeUnit', app.getControlValue(tisTimeControl, 's'), ...
                'displayConcentrationUnit', app.getControlValue(tisConcentrationControl, 'mol/m^3'), ...
                'reactantSelection', app.captureListboxSelection(tisReactantControl), ...
                'speciesSelection', app.captureListboxSelection(tisSpeciesControl), ...
                'rtdStatus', app.captureLabelState(app.TIS_RTDStatusLabel), ...
                'rsStatus', app.captureLabelState(app.TIS_RSStatusLabel), ...
                'streamStatus', app.captureLabelState(app.TIS_StreamStatusLabel)) ;

            currentDispPe = app.Disp_BoField.Value ;
            snapshot.dispersion = struct( ...
                'inputMethod', app.Disp_InputMethodDropdown.Value, ...
                'peValue', currentDispPe, ...
                'boValue', 1 / max(currentDispPe, 1e-12), ...
                'boundary', app.Disp_BCDropdown.Value, ...
                'tauField', app.captureFieldWithUnit(app.Disp_tauField), ...
                'rs', app.serializeValueObject(app.Disp_RS), ...
                'rsName', app.Disp_RSNameField.Value, ...
                'feedStream', app.serializeValueObject(app.Disp_feedStream), ...
                'streamName', app.Disp_StreamNameField.Value, ...
                'displayTimeUnit', app.getControlValue(dispTimeControl, 's'), ...
                'displayConcentrationUnit', app.getControlValue(dispConcentrationControl, 'mol/m^3'), ...
                'reactantSelection', app.captureListboxSelection(dispReactantControl), ...
                'speciesSelection', app.captureListboxSelection(dispSpeciesControl), ...
                'rtdStatus', app.captureLabelState(app.Disp_RTDStatusLabel), ...
                'rsStatus', app.captureLabelState(app.Disp_RSStatusLabel), ...
                'streamStatus', app.captureLabelState(app.Disp_StreamStatusLabel)) ;

            snapshot.designWorkspace = app.DW_buildSnapshot() ;
        end

        function applySessionSnapshot(app, snapshot)
            shared = app.getStructField(snapshot, 'shared', struct()) ;
            app.rtd = app.deserializeValueObject(app.getStructField(shared, 'rtd', []), 'RTD') ;
            app.DisplayCache = app.getStructField(shared, 'displayCache', struct()) ;
            app.seg_model = app.getStructField(shared, 'seg_model', []) ;
            app.mm_model = app.getStructField(shared, 'mm_model', []) ;
            app.disp_reactor = app.getStructField(shared, 'disp_reactor', []) ;

            rtdTimeControl = app.getDisplayControl('RTD', 'time') ;
            rtdVolumeControl = app.getDisplayControl('RTD', 'volume') ;
            predConcentrationControl = app.getDisplayControl('Prediction', 'concentration') ;
            predReactantControl = app.getDisplayControl('Prediction', 'reactant') ;
            predSpeciesControl = app.getDisplayControl('Prediction', 'species') ;
            tisTimeControl = app.getDisplayControl('TIS', 'time') ;
            tisConcentrationControl = app.getDisplayControl('TIS', 'concentration') ;
            tisReactantControl = app.getDisplayControl('TIS', 'reactant') ;
            tisSpeciesControl = app.getDisplayControl('TIS', 'component', 'species') ;
            dispTimeControl = app.getDisplayControl('Dispersion', 'time') ;
            dispConcentrationControl = app.getDisplayControl('Dispersion', 'concentration') ;
            dispReactantControl = app.getDisplayControl('Dispersion', 'reactant') ;
            dispSpeciesControl = app.getDisplayControl('Dispersion', 'species', 'component') ;

            rtdSnapshot = app.getStructField(snapshot, 'rtd', struct()) ;
            app.setDropdownValueIfValid(app.RTD_SourceDropdown, app.getStructField(rtdSnapshot, 'source', app.RTD_SourceDropdown.Value)) ;
            app.RTD_sourceChanged() ;
            app.applyFieldWithUnit(app.RTD_TauField, app.getStructField(rtdSnapshot, 'tauField', struct())) ;
            app.applyFieldWithUnit(app.RTD_QvField, app.getStructField(rtdSnapshot, 'qvField', struct())) ;
            app.RTD_NField.Value = app.getStructField(rtdSnapshot, 'nValue', app.RTD_NField.Value) ;
            app.RTD_BoField.Value = app.getStructField(rtdSnapshot, 'boValue', app.RTD_BoField.Value) ;
            app.RTD_ExpTVarField.Value = app.getStructField(rtdSnapshot, 'expTVar', app.RTD_ExpTVarField.Value) ;
            app.setDropdownValueIfValid(app.RTD_ExpTUnitDropdown, app.getStructField(rtdSnapshot, 'expTUnit', app.RTD_ExpTUnitDropdown.Value)) ;
            app.RTD_ExpCVarField.Value = app.getStructField(rtdSnapshot, 'expCVar', app.RTD_ExpCVarField.Value) ;
            app.applyFieldWithUnit(app.RTD_ExpC0Field, app.getStructField(rtdSnapshot, 'expC0Field', struct())) ;
            app.RTD_EqTable.Data = app.getRTDEquationTableDataFromSnapshot(rtdSnapshot) ;
            app.setDropdownValueIfValid(app.RTD_EqTimeUnitDropdown, app.getStructField(rtdSnapshot, 'equationTimeUnit', app.RTD_EqTimeUnitDropdown.Value)) ;
            app.RTD_EqNptsField.Value = app.getStructField(rtdSnapshot, 'equationNpts', app.RTD_EqNptsField.Value) ;
            % Sessions saved before the pulse/step selector existed are pulse responses
            app.setDropdownValueIfValid(app.RTD_EqDataTypeDropdown, app.getStructField(rtdSnapshot, 'equationDataType', 'Pulse C(t)')) ;
            app.RTD_EqC0Field.Value = app.getStructField(rtdSnapshot, 'equationC0', 1) ;
            app.RTD_eqDataTypeChanged() ;
            app.setDropdownValueIfValid(app.RTD_DataTypeDropdown, app.getStructField(rtdSnapshot, 'dataType', app.RTD_DataTypeDropdown.Value)) ;
            app.RTD_dataTypeChanged() ;
            app.RTD_DataTable.Data = app.getStructField(rtdSnapshot, 'dataTable', app.RTD_DataTable.Data) ;
            app.RTD_ExportNameField.Value = app.getStructField(rtdSnapshot, 'exportName', app.RTD_ExportNameField.Value) ;
            app.RTD_ExportCounter = app.getStructField(rtdSnapshot, 'exportCounter', app.RTD_ExportCounter) ;
            app.setDropdownValueIfValid(rtdTimeControl, app.getStructField(rtdSnapshot, 'displayTimeUnit', app.getControlValue(rtdTimeControl, 's'))) ;
            app.setDropdownValueIfValid(rtdVolumeControl, app.getStructField(rtdSnapshot, 'displayVolumeUnit', app.getControlValue(rtdVolumeControl, 'm^3'))) ;
            app.RTD_RS = app.deserializeValueObject(app.getStructField(rtdSnapshot, 'rs', []), 'ReactionSys') ;
            app.RTD_RSNameField.Value = app.getStructField(rtdSnapshot, 'rsName', app.RTD_RSNameField.Value) ;
            app.RTD_feedStream = app.deserializeValueObject(app.getStructField(rtdSnapshot, 'feedStream', []), 'Stream') ;
            app.RTD_StreamNameField.Value = app.getStructField(rtdSnapshot, 'streamName', app.RTD_StreamNameField.Value) ;
            app.assignExperimentalWorkspaceData(rtdSnapshot) ;
            app.applyLabelState(app.RTD_ImportLabel, app.getStructField(rtdSnapshot, 'importLabel', struct())) ;
            app.applyLabelState(app.RTD_RSStatusLabel, app.getStructField(rtdSnapshot, 'rsStatus', struct())) ;
            app.applyLabelState(app.RTD_StreamStatusLabel, app.getStructField(rtdSnapshot, 'streamStatus', struct())) ;
            app.RTD_RSEditButton.Enable = app.enableStateForObject(app.RTD_RS) ;
            app.RTD_StreamEditButton.Enable = app.enableStateForObject(app.RTD_feedStream) ;
            app.RTD_ExportButton.Enable = app.enableStateForObject(app.rtd) ;
            if ~isempty(app.rtd)
                app.RTD_updateResults() ;
                app.RTD_updatePlots() ;
            end
            app.RTD_FQueryInputField.Value = app.getStructField(rtdSnapshot, 'fQueryValue', app.RTD_FQueryInputField.Value) ;
            app.RTD_queryValueChanged() ;

            predSnapshot = app.getStructField(snapshot, 'prediction', struct()) ;
            app.Pred_RS = app.deserializeValueObject(app.getStructField(predSnapshot, 'rs', []), 'ReactionSys') ;
            app.Pred_RSNameField.Value = app.getStructField(predSnapshot, 'rsName', app.Pred_RSNameField.Value) ;
            app.Pred_feedStream = app.deserializeValueObject(app.getStructField(predSnapshot, 'feedStream', []), 'Stream') ;
            app.Pred_StreamNameField.Value = app.getStructField(predSnapshot, 'streamName', app.Pred_StreamNameField.Value) ;
            app.setDropdownValueIfValid(app.Pred_InputMethodDropdown, app.getStructField(predSnapshot, 'inputMethod', app.Pred_InputMethodDropdown.Value)) ;
            app.Pred_inputMethodChanged() ;
            app.setDropdownValueIfValid(predConcentrationControl, ...
                app.getStructField(predSnapshot, 'displayConcentrationUnit', app.getControlValue(predConcentrationControl, 'mol/m^3'))) ;
            if ~isempty(app.Pred_RS) && ~isempty(app.Pred_feedStream)
                app.restoreChemicalSelectors(app.Pred_RS, app.Pred_feedStream.concentration(:)', ...
                    predReactantControl, app.getStructField(predSnapshot, 'reactantSelection', []), ...
                    predSpeciesControl, app.getStructField(predSnapshot, 'speciesSelection', [])) ;
            end
            app.applyLabelState(app.Pred_RTDStatusLabel, app.getStructField(predSnapshot, 'rtdStatus', struct())) ;
            app.applyLabelState(app.Pred_RSStatusLabel, app.getStructField(predSnapshot, 'rsStatus', struct())) ;
            app.applyLabelState(app.Pred_StreamStatusLabel, app.getStructField(predSnapshot, 'streamStatus', struct())) ;
            if strcmp(app.Pred_InputMethodDropdown.Value, 'Manual')
                app.Pred_RSEditButton.Enable = app.enableStateForObject(app.Pred_RS) ;
                app.Pred_StreamEditButton.Enable = app.enableStateForObject(app.Pred_feedStream) ;
            end
            if ~isempty(app.seg_model) && ~isempty(app.mm_model) && ~isempty(app.rtd) && ...
                    ~isempty(app.Pred_RS) && ~isempty(app.Pred_feedStream)
                app.Pred_updatePlots() ;
            end

            tisSnapshot = app.getStructField(snapshot, 'tis', struct()) ;
            app.TIS_RS = app.deserializeValueObject(app.getStructField(tisSnapshot, 'rs', []), 'ReactionSys') ;
            app.TIS_RSNameField.Value = app.getStructField(tisSnapshot, 'rsName', app.TIS_RSNameField.Value) ;
            app.TIS_feedStream = app.deserializeValueObject(app.getStructField(tisSnapshot, 'feedStream', []), 'Stream') ;
            app.TIS_StreamNameField.Value = app.getStructField(tisSnapshot, 'streamName', app.TIS_StreamNameField.Value) ;
            app.TIS_NField.Value = app.getStructField(tisSnapshot, 'nValue', app.TIS_NField.Value) ;
            app.applyFieldWithUnit(app.TIS_tauField, app.getStructField(tisSnapshot, 'tauField', struct())) ;
            app.setDropdownValueIfValid(app.TIS_NMethodDropdown, app.getStructField(tisSnapshot, 'inputMethod', app.TIS_NMethodDropdown.Value)) ;
            app.TIS_NMethodChanged() ;
            app.setDropdownValueIfValid(tisTimeControl, app.getStructField(tisSnapshot, 'displayTimeUnit', app.getControlValue(tisTimeControl, 's'))) ;
            app.setDropdownValueIfValid(tisConcentrationControl, ...
                app.getStructField(tisSnapshot, 'displayConcentrationUnit', app.getControlValue(tisConcentrationControl, 'mol/m^3'))) ;
            if ~isempty(app.TIS_RS) && ~isempty(app.TIS_feedStream)
                app.restoreChemicalSelectors(app.TIS_RS, app.TIS_feedStream.concentration(:)', ...
                    tisReactantControl, app.getStructField(tisSnapshot, 'reactantSelection', []), ...
                    tisSpeciesControl, app.getStructField(tisSnapshot, 'speciesSelection', [])) ;
            end
            app.applyLabelState(app.TIS_RTDStatusLabel, app.getStructField(tisSnapshot, 'rtdStatus', struct())) ;
            app.applyLabelState(app.TIS_RSStatusLabel, app.getStructField(tisSnapshot, 'rsStatus', struct())) ;
            app.applyLabelState(app.TIS_StreamStatusLabel, app.getStructField(tisSnapshot, 'streamStatus', struct())) ;
            if strcmp(app.TIS_NMethodDropdown.Value, 'Manual')
                app.TIS_RSEditButton.Enable = app.enableStateForObject(app.TIS_RS) ;
                app.TIS_StreamEditButton.Enable = app.enableStateForObject(app.TIS_feedStream) ;
            end
            if isfield(app.DisplayCache, 'TIS') && ~isempty(app.DisplayCache.TIS)
                app.refreshDisplayUnits('TIS') ;
            end

            dispSnapshot = app.getStructField(snapshot, 'dispersion', struct()) ;
            app.Disp_RS = app.deserializeValueObject(app.getStructField(dispSnapshot, 'rs', []), 'ReactionSys') ;
            app.Disp_RSNameField.Value = app.getStructField(dispSnapshot, 'rsName', app.Disp_RSNameField.Value) ;
            app.Disp_feedStream = app.deserializeValueObject(app.getStructField(dispSnapshot, 'feedStream', []), 'Stream') ;
            app.Disp_StreamNameField.Value = app.getStructField(dispSnapshot, 'streamName', app.Disp_StreamNameField.Value) ;
            peSnapshotValue = app.getStructField(dispSnapshot, 'peValue', []) ;
            if isempty(peSnapshotValue)
                legacyBoValue = app.getStructField(dispSnapshot, 'boValue', []) ;
                if ~isempty(legacyBoValue) && isfinite(legacyBoValue) && legacyBoValue > 0
                    peSnapshotValue = 1 / legacyBoValue ;
                end
            end
            if isempty(peSnapshotValue)
                peSnapshotValue = app.Disp_BoField.Value ;
            end
            app.Disp_BoField.Value = peSnapshotValue ;
            app.setDropdownValueIfValid(app.Disp_BCDropdown, app.getStructField(dispSnapshot, 'boundary', app.Disp_BCDropdown.Value)) ;
            app.applyFieldWithUnit(app.Disp_tauField, app.getStructField(dispSnapshot, 'tauField', struct())) ;
            app.setDropdownValueIfValid(app.Disp_InputMethodDropdown, app.getStructField(dispSnapshot, 'inputMethod', app.Disp_InputMethodDropdown.Value)) ;
            app.Disp_inputMethodChanged() ;
            app.Disp_updatePe() ;
            app.setDropdownValueIfValid(dispTimeControl, app.getStructField(dispSnapshot, 'displayTimeUnit', app.getControlValue(dispTimeControl, 's'))) ;
            app.setDropdownValueIfValid(dispConcentrationControl, ...
                app.getStructField(dispSnapshot, 'displayConcentrationUnit', app.getControlValue(dispConcentrationControl, 'mol/m^3'))) ;
            if ~isempty(app.Disp_RS) && ~isempty(app.Disp_feedStream)
                app.restoreChemicalSelectors(app.Disp_RS, app.Disp_feedStream.concentration(:)', ...
                    dispReactantControl, app.getStructField(dispSnapshot, 'reactantSelection', []), ...
                    dispSpeciesControl, app.getStructField(dispSnapshot, 'speciesSelection', [])) ;
            end
            app.applyLabelState(app.Disp_RTDStatusLabel, app.getStructField(dispSnapshot, 'rtdStatus', struct())) ;
            app.applyLabelState(app.Disp_RSStatusLabel, app.getStructField(dispSnapshot, 'rsStatus', struct())) ;
            app.applyLabelState(app.Disp_StreamStatusLabel, app.getStructField(dispSnapshot, 'streamStatus', struct())) ;
            if strcmp(app.Disp_InputMethodDropdown.Value, 'Manual')
                app.Disp_RSEditButton.Enable = app.enableStateForObject(app.Disp_RS) ;
                app.Disp_StreamEditButton.Enable = app.enableStateForObject(app.Disp_feedStream) ;
            end
            if isempty(app.disp_reactor)
                app.disp_reactor = DispersionReactor(1 / max(app.Disp_BoField.Value, 1e-12), app.Disp_BCDropdown.Value) ;
            end
            if isfield(app.DisplayCache, 'Dispersion') && ~isempty(app.DisplayCache.Dispersion)
                app.refreshDisplayUnits('Dispersion') ;
            end

            designSnapshot = app.getStructField(snapshot, 'designWorkspace', struct()) ;
            if isempty(fieldnames(designSnapshot))
                designSnapshot = app.DW_convertLegacyTemplateSnapshot( ...
                    app.getStructField(snapshot, 'designTemplates', struct())) ;
            end
            app.DW_applySnapshot(designSnapshot) ;

            selectedTabTitle = app.getStructField(snapshot, 'selected_tab_title', '') ;
            if ~isempty(selectedTabTitle)
                for k = 1:numel(app.TabGroup.Children)
                    if strcmp(app.TabGroup.Children(k).Title, selectedTabTitle)
                        app.TabGroup.SelectedTab = app.TabGroup.Children(k) ;
                        break
                    end
                end
            end
        end

        function saveSession(app)
            try
                saveDir = app.getSavesDirectory() ;
                if ~exist(saveDir, 'dir')
                    mkdir(saveDir) ;
                end

                defaultFile = fullfile(saveDir, sprintf('session_%s.mat', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss')))) ;
                [fileName, ~] = uiputfile({'*.mat', 'MAT-files (*.mat)'}, ...
                    'Guardar sesión', defaultFile) ;
                if isequal(fileName, 0)
                    return
                end
                if isempty(fileparts(fileName))
                    [~, baseName, ext] = fileparts(fileName) ;
                    if isempty(ext)
                        fileName = [baseName '.mat'] ;
                    end
                end
                fullPath = fullfile(saveDir, fileName) ;
                if exist(fullPath, 'file')
                    choice = uiconfirm(app.UIFigure, ...
                        sprintf('El archivo "%s" ya existe. ¿Deseas sobrescribirlo?', fileName), ...
                        'Confirmar sobreescritura', ...
                        'Options', {'Sobrescribir', 'Cancelar'}, ...
                        'DefaultOption', 2, ...
                        'CancelOption', 2, ...
                        'Icon', 'warning') ;
                    if ~strcmp(choice, 'Sobrescribir')
                        return
                    end
                end

                [~, sessionName] = fileparts(fileName) ;
                app.saveSessionToFile(fullPath, sessionName) ;
                app.updateStatus(sprintf('Session saved: %s', fileName)) ;
            catch ME
                app.updateStatus('Error') ;
                errorMessage = ME.message ;
                if ~isempty(ME.stack)
                    errorMessage = sprintf('%s\n\n%s (line %d)', ...
                        errorMessage, ME.stack(1).name, ME.stack(1).line) ;
                end
                uialert(app.UIFigure, errorMessage, 'Save Session Error') ;
            end
        end

        function loadSession(app)
            saveDir = app.getSavesDirectory() ;
            if ~exist(saveDir, 'dir')
                uialert(app.UIFigure, ...
                    'No existe la carpeta "saves" todavia. Guarda una sesion primero.', ...
                    'No Saved Sessions') ;
                return
            end

            [fileName, filePath] = uigetfile({'*.mat', 'MAT-files (*.mat)'}, ...
                'Cargar sesión', saveDir) ;
            if isequal(fileName, 0)
                return
            end

            backupSnapshot = app.buildSessionSnapshot('backup_before_load') ;
            try
                app.loadSessionFromFile(fullfile(filePath, fileName)) ;
                app.updateStatus(sprintf('Session loaded: %s', fileName)) ;

                loadedData = load(fullfile(filePath, fileName), 'sessionData') ;
                if ~isfield(loadedData.sessionData, 'session_version') || ...
                        loadedData.sessionData.session_version < 2
                    uialert(app.UIFigure, ...
                        'La sesion cargada usa un formato antiguo o incompleto. Se han aplicado valores por defecto donde ha sido necesario.', ...
                        'Session Compatibility', 'Icon', 'info') ;
                end
            catch ME
                try
                    app.applySessionSnapshot(backupSnapshot) ;
                catch
                end
                app.updateStatus('Error') ;
                errorMessage = ME.message ;
                if ~isempty(ME.stack)
                    errorMessage = sprintf('%s\n\n%s (line %d)', ...
                        errorMessage, ME.stack(1).name, ME.stack(1).line) ;
                end
                uialert(app.UIFigure, errorMessage, 'Load Session Error') ;
            end
        end

        %% ============== HELPER: NUMERIC FIELD + UNIT SELECTOR ==============

        function [field, subGrid, btn] = createNumericWithConv(app, parentGrid, row, col, defaultVal, unitCat, varargin)
            % createNumericWithConv  Create a text editfield with a unit dropdown.
            %
            %   [field, subGrid, btn] = app.createNumericWithConv(parentGrid, row, col, defaultVal, unitCat, ...)
            %
            %   The edit field accepts simple arithmetic expressions such as
            %   10/6 or 2*60. Values are converted to SI only when read.

            btn = [] ;

            subGrid = uigridlayout(parentGrid, [1 2], ...
                'ColumnWidth', {'1x', 78}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 2) ;
            subGrid.Layout.Row    = row ;
            subGrid.Layout.Column = col ;

            field = uieditfield(subGrid, 'text', ...
                'Value', InputLayerHelper.formatScalar(defaultVal), ...
                'Tooltip', 'Accepts simple arithmetic expressions. Converted to SI at runtime.') ;
            field.Layout.Row = 1 ; field.Layout.Column = 1 ;

            unitDropdown = uidropdown(subGrid, ...
                'Items', UnitConverterHelper.getUnits(unitCat), ...
                'Value', UnitConverterHelper.defaultUnit(unitCat), ...
                'Tooltip', 'Choose the input unit for this field. Internal calculations remain in SI units.') ;
            unitDropdown.Layout.Row = 1 ; unitDropdown.Layout.Column = 2 ;

            field.UserData = struct( ...
                'unitCategory', unitCat, ...
                'unitDropdown', unitDropdown) ;
            app.updateInputFieldCategory(field, unitCat) ;
        end

        function value = readInputField(~, field)
            value = InputLayerHelper.readFieldToSI(field) ;
        end

        function value = readOptionalInputField(~, field)
            value = [] ;
            if isempty(field) || ~isvalid(field)
                return
            end
            rawValue = strtrim(char(string(field.Value))) ;
            if isempty(rawValue)
                return
            end
            value = InputLayerHelper.readFieldToSI(field) ;
        end

        function setInputFieldValue(~, field, siValue)
            InputLayerHelper.setFieldFromSI(field, siValue) ;
        end

        function defs = DW_fitConstraintDefinitions(~)
            defs = struct( ...
                'key', {'N', 'Bo', 'bypassFraction', 'tau_pfr_active', 'tau_cstr_active', 'splitToPFR', 'referenceTau', 'totalVolume'}, ...
                'label', {'N', 'Bo', 'bypassFraction', 'tau_pfr_active', 'tau_cstr_active', 'splitToPFR', 'Ref. tau_total', 'Total volume'}, ...
                'category', {'dimensionless', 'dimensionless', 'fraction', 'time', 'time', 'fraction', 'time', 'volume'}, ...
                'mode', {'bounds', 'bounds', 'bounds', 'bounds', 'bounds', 'bounds', 'scalar', 'scalar'}) ;
        end

        function rowIndices = DW_fitConstraintRowsByMode(app, mode)
            defs = app.DW_fitConstraintDefinitions() ;
            rowIndices = find(strcmp({defs.mode}, char(string(mode)))) ;
        end

        function tables = DW_getFitConstraintTableHandles(app)
            tables = {} ;
            fieldNames = {'VariableTable', 'ScalarVariableTable'} ;
            for i = 1:numel(fieldNames)
                if isfield(app.DesignUI, 'Fit') && isfield(app.DesignUI.Fit, fieldNames{i})
                    table = app.DesignUI.Fit.(fieldNames{i}) ;
                    if ~isempty(table) && isvalid(table)
                        tables{end + 1} = table ; %#ok<AGROW>
                    end
                end
            end
        end

        function table = DW_getPrimaryFitConstraintTable(app)
            table = [] ;
            tables = app.DW_getFitConstraintTableHandles() ;
            if ~isempty(tables)
                table = tables{1} ;
            end
        end

        function state = DW_defaultFitConstraintState(app)
            defs = app.DW_fitConstraintDefinitions() ;
            state = repmat(struct( ...
                'variable', '', ...
                'use', false, ...
                'minSI', NaN, ...
                'maxSI', NaN, ...
                'manual', false, ...
                'defaultInitialized', false, ...
                'defaultValueSI', NaN), numel(defs), 1) ;
            for i = 1:numel(defs)
                state(i).variable = defs(i).key ;
            end
            state(app.DW_findFitConstraintRow('N')).minSI = 1 ;
            state(app.DW_findFitConstraintRow('N')).maxSI = 25 ;
            state(app.DW_findFitConstraintRow('Bo')).minSI = 1e-5 ;
            state(app.DW_findFitConstraintRow('Bo')).maxSI = 5 ;
            state(app.DW_findFitConstraintRow('bypassFraction')).minSI = 0 ;
            state(app.DW_findFitConstraintRow('bypassFraction')).maxSI = 0.95 ;
            state(app.DW_findFitConstraintRow('splitToPFR')).minSI = 0 ;
            state(app.DW_findFitConstraintRow('splitToPFR')).maxSI = 1 ;
        end

        function idx = DW_findFitConstraintRow(app, key)
            defs = app.DW_fitConstraintDefinitions() ;
            idx = find(strcmp({defs.key}, key), 1, 'first') ;
        end

        function relevant = DW_relevantFitConstraintVariables(~, family)
            relevant = {} ;
            switch char(string(family))
                case 'Tanks-in-Series'
                    relevant = {'N'} ;
                case 'Axial Dispersion'
                    relevant = {'Bo'} ;
                case {'CSTR (dead volume)', 'PFR (dead volume)'}
                    relevant = {'referenceTau', 'totalVolume'} ;
                case 'PFR + CSTR (series, dead volume)'
                    relevant = {'tau_pfr_active', 'tau_cstr_active', 'referenceTau', 'totalVolume'} ;
                case 'PFR + CSTR (parallel, dead volume)'
                    relevant = {'splitToPFR', 'tau_pfr_active', 'tau_cstr_active', 'referenceTau', 'totalVolume'} ;
                case 'CSTR + Bypass (dead volume)'
                    relevant = {'bypassFraction', 'referenceTau', 'totalVolume'} ;
            end
        end

        function DW_initializeFitConstraintTable(app)
            tables = app.DW_getFitConstraintTableHandles() ;
            if isempty(tables)
                return
            end
            defs = app.DW_fitConstraintDefinitions() ;
            state = app.DW_defaultFitConstraintState() ;
            for i = 1:numel(tables)
                table = tables{i} ;
                tableMode = 'bounds' ;
                if isfield(app.DesignUI.Fit, 'ScalarVariableTable') && isequal(table, app.DesignUI.Fit.ScalarVariableTable)
                    tableMode = 'scalar' ;
                end
                table.UserData = struct( ...
                    'definitions', defs, ...
                    'state', state, ...
                    'relevantRows', [], ...
                    'family', '', ...
                    'isRendering', false, ...
                    'suspendReferenceTauTracking', false, ...
                    'rowIndices', app.DW_fitConstraintRowsByMode(tableMode), ...
                    'tableMode', tableMode) ;
            end
            app.DW_refreshFitConstraintTable() ;
        end

        function state = DW_getFitConstraintState(app)
            state = app.DW_defaultFitConstraintState() ;
            table = app.DW_getPrimaryFitConstraintTable() ;
            if isempty(table) || ~isvalid(table) || ~isstruct(table.UserData)
                return
            end
            if isfield(table.UserData, 'state') && ~isempty(table.UserData.state)
                state = table.UserData.state ;
            end
        end

        function DW_setFitConstraintState(app, state)
            tables = app.DW_getFitConstraintTableHandles() ;
            if isempty(tables)
                return
            end
            for i = 1:numel(tables)
                table = tables{i} ;
                userData = table.UserData ;
                if ~isstruct(userData)
                    userData = struct() ;
                end
                userData.state = state ;
                table.UserData = userData ;
            end
        end

        function valueDisplay = DW_convertFitConstraintToDisplay(app, category, siValue)
            if isempty(siValue) || ~isscalar(siValue) || ~isfinite(siValue)
                valueDisplay = '' ;
                return
            end
            switch category
                case 'time'
                    valueDisplay = app.convertOutputScalar('Time', siValue, app.getDisplayControl('DesignFit', 'time')) ;
                case 'volume'
                    valueDisplay = app.convertOutputScalar('Volume', siValue, app.getDisplayControl('DesignFit', 'volume')) ;
                otherwise
                    valueDisplay = siValue ;
            end
        end

        function valueSI = DW_parseFitConstraintDisplayValue(app, category, rawValue)
            valueSI = NaN ;
            if isempty(rawValue)
                return
            end
            if isstring(rawValue) || ischar(rawValue)
                txt = strtrim(char(string(rawValue))) ;
                if isempty(txt) || strcmpi(txt, 'n/a')
                    return
                end
                numericValue = str2double(txt) ;
            else
                numericValue = double(rawValue) ;
            end
            if ~isscalar(numericValue) || ~isfinite(numericValue)
                return
            end
            switch category
                case 'time'
                    valueSI = UnitConverterHelper.convertToSI('Time', numericValue, ...
                        app.getControlValue(app.getDisplayControl('DesignFit', 'time'), 's')) ;
                case 'volume'
                    valueSI = UnitConverterHelper.convertToSI('Volume', numericValue, ...
                        app.getControlValue(app.getDisplayControl('DesignFit', 'volume'), 'm^3')) ;
                otherwise
                    valueSI = numericValue ;
            end
        end

        function DW_seedFitConstraintDefaults(app)
            state = app.DW_getFitConstraintState() ;
            tauActive = NaN ;
            if ~isempty(app.rtd) && isa(app.rtd, 'RTD') && ~isempty(app.rtd.tau) && isfinite(app.rtd.tau) && app.rtd.tau > 0
                tauActive = app.rtd.tau ;
            end
            for key = {'tau_pfr_active', 'tau_cstr_active'}
                rowIdx = app.DW_findFitConstraintRow(key{1}) ;
                if isempty(rowIdx)
                    continue
                end
                if ~isfinite(state(rowIdx).minSI) || state(rowIdx).minSI <= 0
                    state(rowIdx).minSI = 1e-6 ;
                end
                if isfinite(tauActive) && tauActive > 0 && (~isfinite(state(rowIdx).maxSI) || state(rowIdx).maxSI <= 0)
                    state(rowIdx).maxSI = tauActive ;
                end
            end
            app.DW_setFitConstraintState(state) ;
        end

        function DW_refreshFitConstraintTable(app)
            table = app.DW_getPrimaryFitConstraintTable() ;
            if isempty(table) || ~isvalid(table)
                return
            end
            if ~isstruct(table.UserData)
                return
            end
            app.DW_seedFitConstraintDefaults() ;
            state = app.DW_getFitConstraintState() ;
            defs = table.UserData.definitions ;
            family = app.DesignUI.Fit.FamilyDropdown.Value ;
            relevant = app.DW_relevantFitConstraintVariables(family) ;
            relevantRows = [] ;
            for i = 1:numel(defs)
                if any(strcmp(defs(i).key, relevant))
                    relevantRows(end + 1) = i ; %#ok<AGROW>
                else
                    state(i).use = false ;
                end
            end

            app.DW_setFitConstraintState(state) ;
            app.DW_renderFitConstraintTable(app.DesignUI.Fit.VariableTable, defs, state, relevantRows, family, 'bounds') ;
            if isfield(app.DesignUI.Fit, 'ScalarVariableTable')
                app.DW_renderFitConstraintTable(app.DesignUI.Fit.ScalarVariableTable, defs, state, relevantRows, family, 'scalar') ;
            end
        end

        function DW_renderFitConstraintTable(app, table, defs, state, relevantRows, family, tableMode)
            if isempty(table) || ~isvalid(table)
                return
            end

            rowIndices = app.DW_fitConstraintRowsByMode(tableMode) ;
            localRelevantRows = find(ismember(rowIndices, relevantRows)) ;
            switch tableMode
                case 'scalar'
                    data = cell(numel(rowIndices), 3) ;
                    for i = 1:numel(rowIndices)
                        rowIdx = rowIndices(i) ;
                        data{i, 1} = logical(state(rowIdx).use) ;
                        data{i, 2} = defs(rowIdx).label ;
                        data{i, 3} = app.DW_convertFitConstraintToDisplay(defs(rowIdx).category, state(rowIdx).minSI) ;
                    end
                otherwise
                    data = cell(numel(rowIndices), 4) ;
                    for i = 1:numel(rowIndices)
                        rowIdx = rowIndices(i) ;
                        data{i, 1} = logical(state(rowIdx).use) ;
                        data{i, 2} = defs(rowIdx).label ;
                        data{i, 3} = app.DW_convertFitConstraintToDisplay(defs(rowIdx).category, state(rowIdx).minSI) ;
                        data{i, 4} = app.DW_convertFitConstraintToDisplay(defs(rowIdx).category, state(rowIdx).maxSI) ;
                    end
            end

            userData = table.UserData ;
            if ~isstruct(userData)
                userData = struct() ;
            end
            userData.definitions = defs ;
            userData.state = state ;
            userData.relevantRows = relevantRows ;
            userData.family = family ;
            userData.rowIndices = rowIndices ;
            userData.tableMode = tableMode ;
            userData.isRendering = true ;
            table.UserData = userData ;
            table.Data = data ;
            userData = table.UserData ;
            userData.isRendering = false ;
            table.UserData = userData ;
            app.DW_applyFitConstraintTableStyles(table, localRelevantRows) ;
        end

        function DW_applyFitConstraintTableStyles(~, table, relevantRows)
            if isempty(table) || ~isvalid(table)
                return
            end
            try
                removeStyle(table) ;
            catch
            end
            inactiveRows = setdiff(1:size(table.Data, 1), relevantRows) ;
            if isempty(inactiveRows)
                return
            end
            try
                style = uistyle('BackgroundColor', [0.94 0.94 0.94], 'FontColor', [0.45 0.45 0.45]) ;
                addStyle(table, style, 'row', inactiveRows) ;
            catch
            end
        end

        function state = DW_captureFitConstraintState(app)
            state = app.DW_getFitConstraintState() ;
        end

        function DW_applyFitConstraintSnapshot(app, storedState, legacyReferenceTau, legacyTotalVolume)
            state = app.DW_defaultFitConstraintState() ;
            if isstruct(storedState) && ~isempty(storedState)
                defs = app.DW_fitConstraintDefinitions() ;
                for i = 1:numel(state)
                    key = defs(i).key ;
                    idx = find(arrayfun(@(s) isfield(s, 'variable') && strcmp(s.variable, key), storedState), 1, 'first') ;
                    if isempty(idx)
                        continue
                    end
                    incoming = storedState(idx) ;
                    state(i).use = logical(app.getStructField(incoming, 'use', state(i).use)) ;
                    state(i).minSI = app.getStructField(incoming, 'minSI', state(i).minSI) ;
                    state(i).maxSI = app.getStructField(incoming, 'maxSI', state(i).maxSI) ;
                    state(i).manual = logical(app.getStructField(incoming, 'manual', state(i).manual)) ;
                    state(i).defaultInitialized = logical(app.getStructField(incoming, 'defaultInitialized', state(i).defaultInitialized)) ;
                    state(i).defaultValueSI = app.getStructField(incoming, 'defaultValueSI', state(i).defaultValueSI) ;
                end
            else
                refIdx = app.DW_findFitConstraintRow('referenceTau') ;
                totalIdx = app.DW_findFitConstraintRow('totalVolume') ;
                if isstruct(legacyReferenceTau) && isfield(legacyReferenceTau, 'value')
                    state(refIdx).minSI = app.DW_parseLegacyConstraintField(legacyReferenceTau, 'Time') ;
                    state(refIdx).manual = true ;
                    state(refIdx).defaultInitialized = true ;
                end
                if isstruct(legacyTotalVolume) && isfield(legacyTotalVolume, 'value')
                    state(totalIdx).minSI = app.DW_parseLegacyConstraintField(legacyTotalVolume, 'Volume') ;
                    state(totalIdx).manual = true ;
                end
            end
            app.DW_setFitConstraintState(state) ;
            app.DW_syncDefaultReferenceTau() ;
            app.DW_refreshFitConstraintTable() ;
        end

        function valueSI = DW_parseLegacyConstraintField(~, state, category)
            valueSI = NaN ;
            if ~isstruct(state) || ~isfield(state, 'value')
                return
            end
            if isempty(state.value)
                return
            end
            if isfield(state, 'unit') && ~isempty(state.unit)
                valueSI = UnitConverterHelper.convertToSI(category, state.value, state.unit) ;
            else
                valueSI = state.value ;
            end
        end

        function updateInputFieldCategory(~, field, unitCat)
            fieldData = field.UserData ;
            fieldData.unitCategory = unitCat ;
            field.UserData = fieldData ;

            unitDropdown = fieldData.unitDropdown ;
            if isempty(unitDropdown) || ~isvalid(unitDropdown)
                return
            end

            currentUnit = unitDropdown.Value ;
            unitDropdown.Items = UnitConverterHelper.getUnits(unitCat) ;
            if any(strcmp(unitDropdown.Items, currentUnit))
                unitDropdown.Value = currentUnit ;
            else
                unitDropdown.Value = UnitConverterHelper.defaultUnit(unitCat) ;
            end

        end

        function cat = getKCategory(~, dropdown)
            % getKCategory  Return the correct unit converter category for k
            %   based on the current kinetics selection in the given dropdown.
            if contains(dropdown.Value, '2nd')
                cat = 'k_2ndOrder' ;
            else
                cat = 'k_1stOrder' ;
            end
        end

        function dropdown = createDisplayUnitControl(~, parentGrid, row, col, ...
                labelText, category, defaultUnit, callbackFcn, dropdownWidth)
            if nargin < 9 || isempty(dropdownWidth)
                dropdownWidth = 110 ;
            end
            subGrid = uigridlayout(parentGrid, [1 2], ...
                'ColumnWidth', {'fit', dropdownWidth}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4) ;
            subGrid.Layout.Row = row ;
            subGrid.Layout.Column = col ;

            labelArgs = {'Text', labelText, 'FontSize', 11} ;
            if contains(labelText, '<')
                labelArgs = [labelArgs, {'Interpreter', 'html'}] ;
            elseif contains(labelText, '$')
                labelArgs = [labelArgs, {'Interpreter', 'latex'}] ;
            end
            label = uilabel(subGrid, labelArgs{:}) ;
            dropdown = uidropdown(subGrid, ...
                'Items', UnitConverterHelper.getUnits(category), ...
                'Value', defaultUnit, ...
                'FontSize', 11, ...
                'Tooltip', sprintf('Choose the display unit for %s. This only changes how results are shown in the UI.', ...
                    lower(strrep(labelText, ':', ''))), ...
                'ValueChangedFcn', callbackFcn) ;
            dropdown.Layout.Row = 1 ;
            dropdown.Layout.Column = 2 ;
            label.Tooltip = dropdown.Tooltip ;
        end

        function dropdown = createDisplayChoiceControl(~, parentGrid, row, col, ...
                labelText, items, defaultValue, callbackFcn, dropdownWidth)
            if nargin < 9 || isempty(dropdownWidth)
                dropdownWidth = 110 ;
            end
            subGrid = uigridlayout(parentGrid, [1 2], ...
                'ColumnWidth', {'fit', dropdownWidth}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4) ;
            subGrid.Layout.Row = row ;
            subGrid.Layout.Column = col ;

            labelArgs = {'Text', labelText, 'FontSize', 11} ;
            if contains(labelText, '<')
                labelArgs = [labelArgs, {'Interpreter', 'html'}] ;
            elseif contains(labelText, '$')
                labelArgs = [labelArgs, {'Interpreter', 'latex'}] ;
            end
            label = uilabel(subGrid, labelArgs{:}) ;
            dropdown = uidropdown(subGrid, ...
                'Items', items, ...
                'Value', defaultValue, ...
                'FontSize', 11, ...
                'Tooltip', sprintf('Choose the option used for %s.', ...
                    lower(strrep(labelText, ':', ''))), ...
                'ValueChangedFcn', callbackFcn) ;
            dropdown.Layout.Row = 1 ;
            dropdown.Layout.Column = 2 ;
            label.Tooltip = dropdown.Tooltip ;
        end

        function listbox = createDisplayMultiSelectControl(~, parentGrid, row, col, ...
                labelText, callbackFcn, listHeight)
            if nargin < 7 || isempty(listHeight)
                listHeight = 88 ;
            end
            if isstring(listHeight) && isscalar(listHeight)
                listHeight = char(listHeight) ;
            end
            subGrid = uigridlayout(parentGrid, [2 1], ...
                'RowHeight', {18, listHeight}, ...
                'ColumnWidth', {'1x'}, ...
                'Padding', [0 0 0 0], ...
                'RowSpacing', 4) ;
            subGrid.Layout.Row = row ;
            subGrid.Layout.Column = col ;

            tooltipText = sprintf('Select which %s are used in this section.', ...
                lower(strrep(labelText, ':', ''))) ;
            if strcmpi(strtrim(labelText), 'Reactants:')
                tooltipText = ['Select which functional reactants are used in this section. ' ...
                    'Functional reactants include consumed intermediates in reversible or bidirectional systems.'] ;
            end
            label = uilabel(subGrid, 'Text', labelText, 'FontSize', 11, ...
                'FontWeight', 'bold') ;
            listbox = uilistbox(subGrid, ...
                'Multiselect', 'on', ...
                'FontSize', 11, ...
                'Tooltip', tooltipText, ...
                'ValueChangedFcn', callbackFcn) ;
            listbox.Layout.Row = 2 ;
            listbox.Layout.Column = 1 ;
            label.Tooltip = listbox.Tooltip ;
        end

        function value = convertOutputScalar(~, category, siValue, dropdown)
            if isempty(dropdown) || ~isvalid(dropdown)
                value = siValue ;
                return
            end
            value = UnitConverterHelper.convertFromSI(category, siValue, dropdown.Value) ;
        end

        function values = convertOutputVector(~, category, siValues, dropdown)
            if isempty(dropdown) || ~isvalid(dropdown)
                values = siValues ;
                return
            end
            values = UnitConverterHelper.convertFromSI(category, siValues, dropdown.Value) ;
        end

        function values = convertOutputConcentration(app, siValues, dropdown)
            values = app.convertOutputVector('Concentration', siValues, dropdown) ;
        end

        function label = axisLabelWithUnit(~, baseText, dropdown)
            if isempty(dropdown) || ~isvalid(dropdown)
                label = baseText ;
                return
            end
            label = sprintf('%s [%s]', baseText, dropdown.Value) ;
        end

        function label = htmlLabelWithUnit(app, baseHtml, dropdown)
            unitText = app.unitToHtml(dropdown.Value) ;
            label = sprintf('%s [%s]:', baseHtml, unitText) ;
        end

        function label = latexLabelWithUnit(~, baseLatex, unitText)
            label = sprintf('%s [%s]:', baseLatex, unitText) ;
        end

        function label = axisLabelWithUnitName(~, baseText, unitName)
            label = sprintf('%s [%s]', baseText, unitName) ;
        end

        function unitName = timeSquaredUnitName(~, timeDropdown)
            switch timeDropdown.Value
                case 's'
                    unitName = 's^2' ;
                case 'min'
                    unitName = 'min^2' ;
                case 'h'
                    unitName = 'h^2' ;
                otherwise
                    unitName = 's^2' ;
            end
        end

        function unitName = timeInverseUnitName(~, timeDropdown)
            unitName = ['1/' timeDropdown.Value] ;
        end

        function value = convertOutputFromTime(app, mode, siValue, timeDropdown)
            switch mode
                case 'time'
                    value = app.convertOutputScalar('Time', siValue, timeDropdown) ;
                case 'timeSquared'
                    value = UnitConverterHelper.convertFromSI('TimeSquared', siValue, ...
                        app.timeSquaredUnitName(timeDropdown)) ;
                case 'timeInverse'
                    value = UnitConverterHelper.convertFromSI('TimeInverse', siValue, ...
                        app.timeInverseUnitName(timeDropdown)) ;
                otherwise
                    value = siValue ;
            end
        end

        function values = convertOutputVectorFromTime(app, mode, siValues, timeDropdown)
            switch mode
                case 'time'
                    values = app.convertOutputVector('Time', siValues, timeDropdown) ;
                case 'timeInverse'
                    values = UnitConverterHelper.convertFromSI('TimeInverse', siValues, ...
                        app.timeInverseUnitName(timeDropdown)) ;
                otherwise
                    values = siValues ;
            end
        end

        function refreshDisplayUnits(app, tabName)
            switch tabName
                case 'RTD'
                    app.RTD_updateResults() ;
                    app.RTD_updatePlots() ;
                    app.RTD_syncQueryFieldToDisplayUnit() ;
                    app.RTD_updateFQuery() ;
                case 'Prediction'
                    app.Pred_updatePlots() ;
                case 'TIS'
                    if isfield(app.DisplayCache, 'TIS') && ~isempty(app.DisplayCache.TIS)
                        c = app.DisplayCache.TIS ;
                        app.TIS_updatePlots(c.N_val, c.tau_val, c.RS, c.C0, ...
                            c.X_tis, c.X_cstr, c.X_pfr, ...
                            c.C_out_tis, c.C_out_cstr, c.C_out_pfr) ;
                    end
                case 'Dispersion'
                    if isfield(app.DisplayCache, 'Dispersion') && ~isempty(app.DisplayCache.Dispersion)
                        c = app.DisplayCache.Dispersion ;
                        app.Disp_updatePlots(c.Bo_val, c.tau_val, c.RS, c.C0, ...
                            c.X_disp, c.X_cstr, c.X_pfr, ...
                            c.C_out_disp, c.C_out_cstr, c.C_out_pfr, c.bcType) ;
                    end
                case 'DesignFit'
                    app.DW_refreshFitConstraintTable() ;
                    app.DW_refreshFit() ;
                case 'DesignReactive'
                    app.DW_refreshReactive() ;
                case 'DesignOptimization'
                    app.DW_refreshOptimization() ;
            end
        end

        function labels = getComponentLabels(app, nComp)
            labels = arrayfun(@(i) ['C' app.componentLetterSuffix(i)], ...
                1:nComp, 'UniformOutput', false) ;
        end

        function suffix = componentLetterSuffix(~, idx)
            alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' ;
            suffix = '' ;
            idx = round(double(idx)) ;
            if ~isfinite(idx) || idx < 1
                idx = 1 ;
            end
            while idx > 0
                remIdx = mod(idx - 1, numel(alphabet)) + 1 ;
                suffix = [alphabet(remIdx) suffix] ; %#ok<AGROW>
                idx = floor((idx - 1) / numel(alphabet)) ;
            end
        end

        function labels = getReactionComponentLabels(app, RS)
            labels = app.getComponentLabels(RS.nComponents) ;
            if ~isprop(RS, 'componentNames') || isempty(RS.componentNames)
                return
            end

            for i = 1:min(numel(RS.componentNames), RS.nComponents)
                nameValue = RS.componentNames{i} ;
                if isstring(nameValue)
                    nameValue = char(nameValue) ;
                end
                if ischar(nameValue)
                    nameValue = strtrim(nameValue) ;
                    if ~isempty(nameValue)
                        labels{i} = nameValue ;
                    end
                end
            end
        end

        function info = getPredictionReactantInfo(app, RS, C0)
            compLabels = app.getReactionComponentLabels(RS) ;
            reactantIdx = app.getFunctionalReactantIndices(RS, C0) ;
            reactantLabels = compLabels(reactantIdx) ;
            info = struct( ...
                'componentLabels', {compLabels}, ...
                'reactantIndices', reactantIdx, ...
                'reactantLabels', {reactantLabels}) ;
        end

        function reactantIdx = getFunctionalReactantIndices(~, RS, C0)
            reactantMask = any(RS.stochiometricMatrix < 0, 1) ;
            reactantIdx = find(reactantMask & (C0(:)' > 1e-12)) ;
        end

        function ensurePredictionReactantSelector(~, listbox, reactantInfo)
            if isempty(listbox) || ~isvalid(listbox)
                return
            end

            if isempty(reactantInfo.reactantIndices)
                listbox.Items = {'No functional reactants'} ;
                listbox.ItemsData = [] ;
                listbox.Value = {'No functional reactants'} ;
                listbox.Enable = 'off' ;
                return
            end

            currentValue = [] ;
            if isnumeric(listbox.Value)
                currentValue = reshape(listbox.Value, 1, []) ;
            end
            listbox.Enable = 'on' ;
            listbox.Items = reactantInfo.reactantLabels ;
            listbox.ItemsData = reactantInfo.reactantIndices ;
            selectedValues = intersect(reactantInfo.reactantIndices, currentValue, 'stable') ;
            if isempty(selectedValues)
                selectedValues = reactantInfo.reactantIndices ;
            end
            listbox.Value = selectedValues ;
        end

        function idx = getPredictionSelectedReactants(~, listbox, reactantInfo)
            if isempty(reactantInfo.reactantIndices) || isempty(listbox) || ~isvalid(listbox) || ...
                    strcmp(listbox.Enable, 'off')
                idx = [] ;
                return
            end

            if isnumeric(listbox.Value)
                idx = reshape(listbox.Value, 1, []) ;
            else
                idx = [] ;
            end
        end

        function info = getPredictionSpeciesInfo(app, RS)
            compLabels = app.getReactionComponentLabels(RS) ;
            speciesIdx = 1:RS.nComponents ;
            info = struct( ...
                'componentLabels', {compLabels}, ...
                'speciesIndices', speciesIdx) ;
        end

        function ensurePredictionSpeciesSelector(~, listbox, speciesInfo)
            if isempty(listbox) || ~isvalid(listbox)
                return
            end

            if isempty(speciesInfo.speciesIndices)
                listbox.Items = {'No species'} ;
                listbox.ItemsData = [] ;
                listbox.Value = {'No species'} ;
                listbox.Enable = 'off' ;
                return
            end

            currentValue = [] ;
            if isnumeric(listbox.Value)
                currentValue = reshape(listbox.Value, 1, []) ;
            end
            listbox.Enable = 'on' ;
            listbox.Items = speciesInfo.componentLabels ;
            listbox.ItemsData = speciesInfo.speciesIndices ;
            selectedValues = intersect(speciesInfo.speciesIndices, currentValue, 'stable') ;
            if isempty(selectedValues)
                selectedValues = speciesInfo.speciesIndices ;
            end
            listbox.Value = selectedValues ;
        end

        function idx = getPredictionSelectedSpecies(~, listbox, speciesInfo)
            if isempty(speciesInfo.speciesIndices) || isempty(listbox) || ~isvalid(listbox) || ...
                    strcmp(listbox.Enable, 'off')
                idx = [] ;
                return
            end

            if isnumeric(listbox.Value)
                idx = reshape(listbox.Value, 1, []) ;
            else
                idx = [] ;
            end
        end

        function [labels, colors] = getPredictionModelLegendSpec(~)
            labels = {'Ideal CSTR', 'Segregation', 'Max Mixedness', 'Ideal PFR'} ;
            colors = [ ...
                0.29 0.64 0.25
                0.18 0.45 0.78
                0.85 0.33 0.10
                0.49 0.18 0.56] ;
        end

        function applyPredictionBarStyles(app, barHandles)
            [labels, colors] = app.getPredictionModelLegendSpec() ;
            for i = 1:min(numel(barHandles), size(colors, 1))
                barHandles(i).FaceColor = colors(i, :) ;
                barHandles(i).DisplayName = labels{i} ;
            end
        end

        function setPredictionAnnotatedYLimits(~, ax, valueMatrix, minimumUpper)
            if nargin < 4 || isempty(minimumUpper)
                minimumUpper = [] ;
            end
            if isempty(valueMatrix)
                return
            end

            finiteValues = valueMatrix(isfinite(valueMatrix)) ;
            if isempty(finiteValues)
                return
            end

            minVal = min([0; finiteValues(:)]) ;
            maxVal = max([0; finiteValues(:)]) ;
            span = maxVal - minVal ;
            if span < 1e-12
                span = max([1, abs(maxVal), abs(minVal)]) ;
            end

            pad = max([0.12 * span, 0.04 * max(abs([minVal, maxVal])), 0.02]) ;
            lowerLim = minVal - 0.35 * pad ;
            upperLim = maxVal + 1.75 * pad ;

            if minVal >= 0
                lowerLim = 0 ;
            end
            if ~isempty(minimumUpper)
                upperLim = max(upperLim, minimumUpper) ;
            end

            ylim(ax, [lowerLim, upperLim]) ;
        end

        function annotatePredictionBars(~, ax, barHandles, valueMatrix, formatSpec)
            if isempty(barHandles) || isempty(valueMatrix)
                return
            end

            nSeries = min(numel(barHandles), size(valueMatrix, 2)) ;
            for i = 1:nSeries
                if ~isprop(barHandles(i), 'XEndPoints') || ~isprop(barHandles(i), 'YEndPoints')
                    continue
                end

                xPos = barHandles(i).XEndPoints ;
                yPos = barHandles(i).YEndPoints ;
                nPoints = min(numel(xPos), size(valueMatrix, 1)) ;
                for k = 1:nPoints
                    value = valueMatrix(k, i) ;
                    if ~isfinite(value)
                        continue
                    end

                    vAlign = 'bottom' ;
                    if yPos(k) < 0
                        vAlign = 'top' ;
                    end

                    text(ax, xPos(k), yPos(k), sprintf(formatSpec, value), ...
                        'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', vAlign, ...
                        'FontSize', 8, ...
                        'Clipping', 'on') ;
                end
            end
        end

        function legendHandles = createPredictionLegendPlaceholders(app, ax)
            [labels, colors] = app.getPredictionModelLegendSpec() ;
            legendHandles = gobjects(1, numel(labels)) ;
            hold(ax, 'on') ;
            for i = 1:numel(labels)
                legendHandles(i) = plot(ax, nan, nan, 's', ...
                    'MarkerSize', 8, ...
                    'MarkerFaceColor', colors(i, :), ...
                    'MarkerEdgeColor', colors(i, :), ...
                    'LineStyle', 'none', ...
                    'DisplayName', labels{i}) ;
            end
            hold(ax, 'off') ;
        end

        function updatePredictionSharedLegend(app, legendHandles)
            if ~isempty(app.Pred_SharedLegend) && isvalid(app.Pred_SharedLegend)
                delete(app.Pred_SharedLegend) ;
            end
            [labels, ~] = app.getPredictionModelLegendSpec() ;
            app.Pred_SharedLegend = legend(app.Pred_AxesXbatch, legendHandles, labels, ...
                'Orientation', 'horizontal', ...
                'Location', 'southoutside') ;
            app.Pred_SharedLegend.Layout.Tile = 'south' ;
        end

        function values = computePredictionModelComparison(~, X_model, X_reference)
            values = nan(size(X_model)) ;
            validMask = abs(X_reference) > 1e-12 ;
            values(validMask) = (X_model(validMask) - X_reference(validMask)) ./ ...
                max(abs(X_reference(validMask)), eps) * 100 ;
        end

        function updatePredictionMixingEffectPanel(app, reactantInfo, selectedIdx, ...
                X_seg_all, X_mm_all, X_cstr_all, X_pfr_all, X_seg_cstr_all)
            if isempty(app.Pred_MixingEffectPanel) || ~isvalid(app.Pred_MixingEffectPanel)
                return
            end

            app.Pred_MixingEffectPanel.Title = 'Macromixing / Micromixing Map' ;

            if isempty(reactantInfo.reactantIndices)
                app.Pred_MixingEffectAxes.Visible = 'off' ;
                app.Pred_MixingEffectLabel.Visible = 'on' ;
                app.Pred_MixingEffectLabel.Text = 'No functional reactants with C_0 > 0' ;
                return
            end

            if isempty(selectedIdx)
                app.Pred_MixingEffectAxes.Visible = 'off' ;
                app.Pred_MixingEffectLabel.Visible = 'on' ;
                app.Pred_MixingEffectLabel.Text = 'No functional reactants selected' ;
                return
            end

            activeReactantIdx = selectedIdx(1) ;
            reactantPlotPos = find(reactantInfo.reactantIndices == activeReactantIdx, 1) ;
            if isempty(reactantPlotPos)
                app.Pred_MixingEffectAxes.Visible = 'off' ;
                app.Pred_MixingEffectLabel.Visible = 'on' ;
                app.Pred_MixingEffectLabel.Text = 'Selected reactant is no longer available' ;
                return
            end

            app.Pred_MixingEffectLabel.Visible = 'off' ;
            app.Pred_MixingEffectAxes.Visible = 'on' ;
            app.drawPredictionMixingEffectMap( ...
                app.Pred_MixingEffectAxes, ...
                reactantInfo.componentLabels{activeReactantIdx}, ...
                numel(selectedIdx), ...
                X_pfr_all(reactantPlotPos), ...
                X_seg_all(reactantPlotPos), ...
                X_mm_all(reactantPlotPos), ...
                X_seg_cstr_all(reactantPlotPos), ...
                X_cstr_all(reactantPlotPos)) ;
        end

        function X_seg_cstr_all = computePredictionSegregatedCSTRConversions(app, RS, C0, reactantIndices)
            X_seg_cstr_all = nan(1, numel(reactantIndices)) ;
            if isempty(reactantIndices) || isempty(app.rtd) || ~isfinite(app.rtd.tau) || app.rtd.tau <= 0
                return
            end
            segCstrModel = SegregationModel(RTD.ideal_cstr(app.rtd.tau)) ;
            segCstrModel = segCstrModel.compute_isothermal(RS, C0) ;
            X_seg_cstr_all = app.computeSpeciesConversion(C0, segCstrModel.C_exit, reactantIndices) ;
        end

        function drawPredictionMixingEffectMap(app, ax, reactantLabel, nSelected, X_pfr, X_seg, X_mm, X_seg_cstr, X_cstr)
            cla(ax) ;
            hold(ax, 'on') ;
            [~, baseColors] = app.getPredictionModelLegendSpec() ;
            cstrColor = baseColors(1, :) ;
            segColor = baseColors(2, :) ;
            mmColor = baseColors(3, :) ;
            pfrColor = baseColors(4, :) ;
            tol = 1e-12 ;
            leaderColor = [0.45 0.45 0.45] ;

            xCandidates = [] ;
            noteText = "" ;

            denomSeg = X_seg_cstr - X_pfr ;
            if isfinite(denomSeg) && abs(denomSeg) > tol
                xCandidates(end + 1) = (X_seg - X_pfr) / denomSeg ; %#ok<AGROW>
            end

            denomMM = X_cstr - X_pfr ;
            if isfinite(denomMM) && abs(denomMM) > tol
                xCandidates(end + 1) = (X_mm - X_pfr) / denomMM ; %#ok<AGROW>
            end

            if isempty(xCandidates)
                xRTD = 0.5 ;
                noteText = "RTD horizontal position is indeterminate from these conversions; using x = 0.5" ;
            else
                xRTD = mean(xCandidates) ;
            end
            xRTD = min(max(xRTD, 0), 1) ;

            patch(ax, [0 1 1], [0 0 1], [0.72 0.80 0.90], ...
                'FaceAlpha', 0.35, 'EdgeColor', 'none') ;
            plot(ax, [0 1], [0 0], '-', 'Color', [0.00 0.70 0.35], 'LineWidth', 2.5) ;
            plot(ax, [0 1], [0 1], '-', 'Color', mmColor, 'LineWidth', 2.5) ;
            plot(ax, [1 1], [0 1], '-', 'Color', [0.80 0.00 0.00], 'LineWidth', 2.5) ;
            plot(ax, [xRTD xRTD], [0 xRTD], '--', 'Color', [0.25 0.25 0.25], 'LineWidth', 1.2) ;

            text(ax, 0.50, -0.055, 'Complete Segregation', ...
                'Color', [0.00 0.60 0.30], 'FontSize', 10, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'top') ;
            text(ax, 0.44, 0.58, 'Maximum Mixedness', ...
                'Color', mmColor, 'FontSize', 10, 'Rotation', 43, ...
                'HorizontalAlignment', 'center') ;
            text(ax, 1.025, 0.84, 'RTD of a CSTR', ...
                'Color', [0.80 0.00 0.00], 'FontSize', 10, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle') ;

            plot(ax, 0, 0, 'o', 'MarkerSize', 8, ...
                'MarkerFaceColor', pfrColor, 'MarkerEdgeColor', pfrColor, 'LineWidth', 1.2) ;
            plot(ax, 1, 0, 'd', 'MarkerSize', 9, ...
                'MarkerFaceColor', cstrColor, 'MarkerEdgeColor', segColor, 'LineWidth', 1.6) ;
            plot(ax, 1, 1, 'o', 'MarkerSize', 9, ...
                'MarkerFaceColor', cstrColor, 'MarkerEdgeColor', cstrColor, 'LineWidth', 1.2) ;
            plot(ax, xRTD, xRTD, 's', 'MarkerSize', 10, ...
                'MarkerFaceColor', 'none', 'MarkerEdgeColor', mmColor, 'LineWidth', 1.8) ;
            plot(ax, xRTD, 0, 'o', 'MarkerSize', 8, ...
                'MarkerFaceColor', segColor, 'MarkerEdgeColor', segColor, 'LineWidth', 1.2) ;

            pfrTextX = -0.055 ; pfrTextY = 0.02 ; pfrAlign = 'right' ; pfrVAlign = 'bottom' ; pfrLeader = false ;
            segTextX = xRTD ; segTextY = 0.045 ; segAlign = 'center' ; segVAlign = 'bottom' ; segLeader = false ;
            mmTextX = xRTD - 0.035 ; mmTextY = xRTD + 0.03 ; mmAlign = 'right' ; mmVAlign = 'bottom' ; mmLeader = false ;
            segCstrTextX = 1.03 ; segCstrTextY = 0.05 ; segCstrAlign = 'left' ; segCstrVAlign = 'bottom' ; segCstrLeader = false ;
            idealCstrTextX = 1.03 ; idealCstrTextY = 1.015 ; idealCstrAlign = 'left' ; idealCstrVAlign = 'bottom' ; idealCstrLeader = false ;

            if xRTD <= 0.12
                pfrTextX = -0.115 ; pfrTextY = 0.055 ; pfrLeader = true ;
                segTextX = -0.115 ; segTextY = 0.005 ; segAlign = 'right' ; segVAlign = 'bottom' ; segLeader = true ;
            end

            if xRTD <= 0.18
                mmTextX = 0.14 ; mmTextY = max(0.14, xRTD + 0.08) ; mmAlign = 'left' ; mmVAlign = 'bottom' ; mmLeader = true ;
            end

            if (1 - xRTD) <= 0.08
                segTextX = 1.045 ; segTextY = 0.085 ; segAlign = 'left' ; segVAlign = 'bottom' ; segLeader = true ;
                segCstrTextX = 1.045 ; segCstrTextY = 0.018 ; segCstrAlign = 'left' ; segCstrVAlign = 'bottom' ; segCstrLeader = true ;
            end

            if (1 - xRTD) <= 0.10 || ...
                    (abs(mmTextX - idealCstrTextX) <= 0.10 && abs(mmTextY - idealCstrTextY) <= 0.10)
                mmTextX = 1.045 ; mmTextY = 0.965 ; mmAlign = 'left' ; mmVAlign = 'bottom' ; mmLeader = true ;
                idealCstrTextX = 1.045 ; idealCstrTextY = 1.055 ; idealCstrAlign = 'left' ; idealCstrVAlign = 'bottom' ; idealCstrLeader = true ;
            end

            app.annotatePredictionMixingPoint(ax, 0, 0, 'Ideal PFR', X_pfr, ...
                pfrTextX, pfrTextY, pfrAlign, pfrVAlign, pfrLeader, leaderColor) ;
            app.annotatePredictionMixingPoint(ax, 1, 0, 'Segregated CSTR RTD', X_seg_cstr, ...
                segCstrTextX, segCstrTextY, segCstrAlign, segCstrVAlign, segCstrLeader, leaderColor) ;
            app.annotatePredictionMixingPoint(ax, 1, 1, 'Ideal CSTR', X_cstr, ...
                idealCstrTextX, idealCstrTextY, idealCstrAlign, idealCstrVAlign, idealCstrLeader, leaderColor) ;
            app.annotatePredictionMixingPoint(ax, xRTD, 0, 'Segregation', X_seg, ...
                segTextX, segTextY, segAlign, segVAlign, segLeader, leaderColor) ;
            app.annotatePredictionMixingPoint(ax, xRTD, xRTD, 'Maximum Mixedness', X_mm, ...
                mmTextX, mmTextY, mmAlign, mmVAlign, mmLeader, leaderColor) ;

            deltaXMicro = abs(X_mm - X_seg) ;
            microTextX = min(max(xRTD + 0.06, 0.22), 0.74) ;
            microTextY = min(max(0.11, xRTD * 0.42), 0.34) ;
            if xRTD <= 0.18
                microTextX = 0.22 ;
                microTextY = 0.10 ;
            elseif (1 - xRTD) <= 0.10
                microTextX = 0.72 ;
                microTextY = 0.32 ;
            end
            text(ax, microTextX, microTextY, ...
                sprintf('Micromixing effect\n\\DeltaX = %.4f', deltaXMicro), ...
                'FontSize', 9, 'Color', [0.2 0.2 0.2], ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'Interpreter', 'tex') ;

            titleText = sprintf('Active reactant: %s', reactantLabel) ;
            if nSelected > 1
                titleText = sprintf('Active reactant: %s (first selected)', reactantLabel) ;
            end
            title(ax, titleText) ;
            xlabel(ax, 'Macromixing / RTD effect') ;
            ylabel(ax, 'Degree of Micromixing') ;
            xlim(ax, [-0.18 1.19]) ;
            ylim(ax, [-0.12 1.13]) ;
            ax.XTick = [] ;
            ax.YTick = [] ;
            ax.Box = 'off' ;
            grid(ax, 'off') ;
            ax.DataAspectRatio = [1 1 1] ;

            if strlength(noteText) > 0
                text(ax, 0.02, 1.08, noteText, ...
                    'FontSize', 8.5, 'Color', [0.30 0.30 0.30], ...
                    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top') ;
            end

            hold(ax, 'off') ;
        end

        function annotatePredictionMixingPoint(~, ax, x, y, modelLabel, conversionValue, textX, textY, hAlign, vAlign, showLeader, leaderColor)
            if showLeader
                plot(ax, [x textX], [y textY], ':', 'Color', leaderColor, 'LineWidth', 0.9) ;
            end
            text(ax, textX, textY, sprintf('%s\nX = %.4f', modelLabel, conversionValue), ...
                'FontSize', 9, 'HorizontalAlignment', hAlign, 'VerticalAlignment', vAlign) ;
        end

        function X = computeSpeciesConversion(~, C0, C_exit, indices)
            X = zeros(1, numel(indices)) ;
            for k = 1:numel(indices)
                i = indices(k) ;
                denom = max(C0(i), 1e-12) ;
                X(k) = (C0(i) - C_exit(i)) / denom ;
            end
            X = max(min(X, 1), 0) ;
        end

        function roles = classifySpeciesRoles(~, RS)
            nComp = RS.nComponents ;
            roles = cell(1, nComp) ;
            for i = 1:nComp
                hasNeg = any(RS.stochiometricMatrix(:, i) < 0) ;
                hasPos = any(RS.stochiometricMatrix(:, i) > 0) ;
                if hasNeg && ~hasPos
                    roles{i} = 'Reactant' ;
                elseif ~hasNeg && hasPos
                    roles{i} = 'Product' ;
                elseif hasNeg && hasPos
                    roles{i} = 'Intermediate' ;
                else
                    roles{i} = 'Inert' ;
                end
            end
        end

        function rolePriority = getSpeciesRolePriority(~, roles)
            rolePriority = zeros(1, numel(roles)) ;
            for i = 1:numel(roles)
                switch roles{i}
                    case 'Reactant'
                        rolePriority(i) = 1 ;
                    case 'Intermediate'
                        rolePriority(i) = 2 ;
                    case 'Product'
                        rolePriority(i) = 3 ;
                    otherwise
                        rolePriority(i) = 4 ;
                end
            end
        end

        function rowOrder = getDefaultSpeciesRowOrder(app, roles, nComp, functionalIndices)
            functionalPriority = ones(1, nComp) * 2 ;
            functionalPriority(functionalIndices) = 1 ;
            rolePriority = app.getSpeciesRolePriority(roles) ;
            [~, rowOrder] = sortrows([functionalPriority(:), rolePriority(:), (1:nComp)']) ;
            rowOrder = rowOrder(:)' ;
        end

        function updatePredictionSummaryTable(app, ...
                compLabels, roles, C0, ...
                C_seg, C_mm, C_cstr, C_pfr, ...
                reactantIndices, X_seg, X_mm, X_cstr, X_pfr, ...
                selectedIdx, concDropdown)

            nComp = numel(compLabels) ;
            summaryRows = cell(nComp, 11) ;
            concMatrix = [C0(:), C_seg(:), C_mm(:), C_cstr(:), C_pfr(:)] ;
            concDisplay = reshape(app.convertOutputConcentration(concMatrix(:)', concDropdown), size(concMatrix)) ;

            reactantPosMap = containers.Map('KeyType', 'double', 'ValueType', 'double') ;
            for k = 1:numel(reactantIndices)
                reactantPosMap(reactantIndices(k)) = k ;
            end

            for i = 1:nComp
                summaryRows{i, 1} = compLabels{i} ;
                summaryRows{i, 2} = roles{i} ;
                for j = 1:5
                    summaryRows{i, j + 2} = sprintf('%.4g', concDisplay(i, j)) ;
                end

                if isKey(reactantPosMap, i)
                    pos = reactantPosMap(i) ;
                    summaryRows{i, 8} = sprintf('%.4f', X_cstr(pos)) ;
                    summaryRows{i, 9} = sprintf('%.4f', X_seg(pos)) ;
                    summaryRows{i, 10} = sprintf('%.4f', X_mm(pos)) ;
                    summaryRows{i, 11} = sprintf('%.4f', X_pfr(pos)) ;
                else
                    summaryRows{i, 8} = '--' ;
                    summaryRows{i, 9} = '--' ;
                    summaryRows{i, 10} = '--' ;
                    summaryRows{i, 11} = '--' ;
                end
            end

            if isempty(selectedIdx) || isequal(selectedIdx, reactantIndices)
                rowOrder = app.getDefaultSpeciesRowOrder(roles, nComp, reactantIndices) ;
            else
                remaining = setdiff(1:nComp, selectedIdx, 'stable') ;
                rowOrder = [selectedIdx, remaining] ;
            end

            app.Pred_C_exitTable.ColumnName = { ...
                'Component', 'Role', 'C_in', 'Seg. C_out', 'MM C_out', ...
                'CSTR C_out', 'PFR C_out', ...
                'X_CSTR', 'X_seg', 'X_MM', 'X_PFR'} ;
            app.Pred_C_exitTable.ColumnWidth = {88, 70, 68, 78, 78, 84, 84, 62, 62, 72, 72} ;
            app.Pred_C_exitTable.Data = summaryRows(rowOrder, :) ;
        end

        function updateTISSummaryTable(app, ...
                compLabels, roles, C0, ...
                C_tis, C_cstr, C_pfr, ...
                reactantIndices, X_tis, X_cstr, X_pfr, concDropdown)

            nComp = numel(compLabels) ;
            summaryRows = cell(nComp, 9) ;
            concMatrix = [C0(:), C_tis(:), C_cstr(:), C_pfr(:)] ;
            concDisplay = reshape(app.convertOutputConcentration(concMatrix(:)', concDropdown), size(concMatrix)) ;

            reactantPosMap = containers.Map('KeyType', 'double', 'ValueType', 'double') ;
            for k = 1:numel(reactantIndices)
                reactantPosMap(reactantIndices(k)) = k ;
            end

            rolePriority = zeros(1, nComp) ;
            for i = 1:nComp
                summaryRows{i, 1} = compLabels{i} ;
                summaryRows{i, 2} = roles{i} ;
                for j = 1:4
                    summaryRows{i, j + 2} = sprintf('%.4g', concDisplay(i, j)) ;
                end

                if isKey(reactantPosMap, i)
                    pos = reactantPosMap(i) ;
                    summaryRows{i, 7} = sprintf('%.4f', X_tis(pos)) ;
                    summaryRows{i, 8} = sprintf('%.4f', X_cstr(pos)) ;
                    summaryRows{i, 9} = sprintf('%.4f', X_pfr(pos)) ;
                else
                    summaryRows{i, 7} = '--' ;
                    summaryRows{i, 8} = '--' ;
                    summaryRows{i, 9} = '--' ;
                end

                rolePriority(i) = app.getSpeciesRolePriority(roles(i)) ;
            end

            functionalPriority = ones(1, nComp) * 2 ;
            functionalPriority(reactantIndices) = 1 ;
            [~, rowOrder] = sortrows([functionalPriority(:), rolePriority(:), (1:nComp)']) ;
            rowOrder = rowOrder(:)' ;

            app.TIS_C_exitTable.ColumnName = { ...
                'Component', 'Role', 'C_in', 'TIS C_out', 'CSTR C_out', ...
                'PFR C_out', 'X_TIS', 'X_CSTR', 'X_PFR'} ;
            app.TIS_C_exitTable.ColumnWidth = {86, 72, 68, 82, 84, 84, 64, 74, 74} ;
            app.TIS_C_exitTable.Data = summaryRows(rowOrder, :) ;
        end

        function updateDispSummaryTable(app, ...
                compLabels, roles, C0, ...
                C_disp, C_cstr, C_pfr, ...
                reactantIndices, X_disp, X_cstr, X_pfr, concDropdown)

            nComp = numel(compLabels) ;
            summaryRows = cell(nComp, 9) ;
            concMatrix = [C0(:), C_disp(:), C_cstr(:), C_pfr(:)] ;
            concDisplay = reshape(app.convertOutputConcentration(concMatrix(:)', concDropdown), size(concMatrix)) ;

            reactantPosMap = containers.Map('KeyType', 'double', 'ValueType', 'double') ;
            for k = 1:numel(reactantIndices)
                reactantPosMap(reactantIndices(k)) = k ;
            end

            rolePriority = zeros(1, nComp) ;
            for i = 1:nComp
                summaryRows{i, 1} = compLabels{i} ;
                summaryRows{i, 2} = roles{i} ;
                for j = 1:4
                    summaryRows{i, j + 2} = sprintf('%.4g', concDisplay(i, j)) ;
                end

                if isKey(reactantPosMap, i)
                    pos = reactantPosMap(i) ;
                    summaryRows{i, 7} = sprintf('%.4f', X_disp(pos)) ;
                    summaryRows{i, 8} = sprintf('%.4f', X_cstr(pos)) ;
                    summaryRows{i, 9} = sprintf('%.4f', X_pfr(pos)) ;
                else
                    summaryRows{i, 7} = '--' ;
                    summaryRows{i, 8} = '--' ;
                    summaryRows{i, 9} = '--' ;
                end

                rolePriority(i) = app.getSpeciesRolePriority(roles(i)) ;
            end

            functionalPriority = ones(1, nComp) * 2 ;
            functionalPriority(reactantIndices) = 1 ;
            [~, rowOrder] = sortrows([functionalPriority(:), rolePriority(:), (1:nComp)']) ;
            rowOrder = rowOrder(:)' ;

            app.Disp_C_exitTable.ColumnName = { ...
                'Component', 'Role', 'C_in', 'Disp C_out', 'CSTR C_out', ...
                'PFR C_out', 'X_Disp', 'X_CSTR', 'X_PFR'} ;
            app.Disp_C_exitTable.ColumnWidth = {86, 72, 68, 84, 84, 84, 68, 74, 74} ;
            app.Disp_C_exitTable.Data = summaryRows(rowOrder, :) ;
        end

        function ensureComponentSelectorItems(app, dropdown, nComp)
            if isempty(dropdown) || ~isvalid(dropdown)
                return
            end
            items = [{'All'}, app.getComponentLabels(nComp)] ;
            currentValue = dropdown.Value ;
            dropdown.Items = items ;
            if any(strcmp(items, currentValue))
                dropdown.Value = currentValue ;
            else
                dropdown.Value = 'All' ;
            end
        end

        function idx = getSelectedComponentIndices(app, dropdown, nComp)
            if isempty(dropdown) || ~isvalid(dropdown) || strcmp(dropdown.Value, 'All')
                idx = 1:nComp ;
                return
            end

            labels = app.getComponentLabels(nComp) ;
            idx = find(strcmp(labels, dropdown.Value), 1) ;
            if isempty(idx)
                idx = 1:nComp ;
                return
            end
        end

        function unitName = concentrationUnitName(~, dropdown)
            if isempty(dropdown) || ~isvalid(dropdown)
                unitName = 'mol/m^3' ;
            else
                unitName = dropdown.Value ;
            end
        end

        function setTooltip(~, tooltipText, varargin)
            for k = 1:numel(varargin)
                h = varargin{k} ;
                if ~isempty(h) && isvalid(h)
                    h.Tooltip = tooltipText ;
                end
            end
        end

        function text = buildTooltipFromColumns(~, introText, columnNames)
            if isempty(columnNames)
                text = introText ;
                return
            end
            text = sprintf('%s Columns: %s.', introText, strjoin(columnNames, ', ')) ;
        end

        function text = htmlStatusTauSigma(~, sourceText, tauValue, sigma2Value)
            text = sprintf('%s | &tau;=%.2f, &sigma;<sup>2</sup>=%.2f', ...
                sourceText, tauValue, sigma2Value) ;
        end

        function text = htmlStatusTauN(~, prefixText, tauValue, nValue)
            text = sprintf('%s&tau;=%.2f, N=%.2f', prefixText, tauValue, nValue) ;
        end

        function text = htmlStatusTauPe(~, prefixText, tauValue, peValue)
            text = sprintf('%s&tau;=%.2f, Pe=%.4g', prefixText, tauValue, peValue) ;
        end

        function text = buildFitSummaryText(~, result)
            if isfield(result, 'mode') && strcmp(result.mode, 'search')
                nOk = numel(result.searchResults) ;
                nSkipped = sum(strcmp({result.searchEntries.status}, 'Skipped')) ;
                text = sprintf([ ...
                    'Search completed. Best family: %s. ' ...
                    'Evaluated = %d. Omitted = %d. ' ...
                    'Best RMSE = %.6g. Best score = %.6g'], ...
                    result.searchBestFamily, nOk, nSkipped, result.rmse, result.score) ;
                return
            end
            text = sprintf([ ...
                '%s fitted. RMSE = %.6g. ' ...
                'Score = %.6g'], ...
                result.family, result.rmse, result.score) ;
        end

        function text = buildFitSummaryTextWithUnits(app, result, timeDropdown)
            rmseDisplay = app.convertOutputFromTime('timeInverse', result.rmse, timeDropdown) ;
            rmseUnit = app.timeInverseUnitName(timeDropdown) ;
            if isfield(result, 'mode') && strcmp(result.mode, 'search')
                nOk = numel(result.searchResults) ;
                nSkipped = sum(strcmp({result.searchEntries.status}, 'Skipped')) ;
                text = sprintf([ ...
                    'Search completed. Best family: %s. ' ...
                    'Evaluated = %d. Omitted = %d. ' ...
                    'Best RMSE = %.6g %s. Best score = %.6g'], ...
                    result.searchBestFamily, nOk, nSkipped, rmseDisplay, rmseUnit, result.score) ;
                return
            end
            text = sprintf([ ...
                '%s fitted. RMSE = %.6g %s. ' ...
                'Score = %.6g'], ...
                result.family, rmseDisplay, rmseUnit, result.score) ;
        end

        function [labelText, valueText] = DW_formatFitParameter(app, fieldName, fieldValue, timeDropdown, volumeDropdown)
            timeUnit = app.getControlValue(timeDropdown, 's') ;
            switch fieldName
                case {'tau', 'tau_nominal', 'tau_active', 'tau_total', 'tau_pfr', 'tau_cstr', 'tau_pfr_active', 'tau_cstr_active'}
                    labelText = sprintf('%s [%s]', fieldName, timeUnit) ;
                    valueDisplay = app.convertOutputFromTime('time', fieldValue, timeDropdown) ;
                    valueText = sprintf('%.6g', valueDisplay) ;
                case {'N', 'Pe', 'activeFraction', 'deadFraction', 'bypassFraction', 'pfrFraction', 'cstrFraction', 'pfrResidenceFraction', 'cstrResidenceFraction', 'splitToPFR', 'splitToCSTR'}
                    labelText = sprintf('%s [-]', fieldName) ;
                    valueText = sprintf('%.6g', fieldValue) ;
                case 'Bo'
                    labelText = 'Bo [-]' ;
                    valueText = sprintf('%.6g', fieldValue) ;
                case {'V_total', 'V_active', 'V_dead'}
                    labelText = sprintf('%s [%s]', fieldName, app.getControlValue(volumeDropdown, 'm^3')) ;
                    valueText = sprintf('%.6g', app.convertOutputScalar('Volume', fieldValue, volumeDropdown)) ;
                otherwise
                    labelText = fieldName ;
                    if isnumeric(fieldValue) && isscalar(fieldValue)
                        valueText = sprintf('%.6g', fieldValue) ;
                    else
                        valueText = char(string(fieldValue)) ;
                    end
            end
        end

        function labelText = DW_fitParameterHtmlLabel(app, fieldName, timeDropdown, volumeDropdown)
            timeUnitText = app.getControlValue(timeDropdown, 's') ;
            volumeUnitText = app.getControlValue(volumeDropdown, 'm^3') ;
            switch fieldName
                case 'tau'
                    labelText = sprintf('$\\tau$ [%s]:', timeUnitText) ;
                case 'tau_nominal'
                    labelText = sprintf('$\\tau_{\\mathrm{nominal}}$ [%s]:', timeUnitText) ;
                case 'tau_active'
                    labelText = sprintf('$\\tau_{\\mathrm{active}}$ [%s]:', timeUnitText) ;
                case 'tau_total'
                    labelText = sprintf('$\\tau_{\\mathrm{total}}$ [%s]:', timeUnitText) ;
                case 'tau_pfr'
                    labelText = sprintf('$\\tau_{\\mathrm{PFR}}$ [%s]:', timeUnitText) ;
                case 'tau_cstr'
                    labelText = sprintf('$\\tau_{\\mathrm{CSTR}}$ [%s]:', timeUnitText) ;
                case 'tau_pfr_active'
                    labelText = sprintf('$\\tau_{\\mathrm{PFR,active}}$ [%s]:', timeUnitText) ;
                case 'tau_cstr_active'
                    labelText = sprintf('$\\tau_{\\mathrm{CSTR,active}}$ [%s]:', timeUnitText) ;
                case 'N'
                    labelText = '$N$ [-]:' ;
                case 'Bo'
                    labelText = '$Bo$ [-]:' ;
                case 'Pe'
                    labelText = '$Pe$ [-]:' ;
                case 'splitToPFR'
                    labelText = '$\phi_{\mathrm{PFR}}$ [-]:' ;
                case 'splitToCSTR'
                    labelText = '$\phi_{\mathrm{CSTR}}$ [-]:' ;
                case 'bypassFraction'
                    labelText = '$\beta_{\mathrm{bypass}}$ [-]:' ;
                case 'deadFraction'
                    labelText = '$\phi_{\mathrm{dead}}$ [-]:' ;
                case 'V_total'
                    labelText = sprintf('$V_{\\mathrm{total}}$ [%s]:', volumeUnitText) ;
                case 'V_active'
                    labelText = sprintf('$V_{\\mathrm{active}}$ [%s]:', volumeUnitText) ;
                case 'V_dead'
                    labelText = sprintf('$V_{\\mathrm{dead}}$ [%s]:', volumeUnitText) ;
                case 'deadVolumeNote'
                    labelText = 'Note:' ;
                otherwise
                    labelText = sprintf('%s:', fieldName) ;
            end
        end

        function tooltipText = DW_fitParameterTooltip(~, fieldName)
            switch fieldName
                case 'tau'
                    tooltipText = 'Mean residence time of the fitted equivalent RTD.' ;
                case 'tau_nominal'
                    tooltipText = 'Nominal residence time reported by the fitted family before any dead-volume interpretation.' ;
                case 'tau_active'
                    tooltipText = 'Residence time associated with the active volume that effectively exchanges tracer.' ;
                case 'tau_total'
                    tooltipText = 'Total space time V/Q. It can come from Total volume and Qv, or from Ref. tau_total as fallback.' ;
                case 'tau_pfr'
                    tooltipText = 'Residence-time contribution assigned to the plug-flow segment of the fitted family.' ;
                case 'tau_cstr'
                    tooltipText = 'Residence-time contribution assigned to the perfectly mixed segment of the fitted family.' ;
                case 'tau_pfr_active'
                    tooltipText = 'Active residence time of the PFR branch or PFR segment inside the fitted family.' ;
                case 'tau_cstr_active'
                    tooltipText = 'Active residence time of the CSTR branch or CSTR segment inside the fitted family.' ;
                case 'N'
                    tooltipText = 'Equivalent number of tanks in series. Larger N means behavior closer to plug flow.' ;
                case 'Bo'
                    tooltipText = 'Axial dispersion number. Smaller Bo indicates weaker axial mixing and behavior closer to plug flow.' ;
                case 'Pe'
                    tooltipText = 'Peclet number, equal to 1/Bo in this model. Larger Pe means weaker axial dispersion.' ;
                case 'splitToPFR'
                    tooltipText = 'Fraction of the inlet flow that is routed to the PFR branch in the parallel PFR + CSTR family.' ;
                case 'splitToCSTR'
                    tooltipText = 'Fraction of the inlet flow that is routed to the CSTR branch in the parallel PFR + CSTR family.' ;
                case 'bypassFraction'
                    tooltipText = 'Fraction of the feed that bypasses the active reactor volume and leaves almost immediately.' ;
                case 'deadFraction'
                    tooltipText = 'Fraction of total reactor volume that is interpreted as dead or hydraulically inactive volume.' ;
                case 'V_total'
                    tooltipText = 'Total reactor volume provided by the user for dead-volume interpretation.' ;
                case 'V_active'
                    tooltipText = 'Effective active volume computed from the fitted active residence time and the total-volume interpretation.' ;
                case 'V_dead'
                    tooltipText = 'Estimated dead volume, computed as the inactive fraction of the total reactor volume.' ;
                case 'deadVolumeNote'
                    tooltipText = 'Consistency note for the dead-volume interpretation, shown when total and active times are incompatible.' ;
                otherwise
                    tooltipText = sprintf('Fitted value of %s for the selected hydrodynamic family.', fieldName) ;
            end
        end

        function text = DW_formatFitDisplayNumber(~, value)
            if isempty(value) || any(~isfinite(value))
                text = '-' ;
            else
                text = sprintf('%.6g', value) ;
            end
        end

        function DW_createFitResultFields(app)
            panel = app.DesignUI.Fit.ParameterFieldsPanel ;
            fieldGrid = uigridlayout(panel, [1 3], ...
                'RowHeight', {'1x'}, ...
                'ColumnWidth', {'1x', '1x', 220}, ...
                'Padding', [0 0 0 0], ...
                'RowSpacing', 0, ...
                'ColumnSpacing', 10) ;
            app.DesignUI.Fit.ParameterFieldsGrid = fieldGrid ;

            tauPanel = uipanel(fieldGrid, 'Title', 'Residence Times', 'FontWeight', 'bold') ;
            tauPanel.Layout.Row = 1 ;
            tauPanel.Layout.Column = 1 ;
            app.DesignUI.Fit.TauPanel = tauPanel ;
            tauGrid = uigridlayout(tauPanel, [7 2], ...
                'RowHeight', repmat({'fit'}, 1, 7), ...
                'ColumnWidth', {160, '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 4, ...
                'ColumnSpacing', 8) ;
            app.DesignUI.Fit.TauFieldLabels = gobjects(7, 1) ;
            app.DesignUI.Fit.TauFieldValues = gobjects(7, 1) ;
            for i = 1:7
                nameLabel = uilabel(tauGrid, 'Text', '', 'FontWeight', 'bold', 'Visible', 'off', ...
                    'Interpreter', 'latex') ;
                nameLabel.Layout.Row = i ;
                nameLabel.Layout.Column = 1 ;
                valueLabel = uilabel(tauGrid, 'Text', '', 'Visible', 'off', 'WordWrap', 'on') ;
                valueLabel.Layout.Row = i ;
                valueLabel.Layout.Column = 2 ;
                app.DesignUI.Fit.TauFieldLabels(i) = nameLabel ;
                app.DesignUI.Fit.TauFieldValues(i) = valueLabel ;
            end

            deadPanel = uipanel(fieldGrid, 'Title', 'Dead Volume', 'FontWeight', 'bold') ;
            deadPanel.Layout.Row = 1 ;
            deadPanel.Layout.Column = 2 ;
            app.DesignUI.Fit.DeadPanel = deadPanel ;
            deadGrid = uigridlayout(deadPanel, [5 2], ...
                'RowHeight', repmat({'fit'}, 1, 5), ...
                'ColumnWidth', {145, '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 4, ...
                'ColumnSpacing', 8) ;
            app.DesignUI.Fit.DeadFieldLabels = gobjects(5, 1) ;
            app.DesignUI.Fit.DeadFieldValues = gobjects(5, 1) ;
            for i = 1:5
                nameLabel = uilabel(deadGrid, 'Text', '', 'FontWeight', 'bold', 'Visible', 'off', ...
                    'Interpreter', 'latex') ;
                nameLabel.Layout.Row = i ;
                nameLabel.Layout.Column = 1 ;
                valueLabel = uilabel(deadGrid, 'Text', '', 'Visible', 'off', 'WordWrap', 'on') ;
                valueLabel.Layout.Row = i ;
                valueLabel.Layout.Column = 2 ;
                app.DesignUI.Fit.DeadFieldLabels(i) = nameLabel ;
                app.DesignUI.Fit.DeadFieldValues(i) = valueLabel ;
            end

            miscPanel = uipanel(fieldGrid, 'Title', 'Family Parameters', 'FontWeight', 'bold') ;
            miscPanel.Layout.Row = 1 ;
            miscPanel.Layout.Column = 3 ;
            app.DesignUI.Fit.MiscPanel = miscPanel ;
            miscGrid = uigridlayout(miscPanel, [8 2], ...
                'RowHeight', repmat({'fit'}, 1, 8), ...
                'ColumnWidth', {150, '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 4, ...
                'ColumnSpacing', 8) ;
            app.DesignUI.Fit.MiscFieldLabels = gobjects(8, 1) ;
            app.DesignUI.Fit.MiscFieldValues = gobjects(8, 1) ;
            for i = 1:8
                nameLabel = uilabel(miscGrid, 'Text', '', 'FontWeight', 'bold', 'Visible', 'off', ...
                    'Interpreter', 'latex') ;
                nameLabel.Layout.Row = i ;
                nameLabel.Layout.Column = 1 ;
                valueLabel = uilabel(miscGrid, 'Text', '', 'Visible', 'off', 'WordWrap', 'on') ;
                valueLabel.Layout.Row = i ;
                valueLabel.Layout.Column = 2 ;
                app.DesignUI.Fit.MiscFieldLabels(i) = nameLabel ;
                app.DesignUI.Fit.MiscFieldValues(i) = valueLabel ;
            end
        end

        function entries = DW_collectFitParameterEntries(app, result, timeDropdown, volumeDropdown)
            params = app.getStructField(result, 'parameters', struct()) ;
            if isempty(params)
                entries = struct('fieldName', {}, 'label', {}, 'value', {}) ;
                return
            end

            hiddenFields = {'pfrResidenceFraction', 'cstrResidenceFraction', 'activeFraction'} ;
            orderedFields = {'tau', 'tau_active', 'tau_total', 'tau_pfr', 'tau_cstr', ...
                'tau_pfr_active', 'tau_cstr_active', 'N', 'Bo', 'Pe', 'splitToPFR', ...
                'splitToCSTR', 'bypassFraction', 'deadFraction', 'V_total', 'V_active', ...
                'V_dead', 'deadVolumeNote'} ;
            availableFields = fieldnames(params) ;
            orderedVisible = orderedFields(ismember(orderedFields, availableFields)) ;
            remainingFields = setdiff(availableFields(:)', [orderedFields, hiddenFields], 'stable') ;
            fields = [orderedVisible, remainingFields] ;
            fields = fields(~ismember(fields, hiddenFields)) ;

            entries = repmat(struct('fieldName', '', 'label', '', 'value', ''), 1, numel(fields)) ;
            for i = 1:numel(fields)
                fieldName = fields{i} ;
                fieldValue = params.(fieldName) ;
                [labelText, valueText] = app.DW_formatFitParameter(fieldName, fieldValue, timeDropdown, volumeDropdown) ;
                entries(i).fieldName = fieldName ;
                entries(i).label = labelText ;
                entries(i).value = valueText ;
            end
        end

        function tableData = DW_buildFitParameterTableData(app, result, timeDropdown, volumeDropdown)
            entries = app.DW_collectFitParameterEntries(result, timeDropdown, volumeDropdown) ;
            tableData = cell(numel(entries), 2) ;
            for i = 1:numel(entries)
                tableData{i, 1} = entries(i).label ;
                tableData{i, 2} = entries(i).value ;
            end
        end

        function DW_clearFitResultFields(app)
            if ~isfield(app.DesignUI.Fit, 'TauFieldLabels')
                return
            end
            for i = 1:numel(app.DesignUI.Fit.TauFieldLabels)
                if isvalid(app.DesignUI.Fit.TauFieldLabels(i))
                    app.DesignUI.Fit.TauFieldLabels(i).Text = '' ;
                    app.DesignUI.Fit.TauFieldLabels(i).Visible = 'off' ;
                    app.DesignUI.Fit.TauFieldLabels(i).Tooltip = '' ;
                end
                if isvalid(app.DesignUI.Fit.TauFieldValues(i))
                    app.DesignUI.Fit.TauFieldValues(i).Text = '' ;
                    app.DesignUI.Fit.TauFieldValues(i).Visible = 'off' ;
                    app.DesignUI.Fit.TauFieldValues(i).Tooltip = '' ;
                end
            end
            for i = 1:numel(app.DesignUI.Fit.DeadFieldLabels)
                if isvalid(app.DesignUI.Fit.DeadFieldLabels(i))
                    app.DesignUI.Fit.DeadFieldLabels(i).Text = '' ;
                    app.DesignUI.Fit.DeadFieldLabels(i).Visible = 'off' ;
                    app.DesignUI.Fit.DeadFieldLabels(i).Tooltip = '' ;
                end
                if isvalid(app.DesignUI.Fit.DeadFieldValues(i))
                    app.DesignUI.Fit.DeadFieldValues(i).Text = '' ;
                    app.DesignUI.Fit.DeadFieldValues(i).Visible = 'off' ;
                    app.DesignUI.Fit.DeadFieldValues(i).Tooltip = '' ;
                end
            end
            for i = 1:numel(app.DesignUI.Fit.MiscFieldLabels)
                if isvalid(app.DesignUI.Fit.MiscFieldLabels(i))
                    app.DesignUI.Fit.MiscFieldLabels(i).Text = '' ;
                    app.DesignUI.Fit.MiscFieldLabels(i).Visible = 'off' ;
                    app.DesignUI.Fit.MiscFieldLabels(i).Tooltip = '' ;
                end
                if isvalid(app.DesignUI.Fit.MiscFieldValues(i))
                    app.DesignUI.Fit.MiscFieldValues(i).Text = '' ;
                    app.DesignUI.Fit.MiscFieldValues(i).Visible = 'off' ;
                    app.DesignUI.Fit.MiscFieldValues(i).Tooltip = '' ;
                end
            end
            if isfield(app.DesignUI.Fit, 'TauPanel') && isvalid(app.DesignUI.Fit.TauPanel)
                app.DesignUI.Fit.TauPanel.Visible = 'on' ;
            end
            if isfield(app.DesignUI.Fit, 'DeadPanel') && isvalid(app.DesignUI.Fit.DeadPanel)
                app.DesignUI.Fit.DeadPanel.Visible = 'off' ;
            end
            if isfield(app.DesignUI.Fit, 'MiscPanel') && isvalid(app.DesignUI.Fit.MiscPanel)
                app.DesignUI.Fit.MiscPanel.Visible = 'off' ;
            end
            if isfield(app.DesignUI.Fit, 'ParameterFieldsGrid') && isvalid(app.DesignUI.Fit.ParameterFieldsGrid)
                app.DesignUI.Fit.ParameterFieldsGrid.ColumnWidth = {'1x', 0, 0} ;
            end
        end

        function DW_populateFitResultFields(app, result, timeDropdown, volumeDropdown)
            entries = app.DW_collectFitParameterEntries(result, timeDropdown, volumeDropdown) ;
            tauFields = {'tau', 'tau_nominal', 'tau_active', 'tau_total', 'tau_pfr', 'tau_cstr', 'tau_pfr_active', 'tau_cstr_active'} ;
            deadFields = {'deadFraction', 'V_total', 'V_active', 'V_dead', 'deadVolumeNote'} ;
            tauEntries = entries(ismember({entries.fieldName}, tauFields)) ;
            deadEntries = entries(ismember({entries.fieldName}, deadFields)) ;
            miscEntries = entries(~ismember({entries.fieldName}, [tauFields, deadFields])) ;

            app.DW_clearFitResultFields() ;
            maxRows = min(numel(tauEntries), numel(app.DesignUI.Fit.TauFieldLabels)) ;
            for i = 1:maxRows
                app.DesignUI.Fit.TauFieldLabels(i).Text = app.DW_fitParameterHtmlLabel(tauEntries(i).fieldName, timeDropdown, volumeDropdown) ;
                app.DesignUI.Fit.TauFieldLabels(i).Visible = 'on' ;
                tooltipText = app.DW_fitParameterTooltip(tauEntries(i).fieldName) ;
                app.DesignUI.Fit.TauFieldLabels(i).Tooltip = tooltipText ;
                app.DesignUI.Fit.TauFieldValues(i).Text = tauEntries(i).value ;
                app.DesignUI.Fit.TauFieldValues(i).Visible = 'on' ;
                app.DesignUI.Fit.TauFieldValues(i).Tooltip = tooltipText ;
            end
            if isfield(app.DesignUI.Fit, 'TauPanel') && isvalid(app.DesignUI.Fit.TauPanel)
                app.DesignUI.Fit.TauPanel.Visible = app.ternary(~isempty(tauEntries), 'on', 'off') ;
            end

            maxRows = min(numel(deadEntries), numel(app.DesignUI.Fit.DeadFieldLabels)) ;
            for i = 1:maxRows
                app.DesignUI.Fit.DeadFieldLabels(i).Text = app.DW_fitParameterHtmlLabel(deadEntries(i).fieldName, timeDropdown, volumeDropdown) ;
                app.DesignUI.Fit.DeadFieldLabels(i).Visible = 'on' ;
                tooltipText = app.DW_fitParameterTooltip(deadEntries(i).fieldName) ;
                app.DesignUI.Fit.DeadFieldLabels(i).Tooltip = tooltipText ;
                app.DesignUI.Fit.DeadFieldValues(i).Text = deadEntries(i).value ;
                app.DesignUI.Fit.DeadFieldValues(i).Visible = 'on' ;
                app.DesignUI.Fit.DeadFieldValues(i).Tooltip = tooltipText ;
            end
            if isfield(app.DesignUI.Fit, 'DeadPanel') && isvalid(app.DesignUI.Fit.DeadPanel)
                app.DesignUI.Fit.DeadPanel.Visible = app.ternary(~isempty(deadEntries), 'on', 'off') ;
            end

            maxRows = min(numel(miscEntries), numel(app.DesignUI.Fit.MiscFieldLabels)) ;
            for i = 1:maxRows
                app.DesignUI.Fit.MiscFieldLabels(i).Text = app.DW_fitParameterHtmlLabel(miscEntries(i).fieldName, timeDropdown, volumeDropdown) ;
                app.DesignUI.Fit.MiscFieldLabels(i).Visible = 'on' ;
                tooltipText = app.DW_fitParameterTooltip(miscEntries(i).fieldName) ;
                app.DesignUI.Fit.MiscFieldLabels(i).Tooltip = tooltipText ;
                app.DesignUI.Fit.MiscFieldValues(i).Text = miscEntries(i).value ;
                app.DesignUI.Fit.MiscFieldValues(i).Visible = 'on' ;
                app.DesignUI.Fit.MiscFieldValues(i).Tooltip = tooltipText ;
            end
            if isfield(app.DesignUI.Fit, 'MiscPanel') && isvalid(app.DesignUI.Fit.MiscPanel)
                app.DesignUI.Fit.MiscPanel.Visible = app.ternary(~isempty(miscEntries), 'on', 'off') ;
            end
            if isfield(app.DesignUI.Fit, 'ParameterFieldsGrid') && isvalid(app.DesignUI.Fit.ParameterFieldsGrid)
                app.DesignUI.Fit.ParameterFieldsGrid.ColumnWidth = { ...
                    app.ternary(~isempty(tauEntries), '1x', 0), ...
                    app.ternary(~isempty(deadEntries), '1x', 0), ...
                    app.ternary(~isempty(miscEntries), 220, 0)} ;
            end
        end

        function DW_showFitResultPresentation(app, modeName)
            showSearchTable = strcmp(modeName, 'search') ;
            if isfield(app.DesignUI.Fit, 'ParameterTable') && isvalid(app.DesignUI.Fit.ParameterTable)
                app.DesignUI.Fit.ParameterTable.Visible = app.ternary(showSearchTable, 'on', 'off') ;
            end
            if isfield(app.DesignUI.Fit, 'ParameterFieldsPanel') && isvalid(app.DesignUI.Fit.ParameterFieldsPanel)
                app.DesignUI.Fit.ParameterFieldsPanel.Visible = app.ternary(showSearchTable, 'off', 'on') ;
            end
        end

        function tableData = DW_buildFitSearchSummaryTable(app, result, timeDropdown)
            entries = app.getStructField(result, 'searchEntries', struct([])) ;
            tableData = cell(numel(entries), 3) ;
            for i = 1:numel(entries)
                tableData{i, 1} = entries(i).displayName ;
                rmseDisplay = app.convertOutputFromTime('timeInverse', entries(i).rmse, timeDropdown) ;
                tableData{i, 2} = app.DW_formatFitDisplayNumber(rmseDisplay) ;
                tableData{i, 3} = app.DW_formatFitDisplayNumber(entries(i).score) ;
            end
        end

        function names = DW_fitSearchColumnNames(app, timeDropdown)
            names = {'Family', sprintf('RMSE [%s]', app.timeInverseUnitName(timeDropdown)), 'Score [-]'} ;
        end

        function DW_applyFitAxesLabels(app, titleText)
            timeDD = app.getDisplayControl('DesignFit', 'time') ;
            title(app.DesignUI.Fit.CompareAxes, titleText) ;
            xlabel(app.DesignUI.Fit.CompareAxes, app.axisLabelWithUnit('t', timeDD)) ;
            ylabel(app.DesignUI.Fit.CompareAxes, app.axisLabelWithUnitName('E(t)', app.timeInverseUnitName(timeDD))) ;
        end

        function tableData = DW_buildReactiveSummaryTable(app, result)
            metrics = app.getStructField(result, 'metrics', struct()) ;
            tableData = { ...
                'Ideal CSTR', app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'cstr', struct()), 'conversion', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'cstr', struct()), 'selectivity', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'cstr', struct()), 'yield', NaN)) ; ...
                'Segregation', app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'segregation', struct()), 'conversion', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'segregation', struct()), 'selectivity', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'segregation', struct()), 'yield', NaN)) ; ...
                'Max Mixedness', app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'maxMixedness', struct()), 'conversion', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'maxMixedness', struct()), 'selectivity', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'maxMixedness', struct()), 'yield', NaN)) ; ...
                'Ideal PFR', app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'pfr', struct()), 'conversion', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'pfr', struct()), 'selectivity', NaN)), ...
                app.DW_formatFitDisplayNumber(app.getStructField(app.getStructField(metrics, 'pfr', struct()), 'yield', NaN))} ;
        end

        function tableData = DW_buildReactiveCoutTable(app, result, RS, C0, concDropdown)
            if isempty(RS) || isempty(C0)
                tableData = app.getStructField(result, 'coutTable', cell(0, 6)) ;
                return
            end

            nComp = numel(C0) ;
            rowLabels = cell(1, nComp) ;
            for i = 1:nComp
                rowLabels{i} = app.getComponentLabel(RS, i) ;
            end
            seriesData = [C0(:), result.segregation.C_exit(:), result.maxMixedness.C_exit(:), ...
                result.cstr.C_out(:), result.pfr.C_out(:)] ;
            concDisplay = reshape(app.convertOutputConcentration(seriesData(:)', concDropdown), size(seriesData)) ;
            tableData = cell(nComp, 6) ;
            for i = 1:nComp
                tableData{i, 1} = rowLabels{i} ;
                for j = 1:5
                    tableData{i, j + 1} = app.DW_formatFitDisplayNumber(concDisplay(i, j)) ;
                end
            end
        end

        function [metricName, titleText, yLabel] = DW_getReactiveMetricSpec(app)
            metricDropdown = app.getDisplayControl('DesignReactive', 'metric') ;
            metricName = app.getControlValue(metricDropdown, 'Conversion') ;
            switch char(string(metricName))
                case 'Selectivity'
                    titleText = 'Selectivity comparison' ;
                    yLabel = 'Selectivity (-)' ;
                case 'Yield'
                    titleText = 'Yield comparison' ;
                    yLabel = 'Yield (-)' ;
                otherwise
                    metricName = 'Conversion' ;
                    titleText = 'Conversion comparison' ;
                    yLabel = 'Conversion X (-)' ;
            end
        end

        function values = DW_getReactiveMetricValues(app, result, metricName)
            metrics = app.getStructField(result, 'metrics', struct()) ;
            switch char(string(metricName))
                case 'Selectivity'
                    fieldName = 'selectivity' ;
                case 'Yield'
                    fieldName = 'yield' ;
                otherwise
                    fieldName = 'conversion' ;
            end
            values = [ ...
                app.getStructField(app.getStructField(metrics, 'cstr', struct()), fieldName, NaN), ...
                app.getStructField(app.getStructField(metrics, 'segregation', struct()), fieldName, NaN), ...
                app.getStructField(app.getStructField(metrics, 'maxMixedness', struct()), fieldName, NaN), ...
                app.getStructField(app.getStructField(metrics, 'pfr', struct()), fieldName, NaN)] ;
        end

        function DW_refreshReactivePlot(app, result)
            cla(app.DesignUI.Reactive.Axes) ;
            [metricName, titleText, yLabel] = app.DW_getReactiveMetricSpec() ;
            values = app.DW_getReactiveMetricValues(result, metricName) ;
            finiteValues = values(isfinite(values)) ;
            if isempty(finiteValues)
                text(app.DesignUI.Reactive.Axes, 0.5, 0.5, 'No reactive metrics available', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                title(app.DesignUI.Reactive.Axes, titleText) ;
                ylabel(app.DesignUI.Reactive.Axes, yLabel) ;
                grid(app.DesignUI.Reactive.Axes, 'on') ;
                return
            end

            [~, colors] = app.getPredictionModelLegendSpec() ;
            b = bar(app.DesignUI.Reactive.Axes, 1:numel(values), values, 'FaceColor', 'flat') ;
            b.CData = colors(1:numel(values), :) ;
            app.DesignUI.Reactive.Axes.XTick = 1:numel(values) ;
            app.DesignUI.Reactive.Axes.XTickLabel = {'CSTR', 'Seg', 'MM', 'PFR'} ;
            app.setPredictionAnnotatedYLimits(app.DesignUI.Reactive.Axes, values(:), 1) ;
            app.annotatePredictionBars(app.DesignUI.Reactive.Axes, b, values(:), '%.4f') ;
            title(app.DesignUI.Reactive.Axes, titleText) ;
            ylabel(app.DesignUI.Reactive.Axes, yLabel) ;
            grid(app.DesignUI.Reactive.Axes, 'on') ;
        end

        function names = DW_buildReactiveCoutColumnNames(app, concDropdown)
            unitName = app.concentrationUnitName(concDropdown) ;
            names = {'Component', ...
                sprintf('C_in [%s]', unitName), ...
                sprintf('Seg [%s]', unitName), ...
                sprintf('MM [%s]', unitName), ...
                sprintf('CSTR [%s]', unitName), ...
                sprintf('PFR [%s]', unitName)} ;
        end

        function tableData = DW_buildOptimizationComparisonTable(app, result)
            rows = app.getStructField(result, 'comparisonRows', struct([])) ;
            tableData = cell(numel(rows), 3) ;
            concDropdown = app.getDisplayControl('DesignOptimization', 'concentration') ;
            for i = 1:numel(rows)
                tableData{i, 1} = app.getStructField(rows(i), 'label', '-') ;
                tableData{i, 2} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'baseValue', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 3} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'optimumValue', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
            end
        end

        function tableData = DW_buildOptimizationModelTable(app, result)
            rows = app.getStructField(result, 'modelComparisonRows', struct([])) ;
            concDropdown = app.getDisplayControl('DesignOptimization', 'concentration') ;
            tableData = cell(numel(rows), 9) ;
            for i = 1:numel(rows)
                tableData{i, 1} = app.getStructField(rows(i), 'label', '-') ;
                tableData{i, 2} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'cstrBase', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 3} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'cstrOptimum', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 4} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'segBase', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 5} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'segOptimum', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 6} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'mmBase', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 7} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'mmOptimum', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 8} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'pfrBase', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
                tableData{i, 9} = app.DW_formatOptimizationDisplayValue( ...
                    app.getStructField(rows(i), 'pfrOptimum', NaN), ...
                    app.getStructField(rows(i), 'valueType', 'dimensionless'), ...
                    concDropdown) ;
            end
        end

        function text = DW_formatOptimizationDisplayValue(app, valueSI, valueType, concDropdown)
            switch char(string(valueType))
                case 'concentration'
                    valueDisplay = app.convertOutputScalar('Concentration', valueSI, concDropdown) ;
                otherwise
                    valueDisplay = valueSI ;
            end
            text = app.DW_formatFitDisplayNumber(valueDisplay) ;
        end

        function columnNames = DW_buildOptimizationModelColumnNames(~)
            columnNames = {'Variable', ...
                'CSTR Base', 'CSTR Optimum', ...
                'Seg Base', 'Seg Optimum', ...
                'MM Base', 'MM Optimum', ...
                'PFR Base', 'PFR Optimum'} ;
        end

        function noticeText = DW_buildOptimizationInputUnitNotice(app)
            feedStream = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
            if isempty(feedStream) || ~isa(feedStream, 'Stream')
                noticeText = ['Input units are inherited from the Feed Stream. ' ...
                    'Load a Feed Stream to define the C_in,i units used in optimization.'] ;
                return
            end
            concUnit = app.DW_getOptimizationInputConcentrationUnit() ;
            noticeText = sprintf([ ...
                'Input concentrations inherited from Feed Stream: C_in,i [%s]. ' ...
                'Change them in defineStreamApp if needed.'], concUnit) ;
        end

        function columnNames = DW_buildOptimizationDecisionColumnNames(app)
            concUnit = app.DW_getOptimizationInputConcentrationUnit() ;
            columnNames = {'Use', 'Variable', ...
                sprintf('Lower [%s]', concUnit), ...
                sprintf('Upper [%s]', concUnit)} ;
        end

        function concUnit = DW_getOptimizationInputConcentrationUnit(app)
            concUnit = 'mol/m^3' ;
            feedStream = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
            if isempty(feedStream) || ~isa(feedStream, 'Stream')
                return
            end
            try
                if ~isempty(feedStream.concentration_Units)
                    concUnit = char(string(feedStream.concentration_Units)) ;
                end
            catch
            end
        end

        function valueSI = DW_convertOptimizationInputToSI(~, valueDisplay, def, concUnit)
            unitCategory = '' ;
            if isstruct(def) && isfield(def, 'unitCategory')
                unitCategory = char(string(def.unitCategory)) ;
            end
            switch unitCategory
                case 'Concentration'
                    valueSI = UnitConverterHelper.convertToSI('Concentration', valueDisplay, concUnit) ;
                otherwise
                    valueSI = valueDisplay ;
            end
        end

        function valueDisplay = DW_convertOptimizationInputFromSI(~, valueSI, def, concUnit)
            unitCategory = '' ;
            if isstruct(def) && isfield(def, 'unitCategory')
                unitCategory = char(string(def.unitCategory)) ;
            end
            switch unitCategory
                case 'Concentration'
                    valueDisplay = UnitConverterHelper.convertFromSI('Concentration', valueSI, concUnit) ;
                otherwise
                    valueDisplay = valueSI ;
            end
        end

        function updateConcentrationHeader(app, labelHandle, concDropdown)
            if isempty(labelHandle) || ~isvalid(labelHandle)
                return
            end
            labelHandle.Text = sprintf('Outlet Conc. at Exit [%s]:', ...
                app.concentrationUnitName(concDropdown)) ;
        end

        function updateConcentrationTable(app, tableHandle, seriesData, seriesNames, concDropdown)
            nComp = size(seriesData, 1) ;
            compLabels = app.getComponentLabels(nComp) ;
            app.updateNamedConcentrationTable(tableHandle, compLabels, seriesData, ...
                seriesNames, concDropdown) ;
        end

        function updateNamedConcentrationTable(app, tableHandle, rowLabels, seriesData, seriesNames, concDropdown)
            concDisplay = reshape(app.convertOutputConcentration(seriesData(:)', concDropdown), size(seriesData)) ;

            tableData = cell(numel(rowLabels), 1 + size(concDisplay, 2)) ;
            for i = 1:numel(rowLabels)
                tableData{i, 1} = rowLabels{i} ;
                for j = 1:size(concDisplay, 2)
                    tableData{i, j + 1} = sprintf('%.4g', concDisplay(i, j)) ;
                end
            end

            tableHandle.ColumnName = [{'Comp.'}, seriesNames] ;
            tableHandle.Data = tableData ;
        end

        function htmlText = unitToHtml(~, unitText)
            htmlText = strrep(unitText, '^2', '<sup>2</sup>') ;
            htmlText = strrep(htmlText, '^3', '<sup>3</sup>') ;
        end

        %% ============== ABOUT DIALOG (T7) ==============

        function showAbout(~) 
            fig = uifigure('Name', 'About', ...
                'Position', [400 300 420 260], 'Resize', 'off') ;
            g = uigridlayout(fig, [7 1]) ;
            g.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'} ;
            g.Padding = [20 20 20 20] ;
            g.RowSpacing = 8 ;

            uilabel(g, 'Text', 'Non-Ideal Reactor Analysis', ...
                'FontSize', 18, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center') ;
            uilabel(g, 'Text', 'Version 2.1 - July 2026', ...
                'HorizontalAlignment', 'center') ;
            uilabel(g, 'Text', 'Javier Berenguer Sabater', ...
                'HorizontalAlignment', 'center', 'FontWeight', 'bold') ;
            uilabel(g, 'Text', 'Based on ReactorApp by Isabella Fons', ...
                'HorizontalAlignment', 'center') ;
            uilabel(g, 'Text', 'TFG - Chemical Engineering', ...
                'HorizontalAlignment', 'center') ;
            uilabel(g, 'Text', sprintf('MATLAB %s', version), ...
                'HorizontalAlignment', 'center', ...
                'FontColor', [0.5 0.5 0.5]) ;
            uibutton(g, 'Text', 'Close', ...
                'ButtonPushedFcn', @(~,~) delete(fig)) ;
        end

        %% ============== STATUS BAR (T8) ==============

        function updateStatus(app, msg)
            app.StatusBar.Text = ['  ' msg] ;
            drawnow limitrate ;
        end

        %% ============== TAB 1: RTD ANALYSIS ==============
        function createRTDTab(app)

            app.RTDTab = uitab(app.TabGroup, 'Title', 'RTD Analysis') ;

            % Main grid: left panel (controls) + right panel (plots)
            mainGrid = uigridlayout(app.RTDTab, [1 2]) ;
            mainGrid.ColumnWidth = {350, '1x'} ;

            % ---- LEFT PANEL ----
            leftPanel = uipanel(mainGrid, 'Title', 'RTD Configuration') ;
            leftGrid = uigridlayout(leftPanel, [24 2]) ;
            leftGrid.RowHeight = repmat({28}, 1, 24) ;
            leftGrid.ColumnWidth = {'1x', '1x'} ;
            leftGrid.Padding = [10 10 10 10] ;
            leftGrid.RowSpacing = 5 ;

            % Row 1: RTD Source dropdown
            lbl = uilabel(leftGrid, 'Text', 'RTD Source:', ...
                'FontWeight', 'bold') ;
            lbl.Layout.Row = 1 ; lbl.Layout.Column = 1 ;
            app.RTD_SourceDropdown = uidropdown(leftGrid, ...
                'Items', {'Ideal CSTR', 'Ideal PFR', 'Tanks-in-Series', ...
                          'Dispersion (open)', 'Dispersion (closed)', ...
                          'Laminar Flow', ...
                          'Experimental Pulse', 'Experimental Step', ...
                          'C(t) Equation', 'Tabular Input'}, ...
                'Value', 'Ideal CSTR', ...
                'ValueChangedFcn', @(~,~) app.RTD_sourceChanged()) ;
            app.RTD_SourceDropdown.Layout.Row = 1 ;
            app.RTD_SourceDropdown.Layout.Column = 2 ;
            app.setTooltip('Choose how the RTD will be generated or imported.', lbl, app.RTD_SourceDropdown) ;

            % Row 2: Tau field
            lbl = uilabel(leftGrid, 'Text', '$\tau$:', 'Interpreter', 'latex') ;
            lbl.Layout.Row = 2 ; lbl.Layout.Column = 1 ;
            [app.RTD_TauField, ~] = app.createNumericWithConv( ...
                leftGrid, 2, 2, 10, 'Time', 'Limits', [0.001 Inf]) ;
            app.setTooltip('Mean residence time used by the selected RTD model.', lbl, app.RTD_TauField) ;

            % Row 3: Qv (volumetric flow rate) — always visible
            app.RTD_QvLabel = uilabel(leftGrid, 'Text', '$Q_v$:', 'Interpreter', 'latex') ;
            app.RTD_QvLabel.Layout.Row = 3 ; app.RTD_QvLabel.Layout.Column = 1 ;
            [app.RTD_QvField, ~] = app.createNumericWithConv( ...
                leftGrid, 3, 2, 0.001, 'VolumetricFlow', 'Limits', [1e-12 Inf]) ;
            app.setTooltip('Volumetric flow rate used to infer effective reactor volume from the RTD.', app.RTD_QvLabel, app.RTD_QvField) ;

            % Row 4: N field (for Tanks-in-Series) — shares row with Bo
            app.RTD_NLabel = uilabel(leftGrid, 'Text', '$N$ [tanks]:', 'Interpreter', 'latex') ;
            app.RTD_NLabel.Layout.Row = 4 ; app.RTD_NLabel.Layout.Column = 1 ;
            app.RTD_NField = uieditfield(leftGrid, 'numeric', ...
                'Value', 3, 'Limits', [0.1 Inf]) ;
            app.RTD_NField.Layout.Row = 4 ; app.RTD_NField.Layout.Column = 2 ;
            app.setTooltip('Equivalent number of stirred tanks for the tanks-in-series RTD model.', app.RTD_NLabel, app.RTD_NField) ;
            app.RTD_NLabel.Visible = 'off' ;
            app.RTD_NField.Visible = 'off' ;

            % Row 4: Bo field (for Dispersion) — overlaps with N (only one visible)
            app.RTD_BoLabel = uilabel(leftGrid, 'Text', 'Bo [D<sub>e</sub>/uL]:', 'Interpreter', 'html') ;
            app.RTD_BoLabel.Layout.Row = 4 ; app.RTD_BoLabel.Layout.Column = 1 ;
            app.RTD_BoField = uieditfield(leftGrid, 'numeric', ...
                'Value', 0.01, 'Limits', [1e-6 Inf], ...
                'Tooltip', 'Dispersion number Bo = De/(u·L). Bo→0: plug flow, Bo→∞: perfect mixing.') ;
            app.RTD_BoField.Layout.Row = 4 ; app.RTD_BoField.Layout.Column = 2 ;
            app.setTooltip('Axial dispersion number used by the dispersion RTD model.', app.RTD_BoLabel, app.RTD_BoField) ;
            app.RTD_BoLabel.Visible = 'off' ;
            app.RTD_BoField.Visible = 'off' ;

            % Row 5: Experimental t variable
            app.RTD_ExpTVarLabel = uilabel(leftGrid, 'Text', '<i>t</i> variable (workspace):', 'Interpreter', 'html') ;
            app.RTD_ExpTVarLabel.Layout.Row = 5 ; app.RTD_ExpTVarLabel.Layout.Column = 1 ;
            expTGrid = uigridlayout(leftGrid, [1 2], ...
                'ColumnWidth', {'1x', 78}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 2) ;
            expTGrid.Layout.Row = 5 ; expTGrid.Layout.Column = 2 ;
            app.RTD_ExpTVarField = uieditfield(expTGrid, 'text', ...
                'Value', 't_exp') ;
            app.RTD_ExpTVarField.Layout.Row = 1 ; app.RTD_ExpTVarField.Layout.Column = 1 ;
            app.RTD_ExpTUnitDropdown = uidropdown(expTGrid, ...
                'Items', UnitConverterHelper.getUnits('Time'), ...
                'Value', 's') ;
            app.RTD_ExpTUnitDropdown.Layout.Row = 1 ; app.RTD_ExpTUnitDropdown.Layout.Column = 2 ;
            app.setTooltip('Workspace variable that contains the experimental time vector, plus its unit.', ...
                app.RTD_ExpTVarLabel, app.RTD_ExpTVarField, app.RTD_ExpTUnitDropdown) ;
            app.RTD_ExpTVarLabel.Visible = 'off' ;
            expTGrid.Visible = 'off' ;

            % Row 6: Experimental C variable
            app.RTD_ExpCVarLabel = uilabel(leftGrid, 'Text', '<i>C</i>(<i>t</i>) variable (workspace):', 'Interpreter', 'html') ;
            app.RTD_ExpCVarLabel.Layout.Row = 6 ; app.RTD_ExpCVarLabel.Layout.Column = 1 ;
            app.RTD_ExpCVarField = uieditfield(leftGrid, 'text', ...
                'Value', 'C_exp') ;
            app.RTD_ExpCVarField.Layout.Row = 6 ; app.RTD_ExpCVarField.Layout.Column = 2 ;
            app.setTooltip('Workspace variable that contains the experimental tracer signal C(t).', ...
                app.RTD_ExpCVarLabel, app.RTD_ExpCVarField) ;
            app.RTD_ExpCVarLabel.Visible = 'off' ;
            app.RTD_ExpCVarField.Visible = 'off' ;

            % Row 7: C0 (step only)
            app.RTD_ExpC0Label = uilabel(leftGrid, 'Text', '$C_0$ (same units as $C(t)$):', 'Interpreter', 'latex') ;
            app.RTD_ExpC0Label.Layout.Row = 7 ; app.RTD_ExpC0Label.Layout.Column = 1 ;
            [app.RTD_ExpC0Field, tmpSG] = app.createNumericWithConv( ...
                leftGrid, 7, 2, 1, 'RawScalar', 'Limits', [0 Inf]) ;
            app.setTooltip('Tracer concentration for the inlet step experiment. Use the same units as the imported C(t).', ...
                app.RTD_ExpC0Label, app.RTD_ExpC0Field) ;
            app.RTD_ExpC0Label.Visible = 'off' ;
            tmpSG.Visible = 'off' ;

            % Row 8: Import from file button (for experimental data)
            app.RTD_ImportButton = uibutton(leftGrid, 'push', ...
                'Text', 'Import Experimental Data', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1 1 1], ...
                'FontColor', [0.8 0 0], ...
                'ButtonPushedFcn', @(~,~) app.RTD_importFromFile()) ;
            app.RTD_ImportButton.Layout.Row = 8 ;
            app.RTD_ImportButton.Layout.Column = [1 2] ;
            app.RTD_ImportButton.Tooltip = 'Import experimental RTD data from a file and store a local copy in the session.' ;
            app.RTD_ImportButton.Visible = 'off' ;

            % Row 9: Import status label
            app.RTD_ImportLabel = uilabel(leftGrid, 'Text', '') ;
            app.RTD_ImportLabel.Layout.Row = 9 ;
            app.RTD_ImportLabel.Layout.Column = [1 2] ;
            app.RTD_ImportLabel.FontColor = [0 0.5 0] ;
            app.RTD_ImportLabel.Tooltip = 'Shows the status of the experimental RTD data currently loaded.' ;
            app.RTD_ImportLabel.Visible = 'off' ;

            % Rows 4-6: Piecewise C(t) table (for C(t) Equation)
            app.RTD_EqTable = uitable(leftGrid, ...
                'ColumnName', {'C(t)', 't start', 't end'}, ...
                'ColumnEditable', [true true true], ...
                'Data', app.defaultRTDEquationTableData(), ...
                'RowName', {}, ...
                'Tooltip', ['Define one C(t) expression per time interval. Use "t" as variable in the selected time unit. ' ...
                    'Leave unused rows blank.']) ;
            app.RTD_EqTable.Layout.Row = [4 6] ;
            app.RTD_EqTable.Layout.Column = [1 2] ;
            app.RTD_EqTable.Visible = 'off' ;

            % Row 7: time unit + N points (compact sub-grid, C(t) Equation only)
            app.RTD_EqRow7Grid = uigridlayout(leftGrid, [1 4], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4) ;
            app.RTD_EqRow7Grid.Layout.Row = 7 ; app.RTD_EqRow7Grid.Layout.Column = [1 2] ;
            app.RTD_EqRow7Grid.Visible = 'off' ;

            app.RTD_EqTimeUnitLabel = uilabel(app.RTD_EqRow7Grid, 'Text', 'Time unit:') ;
            app.RTD_EqTimeUnitLabel.Layout.Row = 1 ; app.RTD_EqTimeUnitLabel.Layout.Column = 1 ;
            app.RTD_EqTimeUnitLabel.Visible = 'off' ;
            app.RTD_EqTimeUnitDropdown = uidropdown(app.RTD_EqRow7Grid, ...
                'Items', UnitConverterHelper.getUnits('Time'), ...
                'Value', 's', ...
                'Tooltip', 'Defines the units shared by all t start, t end, and t values used in the piecewise C(t) table.') ;
            app.RTD_EqTimeUnitDropdown.Layout.Row = 1 ;
            app.RTD_EqTimeUnitDropdown.Layout.Column = 2 ;
            app.setTooltip('Time unit used by every piecewise C(t) segment and by the generated RTD timeline.', ...
                app.RTD_EqTimeUnitLabel, app.RTD_EqTimeUnitDropdown) ;
            app.RTD_EqTimeUnitDropdown.Visible = 'off' ;

            app.RTD_EqNptsLabel = uilabel(app.RTD_EqRow7Grid, 'Text', 'N points:') ;
            app.RTD_EqNptsLabel.Layout.Row = 1 ; app.RTD_EqNptsLabel.Layout.Column = 3 ;
            app.RTD_EqNptsLabel.Visible = 'off' ;
            app.RTD_EqNptsField = uieditfield(app.RTD_EqRow7Grid, 'numeric', ...
                'Value', 500, 'Limits', [10 10000]) ;
            app.RTD_EqNptsField.Layout.Row = 1 ; app.RTD_EqNptsField.Layout.Column = 4 ;
            app.setTooltip('Approximate total number of points used to discretize all piecewise C(t) segments before building the RTD.', ...
                app.RTD_EqNptsLabel, app.RTD_EqNptsField) ;
            app.RTD_EqNptsField.Visible = 'off' ;

            % Row 8: signal type (pulse/step) + C0 (compact sub-grid, C(t) Equation only)
            app.RTD_EqRow8Grid = uigridlayout(leftGrid, [1 4], ...
                'ColumnWidth', {'fit', '1x', 'fit', '1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4) ;
            app.RTD_EqRow8Grid.Layout.Row = 8 ; app.RTD_EqRow8Grid.Layout.Column = [1 2] ;
            app.RTD_EqRow8Grid.Visible = 'off' ;

            app.RTD_EqDataTypeLabel = uilabel(app.RTD_EqRow8Grid, 'Text', 'Data type:') ;
            app.RTD_EqDataTypeLabel.Layout.Row = 1 ; app.RTD_EqDataTypeLabel.Layout.Column = 1 ;
            app.RTD_EqDataTypeDropdown = uidropdown(app.RTD_EqRow8Grid, ...
                'Items', {'Pulse C(t)', 'Step C(t)'}, ...
                'Value', 'Pulse C(t)', ...
                'ValueChangedFcn', @(~,~) app.RTD_eqDataTypeChanged()) ;
            app.RTD_EqDataTypeDropdown.Layout.Row = 1 ; app.RTD_EqDataTypeDropdown.Layout.Column = 2 ;
            app.setTooltip(['Pulse: the piecewise C(t) is the response to an ideal pulse, E(t) = C(t)/integral(C dt). ' ...
                'Step: it is the response to an ideal step of height C0, F(t) = C(t)/C0 and E(t) = dF/dt.'], ...
                app.RTD_EqDataTypeLabel, app.RTD_EqDataTypeDropdown) ;

            app.RTD_EqC0Label = uilabel(app.RTD_EqRow8Grid, 'Text', '$C_0$:', 'Interpreter', 'latex') ;
            app.RTD_EqC0Label.Layout.Row = 1 ; app.RTD_EqC0Label.Layout.Column = 3 ;
            app.RTD_EqC0Field = uieditfield(app.RTD_EqRow8Grid, 'numeric', ...
                'Value', 1, 'Limits', [0 Inf], 'LowerLimitInclusive', 'off') ;
            app.RTD_EqC0Field.Layout.Row = 1 ; app.RTD_EqC0Field.Layout.Column = 4 ;
            app.setTooltip('Height of the inlet step, in the same units as the piecewise C(t). Only used with Step C(t).', ...
                app.RTD_EqC0Label, app.RTD_EqC0Field) ;
            app.RTD_eqDataTypeChanged() ;

            % Rows 4-9: Tabular Input components (hidden by default)
            % These share rows with N/Bo, Exp, and Equation fields

            % Row 4: Data type dropdown (Pulse C(t) or Step C(t))
            app.RTD_DataTypeLabel = uilabel(leftGrid, 'Text', 'Data type:') ;
            app.RTD_DataTypeLabel.Layout.Row = 4 ; app.RTD_DataTypeLabel.Layout.Column = 1 ;
            app.RTD_DataTypeLabel.Visible = 'off' ;
            app.RTD_DataTypeDropdown = uidropdown(leftGrid, ...
                'Items', {'Pulse C(t)', 'Step C(t)'}, ...
                'Value', 'Pulse C(t)', ...
                'Tooltip', 'Pulse: enter C(t) directly. Step: enter cumulative C(t) response to a step input.', ...
                'ValueChangedFcn', @(~,~) app.RTD_dataTypeChanged()) ;
            app.RTD_DataTypeDropdown.Layout.Row = 4 ; app.RTD_DataTypeDropdown.Layout.Column = 2 ;
            app.setTooltip('Choose whether the tabular signal represents a pulse response or a step response.', ...
                app.RTD_DataTypeLabel, app.RTD_DataTypeDropdown) ;
            app.RTD_DataTypeDropdown.Visible = 'off' ;

            % Row 5: C0 for step input (reuse same row as ExpC0)
            % (uses existing RTD_ExpC0Label and RTD_ExpC0Field, toggled in sourceChanged)

            % Rows 5-8: Editable data table
            app.RTD_DataTable = uitable(leftGrid, ...
                'ColumnName', {'t [s]', 'C(t) [mol/m³]'}, ...
                'ColumnEditable', [true true], ...
                'Data', cell(10, 2), ...
                'RowName', {}, ...
                'Tooltip', 'Enter time and concentration data. Use Add/Remove Row buttons below.') ;
            app.RTD_DataTable.Layout.Row = [5 8] ;
            app.RTD_DataTable.Layout.Column = [1 2] ;
            app.RTD_DataTable.Visible = 'off' ;

            % Row 9: Add/Remove row buttons
            app.RTD_AddRowButton = uibutton(leftGrid, 'push', ...
                'Text', '+ Row', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'ButtonPushedFcn', @(~,~) app.RTD_addTableRow()) ;
            app.RTD_AddRowButton.Layout.Row = 9 ; app.RTD_AddRowButton.Layout.Column = 1 ;
            app.RTD_AddRowButton.Tooltip = 'Append one empty row to the tabular RTD input.' ;
            app.RTD_AddRowButton.Visible = 'off' ;

            app.RTD_RemoveRowButton = uibutton(leftGrid, 'push', ...
                'Text', '- Row', ...
                'BackgroundColor', [0.95 0.85 0.85], ...
                'ButtonPushedFcn', @(~,~) app.RTD_removeTableRow()) ;
            app.RTD_RemoveRowButton.Layout.Row = 9 ; app.RTD_RemoveRowButton.Layout.Column = 2 ;
            app.RTD_RemoveRowButton.Tooltip = 'Remove the last row from the tabular RTD input.' ;
            app.RTD_RemoveRowButton.Visible = 'off' ;

            % Row 10: Generate button
            app.RTD_GenerateButton = uibutton(leftGrid, 'push', ...
                'Text', 'Generate RTD', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.3 0.6 0.9], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.RTD_generate()) ;
            app.RTD_GenerateButton.Layout.Row = 10 ;
            app.RTD_GenerateButton.Layout.Column = [1 2] ;
            app.RTD_GenerateButton.Tooltip = 'Generate or import the RTD and update the plots and characteristic moments.' ;

            % Row 11-12: Display units
            lbl = uilabel(leftGrid, 'Text', 'Display units:', ...
                'FontWeight', 'bold', 'FontSize', 13) ;
            lbl.Layout.Row = 11 ; lbl.Layout.Column = [1 2] ;
            unitsGrid = uigridlayout(leftGrid, [2 2], ...
                'ColumnWidth', {'1.15x', '0.9x'}, ...
                'RowHeight', {28, 28}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 6) ;
            unitsGrid.Layout.Row = 12 ;
            unitsGrid.Layout.Column = [1 2] ;
            app.DisplayControls.RTD.time = app.createDisplayUnitControl( ...
                unitsGrid, 1, 1, '$t$ base:', 'Time', 's', @(~,~) app.refreshDisplayUnits('RTD'), 92) ;
            app.DisplayControls.RTD.volume = app.createDisplayUnitControl( ...
                unitsGrid, 1, 2, '$V$:', 'Volume', 'm^3', @(~,~) app.refreshDisplayUnits('RTD'), 78) ;

            % Row 13: Results header
            lbl = uilabel(leftGrid, 'Text', 'Results:', ...
                'FontWeight', 'bold', 'FontSize', 13) ;
            lbl.Layout.Row = 13 ; lbl.Layout.Column = [1 2] ;

            % Row 14: tau_m
            app.RTD_ResultTauLabel = uilabel(leftGrid, ...
                'Text', '$\tau_m$ [s]:', 'Interpreter', 'latex') ;
            app.RTD_ResultTauLabel.Layout.Row = 14 ; app.RTD_ResultTauLabel.Layout.Column = 1 ;
            app.RTD_ResultTau = uilabel(leftGrid, 'Text', '--') ;
            app.RTD_ResultTau.Layout.Row = 14 ;
            app.RTD_ResultTau.Layout.Column = 2 ;
            app.setTooltip('Mean residence time of the RTD. It is the average time spent by fluid elements inside the reactor.', ...
                app.RTD_ResultTauLabel, app.RTD_ResultTau) ;

            % Row 15: sigma^2
            app.RTD_ResultSigma2Label = uilabel(leftGrid, ...
                'Text', '$\sigma^2$ [s^2]:', 'Interpreter', 'latex') ;
            app.RTD_ResultSigma2Label.Layout.Row = 15 ; app.RTD_ResultSigma2Label.Layout.Column = 1 ;
            app.RTD_ResultSigma2 = uilabel(leftGrid, 'Text', '--') ;
            app.RTD_ResultSigma2.Layout.Row = 15 ;
            app.RTD_ResultSigma2.Layout.Column = 2 ;
            app.setTooltip('Variance of the RTD. Higher values indicate broader residence-time spreading and stronger deviation from ideal plug flow.', ...
                app.RTD_ResultSigma2Label, app.RTD_ResultSigma2) ;

            % Row 16: sigma^2_theta
            lbl = uilabel(leftGrid, 'Text', '$\sigma_{\theta}^2$:', 'Interpreter', 'latex') ;
            lbl.Layout.Row = 16 ; lbl.Layout.Column = 1 ;
            app.RTD_ResultSigma2Theta = uilabel(leftGrid, 'Text', '--') ;
            app.RTD_ResultSigma2Theta.Layout.Row = 16 ;
            app.RTD_ResultSigma2Theta.Layout.Column = 2 ;
            app.setTooltip('Dimensionless RTD variance, sigma_theta^2 = sigma^2 / tau_m^2. Useful to compare RTDs independently of time scale.', ...
                lbl, app.RTD_ResultSigma2Theta) ;

            % Row 17: s^3
            lbl = uilabel(leftGrid, 'Text', '$s^3$ [skewness]:', 'Interpreter', 'latex') ;
            lbl.Layout.Row = 17 ; lbl.Layout.Column = 1 ;
            app.RTD_ResultS3 = uilabel(leftGrid, 'Text', '--') ;
            app.RTD_ResultS3.Layout.Row = 17 ;
            app.RTD_ResultS3.Layout.Column = 2 ;
            app.setTooltip('Skewness of the RTD. It indicates whether the residence-time distribution is symmetric or biased toward early or late times.', ...
                lbl, app.RTD_ResultS3) ;

            % Row 18: N_est
            lbl = uilabel(leftGrid, 'Text', '$N_{est}$ [$=\tau^2/\sigma^2$]:', 'Interpreter', 'latex') ;
            lbl.Layout.Row = 18 ; lbl.Layout.Column = 1 ;
            app.RTD_ResultN = uilabel(leftGrid, 'Text', '--') ;
            app.RTD_ResultN.Layout.Row = 18 ;
            app.RTD_ResultN.Layout.Column = 2 ;
            app.setTooltip('Equivalent number of tanks in series estimated from the RTD variance. Higher N means behavior closer to plug flow.', ...
                lbl, app.RTD_ResultN) ;

            % Row 19: V_eff
            app.RTD_ResultVeffLabel = uilabel(leftGrid, ...
                'Text', '$V_{eff}$ [m^3]:', 'Interpreter', 'latex') ;
            app.RTD_ResultVeffLabel.Layout.Row = 19 ; app.RTD_ResultVeffLabel.Layout.Column = 1 ;
            app.RTD_ResultVeff = uilabel(leftGrid, 'Text', '--') ;
            app.RTD_ResultVeff.Layout.Row = 19 ;
            app.RTD_ResultVeff.Layout.Column = 2 ;
            app.setTooltip('Effective reactor volume inferred from V_eff = tau_m * Q. It represents the volume effectively used by the flow.', ...
                app.RTD_ResultVeffLabel, app.RTD_ResultVeff) ;

            % Row 20: Export name
            lbl = uilabel(leftGrid, 'Text', 'Export name:') ;
            lbl.Layout.Row = 20 ; lbl.Layout.Column = 1 ;
            app.RTD_ExportNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'RTD_1') ;
            app.RTD_ExportNameField.Layout.Row = 20 ;
            app.RTD_ExportNameField.Layout.Column = 2 ;
            app.setTooltip('Workspace variable name used when exporting the current RTD object.', lbl, app.RTD_ExportNameField) ;

            % Row 21: Export button
            app.RTD_ExportButton = uibutton(leftGrid, 'push', ...
                'Text', 'Export RTD to Workspace', ...
                'BackgroundColor', [0.2 0.7 0.3], ...
                'FontColor', 'white', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.RTD_export()) ;
            app.RTD_ExportButton.Layout.Row = 21 ;
            app.RTD_ExportButton.Layout.Column = [1 2] ;
            app.RTD_ExportButton.Tooltip = 'Export the current RTD object to the MATLAB workspace using the chosen variable name.' ;

            % ---- RIGHT PANEL (PLOTS) ----
            rightPanel = uipanel(mainGrid, 'Title', 'RTD Plots') ;
            plotGrid = uigridlayout(rightPanel, [2 2]) ;
            plotGrid.RowHeight = {'1x', '1x'} ;
            plotGrid.ColumnWidth = {'1x', '1x'} ;

            % E(t) plot
            app.RTD_AxesEt = uiaxes(plotGrid) ;
            app.RTD_AxesEt.Layout.Row = 1 ;
            app.RTD_AxesEt.Layout.Column = 1 ;
            title(app.RTD_AxesEt, 'E(t)') ;
            xlabel(app.RTD_AxesEt, 't [s]') ;
            ylabel(app.RTD_AxesEt, 'E(t) [1/s]') ;
            grid(app.RTD_AxesEt, 'on') ;

            % F(t) plot
            app.RTD_AxesFt = uiaxes(plotGrid) ;
            app.RTD_AxesFt.Layout.Row = 1 ;
            app.RTD_AxesFt.Layout.Column = 2 ;
            title(app.RTD_AxesFt, 'F(t)') ;
            xlabel(app.RTD_AxesFt, 't [s]') ;
            ylabel(app.RTD_AxesFt, 'F(t)') ;
            grid(app.RTD_AxesFt, 'on') ;

            % E(theta) plot
            app.RTD_AxesEtheta = uiaxes(plotGrid) ;
            app.RTD_AxesEtheta.Layout.Row = 2 ;
            app.RTD_AxesEtheta.Layout.Column = 1 ;
            title(app.RTD_AxesEtheta, 'E(\Theta)') ;
            xlabel(app.RTD_AxesEtheta, '\Theta = t/\tau') ;
            ylabel(app.RTD_AxesEtheta, 'E(\Theta)') ;
            grid(app.RTD_AxesEtheta, 'on') ;

            % RTD utilities panel
            app.RTD_FQueryPanel = uipanel(plotGrid, 'Title', 'RTD Utilities') ;
            app.RTD_FQueryPanel.Layout.Row = 2 ;
            app.RTD_FQueryPanel.Layout.Column = 2 ;
            queryGrid = uigridlayout(app.RTD_FQueryPanel, [12 2]) ;
            queryGrid.RowHeight = {22, 28, 24, 22, 28, 28, 38, 22, 28, 28, 38, '1x'} ;
            queryGrid.ColumnWidth = {'1x', '1x'} ;
            queryGrid.Padding = [8 8 8 8] ;
            queryGrid.RowSpacing = 4 ;
            queryGrid.ColumnSpacing = 6 ;

            lbl = uilabel(queryGrid, 'Text', 'F(t) Query', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 1 ;
            lbl.Layout.Column = [1 2] ;
            lbl.Tooltip = ['Interpret F(t) as in exercise 51(c): x is elapsed time, ' ...
                'y = F(t) is the fraction of effluent that has already left, ' ...
                'and 1-y is the fraction that still remains inside the reactor.'] ;

            lbl = uilabel(queryGrid, 'Text', '<i>x</i> = elapsed time:', 'Interpreter', 'html') ;
            lbl.Tooltip = 'Elapsed time since the tracer entered the reactor, expressed in the selected display time unit.' ;
            app.RTD_FQueryInputField = uieditfield(queryGrid, 'text', ...
                'Value', '0', ...
                'Tooltip', 'Elapsed time x in the selected RTD display time unit.', ...
                'ValueChangedFcn', @(~,~) app.RTD_queryValueChanged()) ;
            app.RTD_FQueryInputField.Layout.Row = 2 ;
            app.RTD_FQueryInputField.Layout.Column = 2 ;
            app.setTooltip('Elapsed time x in the selected RTD display time unit.', ...
                lbl, app.RTD_FQueryInputField) ;

            lbl = uilabel(queryGrid, 'Text', '<i>y</i> = F(t):', 'Interpreter', 'html') ;
            app.RTD_FQueryValueLabel = uilabel(queryGrid, 'Text', '--') ;
            app.RTD_FQueryValueLabel.Layout.Row = 3 ;
            app.RTD_FQueryValueLabel.Layout.Column = 2 ;
            app.setTooltip(['Fraction of the effluent that has already left the reactor ' ...
                'by elapsed time x.'], lbl, app.RTD_FQueryValueLabel) ;

            lbl = uilabel(queryGrid, 'Text', '1 - <i>y</i>:', 'Interpreter', 'html') ;
            app.RTD_FQueryComplementLabel = uilabel(queryGrid, 'Text', '--') ;
            app.RTD_FQueryComplementLabel.Layout.Row = 4 ;
            app.RTD_FQueryComplementLabel.Layout.Column = 2 ;
            app.setTooltip(['Fraction of the effluent that still remains inside the reactor ' ...
                'at elapsed time x.'], lbl, app.RTD_FQueryComplementLabel) ;

            lbl = uilabel(queryGrid, 'Text', 'Reaction System', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 5 ;
            lbl.Layout.Column = [1 2] ;

            app.RTD_RSDefineButton = uibutton(queryGrid, 'push', ...
                'Text', 'New RS', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new Reaction System from scratch', ...
                'ButtonPushedFcn', @(~,~) defineReactionSysApp()) ;
            app.RTD_RSDefineButton.Layout.Row = 6 ;
            app.RTD_RSDefineButton.Layout.Column = 1 ;
            app.RTD_RSEditButton = uibutton(queryGrid, 'push', ...
                'Text', 'Edit RS', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded Reaction System', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.RTD_editRS()) ;
            app.RTD_RSEditButton.Layout.Row = 6 ;
            app.RTD_RSEditButton.Layout.Column = 2 ;
            app.RTD_RSNameField = uieditfield(queryGrid, 'text', ...
                'Value', 'RS', ...
                'Tooltip', 'Name of the ReactionSys variable in the MATLAB workspace') ;
            app.RTD_RSNameField.Layout.Row = 7 ;
            app.RTD_RSNameField.Layout.Column = 1 ;
            app.RTD_RSLoadButton = uibutton(queryGrid, 'push', ...
                'Text', 'Load', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the ReactionSys object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.RTD_loadRS()) ;
            app.RTD_RSLoadButton.Layout.Row = 7 ;
            app.RTD_RSLoadButton.Layout.Column = 2 ;
            app.RTD_RSStatusLabel = uilabel(queryGrid, ...
                'Text', 'No Reaction System loaded', ...
                'FontColor', [0.6 0 0], ...
                'WordWrap', 'on') ;
            app.RTD_RSStatusLabel.Layout.Row = 8 ;
            app.RTD_RSStatusLabel.Layout.Column = [1 2] ;
            app.RTD_RSStatusLabel.Tooltip = 'Shows whether a Reaction System is loaded and ready to be reused by later tabs.' ;

            lbl = uilabel(queryGrid, 'Text', 'Feed Stream', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 9 ;
            lbl.Layout.Column = [1 2] ;

            app.RTD_StreamDefineButton = uibutton(queryGrid, 'push', ...
                'Text', 'New Stream', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new feed stream with defineStreamApp', ...
                'ButtonPushedFcn', @(~,~) defineStreamApp()) ;
            app.RTD_StreamDefineButton.Layout.Row = 10 ;
            app.RTD_StreamDefineButton.Layout.Column = 1 ;
            app.RTD_StreamEditButton = uibutton(queryGrid, 'push', ...
                'Text', 'Edit Stream', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded feed stream', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.RTD_editStream()) ;
            app.RTD_StreamEditButton.Layout.Row = 10 ;
            app.RTD_StreamEditButton.Layout.Column = 2 ;
            app.RTD_StreamNameField = uieditfield(queryGrid, 'text', ...
                'Value', 'feed', ...
                'Tooltip', 'Name of the feed Stream variable in the MATLAB workspace') ;
            app.RTD_StreamNameField.Layout.Row = 11 ;
            app.RTD_StreamNameField.Layout.Column = 1 ;
            app.RTD_StreamLoadButton = uibutton(queryGrid, 'push', ...
                'Text', 'Load', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the feed Stream object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.RTD_loadStream()) ;
            app.RTD_StreamLoadButton.Layout.Row = 11 ;
            app.RTD_StreamLoadButton.Layout.Column = 2 ;
            app.RTD_StreamStatusLabel = uilabel(queryGrid, ...
                'Text', 'No feed stream loaded', ...
                'FontColor', [0.6 0 0], ...
                'WordWrap', 'on') ;
            app.RTD_StreamStatusLabel.Layout.Row = 12 ;
            app.RTD_StreamStatusLabel.Layout.Column = [1 2] ;
            app.RTD_StreamStatusLabel.Tooltip = 'Shows whether a feed Stream is loaded and ready to be reused by later tabs.' ;

        end

        %% ============== RTD CALLBACKS ==============

        function RTD_sourceChanged(app)
            % Show/hide fields based on selected RTD source

            source = app.RTD_SourceDropdown.Value ;

            % Hide all optional fields first
            app.RTD_NLabel.Visible = 'off' ;
            app.RTD_NField.Visible = 'off' ;
            app.RTD_BoLabel.Visible = 'off' ;
            app.RTD_BoField.Visible = 'off' ;
            app.RTD_ExpTVarLabel.Visible = 'off' ;
            app.RTD_ExpTVarField.Parent.Visible = 'off' ;
            app.RTD_ExpCVarLabel.Visible = 'off' ;
            app.RTD_ExpCVarField.Visible = 'off' ;
            app.RTD_ExpC0Label.Visible = 'off' ;
            app.RTD_ExpC0Field.Parent.Visible = 'off' ;
            app.RTD_ImportButton.Visible = 'off' ;
            app.RTD_ImportLabel.Visible = 'off' ;
            app.RTD_EqTable.Visible = 'off' ;
            app.RTD_EqTimeUnitLabel.Visible = 'off' ;
            app.RTD_EqTimeUnitDropdown.Visible = 'off' ;
            app.RTD_EqNptsLabel.Visible = 'off' ;
            app.RTD_EqNptsField.Visible = 'off' ;
            app.RTD_EqRow7Grid.Visible = 'off' ;
            app.RTD_EqRow8Grid.Visible = 'off' ;
            app.RTD_DataTypeLabel.Visible = 'off' ;
            app.RTD_DataTypeDropdown.Visible = 'off' ;
            app.RTD_DataTable.Visible = 'off' ;
            app.RTD_AddRowButton.Visible = 'off' ;
            app.RTD_RemoveRowButton.Visible = 'off' ;
            app.RTD_AddRowButton.Text = '+ Row' ;
            app.RTD_RemoveRowButton.Text = '- Row' ;
            app.RTD_AddRowButton.Tooltip = 'Append one empty row to the active table input.' ;
            app.RTD_RemoveRowButton.Tooltip = 'Remove the last row from the active table input.' ;

            % Show tau for all analytical models
            tauVisible = 'on' ;

            switch source
                case 'Tanks-in-Series'
                    app.RTD_NLabel.Visible = 'on' ;
                    app.RTD_NField.Visible = 'on' ;

                case {'Dispersion (open)', 'Dispersion (closed)'}
                    app.RTD_BoLabel.Visible = 'on' ;
                    app.RTD_BoField.Visible = 'on' ;

                case 'Laminar Flow'
                    % Only tau is needed (default visible)

                case 'Experimental Pulse'
                    app.RTD_ExpTVarLabel.Visible = 'on' ;
                    app.RTD_ExpTVarField.Parent.Visible = 'on' ;
                    app.RTD_ExpCVarLabel.Visible = 'on' ;
                    app.RTD_ExpCVarField.Visible = 'on' ;
                    app.RTD_ImportButton.Visible = 'on' ;
                    app.RTD_ImportLabel.Visible = 'on' ;
                    tauVisible = 'off' ;

                case 'Experimental Step'
                    app.RTD_ExpTVarLabel.Visible = 'on' ;
                    app.RTD_ExpTVarField.Parent.Visible = 'on' ;
                    app.RTD_ExpCVarLabel.Visible = 'on' ;
                    app.RTD_ExpCVarField.Visible = 'on' ;
                    app.RTD_ExpC0Label.Visible = 'on' ;
                    app.RTD_ExpC0Field.Parent.Visible = 'on' ;
                    app.RTD_ImportButton.Visible = 'on' ;
                    app.RTD_ImportLabel.Visible = 'on' ;
                    tauVisible = 'off' ;

                case 'C(t) Equation'
                    app.RTD_EqTable.Visible = 'on' ;
                    app.RTD_EqTimeUnitLabel.Visible = 'on' ;
                    app.RTD_EqTimeUnitDropdown.Visible = 'on' ;
                    app.RTD_EqNptsLabel.Visible = 'on' ;
                    app.RTD_EqNptsField.Visible = 'on' ;
                    app.RTD_EqRow7Grid.Visible = 'on' ;
                    app.RTD_EqRow8Grid.Visible = 'on' ;
                    app.RTD_AddRowButton.Visible = 'on' ;
                    app.RTD_RemoveRowButton.Visible = 'on' ;
                    app.RTD_AddRowButton.Text = '+ Segment' ;
                    app.RTD_RemoveRowButton.Text = '- Segment' ;
                    app.RTD_AddRowButton.Tooltip = 'Append one empty segment to the piecewise C(t) table.' ;
                    app.RTD_RemoveRowButton.Tooltip = 'Remove the last segment row from the piecewise C(t) table.' ;
                    tauVisible = 'off' ;

                case 'Tabular Input'
                    app.RTD_DataTypeLabel.Visible = 'on' ;
                    app.RTD_DataTypeDropdown.Visible = 'on' ;
                    app.RTD_DataTable.Visible = 'on' ;
                    app.RTD_AddRowButton.Visible = 'on' ;
                    app.RTD_RemoveRowButton.Visible = 'on' ;
                    % Show C0 field only for step input
                    if strcmp(app.RTD_DataTypeDropdown.Value, 'Step C(t)')
                        app.RTD_ExpC0Label.Visible = 'on' ;
                        app.RTD_ExpC0Field.Parent.Visible = 'on' ;
                    end
                    tauVisible = 'off' ;
            end

            app.RTD_TauField.Parent.Visible = tauVisible ;
        end

        function RTD_dataTypeChanged(app)
            % Show/hide C0 field when switching between Pulse and Step in Tabular Input
            if strcmp(app.RTD_SourceDropdown.Value, 'Tabular Input')
                if strcmp(app.RTD_DataTypeDropdown.Value, 'Step C(t)')
                    app.RTD_ExpC0Label.Visible = 'on' ;
                    app.RTD_ExpC0Field.Parent.Visible = 'on' ;
                else
                    app.RTD_ExpC0Label.Visible = 'off' ;
                    app.RTD_ExpC0Field.Parent.Visible = 'off' ;
                end
            end
        end

        function RTD_eqDataTypeChanged(app)
            % Enable C0 only when the piecewise C(t) is a step response
            state = 'off' ;
            if strcmp(app.RTD_EqDataTypeDropdown.Value, 'Step C(t)')
                state = 'on' ;
            end
            app.RTD_EqC0Label.Enable = state ;
            app.RTD_EqC0Field.Enable = state ;
        end

        function RTD_addTableRow(app)
            % Add a row to the active table input
            targetTable = app.RTD_DataTable ;
            newRow = cell(1, 2) ;
            if strcmp(app.RTD_SourceDropdown.Value, 'C(t) Equation')
                targetTable = app.RTD_EqTable ;
                newRow = cell(1, 3) ;
            end

            currentData = targetTable.Data ;
            if ~iscell(currentData)
                currentData = num2cell(currentData) ;
            end
            targetTable.Data = [currentData ; newRow] ;
        end

        function RTD_removeTableRow(app)
            % Remove the last row from the active table input
            targetTable = app.RTD_DataTable ;
            if strcmp(app.RTD_SourceDropdown.Value, 'C(t) Equation')
                targetTable = app.RTD_EqTable ;
            end

            currentData = targetTable.Data ;
            if size(currentData, 1) > 1
                targetTable.Data = currentData(1:end-1, :) ;
            end
        end

        function RTD_generate(app)
            % Generate RTD based on selected source and parameters

            try
                app.updateStatus('Generating RTD...') ;
                source = app.RTD_SourceDropdown.Value ;
                tau_val = app.readInputField(app.RTD_TauField) ;

                switch source
                    case 'Ideal CSTR'
                        app.rtd = RTD.ideal_cstr(tau_val) ;

                    case 'Ideal PFR'
                        app.rtd = RTD.ideal_pfr(tau_val) ;

                    case 'Tanks-in-Series'
                        n = app.RTD_NField.Value ;
                        app.rtd = RTD.tanks_in_series(n, tau_val) ;

                    case 'Dispersion (open)'
                        Bo = app.RTD_BoField.Value ;
                        tauSpace = tau_val / (1 + 2 * Bo) ;
                        app.rtd = RTD.dispersion_open(Bo, tauSpace) ;

                    case 'Dispersion (closed)'
                        Bo = app.RTD_BoField.Value ;
                        app.rtd = RTD.dispersion_closed(Bo, tau_val) ;

                    case 'Laminar Flow'
                        tau_val = app.readInputField(app.RTD_TauField) ;
                        app.rtd = RTD.laminar_flow(tau_val) ;

                    case 'Experimental Pulse'
                        t_var = app.RTD_ExpTVarField.Value ;
                        C_var = app.RTD_ExpCVarField.Value ;
                        t_data = evalin('base', t_var) ;
                        C_data = evalin('base', C_var) ;
                        t_data = UnitConverterHelper.convertToSI('Time', t_data, app.RTD_ExpTUnitDropdown.Value) ;
                        app.rtd = RTD.from_pulse(t_data, C_data) ;

                    case 'Experimental Step'
                        t_var = app.RTD_ExpTVarField.Value ;
                        C_var = app.RTD_ExpCVarField.Value ;
                        t_data = evalin('base', t_var) ;
                        C_data = evalin('base', C_var) ;
                        t_data = UnitConverterHelper.convertToSI('Time', t_data, app.RTD_ExpTUnitDropdown.Value) ;
                        C0 = app.readInputField(app.RTD_ExpC0Field) ;
                        app.rtd = RTD.from_step(t_data, C_data, C0) ;

                    case 'C(t) Equation'
                        t_unit = app.RTD_EqTimeUnitDropdown.Value ;
                        [t, C_data] = app.buildRTDEquationSignal() ;
                        t_si = UnitConverterHelper.convertToSI('Time', t, t_unit) ;
                        if strcmp(app.RTD_EqDataTypeDropdown.Value, 'Step C(t)')
                            app.rtd = RTD.from_step(t_si, C_data, app.RTD_EqC0Field.Value) ;
                        else
                            app.rtd = RTD.from_pulse(t_si, C_data) ;
                        end

                    case 'Tabular Input'
                        % Read data from the editable table
                        rawData = app.RTD_DataTable.Data ;

                        % Convert cell array to numeric, filtering empty rows
                        if iscell(rawData)
                            numData = zeros(size(rawData)) ;
                            validRows = true(size(rawData, 1), 1) ;
                            for iRow = 1:size(rawData, 1)
                                for iCol = 1:2
                                    val = rawData{iRow, iCol} ;
                                    if isempty(val) || (ischar(val) && isempty(strtrim(val)))
                                        validRows(iRow) = false ;
                                        break
                                    end
                                    if ischar(val) || isstring(val)
                                        try
                                            val = InputLayerHelper.parseArithmeticExpression(val) ;
                                        catch
                                            validRows(iRow) = false ;
                                            break
                                        end
                                    end
                                    if isnan(val)
                                        validRows(iRow) = false ;
                                        break
                                    end
                                    numData(iRow, iCol) = val ;
                                end
                            end
                            numData = numData(validRows, :) ;
                        else
                            % Already numeric (table or matrix)
                            if istable(rawData)
                                numData = table2array(rawData) ;
                            else
                                numData = rawData ;
                            end
                            validRows = all(isfinite(numData), 2) ;
                            numData = numData(validRows, :) ;
                        end

                        if size(numData, 1) < 3
                            error('At least 3 valid data points are required. Fill the table with time [s] and C(t) [mol/m³] values.') ;
                        end

                        t_data = numData(:, 1)' ;
                        C_data = numData(:, 2)' ;

                        % Validate
                        if any(t_data < 0)
                            error('Time values must be non-negative.') ;
                        end

                        % Ensure non-negative concentrations
                        C_data = max(C_data, 0) ;

                        dataType = app.RTD_DataTypeDropdown.Value ;
                        if strcmp(dataType, 'Pulse C(t)')
                            app.rtd = RTD.from_pulse(t_data, C_data) ;
                        else
                            % Step input: need C0
                            C0 = app.readInputField(app.RTD_ExpC0Field) ;
                            app.rtd = RTD.from_step(t_data, C_data, C0) ;
                        end
                end

                % Update results
                app.RTD_updateResults() ;

                % Update plots
                app.RTD_updatePlots() ;
                app.RTD_updateFQuery() ;

                % Enable export button
                app.RTD_ExportButton.Enable = 'on' ;

                % Update Tab 2 RTD status if tab exists
                if ~isempty(app.Pred_RTDStatusLabel)
                    app.Pred_RTDStatusLabel.Text = app.htmlStatusTauSigma(source, app.rtd.tau, app.rtd.sigma2) ;
                    app.Pred_RTDStatusLabel.FontColor = [0 0.5 0] ;
                end
                if ~isempty(app.Pred_InputMethodDropdown) && ...
                        contains(app.Pred_InputMethodDropdown.Value, 'From Calculated')
                    app.Pred_syncFromRTDTab() ;
                end

                app.updateStatus('Ready') ;

            catch ME
                app.updateStatus('Error') ;
                uialert(app.UIFigure, ME.message, 'RTD Generation Error') ;
            end
        end

        function RTD_updateResults(app)
            % Update the results labels with RTD moments

            if isempty(app.rtd)
                return
            end

            timeDD = app.DisplayControls.RTD.time ;
            volDD = app.DisplayControls.RTD.volume ;

            app.RTD_ResultTauLabel.Text = app.latexLabelWithUnit('$\tau_m$', timeDD.Value) ;
            app.RTD_ResultSigma2Label.Text = app.latexLabelWithUnit('$\sigma^2$', app.timeSquaredUnitName(timeDD)) ;
            app.RTD_ResultVeffLabel.Text = app.latexLabelWithUnit('$V_{eff}$', volDD.Value) ;

            tauDisplay = app.convertOutputFromTime('time', app.rtd.tau, timeDD) ;
            sigmaDisplay = app.convertOutputFromTime('timeSquared', app.rtd.sigma2, timeDD) ;
            app.RTD_ResultTau.Text = sprintf('%.4f', tauDisplay) ;
            app.RTD_ResultSigma2.Text = sprintf('%.4f', sigmaDisplay) ;

            if ~isempty(app.rtd.sigma2_theta)
                app.RTD_ResultSigma2Theta.Text = sprintf('%.6f', app.rtd.sigma2_theta) ;
            end

            if ~isempty(app.rtd.s3)
                app.RTD_ResultS3.Text = sprintf('%.4f', app.rtd.s3) ;
            end

            if app.rtd.sigma2 > 0
                N_est = app.rtd.tau^2 / app.rtd.sigma2 ;
                app.RTD_ResultN.Text = sprintf('%.2f', N_est) ;
            end

            % V_eff = tau * Qv
            Qv = app.readInputField(app.RTD_QvField) ;
            V_eff = app.rtd.tau * Qv ;
            VeffDisplay = app.convertOutputScalar('Volume', V_eff, volDD) ;
            app.RTD_ResultVeff.Text = sprintf('%.6g', VeffDisplay) ;
        end

        function RTD_updatePlots(app)
            % Update all three RTD plots

            if isempty(app.rtd)
                return
            end

            app.RTD_clearMomentOverlays() ;

            timeDD = app.DisplayControls.RTD.time ;
            t_display = app.convertOutputVectorFromTime('time', app.rtd.t, timeDD) ;
            Et_display = app.convertOutputVectorFromTime('timeInverse', app.rtd.Et, timeDD) ;
            tol = 1e-12 ;

            % E(t) plot
            cla(app.RTD_AxesEt) ;
            hold(app.RTD_AxesEt, 'on') ;
            tau_display = app.convertOutputFromTime('time', app.rtd.tau, timeDD) ;
            sigma_display = app.convertOutputFromTime('time', sqrt(max(app.rtd.sigma2, 0)), timeDD) ;
            t_lower = max(0, tau_display - sigma_display) ;
            t_upper = tau_display + sigma_display ;
            if isfinite(sigma_display) && sigma_display > tol
                [xPatch, yPatch] = app.RTD_buildMomentBandPatch(t_display, Et_display, t_lower, t_upper) ;
                if ~isempty(xPatch)
                    app.RTD_EtSigmaBandHandle = patch(app.RTD_AxesEt, xPatch, yPatch, [0.64 0.80 1.00], ...
                        'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off') ;
                end
            end
            plot(app.RTD_AxesEt, t_display, Et_display, 'b-', 'LineWidth', 1.5) ;
            app.RTD_expandMomentAxesY(app.RTD_AxesEt, Et_display) ;
            title(app.RTD_AxesEt, 'E(t)') ;
            xlabel(app.RTD_AxesEt, app.axisLabelWithUnit('t', timeDD)) ;
            ylabel(app.RTD_AxesEt, app.axisLabelWithUnitName('E(t)', app.timeInverseUnitName(timeDD))) ;
            [app.RTD_EtSigmaCenterHandle, app.RTD_EtSigmaLowerHandle, app.RTD_EtSigmaUpperHandle, app.RTD_EtSigmaLabelHandles] = ...
                app.RTD_drawMomentGuideLines(app.RTD_AxesEt, t_display, Et_display, tau_display, t_lower, t_upper, sigma_display, [0.00 0.20 0.75], tol, ...
                {'\tau', '\tau-\sigma', '\tau+\sigma'}) ;
            hold(app.RTD_AxesEt, 'off') ;

            % F(t) plot
            cla(app.RTD_AxesFt) ;
            plot(app.RTD_AxesFt, t_display, app.rtd.Ft, 'r-', 'LineWidth', 1.5) ;
            title(app.RTD_AxesFt, 'F(t)') ;
            xlabel(app.RTD_AxesFt, app.axisLabelWithUnit('t', timeDD)) ;
            ylabel(app.RTD_AxesFt, 'F(t)') ;
            ylim(app.RTD_AxesFt, [0 1.05]) ;

            % E(theta) plot
            cla(app.RTD_AxesEtheta) ;
            hold(app.RTD_AxesEtheta, 'on') ;
            if ~isempty(app.rtd.theta) && ~isempty(app.rtd.Etheta)
                sigma_theta = sqrt(max(app.rtd.sigma2_theta, 0)) ;
                theta_lower = max(0, 1 - sigma_theta) ;
                theta_upper = 1 + sigma_theta ;
                if ~isempty(app.rtd.tau) && isfinite(app.rtd.tau) && app.rtd.tau > 0 && ...
                        ~isempty(sigma_theta) && ...
                        isfinite(sigma_theta) && sigma_theta > tol
                    [thetaPatch, ethetaPatch] = app.RTD_buildMomentBandPatch( ...
                        app.rtd.theta, app.rtd.Etheta, theta_lower, theta_upper) ;
                    if ~isempty(thetaPatch)
                        app.RTD_EthetaSigmaBandHandle = patch(app.RTD_AxesEtheta, thetaPatch, ethetaPatch, [0.72 0.90 0.72], ...
                            'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off') ;
                    end
                end
                plot(app.RTD_AxesEtheta, app.rtd.theta, app.rtd.Etheta, ...
                     'Color', [0 0.6 0], 'LineWidth', 1.5) ;
                app.RTD_expandMomentAxesY(app.RTD_AxesEtheta, app.rtd.Etheta) ;
                if ~isempty(app.rtd.tau) && isfinite(app.rtd.tau) && app.rtd.tau > 0
                    [app.RTD_EthetaSigmaCenterHandle, app.RTD_EthetaSigmaLowerHandle, app.RTD_EthetaSigmaUpperHandle, app.RTD_EthetaSigmaLabelHandles] = ...
                        app.RTD_drawMomentGuideLines(app.RTD_AxesEtheta, app.rtd.theta, app.rtd.Etheta, 1, theta_lower, theta_upper, sigma_theta, [0.00 0.45 0.00], tol, ...
                        {'1', '1-\sigma_\theta', '1+\sigma_\theta'}) ;
                end
            end
            title(app.RTD_AxesEtheta, 'E(\Theta)') ;
            xlabel(app.RTD_AxesEtheta, '\Theta = t/\tau') ;
            ylabel(app.RTD_AxesEtheta, 'E(\Theta)') ;
            hold(app.RTD_AxesEtheta, 'off') ;
        end

        function RTD_queryValueChanged(app)
            if isempty(app.RTD_FQueryInputField) || ~isvalid(app.RTD_FQueryInputField)
                return
            end

            queryText = strtrim(app.RTD_FQueryInputField.Value) ;
            if isempty(queryText)
                app.RTD_FQueryInputField.UserData = [] ;
                app.RTD_updateFQuery() ;
                return
            end

            try
                queryValue = InputLayerHelper.parseArithmeticExpression(queryText) ;
                querySI = UnitConverterHelper.convertToSI('Time', queryValue, ...
                    app.DisplayControls.RTD.time.Value) ;
                app.RTD_FQueryInputField.UserData = struct('querySI', querySI) ;
                app.RTD_syncQueryFieldToDisplayUnit() ;
            catch
                app.RTD_FQueryInputField.UserData = [] ;
            end
            app.RTD_updateFQuery() ;
        end

        function RTD_syncQueryFieldToDisplayUnit(app)
            if isempty(app.RTD_FQueryInputField) || ~isvalid(app.RTD_FQueryInputField)
                return
            end

            if ~isstruct(app.RTD_FQueryInputField.UserData) || ...
                    ~isfield(app.RTD_FQueryInputField.UserData, 'querySI')
                return
            end

            queryDisplay = UnitConverterHelper.convertFromSI('Time', ...
                app.RTD_FQueryInputField.UserData.querySI, app.DisplayControls.RTD.time.Value) ;
            app.RTD_FQueryInputField.Value = sprintf('%.6g', queryDisplay) ;
        end

        function RTD_updateFQuery(app)
            if isempty(app.RTD_FQueryValueLabel) || ~isvalid(app.RTD_FQueryValueLabel)
                return
            end

            if isempty(app.rtd) || ~isstruct(app.RTD_FQueryInputField.UserData) || ...
                    ~isfield(app.RTD_FQueryInputField.UserData, 'querySI')
                app.RTD_FQueryValueLabel.Text = '--' ;
                app.RTD_FQueryComplementLabel.Text = '--' ;
                app.RTD_clearFQueryOverlay() ;
                return
            end

            querySI = app.RTD_FQueryInputField.UserData.querySI ;
            tData = app.rtd.t(:) ;
            fData = app.rtd.Ft(:) ;

            if isempty(tData) || isempty(fData)
                app.RTD_FQueryValueLabel.Text = '--' ;
                app.RTD_FQueryComplementLabel.Text = '--' ;
                app.RTD_clearFQueryOverlay() ;
                return
            end

            if querySI <= tData(1)
                fValue = 0 ;
            elseif querySI >= tData(end)
                fValue = 1 ;
            else
                fValue = interp1(tData, fData, querySI, 'linear') ;
            end

            fValue = min(max(fValue, 0), 1) ;
            app.RTD_FQueryValueLabel.Text = sprintf('%.6f', fValue) ;
            app.RTD_FQueryComplementLabel.Text = sprintf('%.6f', 1 - fValue) ;
            app.RTD_drawFQueryOverlay(querySI, fValue) ;
        end

        function RTD_clearFQueryOverlay(app)
            overlayHandles = { ...
                app.RTD_FQueryPointHandle, ...
                app.RTD_FQueryVerticalHandle, ...
                app.RTD_FQueryHorizontalHandle} ;

            for k = 1:numel(overlayHandles)
                h = overlayHandles{k} ;
                if ~isempty(h)
                    validHandles = h(isgraphics(h)) ;
                    if ~isempty(validHandles)
                        delete(validHandles) ;
                    end
                end
            end

            app.RTD_FQueryPointHandle = [] ;
            app.RTD_FQueryVerticalHandle = [] ;
            app.RTD_FQueryHorizontalHandle = [] ;
        end

        function RTD_clearMomentOverlays(app)
            overlayHandles = { ...
                app.RTD_EtSigmaBandHandle, ...
                app.RTD_EtSigmaCenterHandle, ...
                app.RTD_EtSigmaLowerHandle, ...
                app.RTD_EtSigmaUpperHandle, ...
                app.RTD_EthetaSigmaBandHandle, ...
                app.RTD_EthetaSigmaCenterHandle, ...
                app.RTD_EthetaSigmaLowerHandle, ...
                app.RTD_EthetaSigmaUpperHandle, ...
                app.RTD_EtSigmaLabelHandles, ...
                app.RTD_EthetaSigmaLabelHandles} ;

            for k = 1:numel(overlayHandles)
                h = overlayHandles{k} ;
                if ~isempty(h)
                    validHandles = h(isgraphics(h)) ;
                    if ~isempty(validHandles)
                        delete(validHandles) ;
                    end
                end
            end

            app.RTD_EtSigmaBandHandle = [] ;
            app.RTD_EtSigmaCenterHandle = [] ;
            app.RTD_EtSigmaLowerHandle = [] ;
            app.RTD_EtSigmaUpperHandle = [] ;
            app.RTD_EthetaSigmaBandHandle = [] ;
            app.RTD_EthetaSigmaCenterHandle = [] ;
            app.RTD_EthetaSigmaLowerHandle = [] ;
            app.RTD_EthetaSigmaUpperHandle = [] ;
            app.RTD_EtSigmaLabelHandles = gobjects(0) ;
            app.RTD_EthetaSigmaLabelHandles = gobjects(0) ;
        end

        function clearGraphicsHandleSet(~, overlayHandles)
            for k = 1:numel(overlayHandles)
                h = overlayHandles{k} ;
                if ~isempty(h)
                    validHandles = h(isgraphics(h)) ;
                    if ~isempty(validHandles)
                        delete(validHandles) ;
                    end
                end
            end
        end

        function TIS_clearMomentOverlay(app)
            app.clearGraphicsHandleSet({ ...
                app.TIS_EtSigmaBandHandle, ...
                app.TIS_EtSigmaCenterHandle, ...
                app.TIS_EtSigmaLowerHandle, ...
                app.TIS_EtSigmaUpperHandle, ...
                app.TIS_EtSigmaLabelHandles}) ;
            app.TIS_EtSigmaBandHandle = [] ;
            app.TIS_EtSigmaCenterHandle = [] ;
            app.TIS_EtSigmaLowerHandle = [] ;
            app.TIS_EtSigmaUpperHandle = [] ;
            app.TIS_EtSigmaLabelHandles = gobjects(0) ;
        end

        function Disp_clearMomentOverlay(app)
            app.clearGraphicsHandleSet({ ...
                app.Disp_EtSigmaBandHandle, ...
                app.Disp_EtSigmaCenterHandle, ...
                app.Disp_EtSigmaLowerHandle, ...
                app.Disp_EtSigmaUpperHandle, ...
                app.Disp_EtSigmaLabelHandles}) ;
            app.Disp_EtSigmaBandHandle = [] ;
            app.Disp_EtSigmaCenterHandle = [] ;
            app.Disp_EtSigmaLowerHandle = [] ;
            app.Disp_EtSigmaUpperHandle = [] ;
            app.Disp_EtSigmaLabelHandles = gobjects(0) ;
        end

        function [centerValue, sigmaValue] = RTD_resolveMomentCenterSigmaFromEt(app, rtdObj, xData, yData, timeDD)
            centerValue = NaN ;
            sigmaValue = NaN ;

            if ~isempty(rtdObj) && isa(rtdObj, 'RTD') && ...
                    ~isempty(rtdObj.tau) && isfinite(rtdObj.tau) && ...
                    ~isempty(rtdObj.sigma2) && isfinite(rtdObj.sigma2)
                centerValue = app.convertOutputFromTime('time', rtdObj.tau, timeDD) ;
                sigmaValue = app.convertOutputFromTime('time', sqrt(max(rtdObj.sigma2, 0)), timeDD) ;
                return
            end

            if isempty(xData) || isempty(yData)
                return
            end

            xData = xData(:)' ;
            yData = yData(:)' ;
            validMask = isfinite(xData) & isfinite(yData) ;
            xData = xData(validMask) ;
            yData = yData(validMask) ;
            if numel(xData) < 2
                return
            end

            area = trapz(xData, yData) ;
            if ~(isfinite(area) && area > 0)
                return
            end

            yNorm = yData / area ;
            centerValue = trapz(xData, xData .* yNorm) ;
            sigma2Value = trapz(xData, (xData - centerValue).^2 .* yNorm) ;
            if isfinite(sigma2Value)
                sigmaValue = sqrt(max(sigma2Value, 0)) ;
            end
        end

        function [bandHandle, centerValue, lowerValue, upperValue, sigmaValue] = RTD_drawEtMomentOverlay(app, ax, rtdObj, xData, yData, timeDD, bandColor)
            bandHandle = [] ;
            centerValue = NaN ;
            lowerValue = NaN ;
            upperValue = NaN ;
            sigmaValue = NaN ;

            if isempty(ax) || ~isvalid(ax) || isempty(xData) || isempty(yData)
                return
            end

            tol = 1e-12 ;
            [centerValue, sigmaValue] = app.RTD_resolveMomentCenterSigmaFromEt(rtdObj, xData, yData, timeDD) ;
            if ~(isfinite(centerValue) && centerValue >= 0)
                return
            end

            lowerValue = max(0, centerValue - max(sigmaValue, 0)) ;
            upperValue = centerValue + max(sigmaValue, 0) ;

            if isfinite(sigmaValue) && sigmaValue > tol
                [xPatch, yPatch] = app.RTD_buildMomentBandPatch(xData, yData, lowerValue, upperValue) ;
                if ~isempty(xPatch)
                    bandHandle = patch(ax, xPatch, yPatch, bandColor, ...
                        'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off') ;
                end
            end
        end

        function [xPatch, yPatch] = RTD_buildMomentBandPatch(~, xData, yData, xLower, xUpper)
            xPatch = [] ;
            yPatch = [] ;

            if isempty(xData) || isempty(yData) || numel(xData) ~= numel(yData)
                return
            end

            xData = xData(:)' ;
            yData = yData(:)' ;
            validMask = isfinite(xData) & isfinite(yData) ;
            xData = xData(validMask) ;
            yData = yData(validMask) ;
            if numel(xData) < 2
                return
            end

            xStart = max(xLower, xData(1)) ;
            xEnd = min(xUpper, xData(end)) ;
            if ~isfinite(xStart) || ~isfinite(xEnd) || xEnd <= xStart
                return
            end

            yStart = interp1(xData, yData, xStart, 'linear') ;
            yEnd = interp1(xData, yData, xEnd, 'linear') ;
            interiorMask = xData > xStart & xData < xEnd ;
            xSegment = [xStart, xData(interiorMask), xEnd] ;
            ySegment = [yStart, yData(interiorMask), yEnd] ;

            xPatch = [xSegment, fliplr(xSegment)] ;
            yPatch = [zeros(size(ySegment)), fliplr(ySegment)] ;
        end

        function RTD_expandMomentAxesY(~, ax, yData)
            if isempty(ax) || ~isvalid(ax) || isempty(yData)
                return
            end

            yData = yData(isfinite(yData)) ;
            if isempty(yData)
                return
            end

            yMax = max(yData) ;
            if ~isfinite(yMax)
                return
            end
            if yMax <= 0
                ylim(ax, [0 1]) ;
            else
                ylim(ax, [0 yMax * 1.12]) ;
            end
        end

        function [centerHandle, lowerHandle, upperHandle, labelHandles] = RTD_drawMomentGuideLines(~, ax, xData, yData, centerValue, lowerValue, upperValue, sigmaValue, lineColor, tol, labels)
            centerHandle = [] ;
            lowerHandle = [] ;
            upperHandle = [] ;
            labelHandles = gobjects(0) ;

            if isempty(ax) || ~isvalid(ax) || ~isfinite(centerValue) || isempty(xData) || isempty(yData)
                return
            end

            xData = xData(:)' ;
            yData = yData(:)' ;
            validMask = isfinite(xData) & isfinite(yData) ;
            xData = xData(validMask) ;
            yData = yData(validMask) ;
            if numel(xData) < 2
                return
            end

            yLimits = ylim(ax) ;
            yRange = max(yLimits(2) - yLimits(1), 1e-12) ;
            labelOffset = 0.02 * yRange ;
            [centerY, centerDrawn] = localCurveIntersection(centerValue) ;
            if centerDrawn
                centerHandle = plot(ax, [centerValue centerValue], [0 centerY], '-', ...
                'Color', lineColor, 'LineWidth', 1.6, 'HandleVisibility', 'off') ;
                labelHandles(end + 1) = text(ax, centerValue, min(centerY + labelOffset, yLimits(2) - 0.01 * yRange), labels{1}, ...
                    'Color', lineColor, 'FontSize', 9, 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom', 'Interpreter', 'tex', 'Clipping', 'on') ; %#ok<AGROW>
            end

            if isempty(sigmaValue) || ~isfinite(sigmaValue) || sigmaValue <= tol
                return
            end

            if isfinite(lowerValue) && abs(lowerValue - centerValue) > tol
                [lowerY, lowerDrawn] = localCurveIntersection(lowerValue) ;
                if lowerDrawn
                    lowerHandle = plot(ax, [lowerValue lowerValue], [0 lowerY], '--', ...
                        'Color', lineColor, 'LineWidth', 1.0, 'HandleVisibility', 'off') ;
                    labelHandles(end + 1) = text(ax, lowerValue, min(lowerY + labelOffset, yLimits(2) - 0.01 * yRange), labels{2}, ...
                        'Color', lineColor, 'FontSize', 9, 'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'bottom', 'Interpreter', 'tex', 'Clipping', 'on') ; %#ok<AGROW>
                end
            end
            if isfinite(upperValue) && abs(upperValue - centerValue) > tol
                [upperY, upperDrawn] = localCurveIntersection(upperValue) ;
                if upperDrawn
                    upperHandle = plot(ax, [upperValue upperValue], [0 upperY], '--', ...
                        'Color', lineColor, 'LineWidth', 1.0, 'HandleVisibility', 'off') ;
                    labelHandles(end + 1) = text(ax, upperValue, min(upperY + labelOffset, yLimits(2) - 0.01 * yRange), labels{3}, ...
                        'Color', lineColor, 'FontSize', 9, 'HorizontalAlignment', 'center', ...
                        'VerticalAlignment', 'bottom', 'Interpreter', 'tex', 'Clipping', 'on') ; %#ok<AGROW>
                end
            end

            function [yValue, isDrawable] = localCurveIntersection(xValue)
                yValue = NaN ;
                isDrawable = false ;
                if ~isfinite(xValue) || xValue < xData(1) || xValue > xData(end)
                    return
                end
                yValue = interp1(xData, yData, xValue, 'linear') ;
                isDrawable = isfinite(yValue) && yValue >= 0 ;
            end
        end

        function RTD_drawFQueryOverlay(app, querySI, fValue)
            if isempty(app.RTD_AxesFt) || ~isvalid(app.RTD_AxesFt)
                return
            end

            app.RTD_clearFQueryOverlay() ;

            timeDD = app.DisplayControls.RTD.time ;
            xQuery = app.convertOutputFromTime('time', querySI, timeDD) ;
            xLimits = xlim(app.RTD_AxesFt) ;
            yLimits = ylim(app.RTD_AxesFt) ;

            hold(app.RTD_AxesFt, 'on') ;
            app.RTD_FQueryVerticalHandle = plot(app.RTD_AxesFt, ...
                [xQuery xQuery], [yLimits(1) fValue], ...
                'k--', 'LineWidth', 1, 'HandleVisibility', 'off') ;
            app.RTD_FQueryHorizontalHandle = plot(app.RTD_AxesFt, ...
                [xLimits(1) xQuery], [fValue fValue], ...
                'k--', 'LineWidth', 1, 'HandleVisibility', 'off') ;
            app.RTD_FQueryPointHandle = plot(app.RTD_AxesFt, ...
                xQuery, fValue, 'ko', 'MarkerSize', 6, ...
                'MarkerFaceColor', [1 0.8 0], ...
                'HandleVisibility', 'off') ;
            hold(app.RTD_AxesFt, 'off') ;
        end


        function RTD_export(app)
            % Export RTD object to base workspace with user-defined name
            % Auto-increments the name for subsequent exports

            if isempty(app.rtd)
                uialert(app.UIFigure, 'No RTD to export. Generate one first.', 'Warning') ;
                return
            end

            varName = app.RTD_ExportNameField.Value ;

            % Validate variable name
            if ~isvarname(varName)
                uialert(app.UIFigure, ...
                    sprintf('"%s" is not a valid MATLAB variable name.', varName), ...
                    'Invalid Name') ;
                return
            end

            assignin('base', varName, app.rtd) ;
            uialert(app.UIFigure, ...
                sprintf('RTD exported to workspace as "%s"', varName), ...
                'Export Successful', 'Icon', 'success') ;

            % Auto-increment for next export
            app.RTD_ExportCounter = app.RTD_ExportCounter + 1 ;
            app.RTD_ExportNameField.Value = sprintf('RTD_%d', app.RTD_ExportCounter) ;
        end

        function RTD_importFromFile(app)
            % Import experimental data (t, C) from Excel or CSV file
            % Reads the first two columns as t and C vectors and assigns
            % them to the workspace with the names specified in the fields.

            [file, path] = uigetfile( ...
                {'*.xlsx;*.xls;*.csv;*.tsv', 'Data files (*.xlsx, *.xls, *.csv, *.tsv)' ; ...
                 '*.*', 'All files (*.*)'}, ...
                'Select experimental data file') ;

            if isequal(file, 0)
                return  % User cancelled
            end

            try
                fullPath = fullfile(path, file) ;

                % Read data depending on extension
                [~, ~, ext] = fileparts(file) ;

                switch lower(ext)
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
                    uialert(app.UIFigure, ...
                        'The file must have at least 2 columns (t and C).', ...
                        'Import Error') ;
                    return
                end

                % Remove rows with NaN (common with headers)
                data = data(~any(isnan(data(:,1:2)), 2), :) ;

                t_data = data(:, 1)' ;
                C_data = data(:, 2)' ;

                % Assign to workspace with user-specified names
                t_varName = app.RTD_ExpTVarField.Value ;
                C_varName = app.RTD_ExpCVarField.Value ;

                assignin('base', t_varName, t_data) ;
                assignin('base', C_varName, C_data) ;

                % Update status label
                app.RTD_ImportLabel.Text = sprintf('Loaded: %s (%d pts)', file, length(t_data)) ;
                app.RTD_ImportLabel.Visible = 'on' ;

            catch ME
                uialert(app.UIFigure, ME.message, 'Import Error') ;
            end
        end

        function RTD_loadRS(app)
            rsName = app.RTD_RSNameField.Value ;
            try
                RS = evalin('base', rsName) ;
                if ~isa(RS, 'ReactionSys')
                    error('Variable "%s" is not a ReactionSys object.', rsName) ;
                end
                app.RTD_RS = RS ;
                app.RTD_RSStatusLabel.Text = sprintf('Loaded: %d reactions, %d components', ...
                    RS.nReactions, RS.nComponents) ;
                app.RTD_RSStatusLabel.FontColor = [0 0.5 0] ;
                app.RTD_RSEditButton.Enable = 'on' ;

                if ~isempty(app.RTD_feedStream) && ...
                        length(app.RTD_feedStream.concentration) ~= RS.nComponents
                    app.RTD_feedStream = [] ;
                    app.RTD_StreamEditButton.Enable = 'off' ;
                    app.RTD_StreamStatusLabel.Text = 'Loaded stream cleared: its component count does not match the new Reaction System.' ;
                    app.RTD_StreamStatusLabel.FontColor = [0.8 0 0] ;
                end
                if ~isempty(app.Pred_InputMethodDropdown) && ...
                        contains(app.Pred_InputMethodDropdown.Value, 'From Calculated')
                    app.Pred_syncFromRTDTab() ;
                end
            catch ME
                app.RTD_RSStatusLabel.Text = ME.message ;
                app.RTD_RSStatusLabel.FontColor = [0.8 0 0] ;
            end
        end

        function RTD_editRS(app)
            if isempty(app.RTD_RS)
                uialert(app.UIFigure, 'No Reaction System loaded to edit.', 'Nothing to Edit') ;
                return
            end
            defineReactionSysApp(app.RTD_RS, app.RTD_RSNameField.Value) ;
        end

        function RTD_loadStream(app)
            [S, ok] = app.loadStreamFromWorkspace( ...
                app.RTD_StreamNameField, app.RTD_StreamStatusLabel, app.RTD_RS) ;
            if ok
                app.RTD_feedStream = S ;
                app.RTD_StreamEditButton.Enable = 'on' ;
                if ~isempty(app.Pred_InputMethodDropdown) && ...
                        contains(app.Pred_InputMethodDropdown.Value, 'From Calculated')
                    app.Pred_syncFromRTDTab() ;
                end
            end
        end

        function RTD_editStream(app)
            if isempty(app.RTD_feedStream)
                uialert(app.UIFigure, 'No feed stream loaded to edit.', 'Nothing to Edit') ;
                return
            end
            defineStreamApp(app.RTD_feedStream, 'edit', app.RTD_StreamNameField.Value) ;
        end

        %% ============== TAB 2: PREDICTION MODELS ==============
        function createPredictionTab(app)

            app.PredTab = uitab(app.TabGroup, 'Title', 'Prediction Models') ;

            % Main grid: left panel (controls) + right panel (plots)
            mainGrid = uigridlayout(app.PredTab, [1 2]) ;
            mainGrid.ColumnWidth = {430, '1x'} ;

            % ---- LEFT PANEL ----
            leftPanel = uipanel(mainGrid, 'Title', 'Prediction Configuration') ;
            leftGrid = uigridlayout(leftPanel, [13 2]) ;
            rowH = repmat({28}, 1, 13) ; rowH{2} = 0 ; rowH{13} = 190 ;
            leftGrid.RowHeight = rowH ;
            leftGrid.ColumnWidth = {'1x', '1x'} ;
            leftGrid.Padding = [10 10 10 10] ;
            leftGrid.RowSpacing = 5 ;

            % Row 1: Input method
            lbl = uilabel(leftGrid, 'Text', 'Input:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 1 ; lbl.Layout.Column = 1 ;
            methodSubGrid = uigridlayout(leftGrid, [1 2], ...
                'ColumnWidth', {'1x', 28}, 'Padding', [0 0 0 0], 'ColumnSpacing', 2) ;
            methodSubGrid.Layout.Row = 1 ; methodSubGrid.Layout.Column = 2 ;
            app.Pred_InputMethodDropdown = uidropdown(methodSubGrid, ...
                'Items', {'Manual', 'From Calculated Data'}, ...
                'Value', 'Manual', ...
                'ValueChangedFcn', @(~,~) app.Pred_inputMethodChanged()) ;
            app.setTooltip('Choose whether Prediction uses manual inputs or reuses RTD data generated in Tab 1.', ...
                lbl, app.Pred_InputMethodDropdown) ;
            app.Pred_RefreshButton = uibutton(methodSubGrid, 'push', ...
                'Text', char(8635), 'FontSize', 12, ...
                'Tooltip', 'Refresh imported data from Tab 1 and Tab 2', ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.Pred_inputMethodChanged()) ;

            % Row 2: RTD status
            lbl = uilabel(leftGrid, 'Text', 'Current RTD:', ...
                'FontWeight', 'bold') ;
            lbl.Layout.Row = 2 ; lbl.Layout.Column = 1 ;
            lbl.Visible = 'off' ;
            app.Pred_RTDStatusLabel = uilabel(leftGrid, ...
                'Text', 'None (generate in Tab 1)', ...
                'FontColor', [0.8 0 0], ...
                'Interpreter', 'html') ;
            app.Pred_RTDStatusLabel.Layout.Row = 2 ;
            app.Pred_RTDStatusLabel.Layout.Column = 2 ;
            app.Pred_RTDStatusLabel.Visible = 'off' ;
            app.setTooltip('Shows which RTD is currently available for prediction calculations.', ...
                lbl, app.Pred_RTDStatusLabel) ;

            % Row 3: Reaction System header
            lbl = uilabel(leftGrid, 'Text', 'Reaction System:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 3 ; lbl.Layout.Column = [1 2] ;

            % Row 4: New RS + Edit RS buttons
            app.Pred_RSDefineButton = uibutton(leftGrid, 'push', ...
                'Text', 'New RS', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new Reaction System from scratch', ...
                'ButtonPushedFcn', @(~,~) defineReactionSysApp()) ;
            app.Pred_RSDefineButton.Layout.Row = 4 ;
            app.Pred_RSDefineButton.Layout.Column = 1 ;

            app.Pred_RSEditButton = uibutton(leftGrid, 'push', ...
                'Text', 'Edit RS', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded Reaction System', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.Pred_editRS()) ;
            app.Pred_RSEditButton.Layout.Row = 4 ;
            app.Pred_RSEditButton.Layout.Column = 2 ;

            % Row 5: RS name field + Load button
            app.Pred_RSNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'RS', ...
                'Tooltip', 'Name of the ReactionSys variable in the MATLAB workspace') ;
            app.Pred_RSNameField.Layout.Row = 5 ; app.Pred_RSNameField.Layout.Column = 1 ;
            app.Pred_RSLoadButton = uibutton(leftGrid, 'push', ...
                'Text', 'Load from Workspace', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the ReactionSys object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.Pred_loadRS()) ;
            app.Pred_RSLoadButton.Layout.Row = 5 ; app.Pred_RSLoadButton.Layout.Column = 2 ;

            % Row 6: RS status
            app.Pred_RSStatusLabel = uilabel(leftGrid, ...
                'Text', 'No Reaction System loaded', 'FontColor', [0.6 0 0]) ;
            app.Pred_RSStatusLabel.Layout.Row = 6 ;
            app.Pred_RSStatusLabel.Layout.Column = [1 2] ;
            app.Pred_RSStatusLabel.Tooltip = 'Shows whether a Reaction System is loaded for the prediction models.' ;

            % Row 7: Feed Stream header
            lbl = uilabel(leftGrid, 'Text', 'Feed Stream:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 7 ; lbl.Layout.Column = [1 2] ;

            % Row 8: New Stream + Edit Stream buttons
            app.Pred_StreamDefineButton = uibutton(leftGrid, 'push', ...
                'Text', 'New Stream', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new feed stream with defineStreamApp', ...
                'ButtonPushedFcn', @(~,~) defineStreamApp()) ;
            app.Pred_StreamDefineButton.Layout.Row = 8 ;
            app.Pred_StreamDefineButton.Layout.Column = 1 ;
            app.Pred_StreamEditButton = uibutton(leftGrid, 'push', ...
                'Text', 'Edit Stream', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded feed stream', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.Pred_editStream()) ;
            app.Pred_StreamEditButton.Layout.Row = 8 ;
            app.Pred_StreamEditButton.Layout.Column = 2 ;

            % Row 9: stream name + Load button
            app.Pred_StreamNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'feed', ...
                'Tooltip', 'Name of the feed Stream variable in the MATLAB workspace') ;
            app.Pred_StreamNameField.Layout.Row = 9 ; app.Pred_StreamNameField.Layout.Column = 1 ;
            app.Pred_StreamLoadButton = uibutton(leftGrid, 'push', ...
                'Text', 'Load from Workspace', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the feed Stream object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.Pred_loadStream()) ;
            app.Pred_StreamLoadButton.Layout.Row = 9 ; app.Pred_StreamLoadButton.Layout.Column = 2 ;

            % Row 10: Stream status
            app.Pred_StreamStatusLabel = uilabel(leftGrid, ...
                'Text', 'No feed stream loaded', 'FontColor', [0.6 0 0], ...
                'Interpreter', 'html') ;
            app.Pred_StreamStatusLabel.Layout.Row = 10 ;
            app.Pred_StreamStatusLabel.Layout.Column = [1 2] ;
            app.Pred_StreamStatusLabel.Tooltip = 'Shows whether a feed Stream is loaded for the prediction models.' ;

            % Row 11: Compute button
            app.Pred_ComputeButton = uibutton(leftGrid, 'push', ...
                'Text', 'Compute', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.3 0.6 0.9], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.Pred_compute()) ;
            app.Pred_ComputeButton.Layout.Row = 11 ;
            app.Pred_ComputeButton.Layout.Column = [1 2] ;
            app.Pred_ComputeButton.Tooltip = 'Run the four reference prediction models with the currently loaded RTD, chemistry and feed.' ;

            % Row 12: Display units title
            lbl = uilabel(leftGrid, 'Text', 'Display units:', ...
                'FontWeight', 'bold', 'FontSize', 13) ;
            lbl.Layout.Row = 12 ; lbl.Layout.Column = [1 2] ;

            % Row 13: Display units
            unitsGrid = uigridlayout(leftGrid, [1 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'RowHeight', {'1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4, ...
                'RowSpacing', 4) ;
            unitsGrid.Layout.Row = 13 ;
            unitsGrid.Layout.Column = [1 2] ;
            conversionPanel = uipanel(unitsGrid, 'Title', 'Conversion Comparison') ;
            conversionPanel.Layout.Row = 1 ;
            conversionPanel.Layout.Column = 1 ;
            conversionGrid = uigridlayout(conversionPanel, [1 1], ...
                'Padding', [6 6 6 6]) ;
            app.DisplayControls.Prediction.reactant = app.createDisplayMultiSelectControl( ...
                conversionGrid, 1, 1, 'Reactants:', @(~,~) app.refreshDisplayUnits('Prediction'), 120) ;

            concentrationPanel = uipanel(unitsGrid, 'Title', 'Outlet Concentration') ;
            concentrationPanel.Layout.Row = 1 ;
            concentrationPanel.Layout.Column = 2 ;
            concentrationGrid = uigridlayout(concentrationPanel, [2 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 6) ;
            app.DisplayControls.Prediction.concentration = app.createDisplayUnitControl( ...
                concentrationGrid, 1, 1, 'Concentration:', 'Concentration', 'mol/m^3', @(~,~) app.refreshDisplayUnits('Prediction'), 92) ;
            app.DisplayControls.Prediction.species = app.createDisplayMultiSelectControl( ...
                concentrationGrid, 2, 1, 'Species:', @(~,~) app.refreshDisplayUnits('Prediction'), 90) ;

            % ---- RIGHT PANEL (PLOTS) ----
            rightPanel = uipanel(mainGrid, 'Title', 'Model Results') ;
            rightGrid = uigridlayout(rightPanel, [2 2]) ;
            rightGrid.RowHeight = {'1x', '1x'} ;
            rightGrid.ColumnWidth = {'1.00x', '0.73x'} ;
            rightGrid.Padding = [0 0 0 0] ;
            rightGrid.RowSpacing = 6 ;
            rightGrid.ColumnSpacing = 6 ;

            plotPanel = uipanel(rightGrid, 'BorderType', 'none') ;
            plotPanel.Layout.Row = 1 ;
            plotPanel.Layout.Column = [1 2] ;
            plotLayout = tiledlayout(plotPanel, 1, 2, ...
                'Padding', 'compact', ...
                'TileSpacing', 'compact') ;

            % Conversion comparison bar chart (all models, per reactant)
            app.Pred_AxesXbatch = nexttile(plotLayout, 1) ;
            title(app.Pred_AxesXbatch, 'Conversion Comparison') ;
            xlabel(app.Pred_AxesXbatch, 'Reactant') ;
            ylabel(app.Pred_AxesXbatch, 'Conversion X (-)') ;
            grid(app.Pred_AxesXbatch, 'on') ;

            % Outlet concentration bar chart for all species
            app.Pred_AxesIntegrand = nexttile(plotLayout, 2) ;
            title(app.Pred_AxesIntegrand, 'Outlet Concentration') ;
            xlabel(app.Pred_AxesIntegrand, 'Species') ;
            ylabel(app.Pred_AxesIntegrand, 'C [mol/m^3]') ;
            grid(app.Pred_AxesIntegrand, 'on') ;

            % Exit summary table
            app.Pred_C_exitPanel = uipanel(rightGrid, ...
                'Title', 'Exit Summary - Concentration [mol/m^3]') ;
            app.Pred_C_exitPanel.Layout.Row = 2 ;
            app.Pred_C_exitPanel.Layout.Column = 1 ;
            app.Pred_C_exitPanel.Tooltip = ...
                ['Per-species summary of feed concentration, outlet concentration and functional-reactant conversion for each prediction model. ' ...
                'C_in denotes feed concentration and C_out denotes outlet concentration at the reactor exit.'] ;
            tableGrid = uigridlayout(app.Pred_C_exitPanel, [1 1], ...
                'Padding', [6 6 6 6]) ;
            app.Pred_C_exitLabel = uilabel(tableGrid, ...
                'Text', '', ...
                'Visible', 'off') ;
            app.Pred_C_exitTable = uitable(tableGrid, ...
                'ColumnName', {'Component', 'Role', 'C_in', 'Seg. C_out', 'MM C_out', 'CSTR C_out', 'PFR C_out', 'X_CSTR', 'X_seg', 'X_MM', 'X_PFR'}, ...
                'ColumnEditable', false(1, 11), ...
                'ColumnWidth', {88, 70, 68, 78, 78, 84, 84, 62, 62, 72, 72}, ...
                'RowName', {}) ;
            app.Pred_C_exitTable.Layout.Row = 1 ;
            app.Pred_C_exitTable.Tooltip = ...
                ['Functional reactants show concentration and conversion. Products and inerts show concentration only, and intermediates can also show conversion when they are consumed. ' ...
                'C_in denotes feed concentration and C_out denotes outlet concentration at the reactor exit.'] ;

            app.Pred_MixingEffectPanel = uipanel(rightGrid, ...
                'Title', 'Macromixing / Micromixing Map') ;
            app.Pred_MixingEffectPanel.Layout.Row = 2 ;
            app.Pred_MixingEffectPanel.Layout.Column = 2 ;
            app.Pred_MixingEffectPanel.Tooltip = '' ;
            app.Pred_MixingEffectPanel.BackgroundColor = [1 1 1] ;
            mixGrid = uigridlayout(app.Pred_MixingEffectPanel, [1 1], ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 6) ;
            mixGrid.BackgroundColor = [1 1 1] ;
            app.Pred_MixingEffectLabel = uilabel(mixGrid, ...
                'Text', 'Compute a case to populate this macromixing/micromixing map.', ...
                'WordWrap', 'on') ;
            app.Pred_MixingEffectLabel.HorizontalAlignment = 'center' ;
            app.Pred_MixingEffectLabel.VerticalAlignment = 'top' ;
            app.Pred_MixingEffectLabel.BackgroundColor = [1 1 1] ;
            app.Pred_MixingEffectLabel.Layout.Row = 1 ;
            app.Pred_MixingEffectLabel.Layout.Column = 1 ;
            app.Pred_MixingEffectAxes = uiaxes(mixGrid, ...
                'Visible', 'off') ;
            app.Pred_MixingEffectAxes.Color = [1 1 1] ;
            app.Pred_MixingEffectAxes.Layout.Row = 1 ;
            app.Pred_MixingEffectAxes.Layout.Column = 1 ;
        end

        %% ============== STREAM LOADING HELPER + CALLBACKS ==============

        function [S, ok] = loadStreamFromWorkspace(~, nameField, statusLabel, RS)
            ok = false ; S = [] ;
            streamName = nameField.Value ;
            try
                S = evalin('base', streamName) ;
                if ~isa(S, 'Stream')
                    error('Variable "%s" is not a Stream object.', streamName) ;
                end
                if ~isempty(RS) && length(S.concentration) ~= RS.nComponents
                    error('Stream has %d components but RS has %d. They must match.', ...
                        length(S.concentration), RS.nComponents) ;
                end
                C_str = sprintf('%.4g  ', S.concentration) ;
                statusLabel.Text = sprintf('Loaded C0 (internal SI): [%s] mol/m^3', strtrim(C_str)) ;
                statusLabel.FontColor = [0 0.5 0] ;
                ok = true ;
            catch ME
                statusLabel.Text = ME.message ;
                statusLabel.FontColor = [0.8 0 0] ;
            end
        end

        function Pred_loadStream(app)
            [S, ok] = app.loadStreamFromWorkspace( ...
                app.Pred_StreamNameField, app.Pred_StreamStatusLabel, app.Pred_RS) ;
            if ok
                app.Pred_feedStream = S ;
                app.Pred_StreamEditButton.Enable = 'on' ;
            end
        end

        function TIS_loadStream(app)
            [S, ok] = app.loadStreamFromWorkspace( ...
                app.TIS_StreamNameField, app.TIS_StreamStatusLabel, app.TIS_RS) ;
            if ok
                app.TIS_feedStream = S ;
                app.TIS_StreamEditButton.Enable = 'on' ;
            end
        end

        function Disp_loadStream(app)
            [S, ok] = app.loadStreamFromWorkspace( ...
                app.Disp_StreamNameField, app.Disp_StreamStatusLabel, app.Disp_RS) ;
            if ok
                app.Disp_feedStream = S ;
                app.Disp_StreamEditButton.Enable = 'on' ;
            end
        end

        function Pred_editStream(app)
            if isempty(app.Pred_feedStream)
                uialert(app.UIFigure, ...
                    'No feed stream loaded to edit.', 'Nothing to Edit') ;
                return
            end
            defineStreamApp(app.Pred_feedStream, 'edit', app.Pred_StreamNameField.Value) ;
        end

        function TIS_editStream(app)
            if isempty(app.TIS_feedStream)
                uialert(app.UIFigure, ...
                    'No feed stream loaded to edit.', 'Nothing to Edit') ;
                return
            end
            defineStreamApp(app.TIS_feedStream, 'edit', app.TIS_StreamNameField.Value) ;
        end

        function Disp_editStream(app)
            if isempty(app.Disp_feedStream)
                uialert(app.UIFigure, ...
                    'No feed stream loaded to edit.', 'Nothing to Edit') ;
                return
            end
            defineStreamApp(app.Disp_feedStream, 'edit', app.Disp_StreamNameField.Value) ;
        end

        %% ============== PREDICTION CALLBACKS ==============

        function Pred_inputMethodChanged(app)
            useCalculated = contains(app.Pred_InputMethodDropdown.Value, 'From Calculated') ;
            manualState = 'on' ;
            refreshState = 'off' ;
            if useCalculated
                manualState = 'off' ;
                refreshState = 'on' ;
            end

            app.Pred_RSDefineButton.Enable = manualState ;
            app.Pred_RSEditButton.Enable = 'off' ;
            app.Pred_RSNameField.Enable = manualState ;
            app.Pred_RSLoadButton.Enable = manualState ;
            app.Pred_StreamDefineButton.Enable = manualState ;
            app.Pred_StreamEditButton.Enable = 'off' ;
            app.Pred_StreamNameField.Enable = manualState ;
            app.Pred_StreamLoadButton.Enable = manualState ;
            app.Pred_RefreshButton.Visible = refreshState ;

            if useCalculated
                app.Pred_syncFromRTDTab() ;
            else
                if ~isempty(app.Pred_RS)
                    app.Pred_RSEditButton.Enable = 'on' ;
                end
                if ~isempty(app.Pred_feedStream)
                    app.Pred_StreamEditButton.Enable = 'on' ;
                end
                if isempty(app.rtd)
                    app.Pred_RTDStatusLabel.Text = 'None (generate in Tab 1)' ;
                    app.Pred_RTDStatusLabel.FontColor = [0.8 0 0] ;
                else
                    app.Pred_RTDStatusLabel.Text = app.htmlStatusTauSigma(app.RTD_SourceDropdown.Value, app.rtd.tau, app.rtd.sigma2) ;
                    app.Pred_RTDStatusLabel.FontColor = [0 0.5 0] ;
                end
            end
        end

        function Pred_syncFromRTDTab(app)
            infoLines = {} ;

            if ~isempty(app.rtd)
                infoLines{end+1} = app.htmlStatusTauSigma( ...
                    sprintf('RTD: %s', app.RTD_SourceDropdown.Value), ...
                    app.rtd.tau, app.rtd.sigma2) ;
            else
                infoLines{end+1} = 'RTD: not loaded' ;
            end

            if ~isempty(app.RTD_RS)
                app.Pred_RS = app.RTD_RS ;
                app.Pred_RSNameField.Value = app.RTD_RSNameField.Value ;
                app.Pred_RSStatusLabel.Text = sprintf('From Tab 1: %d reactions, %d components', ...
                    app.RTD_RS.nReactions, app.RTD_RS.nComponents) ;
                app.Pred_RSStatusLabel.FontColor = [0 0.5 0] ;
                infoLines{end+1} = sprintf('RS: %s', app.RTD_RSNameField.Value) ;
            else
                app.Pred_RS = [] ;
                app.Pred_RSStatusLabel.Text = 'Tab 1 has no Reaction System loaded' ;
                app.Pred_RSStatusLabel.FontColor = [0.8 0 0] ;
                infoLines{end+1} = 'RS: not loaded' ;
            end

            if ~isempty(app.RTD_feedStream)
                app.Pred_feedStream = app.RTD_feedStream ;
                app.Pred_StreamNameField.Value = app.RTD_StreamNameField.Value ;
                C_str = sprintf('%.4g  ', app.RTD_feedStream.concentration) ;
                app.Pred_StreamStatusLabel.Text = sprintf('(from Tab 1, internal SI) [%s] mol/m<sup>3</sup>', strtrim(C_str)) ;
                app.Pred_StreamStatusLabel.FontColor = [0 0.5 0] ;
                infoLines{end+1} = sprintf('Stream: %s', app.RTD_StreamNameField.Value) ;
            else
                app.Pred_feedStream = [] ;
                app.Pred_StreamStatusLabel.Text = 'Tab 1 has no feed stream loaded' ;
                app.Pred_StreamStatusLabel.FontColor = [0.8 0 0] ;
                infoLines{end+1} = 'Stream: not loaded' ;
            end

            if any(contains(infoLines, 'not loaded'))
                app.Pred_RTDStatusLabel.FontColor = [0.8 0 0] ;
            else
                app.Pred_RTDStatusLabel.FontColor = [0 0.5 0] ;
            end
                app.Pred_RTDStatusLabel.Text = strjoin(infoLines, ' | ') ;
        end

        function Pred_loadRS(app)
            % Load a ReactionSys object from the MATLAB workspace by name
            rsName = app.Pred_RSNameField.Value ;
            try
                RS = evalin('base', rsName) ;
                if ~isa(RS, 'ReactionSys')
                    error('Variable "%s" is not a ReactionSys object.', rsName) ;
                end
                app.Pred_RS = RS ;
                nR = RS.nReactions ;
                nC = RS.nComponents ;
                app.Pred_RSStatusLabel.Text = sprintf('Loaded: %d reactions, %d components', nR, nC) ;
                app.Pred_RSStatusLabel.FontColor = [0 0.5 0] ;
                app.Pred_RSEditButton.Enable = 'on' ;
            catch ME
                app.Pred_RSStatusLabel.Text = ME.message ;
                app.Pred_RSStatusLabel.FontColor = [0.8 0 0] ;
            end
        end

        function Pred_editRS(app)
            % Open defineReactionSysApp pre-loaded with the current RS
            if isempty(app.Pred_RS)
                uialert(app.UIFigure, ...
                    'No Reaction System loaded to edit.', 'Nothing to Edit') ;
                return
            end
            rsName = app.Pred_RSNameField.Value ;
            defineReactionSysApp(app.Pred_RS, rsName) ;
        end

        function Pred_compute(app)
            % Compute segregation and max mixedness predictions/bounds
            % using the loaded ReactionSys object.

            try
                app.updateStatus('Computing conversion bounds...') ;

                if contains(app.Pred_InputMethodDropdown.Value, 'From Calculated')
                    app.Pred_syncFromRTDTab() ;
                end

                % Check RTD is available
                if isempty(app.rtd)
                    uialert(app.UIFigure, ...
                        'No RTD available. Go to Tab 1 and generate an RTD first.', ...
                        'RTD Required') ;
                    app.updateStatus('Ready') ;
                    return
                end

                % Validate that a ReactionSys is loaded
                if isempty(app.Pred_RS)
                    uialert(app.UIFigure, ...
                        'No Reaction System loaded. Use "Define Reaction System" to create one, then "Load from Workspace" to import it.', ...
                        'Missing Reaction System') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                % Validate feed stream
                if isempty(app.Pred_feedStream)
                    uialert(app.UIFigure, ...
                        'No feed stream loaded. Define a Stream with "New Stream" and load it.', ...
                        'Missing Feed Stream') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                RS = app.Pred_RS ;
                C0 = app.Pred_feedStream.concentration(:)' ;

                if length(C0) ~= RS.nComponents
                    uialert(app.UIFigure, ...
                        sprintf('Feed stream has %d components but RS has %d. They must match.', ...
                        length(C0), RS.nComponents), 'Component Mismatch') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                % Create model objects with RTD
                app.seg_model = SegregationModel ;
                app.seg_model.rtd = app.rtd ;

                app.mm_model = MaxMixednessModel ;
                app.mm_model.rtd = app.rtd ;

                % Compute using the general isothermal methods
                app.seg_model = app.seg_model.compute_isothermal(RS, C0) ;
                app.mm_model = app.mm_model.compute_isothermal(RS, C0) ;

                % Update plots
                app.Pred_updatePlots() ;

                % Update RTD status label
                app.Pred_RTDStatusLabel.Text = sprintf('&tau;=%.2f, &sigma;<sup>2</sup>=%.2f', ...
                    app.rtd.tau, app.rtd.sigma2) ;
                app.Pred_RTDStatusLabel.FontColor = [0 0.5 0] ;

                app.updateStatus('Ready') ;

            catch ME
                app.updateStatus('Error') ;
                uialert(app.UIFigure, ME.message, 'Computation Error') ;
            end
        end

        function Pred_updatePlots(app)
            % Update all prediction model plots

            if isempty(app.seg_model) || isempty(app.mm_model)
                return
            end

            concDD = app.DisplayControls.Prediction.concentration ;
            RS = app.Pred_RS ;
            C0 = app.Pred_feedStream.concentration(:)' ;
            reactantInfo = app.getPredictionReactantInfo(RS, C0) ;
            speciesInfo = app.getPredictionSpeciesInfo(RS) ;
            speciesRoles = app.classifySpeciesRoles(RS) ;
            app.ensurePredictionReactantSelector(app.DisplayControls.Prediction.reactant, reactantInfo) ;
            selectedIdx = app.getPredictionSelectedReactants( ...
                app.DisplayControls.Prediction.reactant, reactantInfo) ;
            app.ensurePredictionSpeciesSelector(app.DisplayControls.Prediction.species, speciesInfo) ;
            selectedSpeciesIdx = app.getPredictionSelectedSpecies( ...
                app.DisplayControls.Prediction.species, speciesInfo) ;
            [C_out_cstr_ref, ~] = TanksInSeries.solve_sequential(1, RS, C0, app.rtd.tau) ;
            [C_out_pfr_ref, ~] = TanksInSeries.solve_PFR(RS, C0, app.rtd.tau) ;

            % Compute conversions for all reactants up front
            X_seg_all  = app.computeSpeciesConversion(C0, app.seg_model.C_exit, reactantInfo.reactantIndices) ;
            X_mm_all   = app.computeSpeciesConversion(C0, app.mm_model.C_exit,  reactantInfo.reactantIndices) ;
            X_cstr_all = app.computeSpeciesConversion(C0, C_out_cstr_ref,       reactantInfo.reactantIndices) ;
            X_pfr_all  = app.computeSpeciesConversion(C0, C_out_pfr_ref,        reactantInfo.reactantIndices) ;
            X_seg_cstr_all = app.computePredictionSegregatedCSTRConversions( ...
                RS, C0, reactantInfo.reactantIndices) ;

            % Update exit summary panel header
            app.updateConcentrationHeader(app.Pred_C_exitLabel, concDD) ;
            app.Pred_C_exitPanel.Title = sprintf('Exit Summary - Concentration [%s]', ...
                app.concentrationUnitName(concDD)) ;

            % --- PLOT 1: Conversion comparison (grouped bars, selected reactants) ---
            cla(app.Pred_AxesXbatch) ;
            nR = numel(reactantInfo.reactantIndices) ;
            if nR == 0
                text(app.Pred_AxesXbatch, 0.5, 0.5, 'No functional reactants with C_0 > 0', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
            elseif isempty(selectedIdx)
                text(app.Pred_AxesXbatch, 0.5, 0.5, 'No functional reactants selected', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
            else
                reactantPlotPos = arrayfun(@(idx) find(reactantInfo.reactantIndices == idx, 1), selectedIdx) ;
                X_matrix = [X_cstr_all(reactantPlotPos)', X_seg_all(reactantPlotPos)', ...
                            X_mm_all(reactantPlotPos)', X_pfr_all(reactantPlotPos)'] ;
                reactantLabels = reactantInfo.componentLabels(selectedIdx) ;
                nSelectedReactants = numel(selectedIdx) ;
                b = bar(app.Pred_AxesXbatch, 1:nSelectedReactants, X_matrix, 'grouped') ;
                app.applyPredictionBarStyles(b) ;
                app.Pred_AxesXbatch.XTick = 1:nSelectedReactants ;
                app.Pred_AxesXbatch.XTickLabel = reactantLabels ;
                app.setPredictionAnnotatedYLimits(app.Pred_AxesXbatch, X_matrix, 1) ;
                app.annotatePredictionBars(app.Pred_AxesXbatch, b, X_matrix, '%.4f') ;
            end
            title(app.Pred_AxesXbatch, 'Conversion Comparison') ;
            xlabel(app.Pred_AxesXbatch, 'Reactant') ;
            ylabel(app.Pred_AxesXbatch, 'Conversion X (-)') ;
            grid(app.Pred_AxesXbatch, 'on') ;

            % --- PLOT 2: Outlet concentration for selected species ---
            cla(app.Pred_AxesIntegrand) ;
            if isempty(selectedSpeciesIdx)
                text(app.Pred_AxesIntegrand, 0.5, 0.5, 'No species selected', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
            else
                concMatrix = [C_out_cstr_ref(:), app.seg_model.C_exit(:), ...
                              app.mm_model.C_exit(:), C_out_pfr_ref(:)] ;  % nComp x 4
                concDisplay = reshape(app.convertOutputConcentration(concMatrix(:)', concDD), size(concMatrix)) ;
                C_species = concDisplay(selectedSpeciesIdx, :) ;
                speciesLabels = speciesInfo.componentLabels(selectedSpeciesIdx) ;
                nSelectedSpecies = numel(selectedSpeciesIdx) ;
                b = bar(app.Pred_AxesIntegrand, 1:nSelectedSpecies, C_species, 'grouped') ;
                app.applyPredictionBarStyles(b) ;
                app.Pred_AxesIntegrand.XTick = 1:nSelectedSpecies ;
                app.Pred_AxesIntegrand.XTickLabel = speciesLabels ;
                app.setPredictionAnnotatedYLimits(app.Pred_AxesIntegrand, C_species) ;
                app.annotatePredictionBars(app.Pred_AxesIntegrand, b, C_species, '%.4g') ;
            end
            legendHandles = app.createPredictionLegendPlaceholders(app.Pred_AxesXbatch) ;
            app.updatePredictionSharedLegend(legendHandles) ;
            title(app.Pred_AxesIntegrand, 'Outlet Concentration') ;
            xlabel(app.Pred_AxesIntegrand, 'Species') ;
            ylabel(app.Pred_AxesIntegrand, app.axisLabelWithUnit('C', concDD)) ;
            grid(app.Pred_AxesIntegrand, 'on') ;

            % --- Update Exit Summary table ---
            app.updatePredictionSummaryTable( ...
                reactantInfo.componentLabels, speciesRoles, C0, ...
                app.seg_model.C_exit, app.mm_model.C_exit, C_out_cstr_ref, C_out_pfr_ref, ...
                reactantInfo.reactantIndices, X_seg_all, X_mm_all, X_cstr_all, X_pfr_all, ...
                selectedIdx, concDD) ;
            app.updatePredictionMixingEffectPanel( ...
                reactantInfo, selectedIdx, X_seg_all, X_mm_all, X_cstr_all, X_pfr_all, X_seg_cstr_all) ;
        end

        %% ============== TAB 3: TANKS-IN-SERIES ==============
        function createTISTab(app)

            app.TISTab = uitab(app.TabGroup, 'Title', 'Tanks-in-Series') ;

            % Main grid: left panel (controls) + right panel (plots)
            mainGrid = uigridlayout(app.TISTab, [1 2]) ;
            mainGrid.ColumnWidth = {430, '1x'} ;

            % ---- LEFT PANEL ----
            leftPanel = uipanel(mainGrid, 'Title', 'TIS Configuration') ;
            leftGrid = uigridlayout(leftPanel, [15 2]) ;
            rowH = repmat({28}, 1, 15) ; rowH{3} = 0 ; rowH{15} = 260 ;
            leftGrid.RowHeight = rowH ;
            leftGrid.ColumnWidth = {'1x', '1x'} ;
            leftGrid.Padding = [10 10 10 10] ;
            leftGrid.RowSpacing = 5 ;

            % Row 1: N method
            lbl = uilabel(leftGrid, 'Text', 'N Method:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 1 ; lbl.Layout.Column = 1 ;
            methodSubGrid = uigridlayout(leftGrid, [1 2], ...
                'ColumnWidth', {'1x', 28}, 'Padding', [0 0 0 0], 'ColumnSpacing', 2) ;
            methodSubGrid.Layout.Row = 1 ; methodSubGrid.Layout.Column = 2 ;
            app.TIS_NMethodDropdown = uidropdown(methodSubGrid, ...
                'Items', {'Manual', 'From Calculated Data'}, ...
                'Value', 'Manual', ...
                'ValueChangedFcn', @(~,~) app.TIS_NMethodChanged()) ;
            app.setTooltip('Choose whether N and tau are entered manually or inferred from previously calculated data.', ...
                lbl, app.TIS_NMethodDropdown) ;
            app.TIS_RefreshButton = uibutton(methodSubGrid, 'push', ...
                'Text', char(8635), 'FontSize', 12, ...
                'Tooltip', 'Refresh imported data from Tab 1 and Tab 2', ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.TIS_NMethodChanged()) ;

            % Row 2: N tanks
            app.TIS_NLabel = uilabel(leftGrid, 'Text', '$N$ [tanks]:', 'Interpreter', 'latex') ;
            app.TIS_NLabel.Layout.Row = 2 ; app.TIS_NLabel.Layout.Column = 1 ;
            app.TIS_NField = uieditfield(leftGrid, 'numeric', ...
                'Value', 3, 'Limits', [0.1 Inf], ...
                'Tooltip', 'Number of tanks in series. N=1: CSTR, N→∞: PFR. Can be non-integer for RTD.') ;
            app.TIS_NField.Layout.Row = 2 ; app.TIS_NField.Layout.Column = 2 ;

            % Row 3: RTD status (shown when "From RTD")
            app.TIS_RTDStatusLabel = uilabel(leftGrid, ...
                'Text', 'RTD: not loaded', 'FontColor', [0.6 0 0], ...
                'Interpreter', 'html') ;
            app.TIS_RTDStatusLabel.Layout.Row = 3 ;
            app.TIS_RTDStatusLabel.Layout.Column = [1 2] ;
            app.TIS_RTDStatusLabel.Tooltip = 'Shows the RTD source currently imported into the tanks-in-series model.' ;
            app.TIS_RTDStatusLabel.Visible = 'off' ;

            % Row 4: tau
            app.TIS_tauLabel = uilabel(leftGrid, 'Text', '$\tau_{\mathrm{total}}$:', 'Interpreter', 'latex') ;
            app.TIS_tauLabel.Layout.Row = 4 ; app.TIS_tauLabel.Layout.Column = 1 ;
            [app.TIS_tauField, ~] = app.createNumericWithConv( ...
                leftGrid, 4, 2, 10, 'Time', ...
                'Limits', [0.001 Inf], ...
                'Tooltip', 'Total mean residence time: tau = V_total / Q.') ;
            app.setTooltip('Total mean residence time assigned to the equivalent tanks-in-series reactor.', ...
                app.TIS_tauLabel, app.TIS_tauField) ;

            % Row 5: Reaction System header
            lbl = uilabel(leftGrid, 'Text', 'Reaction System:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 5 ; lbl.Layout.Column = [1 2] ;

            % Row 6: Define RS button + Edit RS button
            app.TIS_RSDefineButton = uibutton(leftGrid, 'push', ...
                'Text', 'New RS', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new Reaction System from scratch', ...
                'ButtonPushedFcn', @(~,~) defineReactionSysApp()) ;
            app.TIS_RSDefineButton.Layout.Row = 6 ;
            app.TIS_RSDefineButton.Layout.Column = 1 ;

            app.TIS_RSEditButton = uibutton(leftGrid, 'push', ...
                'Text', 'Edit RS', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded Reaction System', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.TIS_editRS()) ;
            app.TIS_RSEditButton.Layout.Row = 6 ;
            app.TIS_RSEditButton.Layout.Column = 2 ;

            % Row 7: RS name field + Load button
            app.TIS_RSNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'RS', ...
                'Tooltip', 'Name of the ReactionSys variable in the MATLAB workspace') ;
            app.TIS_RSNameField.Layout.Row = 7 ; app.TIS_RSNameField.Layout.Column = 1 ;
            app.TIS_RSLoadButton = uibutton(leftGrid, 'push', ...
                'Text', 'Load from Workspace', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the ReactionSys object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.TIS_loadRS()) ;
            app.TIS_RSLoadButton.Layout.Row = 7 ; app.TIS_RSLoadButton.Layout.Column = 2 ;

            % Row 8: RS status
            app.TIS_RSStatusLabel = uilabel(leftGrid, ...
                'Text', 'No Reaction System loaded', 'FontColor', [0.6 0 0]) ;
            app.TIS_RSStatusLabel.Layout.Row = 8 ;
            app.TIS_RSStatusLabel.Layout.Column = [1 2] ;
            app.TIS_RSStatusLabel.Tooltip = 'Shows whether a Reaction System is loaded for the tanks-in-series calculation.' ;

            % Row 9: Feed Stream header
            lbl = uilabel(leftGrid, 'Text', 'Feed Stream:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 9 ; lbl.Layout.Column = [1 2] ;

            % Row 10: New Stream + Edit Stream buttons
            app.TIS_StreamDefineButton = uibutton(leftGrid, 'push', ...
                'Text', 'New Stream', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new feed stream with defineStreamApp', ...
                'ButtonPushedFcn', @(~,~) defineStreamApp()) ;
            app.TIS_StreamDefineButton.Layout.Row = 10 ;
            app.TIS_StreamDefineButton.Layout.Column = 1 ;
            app.TIS_StreamEditButton = uibutton(leftGrid, 'push', ...
                'Text', 'Edit Stream', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded feed stream', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.TIS_editStream()) ;
            app.TIS_StreamEditButton.Layout.Row = 10 ;
            app.TIS_StreamEditButton.Layout.Column = 2 ;

            % Row 11: stream name + Load button
            app.TIS_StreamNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'feed', ...
                'Tooltip', 'Name of the feed Stream variable in the MATLAB workspace') ;
            app.TIS_StreamNameField.Layout.Row = 11 ; app.TIS_StreamNameField.Layout.Column = 1 ;
            app.TIS_StreamLoadButton = uibutton(leftGrid, 'push', ...
                'Text', 'Load from Workspace', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the feed Stream object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.TIS_loadStream()) ;
            app.TIS_StreamLoadButton.Layout.Row = 11 ; app.TIS_StreamLoadButton.Layout.Column = 2 ;

            % Row 12: Stream status
            app.TIS_StreamStatusLabel = uilabel(leftGrid, ...
                'Text', 'No feed stream loaded', 'FontColor', [0.6 0 0], ...
                'Interpreter', 'html') ;
            app.TIS_StreamStatusLabel.Layout.Row = 12 ;
            app.TIS_StreamStatusLabel.Layout.Column = [1 2] ;
            app.TIS_StreamStatusLabel.Tooltip = 'Shows whether a feed Stream is loaded for the tanks-in-series calculation.' ;

            % Row 13: Compute button
            app.TIS_ComputeButton = uibutton(leftGrid, 'push', ...
                'Text', 'Compute', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.3 0.6 0.9], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.TIS_compute()) ;
            app.TIS_ComputeButton.Layout.Row = 13 ;
            app.TIS_ComputeButton.Layout.Column = [1 2] ;
            app.TIS_ComputeButton.Tooltip = 'Compute the tanks-in-series reactor and compare it with ideal CSTR and PFR references.' ;

            % Row 14: Display units title
            lbl = uilabel(leftGrid, 'Text', 'Display units:', ...
                'FontWeight', 'bold', 'FontSize', 13) ;
            lbl.Layout.Row = 14 ; lbl.Layout.Column = [1 2] ;

            % Row 15: Display units
            unitsGrid = uigridlayout(leftGrid, [2 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4, ...
                'RowSpacing', 4) ;
            unitsGrid.Layout.Row = 15 ;
            unitsGrid.Layout.Column = [1 2] ;

            rtdPanel = uipanel(unitsGrid, 'Title', 'E(t) Plot') ;
            rtdPanel.Layout.Row = 1 ;
            rtdPanel.Layout.Column = [1 2] ;
            rtdGrid = uigridlayout(rtdPanel, [1 1], ...
                'Padding', [6 6 6 6]) ;
            app.DisplayControls.TIS.time = app.createDisplayUnitControl( ...
                rtdGrid, 1, 1, 'Time base:', 'Time', 's', @(~,~) app.refreshDisplayUnits('TIS'), 84) ;

            concPanel = uipanel(unitsGrid, 'Title', 'Outlet Concentration vs N') ;
            concPanel.Layout.Row = 2 ;
            concPanel.Layout.Column = 1 ;
            concGrid = uigridlayout(concPanel, [2 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 6) ;
            app.DisplayControls.TIS.concentration = app.createDisplayUnitControl( ...
                concGrid, 1, 1, 'Concentration:', 'Concentration', 'mol/m^3', @(~,~) app.refreshDisplayUnits('TIS'), 92) ;
            app.DisplayControls.TIS.component = app.createDisplayMultiSelectControl( ...
                concGrid, 2, 1, 'Species:', @(~,~) app.refreshDisplayUnits('TIS'), '1x') ;

            convPanel = uipanel(unitsGrid, 'Title', 'Conversion vs N') ;
            convPanel.Layout.Row = 2 ;
            convPanel.Layout.Column = 2 ;
            convGrid = uigridlayout(convPanel, [2 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 6) ;
            app.DisplayControls.TIS.reactant = app.createDisplayMultiSelectControl( ...
                convGrid, 2, 1, 'Reactants:', @(~,~) app.refreshDisplayUnits('TIS'), '1x') ;

            % ---- RIGHT PANEL (PLOTS) ----
            rightPanel = uipanel(mainGrid, 'Title', 'TIS Results') ;
            rightGrid = uigridlayout(rightPanel, [2 2]) ;
            rightGrid.RowHeight = {'1x', '1x'} ;
            rightGrid.ColumnWidth = {'1x', '1x'} ;
            rightGrid.Padding = [0 0 0 0] ;
            rightGrid.RowSpacing = 6 ;
            rightGrid.ColumnSpacing = 6 ;

            % Outlet concentration vs N plot
            app.TIS_AxesXvsN = uiaxes(rightGrid) ;
            app.TIS_AxesXvsN.Layout.Row = 1 ;
            app.TIS_AxesXvsN.Layout.Column = 1 ;
            title(app.TIS_AxesXvsN, 'Outlet Concentration vs N') ;
            xlabel(app.TIS_AxesXvsN, 'N [number of tanks]') ;
            ylabel(app.TIS_AxesXvsN, 'C [mol/m^3]') ;
            grid(app.TIS_AxesXvsN, 'on') ;

            % Conversion vs N plot
            app.TIS_AxesComparison = uiaxes(rightGrid) ;
            app.TIS_AxesComparison.Layout.Row = 1 ;
            app.TIS_AxesComparison.Layout.Column = 2 ;
            title(app.TIS_AxesComparison, 'Conversion vs N') ;
            xlabel(app.TIS_AxesComparison, 'N [number of tanks]') ;
            ylabel(app.TIS_AxesComparison, 'Conversion X') ;
            grid(app.TIS_AxesComparison, 'on') ;

            % Exit summary table
            app.TIS_C_exitPanel = uipanel(rightGrid, ...
                'Title', 'Exit Summary - Concentration [mol/m^3]') ;
            app.TIS_C_exitPanel.Layout.Row = 2 ;
            app.TIS_C_exitPanel.Layout.Column = 1 ;
            app.TIS_C_exitPanel.Tooltip = ...
                ['Per-species summary of feed concentration, outlet concentration and functional-reactant conversion for TIS and its CSTR/PFR references. ' ...
                'C_in denotes feed concentration and C_out denotes outlet concentration at the reactor exit.'] ;
            tableGrid = uigridlayout(app.TIS_C_exitPanel, [1 1], ...
                'Padding', [6 6 6 6]) ;
            app.TIS_C_exitLabel = uilabel(tableGrid, ...
                'Text', '', ...
                'Visible', 'off') ;
            app.TIS_C_exitTable = uitable(tableGrid, ...
                'ColumnName', {'Component', 'Role', 'C_in', 'TIS C_out', 'CSTR C_out', 'PFR C_out', 'X_TIS', 'X_CSTR', 'X_PFR'}, ...
                'ColumnEditable', false(1, 9), ...
                'ColumnWidth', {86, 72, 68, 82, 84, 84, 64, 74, 74}, ...
                'RowName', {}) ;
            app.TIS_C_exitTable.Layout.Row = 1 ;
            app.TIS_C_exitTable.Tooltip = ...
                ['Functional reactants show concentration and conversion. Products and inerts show concentration only, and intermediates can also show conversion when they are consumed. ' ...
                'C_in denotes feed concentration and C_out denotes outlet concentration at the reactor exit.'] ;

            % E(t) plot for TIS model
            app.TIS_AxesEt = uiaxes(rightGrid) ;
            app.TIS_AxesEt.Layout.Row = 2 ;
            app.TIS_AxesEt.Layout.Column = 2 ;
            title(app.TIS_AxesEt, 'E(t) - TIS Model') ;
            xlabel(app.TIS_AxesEt, 't [s]') ;
            ylabel(app.TIS_AxesEt, 'E(t) [1/s]') ;
            grid(app.TIS_AxesEt, 'on') ;
        end

        %% ============== TIS CALLBACKS ==============

        function TIS_NMethodChanged(app)
            source = app.TIS_NMethodDropdown.Value ;
            if contains(source, 'From Calculated')
                % Auto-compute N from RTD variance
                app.TIS_NField.Enable = 'off' ;
                app.TIS_tauField.Enable = 'off' ;
                app.TIS_RTDStatusLabel.Visible = 'off' ;
                app.TIS_RefreshButton.Visible = 'on' ;
                infoLines = {} ;

                if ~isempty(app.rtd) && app.rtd.sigma2 > 0
                    N_from_rtd = app.rtd.tau^2 / app.rtd.sigma2 ;
                    app.TIS_NField.Value = N_from_rtd ;
                    app.setInputFieldValue(app.TIS_tauField, app.rtd.tau) ;
                    infoLines{end+1} = app.htmlStatusTauN('RTD: ', app.rtd.tau, N_from_rtd) ;
                else
                    infoLines{end+1} = 'RTD: not loaded' ;
                end

                % Import RS from Prediction Models tab (if loaded)
                if ~isempty(app.Pred_RS)
                    app.TIS_RS = app.Pred_RS ;
                    app.TIS_RSNameField.Value = app.Pred_RSNameField.Value ;
                    nR = app.Pred_RS.nReactions ;
                    nC = app.Pred_RS.nComponents ;
                    app.TIS_RSStatusLabel.Text = sprintf('Loaded: %d reactions, %d components', nR, nC) ;
                    app.TIS_RSStatusLabel.FontColor = [0 0.5 0] ;
                    app.TIS_RSEditButton.Enable = 'on' ;
                    infoLines{end+1} = sprintf('RS: %s', app.Pred_RSNameField.Value) ;
                else
                    infoLines{end+1} = 'RS: not loaded' ;
                end

                % Import feed Stream from Prediction Models tab
                if ~isempty(app.Pred_feedStream)
                    app.TIS_feedStream = app.Pred_feedStream ;
                    app.TIS_StreamNameField.Value = app.Pred_StreamNameField.Value ;
                    app.TIS_StreamEditButton.Enable = 'on' ;
                    C_str = sprintf('%.4g  ', app.Pred_feedStream.concentration) ;
                    app.TIS_StreamStatusLabel.Text = sprintf('(from Prediction, internal SI) [%s] mol/m<sup>3</sup>', strtrim(C_str)) ;
                    app.TIS_StreamStatusLabel.FontColor = [0 0.5 0] ;
                    infoLines{end+1} = 'Stream: from Prediction' ;
                else
                    infoLines{end+1} = 'Stream: not loaded' ;
                end

                if any(contains(infoLines, 'not loaded'))
                    app.TIS_RTDStatusLabel.FontColor = [0.8 0 0] ;
                else
                    app.TIS_RTDStatusLabel.FontColor = [0 0.5 0] ;
                end
                app.TIS_RTDStatusLabel.Text = strjoin(infoLines, ' | ') ;
            else
                app.TIS_NField.Enable = 'on' ;
                app.TIS_tauField.Enable = 'on' ;
                app.TIS_RTDStatusLabel.Visible = 'off' ;
                app.TIS_RefreshButton.Visible = 'off' ;
            end
        end

        function TIS_loadRS(app)
            % Load a ReactionSys object from the MATLAB workspace by name
            rsName = app.TIS_RSNameField.Value ;
            try
                RS = evalin('base', rsName) ;
                if ~isa(RS, 'ReactionSys')
                    error('Variable "%s" is not a ReactionSys object.', rsName) ;
                end
                app.TIS_RS = RS ;
                nR = RS.nReactions ;
                nC = RS.nComponents ;
                app.TIS_RSStatusLabel.Text = sprintf('Loaded: %d reactions, %d components', nR, nC) ;
                app.TIS_RSStatusLabel.FontColor = [0 0.5 0] ;
                app.TIS_RSEditButton.Enable = 'on' ;
            catch ME
                app.TIS_RSStatusLabel.Text = ME.message ;
                app.TIS_RSStatusLabel.FontColor = [0.8 0 0] ;
            end
        end

        function TIS_editRS(app)
            % Open defineReactionSysApp pre-loaded with the current RS
            if isempty(app.TIS_RS)
                uialert(app.UIFigure, ...
                    'No Reaction System loaded to edit.', 'Nothing to Edit') ;
                return
            end
            rsName = app.TIS_RSNameField.Value ;
            defineReactionSysApp(app.TIS_RS, rsName) ;
        end

        function TIS_compute(app)
            try
                app.updateStatus('Computing TIS model...') ;

                % Validate that a ReactionSys is loaded
                if isempty(app.TIS_RS)
                    uialert(app.UIFigure, ...
                        'No Reaction System loaded. Use "Define Reaction System" to create one, then "Load from Workspace" to import it.', ...
                        'Missing Reaction System') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                % Validate feed stream
                if isempty(app.TIS_feedStream)
                    uialert(app.UIFigure, ...
                        'No feed stream loaded. Define a Stream with "New Stream" and load it.', ...
                        'Missing Feed Stream') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                N_val = app.TIS_NField.Value ;
                tau_val = app.readInputField(app.TIS_tauField) ;
                RS = app.TIS_RS ;
                C0 = app.TIS_feedStream.concentration(:)' ;

                if length(C0) ~= RS.nComponents
                    uialert(app.UIFigure, ...
                        sprintf('Feed stream has %d components but RS has %d. They must match.', ...
                        length(C0), RS.nComponents), 'Component Mismatch') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                % --- Compute X_TIS for selected N ---
                [C_out_tis,  X_tis]  = TanksInSeries.solve_sequential(N_val, RS, C0, tau_val) ;

                % --- Reference: CSTR (N=1) ---
                [C_out_cstr, X_cstr] = TanksInSeries.solve_sequential(1, RS, C0, tau_val) ;

                % --- Reference: PFR (N→inf) ---
                [C_out_pfr,  X_pfr]  = TanksInSeries.solve_PFR(RS, C0, tau_val) ;

                app.DisplayCache.TIS = struct( ...
                    'N_val', N_val, ...
                    'tau_val', tau_val, ...
                    'RS', RS, ...
                    'C0', C0, ...
                    'X_tis', X_tis, ...
                    'X_cstr', X_cstr, ...
                    'X_pfr', X_pfr, ...
                    'C_out_tis', C_out_tis, ...
                    'C_out_cstr', C_out_cstr, ...
                    'C_out_pfr', C_out_pfr) ;

                % --- Update plots ---
                app.TIS_updatePlots(N_val, tau_val, RS, C0, ...
                    X_tis, X_cstr, X_pfr, ...
                    C_out_tis, C_out_cstr, C_out_pfr) ;

                app.updateStatus('Ready') ;

            catch ME
                app.updateStatus('Error') ;
                uialert(app.UIFigure, ME.message, 'TIS Computation Error') ;
            end
        end

        function TIS_updatePlots(app, N_val, tau_val, RS, C0, ...
                                 ~, ~, ~, ...
                                 C_out_tis, C_out_cstr, C_out_pfr)

            % ---- Plot 1: E(t) for current N ----
            app.TIS_clearMomentOverlay() ;
            cla(app.TIS_AxesEt) ;
            rtd_tis = RTD.tanks_in_series(N_val, tau_val) ;
            timeDD = app.DisplayControls.TIS.time ;
            concDD = app.DisplayControls.TIS.concentration ;
            t_display = app.convertOutputVectorFromTime('time', rtd_tis.t, timeDD) ;
            Et_display = app.convertOutputVectorFromTime('timeInverse', rtd_tis.Et, timeDD) ;
            hold(app.TIS_AxesEt, 'on') ;
            [app.TIS_EtSigmaBandHandle, tauOverlay, lowerOverlay, upperOverlay, sigmaOverlay] = ...
                app.RTD_drawEtMomentOverlay(app.TIS_AxesEt, rtd_tis, t_display, Et_display, timeDD, [0.64 0.80 1.00]) ;
            plot(app.TIS_AxesEt, t_display, Et_display, 'b-', 'LineWidth', 1.5) ;
            app.RTD_expandMomentAxesY(app.TIS_AxesEt, Et_display) ;
            [app.TIS_EtSigmaCenterHandle, app.TIS_EtSigmaLowerHandle, app.TIS_EtSigmaUpperHandle, app.TIS_EtSigmaLabelHandles] = ...
                app.RTD_drawMomentGuideLines(app.TIS_AxesEt, t_display, Et_display, tauOverlay, lowerOverlay, upperOverlay, sigmaOverlay, [0.00 0.20 0.75], 1e-12, ...
                {'\tau', '\tau-\sigma', '\tau+\sigma'}) ;
            title(app.TIS_AxesEt, sprintf('E(t) - TIS  N=%.1f', N_val)) ;
            xlabel(app.TIS_AxesEt, app.axisLabelWithUnit('t', timeDD)) ;
            ylabel(app.TIS_AxesEt, app.axisLabelWithUnitName('E(t)', app.timeInverseUnitName(timeDD))) ;
            hold(app.TIS_AxesEt, 'off') ;

            app.updateConcentrationHeader(app.TIS_C_exitLabel, concDD) ;
            app.TIS_C_exitPanel.Title = sprintf('Exit Summary - Concentration [%s]', ...
                app.concentrationUnitName(concDD)) ;

            compLabels = app.getReactionComponentLabels(RS) ;
            speciesRoles = app.classifySpeciesRoles(RS) ;
            reactantInfo = app.getPredictionReactantInfo(RS, C0) ;
            speciesInfo = app.getPredictionSpeciesInfo(RS) ;
            X_tis_all = app.computeSpeciesConversion(C0, C_out_tis, reactantInfo.reactantIndices) ;
            X_cstr_all = app.computeSpeciesConversion(C0, C_out_cstr, reactantInfo.reactantIndices) ;
            X_pfr_all = app.computeSpeciesConversion(C0, C_out_pfr, reactantInfo.reactantIndices) ;
            app.updateTISSummaryTable( ...
                compLabels, speciesRoles, C0, ...
                C_out_tis, C_out_cstr, C_out_pfr, ...
                reactantInfo.reactantIndices, X_tis_all, X_cstr_all, X_pfr_all, concDD) ;

            % ---- Plot 2: Outlet concentration vs N sweep ----
            cla(app.TIS_AxesXvsN) ;
            N_sweep = [1, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 50, 100] ;
            C_sweep = zeros(numel(N_sweep), RS.nComponents) ;

            for idx = 1:length(N_sweep)
                [C_sweep(idx, :), ~] = TanksInSeries.solve_sequential( ...
                    N_sweep(idx), RS, C0, tau_val) ;
            end

            app.ensurePredictionSpeciesSelector(app.DisplayControls.TIS.component, speciesInfo) ;
            selectedIdx = app.getPredictionSelectedSpecies(app.DisplayControls.TIS.component, speciesInfo) ;
            C_sweep_display = app.convertOutputConcentration(C_sweep, concDD) ;
            C_cstr_display = app.convertOutputConcentration(C_out_cstr, concDD) ;
            C_pfr_display = app.convertOutputConcentration(C_out_pfr, concDD) ;
            compLabels = app.getReactionComponentLabels(RS) ;
            colors = lines(RS.nComponents) ;
            hold(app.TIS_AxesXvsN, 'on') ;
            for i = selectedIdx
                plot(app.TIS_AxesXvsN, N_sweep, C_sweep_display(:, i), 'o-', ...
                    'Color', colors(i,:), 'LineWidth', 1.5, ...
                    'MarkerFaceColor', colors(i,:), ...
                    'DisplayName', compLabels{i}) ;
                if isscalar(selectedIdx)
                    yline(app.TIS_AxesXvsN, C_cstr_display(i), '--', 'CSTR', ...
                        'Color', [0.8 0 0], 'LineWidth', 1, ...
                        'LabelHorizontalAlignment', 'left') ;
                    yline(app.TIS_AxesXvsN, C_pfr_display(i), '--', 'PFR', ...
                    'Color', [0 0.6 0], 'LineWidth', 1, ...
                        'LabelHorizontalAlignment', 'left') ;
                end
            end
            if ~isempty(selectedIdx)
                xline(app.TIS_AxesXvsN, N_val, ':', sprintf('N = %.4g', N_val), ...
                    'Color', [0.35 0.35 0.35], ...
                    'LineWidth', 1, ...
                    'LabelVerticalAlignment', 'middle', ...
                    'LabelHorizontalAlignment', 'center', ...
                    'HandleVisibility', 'off') ;
            end
            hold(app.TIS_AxesXvsN, 'off') ;

            if isempty(selectedIdx)
                text(app.TIS_AxesXvsN, 0.5, 0.5, 'No species selected', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                legend(app.TIS_AxesXvsN, 'off') ;
            elseif isscalar(selectedIdx)
                title(app.TIS_AxesXvsN, sprintf('Outlet Concentration vs N - %s', compLabels{selectedIdx})) ;
            else
                title(app.TIS_AxesXvsN, 'Outlet Concentration vs N') ;
            end
            xlabel(app.TIS_AxesXvsN, 'N [number of tanks]') ;
            ylabel(app.TIS_AxesXvsN, app.axisLabelWithUnit('C', concDD)) ;
            if isempty(selectedIdx) || isscalar(selectedIdx)
                legend(app.TIS_AxesXvsN, 'off') ;
            else
                legend(app.TIS_AxesXvsN, 'Location', 'best') ;
            end

            % ---- Plot 3: Conversion vs N ----
            cla(app.TIS_AxesComparison) ;
            app.ensurePredictionReactantSelector(app.DisplayControls.TIS.reactant, reactantInfo) ;
            selectedReactants = app.getPredictionSelectedReactants(app.DisplayControls.TIS.reactant, reactantInfo) ;
            if isempty(reactantInfo.reactantIndices)
                text(app.TIS_AxesComparison, 0.5, 0.5, 'No functional reactants with C_0 > 0', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                legend(app.TIS_AxesComparison, 'off') ;
            elseif isempty(selectedReactants)
                text(app.TIS_AxesComparison, 0.5, 0.5, 'No functional reactants selected', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                legend(app.TIS_AxesComparison, 'off') ;
            else
                X_sweep_all = zeros(numel(N_sweep), numel(reactantInfo.reactantIndices)) ;
                for idx = 1:numel(N_sweep)
                    X_sweep_all(idx, :) = app.computeSpeciesConversion( ...
                        C0, C_sweep(idx, :), reactantInfo.reactantIndices) ;
                end
                reactantPlotPos = arrayfun(@(idx) find(reactantInfo.reactantIndices == idx, 1), selectedReactants) ;
                reactantLabels = compLabels(selectedReactants) ;
                reactantColors = lines(max(1, numel(reactantInfo.reactantIndices))) ;
                hold(app.TIS_AxesComparison, 'on') ;
                for k = 1:numel(selectedReactants)
                    pos = reactantPlotPos(k) ;
                    plot(app.TIS_AxesComparison, N_sweep, X_sweep_all(:, pos), 'o-', ...
                        'Color', reactantColors(pos, :), ...
                        'LineWidth', 1.5, ...
                        'MarkerFaceColor', reactantColors(pos, :), ...
                        'DisplayName', reactantLabels{k}) ;
                    if isscalar(selectedReactants)
                        yline(app.TIS_AxesComparison, X_cstr_all(pos), '--', 'CSTR', ...
                            'Color', [0.80 0.20 0.20], ...
                            'LineWidth', 1, ...
                            'LabelHorizontalAlignment', 'left') ;
                        yline(app.TIS_AxesComparison, X_pfr_all(pos), '--', 'PFR', ...
                            'Color', [0.20 0.60 0.20], ...
                            'LineWidth', 1, ...
                            'LabelHorizontalAlignment', 'left') ;
                    end
                end
                xline(app.TIS_AxesComparison, N_val, ':', sprintf('N = %.4g', N_val), ...
                    'Color', [0.35 0.35 0.35], ...
                    'LineWidth', 1, ...
                    'LabelVerticalAlignment', 'middle', ...
                    'LabelHorizontalAlignment', 'center', ...
                    'HandleVisibility', 'off') ;
                hold(app.TIS_AxesComparison, 'off') ;
                if isscalar(selectedReactants)
                    title(app.TIS_AxesComparison, sprintf('Conversion vs N - %s', reactantLabels{1})) ;
                else
                    title(app.TIS_AxesComparison, 'Conversion vs N') ;
                end
                plotLimitMatrix = X_sweep_all(:, reactantPlotPos) ;
                app.setPredictionAnnotatedYLimits(app.TIS_AxesComparison, plotLimitMatrix, 1) ;
                if isscalar(selectedReactants)
                    legend(app.TIS_AxesComparison, 'off') ;
                else
                    legend(app.TIS_AxesComparison, 'Location', 'best') ;
                end
            end
            xlabel(app.TIS_AxesComparison, 'N [number of tanks]') ;
            ylabel(app.TIS_AxesComparison, 'Conversion X (-)') ;
        end

        %% ============== TAB 4: DISPERSION MODEL ==============

        function createDispersionTab(app)

            app.DispTab = uitab(app.TabGroup, 'Title', 'Dispersion Model') ;

            mainGrid = uigridlayout(app.DispTab, [1 2]) ;
            mainGrid.ColumnWidth = {430, '1x'} ;

            % ---- LEFT PANEL ----
            leftPanel = uipanel(mainGrid, 'Title', 'Dispersion Configuration') ;
            leftGrid = uigridlayout(leftPanel, [17 2]) ;
            rowHD = repmat({28}, 1, 17) ; rowHD{2} = 0 ; rowHD{17} = 260 ;
            leftGrid.RowHeight = rowHD ;
            leftGrid.ColumnWidth = {'1x', '1x'} ;
            leftGrid.Padding = [10 10 10 10] ;
            leftGrid.RowSpacing = 5 ;

            % Row 1: Input method
            lbl = uilabel(leftGrid, 'Text', 'Input:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 1 ; lbl.Layout.Column = 1 ;
            methodSubGridD = uigridlayout(leftGrid, [1 2], ...
                'ColumnWidth', {'1x', 28}, 'Padding', [0 0 0 0], 'ColumnSpacing', 2) ;
            methodSubGridD.Layout.Row = 1 ; methodSubGridD.Layout.Column = 2 ;
            app.Disp_InputMethodDropdown = uidropdown(methodSubGridD, ...
                'Items', {'Manual', 'From Calculated Data'}, ...
                'Value', 'Manual', ...
                'ValueChangedFcn', @(~,~) app.Disp_inputMethodChanged()) ;
            app.setTooltip('Choose whether dispersion inputs are entered manually or reused from previously calculated data.', ...
                lbl, app.Disp_InputMethodDropdown) ;
            app.Disp_RefreshButton = uibutton(methodSubGridD, 'push', ...
                'Text', char(8635), 'FontSize', 12, ...
                'Tooltip', 'Refresh imported data from Tab 1 and Tab 2', ...
                'Visible', 'off', ...
                'ButtonPushedFcn', @(~,~) app.Disp_inputMethodChanged()) ;

            % Row 2: Import status (hidden by default)
            app.Disp_RTDStatusLabel = uilabel(leftGrid, ...
                'Text', '', 'FontColor', [0 0.5 0], ...
                'Interpreter', 'html') ;
            app.Disp_RTDStatusLabel.Layout.Row = 2 ;
            app.Disp_RTDStatusLabel.Layout.Column = [1 2] ;
            app.Disp_RTDStatusLabel.Tooltip = 'Shows the RTD source currently imported into the dispersion model.' ;
            app.Disp_RTDStatusLabel.Visible = 'off' ;

            % Row 3: Pe
            app.Disp_BoLabel = uilabel(leftGrid, 'Text', 'Pe [-]:') ;
            app.Disp_BoLabel.Layout.Row = 3 ; app.Disp_BoLabel.Layout.Column = 1 ;
            app.Disp_BoLabel.FontWeight = 'bold' ;
            app.Disp_BoField = uieditfield(leftGrid, 'numeric', ...
                'Value', 40, 'Limits', [1e-3 Inf], ...
                'ValueChangedFcn', @(~,~) app.Disp_updatePe(), ...
                'Tooltip', 'Dispersion number Bo = De/(u·L). Bo→0: plug flow (PFR), Bo→∞: perfect mixing (CSTR).') ;
            app.Disp_BoField.Layout.Row = 3 ; app.Disp_BoField.Layout.Column = 2 ;
            app.Disp_BoField.Tooltip = 'Peclet number used by the dispersion model. Larger Pe means weaker axial dispersion and behavior closer to PFR.' ;

            % Row 4: Bo display (read-only)
            lbl = uilabel(leftGrid, 'Text', '$Bo = 1/Pe$:', 'Interpreter', 'latex') ;
            lbl.Layout.Row = 4 ; lbl.Layout.Column = 1 ;
            app.Disp_PeLabel = uilabel(leftGrid, 'Text', sprintf('%.4g', 1/40)) ;
            app.Disp_PeLabel.Layout.Row = 4 ; app.Disp_PeLabel.Layout.Column = 2 ;
            app.setTooltip('Dispersion number corresponding to the current Peclet value. Bo = 1 / Pe.', lbl, app.Disp_PeLabel) ;

            % Row 5: Boundary conditions
            app.Disp_BCLabel = uilabel(leftGrid, 'Text', 'Boundary:') ;
            app.Disp_BCLabel.Layout.Row = 5 ; app.Disp_BCLabel.Layout.Column = 1 ;
            app.Disp_BCDropdown = uidropdown(leftGrid, ...
                'Items', {'closed-closed', 'open-open'}, ...
                'Value', 'closed-closed', ...
                'Tooltip', 'closed-closed: confined reactor (Danckwerts). open-open: open reactor (Gaussian approximation).') ;
            app.Disp_BCDropdown.Layout.Row = 5 ; app.Disp_BCDropdown.Layout.Column = 2 ;
            app.Disp_BCDropdown.Tooltip = 'closed-closed uses Danckwerts boundary conditions for the reactive axial-dispersion model. open-open is kept for RTD work and linear first-order reactive cases only.' ;
            app.setTooltip('Boundary condition used by the axial dispersion model.', app.Disp_BCLabel, app.Disp_BCDropdown) ;
            app.Disp_BCLabel.Tooltip = 'closed-closed uses Danckwerts boundary conditions for the reactive axial-dispersion model. open-open is kept for RTD work and linear first-order reactive cases only.' ;
            app.Disp_BCDropdown.Tooltip = 'closed-closed uses Danckwerts boundary conditions for the reactive axial-dispersion model. open-open is kept for RTD work and linear first-order reactive cases only.' ;

            % Row 6: tau
            app.Disp_tauLabel = uilabel(leftGrid, 'Text', '$\tau$:', 'Interpreter', 'latex') ;
            app.Disp_tauLabel.Layout.Row = 6 ; app.Disp_tauLabel.Layout.Column = 1 ;
            [app.Disp_tauField, ~] = app.createNumericWithConv( ...
                leftGrid, 6, 2, 10, 'Time', ...
                'Limits', [0.001 Inf], ...
                'Tooltip', 'Mean residence time: tau = V/Q = L/u.') ;
            app.setTooltip('Mean residence time assigned to the dispersion model. For open-open RTDs the internal tau_space is derived from this mean tau and Bo.', app.Disp_tauLabel, app.Disp_tauField) ;

            % Row 7: Reaction System header
            lbl = uilabel(leftGrid, 'Text', 'Reaction System:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 7 ; lbl.Layout.Column = [1 2] ;

            % Row 8: New RS + Edit RS buttons
            app.Disp_RSDefineButton = uibutton(leftGrid, 'push', ...
                'Text', 'New RS', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new Reaction System from scratch', ...
                'ButtonPushedFcn', @(~,~) defineReactionSysApp()) ;
            app.Disp_RSDefineButton.Layout.Row = 8 ;
            app.Disp_RSDefineButton.Layout.Column = 1 ;

            app.Disp_RSEditButton = uibutton(leftGrid, 'push', ...
                'Text', 'Edit RS', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded Reaction System', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.Disp_editRS()) ;
            app.Disp_RSEditButton.Layout.Row = 8 ;
            app.Disp_RSEditButton.Layout.Column = 2 ;

            % Row 9: RS name field + Load button
            app.Disp_RSNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'RS', ...
                'Tooltip', 'Name of the ReactionSys variable in the MATLAB workspace') ;
            app.Disp_RSNameField.Layout.Row = 9 ; app.Disp_RSNameField.Layout.Column = 1 ;
            app.Disp_RSLoadButton = uibutton(leftGrid, 'push', ...
                'Text', 'Load from Workspace', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the ReactionSys object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.Disp_loadRS()) ;
            app.Disp_RSLoadButton.Layout.Row = 9 ; app.Disp_RSLoadButton.Layout.Column = 2 ;

            % Row 10: RS status
            app.Disp_RSStatusLabel = uilabel(leftGrid, ...
                'Text', 'No Reaction System loaded', 'FontColor', [0.6 0 0]) ;
            app.Disp_RSStatusLabel.Layout.Row = 10 ;
            app.Disp_RSStatusLabel.Layout.Column = [1 2] ;
            app.Disp_RSStatusLabel.Tooltip = 'Shows whether a Reaction System is loaded for the dispersion calculation.' ;

            % Row 11: Feed Stream header
            lbl = uilabel(leftGrid, 'Text', 'Feed Stream:', 'FontWeight', 'bold') ;
            lbl.Layout.Row = 11 ; lbl.Layout.Column = [1 2] ;

            % Row 12: New Stream + Edit Stream buttons
            app.Disp_StreamDefineButton = uibutton(leftGrid, 'push', ...
                'Text', 'New Stream', ...
                'BackgroundColor', [0.85 0.90 1.0], ...
                'Tooltip', 'Create a new feed stream with defineStreamApp', ...
                'ButtonPushedFcn', @(~,~) defineStreamApp()) ;
            app.Disp_StreamDefineButton.Layout.Row = 12 ;
            app.Disp_StreamDefineButton.Layout.Column = 1 ;
            app.Disp_StreamEditButton = uibutton(leftGrid, 'push', ...
                'Text', 'Edit Stream', ...
                'BackgroundColor', [1.0 0.95 0.80], ...
                'Tooltip', 'Edit the currently loaded feed stream', ...
                'Enable', 'off', ...
                'ButtonPushedFcn', @(~,~) app.Disp_editStream()) ;
            app.Disp_StreamEditButton.Layout.Row = 12 ;
            app.Disp_StreamEditButton.Layout.Column = 2 ;

            % Row 13: stream name + Load button
            app.Disp_StreamNameField = uieditfield(leftGrid, 'text', ...
                'Value', 'feed', ...
                'Tooltip', 'Name of the feed Stream variable in the MATLAB workspace') ;
            app.Disp_StreamNameField.Layout.Row = 13 ; app.Disp_StreamNameField.Layout.Column = 1 ;
            app.Disp_StreamLoadButton = uibutton(leftGrid, 'push', ...
                'Text', 'Load from Workspace', ...
                'BackgroundColor', [0.85 0.95 0.85], ...
                'Tooltip', 'Load the feed Stream object from the workspace', ...
                'ButtonPushedFcn', @(~,~) app.Disp_loadStream()) ;
            app.Disp_StreamLoadButton.Layout.Row = 13 ; app.Disp_StreamLoadButton.Layout.Column = 2 ;

            % Row 14: Stream status
            app.Disp_StreamStatusLabel = uilabel(leftGrid, ...
                'Text', 'No feed stream loaded', 'FontColor', [0.6 0 0], ...
                'Interpreter', 'html') ;
            app.Disp_StreamStatusLabel.Layout.Row = 14 ;
            app.Disp_StreamStatusLabel.Layout.Column = [1 2] ;
            app.Disp_StreamStatusLabel.Tooltip = 'Shows whether a feed Stream is loaded for the dispersion calculation.' ;

            % Row 15: Compute button
            app.Disp_ComputeButton = uibutton(leftGrid, 'push', ...
                'Text', 'Compute', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.3 0.6 0.9], ...
                'FontColor', 'white', ...
                'ButtonPushedFcn', @(~,~) app.Disp_compute()) ;
            app.Disp_ComputeButton.Layout.Row = 15 ;
            app.Disp_ComputeButton.Layout.Column = [1 2] ;
            app.Disp_ComputeButton.Tooltip = 'Compute the reactive dispersion result and compare it with the ideal references. closed-closed uses the axial-dispersion BVP; open-open is limited to linear first-order kinetics.' ;

            % Row 16: Display units title
            lbl = uilabel(leftGrid, 'Text', 'Display units:', ...
                'FontWeight', 'bold', 'FontSize', 13) ;
            lbl.Layout.Row = 16 ; lbl.Layout.Column = [1 2] ;

            % Row 17: Display units
            unitsGrid = uigridlayout(leftGrid, [2 2], ...
                'ColumnWidth', {'1x', '1x'}, ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [0 0 0 0], ...
                'ColumnSpacing', 4, ...
                'RowSpacing', 4) ;
            unitsGrid.Layout.Row = 17 ;
            unitsGrid.Layout.Column = [1 2] ;

            rtdPanel = uipanel(unitsGrid, 'Title', 'E(t) Plot') ;
            rtdPanel.Layout.Row = 1 ;
            rtdPanel.Layout.Column = [1 2] ;
            rtdGrid = uigridlayout(rtdPanel, [1 1], ...
                'Padding', [6 6 6 6]) ;
            app.DisplayControls.Dispersion.time = app.createDisplayUnitControl( ...
                rtdGrid, 1, 1, 'Time base:', 'Time', 's', @(~,~) app.refreshDisplayUnits('Dispersion'), 84) ;

            concPanel = uipanel(unitsGrid, 'Title', 'Outlet Concentration vs Pe') ;
            concPanel.Layout.Row = 2 ;
            concPanel.Layout.Column = 1 ;
            concGrid = uigridlayout(concPanel, [2 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 6) ;
            app.DisplayControls.Dispersion.concentration = app.createDisplayUnitControl( ...
                concGrid, 1, 1, 'Concentration:', 'Concentration', 'mol/m^3', @(~,~) app.refreshDisplayUnits('Dispersion'), 92) ;
            app.DisplayControls.Dispersion.species = app.createDisplayMultiSelectControl( ...
                concGrid, 2, 1, 'Species:', @(~,~) app.refreshDisplayUnits('Dispersion'), '1x') ;

            convPanel = uipanel(unitsGrid, 'Title', 'Conversion vs Pe') ;
            convPanel.Layout.Row = 2 ;
            convPanel.Layout.Column = 2 ;
            convGrid = uigridlayout(convPanel, [2 1], ...
                'RowHeight', {'fit', '1x'}, ...
                'Padding', [6 6 6 6], ...
                'RowSpacing', 6) ;
            app.DisplayControls.Dispersion.reactant = app.createDisplayMultiSelectControl( ...
                convGrid, 2, 1, 'Reactants:', @(~,~) app.refreshDisplayUnits('Dispersion'), '1x') ;

            % ---- RIGHT PANEL (PLOTS) ----
            rightPanel = uipanel(mainGrid, 'Title', 'Dispersion Results') ;
            rightGrid = uigridlayout(rightPanel, [2 2]) ;
            rightGrid.RowHeight = {'1x', '1x'} ;
            rightGrid.ColumnWidth = {'1x', '1x'} ;
            rightGrid.Padding = [0 0 0 0] ;
            rightGrid.RowSpacing = 6 ;
            rightGrid.ColumnSpacing = 6 ;

            % Outlet concentration vs Pe plot
            app.Disp_AxesXvsBo = uiaxes(rightGrid) ;
            app.Disp_AxesXvsBo.Layout.Row = 1 ;
            app.Disp_AxesXvsBo.Layout.Column = 1 ;
            title(app.Disp_AxesXvsBo, 'Outlet Concentration vs Pe') ;
            xlabel(app.Disp_AxesXvsBo, 'Pe [-]') ;
            ylabel(app.Disp_AxesXvsBo, 'C [mol/m^3]') ;
            grid(app.Disp_AxesXvsBo, 'on') ;

            % Conversion vs Pe plot
            app.Disp_AxesComparison = uiaxes(rightGrid) ;
            app.Disp_AxesComparison.Layout.Row = 1 ;
            app.Disp_AxesComparison.Layout.Column = 2 ;
            title(app.Disp_AxesComparison, 'Conversion vs Pe') ;
            xlabel(app.Disp_AxesComparison, 'Pe [-]') ;
            ylabel(app.Disp_AxesComparison, 'Conversion X') ;
            grid(app.Disp_AxesComparison, 'on') ;

            % Exit summary table
            app.Disp_C_exitPanel = uipanel(rightGrid, ...
                'Title', 'Exit Summary - Concentration [mol/m^3]') ;
            app.Disp_C_exitPanel.Layout.Row = 2 ;
            app.Disp_C_exitPanel.Layout.Column = 1 ;
            app.Disp_C_exitPanel.Tooltip = ...
                ['Per-species summary of feed concentration, outlet concentration and functional-reactant conversion for dispersion and its CSTR/PFR references. ' ...
                'C_in denotes feed concentration and C_out denotes outlet concentration at the reactor exit.'] ;
            tableGrid = uigridlayout(app.Disp_C_exitPanel, [1 1], ...
                'Padding', [6 6 6 6]) ;
            app.Disp_C_exitLabel = uilabel(tableGrid, ...
                'Text', '', ...
                'Visible', 'off') ;
            app.Disp_C_exitTable = uitable(tableGrid, ...
                'ColumnName', {'Component', 'Role', 'C_in', 'Disp C_out', 'CSTR C_out', 'PFR C_out', 'X_Disp', 'X_CSTR', 'X_PFR'}, ...
                'ColumnEditable', false(1, 9), ...
                'ColumnWidth', {86, 72, 68, 84, 84, 84, 68, 74, 74}, ...
                'RowName', {}) ;
            app.Disp_C_exitTable.Layout.Row = 1 ;
            app.Disp_C_exitTable.Tooltip = ...
                ['Functional reactants show concentration and conversion. Products and inerts show concentration only, and intermediates can also show conversion when they are consumed. ' ...
                'C_in denotes feed concentration and C_out denotes outlet concentration at the reactor exit.'] ;

            % E(t) plot
            app.Disp_AxesEt = uiaxes(rightGrid) ;
            app.Disp_AxesEt.Layout.Row = 2 ;
            app.Disp_AxesEt.Layout.Column = 2 ;
            title(app.Disp_AxesEt, 'E(t) - Dispersion') ;
            xlabel(app.Disp_AxesEt, 't [s]') ;
            ylabel(app.Disp_AxesEt, 'E(t) [1/s]') ;
            grid(app.Disp_AxesEt, 'on') ;
        end

        %% ============== DISPERSION CALLBACKS ==============

        function Disp_updatePe(app)
            Pe = max(app.Disp_BoField.Value, 1e-12) ;
            Bo = 1 / Pe ;
            app.Disp_PeLabel.Text = sprintf('%.4g', Bo) ;
        end

        function Disp_loadRS(app)
            % Load a ReactionSys object from the MATLAB workspace by name
            rsName = app.Disp_RSNameField.Value ;
            try
                RS = evalin('base', rsName) ;
                if ~isa(RS, 'ReactionSys')
                    error('Variable "%s" is not a ReactionSys object.', rsName) ;
                end
                app.Disp_RS = RS ;
                nR = RS.nReactions ;
                nC = RS.nComponents ;
                app.Disp_RSStatusLabel.Text = sprintf('Loaded: %d reactions, %d components', nR, nC) ;
                app.Disp_RSStatusLabel.FontColor = [0 0.5 0] ;
                app.Disp_RSEditButton.Enable = 'on' ;
            catch ME
                app.Disp_RSStatusLabel.Text = ME.message ;
                app.Disp_RSStatusLabel.FontColor = [0.8 0 0] ;
            end
        end

        function Disp_editRS(app)
            % Open defineReactionSysApp pre-loaded with the current RS
            if isempty(app.Disp_RS)
                uialert(app.UIFigure, ...
                    'No Reaction System loaded to edit.', 'Nothing to Edit') ;
                return
            end
            rsName = app.Disp_RSNameField.Value ;
            defineReactionSysApp(app.Disp_RS, rsName) ;
        end

        function Disp_inputMethodChanged(app)
            source = app.Disp_InputMethodDropdown.Value ;

            if contains(source, 'From Calculated')
                % Disable manual fields and import data
                app.Disp_BoField.Enable = 'off' ;
                app.Disp_tauField.Enable = 'off' ;
                app.Disp_RTDStatusLabel.Visible = 'off' ;
                app.Disp_RefreshButton.Visible = 'on' ;
                infoLines = {} ;

                % Import RTD data (tau, sigma2_theta -> Bo)
                if ~isempty(app.rtd) && app.rtd.sigma2 > 0
                    app.setInputFieldValue(app.Disp_tauField, app.rtd.tau) ;
                    sigma2_theta = app.rtd.sigma2 / app.rtd.tau^2 ;
                    bcType = app.Disp_BCDropdown.Value ;

                    % Compute Bo from sigma2_theta
                    Bo_calc = app.compute_Bo_from_variance(sigma2_theta, bcType, app.rtd) ;
                    if isnan(Bo_calc) || isinf(Bo_calc) || Bo_calc < 1e-6 || Bo_calc > 100
                        msg = sprintf(['Calculated Bo = %g is outside the valid range [1e-6, 100].\n\n' ...
                            'Possible causes:\n' ...
                            '  - Near-ideal RTD (PFR-like): variance is too small, leading to Bo ≈ 0.\n' ...
                            '  - Invalid RTD data: sigma² or tau contain NaN/Inf values.\n' ...
                            '  - Very large dispersion: variance is too high, producing Bo > 100.\n\n' ...
                            'Current RTD values: sigma² = %.4g, tau = %.4g'], ...
                            Bo_calc, app.rtd.sigma2, app.rtd.tau) ;
                        uialert(app.UIFigure, msg, 'Bo Out of Range', 'Icon', 'warning') ;
                        return
                    end
                    app.Disp_BoField.Value = 1 / max(Bo_calc, 1e-12) ;
                    app.Disp_updatePe() ;

                    infoLines{end+1} = app.htmlStatusTauPe('RTD: ', app.rtd.tau, 1 / max(Bo_calc, 1e-12)) ;
                else
                    infoLines{end+1} = 'RTD: not loaded' ;
                end

                % Import RS from Prediction Models tab (if loaded)
                if ~isempty(app.Pred_RS)
                    app.Disp_RS = app.Pred_RS ;
                    app.Disp_RSNameField.Value = app.Pred_RSNameField.Value ;
                    nR = app.Disp_RS.nReactions ;
                    nC = app.Disp_RS.nComponents ;
                    app.Disp_RSStatusLabel.Text = sprintf('Loaded: %d reactions, %d components', nR, nC) ;
                    app.Disp_RSStatusLabel.FontColor = [0 0.5 0] ;
                    app.Disp_RSEditButton.Enable = 'on' ;
                    infoLines{end+1} = sprintf('RS: %s', app.Pred_RSNameField.Value) ;
                else
                    infoLines{end+1} = 'RS: not loaded' ;
                end

                % Import feed Stream from Prediction Models tab
                if ~isempty(app.Pred_feedStream)
                    app.Disp_feedStream = app.Pred_feedStream ;
                    app.Disp_StreamNameField.Value = app.Pred_StreamNameField.Value ;
                    app.Disp_StreamEditButton.Enable = 'on' ;
                    C_str = sprintf('%.4g  ', app.Pred_feedStream.concentration) ;
                    app.Disp_StreamStatusLabel.Text = sprintf('(from Prediction, internal SI) [%s] mol/m<sup>3</sup>', strtrim(C_str)) ;
                    app.Disp_StreamStatusLabel.FontColor = [0 0.5 0] ;
                    infoLines{end+1} = 'Stream: from Prediction' ;
                else
                    infoLines{end+1} = 'Stream: not loaded' ;
                end

                if any(contains(infoLines, 'not loaded'))
                    app.Disp_RTDStatusLabel.FontColor = [0.8 0 0] ;
                else
                    app.Disp_RTDStatusLabel.FontColor = [0 0.5 0] ;
                end
                app.Disp_RTDStatusLabel.Text = strjoin(infoLines, ' | ') ;
            else
                % Manual mode: re-enable all fields
                app.Disp_BoField.Enable = 'on' ;
                app.Disp_tauField.Enable = 'on' ;
                app.Disp_RTDStatusLabel.Visible = 'off' ;
                app.Disp_RefreshButton.Visible = 'off' ;
            end
        end

        function Disp_compute(app)

            try
                app.updateStatus('Computing dispersion model...') ;

                % Validate that a ReactionSys is loaded
                if isempty(app.Disp_RS)
                    uialert(app.UIFigure, ...
                        'No Reaction System loaded. Use "New RS" to create one, then "Load from Workspace" to import it.', ...
                        'Missing Reaction System') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                % Validate feed stream
                if isempty(app.Disp_feedStream)
                    uialert(app.UIFigure, ...
                        'No feed stream loaded. Define a Stream with "New Stream" and load it.', ...
                        'Missing Feed Stream') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                RS = app.Disp_RS ;
                C0 = app.Disp_feedStream.concentration(:)' ;

                if length(C0) ~= RS.nComponents
                    uialert(app.UIFigure, ...
                        sprintf('Feed stream has %d components but RS has %d. They must match.', ...
                        length(C0), RS.nComponents), 'Component Mismatch') ;
                    app.updateStatus('Ready') ;
                    return ;
                end

                Pe_val = max(app.Disp_BoField.Value, 1e-12) ;
                Bo_val = 1 / Pe_val ;
                bcType = app.Disp_BCDropdown.Value ;
                tau_val = app.readInputField(app.Disp_tauField) ;

                % Create DispersionReactor
                app.disp_reactor = DispersionReactor(Bo_val, bcType) ;
                if strcmp(bcType, 'open-open') && ~DispersionReactor.supports_open_open_first_order(RS)
                    uialert(app.UIFigure, ...
                        ['Open-open dispersion can only be used with linear first-order kinetics.' newline newline ...
                         'For this reaction system, please use closed-closed boundary conditions or redefine the kinetics as first-order linear.'], ...
                        'Open-open Not Available', ...
                        'Icon', 'warning') ;
                    app.updateStatus('Ready') ;
                    return
                end

                % Compute dispersion conversion via general method
                [X_disp, C_out_disp] = app.disp_reactor.compute_conversion_general(RS, C0, tau_val) ;

                % Reference: CSTR and PFR via TanksInSeries module
                [C_out_cstr, X_cstr] = TanksInSeries.solve_sequential(1, RS, C0, tau_val) ;
                [C_out_pfr,  X_pfr]  = TanksInSeries.solve_PFR(RS, C0, tau_val) ;

                X_cstr = max(0, min(1, X_cstr)) ;
                X_pfr  = max(0, min(1, X_pfr)) ;

                app.DisplayCache.Dispersion = struct( ...
                    'Bo_val', Bo_val, ...
                    'Pe_val', Pe_val, ...
                    'tau_val', tau_val, ...
                    'RS', RS, ...
                    'C0', C0, ...
                    'X_disp', X_disp, ...
                    'X_cstr', X_cstr, ...
                    'X_pfr', X_pfr, ...
                    'C_out_disp', C_out_disp, ...
                    'C_out_cstr', C_out_cstr, ...
                    'C_out_pfr', C_out_pfr, ...
                    'bcType', bcType) ;

                % Update plots
                app.Disp_updatePlots(Bo_val, tau_val, RS, C0, ...
                                     X_disp, X_cstr, X_pfr, ...
                                     C_out_disp, C_out_cstr, C_out_pfr, bcType) ;

                app.updateStatus('Ready') ;

            catch ME
                app.updateStatus('Error') ;
                uialert(app.UIFigure, ME.message, 'Dispersion Model Error') ;
            end
        end

        function Disp_updatePlots(app, Bo_val, tau_val, RS, C0, ...
                                  ~, ~, ~, ...
                                  C_out_disp, C_out_cstr, C_out_pfr, bcType)

            % ---- Plot 1: E(t) ----
            app.Disp_clearMomentOverlay() ;
            cla(app.Disp_AxesEt) ;
            rtd_obj = app.disp_reactor.generate_RTD(tau_val) ;
            timeDD = app.DisplayControls.Dispersion.time ;
            concDD = app.DisplayControls.Dispersion.concentration ;
            t_display = app.convertOutputVectorFromTime('time', rtd_obj.t, timeDD) ;
            Et_display = app.convertOutputVectorFromTime('timeInverse', rtd_obj.Et, timeDD) ;
            hold(app.Disp_AxesEt, 'on') ;
            [app.Disp_EtSigmaBandHandle, tauOverlay, lowerOverlay, upperOverlay, sigmaOverlay] = ...
                app.RTD_drawEtMomentOverlay(app.Disp_AxesEt, rtd_obj, t_display, Et_display, timeDD, [0.64 0.80 1.00]) ;
            plot(app.Disp_AxesEt, t_display, Et_display, 'b-', 'LineWidth', 1.5) ;
            app.RTD_expandMomentAxesY(app.Disp_AxesEt, Et_display) ;
            [app.Disp_EtSigmaCenterHandle, app.Disp_EtSigmaLowerHandle, app.Disp_EtSigmaUpperHandle, app.Disp_EtSigmaLabelHandles] = ...
                app.RTD_drawMomentGuideLines(app.Disp_AxesEt, t_display, Et_display, tauOverlay, lowerOverlay, upperOverlay, sigmaOverlay, [0.00 0.20 0.75], 1e-12, ...
                {'\tau', '\tau-\sigma', '\tau+\sigma'}) ;
            title(app.Disp_AxesEt, sprintf('E(t) - %s, Bo=%.4g', ...
                  bcType, Bo_val)) ;
            xlabel(app.Disp_AxesEt, app.axisLabelWithUnit('t', timeDD)) ;
            ylabel(app.Disp_AxesEt, app.axisLabelWithUnitName('E(t)', app.timeInverseUnitName(timeDD))) ;

            tau_display = app.convertOutputScalar('Time', tau_val, timeDD) ;
            annotationText = sprintf('Bo = %.4g\nPe = %.4g\n\\tau_m = %.4g %s', ...
                Bo_val, 1 / Bo_val, tau_display, timeDD.Value) ;
            if strcmp(bcType, 'open-open') && isstruct(rtd_obj.modelInfo) && isfield(rtd_obj.modelInfo, 'tauSpace')
                tauSpace_display = app.convertOutputScalar('Time', rtd_obj.modelInfo.tauSpace, timeDD) ;
                annotationText = sprintf('%s\n\\tau_{space} = %.4g %s', ...
                    annotationText, tauSpace_display, timeDD.Value) ;
            end
            text(app.Disp_AxesEt, 0.95, 0.90, annotationText, ...
                'Units', 'normalized', 'HorizontalAlignment', 'right', ...
                'VerticalAlignment', 'top', 'FontSize', 9, ...
                'Interpreter', 'tex', ...
                'BackgroundColor', [1 1 1 0.8], 'EdgeColor', [0.7 0.7 0.7]) ;
            hold(app.Disp_AxesEt, 'off') ;

            app.Disp_C_exitPanel.Title = sprintf('Exit Summary - Concentration [%s]', ...
                app.concentrationUnitName(concDD)) ;

            compLabels = app.getReactionComponentLabels(RS) ;
            speciesRoles = app.classifySpeciesRoles(RS) ;
            reactantInfo = app.getPredictionReactantInfo(RS, C0) ;
            speciesInfo = app.getPredictionSpeciesInfo(RS) ;
            X_disp_all = app.computeSpeciesConversion(C0, C_out_disp, reactantInfo.reactantIndices) ;
            X_cstr_all = app.computeSpeciesConversion(C0, C_out_cstr, reactantInfo.reactantIndices) ;
            X_pfr_all = app.computeSpeciesConversion(C0, C_out_pfr, reactantInfo.reactantIndices) ;
            app.updateDispSummaryTable( ...
                compLabels, speciesRoles, C0, ...
                C_out_disp, C_out_cstr, C_out_pfr, ...
                reactantInfo.reactantIndices, X_disp_all, X_cstr_all, X_pfr_all, concDD) ;

            % ---- Plot 2: Outlet concentration vs Pe sweep ----
            cla(app.Disp_AxesXvsBo) ;
            [Pe_sweep, ~, C_sweep] = app.disp_reactor.sweep_Pe_general(RS, C0, tau_val) ;
            app.ensurePredictionSpeciesSelector(app.DisplayControls.Dispersion.species, speciesInfo) ;
            selectedIdx = app.getPredictionSelectedSpecies(app.DisplayControls.Dispersion.species, speciesInfo) ;
            C_sweep_display = app.convertOutputConcentration(C_sweep, concDD) ;
            C_cstr_display = app.convertOutputConcentration(C_out_cstr, concDD) ;
            C_pfr_display = app.convertOutputConcentration(C_out_pfr, concDD) ;
            colors = lines(RS.nComponents) ;
            title(app.Disp_AxesXvsBo, 'Outlet Concentration vs Pe') ;
            hold(app.Disp_AxesXvsBo, 'on') ;
            for i = selectedIdx
                semilogx(app.Disp_AxesXvsBo, Pe_sweep, C_sweep_display(:, i), '-', ...
                    'Color', colors(i,:), 'LineWidth', 1.5, ...
                    'DisplayName', compLabels{i}) ;
                if isscalar(selectedIdx)
                    yline(app.Disp_AxesXvsBo, C_pfr_display(i), '--', 'PFR', ...
                        'Color', [0 0.6 0], 'LineWidth', 1, ...
                        'LabelHorizontalAlignment', 'left') ;
                    yline(app.Disp_AxesXvsBo, C_cstr_display(i), '--', 'CSTR', ...
                        'Color', [0.8 0 0], 'LineWidth', 1, ...
                        'LabelHorizontalAlignment', 'left') ;
                end
            end
            if ~isempty(selectedIdx)
                xline(app.Disp_AxesXvsBo, 1 / Bo_val, ':', sprintf('Pe = %.4g', 1 / Bo_val), ...
                    'Color', [0.35 0.35 0.35], ...
                    'LineWidth', 1, ...
                    'LabelVerticalAlignment', 'middle', ...
                    'LabelHorizontalAlignment', 'center', ...
                    'HandleVisibility', 'off') ;
            end
            hold(app.Disp_AxesXvsBo, 'off') ;

            if isempty(selectedIdx)
                text(app.Disp_AxesXvsBo, 0.5, 0.5, 'No species selected', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                legend(app.Disp_AxesXvsBo, 'off') ;
            elseif isscalar(selectedIdx)
                title(app.Disp_AxesXvsBo, sprintf('Outlet Concentration vs Pe - %s', compLabels{selectedIdx})) ;
            else
                title(app.Disp_AxesXvsBo, 'Outlet Concentration vs Pe') ;
            end
            xlabel(app.Disp_AxesXvsBo, 'Pe [-]') ;
            ylabel(app.Disp_AxesXvsBo, app.axisLabelWithUnit('C', concDD)) ;
            if isempty(selectedIdx) || isscalar(selectedIdx)
                legend(app.Disp_AxesXvsBo, 'off') ;
            else
                legend(app.Disp_AxesXvsBo, 'Location', 'best') ;
            end

            % ---- Plot 3: Comparison bar chart (CSTR → Disp → PFR) ----
            cla(app.Disp_AxesComparison) ;
            title(app.Disp_AxesComparison, 'Conversion vs Pe') ;
            app.ensurePredictionReactantSelector(app.DisplayControls.Dispersion.reactant, reactantInfo) ;
            selectedReactants = app.getPredictionSelectedReactants(app.DisplayControls.Dispersion.reactant, reactantInfo) ;
            if isempty(reactantInfo.reactantIndices)
                text(app.Disp_AxesComparison, 0.5, 0.5, 'No functional reactants with C_0 > 0', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                legend(app.Disp_AxesComparison, 'off') ;
            elseif isempty(selectedReactants)
                text(app.Disp_AxesComparison, 0.5, 0.5, 'No functional reactants selected', ...
                    'Units', 'normalized', 'HorizontalAlignment', 'center') ;
                legend(app.Disp_AxesComparison, 'off') ;
            else
                X_sweep_all = zeros(numel(Pe_sweep), numel(reactantInfo.reactantIndices)) ;
                for idx = 1:numel(Pe_sweep)
                    X_sweep_all(idx, :) = app.computeSpeciesConversion( ...
                        C0, C_sweep(idx, :), reactantInfo.reactantIndices) ;
                end
                reactantPlotPos = arrayfun(@(idx) find(reactantInfo.reactantIndices == idx, 1), selectedReactants) ;
                reactantLabels = compLabels(selectedReactants) ;
                reactantColors = lines(max(1, numel(reactantInfo.reactantIndices))) ;
                hold(app.Disp_AxesComparison, 'on') ;
                for k = 1:numel(selectedReactants)
                    pos = reactantPlotPos(k) ;
                    semilogx(app.Disp_AxesComparison, Pe_sweep, X_sweep_all(:, pos), 'o-', ...
                        'Color', reactantColors(pos, :), ...
                        'LineWidth', 1.5, ...
                        'MarkerFaceColor', reactantColors(pos, :), ...
                        'DisplayName', reactantLabels{k}) ;
                    if isscalar(selectedReactants)
                        yline(app.Disp_AxesComparison, X_cstr_all(pos), '--', 'CSTR', ...
                            'Color', [0.80 0.20 0.20], ...
                            'LineWidth', 1, ...
                            'LabelHorizontalAlignment', 'left') ;
                        yline(app.Disp_AxesComparison, X_pfr_all(pos), '--', 'PFR', ...
                            'Color', [0.20 0.60 0.20], ...
                            'LineWidth', 1, ...
                            'LabelHorizontalAlignment', 'left') ;
                    end
                end
                xline(app.Disp_AxesComparison, 1 / Bo_val, ':', sprintf('Pe = %.4g', 1 / Bo_val), ...
                    'Color', [0.35 0.35 0.35], ...
                    'LineWidth', 1, ...
                    'LabelVerticalAlignment', 'middle', ...
                    'LabelHorizontalAlignment', 'center', ...
                    'HandleVisibility', 'off') ;
                hold(app.Disp_AxesComparison, 'off') ;
                if isscalar(selectedReactants)
                    title(app.Disp_AxesComparison, sprintf('Conversion vs Pe - %s', reactantLabels{1})) ;
                else
                    title(app.Disp_AxesComparison, 'Conversion vs Pe') ;
                end
                plotLimitMatrix = X_sweep_all(:, reactantPlotPos) ;
                app.setPredictionAnnotatedYLimits(app.Disp_AxesComparison, plotLimitMatrix, 1) ;
                if isscalar(selectedReactants)
                    legend(app.Disp_AxesComparison, 'off') ;
                else
                    legend(app.Disp_AxesComparison, 'Location', 'best') ;
                end
            end
            xlabel(app.Disp_AxesComparison, 'Pe [-]') ;
            ylabel(app.Disp_AxesComparison, 'Conversion X (-)') ;
        end

        %% ============== TAB 5: DESIGN & OPTIMIZATION WORKSPACE ==============

        function createDesignTemplatesTab(app)
            app.DesignState = DesignWorkspaceHelper.defaultState() ;
            app.DesignTab = uitab(app.TabGroup, 'Title', 'Design & Optimization') ;

            root = uigridlayout(app.DesignTab, [1 1]) ;
            root.Padding = [8 8 8 8] ;

            app.DesignUI.TabGroup = uitabgroup(root) ;

            app.DW_createFitTab() ;
            app.DW_createReactiveTab() ;
            app.DW_createOptimizationTab() ;
            app.DW_refreshAll() ;
        end

        function D = DW_buildSnapshot(app)
            D = struct() ;
            D.fit = struct() ;
            D.fit.source = app.DesignUI.Fit.SourceDropdown.Value ;
            D.fit.family = app.DesignUI.Fit.FamilyDropdown.Value ;
            D.fit.boundary = app.DesignUI.Fit.BoundaryDropdown.Value ;
            D.fit.fitConstraintState = app.DW_captureFitConstraintState() ;
            D.fit.displayTimeUnit = app.getControlValue(app.getDisplayControl('DesignFit', 'time'), 's') ;
            D.fit.displayVolumeUnit = app.getControlValue(app.getDisplayControl('DesignFit', 'volume'), 'm^3') ;
            D.fit.searchSelection = app.captureListboxSelection(app.DesignUI.Fit.FamilySearchList) ;
            D.fit.result = app.DesignState.fitResult ;

            D.reaction = struct() ;
            D.reaction.rtdSource = app.DesignUI.Reactive.RTDSourceDropdown.Value ;
            D.reaction.rsName = app.DesignUI.Reactive.RSNameField.Value ;
            D.reaction.streamName = app.DesignUI.Reactive.StreamNameField.Value ;
            D.reaction.rs = app.serializeValueObject(app.getStructField(app.DesignState.reactionSpec, 'rs', [])) ;
            D.reaction.feedStream = app.serializeValueObject(app.getStructField(app.DesignState.reactionSpec, 'feedStream', [])) ;
            D.reaction.keyComponentIndex = app.DesignUI.Reactive.KeyComponentDropdown.Value ;
            D.reaction.desiredProductIndex = app.DesignUI.Reactive.DesiredProductDropdown.Value ;
            D.reaction.byproductIndex = app.DesignUI.Reactive.ByproductDropdown.Value ;
            D.reaction.displayConcentrationUnit = app.getControlValue(app.getDisplayControl('DesignReactive', 'concentration'), 'mol/m^3') ;
            D.reaction.chartMetric = app.getControlValue(app.getDisplayControl('DesignReactive', 'metric'), 'Conversion') ;
            D.reaction.result = app.getStructField(app.DesignState.lastSolutions, 'reactiveResult', []) ;

            D.optimization = struct() ;
            D.optimization.rtdSource = app.DesignUI.Optimization.RTDSourceDropdown.Value ;
            D.optimization.reactionMode = app.DesignUI.Optimization.ReactionModeDropdown.Value ;
            D.optimization.objective = app.DesignUI.Optimization.ObjectiveDropdown.Value ;
            D.optimization.keyReactant = app.DesignUI.Optimization.KeyReactantDropdown.Value ;
            D.optimization.desiredProduct = app.DesignUI.Optimization.DesiredProductDropdown.Value ;
            D.optimization.byproduct = app.DesignUI.Optimization.ByproductDropdown.Value ;
            D.optimization.decisionTable = app.DesignUI.Optimization.DecisionTable.Data ;
            D.optimization.constraintTable = app.DesignUI.Optimization.ConstraintTable.Data ;
            D.optimization.displayConcentrationUnit = app.getControlValue(app.getDisplayControl('DesignOptimization', 'concentration'), 'mol/m^3') ;
            D.optimization.result = app.getStructField(app.DesignState.lastSolutions, 'optimizationResult', []) ;
        end

        function DW_applySnapshot(app, snapshot)
            if isempty(snapshot) || ~isstruct(snapshot)
                return
            end

            fit = app.getStructField(snapshot, 'fit', struct()) ;
            app.setDropdownValueIfValid(app.DesignUI.Fit.SourceDropdown, app.getStructField(fit, 'source', app.DesignUI.Fit.SourceDropdown.Value)) ;
            fitFamily = app.DW_mapLegacyFitFamily(app.getStructField(fit, 'family', app.DesignUI.Fit.FamilyDropdown.Value)) ;
            app.setDropdownValueIfValid(app.DesignUI.Fit.FamilyDropdown, fitFamily) ;
            app.setDropdownValueIfValid(app.DesignUI.Fit.BoundaryDropdown, app.getStructField(fit, 'boundary', app.DesignUI.Fit.BoundaryDropdown.Value)) ;
            fitTimeControl = app.getDisplayControl('DesignFit', 'time') ;
            app.setDropdownValueIfValid(fitTimeControl, app.getStructField(fit, 'displayTimeUnit', app.getControlValue(fitTimeControl, 's'))) ;
            fitVolumeControl = app.getDisplayControl('DesignFit', 'volume') ;
            app.setDropdownValueIfValid(fitVolumeControl, app.getStructField(fit, 'displayVolumeUnit', app.getControlValue(fitVolumeControl, 'm^3'))) ;
            app.DW_applyFitConstraintSnapshot(app.getStructField(fit, 'fitConstraintState', []), ...
                app.getStructField(fit, 'referenceTau', struct()), ...
                app.getStructField(fit, 'totalVolume', struct())) ;
            app.DesignState.fitResult = app.DW_normalizeFitResultFamilies(app.getStructField(fit, 'result', [])) ;
            app.DesignUI.Fit.FamilySearchList.UserData = struct('pendingSelection', ...
                app.getStructField(fit, 'searchSelection', [])) ;

            reaction = app.getStructField(snapshot, 'reaction', struct()) ;
            app.setDropdownValueIfValid(app.DesignUI.Reactive.RTDSourceDropdown, app.getStructField(reaction, 'rtdSource', app.DesignUI.Reactive.RTDSourceDropdown.Value)) ;
            app.DesignUI.Reactive.RSNameField.Value = app.getStructField(reaction, 'rsName', app.DesignUI.Reactive.RSNameField.Value) ;
            app.DesignUI.Reactive.StreamNameField.Value = app.getStructField(reaction, 'streamName', app.DesignUI.Reactive.StreamNameField.Value) ;
            app.DesignState.reactionSpec.rs = app.deserializeValueObject(app.getStructField(reaction, 'rs', []), 'ReactionSys') ;
            app.DesignState.reactionSpec.feedStream = app.deserializeValueObject(app.getStructField(reaction, 'feedStream', []), 'Stream') ;
            app.DesignState.reactionSpec.keyComponentIndex = app.getStructField(reaction, 'keyComponentIndex', 1) ;
            app.DesignState.reactionSpec.desiredProductIndex = app.getStructField(reaction, 'desiredProductIndex', 2) ;
            app.DesignState.reactionSpec.byproductIndex = app.getStructField(reaction, 'byproductIndex', 3) ;
            reactiveConcControl = app.getDisplayControl('DesignReactive', 'concentration') ;
            app.setDropdownValueIfValid(reactiveConcControl, app.getStructField(reaction, 'displayConcentrationUnit', app.getControlValue(reactiveConcControl, 'mol/m^3'))) ;
            reactiveMetricControl = app.getDisplayControl('DesignReactive', 'metric') ;
            app.setDropdownValueIfValid(reactiveMetricControl, app.getStructField(reaction, 'chartMetric', app.getControlValue(reactiveMetricControl, 'Conversion'))) ;
            app.DesignState.lastSolutions.reactiveResult = app.getStructField(reaction, 'result', []) ;

            opt = app.getStructField(snapshot, 'optimization', struct()) ;
            app.setDropdownValueIfValid(app.DesignUI.Optimization.RTDSourceDropdown, app.getStructField(opt, 'rtdSource', app.DesignUI.Optimization.RTDSourceDropdown.Value)) ;
            app.setDropdownValueIfValid(app.DesignUI.Optimization.ReactionModeDropdown, app.getStructField(opt, 'reactionMode', app.DesignUI.Optimization.ReactionModeDropdown.Value)) ;
            app.setDropdownValueIfValid(app.DesignUI.Optimization.ObjectiveDropdown, app.getStructField(opt, 'objective', app.DesignUI.Optimization.ObjectiveDropdown.Value)) ;
            optConcControl = app.getDisplayControl('DesignOptimization', 'concentration') ;
            app.setDropdownValueIfValid(optConcControl, app.getStructField(opt, 'displayConcentrationUnit', app.getControlValue(optConcControl, 'mol/m^3'))) ;
            app.DW_resetOptimizationTables() ;
            app.DW_applyOptimizationSelectorSnapshot(opt) ;
            app.DW_applyOptimizationDecisionSnapshot(app.getStructField(opt, 'decisionTable', [])) ;
            app.DW_applyOptimizationConstraintSnapshot(app.getStructField(opt, 'constraintTable', [])) ;
            if isfield(opt, 'rtdSource')
                app.DesignState.lastSolutions.optimizationResult = app.getStructField(opt, 'result', []) ;
            else
                app.DesignState.lastSolutions.optimizationResult = [] ;
            end

            app.DW_refreshChemicalSelectors() ;
            app.DW_refreshAll() ;
        end

        function snapshot = DW_convertLegacyTemplateSnapshot(~, legacy)
            snapshot = struct() ;
            if isempty(legacy) || ~isstruct(legacy)
                return
            end
            snapshot.fit = struct('source', 'Tab 1 RTD', 'family', 'CSTR (dead volume)', ...
                'boundary', 'closed-closed', 'fitConstraintState', [], ...
                'displayTimeUnit', 's', 'displayVolumeUnit', 'm^3', ...
                'searchSelection', [], 'result', []) ;
        end

        function DW_createFitTab(app)
            tab = uitab(app.DesignUI.TabGroup, 'Title', 'Diagnosis & Fit') ;
            grid = uigridlayout(tab, [1 2]) ;
            grid.ColumnWidth = {340, '1x'} ;

            left = uipanel(grid, 'Title', 'Fit Setup') ;
            left.Layout.Column = 1 ;
            leftGrid = uigridlayout(left, [9 2]) ;
            leftGrid.RowHeight = {'fit','fit',0,180,82,34,34,'fit',0} ;
            leftGrid.ColumnWidth = {120, '1x'} ;
            app.DesignUI.Fit.SetupGrid = leftGrid ;

            lbl = uilabel(leftGrid, 'Text', 'RTD source:') ;
            app.DesignUI.Fit.SourceDropdown = uidropdown(leftGrid, 'Items', {'Tab 1 RTD'}) ;
            app.DesignUI.Fit.SourceDropdown.Layout.Row = 1 ; app.DesignUI.Fit.SourceDropdown.Layout.Column = 2 ;
            app.setTooltip('Choose which RTD is fitted in this workspace. At present the source is the RTD from Tab 1.', ...
                lbl, app.DesignUI.Fit.SourceDropdown) ;

            lbl = uilabel(leftGrid, 'Text', 'Family:') ;
            app.DesignUI.Fit.FamilyLabel = lbl ;
            app.DesignUI.Fit.FamilyDropdown = uidropdown(leftGrid, ...
                'Items', {'Tanks-in-Series', 'Axial Dispersion', 'CSTR (dead volume)', 'PFR (dead volume)', ...
                'PFR + CSTR (series, dead volume)', 'PFR + CSTR (parallel, dead volume)', ...
                'CSTR + Bypass (dead volume)'}) ;
            app.DesignUI.Fit.FamilyDropdown.Layout.Row = 2 ; app.DesignUI.Fit.FamilyDropdown.Layout.Column = 2 ;
            app.setTooltip('Equivalent hydrodynamic family used to approximate the RTD from Tab 1.', ...
                lbl, app.DesignUI.Fit.FamilyDropdown) ;

            lbl = uilabel(leftGrid, 'Text', 'Boundary:') ;
            app.DesignUI.Fit.BoundaryLabel = lbl ;
            app.DesignUI.Fit.BoundaryDropdown = uidropdown(leftGrid, 'Items', {'closed-closed', 'open-open'}) ;
            app.DesignUI.Fit.BoundaryDropdown.Layout.Row = 3 ; app.DesignUI.Fit.BoundaryDropdown.Layout.Column = 2 ;
            app.setTooltip('Boundary condition used when the selected family needs an axial dispersion assumption.', ...
                lbl, app.DesignUI.Fit.BoundaryDropdown) ;

            app.DesignUI.Fit.VariableTable = uitable(leftGrid, ...
                'ColumnName', {'Use', 'Variable', 'Min', 'Max'}, ...
                'ColumnEditable', [true false true true], ...
                'ColumnWidth', {42, 112, 78, 78}, ...
                'RowName', {}, ...
                'CellEditCallback', @(src, event) app.DW_handleFitConstraintTableEdit(src, event)) ;
            app.DesignUI.Fit.VariableTable.Layout.Row = 4 ;
            app.DesignUI.Fit.VariableTable.Layout.Column = [1 2] ;
            app.DesignUI.Fit.VariableTable.Tooltip = app.buildTooltipFromColumns( ...
                'Optional bounds for the simple fit. Mark Use to constrain that family parameter between Min and Max.', ...
                {'Use', 'Variable', 'Min', 'Max'}) ;
            app.DesignUI.Fit.ScalarVariableTable = uitable(leftGrid, ...
                'ColumnName', {'Use', 'Variable', 'Value'}, ...
                'ColumnEditable', [true false true], ...
                'ColumnWidth', {42, 112, 134}, ...
                'RowName', {}, ...
                'CellEditCallback', @(src, event) app.DW_handleFitConstraintTableEdit(src, event)) ;
            app.DesignUI.Fit.ScalarVariableTable.Layout.Row = 5 ;
            app.DesignUI.Fit.ScalarVariableTable.Layout.Column = [1 2] ;
            app.DesignUI.Fit.ScalarVariableTable.Tooltip = app.buildTooltipFromColumns( ...
                ['Scalar fit inputs for dead-volume families. Activate at most one row: ' ...
                'either Ref. tau_total or Total volume.'], ...
                {'Use', 'Variable', 'Value'}) ;
            app.DW_initializeFitConstraintTable() ;
            app.DW_syncDefaultReferenceTau() ;

            app.DesignUI.Fit.SearchButton = uibutton(leftGrid, 'push', 'Text', 'Search best family', ...
                'ButtonPushedFcn', @(~,~) app.DW_runFitSearch()) ;
            app.DesignUI.Fit.SearchButton.Layout.Row = 6 ; app.DesignUI.Fit.SearchButton.Layout.Column = [1 2] ;
            app.DesignUI.Fit.SearchButton.Tooltip = 'Fit every supported family, compare RMSE and score, and overlay the selected fitted RTDs.' ;

            app.DesignUI.Fit.RunButton = uibutton(leftGrid, 'push', 'Text', 'Run Diagnosis & Fit', ...
                'ButtonPushedFcn', @(~,~) app.DW_runFit()) ;
            app.DesignUI.Fit.RunButton.Layout.Row = 7 ; app.DesignUI.Fit.RunButton.Layout.Column = [1 2] ;
            app.DesignUI.Fit.RunButton.Tooltip = 'Run the heuristic diagnosis and fit the selected equivalent hydrodynamic model.' ;

            fitUnitsGrid = uigridlayout(leftGrid, [2 1], ...
                'ColumnWidth', {'fit'}, ...
                'RowHeight', {'fit', 'fit'}, ...
                'Padding', [0 0 0 0], ...
                'RowSpacing', 4, ...
                'ColumnSpacing', 0) ;
            fitUnitsGrid.Layout.Row = 8 ;
            fitUnitsGrid.Layout.Column = [1 2] ;
            app.DisplayControls.DesignFit.time = app.createDisplayUnitControl( ...
                fitUnitsGrid, 1, 1, 'Display time:', 'Time', 's', @(~,~) app.refreshDisplayUnits('DesignFit'), 92) ;
            app.DisplayControls.DesignFit.volume = app.createDisplayUnitControl( ...
                fitUnitsGrid, 2, 1, 'Volume:', 'Volume', 'm^3', @(~,~) app.refreshDisplayUnits('DesignFit'), 92) ;

            app.DesignUI.Fit.FamilySearchList = app.createDisplayMultiSelectControl( ...
                leftGrid, 9, [1 2], 'Families:', @(~,~) app.DW_handleFitSearchSelection(), 176) ;
            app.clearMultiSelectListbox(app.DesignUI.Fit.FamilySearchList) ;
            app.DesignUI.Fit.FamilySearchList.Tooltip = 'Select which fitted families are displayed on the comparison plot.' ;
            app.DesignUI.Fit.FamilySearchList.UserData = struct('familyNames', {{}}, 'pendingSelection', []) ;

            right = uipanel(grid, 'Title', 'Fit Results') ;
            right.Layout.Column = 2 ;
            rightGrid = uigridlayout(right, [3 1]) ;
            rightGrid.RowHeight = {'fit', 250, '1x'} ;

            app.DesignUI.Fit.SummaryLabel = uilabel(rightGrid, 'Text', 'Awaiting RTD fit.', 'WordWrap', 'on') ;
            app.DesignUI.Fit.SummaryLabel.Layout.Row = 1 ;
            app.DesignUI.Fit.SummaryLabel.Tooltip = ['Fit summary. RMSE is the root mean square error between the input and fitted E(t). ' ...
                'Score is a dimensionless similarity indicator based on curve SSE.'] ;

            app.DesignUI.Fit.ResultContainer = uigridlayout(rightGrid, [1 1], ...
                'Padding', [0 0 0 0], 'RowSpacing', 0, 'ColumnSpacing', 0) ;
            app.DesignUI.Fit.ResultContainer.Layout.Row = 2 ;
            app.DesignUI.Fit.ParameterTable = uitable(app.DesignUI.Fit.ResultContainer, 'ColumnName', {'Parameter', 'Value'}, 'RowName', {}) ;
            app.DesignUI.Fit.ParameterTable.Layout.Row = 1 ;
            app.DesignUI.Fit.ParameterTable.Layout.Column = 1 ;
            app.DesignUI.Fit.ParameterTable.Tooltip = app.buildTooltipFromColumns( ...
                'Estimated hydrodynamic parameters obtained from the RTD fit.', {'Parameter', 'Value'}) ;
            app.DesignUI.Fit.ParameterFieldsPanel = uipanel(app.DesignUI.Fit.ResultContainer, 'BorderType', 'none') ;
            app.DesignUI.Fit.ParameterFieldsPanel.Layout.Row = 1 ;
            app.DesignUI.Fit.ParameterFieldsPanel.Layout.Column = 1 ;
            app.DesignUI.Fit.ParameterFieldsPanel.Tooltip = 'Key fitted parameters for the selected hydrodynamic family.' ;
            app.DW_createFitResultFields() ;
            app.DesignUI.Fit.CompareAxes = uiaxes(rightGrid) ; title(app.DesignUI.Fit.CompareAxes, 'Input vs fitted E(t)') ;
            app.DesignUI.Fit.CompareAxes.Layout.Row = 3 ;
            app.DW_applyFitAxesLabels('Input vs fitted E(t)') ;
            app.DesignUI.Fit.FamilyDropdown.ValueChangedFcn = @(~,~) app.DW_refreshFitContext() ;
            app.DW_refreshFitContext() ;
        end

        function DW_createReactiveTab(app)
            tab = uitab(app.DesignUI.TabGroup, 'Title', 'Reactive Performance') ;
            grid = uigridlayout(tab, [1 2]) ;
            grid.ColumnWidth = {360, '1x'} ;

            left = uipanel(grid, 'Title', 'Reaction Inputs') ;
            left.Layout.Column = 1 ;
            leftGrid = uigridlayout(left, [12 2]) ;
            leftGrid.RowHeight = {'fit','fit','fit','fit','fit','fit','fit','fit',34,'fit','fit','1x'} ;
            leftGrid.ColumnWidth = {130, '1x'} ;

            lbl = uilabel(leftGrid, 'Text', 'RTD source:') ;
            app.DesignUI.Reactive.RTDSourceDropdown = uidropdown(leftGrid, 'Items', {'Fitted RTD', 'Tab 1 RTD'}) ;
            app.DesignUI.Reactive.RTDSourceDropdown.Layout.Row = 1 ; app.DesignUI.Reactive.RTDSourceDropdown.Layout.Column = 2 ;
            app.setTooltip('Choose whether reactive calculations use the RTD fitted in this tab or the original RTD from Tab 1.', ...
                lbl, app.DesignUI.Reactive.RTDSourceDropdown) ;

            lbl = uilabel(leftGrid, 'Text', 'ReactionSys var:') ;
            app.DesignUI.Reactive.RSNameField = uieditfield(leftGrid, 'text', 'Value', 'RS') ;
            app.DesignUI.Reactive.RSNameField.Layout.Row = 2 ; app.DesignUI.Reactive.RSNameField.Layout.Column = 2 ;
            app.setTooltip('Workspace variable name of the ReactionSys object used for reactive calculations.', ...
                lbl, app.DesignUI.Reactive.RSNameField) ;
            lbl = uilabel(leftGrid, 'Text', 'Feed Stream var:') ;
            app.DesignUI.Reactive.StreamNameField = uieditfield(leftGrid, 'text', 'Value', 'Feed') ;
            app.DesignUI.Reactive.StreamNameField.Layout.Row = 3 ; app.DesignUI.Reactive.StreamNameField.Layout.Column = 2 ;
            app.setTooltip('Workspace variable name of the feed Stream used for reactive calculations.', ...
                lbl, app.DesignUI.Reactive.StreamNameField) ;

            app.DesignUI.Reactive.RSLoadButton = uibutton(leftGrid, 'push', 'Text', 'Load ReactionSys', ...
                'ButtonPushedFcn', @(~,~) app.DW_loadReactionSystem()) ;
            app.DesignUI.Reactive.RSLoadButton.Layout.Row = 4 ; app.DesignUI.Reactive.RSLoadButton.Layout.Column = [1 2] ;
            app.DesignUI.Reactive.RSLoadButton.Tooltip = 'Load the ReactionSys object named above from the MATLAB workspace.' ;
            app.DesignUI.Reactive.StreamLoadButton = uibutton(leftGrid, 'push', 'Text', 'Load Feed Stream', ...
                'ButtonPushedFcn', @(~,~) app.DW_loadFeedStream()) ;
            app.DesignUI.Reactive.StreamLoadButton.Layout.Row = 5 ; app.DesignUI.Reactive.StreamLoadButton.Layout.Column = [1 2] ;
            app.DesignUI.Reactive.StreamLoadButton.Tooltip = 'Load the feed Stream object named above from the MATLAB workspace.' ;

            lbl = uilabel(leftGrid, 'Text', 'Key reactant:') ;
            app.DesignUI.Reactive.KeyComponentLabel = lbl ;
            app.DesignUI.Reactive.KeyComponentDropdown = uidropdown(leftGrid, 'Items', {'1'}, 'ItemsData', 1, 'Value', 1) ;
            app.DesignUI.Reactive.KeyComponentDropdown.Layout.Row = 6 ; app.DesignUI.Reactive.KeyComponentDropdown.Layout.Column = 2 ;
            app.setTooltip('Main reactant used to report conversion X across the reactive models. In reversible or bidirectional systems this can default to a consumed intermediate acting as a functional reactant.', ...
                lbl, app.DesignUI.Reactive.KeyComponentDropdown) ;
            lbl = uilabel(leftGrid, 'Text', 'Desired product:') ;
            app.DesignUI.Reactive.DesiredProductLabel = lbl ;
            app.DesignUI.Reactive.DesiredProductDropdown = uidropdown(leftGrid, 'Items', {'2'}, 'ItemsData', 2, 'Value', 2) ;
            app.DesignUI.Reactive.DesiredProductDropdown.Layout.Row = 7 ; app.DesignUI.Reactive.DesiredProductDropdown.Layout.Column = 2 ;
            app.setTooltip('Product used to compute selectivity as desired product over reacted key reactant, and yield as desired product over feed key reactant.', ...
                lbl, app.DesignUI.Reactive.DesiredProductDropdown) ;
            lbl = uilabel(leftGrid, 'Text', 'Byproduct:') ;
            app.DesignUI.Reactive.ByproductLabel = lbl ;
            app.DesignUI.Reactive.ByproductDropdown = uidropdown(leftGrid, 'Items', {'3'}, 'ItemsData', 3, 'Value', 3) ;
            app.DesignUI.Reactive.ByproductDropdown.Layout.Row = 8 ; app.DesignUI.Reactive.ByproductDropdown.Layout.Column = 2 ;
            app.setTooltip('Optional side-product reference kept for compatibility. Current selectivity and yield use the desired product and the key-reactant consumption.', ...
                lbl, app.DesignUI.Reactive.ByproductDropdown) ;

            app.DesignUI.Reactive.ComputeButton = uibutton(leftGrid, 'push', 'Text', 'Compute Reactive Performance', ...
                'ButtonPushedFcn', @(~,~) app.DW_computeReactive()) ;
            app.DesignUI.Reactive.ComputeButton.Layout.Row = 9 ; app.DesignUI.Reactive.ComputeButton.Layout.Column = [1 2] ;
            app.DesignUI.Reactive.ComputeButton.Tooltip = 'Compute conversion, selectivity, yield and outlet concentrations for the reactive reference models.' ;

            lbl = uilabel(leftGrid, 'Text', 'Display units:') ;
            lbl.Layout.Row = 10 ; lbl.Layout.Column = [1 2] ;
            unitsGrid = uigridlayout(leftGrid, [2 1], ...
                'RowHeight', {'fit', 'fit'}, ...
                'Padding', [0 0 0 0], ...
                'RowSpacing', 6, ...
                'ColumnSpacing', 0) ;
            unitsGrid.Layout.Row = 11 ;
            unitsGrid.Layout.Column = [1 2] ;
            app.DisplayControls.DesignReactive.concentration = app.createDisplayUnitControl( ...
                unitsGrid, 1, 1, 'Concentration:', 'Concentration', 'mol/m^3', @(~,~) app.refreshDisplayUnits('DesignReactive'), 92) ;
            app.DisplayControls.DesignReactive.metric = app.createDisplayChoiceControl( ...
                unitsGrid, 2, 1, 'Chart metric:', {'Conversion', 'Selectivity', 'Yield'}, ...
                'Conversion', @(~,~) app.refreshDisplayUnits('DesignReactive'), 110) ;
            app.DisplayControls.DesignReactive.metric.Tooltip = 'Select which reactive metric is compared in the bar chart: conversion, selectivity or yield.' ;

            right = uipanel(grid, 'Title', 'Reactive Results') ;
            right.Layout.Column = 2 ;
            rightGrid = uigridlayout(right, [4 1]) ;
            rightGrid.RowHeight = {'fit', 150, 180, '1x'} ;

            app.DesignUI.Reactive.SummaryLabel = uilabel(rightGrid, ...
                'Text', app.DW_getReactiveMetricFormulaText(), ...
                'WordWrap', 'off', ...
                'Interpreter', 'latex') ;
            app.DesignUI.Reactive.SummaryLabel.Layout.Row = 1 ;
            app.DesignUI.Reactive.SummaryLabel.Tooltip = 'Reactive metrics are computed as Selectivity = C_desired / (C_in,key - C_out,key) and Yield = C_desired / C_in,key.' ;
            app.DesignUI.Reactive.ResultTable = uitable(rightGrid, 'ColumnName', {'Model', 'X', 'Selectivity', 'Yield'}, 'RowName', {}) ;
            app.DesignUI.Reactive.ResultTable.Layout.Row = 2 ;
            app.DesignUI.Reactive.ResultTable.Tooltip = app.buildTooltipFromColumns( ...
                'Reactive-performance summary by model. X denotes conversion of the key reactant, Selectivity = C_desired / (C_in,key - C_out,key), and Yield = C_desired / C_in,key.', ...
                {'Model', 'X', 'Selectivity', 'Yield'}) ;
            app.DesignUI.Reactive.CoutTable = uitable(rightGrid, 'ColumnName', {'Component', 'C_in', 'Seg', 'MM', 'CSTR', 'PFR'}, 'RowName', {}) ;
            app.DesignUI.Reactive.CoutTable.Layout.Row = 3 ;
            app.DesignUI.Reactive.CoutTable.Tooltip = app.buildTooltipFromColumns( ...
                'Outlet concentration table. C_in is the feed concentration and each model column is the predicted outlet concentration.', ...
                {'Component', 'C_in', 'Seg', 'MM', 'CSTR', 'PFR'}) ;
            app.DesignUI.Reactive.Axes = uiaxes(rightGrid) ; title(app.DesignUI.Reactive.Axes, 'Conversion comparison') ;
            app.DesignUI.Reactive.Axes.Layout.Row = 4 ;
            app.DW_refreshReactiveContext() ;
        end

        function DW_createOptimizationTab(app)
            tab = uitab(app.DesignUI.TabGroup, 'Title', 'Optimization') ;
            grid = uigridlayout(tab, [1 2]) ;
            grid.ColumnWidth = {470, '1x'} ;

            left = uipanel(grid, 'Title', 'Optimization Setup') ;
            left.Layout.Column = 1 ;
            leftGrid = uigridlayout(left, [11 1]) ;
            leftGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', 180, 140, 34, 'fit', 'fit'} ;
            leftGrid.Padding = [8 8 8 8] ;

            headerGrid = uigridlayout(leftGrid, [6 2]) ;
            headerGrid.ColumnWidth = {132, '1x'} ;
            headerGrid.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit'} ;
            headerGrid.Layout.Row = 1 ;
            app.DesignUI.Optimization.SetupGrid = headerGrid ;

            lbl = uilabel(headerGrid, 'Text', 'RTD source:') ;
            app.DesignUI.Optimization.RTDSourceDropdown = uidropdown(headerGrid, ...
                'Items', {'Tab 1 RTD', 'Fitted RTD'}) ;
            app.DesignUI.Optimization.RTDSourceDropdown.Layout.Row = 1 ;
            app.DesignUI.Optimization.RTDSourceDropdown.Layout.Column = 2 ;
            app.setTooltip('Choose which RTD remains fixed during process optimization.', ...
                lbl, app.DesignUI.Optimization.RTDSourceDropdown) ;

            lbl = uilabel(headerGrid, 'Text', 'Reaction mode:') ;
            app.DesignUI.Optimization.ReactionModeDropdown = uidropdown(headerGrid, ...
                'Items', {'Segregation', 'Max Mixedness'}) ;
            app.DesignUI.Optimization.ReactionModeDropdown.Layout.Row = 2 ;
            app.DesignUI.Optimization.ReactionModeDropdown.Layout.Column = 2 ;
            app.setTooltip('Reactive model used to evaluate each process scenario on the fixed RTD.', ...
                lbl, app.DesignUI.Optimization.ReactionModeDropdown) ;

            lbl = uilabel(headerGrid, 'Text', 'Objective:') ;
            app.DesignUI.Optimization.ObjectiveLabel = lbl ;
            app.DesignUI.Optimization.ObjectiveDropdown = uidropdown(headerGrid, ...
                'Items', {'Max conversion', 'Max selectivity', 'Max yield', ...
                'Max outlet concentration', 'Min outlet concentration'}) ;
            app.DesignUI.Optimization.ObjectiveDropdown.Layout.Row = 3 ;
            app.DesignUI.Optimization.ObjectiveDropdown.Layout.Column = 2 ;
            app.setTooltip('Process objective optimized with fixed RTD, fixed ReactionSys and a duplicated Feed Stream.', ...
                lbl, app.DesignUI.Optimization.ObjectiveDropdown) ;

            lbl = uilabel(headerGrid, 'Text', 'Key reactant:') ;
            app.DesignUI.Optimization.KeyReactantLabel = lbl ;
            app.DesignUI.Optimization.KeyReactantDropdown = uidropdown(headerGrid, ...
                'Items', {'CA'}, 'Value', 'CA') ;
            app.DesignUI.Optimization.KeyReactantDropdown.Layout.Row = 4 ;
            app.DesignUI.Optimization.KeyReactantDropdown.Layout.Column = 2 ;
            app.setTooltip('Species used to define conversion and the reference reactant for selectivity and yield.', ...
                lbl, app.DesignUI.Optimization.KeyReactantDropdown) ;

            lbl = uilabel(headerGrid, 'Text', 'Desired product:') ;
            app.DesignUI.Optimization.DesiredProductLabel = lbl ;
            app.DesignUI.Optimization.DesiredProductDropdown = uidropdown(headerGrid, ...
                'Items', {'CB'}, 'Value', 'CB') ;
            app.DesignUI.Optimization.DesiredProductDropdown.Layout.Row = 5 ;
            app.DesignUI.Optimization.DesiredProductDropdown.Layout.Column = 2 ;
            app.setTooltip('Species used for selectivity, yield and maximum outlet concentration objectives.', ...
                lbl, app.DesignUI.Optimization.DesiredProductDropdown) ;

            lbl = uilabel(headerGrid, 'Text', 'Byproduct:') ;
            app.DesignUI.Optimization.ByproductLabel = lbl ;
            app.DesignUI.Optimization.ByproductDropdown = uidropdown(headerGrid, ...
                'Items', {'CC'}, 'Value', 'CC') ;
            app.DesignUI.Optimization.ByproductDropdown.Layout.Row = 6 ;
            app.DesignUI.Optimization.ByproductDropdown.Layout.Column = 2 ;
            app.setTooltip('Species used for minimum outlet concentration objective.', ...
                lbl, app.DesignUI.Optimization.ByproductDropdown) ;

            app.DesignUI.Optimization.DecisionTable = uitable(leftGrid, ...
                'ColumnName', {'Use', 'Variable', 'Lower', 'Upper'}, ...
                'ColumnEditable', [true false true true], ...
                'ColumnWidth', {42, 150, 100, 100}, ...
                'RowName', {}, ...
                'Data', {false, 'Load Feed Stream first', NaN, NaN}, ...
                'CellEditCallback', @(src,event) app.DW_handleDecisionTableEdit(src, event)) ;
            app.DesignUI.Optimization.DecisionTable.Layout.Row = 7 ;
            app.DesignUI.Optimization.DecisionTable.Tooltip = app.buildTooltipFromColumns( ...
                ['Dynamic inlet concentration variables built from the loaded Feed Stream. ' ...
                'Only C_in,i rows are optimizable because, with fixed RTD, they are the process inputs that affect the reactive result.'], ...
                {'Use', 'Variable', 'Lower', 'Upper'}) ;

            app.DesignUI.Optimization.ConstraintTable = uitable(leftGrid, ...
                'ColumnName', {'Use', 'Variable', 'Species', 'Type', 'Value'}, ...
                'ColumnEditable', [true true true true true], ...
                'ColumnWidth', {42, 124, 90, 98, 92}, ...
                'RowName', {}, ...
                'Data', {false, 'Conversion', 'CA', 'Lower bound', 0.5}) ;
            app.DesignUI.Optimization.ConstraintTable.Layout.Row = 8 ;
            app.DesignUI.Optimization.ConstraintTable.Tooltip = app.buildTooltipFromColumns( ...
                'Optional constraints on reactive metrics or outlet concentration at the optimized solution.', ...
                {'Use', 'Variable', 'Species', 'Type', 'Value'}) ;
            app.DesignUI.Optimization.ConstraintTable.CellEditCallback = @(src,event) app.DW_handleOptimizationConstraintEdit(src, event) ;

            app.DesignUI.Optimization.RunButton = uibutton(leftGrid, 'push', 'Text', 'Run Optimization', ...
                'ButtonPushedFcn', @(~,~) app.DW_runOptimization()) ;
            app.DesignUI.Optimization.RunButton.Layout.Row = 9 ;
            app.DesignUI.Optimization.RunButton.Tooltip = 'Run the constrained optimization using the active decision variables and objective.' ;

            app.DesignUI.Optimization.InputUnitsNotice = uilabel(leftGrid, ...
                'Text', app.DW_buildOptimizationInputUnitNotice(), ...
                'WordWrap', 'on') ;
            app.DesignUI.Optimization.InputUnitsNotice.Layout.Row = 10 ;
            app.DesignUI.Optimization.InputUnitsNotice.Tooltip = ...
                'Optimization inherits its input units from the loaded Feed Stream.' ;

            unitsGrid = uigridlayout(leftGrid, [1 1], ...
                'Padding', [0 0 0 0], ...
                'RowSpacing', 6, ...
                'ColumnSpacing', 0) ;
            unitsGrid.Layout.Row = 11 ;
            unitsGrid.RowHeight = {'fit'} ;
            app.DisplayControls.DesignOptimization.concentration = app.createDisplayUnitControl( ...
                unitsGrid, 1, 1, 'Concentration:', 'Concentration', 'mol/m^3', @(~,~) app.refreshDisplayUnits('DesignOptimization'), 110) ;

            right = uipanel(grid, 'Title', 'Optimization Results') ;
            right.Layout.Column = 2 ;
            rightGrid = uigridlayout(right, [3 1]) ;
            rightGrid.RowHeight = {'fit', 190, '1x'} ;

            app.DesignUI.Optimization.SummaryLabel = uilabel(rightGrid, 'Text', 'Awaiting optimization.', 'WordWrap', 'on') ;
            app.DesignUI.Optimization.SummaryLabel.Layout.Row = 1 ;
            app.DesignUI.Optimization.SummaryLabel.Tooltip = 'Optimization summary comparing baseline and optimum performance for the selected objective.' ;
            app.DesignUI.Optimization.ComparisonTable = uitable(rightGrid, ...
                'ColumnName', {'Variable', 'Base', 'Optimum'}, ...
                'RowName', {}) ;
            app.DesignUI.Optimization.ComparisonTable.Layout.Row = 2 ;
            app.DesignUI.Optimization.ComparisonTable.Tooltip = app.buildTooltipFromColumns( ...
                'Comparison of objective, optimized variables and active constraints before and after optimization.', ...
                {'Variable', 'Base', 'Optimum'}) ;
            app.DesignUI.Optimization.ModelTable = uitable(rightGrid, ...
                'ColumnName', app.DW_buildOptimizationModelColumnNames(), ...
                'RowName', {}) ;
            app.DesignUI.Optimization.ModelTable.Layout.Row = 3 ;
            app.DesignUI.Optimization.ModelTable.Tooltip = app.buildTooltipFromColumns( ...
                'Single wide table comparing inlet concentration, conversion and outlet concentration across the four reactive models for base and optimized feeds.', ...
                app.DW_buildOptimizationModelColumnNames()) ;

            app.DesignUI.Optimization.RTDSourceDropdown.ValueChangedFcn = @(~,~) app.DW_handleOptimizationSetupChanged() ;
            app.DesignUI.Optimization.ReactionModeDropdown.ValueChangedFcn = @(~,~) app.DW_handleOptimizationSetupChanged() ;
            app.DesignUI.Optimization.ObjectiveDropdown.ValueChangedFcn = @(~,~) app.DW_handleOptimizationObjectiveChanged() ;
            app.DesignUI.Optimization.KeyReactantDropdown.ValueChangedFcn = @(~,~) app.DW_handleOptimizationSetupChanged() ;
            app.DesignUI.Optimization.DesiredProductDropdown.ValueChangedFcn = @(~,~) app.DW_handleOptimizationSetupChanged() ;
            app.DesignUI.Optimization.ByproductDropdown.ValueChangedFcn = @(~,~) app.DW_handleOptimizationSetupChanged() ;
            app.DW_resetOptimizationTables() ;
        end

        function DW_runFit(app)
            try
                app.updateStatus('Running diagnosis and fit...') ;
                rtdObj = app.DW_resolveRTDSource(app.DesignUI.Fit.SourceDropdown.Value) ;
                fitConfig = app.DW_collectFitConstraintConfig(true) ;
                spec = struct( ...
                    'rtd', rtdObj, ...
                    'family', app.DesignUI.Fit.FamilyDropdown.Value, ...
                    'boundaryType', app.DesignUI.Fit.BoundaryDropdown.Value, ...
                    'referenceTau', fitConfig.referenceTau, ...
                    'totalVolume', fitConfig.totalVolume, ...
                    'fitConstraints', fitConfig.constraints, ...
                    'flowRate', app.DW_getFitFlowRate()) ;
                app.DesignState.fitResult = DesignWorkspaceHelper.solveHydroFit(spec) ;
                app.DW_refreshFitContext() ;
                app.DW_refreshFit() ;
                app.updateStatus('Diagnosis and fit completed') ;
            catch ME
                app.updateStatus('Error') ;
                app.showDetailedError(ME, 'Diagnosis & Fit Error') ;
            end
        end

        function DW_runFitSearch(app)
            try
                app.updateStatus('Searching best fit family...') ;
                rtdObj = app.DW_resolveRTDSource(app.DesignUI.Fit.SourceDropdown.Value) ;
                spec = struct( ...
                    'rtd', rtdObj, ...
                    'boundaryType', app.DesignUI.Fit.BoundaryDropdown.Value, ...
                    'flowRate', app.DW_getFitFlowRate()) ;
                app.DesignState.fitResult = DesignWorkspaceHelper.solveHydroFitSearch(spec) ;
                app.DW_refreshFitContext() ;
                app.DW_refreshFit() ;
                app.updateStatus('Best-family search completed') ;
            catch ME
                app.updateStatus('Error') ;
                app.showDetailedError(ME, 'Diagnosis & Fit Error') ;
            end
        end

        function DW_loadReactionSystem(app)
            try
                RS = evalin('base', app.DesignUI.Reactive.RSNameField.Value) ;
                if ~isa(RS, 'ReactionSys')
                    error('Workspace variable is not a ReactionSys object.') ;
                end
                app.DesignState.reactionSpec.rs = RS ;
                app.DW_refreshChemicalSelectors() ;
                app.DW_refreshOptimizationDecisionTable(true) ;
                app.DW_refreshOptimizationConstraintTable(true) ;
                app.DesignState.lastSolutions.optimizationResult = [] ;
                app.DW_refreshOptimization() ;
                app.updateStatus('ReactionSys loaded for Design workspace') ;
            catch ME
                uialert(app.UIFigure, ME.message, 'Reaction System Error') ;
            end
        end

        function DW_loadFeedStream(app)
            try
                F = evalin('base', app.DesignUI.Reactive.StreamNameField.Value) ;
                if ~isa(F, 'Stream')
                    error('Workspace variable is not a Stream object.') ;
                end
                app.DesignState.reactionSpec.feedStream = F ;
                app.DW_refreshChemicalSelectors() ;
                app.DW_resetOptimizationTables() ;
                app.updateStatus('Feed Stream loaded for Design workspace') ;
            catch ME
                uialert(app.UIFigure, ME.message, 'Feed Stream Error') ;
            end
        end

        function DW_computeReactive(app)
            try
                app.updateStatus('Computing reactive performance...') ;
                rtdObj = app.DW_resolveRTDSource(app.DesignUI.Reactive.RTDSourceDropdown.Value) ;
                RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
                F = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
                if isempty(RS) || isempty(F)
                    error('Load both ReactionSys and Feed Stream first.') ;
                end
                app.DesignState.reactionSpec.keyComponentIndex = app.DesignUI.Reactive.KeyComponentDropdown.Value ;
                app.DesignState.reactionSpec.desiredProductIndex = app.DesignUI.Reactive.DesiredProductDropdown.Value ;
                app.DesignState.reactionSpec.byproductIndex = app.DesignUI.Reactive.ByproductDropdown.Value ;
                spec = struct( ...
                    'rtd', rtdObj, ...
                    'RS', RS, ...
                    'C0', F.concentration(:)', ...
                    'keyComponentIndex', app.DesignState.reactionSpec.keyComponentIndex, ...
                    'desiredProductIndex', app.DesignState.reactionSpec.desiredProductIndex, ...
                    'byproductIndex', app.DesignState.reactionSpec.byproductIndex) ;
                app.DesignState.lastSolutions.reactiveResult = DesignWorkspaceHelper.solveReactivePerformance(spec) ;
                app.DW_refreshReactive() ;
                app.updateStatus('Reactive performance updated') ;
            catch ME
                app.updateStatus('Error') ;
                uialert(app.UIFigure, ME.message, 'Reactive Performance Error') ;
            end
        end

        function DW_runOptimization(app)
            app.DesignUI.Optimization.RunButton.Enable = 'off' ;
            drawnow limitrate ;
            cleanupObj = onCleanup(@() app.DW_finishOptimizationRun()) ;
            try
                app.updateStatus('Running optimization...') ;
                rtdObj = app.DW_resolveRTDSource(app.DesignUI.Optimization.RTDSourceDropdown.Value) ;
                RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
                F = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
                if isempty(RS) || isempty(F)
                    error('Optimization reuses the chemistry loaded in Reactive Performance. Load RS and Feed first.') ;
                end
                decisionVariables = app.DW_parseDecisionTable() ;
                constraints = app.DW_parseConstraintTable() ;
                app.DW_validateOptimizationSetup(decisionVariables, constraints) ;
                spec = struct( ...
                    'rtd', rtdObj, ...
                    'rtdSource', app.DesignUI.Optimization.RTDSourceDropdown.Value, ...
                    'reactionMode', app.DesignUI.Optimization.ReactionModeDropdown.Value, ...
                    'objective', app.DesignUI.Optimization.ObjectiveDropdown.Value, ...
                    'RS', RS, ...
                    'feedStream', F, ...
                    'keyComponentIndex', app.DW_getOptimizationSelectorIndex(app.DesignUI.Optimization.KeyReactantDropdown), ...
                    'desiredProductIndex', app.DW_getOptimizationSelectorIndex(app.DesignUI.Optimization.DesiredProductDropdown), ...
                    'byproductIndex', app.DW_getOptimizationSelectorIndex(app.DesignUI.Optimization.ByproductDropdown), ...
                    'decisionVariables', decisionVariables, ...
                    'constraints', constraints) ;
                app.DesignState.lastSolutions.optimizationResult = DesignWorkspaceHelper.solveOptimization(spec) ;
                app.DW_refreshOptimization() ;
                app.updateStatus('Optimization completed') ;
            catch ME
                app.updateStatus('Error') ;
                uialert(app.UIFigure, ME.message, 'Optimization Error') ;
            end
        end

        function DW_finishOptimizationRun(app)
            try
                app.DW_refreshOptimizationContext() ;
            catch
            end
        end

        function rtdObj = DW_resolveRTDSource(app, sourceLabel)
            switch char(string(sourceLabel))
                case 'Fitted RTD'
                    result = app.DesignState.fitResult ;
                    if isempty(result), error('Fitted RTD is not available yet.') ; end
                    rtdObj = result.fittedRTD ;
                otherwise
                    if isempty(app.rtd), error('Tab 1 does not hold a valid RTD.') ; end
                    rtdObj = app.rtd ;
            end
        end

        function rows = DW_parseDecisionTable(app)
            data = app.DesignUI.Optimization.DecisionTable.Data ;
            definitions = app.DW_getOptimizationDecisionDefinitions() ;
            inputUnit = app.DW_getOptimizationInputConcentrationUnit() ;
            if isempty(definitions) || size(data, 1) ~= numel(definitions)
                rows = struct('use', {}, 'variable', {}, 'displayName', {}, 'group', {}, ...
                    'speciesIndex', {}, 'initialValue', {}, 'lowerBound', {}, 'upperBound', {}) ;
                return
            end
            rows = repmat(struct('use', false, 'variable', '', 'displayName', '', 'group', '', ...
                'speciesIndex', NaN, 'initialValue', 0, 'lowerBound', 0, 'upperBound', 0), size(data, 1), 1) ;
            for i = 1:size(data, 1)
                rows(i).use = logical(data{i, 1}) ;
                rows(i).variable = char(string(definitions(i).variable)) ;
                rows(i).displayName = char(string(definitions(i).displayName)) ;
                rows(i).group = char(string(definitions(i).group)) ;
                rows(i).speciesIndex = definitions(i).speciesIndex ;
                rows(i).initialValue = definitions(i).defaultValue ;
                rows(i).lowerBound = app.DW_convertOptimizationInputToSI(double(data{i, 3}), definitions(i), inputUnit) ;
                rows(i).upperBound = app.DW_convertOptimizationInputToSI(double(data{i, 4}), definitions(i), inputUnit) ;
            end
        end

        function rows = DW_parseConstraintTable(app)
            data = app.DesignUI.Optimization.ConstraintTable.Data ;
            speciesLabels = app.DW_getOptimizationSpeciesLabels() ;
            rows = repmat(struct('use', false, 'metric', '', 'speciesIndex', 1, 'speciesLabel', '', 'type', 'Lower bound', 'value', 0), size(data, 1), 1) ;
            for i = 1:size(data, 1)
                rows(i).use = logical(data{i, 1}) ;
                rows(i).metric = char(string(data{i, 2})) ;
                rows(i).speciesLabel = char(string(data{i, 3})) ;
                rows(i).speciesIndex = find(strcmp(speciesLabels, rows(i).speciesLabel), 1) ;
                if isempty(rows(i).speciesIndex)
                    rows(i).speciesIndex = 1 ;
                end
                rows(i).type = char(string(data{i, 4})) ;
                rows(i).value = double(data{i, 5}) ;
            end
        end

        function DW_validateOptimizationSetup(~, decisionVariables, constraints)
            activeCount = 0 ;
            for i = 1:numel(decisionVariables)
                row = decisionVariables(i) ;
                if ~row.use
                    continue
                end
                activeCount = activeCount + 1 ;
                if ~isfinite(row.lowerBound) || ~isfinite(row.upperBound)
                    error('All active optimization bounds must be finite.') ;
                end
                if row.lowerBound > row.upperBound
                    error('Each active optimization variable requires Lower <= Upper.') ;
                end
            end
            if activeCount < 1
                error('Select at least one optimization variable.') ;
            end
            for i = 1:numel(constraints)
                row = constraints(i) ;
                if row.use && ~isfinite(row.value)
                    error('All active constraints require a finite Value.') ;
                end
            end
        end

        function defs = DW_getOptimizationDecisionDefinitions(app)
            defs = struct('variable', {}, 'displayName', {}, 'group', {}, ...
                'speciesIndex', {}, 'defaultValue', {}, 'lowerBound', {}, 'upperBound', {}, 'unitCategory', {}) ;
            feedStream = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
            if isempty(feedStream) || ~isa(feedStream, 'Stream')
                return
            end
            try
                concentration = reshape(double(feedStream.concentration), 1, []) ;
            catch
                return
            end
            if isempty(concentration) || any(~isfinite(concentration))
                return
            end
            nComp = numel(concentration) ;
            defs(nComp) = app.DW_makeOptimizationDecisionDef('', '', 'concentration', NaN, 0, 'Concentration') ;
            for i = 1:nComp
                compLabel = app.DW_getOptimizationComponentLabel(i) ;
                compToken = app.DW_getOptimizationComponentToken(compLabel) ;
                defs(i) = app.DW_makeOptimizationDecisionDef( ...
                    sprintf('C_in_%d', i), sprintf('C_%s,in', compToken), 'concentration', i, concentration(i), 'Concentration') ;
            end
        end

        function def = DW_makeOptimizationDecisionDef(~, variable, displayName, group, speciesIndex, defaultValue, unitCategory)
            magnitude = max(abs(defaultValue), 1e-12) ;
            lowerBound = 0 ;
            upperBound = max(2 * magnitude, magnitude + 1) ;
            def = struct( ...
                'variable', char(string(variable)), ...
                'displayName', char(string(displayName)), ...
                'group', char(string(group)), ...
                'speciesIndex', speciesIndex, ...
                'defaultValue', double(defaultValue), ...
                'lowerBound', lowerBound, ...
                'upperBound', upperBound, ...
                'unitCategory', char(string(unitCategory))) ;
        end

        function label = DW_getOptimizationComponentLabel(app, idx)
            RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
            label = app.getComponentLabels(idx) ;
            label = label{end} ;
            if ~isempty(RS)
                label = app.getComponentLabel(RS, idx) ;
            end
        end

        function token = DW_getOptimizationComponentToken(~, compLabel)
            token = char(string(compLabel)) ;
            if ~isempty(regexp(token, '^C[A-Z]+$', 'once'))
                token = token(2:end) ;
            end
        end

        function DW_refreshOptimizationDecisionTable(app, preserveExisting)
            if nargin < 2
                preserveExisting = false ;
            end
            state = struct('variable', {}, 'use', {}, 'lowerBound', {}, 'upperBound', {}) ;
            if preserveExisting
                state = app.DW_captureOptimizationDecisionState() ;
            end
            defs = app.DW_getOptimizationDecisionDefinitions() ;
            if isempty(defs)
                app.DesignUI.Optimization.DecisionTable.ColumnName = {'Use', 'Variable', 'Lower', 'Upper'} ;
                app.DesignUI.Optimization.DecisionTable.Data = {false, 'Load Feed Stream first', NaN, NaN} ;
                app.DesignUI.Optimization.DecisionTable.UserData = struct( ...
                    'definitions', struct([]), 'isPlaceholder', true, 'inactiveRows', 1) ;
                app.DW_applyOptimizationTableStyles() ;
                return
            end

            inputUnit = app.DW_getOptimizationInputConcentrationUnit() ;
            app.DesignUI.Optimization.DecisionTable.ColumnName = app.DW_buildOptimizationDecisionColumnNames() ;
            data = cell(numel(defs), 4) ;
            for i = 1:numel(defs)
                rowState = app.DW_findOptimizationDecisionState(state, defs(i).variable) ;
                useValue = false ;
                lowerBound = defs(i).lowerBound ;
                upperBound = defs(i).upperBound ;
                if ~isempty(rowState)
                    useValue = rowState.use ;
                    lowerBound = rowState.lowerBound ;
                    upperBound = rowState.upperBound ;
                end
                data(i, :) = {useValue, defs(i).displayName, ...
                    app.DW_convertOptimizationInputFromSI(lowerBound, defs(i), inputUnit), ...
                    app.DW_convertOptimizationInputFromSI(upperBound, defs(i), inputUnit)} ;
            end
            app.DesignUI.Optimization.DecisionTable.Data = data ;
            app.DesignUI.Optimization.DecisionTable.UserData = struct( ...
                'definitions', defs, 'isPlaceholder', false, 'inactiveRows', []) ;
            app.DW_refreshOptimizationContext() ;
        end

        function DW_resetOptimizationTables(app)
            app.DW_refreshOptimizationDecisionTable(false) ;
            app.DW_refreshOptimizationConstraintTable(false) ;
            app.DesignState.lastSolutions.optimizationResult = [] ;
            app.DW_refreshOptimization() ;
        end

        function state = DW_captureOptimizationDecisionState(app)
            state = struct('variable', {}, 'use', {}, 'lowerBound', {}, 'upperBound', {}) ;
            table = app.DesignUI.Optimization.DecisionTable ;
            if isempty(table) || ~isvalid(table) || ~isstruct(table.UserData) || ...
                    ~isfield(table.UserData, 'definitions') || isempty(table.UserData.definitions)
                return
            end
            defs = table.UserData.definitions ;
            data = table.Data ;
            inputUnit = app.DW_getOptimizationInputConcentrationUnit() ;
            if size(data, 1) ~= numel(defs)
                return
            end
            state = repmat(struct('variable', '', 'use', false, 'lowerBound', 0, 'upperBound', 0), numel(defs), 1) ;
            for i = 1:numel(defs)
                state(i).variable = defs(i).variable ;
                state(i).use = logical(data{i, 1}) ;
                state(i).lowerBound = app.DW_convertOptimizationInputToSI(double(data{i, 3}), defs(i), inputUnit) ;
                state(i).upperBound = app.DW_convertOptimizationInputToSI(double(data{i, 4}), defs(i), inputUnit) ;
            end
        end

        function rowState = DW_findOptimizationDecisionState(~, state, variableName)
            rowState = [] ;
            for i = 1:numel(state)
                if strcmp(state(i).variable, variableName)
                    rowState = state(i) ;
                    return
                end
            end
        end

        function DW_applyOptimizationDecisionSnapshot(app, snapshotData)
            if isempty(snapshotData) || ~iscell(snapshotData)
                return
            end
            table = app.DesignUI.Optimization.DecisionTable ;
            if isempty(table) || ~isvalid(table) || ~isstruct(table.UserData) || ...
                    ~isfield(table.UserData, 'definitions') || isempty(table.UserData.definitions)
                return
            end
            defs = table.UserData.definitions ;
            data = table.Data ;
            for i = 1:size(snapshotData, 1)
                if size(snapshotData, 2) < 4
                    continue
                end
                label = char(string(snapshotData{i, 2})) ;
                idx = find(strcmp({defs.displayName}, label), 1) ;
                if isempty(idx)
                    continue
                end
                data{idx, 1} = logical(snapshotData{i, 1}) ;
                if size(snapshotData, 2) >= 5
                    data{idx, 3} = snapshotData{i, 4} ;
                    data{idx, 4} = snapshotData{i, 5} ;
                else
                    data{idx, 3} = snapshotData{i, 3} ;
                    data{idx, 4} = snapshotData{i, 4} ;
                end
            end
            table.Data = data ;
            app.DW_refreshOptimizationContext() ;
        end

        function DW_refreshOptimizationConstraintTable(app, preserveExisting)
            if nargin < 2
                preserveExisting = false ;
            end
            state = struct('metric', {}, 'use', {}, 'speciesLabel', {}, 'type', {}, 'value', {}) ;
            if preserveExisting
                state = app.DW_captureOptimizationConstraintState() ;
            end
            speciesLabels = app.DW_getOptimizationSpeciesLabels() ;
            metricLabels = {'Conversion', 'Selectivity', 'Yield', 'Outlet concentration'} ;
            defaultSpecies = app.DW_getOptimizationDefaultConstraintSpecies(metricLabels, speciesLabels) ;
            if isempty(speciesLabels)
                app.DesignUI.Optimization.ConstraintTable.Data = {false, 'Load ReactionSys first', 'CA', 'Lower bound', NaN} ;
                app.DesignUI.Optimization.ConstraintTable.UserData = struct('isPlaceholder', true) ;
                app.DesignUI.Optimization.ConstraintTable.ColumnFormat = {'logical', {'Load ReactionSys first'}, {'CA'}, {'Lower bound'}, 'short g'} ;
                return
            end

            data = cell(numel(metricLabels), 5) ;
            for i = 1:numel(metricLabels)
                rowState = app.DW_findOptimizationConstraintState(state, metricLabels{i}) ;
                useValue = false ;
                speciesLabel = defaultSpecies{i} ;
                typeValue = 'Lower bound' ;
                metricValue = app.DW_defaultOptimizationConstraintValue(metricLabels{i}) ;
                if ~isempty(rowState)
                    useValue = rowState.use ;
                    speciesLabel = rowState.speciesLabel ;
                    typeValue = rowState.type ;
                    metricValue = rowState.value ;
                end
                if ~any(strcmp(speciesLabels, speciesLabel))
                    speciesLabel = defaultSpecies{i} ;
                end
                data(i, :) = {useValue, metricLabels{i}, speciesLabel, typeValue, metricValue} ;
            end
            app.DesignUI.Optimization.ConstraintTable.Data = data ;
            app.DesignUI.Optimization.ConstraintTable.ColumnFormat = { ...
                'logical', metricLabels, speciesLabels, {'Lower bound', 'Upper bound'}, 'short g'} ;
            app.DesignUI.Optimization.ConstraintTable.UserData = struct( ...
                'isPlaceholder', false, ...
                'speciesLabels', {speciesLabels}, ...
                'metricLabels', {metricLabels}) ;
        end

        function state = DW_captureOptimizationConstraintState(app)
            state = struct('metric', {}, 'use', {}, 'speciesLabel', {}, 'type', {}, 'value', {}) ;
            table = app.DesignUI.Optimization.ConstraintTable ;
            if isempty(table) || ~isvalid(table) || ~iscell(table.Data)
                return
            end
            data = table.Data ;
            state = repmat(struct('metric', '', 'use', false, 'speciesLabel', '', 'type', 'Lower bound', 'value', 0), size(data, 1), 1) ;
            for i = 1:size(data, 1)
                state(i).metric = char(string(data{i, 2})) ;
                state(i).use = logical(data{i, 1}) ;
                state(i).speciesLabel = char(string(data{i, 3})) ;
                state(i).type = char(string(data{i, 4})) ;
                state(i).value = double(data{i, 5}) ;
            end
        end

        function rowState = DW_findOptimizationConstraintState(~, state, metricName)
            rowState = [] ;
            for i = 1:numel(state)
                if strcmp(state(i).metric, metricName)
                    rowState = state(i) ;
                    return
                end
            end
        end

        function DW_applyOptimizationConstraintSnapshot(app, snapshotData)
            if isempty(snapshotData) || ~iscell(snapshotData)
                return
            end
            table = app.DesignUI.Optimization.ConstraintTable ;
            if isempty(table) || ~isvalid(table)
                return
            end
            userData = table.UserData ;
            if isstruct(userData) && app.getStructField(userData, 'isPlaceholder', false)
                return
            end
            data = table.Data ;
            speciesLabels = app.DW_getOptimizationSpeciesLabels() ;
            for i = 1:size(snapshotData, 1)
                if size(snapshotData, 2) < 5
                    continue
                end
                metricLabel = app.DW_normalizeOptimizationConstraintMetric(char(string(snapshotData{i, 2}))) ;
                idx = find(strcmp(data(:, 2), metricLabel), 1) ;
                if isempty(idx)
                    continue
                end
                speciesValue = snapshotData{i, 3} ;
                speciesLabel = app.DW_resolveOptimizationSpeciesLabel(speciesValue, speciesLabels) ;
                if isempty(speciesLabel)
                    speciesLabel = data{idx, 3} ;
                end
                data{idx, 1} = logical(snapshotData{i, 1}) ;
                data{idx, 3} = speciesLabel ;
                data{idx, 4} = char(string(snapshotData{i, 4})) ;
                data{idx, 5} = double(snapshotData{i, 5}) ;
            end
            table.Data = data ;
        end

        function metric = DW_normalizeOptimizationConstraintMetric(~, metric)
            metric = char(string(metric)) ;
            switch metric
                case 'C_out'
                    metric = 'Outlet concentration' ;
            end
        end

        function speciesLabel = DW_resolveOptimizationSpeciesLabel(~, speciesValue, speciesLabels)
            speciesLabel = '' ;
            if isempty(speciesLabels)
                return
            end
            if isnumeric(speciesValue) || islogical(speciesValue)
                idx = round(double(speciesValue)) ;
                if isfinite(idx) && idx >= 1 && idx <= numel(speciesLabels)
                    speciesLabel = speciesLabels{idx} ;
                end
                return
            end
            speciesLabel = char(string(speciesValue)) ;
            if ~any(strcmp(speciesLabels, speciesLabel))
                speciesLabel = '' ;
            end
        end

        function speciesLabels = DW_getOptimizationSpeciesLabels(app)
            RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
            if isempty(RS) || ~isa(RS, 'ReactionSys') || RS.nComponents < 1
                speciesLabels = {} ;
                return
            end
            speciesLabels = app.getReactionComponentLabels(RS) ;
        end

        function defaults = DW_getOptimizationDefaultConstraintSpecies(app, metricLabels, speciesLabels)
            defaults = cell(size(metricLabels)) ;
            if isempty(speciesLabels)
                defaults(:) = {'CA'} ;
                return
            end
            keyIdx = app.DW_getOptimizationSelectorIndex(app.DesignUI.Optimization.KeyReactantDropdown) ;
            desiredIdx = app.DW_getOptimizationSelectorIndex(app.DesignUI.Optimization.DesiredProductDropdown) ;
            for i = 1:numel(metricLabels)
                switch metricLabels{i}
                    case 'Conversion'
                        idx = keyIdx ;
                    otherwise
                        idx = desiredIdx ;
                end
                idx = min(max(idx, 1), numel(speciesLabels)) ;
                defaults{i} = speciesLabels{idx} ;
            end
        end

        function value = DW_defaultOptimizationConstraintValue(~, metricLabel)
            switch metricLabel
                case 'Conversion'
                    value = 0.5 ;
                case 'Selectivity'
                    value = 0.5 ;
                case 'Yield'
                    value = 0.2 ;
                otherwise
                    value = 0 ;
            end
        end

        function idx = DW_getOptimizationSelectorIndex(app, dropdown)
            speciesLabels = app.DW_getOptimizationSpeciesLabels() ;
            if isempty(dropdown) || ~isvalid(dropdown) || isempty(speciesLabels)
                idx = 1 ;
                return
            end
            idx = find(strcmp(speciesLabels, char(string(dropdown.Value))), 1) ;
            if isempty(idx)
                idx = 1 ;
            end
        end

        function DW_applyOptimizationSelectorSnapshot(app, optSnapshot)
            speciesLabels = app.DW_getOptimizationSpeciesLabels() ;
            if isempty(speciesLabels)
                return
            end
            keyLabel = app.DW_resolveOptimizationSpeciesLabel( ...
                app.getStructField(optSnapshot, 'keyReactant', speciesLabels{1}), speciesLabels) ;
            desiredLabel = app.DW_resolveOptimizationSpeciesLabel( ...
                app.getStructField(optSnapshot, 'desiredProduct', speciesLabels{min(2, numel(speciesLabels))}), speciesLabels) ;
            byproductLabel = app.DW_resolveOptimizationSpeciesLabel( ...
                app.getStructField(optSnapshot, 'byproduct', speciesLabels{min(max(numel(speciesLabels), 1), numel(speciesLabels))}), speciesLabels) ;
            if isempty(keyLabel)
                keyLabel = speciesLabels{1} ;
            end
            if isempty(desiredLabel)
                desiredLabel = speciesLabels{min(2, numel(speciesLabels))} ;
            end
            if isempty(byproductLabel)
                byproductLabel = speciesLabels{min(max(numel(speciesLabels), 1), numel(speciesLabels))} ;
            end
            app.DesignUI.Optimization.KeyReactantDropdown.Value = keyLabel ;
            app.DesignUI.Optimization.DesiredProductDropdown.Value = desiredLabel ;
            app.DesignUI.Optimization.ByproductDropdown.Value = byproductLabel ;
        end

        function DW_handleOptimizationSetupChanged(app)
            app.DesignState.lastSolutions.optimizationResult = [] ;
            app.DW_refreshOptimization() ;
        end

        function DW_handleOptimizationObjectiveChanged(app)
            app.DW_refreshOptimizationConstraintTable(true) ;
            app.DW_handleOptimizationSetupChanged() ;
        end

        function DW_handleOptimizationConstraintEdit(app, src, event)
            if ~iscell(src.Data) || ~isstruct(src.UserData) || ...
                    app.getStructField(src.UserData, 'isPlaceholder', false)
                src.Data{event.Indices(1), event.Indices(2)} = event.PreviousData ;
                app.updateStatus('Load a ReactionSys before editing optimization constraints') ;
                return
            end
            app.DesignState.lastSolutions.optimizationResult = [] ;
            app.DW_refreshOptimizationContext() ;
            app.DW_refreshOptimization() ;
        end

        function basis = DW_getOptimizationActiveBasis(~, ~, ~)
            basis = 'concentration' ;
        end

        function tf = DW_familyNeedsBoundary(~, family)
            tf = strcmp(char(string(family)), 'Axial Dispersion') ;
        end

        function tf = DW_familySupportsDeadVolume(~, family)
            family = char(string(family)) ;
            tf = any(strcmp(family, {'CSTR (dead volume)', 'PFR (dead volume)', ...
                'PFR + CSTR (series, dead volume)', 'PFR + CSTR (parallel, dead volume)', ...
                'CSTR + Bypass (dead volume)'})) ;
        end

        function tf = DW_familyNeedsReferenceTau(app, family)
            tf = app.DW_familySupportsDeadVolume(family) ;
        end

        function family = DW_mapLegacyFitFamily(~, family)
            family = char(string(family)) ;
            switch family
                case 'Search best family'
                    family = 'Tanks-in-Series' ;
                case 'PFR + CSTR'
                    family = 'PFR + CSTR (series, dead volume)' ;
                case 'CSTR + Dead Volume'
                    family = 'CSTR (dead volume)' ;
                case 'CSTR + Bypass'
                    family = 'CSTR + Bypass (dead volume)' ;
                case 'CSTR + Dead Volume + Bypass'
                    family = 'CSTR + Bypass (dead volume)' ;
            end
        end

        function result = DW_normalizeFitResultFamilies(app, result)
            if isempty(result) || ~isstruct(result)
                return
            end
            if isfield(result, 'family')
                result.family = app.DW_mapLegacyFitFamily(result.family) ;
            end
            if isfield(result, 'searchBestFamily')
                result.searchBestFamily = app.DW_mapLegacyFitFamily(result.searchBestFamily) ;
            end
            if isfield(result, 'searchResults') && isstruct(result.searchResults)
                for i = 1:numel(result.searchResults)
                    if isfield(result.searchResults(i), 'family')
                        result.searchResults(i).family = app.DW_mapLegacyFitFamily(result.searchResults(i).family) ;
                    end
                end
            end
            if isfield(result, 'searchEntries') && isstruct(result.searchEntries)
                for i = 1:numel(result.searchEntries)
                    if isfield(result.searchEntries(i), 'family')
                        result.searchEntries(i).family = app.DW_mapLegacyFitFamily(result.searchEntries(i).family) ;
                    end
                    if isfield(result.searchEntries(i), 'displayName')
                        result.searchEntries(i).displayName = app.DW_mapLegacyFitFamily(result.searchEntries(i).displayName) ;
                    end
                end
            end
        end

        function flowRate = DW_getFitFlowRate(app)
            flowRate = [] ;
            if isempty(app.RTD_QvField) || ~isvalid(app.RTD_QvField)
                return
            end
            try
                flowRate = app.readInputField(app.RTD_QvField) ;
            catch
                flowRate = [] ;
            end
        end

        function DW_setVisiblePair(~, labelHandle, controlHandle, isVisible)
            state = 'off' ;
            if isVisible
                state = 'on' ;
            end
            if ~isempty(labelHandle) && isvalid(labelHandle)
                labelHandle.Visible = state ;
            end
            if ~isempty(controlHandle) && isvalid(controlHandle)
                controlHandle.Visible = state ;
            end
            if ~isempty(controlHandle) && isvalid(controlHandle) && isprop(controlHandle, 'Enable')
                controlHandle.Enable = state ;
            end
            if ~isempty(controlHandle) && isvalid(controlHandle)
                userData = controlHandle.UserData ;
                if isstruct(userData) && isfield(userData, 'unitDropdown')
                    dd = userData.unitDropdown ;
                    if ~isempty(dd) && isvalid(dd)
                        dd.Visible = state ;
                        dd.Enable = state ;
                    end
                end
            end
        end

        function config = DW_collectFitConstraintConfig(app, includeConstraints)
            if nargin < 2
                includeConstraints = true ;
            end
            config = struct('referenceTau', [], 'totalVolume', [], 'constraints', struct('variable', {}, 'lowerBound', {}, 'upperBound', {})) ;
            if ~includeConstraints
                return
            end
            state = app.DW_getFitConstraintState() ;
            defs = app.DW_fitConstraintDefinitions() ;
            family = app.DesignUI.Fit.FamilyDropdown.Value ;
            relevant = app.DW_relevantFitConstraintVariables(family) ;
            activeScalarKeys = {} ;
            constraints = struct('variable', {}, 'lowerBound', {}, 'upperBound', {}) ;
            for i = 1:numel(defs)
                if ~any(strcmp(defs(i).key, relevant))
                    continue
                end
                if ~logical(state(i).use)
                    continue
                end
                if strcmp(defs(i).mode, 'scalar')
                    if ~isfinite(state(i).minSI) || state(i).minSI <= 0
                        error('Enter a positive value for %s.', defs(i).label) ;
                    end
                    activeScalarKeys{end + 1} = defs(i).key ; %#ok<AGROW>
                    switch defs(i).key
                        case 'referenceTau'
                            config.referenceTau = state(i).minSI ;
                        case 'totalVolume'
                            config.totalVolume = state(i).minSI ;
                    end
                    continue
                end

                lb = state(i).minSI ;
                ub = state(i).maxSI ;
                if ~isfinite(lb) || ~isfinite(ub)
                    error('Enter both Min and Max for %s.', defs(i).label) ;
                end
                if ~(lb < ub)
                    error('Min must be smaller than Max for %s.', defs(i).label) ;
                end
                if any(strcmp(defs(i).category, {'time', 'volume'})) && (lb <= 0 || ub <= 0)
                    error('%s requires positive bounds.', defs(i).label) ;
                end
                if strcmp(defs(i).key, 'N') && (lb <= 0 || ub <= 0)
                    error('N requires positive bounds.') ;
                end
                if strcmp(defs(i).key, 'Bo') && (lb <= 0 || ub <= 0)
                    error('Bo requires positive bounds.') ;
                end
                if strcmp(defs(i).category, 'fraction') && (lb < 0 || ub > 1)
                    error('%s must stay inside the physical range [0, 1].', defs(i).label) ;
                end
                constraints(end + 1) = struct( ... %#ok<AGROW>
                    'variable', defs(i).key, ...
                    'lowerBound', lb, ...
                    'upperBound', ub) ;
            end
            if numel(activeScalarKeys) > 1
                error('Ref. tau_total and Total volume are mutually exclusive. Activate only one of them.') ;
            end
            config.constraints = constraints ;
        end

        function DW_handleFitConstraintTableEdit(app, src, event)
            if ~isstruct(src.UserData) || (isfield(src.UserData, 'isRendering') && src.UserData.isRendering)
                return
            end
            defs = src.UserData.definitions ;
            state = src.UserData.state ;
            relevantRows = src.UserData.relevantRows ;
            rowIndices = src.UserData.rowIndices ;
            localRowIdx = event.Indices(1) ;
            rowIdx = rowIndices(localRowIdx) ;
            colIdx = event.Indices(2) ;
            def = defs(rowIdx) ;

            if ~any(relevantRows == rowIdx)
                src.Data{localRowIdx, colIdx} = event.PreviousData ;
                app.updateStatus('That fit variable is inactive for the selected family') ;
                return
            end

            switch colIdx
                case 1
                    state(rowIdx).use = logical(src.Data{localRowIdx, 1}) ;
                    if strcmp(def.mode, 'scalar') && state(rowIdx).use
                        for otherKey = {'referenceTau', 'totalVolume'}
                            otherIdx = app.DW_findFitConstraintRow(otherKey{1}) ;
                            if otherIdx ~= rowIdx
                                state(otherIdx).use = false ;
                            end
                        end
                    end
                    if strcmp(def.key, 'referenceTau')
                        app.DW_markReferenceTauEdited() ;
                    end
                case 3
                    parsedValue = app.DW_parseFitConstraintDisplayValue(def.category, src.Data{localRowIdx, 3}) ;
                    state(rowIdx).minSI = parsedValue ;
                    state(rowIdx).manual = true ;
                    if strcmp(def.key, 'referenceTau')
                        app.DW_markReferenceTauEdited() ;
                    end
                case 4
                    parsedValue = app.DW_parseFitConstraintDisplayValue(def.category, src.Data{localRowIdx, 4}) ;
                    state(rowIdx).maxSI = parsedValue ;
                    state(rowIdx).manual = true ;
            end

            app.DW_setFitConstraintState(state) ;
            app.DW_refreshFitConstraintTable() ;
        end

        function DW_refreshFitContext(app)
            app.DW_syncDefaultReferenceTau() ;
            family = app.DesignUI.Fit.FamilyDropdown.Value ;
            showBoundary = app.DW_familyNeedsBoundary(family) ;
            showSearchSelector = ~isempty(app.DesignState.fitResult) && strcmp(app.getStructField(app.DesignState.fitResult, 'mode', 'single'), 'search') ;
            app.DW_setVisiblePair(app.DesignUI.Fit.BoundaryLabel, app.DesignUI.Fit.BoundaryDropdown, showBoundary) ;
            app.DW_refreshFitConstraintTable() ;
            if isfield(app.DesignUI.Fit, 'SetupGrid') && ~isempty(app.DesignUI.Fit.SetupGrid) && isvalid(app.DesignUI.Fit.SetupGrid)
                rowHeights = {'fit','fit',0,180,82,34,34,'fit',0} ;
                if showBoundary
                    rowHeights{3} = 'fit' ;
                end
                if showSearchSelector
                    rowHeights{9} = '1x' ;
                end
                app.DesignUI.Fit.SetupGrid.RowHeight = rowHeights ;
            end
            if isfield(app.DesignUI.Fit, 'FamilySearchList') && ~isempty(app.DesignUI.Fit.FamilySearchList) && isvalid(app.DesignUI.Fit.FamilySearchList)
                app.DesignUI.Fit.FamilySearchList.Visible = app.ternary(showSearchSelector, 'on', 'off') ;
                app.DesignUI.Fit.FamilySearchList.Enable = app.ternary(showSearchSelector, 'on', 'off') ;
                parentGrid = app.DesignUI.Fit.FamilySearchList.Parent ;
                if ~isempty(parentGrid) && isvalid(parentGrid)
                    parentGrid.Visible = app.ternary(showSearchSelector, 'on', 'off') ;
                end
            end
        end

        function DW_refreshReactiveContext(app)
            app.DW_syncReactiveVariableNameDefaults() ;
            RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
            hasRS = ~isempty(RS) && isa(RS, 'ReactionSys') ;
            app.DesignUI.Reactive.KeyComponentDropdown.Enable = app.ternary(hasRS, 'on', 'off') ;
            app.DesignUI.Reactive.DesiredProductDropdown.Enable = app.ternary(hasRS, 'on', 'off') ;
            app.DesignUI.Reactive.ByproductDropdown.Enable = app.ternary(hasRS, 'on', 'off') ;
            if ~hasRS
                return
            end

            nComp = max(RS.nComponents, 1) ;
            app.DesignUI.Reactive.KeyComponentDropdown.Enable = app.ternary(nComp >= 1, 'on', 'off') ;
            app.DesignUI.Reactive.DesiredProductDropdown.Enable = app.ternary(nComp >= 2, 'on', 'off') ;
            app.DesignUI.Reactive.ByproductDropdown.Enable = app.ternary(nComp >= 3, 'on', 'off') ;
        end

        function DW_syncReactiveVariableNameDefaults(app)
            rsLoaded = ~isempty(app.getStructField(app.DesignState.reactionSpec, 'rs', [])) ;
            feedLoaded = ~isempty(app.getStructField(app.DesignState.reactionSpec, 'feedStream', [])) ;

            if ~rsLoaded && ~isempty(app.RTD_RSNameField) && isvalid(app.RTD_RSNameField)
                rtdRSName = strtrim(char(string(app.RTD_RSNameField.Value))) ;
                currentRSName = strtrim(char(string(app.DesignUI.Reactive.RSNameField.Value))) ;
                if ~isempty(rtdRSName) && (isempty(currentRSName) || strcmp(currentRSName, 'RS'))
                    app.DesignUI.Reactive.RSNameField.Value = rtdRSName ;
                end
            end

            if ~feedLoaded && ~isempty(app.RTD_StreamNameField) && isvalid(app.RTD_StreamNameField)
                rtdStreamName = strtrim(char(string(app.RTD_StreamNameField.Value))) ;
                currentStreamName = strtrim(char(string(app.DesignUI.Reactive.StreamNameField.Value))) ;
                if ~isempty(rtdStreamName) && (isempty(currentStreamName) || strcmp(currentStreamName, 'Feed'))
                    app.DesignUI.Reactive.StreamNameField.Value = rtdStreamName ;
                end
            end
        end

        function txt = DW_getReactiveMetricFormulaText(app) %#ok<MANU>
            txt = ['$Selectivity = \frac{C_{\mathrm{desired}}}{C_{\mathrm{in,key}} - C_{\mathrm{out,key}}}' ...
                '\qquad Yield = \frac{C_{\mathrm{desired}}}{C_{\mathrm{in,key}}}$'] ;
        end

        function DW_applyOptimizationTableStyles(app)
            table = app.DesignUI.Optimization.DecisionTable ;
            try
                removeStyle(table) ;
            catch
            end
            if isempty(table) || ~isvalid(table) || ~isstruct(table.UserData)
                return
            end
            inactiveRows = app.getStructField(table.UserData, 'inactiveRows', []) ;
            try
                if isempty(inactiveRows)
                    return
                end
                style = uistyle('BackgroundColor', [0.94 0.94 0.94], 'FontColor', [0.45 0.45 0.45]) ;
                addStyle(table, style, 'row', inactiveRows) ;
            catch
            end
        end

        function DW_setOptimizationDropdownEnabled(~, labelHandle, dropdownHandle, isEnabled)
            labelColor = [0.15 0.15 0.15] ;
            dropdownState = 'on' ;
            if ~isEnabled
                labelColor = [0.55 0.55 0.55] ;
                dropdownState = 'off' ;
            end
            if ~isempty(labelHandle) && isvalid(labelHandle)
                labelHandle.FontColor = labelColor ;
            end
            if ~isempty(dropdownHandle) && isvalid(dropdownHandle)
                dropdownHandle.Enable = dropdownState ;
            end
        end

        function DW_refreshOptimizationContext(app)
            table = app.DesignUI.Optimization.DecisionTable ;
            if isempty(table) || ~isvalid(table)
                return
            end
            app.DesignUI.Optimization.InputUnitsNotice.Text = app.DW_buildOptimizationInputUnitNotice() ;

            objective = app.DesignUI.Optimization.ObjectiveDropdown.Value ;
            hasSpecies = ~isempty(app.DW_getOptimizationSpeciesLabels()) ;
            showKey = strcmp(objective, 'Max conversion') || any(strcmp(objective, {'Max selectivity', 'Max yield'})) ;
            showDesired = any(strcmp(objective, {'Max selectivity', 'Max yield', 'Max outlet concentration'})) ;
            showByproduct = strcmp(objective, 'Min outlet concentration') ;
            app.DW_setOptimizationDropdownEnabled(app.DesignUI.Optimization.KeyReactantLabel, ...
                app.DesignUI.Optimization.KeyReactantDropdown, showKey && hasSpecies) ;
            app.DW_setOptimizationDropdownEnabled(app.DesignUI.Optimization.DesiredProductLabel, ...
                app.DesignUI.Optimization.DesiredProductDropdown, showDesired && hasSpecies) ;
            app.DW_setOptimizationDropdownEnabled(app.DesignUI.Optimization.ByproductLabel, ...
                app.DesignUI.Optimization.ByproductDropdown, showByproduct && hasSpecies) ;

            userData = table.UserData ;
            if ~isstruct(userData) || app.getStructField(userData, 'isPlaceholder', false)
                if ~isstruct(userData)
                    userData = struct() ;
                end
                if ~isfield(userData, 'inactiveRows')
                    userData.inactiveRows = 1:size(table.Data, 1) ;
                end
                table.UserData = userData ;
                app.DW_applyOptimizationTableStyles() ;
                app.DesignUI.Optimization.RunButton.Enable = 'off' ;
                return
            end

            data = table.Data ;
            defs = app.getStructField(userData, 'definitions', struct([])) ;
            if size(data, 1) ~= numel(defs)
                app.DesignUI.Optimization.RunButton.Enable = 'off' ;
                return
            end
            activeBasis = app.DW_getOptimizationActiveBasis(defs, data) ;
            inactiveMask = false(1, numel(defs)) ;
            table.Data = data ;
            userData.inactiveRows = find(inactiveMask) ;
            userData.activeBasis = activeBasis ;
            table.UserData = userData ;
            app.DW_applyOptimizationTableStyles() ;
            activeRows = arrayfun(@(i) logical(data{i, 1}), 1:size(data, 1)) ;
            hasRS = ~isempty(app.getStructField(app.DesignState.reactionSpec, 'rs', [])) ;
            hasFeed = ~isempty(app.getStructField(app.DesignState.reactionSpec, 'feedStream', [])) ;
            app.DesignUI.Optimization.RunButton.Enable = app.ternary(any(activeRows) && hasRS && hasFeed, 'on', 'off') ;
        end

        function DW_handleDecisionTableEdit(app, src, event)
            if ~isstruct(src.UserData) || app.getStructField(src.UserData, 'isPlaceholder', false)
                src.Data{event.Indices(1), event.Indices(2)} = event.PreviousData ;
                app.updateStatus('Load a Feed Stream before editing optimization variables') ;
                return
            end
            defs = app.getStructField(src.UserData, 'definitions', struct([])) ;
            rowIdx = event.Indices(1) ;
            if rowIdx > numel(defs)
                src.Data{rowIdx, event.Indices(2)} = event.PreviousData ;
                return
            end
            colIdx = event.Indices(2) ;
            if colIdx >= 3
                currentValue = double(src.Data{rowIdx, colIdx}) ;
                if ~isfinite(currentValue)
                    src.Data{rowIdx, colIdx} = event.PreviousData ;
                    app.updateStatus('Optimization bounds must be finite numeric values') ;
                    return
                end
            end
            inputUnit = app.DW_getOptimizationInputConcentrationUnit() ;
            lowerValueSI = app.DW_convertOptimizationInputToSI(double(src.Data{rowIdx, 3}), defs(rowIdx), inputUnit) ;
            upperValueSI = app.DW_convertOptimizationInputToSI(double(src.Data{rowIdx, 4}), defs(rowIdx), inputUnit) ;
            if lowerValueSI > upperValueSI
                src.Data{rowIdx, 4} = src.Data{rowIdx, 3} ;
            end
            app.DesignState.lastSolutions.optimizationResult = [] ;
            app.DW_refreshOptimizationContext() ;
            app.DW_refreshOptimization() ;
        end

        function out = ternary(~, condition, trueValue, falseValue)
            if condition
                out = trueValue ;
            else
                out = falseValue ;
            end
        end

        function DW_refreshAll(app)
            app.DW_refreshFitContext() ;
            app.DW_refreshReactiveContext() ;
            app.DW_refreshOptimizationContext() ;
            app.DW_refreshFit() ;
            app.DW_refreshReactive() ;
            app.DW_refreshOptimization() ;
        end

        function DW_refreshFit(app)
            result = app.DesignState.fitResult ;
            timeDD = app.getDisplayControl('DesignFit', 'time') ;
            volumeDD = app.getDisplayControl('DesignFit', 'volume') ;
            if isempty(result)
                app.DW_showFitResultPresentation('single') ;
                app.DesignUI.Fit.ParameterTable.Data = cell(0, 2) ;
                app.DW_clearFitResultFields() ;
                app.DesignUI.Fit.SummaryLabel.Text = 'Awaiting RTD fit.' ;
                app.DesignUI.Fit.ParameterTable.ColumnName = {'Parameter', 'Value'} ;
                if ~isempty(app.DesignUI.Fit.FamilySearchList) && isvalid(app.DesignUI.Fit.FamilySearchList)
                    app.clearMultiSelectListbox(app.DesignUI.Fit.FamilySearchList) ;
                end
                cla(app.DesignUI.Fit.CompareAxes) ;
                app.DW_applyFitAxesLabels('Input vs fitted E(t)') ;
                return
            end
            resultMode = app.getStructField(result, 'mode', 'single') ;
            if strcmp(resultMode, 'search')
                app.DW_showFitResultPresentation('search') ;
                app.DesignUI.Fit.SummaryLabel.Text = app.buildFitSummaryTextWithUnits(result, timeDD) ;
                app.DesignUI.Fit.ParameterTable.ColumnName = app.DW_fitSearchColumnNames(timeDD) ;
                app.DesignUI.Fit.ParameterTable.Data = app.DW_buildFitSearchSummaryTable(result, timeDD) ;
                app.DesignUI.Fit.ParameterTable.Tooltip = app.buildTooltipFromColumns( ...
                    'Comparison across fitted families sorted by fit quality.', ...
                    app.DesignUI.Fit.ParameterTable.ColumnName) ;
                app.DW_applyFitAxesLabels('Input vs fitted E(t) by family') ;
                app.DW_refreshFitSearchSelector(result) ;
                app.DW_refreshFitSearchPlot(result) ;
                return
            end

            app.DW_showFitResultPresentation('single') ;
            app.DesignUI.Fit.SummaryLabel.Text = app.buildFitSummaryTextWithUnits(result, timeDD) ;
            app.DesignUI.Fit.ParameterTable.Data = cell(0, 2) ;
            app.DW_populateFitResultFields(result, timeDD, volumeDD) ;
            if ~isempty(app.DesignUI.Fit.FamilySearchList) && isvalid(app.DesignUI.Fit.FamilySearchList)
                app.clearMultiSelectListbox(app.DesignUI.Fit.FamilySearchList) ;
                app.DesignUI.Fit.FamilySearchList.UserData = struct('familyNames', {{}}, 'pendingSelection', []) ;
            end
            cla(app.DesignUI.Fit.CompareAxes) ;
            inputT = app.convertOutputVectorFromTime('time', result.inputRTD.t, timeDD) ;
            inputE = app.convertOutputVectorFromTime('timeInverse', result.inputRTD.Et, timeDD) ;
            fittedT = app.convertOutputVectorFromTime('time', result.fittedRTD.t, timeDD) ;
            fittedE = app.convertOutputVectorFromTime('timeInverse', result.fittedRTD.Et, timeDD) ;
            plot(app.DesignUI.Fit.CompareAxes, inputT, inputE, 'k-', 'LineWidth', 1.2) ; hold(app.DesignUI.Fit.CompareAxes, 'on') ;
            plot(app.DesignUI.Fit.CompareAxes, fittedT, fittedE, 'b--', 'LineWidth', 1.2) ; hold(app.DesignUI.Fit.CompareAxes, 'off') ;
            legend(app.DesignUI.Fit.CompareAxes, {'Input', 'Fitted'}, 'Location', 'best') ; grid(app.DesignUI.Fit.CompareAxes, 'on') ;
            app.DW_applyFitAxesLabels('Input vs fitted E(t)') ;
        end

        function DW_refreshFitSearchSelector(app, result)
            if isempty(app.DesignUI.Fit.FamilySearchList) || ~isvalid(app.DesignUI.Fit.FamilySearchList)
                return
            end
            familyNames = {result.searchResults.family} ;
            listbox = app.DesignUI.Fit.FamilySearchList ;
            previousSelection = app.captureListboxSelection(listbox) ;
            listbox.Items = familyNames ;
            listbox.ItemsData = 1:numel(familyNames) ;
            pending = [] ;
            if isstruct(listbox.UserData) && isfield(listbox.UserData, 'pendingSelection')
                pending = listbox.UserData.pendingSelection ;
            end
            if isempty(pending)
                pending = previousSelection ;
            end
            if isempty(pending)
                pending = app.getStructField(result, 'searchSelection', 1) ;
            end
            app.restoreListboxSelection(listbox, pending) ;
            if isempty(listbox.Value) && ~isempty(listbox.ItemsData)
                listbox.Value = listbox.ItemsData(1) ;
            end
            listbox.UserData = struct('familyNames', {familyNames}, 'pendingSelection', []) ;
        end

        function DW_handleFitSearchSelection(app)
            result = app.DesignState.fitResult ;
            if isempty(result) || ~strcmp(app.getStructField(result, 'mode', 'single'), 'search')
                return
            end
            app.DW_refreshFitSearchPlot(result) ;
        end

        function DW_refreshFitSearchPlot(app, result)
            timeDD = app.getDisplayControl('DesignFit', 'time') ;
            selectedIdx = app.captureListboxSelection(app.DesignUI.Fit.FamilySearchList) ;
            if isempty(selectedIdx)
                selectedIdx = app.getStructField(result, 'searchSelection', 1) ;
                if ~isempty(app.DesignUI.Fit.FamilySearchList.ItemsData)
                    app.restoreListboxSelection(app.DesignUI.Fit.FamilySearchList, selectedIdx) ;
                end
            end
            selectedIdx = selectedIdx(selectedIdx >= 1 & selectedIdx <= numel(result.searchResults)) ;
            if isempty(selectedIdx)
                selectedIdx = 1 ;
            end
            cla(app.DesignUI.Fit.CompareAxes) ;
            inputT = app.convertOutputVectorFromTime('time', result.inputRTD.t, timeDD) ;
            inputE = app.convertOutputVectorFromTime('timeInverse', result.inputRTD.Et, timeDD) ;
            plot(app.DesignUI.Fit.CompareAxes, inputT, inputE, 'k-', 'LineWidth', 1.4) ;
            hold(app.DesignUI.Fit.CompareAxes, 'on') ;
            legendEntries = {'Input'} ;
            colors = lines(max(numel(selectedIdx), 1)) ;
            for i = 1:numel(selectedIdx)
                fitItem = result.searchResults(selectedIdx(i)) ;
                fittedT = app.convertOutputVectorFromTime('time', fitItem.fittedRTD.t, timeDD) ;
                fittedE = app.convertOutputVectorFromTime('timeInverse', fitItem.fittedRTD.Et, timeDD) ;
                plot(app.DesignUI.Fit.CompareAxes, fittedT, fittedE, '--', ...
                    'LineWidth', 1.2, 'Color', colors(i, :)) ;
                legendEntries{end + 1} = fitItem.family ; %#ok<AGROW>
            end
            hold(app.DesignUI.Fit.CompareAxes, 'off') ;
            legend(app.DesignUI.Fit.CompareAxes, legendEntries, 'Location', 'best') ;
            grid(app.DesignUI.Fit.CompareAxes, 'on') ;
            app.DW_applyFitAxesLabels('Input vs fitted E(t) by family') ;
        end

        function clearMultiSelectListbox(~, listbox)
            if isempty(listbox) || ~isvalid(listbox)
                return
            end
            try
                listbox.Value = {} ;
            catch
            end
            listbox.Items = {} ;
            if isprop(listbox, 'ItemsData')
                listbox.ItemsData = [] ;
            end
        end

        function DW_markReferenceTauEdited(app)
            table = app.DW_getPrimaryFitConstraintTable() ;
            if isempty(table) || ~isvalid(table) || ~isstruct(table.UserData)
                return
            end
            userData = table.UserData ;
            if ~isstruct(userData)
                return
            end
            if isfield(userData, 'suspendReferenceTauTracking') && userData.suspendReferenceTauTracking
                return
            end
            state = app.DW_getFitConstraintState() ;
            idx = app.DW_findFitConstraintRow('referenceTau') ;
            state(idx).manual = true ;
            state(idx).defaultInitialized = true ;
            app.DW_setFitConstraintState(state) ;
        end

        function DW_beginReferenceTauProgrammaticUpdate(app)
            tables = app.DW_getFitConstraintTableHandles() ;
            if isempty(tables)
                return
            end
            for i = 1:numel(tables)
                table = tables{i} ;
                userData = table.UserData ;
                if ~isstruct(userData)
                    userData = struct() ;
                end
                userData.suspendReferenceTauTracking = true ;
                table.UserData = userData ;
            end
        end

        function DW_endReferenceTauProgrammaticUpdate(app, manualOverride)
            tables = app.DW_getFitConstraintTableHandles() ;
            if isempty(tables)
                return
            end
            for i = 1:numel(tables)
                table = tables{i} ;
                userData = table.UserData ;
                if ~isstruct(userData)
                    userData = struct() ;
                end
                userData.suspendReferenceTauTracking = false ;
                table.UserData = userData ;
            end
            state = app.DW_getFitConstraintState() ;
            idx = app.DW_findFitConstraintRow('referenceTau') ;
            state(idx).manual = logical(manualOverride) ;
            state(idx).defaultInitialized = true ;
            app.DW_setFitConstraintState(state) ;
        end

        function DW_syncDefaultReferenceTau(app)
            state = app.DW_getFitConstraintState() ;
            idx = app.DW_findFitConstraintRow('referenceTau') ;
            if isempty(idx)
                return
            end
            if state(idx).manual
                return
            end

            defaultTauSI = 1 ;
            if ~isempty(app.rtd) && isa(app.rtd, 'RTD') && ~isempty(app.rtd.tau) && isfinite(app.rtd.tau) && app.rtd.tau > 0
                defaultTauSI = ceil(app.rtd.tau) ;
            end

            state(idx).minSI = defaultTauSI ;
            state(idx).defaultInitialized = true ;
            state(idx).defaultValueSI = defaultTauSI ;
            state(idx).manual = false ;
            app.DW_setFitConstraintState(state) ;
        end

        function DW_refreshReactive(app)
            app.DW_refreshChemicalSelectors() ;
            app.DW_refreshReactiveContext() ;
            result = app.getStructField(app.DesignState.lastSolutions, 'reactiveResult', []) ;
            concDD = app.getDisplayControl('DesignReactive', 'concentration') ;
            if isempty(result)
                app.DesignUI.Reactive.ResultTable.Data = cell(0, 4) ;
                app.DesignUI.Reactive.CoutTable.Data = cell(0, 6) ;
                app.DesignUI.Reactive.CoutTable.ColumnName = app.DW_buildReactiveCoutColumnNames(concDD) ;
                app.DesignUI.Reactive.SummaryLabel.Text = app.DW_getReactiveMetricFormulaText() ;
                cla(app.DesignUI.Reactive.Axes) ;
                [~, titleText, yLabel] = app.DW_getReactiveMetricSpec() ;
                title(app.DesignUI.Reactive.Axes, titleText) ;
                ylabel(app.DesignUI.Reactive.Axes, yLabel) ;
                grid(app.DesignUI.Reactive.Axes, 'on') ;
                return
            end
            RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
            feedStream = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
            C0 = [] ;
            if ~isempty(feedStream) && isa(feedStream, 'Stream')
                C0 = feedStream.concentration(:)' ;
            end

            app.DesignUI.Reactive.ResultTable.Data = app.DW_buildReactiveSummaryTable(result) ;
            app.DesignUI.Reactive.CoutTable.ColumnName = app.DW_buildReactiveCoutColumnNames(concDD) ;
            app.DesignUI.Reactive.CoutTable.Data = app.DW_buildReactiveCoutTable(result, RS, C0, concDD) ;
            app.DesignUI.Reactive.SummaryLabel.Text = app.DW_getReactiveMetricFormulaText() ;
            app.DW_refreshReactivePlot(result) ;
        end

        function DW_refreshOptimization(app)
            app.DW_refreshOptimizationContext() ;
            result = app.getStructField(app.DesignState.lastSolutions, 'optimizationResult', []) ;
            if isempty(result)
                app.DesignUI.Optimization.ComparisonTable.Data = cell(0, 3) ;
                app.DesignUI.Optimization.ModelTable.Data = cell(0, 9) ;
                app.DesignUI.Optimization.ModelTable.ColumnName = app.DW_buildOptimizationModelColumnNames() ;
                app.DesignUI.Optimization.SummaryLabel.Text = 'Awaiting optimization.' ;
            else
                app.DesignUI.Optimization.SummaryLabel.Text = result.summaryText ;
                app.DesignUI.Optimization.ComparisonTable.Data = app.DW_buildOptimizationComparisonTable(result) ;
                app.DesignUI.Optimization.ModelTable.ColumnName = app.DW_buildOptimizationModelColumnNames() ;
                app.DesignUI.Optimization.ModelTable.Data = app.DW_buildOptimizationModelTable(result) ;
            end
        end

        function DW_refreshChemicalSelectors(app)
            RS = app.getStructField(app.DesignState.reactionSpec, 'rs', []) ;
            if isempty(RS)
                app.DW_refreshOptimizationConstraintTable(false) ;
                app.DW_refreshReactiveContext() ;
                app.DW_refreshOptimizationContext() ;
                return
            end
            nComp = RS.nComponents ;
            labels = app.getReactionComponentLabels(RS) ;
            itemsData = 1:nComp ;
            app.DesignUI.Reactive.KeyComponentDropdown.Items = labels ;
            app.DesignUI.Reactive.KeyComponentDropdown.ItemsData = itemsData ;
            app.DesignUI.Reactive.DesiredProductDropdown.Items = labels ;
            app.DesignUI.Reactive.DesiredProductDropdown.ItemsData = itemsData ;
            app.DesignUI.Reactive.ByproductDropdown.Items = labels ;
            app.DesignUI.Reactive.ByproductDropdown.ItemsData = itemsData ;
            app.DesignUI.Optimization.KeyReactantDropdown.Items = labels ;
            app.DesignUI.Optimization.DesiredProductDropdown.Items = labels ;
            app.DesignUI.Optimization.ByproductDropdown.Items = labels ;

            keyComponentIndex = app.DW_resolveReactiveKeyComponentIndex(RS, ...
                app.DesignState.reactionSpec.keyComponentIndex) ;
            app.DesignState.reactionSpec.keyComponentIndex = keyComponentIndex ;
            app.DesignUI.Reactive.KeyComponentDropdown.Value = keyComponentIndex ;
            app.DesignUI.Reactive.DesiredProductDropdown.Value = min(max(app.DesignState.reactionSpec.desiredProductIndex, 1), nComp) ;
            app.DesignUI.Reactive.ByproductDropdown.Value = min(max(app.DesignState.reactionSpec.byproductIndex, 1), nComp) ;
            app.DesignUI.Optimization.KeyReactantDropdown.Value = labels{keyComponentIndex} ;
            app.DesignUI.Optimization.DesiredProductDropdown.Value = labels{min(max(app.DesignState.reactionSpec.desiredProductIndex, 1), nComp)} ;
            app.DesignUI.Optimization.ByproductDropdown.Value = labels{min(max(app.DesignState.reactionSpec.byproductIndex, 1), nComp)} ;
            app.DW_refreshOptimizationConstraintTable(true) ;
            app.DW_refreshReactiveContext() ;
            app.DW_refreshOptimizationContext() ;
        end

        function keyComponentIndex = DW_resolveReactiveKeyComponentIndex(app, RS, currentIndex)
            nComp = RS.nComponents ;
            keyComponentIndex = min(max(currentIndex, 1), nComp) ;
            feedStream = app.getStructField(app.DesignState.reactionSpec, 'feedStream', []) ;
            if isempty(feedStream) || ~isa(feedStream, 'Stream')
                return
            end

            functionalIndices = app.getFunctionalReactantIndices(RS, feedStream.concentration(:)') ;
            if isempty(functionalIndices)
                return
            end
            if ~any(functionalIndices == keyComponentIndex)
                keyComponentIndex = functionalIndices(1) ;
            end
        end

        function label = getComponentLabel(app, RS, idx)
            label = app.getComponentLabels(idx) ;
            label = label{end} ;
            try
                if ~isempty(RS.componentNames) && numel(RS.componentNames) >= idx
                    label = char(string(RS.componentNames{idx})) ;
                end
            catch
            end
        end

        function showDetailedError(app, ME, titleText)
            try
                reportText = getReport(ME, 'extended', 'hyperlinks', 'off') ;
                fprintf(2, '\n[%s]\n%s\n', titleText, reportText) ;
            catch
            end

            detail = ME.message ;
            if ~isempty(ME.stack)
                topFrame = ME.stack(1) ;
                detail = sprintf('%s\n\nSource: %s (line %d)', ...
                    ME.message, topFrame.name, topFrame.line) ;
            end

            uialert(app.UIFigure, detail, titleText, 'Interpreter', 'none') ;
        end
    end

    methods (Static, Access = private)
        function Bo = compute_Bo_from_variance(sigma2_theta, bcType, rtdObj)
            if nargin < 3
                rtdObj = [] ;
            end

            switch bcType
                case 'open-open'
                    if isfinite(sigma2_theta) && sigma2_theta > 0
                        tauSpace = NonIdealReactorApp.extractOpenOpenTauSpace(rtdObj) ;
                        if ~isnan(tauSpace) && ~isempty(rtdObj) && isprop(rtdObj, 'sigma2') && isfinite(rtdObj.sigma2)
                            sigmaSpace = rtdObj.sigma2 / max(tauSpace^2, eps) ;
                            Bo = NonIdealReactorApp.solve_open_open_bo_from_space_variance(sigmaSpace) ;
                        else
                            Bo = NonIdealReactorApp.solve_open_open_bo_from_mean_variance(sigma2_theta) ;
                        end
                    else
                        Bo = NaN ;
                    end

                case 'closed-closed'
                    Pe = NonIdealReactorApp.solve_closed_closed_pe_from_variance(sigma2_theta) ;
                    Bo = 1 / Pe ;

                otherwise
                    Bo = NaN ;
            end

            if isfinite(Bo)
                Bo = max(Bo, 1e-8) ;
            end
        end

        function tauSpace = extractOpenOpenTauSpace(rtdObj)
            tauSpace = NaN ;
            if isempty(rtdObj) || ~isprop(rtdObj, 'modelInfo') || ~isstruct(rtdObj.modelInfo)
                return
            end
            if isfield(rtdObj.modelInfo, 'tauSpace') && isfinite(rtdObj.modelInfo.tauSpace) && rtdObj.modelInfo.tauSpace > 0
                tauSpace = rtdObj.modelInfo.tauSpace ;
            end
        end

        function Bo = solve_open_open_bo_from_space_variance(sigmaSpace)
            if ~(isfinite(sigmaSpace) && sigmaSpace > 0)
                error('Open-open variance must be positive and finite.') ;
            end
            Bo = (-1 + sqrt(1 + 8 * sigmaSpace)) / 8 ;
        end

        function Bo = solve_open_open_bo_from_mean_variance(sigmaMean)
            if ~(isfinite(sigmaMean) && sigmaMean > 0 && sigmaMean < 2)
                error('For open-open dispersion model, sigmaTheta2 must satisfy 0 < sigmaTheta2 < 2.') ;
            end

            a = 4 * sigmaMean - 8 ;
            b = 4 * sigmaMean - 2 ;
            c = sigmaMean ;
            rootsVec = roots([a b c]) ;
            rootsVec = rootsVec(abs(imag(rootsVec)) < 1e-10) ;
            rootsVec = real(rootsVec) ;
            rootsVec = rootsVec(rootsVec > 0) ;

            if isempty(rootsVec)
                error('Could not recover a physical open-open Bo from the RTD variance.') ;
            end

            Bo = min(rootsVec) ;
        end

        function Pe = solve_closed_closed_pe_from_variance(sigma2_theta)
            if ~(isfinite(sigma2_theta) && sigma2_theta > 0 && sigma2_theta < 1)
                error('For closed-closed dispersion model, sigmaTheta2 must satisfy 0 < sigmaTheta2 < 1.') ;
            end

            f = @(Pe_val) 2 ./ Pe_val - 2 ./ Pe_val.^2 .* (1 - exp(-Pe_val)) - sigma2_theta ;
            lowerBound = 1e-8 ;
            upperBound = 1 ;
            fLow = f(lowerBound) ;
            fHigh = f(upperBound) ;

            while ~isfinite(fHigh) || sign(fLow) == sign(fHigh)
                upperBound = upperBound * 2 ;
                if upperBound > 1e8
                    error('Could not bracket a physical Peclet root for the current variance.') ;
                end
                fHigh = f(upperBound) ;
            end

            Pe = fzero(f, [lowerBound, upperBound]) ;
        end

        function showTechnicalGuide(~)
            docsDir = fullfile(fileparts(mfilename('fullpath')), 'docs') ;
            guidePath = fullfile(docsDir, 'TechnicalChapter.html') ;

            try
                if ~isfile(guidePath)
                    error('NonIdealReactorApp:MissingTechnicalGuide', ...
                        'Technical guide HTML file not found.') ;
                end

                fig = uifigure('Name', 'Help - Technical Guide', ...
                    'Position', [120 60 980 740], ...
                    'Resize', 'on') ;
                uihtml(fig, ...
                    'HTMLSource', guidePath, ...
                    'Position', [10 10 960 720]) ;
            catch
                fallbackPath = fullfile(docsDir, 'TechnicalChapter.md') ;
                helpText = { ...
                    'Formatted technical guide not available.', ...
                    '', ...
                    ['Expected file: ' guidePath], ...
                    '', ...
                    ['Reference markdown: ' fallbackPath], ...
                    '', ...
                    'Opening the HTML guide in the system browser if possible.'} ;
                try
                    web(guidePath, '-browser') ;
                catch
                end

                fig = uifigure('Name', 'Help - Technical Guide', ...
                    'Position', [180 120 700 220], ...
                    'Resize', 'off') ;
                uitextarea(fig, ...
                    'Value', helpText, ...
                    'Position', [10 10 680 200], ...
                    'Editable', 'off', ...
                    'FontName', 'Consolas', ...
                    'FontSize', 12) ;
            end
        end

        % -----------------------------------------------------------------
        % Help dialog
        % -----------------------------------------------------------------
        function showHelp(~)
            docsDir = fullfile(fileparts(mfilename('fullpath')), 'docs') ;
            guidePath = fullfile(docsDir, 'UserGuide.html') ;

            try
                if ~isfile(guidePath)
                    error('NonIdealReactorApp:MissingUserGuide', ...
                        'User guide HTML file not found.') ;
                end

                fig = uifigure('Name', 'Help - NonIdealReactorApp', ...
                    'Position', [120 60 980 740], ...
                    'Resize', 'on') ;
                uihtml(fig, ...
                    'HTMLSource', guidePath, ...
                    'Position', [10 10 960 720]) ;
            catch
                fallbackPath = fullfile(docsDir, 'UserGuide.md') ;
                helpText = { ...
                    'Formatted user guide not available.', ...
                    '', ...
                    ['Expected file: ' guidePath], ...
                    '', ...
                    ['Reference markdown: ' fallbackPath], ...
                    '', ...
                    'Opening the HTML guide in the system browser if possible.'} ;
                try
                    web(guidePath, '-browser') ;
                catch
                end

                fig = uifigure('Name', 'Help - NonIdealReactorApp', ...
                    'Position', [180 120 700 220], ...
                    'Resize', 'off') ;
                uitextarea(fig, ...
                    'Value', helpText, ...
                    'Position', [10 10 680 200], ...
                    'Editable', 'off', ...
                    'FontName', 'Consolas', ...
                    'FontSize', 12) ;
            end
            return
            helpText = { ...
                'NonIdealReactorApp — Quick Guide', ...
                '==================================', ...
                '', ...
                'Tab 1: RTD Analysis', ...
                '  Generate or import E(t) from analytical expression, experimental', ...
                '  data (pulse/step), Excel file or manual table.', ...
                '  Computes tau, variance, skewness, equivalent N and effective volume.', ...
                '', ...
                'Tab 2: Prediction Models', ...
                '  Predicts conversion with Segregation and Maximum Mixedness.', ...
                '  Requires RTD generated in Tab 1.', ...
                '  Supports 6 kinetics: 1st/2nd Order, Michaelis-Menten,', ...
                '  Reversible, Parallel and Custom Rate Law.', ...
                '', ...
                'Tab 3: Tanks-in-Series (TIS)', ...
                '  Model of N equal CSTRs in series.', ...
                '  Computes N from variance or accepts manual input.', ...
                '', ...
                'Tab 4: Dispersion Model', ...
                '  Reactor with axial dispersion (Bo = D_e/(uL) = 1/Pe).', ...
                '  Boundary conditions: open-open or closed-closed (Danckwerts).', ...
                '  Smaller Bo and larger Pe approach PFR; larger Bo approaches strong backmixing.', ...
                '', ...
                '==================================', ...
                'Internal units: SI (s, m^3, mol/m^3, m^3/s, Pa, K)', ...
                'Use the Unit Converter to convert.', ...
                '', ...
                'Author: Javier Berenguer Sabater (TFG, March 2026)', ...
                'Based on ReactorApp by Isabela Fons.'} ;

            fig = uifigure('Name', 'Help — NonIdealReactorApp', ...
                'Position', [200 100 520 560], ...
                'Resize', 'off') ;
            uitextarea(fig, ...
                'Value', helpText, ...
                'Position', [10 10 500 540], ...
                'Editable', 'off', ...
                'FontName', 'Consolas', ...
                'FontSize', 12) ;
        end

    end

end

function nonIdealReactorAppRestartTimerFcn(~, rootDir, hardMode, restartTag)
try
    if nargin >= 2 && ~isempty(rootDir)
        addpath(rootDir) ;
    end

    if hardMode
        clear functions ;
        clear classes ;
        rehash ;
    end

    NonIdealReactorApp() ;
catch ME
    try
        errordlg({ ...
            'Restart failed. Launch NonIdealReactorApp manually from the MATLAB Command Window.', ...
            '', ...
            ME.message}, ...
            ternaryRestartTitle(hardMode)) ;
    catch
        disp(getReport(ME, 'extended', 'hyperlinks', 'off')) ;
    end
end

try
    staleTimers = timerfindall('Tag', restartTag) ;
    if ~isempty(staleTimers)
        stop(staleTimers) ;
    end
catch
end
end

function titleText = ternaryRestartTitle(hardMode)
if hardMode
    titleText = 'Hard Restart Error' ;
else
    titleText = 'Restart Error' ;
end
end

