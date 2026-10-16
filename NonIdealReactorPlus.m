classdef NonIdealReactorPlus < handle
% NonIdealReactorPlus - Main launcher for the reactor applications.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 16, 2026. Last update: October 16, 2026
% =========================================================================

    properties (SetAccess = private)
        UIFigure
    end

    properties (Hidden)
        % Test-only overrides keyed by Ideal, NonIdeal, OpenLibrary,
        % OpenExample, NewFlowsheet, or OpenGuide. Production launches
        % leave it empty.
        TestActionOverrides = struct()
    end

    properties (Access = private)
        Buttons = {}
        ActiveProgressDialog = []
    end

    methods
        function app = NonIdealReactorPlus()
            app.UIFigure = uifigure( ...
                'Name', 'Non-Ideal Reactor Plus', ...
                'Position', [100 100 560 660], ...
                'Resize', 'off', ...
                'Visible', 'off', ...
                'CloseRequestFcn', @(~,~) delete(app)) ;
            movegui(app.UIFigure, 'center') ;

            mainGrid = uigridlayout(app.UIFigure, [8 1], ...
                'RowHeight', {52, 42, 44, 44, 152, 152, '1x', 42}, ...
                'Padding', [24 18 24 14], ...
                'RowSpacing', 8) ;

            titleLabel = uilabel(mainGrid, ...
                'Text', 'Non-Ideal Reactor Plus', ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 24, ...
                'FontWeight', 'bold') ;
            titleLabel.Layout.Row = 1 ;

            descriptionLabel = uilabel(mainGrid, ...
                'Text', ['Choose a reactor application or open the ' ...
                    'Simulink flowsheet tools.'], ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 12) ;
            descriptionLabel.Layout.Row = 2 ;

            idealButton = uibutton(mainGrid, ...
                'Text', 'Ideal Reactor App', ...
                'Tag', 'NirpLaunchIdeal', ...
                'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) app.runAction('Ideal')) ;
            idealButton.Layout.Row = 3 ;

            nonIdealButton = uibutton(mainGrid, ...
                'Text', 'Non-Ideal Reactor App', ...
                'Tag', 'NirpLaunchNonIdeal', ...
                'FontSize', 13, ...
                'ButtonPushedFcn', @(~,~) app.runAction('NonIdeal')) ;
            nonIdealButton.Layout.Row = 4 ;

            flowsheetPanel = uipanel(mainGrid, ...
                'Title', 'Flowsheet (Simulink)', ...
                'FontWeight', 'bold') ;
            flowsheetPanel.Layout.Row = 5 ;
            flowsheetGrid = uigridlayout(flowsheetPanel, [3 1], ...
                'RowHeight', {'1x', '1x', '1x'}, ...
                'Padding', [10 8 10 8], ...
                'RowSpacing', 7) ;

            libraryButton = uibutton(flowsheetGrid, ...
                'Text', 'Open block library', ...
                'Tag', 'NirpOpenLibrary', ...
                'ButtonPushedFcn', @(~,~) app.runAction('OpenLibrary')) ;
            exampleButton = uibutton(flowsheetGrid, ...
                'Text', 'Open example...', ...
                'Tag', 'NirpOpenExample', ...
                'ButtonPushedFcn', @(~,~) app.runAction('OpenExample')) ;
            newButton = uibutton(flowsheetGrid, ...
                'Text', 'New flowsheet...', ...
                'Tag', 'NirpNewFlowsheet', ...
                'ButtonPushedFcn', @(~,~) app.runAction('NewFlowsheet')) ;

            guidesPanel = uipanel(mainGrid, ...
                'Title', 'Guides', ...
                'FontWeight', 'bold') ;
            guidesPanel.Layout.Row = 6 ;
            guidesGrid = uigridlayout(guidesPanel, [3 1], ...
                'RowHeight', {'1x', '1x', '1x'}, ...
                'Padding', [10 8 10 8], ...
                'RowSpacing', 7) ;

            idealGuideButton = uibutton(guidesGrid, ...
                'Text', 'Ideal Reactor App guide', ...
                'Tag', 'NirpIdealGuide', ...
                'ButtonPushedFcn', @(~,~) app.runAction('IdealGuide')) ;
            nonIdealGuideButton = uibutton(guidesGrid, ...
                'Text', 'Non-Ideal Reactor App guide', ...
                'Tag', 'NirpNonIdealGuide', ...
                'ButtonPushedFcn', @(~,~) app.runAction('NonIdealGuide')) ;
            flowsheetGuideButton = uibutton(guidesGrid, ...
                'Text', 'Flowsheet guide', ...
                'Tag', 'NirpFlowsheetGuide', ...
                'ButtonPushedFcn', @(~,~) app.runAction('FlowsheetGuide')) ;

            creditsLabel = uilabel(mainGrid, ...
                'Text', { ...
                    'Based on ReactorApp by Isabela Fons (University of Alicante)'; ...
                    'Non-Ideal Reactor Plus by Javier Berenguer Sabater'}, ...
                'HorizontalAlignment', 'center', ...
                'FontSize', 10, ...
                'FontColor', [0.35 0.35 0.35]) ;
            creditsLabel.Layout.Row = 8 ;

            app.Buttons = {idealButton, nonIdealButton, libraryButton, ...
                exampleButton, newButton, idealGuideButton, ...
                nonIdealGuideButton, flowsheetGuideButton} ;
            app.UIFigure.Visible = 'on' ;
            drawnow ;
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure) ;
            end
        end
    end

    methods (Access = private)
        function runAction(app, actionName)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return
            end
            app.setButtonsEnabled(false) ;
            progressDialog = [] ;
            actionCleanup = onCleanup(@() app.finishAction()) ;
            try
                switch actionName
                    case 'IdealGuide'
                        app.openGuide(fullfile('guides', ...
                            'ideal-reactor-app.html')) ;
                    case 'NonIdealGuide'
                        app.openGuide('UserGuide.html') ;
                    case 'FlowsheetGuide'
                        app.openGuide(fullfile('guides', ...
                            'simulink-flowsheet.html')) ;
                    case 'Ideal'
                        progressDialog = app.openProgress( ...
                            'Opening Ideal Reactor App...', true) ;
                        app.invokeAction('Ideal', @() ReactorApp()) ;
                    case 'NonIdeal'
                        progressDialog = app.openProgress( ...
                            'Preparing Non-Ideal Reactor App...', false) ;
                        app.invokeAction('NonIdeal', @() NonIdealReactorApp( ...
                            'ProgressFcn', @(fraction, message) ...
                            app.updateProgress(progressDialog, fraction, message))) ;
                    otherwise
                        progressDialog = app.openProgress( ...
                            ['Loading Simulink (the first time can take ' ...
                            'a while)...'], true) ;
                        libraryFile = nirp.setup() ;
                        load_system(libraryFile) ;
                        delete(progressDialog) ;
                        progressDialog = [] ;
                        app.ActiveProgressDialog = [] ;
                        switch actionName
                            case 'OpenLibrary'
                                app.invokeAction('OpenLibrary', ...
                                    @() nirp.flowsheet.openLibrary()) ;
                            case 'OpenExample'
                                app.invokeAction('OpenExample', ...
                                    @() nirp.flowsheet.chooseExample()) ;
                            case 'NewFlowsheet'
                                app.invokeAction('NewFlowsheet', ...
                                    @() nirp.flowsheet.newFromTemplate()) ;
                        end
                end
            catch exception
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                    uialert(app.UIFigure, exception.message, ...
                        'Unable to open selection') ;
                end
            end
            clear actionCleanup
        end

        function invokeAction(app, actionName, defaultAction)
            if isfield(app.TestActionOverrides, actionName) && ...
                    ~isempty(app.TestActionOverrides.(actionName))
                action = app.TestActionOverrides.(actionName) ;
            else
                action = defaultAction ;
            end
            action() ;
        end

        function openGuide(app, relativePath)
            guidePath = fullfile(fileparts(mfilename('fullpath')), ...
                'docs', relativePath) ;
            if ~isfile(guidePath)
                error('NonIdealReactorPlus:MissingGuide', ...
                    'Guide file not found: %s', guidePath) ;
            end
            if isfield(app.TestActionOverrides, 'OpenGuide') && ...
                    ~isempty(app.TestActionOverrides.OpenGuide)
                app.TestActionOverrides.OpenGuide(guidePath) ;
                return
            end
            try
                web(guidePath) ;
            catch exception
                try
                    web(guidePath, '-browser') ;
                catch browserException
                    exception = addCause(exception, browserException) ;
                    rethrow(exception) ;
                end
            end
        end

        function progressDialog = openProgress(app, message, indeterminate)
            if indeterminate
                progressDialog = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Loading', ...
                    'Message', message, ...
                    'Indeterminate', 'on') ;
            else
                progressDialog = uiprogressdlg(app.UIFigure, ...
                    'Title', 'Loading', ...
                    'Message', message, ...
                    'Value', 0) ;
            end
            app.ActiveProgressDialog = progressDialog ;
            drawnow ;
        end

        function updateProgress(~, progressDialog, fraction, message)
            if ~isempty(progressDialog) && isvalid(progressDialog)
                progressDialog.Value = fraction ;
                progressDialog.Message = message ;
                drawnow limitrate ;
            end
        end

        function finishAction(app)
            app.closeProgress(app.ActiveProgressDialog) ;
            app.ActiveProgressDialog = [] ;
            app.setButtonsEnabled(true) ;
        end

        function closeProgress(~, progressDialog)
            if ~isempty(progressDialog) && isvalid(progressDialog)
                delete(progressDialog) ;
            end
        end

        function setButtonsEnabled(app, enabled)
            state = 'off' ;
            if enabled
                state = 'on' ;
            end
            for i = 1:numel(app.Buttons)
                button = app.Buttons{i} ;
                if ~isempty(button) && isvalid(button)
                    button.Enable = state ;
                end
            end
        end
    end
end
