classdef CSTR < matlab.System
    % CSTR wraps nirp.units.cstr with display-unit conversion and caching.
    % Degrees of freedom: specify V and one thermal-mode condition; the
    % material and energy balances determine the outlet stream.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Nontunable)
        % Reactor volume.
        V = 0.1
        % Source of reactor volume.
        VSource = 'Dialog'
        % Reactor-volume unit.
        VUnit = 'm^3'
        % Feed-to-reactor bypass ratio (bypass flow/reactor flow).
        BypassRatio = 0
        % Catalyst bulk density.
        CatalystDensity = 1
        % Catalyst void fraction.
        CatalystPorosity = 0
        % Thermal operating mode.
        HeatMode = 'Isothermal'
        % Specified outlet temperature.
        SpecifiedT = 300
        % Specified-temperature unit.
        SpecifiedTUnit = 'K'
        % Specified heat duty.
        SpecifiedQ = 0
        % Specified-duty unit.
        SpecifiedQUnit = 'W'
        % Overall heat-transfer coefficient.
        U = 0
        % Heat-transfer-coefficient unit.
        UUnit = 'W/(m^2*K)'
        % Heat-transfer area.
        A = 1
        % Heat-transfer-area unit.
        AUnit = 'm^2'
        % Utility inlet temperature.
        UtilityTin = 300
        % Utility-inlet-temperature unit.
        UtilityTinUnit = 'K'
        % Utility outlet temperature; NaN means constant utility temperature.
        UtilityTout = NaN
        % Utility-outlet-temperature unit.
        UtilityToutUnit = 'K'
        % Optional reactor outlet-temperature initial guess.
        InitialTGuess = NaN
        % Initial-temperature-guess unit.
        InitialTGuessUnit = 'K'
        % Show the heat-duty output port.
        ShowHeatPort (1,1) logical = false
    end

    properties (Constant, Hidden)
        VUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Volume'))
        VSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        HeatModeSet = matlab.system.StringSet({'Isothermal','Adiabatic', ...
            'Heat exchange','Specified T','Specified Q'})
        SpecifiedTUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        SpecifiedQUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Power'))
        UUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('HeatTransferCoefficient'))
        AUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Area'))
        UtilityTinUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        UtilityToutUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        InitialTGuessUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
    end

    properties (Access = private)
        RS
        Params
        LastInput
        LastOutput
        LastInfo
        HasCache = false
        CalculationCount = 0
        Model
        Block
    end

    methods (Access = protected)
        function setupImpl(obj)
            [obj.Model,~,obj.RS] = nirp.blocks.internal.modelPackage() ;
            obj.Block = get_param(gcb,'Name') ;
            obj.Params = nirp.blocks.internal.thermalParameters(obj) ;
            obj.Params.V = UnitConverterHelper.convertToSI('Volume',obj.V,char(obj.VUnit)) ;
            if strcmp(obj.Params.heatMode,'Heat exchange')
                obj.Params.heatMode = 'Other' ;
            end
            obj.HasCache = false ;
            obj.CalculationCount = 0 ;
        end

        function varargout = stepImpl(obj,in,varargin)
            nirp.stream.validate(in,obj.RS.nComponents) ;
            params = obj.Params ;
            if strcmp(obj.VSource,'Input port')
                value = varargin{1} ;
                if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value) || value <= 0
                    error('nirp:blocks:invalidParameterPort','CSTR V input must be positive m^3.') ;
                end
                params.V = value ;
            end
            cacheInput = {in,varargin{:}} ;
            if obj.HasCache && isequaln(cacheInput,obj.LastInput)
                out = obj.LastOutput ; info = obj.LastInfo ;
            else
                [out,info] = nirp.units.cstr(params,in,obj.RS) ;
                info.V = params.V ;
                obj.LastInput = cacheInput ; obj.LastOutput = out ; obj.LastInfo = info ;
                obj.HasCache = true ; obj.CalculationCount = obj.CalculationCount+1 ;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out,info) ;
            end
            varargout{1} = out ;
            if obj.ShowHeatPort, varargout{2} = info.heatDuty ; end
        end

        function n = getNumInputsImpl(obj), n = 1+strcmp(obj.VSource,'Input port') ; end
        function n = getNumOutputsImpl(obj), n = 1+double(obj.ShowHeatPort) ; end
        function varargout = getOutputDataTypeImpl(obj)
            varargout{1} = 'NirpStream' ;
            if obj.ShowHeatPort, varargout{2} = 'double' ; end
        end
        function varargout = getOutputSizeImpl(obj)
            varargout = repmat({[1 1]},1,1+double(obj.ShowHeatPort)) ;
        end
        function varargout = isOutputFixedSizeImpl(obj)
            varargout = repmat({true},1,1+double(obj.ShowHeatPort)) ;
        end
        function varargout = isOutputComplexImpl(obj)
            varargout = repmat({false},1,1+double(obj.ShowHeatPort)) ;
        end
        function varargout = getInputNamesImpl(obj)
            varargout{1} = 'Feed' ;
            if strcmp(obj.VSource,'Input port'), varargout{2} = 'V (m^3)' ; end
        end
        function varargout = getOutputNamesImpl(obj)
            varargout{1} = 'Product' ;
            if obj.ShowHeatPort, varargout{2} = 'Heat (W)' ; end
        end
        function icon = getIconImpl(~), icon = 'CSTR' ; end
    end

    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','CSTR', ...
                'PropertyList',{'VSource','V','VUnit','HeatMode','SpecifiedT', ...
                'SpecifiedTUnit','SpecifiedQ','SpecifiedQUnit','U','UUnit', ...
                'A','AUnit','UtilityTin','UtilityTinUnit','UtilityTout', ...
                'UtilityToutUnit','BypassRatio','CatalystDensity', ...
                'CatalystPorosity','InitialTGuess','InitialTGuessUnit','ShowHeatPort'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
