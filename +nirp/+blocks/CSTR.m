classdef CSTR < matlab.System
    % CSTR wraps nirp.units.cstr with display-unit conversion and caching.
    % Degrees of freedom: specify V and one thermal-mode condition; the
    % material and energy balances determine the outlet stream.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 8, 2026
    % =========================================================================

    properties (Nontunable)
        % Reactor volume.
        V = 0.1
        % Source of reactor volume.
        VSource = 'Dialog'
        % Reactor-volume unit.
        VUnit = 'm^3'
        % Catalyst bulk density.
        CatalystDensity = 1
        % Catalyst void fraction.
        CatalystPorosity = 0
        % Thermal operating mode.
        HeatMode = 'Isothermal'
        % Optional reactor outlet-temperature initial guess.
        InitialTGuess = NaN
        % Initial-temperature-guess unit.
        InitialTGuessUnit = 'K'
        % Show the heat-duty output port.
        ShowHeatPort (1,1) logical = false
        % Show the Jacket signal input port.
        ShowJacketPort (1,1) logical = false
    end

    properties (Nontunable, Hidden)
        % Hidden since T-131 (D-057): in a flowsheet a bypass is a Splitter
        % and a Mixer, and the operating temperature is set by the inlet
        % stream (a Heater before an isothermal reactor). Kept so the
        % shared thermal-parameter helper and older models still load.
        BypassRatio = 0
        SpecifiedT = 300
        SpecifiedTUnit = 'K'
        SpecifiedQ = 0
        SpecifiedQUnit = 'W'
        % Legacy heat-exchange properties retained only so old models can
        % load and report an actionable migration error.
        ASource = 'Dialog'
        UtilityTinSource = 'Dialog'
        U = 0
        UUnit = 'W/(m^2*K)'
        A = 1
        AUnit = 'm^2'
        UtilityTin = 300
        UtilityTinUnit = 'K'
        UtilityTout = NaN
        UtilityToutUnit = 'K'
    end

    properties (Constant, Hidden)
        VUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Volume'))
        VSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        ASourceSet = matlab.system.StringSet({'Dialog','Input port'})
        UtilityTinSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        % Heat exchange remains accepted only to diagnose saved old models.
        HeatModeSet = matlab.system.StringSet({'Isothermal','Adiabatic', ...
            'Heat exchange'})
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
            [obj.Model,pkg,obj.RS] = nirp.blocks.internal.modelPackage() ;
            obj.Block = get_param(gcb,'Name') ;
            if ~strcmp(obj.HeatMode,'Isothermal') || obj.ShowJacketPort
                nirp.blocks.internal.requireThermodynamics(pkg,sprintf('CSTR "%s"',obj.Block)) ;
            end
            obj.Params = nirp.blocks.internal.thermalParameters(obj) ;
            obj.Params.V = UnitConverterHelper.convertToSI('Volume',obj.V,char(obj.VUnit)) ;
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
            index = 1+strcmp(obj.VSource,'Input port') ;
            if obj.hasJacket()
                params = nirp.blocks.internal.applyJacket(params,varargin{index},'CSTR') ;
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

        function n = getNumInputsImpl(obj)
            n = 1+strcmp(obj.VSource,'Input port')+double(obj.hasJacket()) ;
        end
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
            index = 1 ;
            if strcmp(obj.VSource,'Input port'), index=index+1;varargout{index}='V (m^3)';end
            if obj.hasJacket(), index=index+1;varargout{index}='Jacket';end
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
                'PropertyList',{'VSource','V','VUnit','HeatMode', ...
                'CatalystDensity','CatalystPorosity','InitialTGuess', ...
                'InitialTGuessUnit','ShowJacketPort','ShowHeatPort'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
    methods (Access = private)
        function flag = hasJacket(obj)
            % T-146: Heat exchange opens the Jacket port; ShowJacketPort is
            % kept for models saved before (Isothermal + Jacket port).
            flag = strcmp(obj.HeatMode,'Heat exchange') || obj.ShowJacketPort ;
        end
    end
end
