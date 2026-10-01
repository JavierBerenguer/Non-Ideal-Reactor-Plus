% UnitConverterHelper - Floating unit conversion tool for reactor engineering
%
% Provides quick conversion between common units used in chemical
% reactor design and simulation.
%
% Usage:
%   UnitConverterHelper.launch()   % Opens the converter window
%
% Internal units (SI):
%   time: s | volume: m^3 | concentration: mol/m^3
%   flow: m^3/s | pressure: Pa | temperature: K
%   k(1st): 1/s | k(2nd): m^3/(mol*s) | energy: J/mol
%
% Author: Javier Berenguer Sabater
% Created: March 2026

classdef UnitConverterHelper < handle

    methods (Static)

        function launch()
            % launch  Open the floating unit converter window.

            % --- Build the unit database (category -> struct of units) ---
            cats = UnitConverterHelper.buildCatalog() ;

            categoryNames = fieldnames(cats) ;

            % === Create figure ===
            fig = uifigure('Name', 'Unit Converter', ...
                'Position', [200 200 400 500], ...
                'Resize', 'off') ;

            mainGrid = uigridlayout(fig, [7 1], ...
                'RowHeight', {30, 30, 30, 30, 35, 22, '1x'}, ...
                'Padding', [15 15 15 15], ...
                'RowSpacing', 8) ;

            % --- Row 1: Category dropdown ---
            catPanel = uigridlayout(mainGrid, [1 2], ...
                'ColumnWidth', {90, '1x'}, 'Padding', [0 0 0 0]) ;
            catPanel.Layout.Row = 1 ;
            uilabel(catPanel, 'Text', 'Category:', ...
                'FontWeight', 'bold') ;
            ddCategory = uidropdown(catPanel, ...
                'Items', categoryNames, ...
                'Value', categoryNames{1}) ;

            % --- Row 2: From unit + input ---
            fromPanel = uigridlayout(mainGrid, [1 3], ...
                'ColumnWidth', {60, '1x', '1x'}, 'Padding', [0 0 0 0]) ;
            fromPanel.Layout.Row = 2 ;
            uilabel(fromPanel, 'Text', 'From:', 'FontWeight', 'bold') ;
            efInput = uieditfield(fromPanel, 'numeric', 'Value', 1) ;
            ddFrom = uidropdown(fromPanel, 'Items', {''}) ;

            % --- Row 3: To unit + result ---
            toPanel = uigridlayout(mainGrid, [1 3], ...
                'ColumnWidth', {60, '1x', '1x'}, 'Padding', [0 0 0 0]) ;
            toPanel.Layout.Row = 3 ;
            uilabel(toPanel, 'Text', 'To:', 'FontWeight', 'bold') ;
            efResult = uieditfield(toPanel, 'numeric', ...
                'Value', 0, 'Editable', 'off') ;
            ddTo = uidropdown(toPanel, 'Items', {''}) ;

            % --- Row 4: Convert button (centred) ---
            btnPanel = uigridlayout(mainGrid, [1 3], ...
                'ColumnWidth', {'1x', 120, '1x'}, 'Padding', [0 0 0 0]) ;
            btnPanel.Layout.Row = 4 ;
            uilabel(btnPanel, 'Text', '') ;   % spacer left
            btnConvert = uibutton(btnPanel, 'Text', 'Convert', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.30 0.60 0.88]) ;
            uilabel(btnPanel, 'Text', '') ;   % spacer right

            % --- Row 5: Formula display ---
            lblFormula = uilabel(mainGrid, 'Text', '', ...
                'HorizontalAlignment', 'center', ...
                'FontAngle', 'italic') ;
            lblFormula.Layout.Row = 5 ;

            % --- Row 6: Reference-table header ---
            lblRef = uilabel(mainGrid, 'Text', 'Reference (to SI base):', ...
                'FontWeight', 'bold', 'FontSize', 11) ;
            lblRef.Layout.Row = 6 ;

            % --- Row 7: Reference table ---
            tblRef = uitable(mainGrid, ...
                'ColumnName', {'Unit', 'Factor (to SI)'}, ...
                'ColumnWidth', {160, 180}, ...
                'RowName', {}) ;
            tblRef.Layout.Row = 7 ;

            % === Internal helper: run conversion ===
            function doConvert(~, ~)
                catKey  = ddCategory.Value ;
                entry   = cats.(catKey) ;
                fromU   = ddFrom.Value ;
                toU     = ddTo.Value ;
                val     = efInput.Value ;

                if strcmp(catKey, 'Temperature')
                    res = UnitConverterHelper.convertTemperature(val, fromU, toU) ;
                else
                    fFrom = entry.factors(fromU) ;
                    fTo   = entry.factors(toU) ;
                    res   = val * fFrom / fTo ;
                end

                efResult.Value = res ;
                lblFormula.Text = sprintf('%g %s = %g %s', val, fromU, res, toU) ;
            end

            % === Internal helper: update dropdowns on category change ===
            function updateDropdowns(~, ~)
                catKey = ddCategory.Value ;
                entry  = cats.(catKey) ;
                units  = entry.factors.keys ;
                ddFrom.Items = units ;
                ddTo.Items   = units ;
                ddFrom.Value = units{1} ;
                if numel(units) > 1
                    ddTo.Value = units{2} ;
                else
                    ddTo.Value = units{1} ;
                end

                % Update reference table
                if strcmp(catKey, 'Temperature')
                    tblRef.Data = {'K', '(base)' ;
                                   char(176) + "C", 'K - 273.15' ;
                                   char(176) + "F", 'K*9/5 - 459.67'} ;
                else
                    uList = units ;
                    nU    = numel(uList) ;
                    tData = cell(nU, 2) ;
                    for k = 1:nU
                        tData{k,1} = uList{k} ;
                        tData{k,2} = sprintf('%g', entry.factors(uList{k})) ;
                    end
                    tblRef.Data = tData ;
                end

                doConvert() ;
            end

            % === Wire callbacks ===
            ddCategory.ValueChangedFcn = @updateDropdowns ;
            ddFrom.ValueChangedFcn     = @doConvert ;
            ddTo.ValueChangedFcn       = @doConvert ;
            efInput.ValueChangedFcn    = @doConvert ;
            btnConvert.ButtonPushedFcn = @doConvert ;

            % === Initialise state ===
            updateDropdowns() ;
        end

        function launchForField(targetField, categoryName)
            % launchForField  Open a contextual unit converter for a specific field.
            %   UnitConverterHelper.launchForField(field, 'Time')
            %
            %   Pre-selects the category, pre-fills the current field value,
            %   and provides an "Apply to Field" button that writes the
            %   SI-equivalent result directly into the target field.

            cats = UnitConverterHelper.buildCatalog() ;
            if ~isfield(cats, categoryName)
                warning('UnitConverterHelper:unknownCategory', ...
                    'Unknown category "%s". Opening general converter.', categoryName) ;
                UnitConverterHelper.launch() ;
                return
            end
            entry = cats.(categoryName) ;
            units = entry.factors.keys ;
            inputVal = UnitConverterHelper.extractFieldNumericValue(targetField) ;
            defaultFrom = UnitConverterHelper.getFieldUnit(targetField, units{1}) ;

            % === Create figure ===
            fig = uifigure('Name', ['Unit Converter — ' categoryName], ...
                'Position', [300 250 400 380], 'Resize', 'off') ;

            mainGrid = uigridlayout(fig, [6 1], ...
                'RowHeight', {30, 30, 35, 28, 40, '1x'}, ...
                'Padding', [15 15 15 15], 'RowSpacing', 8) ;

            % --- Row 1: From unit + input (pre-filled) ---
            fromPanel = uigridlayout(mainGrid, [1 3], ...
                'ColumnWidth', {60, '1x', '1x'}, 'Padding', [0 0 0 0]) ;
            fromPanel.Layout.Row = 1 ;
            uilabel(fromPanel, 'Text', 'From:', 'FontWeight', 'bold') ;
            efInput = uieditfield(fromPanel, 'numeric', 'Value', inputVal) ;
            ddFrom = uidropdown(fromPanel, 'Items', units, 'Value', defaultFrom) ;

            % --- Row 2: To unit + result ---
            toPanel = uigridlayout(mainGrid, [1 3], ...
                'ColumnWidth', {60, '1x', '1x'}, 'Padding', [0 0 0 0]) ;
            toPanel.Layout.Row = 2 ;
            uilabel(toPanel, 'Text', 'To:', 'FontWeight', 'bold') ;
            efResult = uieditfield(toPanel, 'numeric', ...
                'Value', 0, 'Editable', 'off') ;
            ddTo = uidropdown(toPanel, 'Items', units) ;
            if numel(units) > 1
                ddTo.Value = units{2} ;
            end

            % --- Row 3: Convert + Apply buttons side by side ---
            btnPanel = uigridlayout(mainGrid, [1 4], ...
                'ColumnWidth', {'1x', 110, 140, '1x'}, 'Padding', [0 0 0 0]) ;
            btnPanel.Layout.Row = 3 ;
            uilabel(btnPanel, 'Text', '') ;   % spacer
            btnConvert = uibutton(btnPanel, 'Text', 'Convert', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.30 0.60 0.88]) ;
            btnApply = uibutton(btnPanel, 'Text', 'Apply to Field', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.20 0.72 0.35], ...
                'FontColor', 'white') ;
            uilabel(btnPanel, 'Text', '') ;   % spacer

            % --- Row 4: Formula display ---
            lblFormula = uilabel(mainGrid, 'Text', '', ...
                'HorizontalAlignment', 'center', ...
                'FontAngle', 'italic') ;
            lblFormula.Layout.Row = 4 ;

            % --- Row 5: Reference-table header ---
            lblRef = uilabel(mainGrid, 'Text', 'Reference (to SI base):', ...
                'FontWeight', 'bold', 'FontSize', 11) ;
            lblRef.Layout.Row = 5 ;

            % --- Row 6: Reference table ---
            tblRef = uitable(mainGrid, ...
                'ColumnName', {'Unit', 'Factor (to SI)'}, ...
                'ColumnWidth', {160, 180}, ...
                'RowName', {}) ;
            tblRef.Layout.Row = 6 ;

            % Populate reference table
            if strcmp(categoryName, 'Temperature')
                tblRef.Data = {'K', '(base)' ; ...
                               [char(176) 'C'], 'K - 273.15' ; ...
                               [char(176) 'F'], 'K*9/5 - 459.67'} ;
            else
                uList = units ;
                nU = numel(uList) ;
                tData = cell(nU, 2) ;
                for kk = 1:nU
                    tData{kk,1} = uList{kk} ;
                    tData{kk,2} = sprintf('%g', entry.factors(uList{kk})) ;
                end
                tblRef.Data = tData ;
            end

            % === Conversion callback ===
            function doConvert(~, ~)
                fromU = ddFrom.Value ;
                toU   = ddTo.Value ;
                val   = efInput.Value ;

                if strcmp(categoryName, 'Temperature')
                    res = UnitConverterHelper.convertTemperature(val, fromU, toU) ;
                else
                    fFrom = entry.factors(fromU) ;
                    fTo   = entry.factors(toU) ;
                    res   = val * fFrom / fTo ;
                end

                efResult.Value = res ;
                lblFormula.Text = sprintf('%g %s = %g %s', val, fromU, res, toU) ;
            end

            % === Apply callback: write SI value to target field, close ===
            function applyToField(~, ~)
                val   = efInput.Value ;
                fromU = ddFrom.Value ;

                if strcmp(categoryName, 'Temperature')
                    siVal = UnitConverterHelper.convertTemperature(val, fromU, 'K') ;
                else
                    siVal = val * entry.factors(fromU) ;
                end

                if isa(targetField, 'matlab.ui.control.NumericEditField')
                    targetField.Value = siVal ;
                else
                    targetField.Value = sprintf('%.15g', siVal) ;
                end

                if isprop(targetField, 'UserData') && isstruct(targetField.UserData) && ...
                        isfield(targetField.UserData, 'unitDropdown') && isvalid(targetField.UserData.unitDropdown)
                    targetField.UserData.unitDropdown.Value = UnitConverterHelper.defaultUnit(categoryName) ;
                end
                delete(fig) ;
            end

            % === Wire callbacks ===
            ddFrom.ValueChangedFcn     = @doConvert ;
            ddTo.ValueChangedFcn       = @doConvert ;
            efInput.ValueChangedFcn    = @doConvert ;
            btnConvert.ButtonPushedFcn = @doConvert ;
            btnApply.ButtonPushedFcn   = @applyToField ;

            % === Initial conversion ===
            doConvert() ;
        end

        function units = getUnits(categoryName)
            cats = UnitConverterHelper.buildCatalog() ;
            if ~isfield(cats, categoryName)
                error('UnitConverterHelper:UnknownCategory', ...
                    'Unknown category "%s".', categoryName) ;
            end
            units = cats.(categoryName).factors.keys ;
        end

        function unit = defaultUnit(categoryName)
            units = UnitConverterHelper.getUnits(categoryName) ;
            unit = units{1} ;
        end

        function factor = factorToSI(categoryName, unitName)
            cats = UnitConverterHelper.buildCatalog() ;
            if ~isfield(cats, categoryName)
                error('UnitConverterHelper:UnknownCategory', ...
                    'Unknown category "%s".', categoryName) ;
            end
            if strcmp(categoryName, 'Temperature')
                error('UnitConverterHelper:UnsupportedFactor', ...
                    'Temperature requires offset-aware conversion.') ;
            end
            factor = cats.(categoryName).factors(unitName) ;
        end

        function siValue = convertToSI(categoryName, value, unitName)
            if strcmp(categoryName, 'Temperature')
                siValue = UnitConverterHelper.convertTemperature(value, unitName, 'K') ;
            else
                siValue = value * UnitConverterHelper.factorToSI(categoryName, unitName) ;
            end
        end

        function value = convertFromSI(categoryName, siValue, unitName)
            if strcmp(categoryName, 'Temperature')
                value = UnitConverterHelper.convertTemperature(siValue, 'K', unitName) ;
            else
                value = siValue / UnitConverterHelper.factorToSI(categoryName, unitName) ;
            end
        end

    end

    methods (Static, Access = private)

        function val = extractFieldNumericValue(targetField)
            if isa(targetField, 'matlab.ui.control.NumericEditField')
                val = targetField.Value ;
                return
            end

            try
                val = InputLayerHelper.parseArithmeticExpression(targetField.Value) ;
            catch
                val = 0 ;
            end
        end

        function unit = getFieldUnit(targetField, fallback)
            unit = fallback ;
            if ~isprop(targetField, 'UserData') || ~isstruct(targetField.UserData)
                return
            end

            fieldData = targetField.UserData ;
            if isfield(fieldData, 'unitDropdown') && ~isempty(fieldData.unitDropdown) && isvalid(fieldData.unitDropdown)
                unit = fieldData.unitDropdown.Value ;
            end
        end

        function cats = buildCatalog()
            % buildCatalog  Return struct with every category.
            %   Each field is a struct with a containers.Map 'factors'
            %   mapping unit-name -> multiplicative factor to SI base.

            cats = struct() ;

            % ----- Time -----
            m = containers.Map() ;
            m('s')   = 1 ;
            m('min') = 60 ;
            m('h')   = 3600 ;
            cats.Time.factors = m ;

            % ----- Time squared -----
            m = containers.Map() ;
            m('s^2')   = 1 ;
            m('min^2') = 60^2 ;
            m('h^2')   = 3600^2 ;
            cats.TimeSquared.factors = m ;

            % ----- Time inverse -----
            m = containers.Map() ;
            m('1/s')   = 1 ;
            m('1/min') = 1 / 60 ;
            m('1/h')   = 1 / 3600 ;
            cats.TimeInverse.factors = m ;

            % ----- Volume -----
            m = containers.Map() ;
            m('m^3')  = 1 ;
            m('L')    = 1e-3 ;
            m('mL')   = 1e-6 ;
            m('cm^3') = 1e-6 ;
            m('dm^3') = 1e-3 ;
            cats.Volume.factors = m ;

            % ----- Volumetric Flow -----
            m = containers.Map() ;
            m('m^3/s')  = 1 ;
            m('L/min')  = 1e-3 / 60 ;
            m('L/s')    = 1e-3 ;
            m('cm^3/s') = 1e-6 ;
            m('mL/min') = 1e-6 / 60 ;
            cats.VolumetricFlow.factors = m ;

            % ----- Molar Flow -----
            m = containers.Map() ;
            m('mol/s')   = 1 ;
            m('mol/min') = 1 / 60 ;
            m('mol/h')   = 1 / 3600 ;
            m('kmol/h')  = 1e3 / 3600 ;
            m('kmol/s')  = 1e3 ;
            m('moles/s') = 1 ;
            m('gmole/s') = 1 ;
            cats.MolarFlow.factors = m ;

            % ----- Concentration -----
            m = containers.Map() ;
            m('mol/m^3')  = 1 ;
            m('mol/L')    = 1e3 ;
            m('kmol/m^3') = 1e3 ;
            m('mmol/L')   = 1 ;
            cats.Concentration.factors = m ;

            % ----- Raw scalar (no conversion) -----
            m = containers.Map() ;
            m('as entered') = 1 ;
            cats.RawScalar.factors = m ;

            % ----- k (1st order) -----
            m = containers.Map() ;
            m('1/s')   = 1 ;
            m('1/min') = 1 / 60 ;
            m('1/h')   = 1 / 3600 ;
            cats.k_1stOrder.factors = m ;

            % ----- k (2nd order) -----
            m = containers.Map() ;
            m('m^3/(mol*s)')   = 1 ;
            m('L/(mol*s)')     = 1e-3 ;
            m('L/(mol*min)')   = 1e-3 / 60 ;
            m('dm^3/(mol*min)')= 1e-3 / 60 ;
            m('cm^3/(mol*s)')  = 1e-6 ;
            cats.k_2ndOrder.factors = m ;

            % ----- Pressure -----
            m = containers.Map() ;
            m('Pa')   = 1 ;
            m('kPa')  = 1e3 ;
            m('bar')  = 1e5 ;
            m('atm')  = 101325 ;
            m('mmHg') = 133.322 ;
            m('psi')  = 6894.76 ;
            m('torr') = 133.322 ;
            cats.Pressure.factors = m ;

            % ----- Temperature (special) -----
            %   Factors map kept for reference-table display only.
            m = containers.Map() ;
            m('K')  = 1 ;
            m([char(176) 'C']) = 0 ;   % offset-based, not used directly
            m([char(176) 'F']) = 0 ;
            cats.Temperature.factors = m ;

            % ----- Energy/mol -----
            m = containers.Map() ;
            m('J/mol')      = 1 ;
            m('kJ/mol')     = 1e3 ;
            m('cal/mol')    = 4.184 ;
            m('kcal/mol')   = 4184 ;
            m('BTU/lbmol')  = 2.326 ;
            cats.EnergyPerMol.factors = m ;

            % ----- Power -----
            % Thermochemical calorie: 1 cal = 4.184 J exactly. The IT
            % British thermal unit is 1055.05585262 J (NIST SP 811).
            m = containers.Map() ;
            m('W')      = 1 ;
            m('kW')     = 1e3 ;
            m('J/s')    = 1 ;
            m('kJ/h')   = 1e3 / 3600 ;
            m('kcal/h') = 4184 / 3600 ;
            m('cal/s')  = 4.184 ;
            m('BTU/h')  = 1055.05585262 / 3600 ;
            cats.Power.factors = m ;

            % ----- Molar heat capacity -----
            % Calorie factors use the exact thermochemical calorie above.
            m = containers.Map() ;
            m('J/(mol*K)')     = 1 ;
            m('kJ/(kmol*K)')   = 1 ;
            m('kJ/(mol*K)')    = 1e3 ;
            m('cal/(mol*K)')   = 4.184 ;
            m('kcal/(kmol*K)') = 4.184 ;
            cats.MolarHeatCapacity.factors = m ;

            % ----- Heat-transfer coefficient -----
            % The BTU factor is based on the IT BTU above and 1 ft exact
            % = 0.3048 m; a Fahrenheit degree interval is 5/9 K.
            m = containers.Map() ;
            m('W/(m^2*K)')       = 1 ;
            m('kW/(m^2*K)')      = 1e3 ;
            m('kJ/(h*m^2*K)')    = 1e3 / 3600 ;
            m('kcal/(h*m^2*K)')  = 4184 / 3600 ;
            m('BTU/(h*ft^2*F)')  = 1055.05585262 / 3600 / 0.3048^2 * 9 / 5 ;
            cats.HeatTransferCoefficient.factors = m ;

            % ----- Mass flow -----
            m = containers.Map() ;
            m('kg/s')  = 1 ;
            m('kg/h')  = 1 / 3600 ;
            m('g/s')   = 1e-3 ;
            m('g/min') = 1e-3 / 60 ;
            m('t/h')   = 1e3 / 3600 ;
            cats.MassFlow.factors = m ;

            % ----- Diffusivity -----
            m = containers.Map() ;
            m('m^2/s')   = 1 ;
            m('cm^2/s')  = 1e-4 ;
            m('mm^2/s')  = 1e-6 ;
            m('ft^2/s')  = 0.0929 ;
            cats.Diffusivity.factors = m ;

            % ----- Density -----
            m = containers.Map() ;
            m('kg/m^3') = 1 ;
            m('g/L')    = 1 ;
            m('g/cm^3') = 1e3 ;
            m('kg/L')   = 1e3 ;
            cats.Density.factors = m ;

            % ----- Viscosity (dynamic) -----
            m = containers.Map() ;
            m('Pa*s')   = 1 ;
            m('mPa*s')  = 1e-3 ;
            m('cP')     = 1e-3 ;
            m('P')      = 0.1 ;
            cats.Viscosity.factors = m ;

            % ----- Length -----
            m = containers.Map() ;
            m('m')   = 1 ;
            m('cm')  = 1e-2 ;
            m('mm')  = 1e-3 ;
            m('in')  = 0.0254 ;
            m('ft')  = 0.3048 ;
            cats.Length.factors = m ;

            % ----- Area -----
            m = containers.Map() ;
            m('m^2')   = 1 ;
            m('cm^2')  = 1e-4 ;
            m('mm^2')  = 1e-6 ;
            m('ft^2')  = 0.0929 ;
            cats.Area.factors = m ;
        end

        function result = convertTemperature(value, fromUnit, toUnit)
            % convertTemperature  Handle offset-based temperature conversions.

            degC = [char(176) 'C'] ;
            degF = [char(176) 'F'] ;

            % Step 1: convert input to Kelvin
            if strcmp(fromUnit, 'K')
                K = value ;
            elseif strcmp(fromUnit, degC)
                K = value + 273.15 ;
            elseif strcmp(fromUnit, degF)
                K = (value + 459.67) * 5 / 9 ;
            else
                K = value ;   % fallback
            end

            % Step 2: convert Kelvin to target
            if strcmp(toUnit, 'K')
                result = K ;
            elseif strcmp(toUnit, degC)
                result = K - 273.15 ;
            elseif strcmp(toUnit, degF)
                result = K * 9 / 5 - 459.67 ;
            else
                result = K ;   % fallback
            end
        end

    end

end
