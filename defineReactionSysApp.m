classdef defineReactionSysApp < matlab.apps.AppBase
    % Reactive-system editor used by the app and tracer flowsheet.
    % =========================================================================
    % Isabela Fons Moreno-Palancas
    % Modified by Javier Berenguer Sabater, October 25, 2026: optional
    % CreatedFcn callback for the tracer flowsheet.
    % =========================================================================

    % Properties that correspond to app components
    properties (Access = public)
        ReactionSysDefinitionUIFigure   matlab.ui.Figure
        UnitconversionhelperButton      matlab.ui.control.Button
        TabGroup                        matlab.ui.container.TabGroup
        GeneralTab                      matlab.ui.container.Tab
        ChooseanametostorethedataintheworkspaceLabel  matlab.ui.control.Label
        CreateReactiveSystemButton      matlab.ui.control.StateButton
        reactionsxcomponentsLabel       matlab.ui.control.Label
        StochiometricMatrixLabel        matlab.ui.control.Label
        NumberofreactionsSpinner        matlab.ui.control.Spinner
        NumberofreactionsSpinnerLabel   matlab.ui.control.Label
        UITable                         matlab.ui.control.Table
        NumberofcomponentsSpinner       matlab.ui.control.Spinner
        NumberofcomponentsSpinnerLabel  matlab.ui.control.Label
        NameEditField                   matlab.ui.control.EditField
        NameEditFieldLabel              matlab.ui.control.Label
        KineticsTab                     matlab.ui.container.Tab
        OtherKineticsFormat             matlab.ui.container.ButtonGroup
        UsingtablebelowButton           matlab.ui.control.RadioButton
        FromfileButton                  matlab.ui.control.RadioButton
        SpecifythenameofthefunctionEditField  matlab.ui.control.EditField
        SpecifythenameofthefunctionEditFieldLabel  matlab.ui.control.Label
        UserKineticsUnitsPanel          matlab.ui.container.Panel
        UserKineticsTimeUnitDropDown    matlab.ui.control.DropDown
        UserKineticsTimeUnitLabel       matlab.ui.control.Label
        UserKineticsConcentrationUnitDropDown  matlab.ui.control.DropDown
        UserKineticsConcentrationUnitLabel  matlab.ui.control.Label
        UserKineticsHelpLabel           matlab.ui.control.Label
        TextArea                        matlab.ui.control.TextArea
        KineticsButtonGroup             matlab.ui.container.ButtonGroup
        OtherkineticsButton             matlab.ui.control.RadioButton
        LangmuirHinshelwoodRateLawButton  matlab.ui.control.RadioButton
        UITable6                        matlab.ui.control.Table
        ConstantstodefinethedenominatorLabel  matlab.ui.control.Label
        NumeratoroftherateexpressionLabel  matlab.ui.control.Label
        Image                           matlab.ui.control.Image
        UITable3                        matlab.ui.control.Table
        PushtoaddanewterminthesumofthedenominatorLabel  matlab.ui.control.Label
        AddButton                       matlab.ui.control.Button
        ArrheniusRateLawconstantsLabel  matlab.ui.control.Label
        UITable2                        matlab.ui.control.Table
        ThermodynamicsTab               matlab.ui.container.Tab
        LoaddatafromHysysButton         matlab.ui.control.Button
        HysysFileDropDown               matlab.ui.control.DropDown
        HysysFileDropDownLabel          matlab.ui.control.Label
        Streamname                      matlab.ui.control.EditField
        StreamnameEditFieldLabel        matlab.ui.control.Label
        Filename                        matlab.ui.control.EditField
        FilenameEditFieldLabel          matlab.ui.control.Label
        Workingdirectory                matlab.ui.control.EditField
        WorkingdirectoryEditFieldLabel  matlab.ui.control.Label
        CpoptionDropDown                matlab.ui.control.DropDown
        CpoptionDropDownLabel           matlab.ui.control.Label
        TrefKEditField                  matlab.ui.control.NumericEditField
        TrefKEditFieldLabel             matlab.ui.control.Label
        UITable5                        matlab.ui.control.Table
        UITable4                        matlab.ui.control.Table
        PropertySelelctionDropDown      matlab.ui.control.DropDown
        PropertySelelctionDropDownLabel  matlab.ui.control.Label
        ReactiveSystemLabel             matlab.ui.control.Label
    end

    
    properties (Access = private)
        nDenominatorTerms =  0 ; % Number of terms in the denominator of the rate Law
        fileLocation % Information about where the Hysys file to be used is located
        
        UnitsApp
    end
    
    properties (Access = public)
        RS = ReactionSys ; % ReactionSys Object % Description
        CreatedFcn = [] ; % Optional callback: CreatedFcn(RS, workspaceName)
    end
    
    methods (Access = private)
        
        function visibilityHysysItems(app,state)
            app.CpoptionDropDown.Visible = state ;
            app.CpoptionDropDownLabel.Visible = state ;
            app.Workingdirectory.Visible = state ;
            app.WorkingdirectoryEditFieldLabel.Visible = state ;
            app.Filename.Visible = state ;
            app.FilenameEditFieldLabel.Visible = state ;
            app.Streamname.Visible = state ;
            app.StreamnameEditFieldLabel.Visible = state ;
            app.HysysFileDropDown.Visible = state ;
            app.HysysFileDropDownLabel.Visible = state ;
            app.LoaddatafromHysysButton.Visible = state ;
        end
        
        function visibilityUserDefinedThermodinamics(app,state)
            app.UITable4.Visible = state ;
            app.UITable5.Visible = state ;
            app.TrefKEditField.Visible = state ;
            app.TrefKEditFieldLabel.Visible = state ;
        end

        function value = parseScalarCell(~, newData)
            if isnumeric(newData)
                value = newData ;
            else
                value = InputLayerHelper.parseArithmeticExpression(newData) ;
            end
        end

        function wrappedKinetics = buildWrappedUserKinetics(app)
            timeUnit = app.UserKineticsTimeUnitDropDown.Value ;
            concUnit = app.UserKineticsConcentrationUnitDropDown.Value ;

            switch app.OtherKineticsFormat.SelectedObject.Text
                case 'From file'
                    functionName = app.SpecifythenameofthefunctionEditField.Value ;
                    wrappedKinetics = InputLayerHelper.wrapNamedKinetics( ...
                        functionName, timeUnit, concUnit) ;
                    app.RS.userDefinedKineticsSource = 'file' ;
                    app.RS.userDefinedKineticsFunctionName = char(functionName) ;
                    app.RS.userDefinedKineticsExpressions = strings(0, 1) ;

                case 'Using table below'
                    rateEquationsArray = table2array(app.UITable6.Data) ;
                    exprList = strings(numel(rateEquationsArray), 1) ;
                    for i = 1:numel(rateEquationsArray)
                        expr = strtrim(string(rateEquationsArray(i))) ;
                        if strlength(expr) == 0
                            error('Rate expression %d is empty.', i) ;
                        end
                        exprList(i) = expr ;
                    end
                    wrappedKinetics = InputLayerHelper.wrapExpressionKinetics( ...
                        cellstr(exprList), timeUnit, concUnit) ;
                    app.RS.userDefinedKineticsSource = 'table' ;
                    app.RS.userDefinedKineticsExpressions = exprList ;
                    app.RS.userDefinedKineticsFunctionName = '' ;
            end

            app.RS.userKineticsTimeUnit = char(timeUnit) ;
            app.RS.userKineticsConcentrationUnit = char(concUnit) ;
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Value changed function: NumberofcomponentsSpinner, 
        % ...and 1 other component
        function NumberofcomponentsSpinnerValueChanged(app, event)
           if app.NumberofcomponentsSpinner.Value > 0 && app.NumberofreactionsSpinner.Value > 0
            
            % Sets the number of columns and rows of the stochiometric matrix
            components = app.NumberofcomponentsSpinner.Value;
            reactions = app.NumberofreactionsSpinner.Value ;
            
            % Sizing UITable
            app.UITable.Data = cell(reactions,components) ;
            columnNames = cell(1,components) ;
            unicodeLetterID = 65 ; % Corresponds to letter A
            for i = 1:components
                columnNames{i} = char(unicodeLetterID) ;
                unicodeLetterID = unicodeLetterID + 1 ;
            end
            rowNames = cell(1,reactions) ;
            for i=1:reactions
                rowNames{i} = string(['Reaction ',num2str(i)]) ;
            end
            app.UITable.ColumnName = columnNames ;
            app.UITable.ColumnEditable = logical(true) ;
            app.UITable.RowName = rowNames ;
            
            % Sizing UITable2
            rowNames2 = rowNames ;
            app.UITable2.Data = cell(reactions,2) ;
            app.UITable2.RowName = rowNames2 ;
            app.UITable2.ColumnEditable = [logical(true) logical(true)] ;
            
            % Sizing UITable4
            rowNames4 = columnNames ;
            app.UITable4.Data = cell(components,2) ;
            app.UITable4.RowName = rowNames4 ;
            app.UITable4.ColumnEditable = logical(true) ;
            
            % Sizing UITable5
            rowNames5 = rowNames2 ;
            app.UITable5.Data = cell(reactions,1) ;
            app.UITable5.RowName = rowNames5 ;
            app.UITable5.ColumnEditable = logical(true) ;
            
            % Sizing UITable 6
            rowNames6 = rowNames2 ;
            userDefKineticsTable = array2table(strings(reactions,1)) ;
            app.UITable6.Data = userDefKineticsTable ;
            app.UITable6.RowName = rowNames6 ;
            app.UITable6.ColumnEditable = logical(true) ;
            
           end
           
            % Hiding UITables 3,4 and 5
            app.UITable3.Visible = 'off' ;
            app.UITable4.Visible = 'off' ;
            app.UITable5.Visible = 'off' ;
            app.TrefKEditField.Visible = 'off' ;
            app.TrefKEditFieldLabel.Visible = 'off' ;
            app.CpoptionDropDown.Visible = 'off' ;
            app.CpoptionDropDownLabel.Visible = 'off' ;
        end

        % Value changed function: CreateReactiveSystemButton
        function CreateReactiveSystemButtonValueChanged(app, event)
            if isempty(app.NameEditField.Value)
                msgbox('Name edit field is empty. Please, write an identifier before pushing "Create Reactive System" button', 'Warning','warn');
            else
                app.RS.stochiometricMatrix = cell2mat(app.UITable.Data) ;
                if numel(app.RS.componentNames) ~= app.RS.nComponents
                    app.RS.componentNames = cellstr(string(app.UITable.ColumnName)) ;
                end
                
                switch app.KineticsButtonGroup.SelectedObject.Text
                    case 'Langmuir-Hinshelwood Rate Law'
                        k0DataArray = cell2mat(app.UITable2.Data(:,1)) ;
                        if ~isempty(k0DataArray)
                            app.RS.k0 = k0DataArray' ;
                        end
                        EaDataArray = cell2mat(app.UITable2.Data(:,2)) ;
                        if ~isempty(EaDataArray)
                            app.RS.Ea = EaDataArray' ;
                        end
                        if app.nDenominatorTerms > 0
                            langmuirDataArray = cell2mat(app.UITable3.Data) ;
                            app.RS.k0_denominator = langmuirDataArray(:,1)' ;
                            app.RS.Ea_denominator = langmuirDataArray(:,2)' ;
                            app.RS.partialOrders_denominator = langmuirDataArray(:,3:end)' ;
                        end
                        app.RS.userDefinedKinetics = [] ;
                        app.RS.userDefinedKineticsExpressions = strings(0, 1) ;
                        app.RS.userDefinedKineticsSource = '' ;
                        app.RS.userDefinedKineticsFunctionName = '' ;
                    case 'Other kinetics'
                        app.RS.userDefinedKinetics = app.buildWrappedUserKinetics() ;
                end
                
                if strcmp(app.PropertySelelctionDropDown.Value,'User defined')
                    array4 = cell2mat(app.UITable4.Data) ;
                    
                    Cp = cell2mat(app.UITable4.Data(:,1)) ;
                    Mw = cell2mat(app.UITable4.Data(:,2)) ;
                    
                    [DHref] = cell2mat(app.UITable5.Data) ;
                    if ~isempty(Cp)
                        app.RS.componentCp = Cp' ;
                    end
                    if ~isempty(Mw)
                        app.RS.componentMw = Mw' ;
                    end
                    if ~isempty(DHref)
                        app.RS.Tref = app.TrefKEditField.Value ;
                        app.RS.DHref = DHref' ;
                    end
                elseif strcmp(app.PropertySelelctionDropDown.Value,'Import from Hysys')
                    if strcmp(app.CpoptionDropDown.Value,'Average')
                        array4 = cell2mat(app.UITable4.Data) ;
                        Cp = array4(:,1) ;
                        if Cp > 0
                            app.RS.componentCp = Cp' ;
                        end
                    end
                end
                
                assignin("base",app.NameEditField.Value,app.RS)
                if ~isempty(app.CreatedFcn)
                    app.CreatedFcn(app.RS,app.NameEditField.Value) ;
                end
            end
        end

        % Button pushed function: AddButton
        function AddButtonPushed(app, event)
            app.UITable3.Visible = 'on' ;
            
            % Sizing table 3
            nColumns = app.NumberofcomponentsSpinner.Value + 2; % k0 Ea partial order of each component
            columnNames = cell(1,nColumns) ;
            for i=1:nColumns
                if i == 1
                    columnNames{i}='k0_denominator' ;
                elseif i == 2
                    columnNames{i} = 'Ea_denominator' ;
                else
                    columnNames{i} = string(['P.O.Comp ',num2str(i-2)]) ;
                end
            end
            app.UITable3.ColumnName = columnNames ;
            app.UITable3.ColumnEditable = logical(true) ;
            
            if app.nDenominatorTerms < 0
                
                app.UITable3.Data = cell(1,nColumns) ;
                app.UITable3.Visible = 'on' ;
                
            else
                newRow = cell(1,nColumns) ;
                app.UITable3.Data = [app.UITable3.Data ; newRow] ;
            end
            
            app.nDenominatorTerms = app.nDenominatorTerms + 1 ;
        end

        % Button pushed function: LoaddatafromHysysButton
        function LoaddatafromHysysButtonPushed(app, event)
            if strcmp(app.HysysFileDropDown.Value,'Another file')
                app.fileLocation = {app.Workingdirectory.Value,app.Filename.Value,app.Streamname.Value} ;
                app.RS = app.RS.setHysysProperties(app.Workingdirectory.Value,app.Filename.Value,app.Streamname.Value) ;
            elseif strcmp(app.HysysFileDropDown.Value, 'Default (ComponentDataBase.xml)')
                app.RS = app.RS.setHysysProperties ;
            end
            
            if strcmp(app.CpoptionDropDown.Value,'Average')
                app.RS.componentCp.option = 'Average' ;
                CpArray = app.RS.componentCp.Average ;
            elseif strcmp(app.CpoptionDropDown.Value,'Cp = f(T)')
                app.RS.componentCp.option = 'Cp = f(T)' ;
                CpArray = strings(size(app.RS.componentCp.Function)) ;
                for i=1:size(app.RS.componentCp.Function,2)
                    CpArray(i) = "Function" ;
                    app.UITable4.ColumnEditable = logical([false true]) ;
                end
            elseif strcmp(app.CpoptionDropDown.Value,'Cp = f(T,P)')
                app.RS.componentCp.option = 'Cp = f(T,P)' ;
                CpArray = strings(size(app.RS.componentCp.FunctionWithP)) ;
                for i=1:size(app.RS.componentCp.FunctionWithP,2)
                    CpArray(i) = "Function" ;
                    app.UITable4.ColumnEditable = logical([false true]) ;
                end
            end
            
            MwArray = app.RS.componentMw ;
            DHformArray = app.RS.componentHeatOfFormation ;
            
            app.UITable4.Data = array2table([CpArray' MwArray']) ;
            app.UITable5.Data = array2table(DHformArray') ;
            app.UITable4.RowName = app.RS.componentNames ;
            app.UITable5.RowName = app.RS.componentNames ;
            app.UITable5.ColumnName = string([char(916),"Hformation (J/mol)"]) ;
            app.UITable4.Visible = 'on' ;
            app.UITable5.Visible = 'on' ;
            
        end

        % Value changed function: PropertySelelctionDropDown
        function PropertySelelctionDropDownValueChanged(app, event)
            switch app.PropertySelelctionDropDown.Value
                case ''
                    app.visibilityHysysItems('off') ;
                    app.visibilityUserDefinedThermodinamics('off') ;
                case 'Import from Hysys'
                    app.visibilityHysysItems('on') ;
                    app.visibilityUserDefinedThermodinamics('off') ;
                case 'User defined'
                    app.visibilityHysysItems('off') ;
                    app.visibilityUserDefinedThermodinamics('on') ;
            end
        end

        % Value changed function: CpoptionDropDown, Filename, 
        % ...and 3 other components
        function HysysFileDropDownValueChanged(app, event)
            switch app.HysysFileDropDown.Value
                case 'Default (ComponentDataBase.xml)'
                    app.Workingdirectory.Value = '' ;
                    app.Filename.Value = '' ;
                    app.Streamname.Value = '' ;
                    app.fileLocation = {} ;
                    
                    app.Workingdirectory.Editable = 'off' ;
                    app.Filename.Editable = 'off' ;
                    app.Streamname.Editable = 'off' ;
                case 'Another file'
                    app.Workingdirectory.Editable = 'on' ;
                    app.Filename.Editable = 'on' ;
                    app.Streamname.Editable = 'on' ;
            end
            
            check1 = isempty(app.CpoptionDropDown.Value) ;
            check2 = isempty(app.HysysFileDropDown.Value) ;
            if strcmp(app.HysysFileDropDown.Value,'Another file')
                check3 = isempty(app.Workingdirectory.Value) + isempty(app.Filename.Value) +isempty(app.Streamname.Value) ;
            else
                check3 = 0 ;
            end
            if check1 + check2 + check3 == 0
                app.LoaddatafromHysysButton.Enable = 'on' ;
            end
        end

        % Button pushed function: UnitconversionhelperButton
        function UnitconversionhelperButtonPushed(app, event)
            UnitConverterHelper.launch() ;
        end

        % Selection changed function: KineticsButtonGroup
        function KineticsButtonGroupSelectionChanged(app, event)
            selectedButton = app.KineticsButtonGroup.SelectedObject.Text;
            switch selectedButton
                case 'Langmuir-Hinshelwood Rate Law'
                    app.UITable2.Visible = 'on' ;
                    app.UITable3.Visible = 'on' ;
                    app.ArrheniusRateLawconstantsLabel.Visible = 'on' ;
                    app.NumeratoroftherateexpressionLabel.Visible = 'on' ;
                    app.Image.Visible = 'on' ;
                    app.ConstantstodefinethedenominatorLabel.Visible = 'on' ;
                    app.AddButton.Visible = 'on' ;
                    app.UITable6.Visible = 'off' ;
                    app.TextArea.Visible = 'off' ;
                    app.OtherKineticsFormat.Visible = 'off' ;
                    app.SpecifythenameofthefunctionEditField.Visible = 'off' ;
                    app.SpecifythenameofthefunctionEditFieldLabel.Visible = 'off' ;
                    app.UserKineticsUnitsPanel.Visible = 'off' ;
                    app.UserKineticsHelpLabel.Visible = 'off' ;
                case 'Other kinetics'
                    app.UITable2.Visible = 'off' ;
                    app.UITable3.Visible = 'on' ;
                    app.ArrheniusRateLawconstantsLabel.Visible = 'off' ;
                    app.NumeratoroftherateexpressionLabel.Visible = 'off' ;
                    app.Image.Visible = 'off' ;
                    app.ConstantstodefinethedenominatorLabel.Visible = 'off' ;
                    app.AddButton.Visible = 'off' ;
                    app.UITable6.Visible = 'on' ;
                    app.TextArea.Visible = 'on' ;
                    app.OtherKineticsFormat.Visible = 'on' ;
                    app.SpecifythenameofthefunctionEditField.Visible = 'on' ;
                    app.SpecifythenameofthefunctionEditFieldLabel.Visible = 'on' ;
                    app.UserKineticsUnitsPanel.Visible = 'on' ;
                    app.UserKineticsHelpLabel.Visible = 'on' ;
            end
        end

        % Cell edit callback: UITable
        function UITableCellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;

            try
                if isa(newData,'char') || isa(newData, 'string')
                    app.UITable.Data{indices(1),indices(2)} = app.parseScalarCell(newData) ;
                end
            catch ME
                uialert(app.ReactionSysDefinitionUIFigure, ME.message, 'Invalid Input') ;
                app.UITable.Data{indices(1),indices(2)} = [] ;
            end
        end

        % Cell edit callback: UITable2
        function UITable2CellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            try
                if isa(newData,'char') || isa(newData, 'string')
                    app.UITable2.Data{indices(1),indices(2)} = app.parseScalarCell(newData) ;
                end
            catch ME
                uialert(app.ReactionSysDefinitionUIFigure, ME.message, 'Invalid Input') ;
                app.UITable2.Data{indices(1),indices(2)} = [] ;
            end
        end

        % Cell edit callback: UITable3
        function UITable3CellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            try
                if isa(newData,'char') || isa(newData, 'string')
                    app.UITable3.Data{indices(1),indices(2)} = app.parseScalarCell(newData) ;
                end
            catch ME
                uialert(app.ReactionSysDefinitionUIFigure, ME.message, 'Invalid Input') ;
                app.UITable3.Data{indices(1),indices(2)} = [] ;
            end
        end

        % Cell edit callback: UITable4
        function UITable4CellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            try
                if isa(newData,'char') || isa(newData, 'string')
                    app.UITable4.Data{indices(1),indices(2)} = app.parseScalarCell(newData) ;
                end
            catch ME
                uialert(app.ReactionSysDefinitionUIFigure, ME.message, 'Invalid Input') ;
                app.UITable4.Data{indices(1),indices(2)} = [] ;
            end
        end

        % Cell edit callback: UITable5
        function UITable5CellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            try
                if isa(newData,'char') || isa(newData, 'string')
                    app.UITable5.Data{indices(1),indices(2)} = app.parseScalarCell(newData) ;
                end
            catch ME
                uialert(app.ReactionSysDefinitionUIFigure, ME.message, 'Invalid Input') ;
                app.UITable5.Data{indices(1),indices(2)} = [] ;
            end
        end

        % Cell edit callback: UITable6
        function UITable6CellEdit(app, event)
            indices = event.Indices;
            newData = event.NewData;
            if isa(newData,'string')
                newData = char(newData) ;
            end
            if isa(newData,'char')
                app.UITable6.Data{indices(1),indices(2)} = string(strtrim(newData)) ;
            end
        end

        % Selection changed function: OtherKineticsFormat
        function OtherKineticsFormatSelectionChanged(app, event)
            selectedButton = app.OtherKineticsFormat.SelectedObject;
            switch selectedButton.Text
                case 'From file'
                    app.SpecifythenameofthefunctionEditField.Enable = 'on' ;
                    app.UITable6.Enable = 'off' ;
                case 'Using table below'
                    app.SpecifythenameofthefunctionEditField.Enable = 'off' ;
                    app.UITable6.Enable = 'on' ;
            end
        end
    end

    methods (Access = public)

        function loadFromRS(app, RS, name)
            % loadFromRS  Populate the UI from an existing ReactionSys object.
            %   app.loadFromRS(RS, name) sets the spinners, tables, and
            %   kinetics controls so the user can edit the existing system.
            %
            %   Inputs:
            %     RS   - ReactionSys object to load
            %     name - char/string, workspace variable name

            if nargin < 3 || isempty(name)
                name = '' ;
            end

            nR = RS.nReactions ;
            nC = RS.nComponents ;

            % --- General tab ---
            app.NameEditField.Value = char(name) ;
            app.NumberofreactionsSpinner.Value = nR ;
            app.NumberofcomponentsSpinner.Value = nC ;

            % Trigger spinner callback to resize all tables
            app.NumberofcomponentsSpinnerValueChanged([]) ;

            % Stoichiometric matrix (UITable)
            app.UITable.Data = num2cell(RS.stochiometricMatrix) ;

            % Store the RS internally
            app.RS = RS ;

            % --- Kinetics tab ---
            if ~isempty(RS.userDefinedKinetics)
                % Other kinetics mode
                app.KineticsButtonGroup.SelectedObject = app.OtherkineticsButton ;
                app.KineticsButtonGroupSelectionChanged([]) ;
                app.UserKineticsTimeUnitDropDown.Value = char(RS.userKineticsTimeUnit) ;
                app.UserKineticsConcentrationUnitDropDown.Value = char(RS.userKineticsConcentrationUnit) ;

                if strcmp(RS.userDefinedKineticsSource, 'table') && ~isempty(RS.userDefinedKineticsExpressions)
                    app.OtherKineticsFormat.SelectedObject = app.UsingtablebelowButton ;
                    app.OtherKineticsFormatSelectionChanged([]) ;
                    exprData = cellstr(RS.userDefinedKineticsExpressions(:)) ;
                    app.UITable6.Data = array2table(string(exprData)) ;
                    app.UITable6.RowName = app.UITable.RowName ;
                else
                    app.OtherKineticsFormat.SelectedObject = app.FromfileButton ;
                    app.OtherKineticsFormatSelectionChanged([]) ;
                    if ~isempty(RS.userDefinedKineticsFunctionName)
                        app.SpecifythenameofthefunctionEditField.Value = char(RS.userDefinedKineticsFunctionName) ;
                    else
                        app.SpecifythenameofthefunctionEditField.Value = func2str(RS.userDefinedKinetics) ;
                    end
                end

            else
                % Langmuir-Hinshelwood mode
                app.KineticsButtonGroup.SelectedObject = app.LangmuirHinshelwoodRateLawButton ;
                app.KineticsButtonGroupSelectionChanged([]) ;

                % k0 and Ea (UITable2)
                if ~isempty(RS.k0) && ~isempty(RS.Ea)
                    k0_col = RS.k0(:) ;
                    Ea_col = RS.Ea(:) ;
                    app.UITable2.Data = num2cell([k0_col, Ea_col]) ;
                elseif ~isempty(RS.k0)
                    app.UITable2.Data = num2cell([RS.k0(:), zeros(nR, 1)]) ;
                end

                % Denominator terms (UITable3)
                if ~isequal(RS.k0_denominator, 0) && ~isempty(RS.k0_denominator)
                    nTerms = length(RS.k0_denominator) ;
                    app.nDenominatorTerms = 0 ;  % reset counter
                    for i = 1:nTerms
                        app.AddButtonPushed([]) ;  % adds a row
                    end
                    % Populate: [k0_denom, Ea_denom, partialOrders_denom']
                    k0d = RS.k0_denominator(:) ;
                    Ead = RS.Ea_denominator(:) ;
                    pod = RS.partialOrders_denominator ;  % stored as [nComp x nTerms]
                    if size(pod, 2) == nTerms
                        pod = pod' ;  % make [nTerms x nComp]
                    end
                    denomData = num2cell([k0d, Ead, pod]) ;
                    app.UITable3.Data = denomData ;
                end
            end

            % --- Thermodynamics tab ---
            if ~isempty(RS.componentCp) && ~isempty(RS.componentMw)
                app.PropertySelelctionDropDown.Value = 'User defined' ;
                app.PropertySelelctionDropDownValueChanged([]) ;
                Cp_col = RS.componentCp(:) ;
                Mw_col = RS.componentMw(:) ;
                app.UITable4.Data = num2cell([Cp_col, Mw_col]) ;
                if ~isempty(RS.DHref)
                    app.UITable5.Data = num2cell(RS.DHref(:)) ;
                end
                app.TrefKEditField.Value = RS.Tref ;
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create ReactionSysDefinitionUIFigure and hide until all components are created
            app.ReactionSysDefinitionUIFigure = uifigure('Visible', 'off');
            app.ReactionSysDefinitionUIFigure.Position = [100 100 650 486];
            app.ReactionSysDefinitionUIFigure.Name = 'ReactionSysDefinition';

            % Create ReactiveSystemLabel
            app.ReactiveSystemLabel = uilabel(app.ReactionSysDefinitionUIFigure);
            app.ReactiveSystemLabel.HorizontalAlignment = 'center';
            app.ReactiveSystemLabel.FontName = 'Arial';
            app.ReactiveSystemLabel.FontSize = 16;
            app.ReactiveSystemLabel.FontWeight = 'bold';
            app.ReactiveSystemLabel.Position = [205 462 242 25];
            app.ReactiveSystemLabel.Text = 'Reactive System';

            % Create TabGroup
            app.TabGroup = uitabgroup(app.ReactionSysDefinitionUIFigure);
            app.TabGroup.Position = [1 1 650 462];

            % Create GeneralTab
            app.GeneralTab = uitab(app.TabGroup);
            app.GeneralTab.Title = 'General';

            % Create NameEditFieldLabel
            app.NameEditFieldLabel = uilabel(app.GeneralTab);
            app.NameEditFieldLabel.HorizontalAlignment = 'right';
            app.NameEditFieldLabel.FontWeight = 'bold';
            app.NameEditFieldLabel.Position = [52 391 38 22];
            app.NameEditFieldLabel.Text = 'Name';

            % Create NameEditField
            app.NameEditField = uieditfield(app.GeneralTab, 'text');
            app.NameEditField.Position = [105 391 100 22];

            % Create NumberofcomponentsSpinnerLabel
            app.NumberofcomponentsSpinnerLabel = uilabel(app.GeneralTab);
            app.NumberofcomponentsSpinnerLabel.HorizontalAlignment = 'right';
            app.NumberofcomponentsSpinnerLabel.Position = [362 306 130 22];
            app.NumberofcomponentsSpinnerLabel.Text = 'Number of components';

            % Create NumberofcomponentsSpinner
            app.NumberofcomponentsSpinner = uispinner(app.GeneralTab);
            app.NumberofcomponentsSpinner.Limits = [0 Inf];
            app.NumberofcomponentsSpinner.ValueChangedFcn = createCallbackFcn(app, @NumberofcomponentsSpinnerValueChanged, true);
            app.NumberofcomponentsSpinner.Position = [507 306 100 22];

            % Create UITable
            app.UITable = uitable(app.GeneralTab);
            app.UITable.ColumnName = {''};
            app.UITable.RowName = {};
            app.UITable.ColumnEditable = true;
            app.UITable.CellEditCallback = createCallbackFcn(app, @UITableCellEdit, true);
            app.UITable.Position = [45 53 563 232];

            % Create NumberofreactionsSpinnerLabel
            app.NumberofreactionsSpinnerLabel = uilabel(app.GeneralTab);
            app.NumberofreactionsSpinnerLabel.HorizontalAlignment = 'right';
            app.NumberofreactionsSpinnerLabel.Position = [49 306 114 22];
            app.NumberofreactionsSpinnerLabel.Text = 'Number of reactions';

            % Create NumberofreactionsSpinner
            app.NumberofreactionsSpinner = uispinner(app.GeneralTab);
            app.NumberofreactionsSpinner.Limits = [0 Inf];
            app.NumberofreactionsSpinner.ValueChangedFcn = createCallbackFcn(app, @NumberofcomponentsSpinnerValueChanged, true);
            app.NumberofreactionsSpinner.Position = [178 306 100 22];

            % Create StochiometricMatrixLabel
            app.StochiometricMatrixLabel = uilabel(app.GeneralTab);
            app.StochiometricMatrixLabel.FontSize = 14;
            app.StochiometricMatrixLabel.FontWeight = 'bold';
            app.StochiometricMatrixLabel.Position = [253 356 148 22];
            app.StochiometricMatrixLabel.Text = 'Stochiometric Matrix ';

            % Create reactionsxcomponentsLabel
            app.reactionsxcomponentsLabel = uilabel(app.GeneralTab);
            app.reactionsxcomponentsLabel.FontColor = [0.502 0.502 0.502];
            app.reactionsxcomponentsLabel.Position = [256 335 139 22];
            app.reactionsxcomponentsLabel.Text = '[reactions x components]';

            % Create CreateReactiveSystemButton
            app.CreateReactiveSystemButton = uibutton(app.GeneralTab, 'state');
            app.CreateReactiveSystemButton.ValueChangedFcn = createCallbackFcn(app, @CreateReactiveSystemButtonValueChanged, true);
            app.CreateReactiveSystemButton.Text = 'Create Reactive System';
            app.CreateReactiveSystemButton.FontSize = 16;
            app.CreateReactiveSystemButton.FontWeight = 'bold';
            app.CreateReactiveSystemButton.Position = [228 10 198 26];

            % Create ChooseanametostorethedataintheworkspaceLabel
            app.ChooseanametostorethedataintheworkspaceLabel = uilabel(app.GeneralTab);
            app.ChooseanametostorethedataintheworkspaceLabel.FontColor = [0.502 0.502 0.502];
            app.ChooseanametostorethedataintheworkspaceLabel.Position = [236 389 277 22];
            app.ChooseanametostorethedataintheworkspaceLabel.Text = 'Choose a name to store the data in the workspace';

            % Create KineticsTab
            app.KineticsTab = uitab(app.TabGroup);
            app.KineticsTab.Title = 'Kinetics';

            % Create UITable2
            app.UITable2 = uitable(app.KineticsTab);
            app.UITable2.ColumnName = {'k0'; 'Ea'};
            app.UITable2.ColumnWidth = {100, 100};
            app.UITable2.RowName = {};
            app.UITable2.ColumnEditable = true;
            app.UITable2.CellEditCallback = createCallbackFcn(app, @UITable2CellEdit, true);
            app.UITable2.Position = [338 191 263 183];

            % Create ArrheniusRateLawconstantsLabel
            app.ArrheniusRateLawconstantsLabel = uilabel(app.KineticsTab);
            app.ArrheniusRateLawconstantsLabel.FontWeight = 'bold';
            app.ArrheniusRateLawconstantsLabel.Position = [381 394 178 22];
            app.ArrheniusRateLawconstantsLabel.Text = 'Arrhenius Rate Law constants';

            % Create AddButton
            app.AddButton = uibutton(app.KineticsTab, 'push');
            app.AddButton.ButtonPushedFcn = createCallbackFcn(app, @AddButtonPushed, true);
            app.AddButton.Position = [127 136 100 22];
            app.AddButton.Text = 'Add';

            % Create PushtoaddanewterminthesumofthedenominatorLabel
            app.PushtoaddanewterminthesumofthedenominatorLabel = uilabel(app.KineticsTab);
            app.PushtoaddanewterminthesumofthedenominatorLabel.FontColor = [0.502 0.502 0.502];
            app.PushtoaddanewterminthesumofthedenominatorLabel.Position = [237 136 298 22];
            app.PushtoaddanewterminthesumofthedenominatorLabel.Text = 'Push to add a new term in the sum of the denominator';

            % Create UITable3
            app.UITable3 = uitable(app.KineticsTab);
            app.UITable3.ColumnName = {''};
            app.UITable3.RowName = {};
            app.UITable3.ColumnEditable = true;
            app.UITable3.CellEditCallback = createCallbackFcn(app, @UITable3CellEdit, true);
            app.UITable3.Position = [69 22 523 111];

            % Create Image
            app.Image = uiimage(app.KineticsTab);
            app.Image.Tooltip = {'It is not necessary to specify constants of the denominator. In this case, '; 'Den = 1'};
            app.Image.Position = [49 226 247 112];
            app.Image.ImageSource = 'RateHelp.png';

            % Create NumeratoroftherateexpressionLabel
            app.NumeratoroftherateexpressionLabel = uilabel(app.KineticsTab);
            app.NumeratoroftherateexpressionLabel.HorizontalAlignment = 'center';
            app.NumeratoroftherateexpressionLabel.FontColor = [0.502 0.502 0.502];
            app.NumeratoroftherateexpressionLabel.Position = [380 377 181 22];
            app.NumeratoroftherateexpressionLabel.Text = 'Numerator of the rate expression';

            % Create ConstantstodefinethedenominatorLabel
            app.ConstantstodefinethedenominatorLabel = uilabel(app.KineticsTab);
            app.ConstantstodefinethedenominatorLabel.HorizontalAlignment = 'center';
            app.ConstantstodefinethedenominatorLabel.FontWeight = 'bold';
            app.ConstantstodefinethedenominatorLabel.Position = [223 162 216 22];
            app.ConstantstodefinethedenominatorLabel.Text = 'Constants to define the denominator';

            % Create UITable6
            app.UITable6 = uitable(app.KineticsTab);
            app.UITable6.ColumnName = {'Insert the rate equation for each reaction'};
            app.UITable6.RowName = {};
            app.UITable6.CellEditCallback = createCallbackFcn(app, @UITable6CellEdit, true);
            app.UITable6.Visible = 'off';
            app.UITable6.Position = [51 22 556 145];

            % Create KineticsButtonGroup
            app.KineticsButtonGroup = uibuttongroup(app.KineticsTab);
            app.KineticsButtonGroup.SelectionChangedFcn = createCallbackFcn(app, @KineticsButtonGroupSelectionChanged, true);
            app.KineticsButtonGroup.BorderColor = [1 1 1];
            app.KineticsButtonGroup.FontSize = 16;
            app.KineticsButtonGroup.Position = [46 365 265 56];

            % Create LangmuirHinshelwoodRateLawButton
            app.LangmuirHinshelwoodRateLawButton = uiradiobutton(app.KineticsButtonGroup);
            app.LangmuirHinshelwoodRateLawButton.Text = 'Langmuir-Hinshelwood Rate Law';
            app.LangmuirHinshelwoodRateLawButton.FontSize = 14;
            app.LangmuirHinshelwoodRateLawButton.FontWeight = 'bold';
            app.LangmuirHinshelwoodRateLawButton.Position = [11 29 245 22];
            app.LangmuirHinshelwoodRateLawButton.Value = true;

            % Create OtherkineticsButton
            app.OtherkineticsButton = uiradiobutton(app.KineticsButtonGroup);
            app.OtherkineticsButton.Text = 'Other kinetics';
            app.OtherkineticsButton.Position = [11 7 95 22];

            % Create TextArea
            app.TextArea = uitextarea(app.KineticsTab);
            app.TextArea.Editable = 'off';
            app.TextArea.BackgroundColor = [0.9412 0.9412 0.9412];
            app.TextArea.Visible = 'off';
            app.TextArea.Position = [51 289 556 64];
            app.TextArea.Value = {'How to specify different kinetics expressions?'; '- Each row corresponds to the rate equation r_i of a different reaction'; '- Concentration of each species has to be expressed as an element of the vector concentration, being consistent with the order used in the stochiometric matrix.'; '- Temperature has to be expressed as T'; '- Use the base-unit panel below to tell the app which time and concentration units you are using'; ''; 'Example: A + B <-> C  with r_forward = 20*C_A^0.5*C_B^3 and r_reverse = 2*exp(1000/T)*C_C'; 'In the first row of the table you should write:'; '       20 * concentration(1)^0.5 * concentration(2)^3'; 'In the second row you should write:'; '       2 * exp(1000/T)* concentration(3)'; ''};

            % Create SpecifythenameofthefunctionEditFieldLabel
            app.SpecifythenameofthefunctionEditFieldLabel = uilabel(app.KineticsTab);
            app.SpecifythenameofthefunctionEditFieldLabel.HorizontalAlignment = 'right';
            app.SpecifythenameofthefunctionEditFieldLabel.Visible = 'off';
            app.SpecifythenameofthefunctionEditFieldLabel.Position = [53 173 180 22];
            app.SpecifythenameofthefunctionEditFieldLabel.Text = 'Specify the name of the function ';

            % Create SpecifythenameofthefunctionEditField
            app.SpecifythenameofthefunctionEditField = uieditfield(app.KineticsTab, 'text');
            app.SpecifythenameofthefunctionEditField.Enable = 'off';
            app.SpecifythenameofthefunctionEditField.Visible = 'off';
            app.SpecifythenameofthefunctionEditField.Position = [257 173 340 22];

            % Create UserKineticsUnitsPanel
            app.UserKineticsUnitsPanel = uipanel(app.KineticsTab);
            app.UserKineticsUnitsPanel.Title = 'Base units for Other kinetics';
            app.UserKineticsUnitsPanel.Visible = 'off';
            app.UserKineticsUnitsPanel.Position = [51 219 556 50];

            % Create UserKineticsTimeUnitLabel
            app.UserKineticsTimeUnitLabel = uilabel(app.UserKineticsUnitsPanel);
            app.UserKineticsTimeUnitLabel.HorizontalAlignment = 'right';
            app.UserKineticsTimeUnitLabel.Position = [10 2 70 22];
            app.UserKineticsTimeUnitLabel.Text = 'Time';

            % Create UserKineticsTimeUnitDropDown
            app.UserKineticsTimeUnitDropDown = uidropdown(app.UserKineticsUnitsPanel);
            app.UserKineticsTimeUnitDropDown.Items = UnitConverterHelper.getUnits('Time');
            app.UserKineticsTimeUnitDropDown.Position = [90 2 90 22];
            app.UserKineticsTimeUnitDropDown.Value = 's';

            % Create UserKineticsConcentrationUnitLabel
            app.UserKineticsConcentrationUnitLabel = uilabel(app.UserKineticsUnitsPanel);
            app.UserKineticsConcentrationUnitLabel.HorizontalAlignment = 'right';
            app.UserKineticsConcentrationUnitLabel.Position = [205 2 90 22];
            app.UserKineticsConcentrationUnitLabel.Text = 'Concentration';

            % Create UserKineticsConcentrationUnitDropDown
            app.UserKineticsConcentrationUnitDropDown = uidropdown(app.UserKineticsUnitsPanel);
            app.UserKineticsConcentrationUnitDropDown.Items = UnitConverterHelper.getUnits('Concentration');
            app.UserKineticsConcentrationUnitDropDown.Position = [308 2 120 22];
            app.UserKineticsConcentrationUnitDropDown.Value = 'mol/m^3';

            % Create UserKineticsHelpLabel
            app.UserKineticsHelpLabel = uilabel(app.KineticsTab);
            app.UserKineticsHelpLabel.Visible = 'off';
            app.UserKineticsHelpLabel.FontColor = [0.35 0.35 0.35];
            app.UserKineticsHelpLabel.Position = [53 199 552 16];
            app.UserKineticsHelpLabel.Text = 'Write r_i in your preferred base units. The app converts concentration inputs and rate outputs to SI automatically.';

            % Create OtherKineticsFormat
            app.OtherKineticsFormat = uibuttongroup(app.KineticsTab);
            app.OtherKineticsFormat.SelectionChangedFcn = createCallbackFcn(app, @OtherKineticsFormatSelectionChanged, true);
            app.OtherKineticsFormat.BorderColor = [1 1 1];
            app.OtherKineticsFormat.Visible = 'off';
            app.OtherKineticsFormat.Position = [347 367 129 52];

            % Create FromfileButton
            app.FromfileButton = uiradiobutton(app.OtherKineticsFormat);
            app.FromfileButton.Text = 'From file';
            app.FromfileButton.Position = [11 27 69 22];

            % Create UsingtablebelowButton
            app.UsingtablebelowButton = uiradiobutton(app.OtherKineticsFormat);
            app.UsingtablebelowButton.Text = 'Using table below';
            app.UsingtablebelowButton.Position = [11 2 117 22];
            app.UsingtablebelowButton.Value = true;

            % Create ThermodynamicsTab
            app.ThermodynamicsTab = uitab(app.TabGroup);
            app.ThermodynamicsTab.Title = 'Thermodynamics';

            % Create PropertySelelctionDropDownLabel
            app.PropertySelelctionDropDownLabel = uilabel(app.ThermodynamicsTab);
            app.PropertySelelctionDropDownLabel.HorizontalAlignment = 'right';
            app.PropertySelelctionDropDownLabel.Position = [62 385 106 22];
            app.PropertySelelctionDropDownLabel.Text = 'Property Selelction';

            % Create PropertySelelctionDropDown
            app.PropertySelelctionDropDown = uidropdown(app.ThermodynamicsTab);
            app.PropertySelelctionDropDown.Items = {'', 'Import from Hysys', 'User defined'};
            app.PropertySelelctionDropDown.ValueChangedFcn = createCallbackFcn(app, @PropertySelelctionDropDownValueChanged, true);
            app.PropertySelelctionDropDown.Position = [181 385 205 22];
            app.PropertySelelctionDropDown.Value = '';

            % Create UITable4
            app.UITable4 = uitable(app.ThermodynamicsTab);
            app.UITable4.ColumnName = {'Cp (J/mol/K)'; 'Mw (g/mol)'};
            app.UITable4.ColumnWidth = {100, 100};
            app.UITable4.RowName = {};
            app.UITable4.ColumnEditable = true;
            app.UITable4.CellEditCallback = createCallbackFcn(app, @UITable4CellEdit, true);
            app.UITable4.Visible = 'off';
            app.UITable4.Position = [59 23 263 183];

            % Create UITable5
            app.UITable5 = uitable(app.ThermodynamicsTab);
            app.UITable5.ColumnName = {'	ΔHref (J/mol)'};
            app.UITable5.ColumnWidth = {100, 100};
            app.UITable5.RowName = {};
            app.UITable5.ColumnEditable = true;
            app.UITable5.CellEditCallback = createCallbackFcn(app, @UITable5CellEdit, true);
            app.UITable5.Visible = 'off';
            app.UITable5.Position = [404 23 163 183];

            % Create TrefKEditFieldLabel
            app.TrefKEditFieldLabel = uilabel(app.ThermodynamicsTab);
            app.TrefKEditFieldLabel.HorizontalAlignment = 'right';
            app.TrefKEditFieldLabel.Visible = 'off';
            app.TrefKEditFieldLabel.Position = [404 210 46 22];
            app.TrefKEditFieldLabel.Text = 'Tref (K)';

            % Create TrefKEditField
            app.TrefKEditField = uieditfield(app.ThermodynamicsTab, 'numeric');
            app.TrefKEditField.ValueDisplayFormat = '%.2f';
            app.TrefKEditField.Visible = 'off';
            app.TrefKEditField.Position = [465 210 100 22];
            app.TrefKEditField.Value = 298.15;

            % Create CpoptionDropDownLabel
            app.CpoptionDropDownLabel = uilabel(app.ThermodynamicsTab);
            app.CpoptionDropDownLabel.HorizontalAlignment = 'right';
            app.CpoptionDropDownLabel.Visible = 'off';
            app.CpoptionDropDownLabel.Position = [108 343 57 22];
            app.CpoptionDropDownLabel.Text = 'Cp option';

            % Create CpoptionDropDown
            app.CpoptionDropDown = uidropdown(app.ThermodynamicsTab);
            app.CpoptionDropDown.Items = {'', 'Average', 'Cp = f(T)', 'Cp = f(T,P)'};
            app.CpoptionDropDown.ValueChangedFcn = createCallbackFcn(app, @HysysFileDropDownValueChanged, true);
            app.CpoptionDropDown.Visible = 'off';
            app.CpoptionDropDown.Position = [181 343 205 22];
            app.CpoptionDropDown.Value = '';

            % Create WorkingdirectoryEditFieldLabel
            app.WorkingdirectoryEditFieldLabel = uilabel(app.ThermodynamicsTab);
            app.WorkingdirectoryEditFieldLabel.HorizontalAlignment = 'right';
            app.WorkingdirectoryEditFieldLabel.Visible = 'off';
            app.WorkingdirectoryEditFieldLabel.Position = [67 304 99 22];
            app.WorkingdirectoryEditFieldLabel.Text = 'Working directory';

            % Create Workingdirectory
            app.Workingdirectory = uieditfield(app.ThermodynamicsTab, 'text');
            app.Workingdirectory.ValueChangedFcn = createCallbackFcn(app, @HysysFileDropDownValueChanged, true);
            app.Workingdirectory.Visible = 'off';
            app.Workingdirectory.Tooltip = {'Choose the folder where the .xml file used as a data base is found.'};
            app.Workingdirectory.Position = [181 304 386 22];

            % Create FilenameEditFieldLabel
            app.FilenameEditFieldLabel = uilabel(app.ThermodynamicsTab);
            app.FilenameEditFieldLabel.HorizontalAlignment = 'right';
            app.FilenameEditFieldLabel.Visible = 'off';
            app.FilenameEditFieldLabel.Position = [108 283 58 22];
            app.FilenameEditFieldLabel.Text = 'File name';

            % Create Filename
            app.Filename = uieditfield(app.ThermodynamicsTab, 'text');
            app.Filename.ValueChangedFcn = createCallbackFcn(app, @HysysFileDropDownValueChanged, true);
            app.Filename.Visible = 'off';
            app.Filename.Tooltip = {'Write the name of the .xml file used as a data base.'; ''; 'WARNING: only write the name, without typing ".xml".'};
            app.Filename.Position = [181 283 386 22];

            % Create StreamnameEditFieldLabel
            app.StreamnameEditFieldLabel = uilabel(app.ThermodynamicsTab);
            app.StreamnameEditFieldLabel.HorizontalAlignment = 'right';
            app.StreamnameEditFieldLabel.Visible = 'off';
            app.StreamnameEditFieldLabel.Position = [88 262 78 22];
            app.StreamnameEditFieldLabel.Text = 'Stream name';

            % Create Streamname
            app.Streamname = uieditfield(app.ThermodynamicsTab, 'text');
            app.Streamname.ValueChangedFcn = createCallbackFcn(app, @HysysFileDropDownValueChanged, true);
            app.Streamname.Visible = 'off';
            app.Streamname.Tooltip = {'Name of the stream in ''yourFile.xml'' that you''re going to take the data.'; ''; 'WARNING: make sure it''s an independent stream. Changes will be applied to this stream.'};
            app.Streamname.Position = [181 262 386 22];

            % Create HysysFileDropDownLabel
            app.HysysFileDropDownLabel = uilabel(app.ThermodynamicsTab);
            app.HysysFileDropDownLabel.HorizontalAlignment = 'right';
            app.HysysFileDropDownLabel.Visible = 'off';
            app.HysysFileDropDownLabel.Position = [105 364 61 22];
            app.HysysFileDropDownLabel.Text = 'Hysys File';

            % Create HysysFileDropDown
            app.HysysFileDropDown = uidropdown(app.ThermodynamicsTab);
            app.HysysFileDropDown.Items = {'', 'Default (ComponentDataBase.xml)', 'Another file'};
            app.HysysFileDropDown.ValueChangedFcn = createCallbackFcn(app, @HysysFileDropDownValueChanged, true);
            app.HysysFileDropDown.Visible = 'off';
            app.HysysFileDropDown.Position = [181 364 205 22];
            app.HysysFileDropDown.Value = '';

            % Create LoaddatafromHysysButton
            app.LoaddatafromHysysButton = uibutton(app.ThermodynamicsTab, 'push');
            app.LoaddatafromHysysButton.ButtonPushedFcn = createCallbackFcn(app, @LoaddatafromHysysButtonPushed, true);
            app.LoaddatafromHysysButton.Enable = 'off';
            app.LoaddatafromHysysButton.Visible = 'off';
            app.LoaddatafromHysysButton.Position = [429 364 132 22];
            app.LoaddatafromHysysButton.Text = 'Load data from Hysys';

            % Create UnitconversionhelperButton
            app.UnitconversionhelperButton = uibutton(app.ReactionSysDefinitionUIFigure, 'push');
            app.UnitconversionhelperButton.ButtonPushedFcn = createCallbackFcn(app, @UnitconversionhelperButtonPushed, true);
            app.UnitconversionhelperButton.Icon = 'UnitsLogo.png';
            app.UnitconversionhelperButton.Position = [0 465 164 22];
            app.UnitconversionhelperButton.Text = 'Unit conversion helper';

            % Show the figure after all components are created
            app.ReactionSysDefinitionUIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = defineReactionSysApp(RS_existing, varName)
            % defineReactionSysApp  Constructor.
            %   app = defineReactionSysApp()            — empty (original)
            %   app = defineReactionSysApp(RS, name)    — pre-load an existing RS

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.ReactionSysDefinitionUIFigure)

            % If an existing ReactionSys was provided, load it into the UI
            if nargin >= 1 && ~isempty(RS_existing)
                if nargin < 2
                    varName = '' ;
                end
                app.loadFromRS(RS_existing, varName) ;
            end

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.ReactionSysDefinitionUIFigure)
        end
    end
end
