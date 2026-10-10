classdef Jacket < matlab.System
    % Jacket supplies heat-transfer data to a flowsheet reactor in SI units.
    % Output [mode; values] (T-146): Utility [1; U; A; Tin; Tout or NaN],
    % Specified T [2; T; NaN; NaN; NaN], Specified Q [3; Q; NaN; NaN; NaN].
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 8, 2026. Last update: October 8, 2026
    % =========================================================================

    properties (Nontunable)
        % Jacket mode: utility (U*A), specified reactor T or specified duty.
        Mode = 'Utility'
        % Reactor temperature kept by the jacket (Specified T).
        SpecifiedT = 350
        SpecifiedTUnit = 'K'
        % Heat duty added to the reactor, Q > 0 heats (Specified Q).
        SpecifiedQ = 0
        SpecifiedQUnit = 'W'
        % Overall heat-transfer coefficient.
        U = 0
        % Heat-transfer-coefficient display unit.
        UUnit = 'W/(m^2*K)'
        % Heat-transfer area.
        A = 1
        % Heat-transfer-area display unit.
        AUnit = 'm^2'
        % Source of heat-transfer area.
        ASource = 'Dialog'
        % Utility inlet temperature.
        UtilityTin = 300
        % Utility-inlet-temperature display unit.
        UtilityTinUnit = 'K'
        % Source of utility inlet temperature.
        UtilityTinSource = 'Dialog'
        % Utility outlet temperature; NaN means constant temperature.
        UtilityTout = NaN
        % Utility-outlet-temperature display unit.
        UtilityToutUnit = 'K'
        % Optional utility specific heat in J/(kg*K).
        UtilityCp = NaN
        % True when the utility changes phase at constant temperature.
        Condenses (1,1) logical = false
        % Optional utility latent heat in J/kg.
        LatentHeat = NaN
    end
    properties (Constant,Hidden)
        ModeSet = matlab.system.StringSet({'Utility','Specified T','Specified Q'})
        SpecifiedTUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        SpecifiedQUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Power'))
        UUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('HeatTransferCoefficient'))
        AUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Area'))
        ASourceSet = matlab.system.StringSet({'Dialog','Input port'})
        UtilityTinUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        UtilityTinSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        UtilityToutUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
    end
    properties (Access=private)
        Values
        Model
        Block
        CalculationCount = 0
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,pkg,~] = nirp.blocks.internal.modelPackage() ;
            obj.Block = get_param(gcb,'Name') ;
            nirp.blocks.internal.requireThermodynamics(pkg,sprintf('Jacket "%s"',obj.Block)) ;
            obj.CalculationCount = 0 ;
            if strcmp(obj.Mode,'Specified T')
                obj.Values = [convert('Temperature',obj.SpecifiedT,obj.SpecifiedTUnit); NaN; NaN; NaN] ;
                if ~isfinite(obj.Values(1)) || obj.Values(1) <= 0
                    error('nirp:blocks:invalidJacket','Jacket reactor temperature must be positive.') ;
                end
                return
            elseif strcmp(obj.Mode,'Specified Q')
                obj.Values = [convert('Power',obj.SpecifiedQ,obj.SpecifiedQUnit); NaN; NaN; NaN] ;
                if ~isfinite(obj.Values(1))
                    error('nirp:blocks:invalidJacket','Jacket heat duty must be finite.') ;
                end
                return
            end
            obj.Values = [convert('HeatTransferCoefficient',obj.U,obj.UUnit); ...
                convert('Area',obj.A,obj.AUnit); ...
                convert('Temperature',obj.UtilityTin,obj.UtilityTinUnit); ...
                optionalTemperature(obj.UtilityTout,obj.UtilityToutUnit)] ;
            validateValues(obj.Values) ;
            if ~isnan(obj.UtilityCp) && (~isfinite(obj.UtilityCp) || obj.UtilityCp <= 0)
                error('nirp:blocks:invalidJacket','UtilityCp must be positive or NaN.') ;
            end
            if obj.Condenses && (~isfinite(obj.LatentHeat) || obj.LatentHeat <= 0)
                error('nirp:blocks:invalidJacket', ...
                    'A condensing utility requires a positive latent heat in J/kg.') ;
            end
            obj.CalculationCount = 0 ;
        end
        function value = stepImpl(obj,varargin)
            value = obj.Values ; index = 1 ;
            mode = find(strcmp(obj.Mode,{'Utility','Specified T','Specified Q'})) ;
            if mode > 1
                obj.CalculationCount = obj.CalculationCount+1 ;
                info = struct('status',1,'message','','mode',char(obj.Mode)) ;
                if mode == 2, info.specifiedT = value(1) ; else, info.specifiedQ = value(1) ; end
                value = [mode; value] ;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,value,info) ;
                return
            end
            if strcmp(obj.ASource,'Input port')
                value(2) = varargin{index} ; index = index+1 ;
            end
            if strcmp(obj.UtilityTinSource,'Input port')
                value(3) = varargin{index} ;
            end
            validateValues(value) ;
            obj.CalculationCount = obj.CalculationCount+1 ;
            info = struct('status',1,'message','','mode','Utility','U',value(1),'A',value(2), ...
                'utilityTin',value(3),'utilityTout',value(4)) ;
            value = [1; value] ;
            nirp.blocks.internal.diagnostic( ...
                obj.Model,obj.Block,obj.CalculationCount,value,info) ;
        end
        function n = getNumInputsImpl(obj)
            if ~strcmp(obj.Mode,'Utility'), n = 0 ; return, end
            n = strcmp(obj.ASource,'Input port')+ ...
                strcmp(obj.UtilityTinSource,'Input port') ;
        end
        function n = getNumOutputsImpl(~), n = 1 ; end
        function type = getOutputDataTypeImpl(~), type = 'double' ; end
        function size = getOutputSizeImpl(~), size = [5 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function varargout = getInputNamesImpl(obj)
            index = 0 ; varargout = {} ;
            if ~strcmp(obj.Mode,'Utility'), return, end
            if strcmp(obj.ASource,'Input port'), index=index+1;varargout{index}='A (m^2)';end
            if strcmp(obj.UtilityTinSource,'Input port'), index=index+1;varargout{index}='UtilityTin (K)';end
        end
        function name = getOutputNamesImpl(~), name = 'Jacket' ; end
        function icon = getIconImpl(~), icon = 'Jacket' ; end
    end
    methods (Static,Access=protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Jacket', ...
                'PropertyList',{'Mode','SpecifiedT','SpecifiedTUnit','SpecifiedQ','SpecifiedQUnit','U','UUnit','ASource','A','AUnit', ...
                'UtilityTinSource','UtilityTin','UtilityTinUnit', ...
                'UtilityTout','UtilityToutUnit','UtilityCp','Condenses','LatentHeat'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end

function value = convert(category,value,unit)
    value = UnitConverterHelper.convertToSI(category,value,char(unit)) ;
end

function value = optionalTemperature(value,unit)
    if isempty(value) || any(isnan(value)), value = NaN ;
    else, value = convert('Temperature',value,unit) ; end
end

function validateValues(value)
    if ~isnumeric(value) || numel(value) ~= 4 || ...
            any(~isfinite(value(1:3))) || value(1) < 0 || any(value(2:3) <= 0) || ...
            (~isnan(value(4)) && (~isfinite(value(4)) || value(4) <= 0))
        error('nirp:blocks:invalidJacket', ...
            'Jacket requires nonnegative finite U, positive A and Tin; Tout must be positive or NaN.') ;
    end
end
