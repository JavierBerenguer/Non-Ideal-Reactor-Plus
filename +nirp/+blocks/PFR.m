classdef PFR < matlab.System
    % PFR wraps nirp.units.pfr with display-unit conversion and caching.
    % Degrees of freedom: specify V or tube geometry, one thermal mode, and
    % pressure-correlation data when pressure is nonconstant.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Nontunable)
        % Geometry specified as reactor volume or tube length.
        GeometryMode = 'Volume'
        % Reactor volume.
        V = 0.1
        % Source of reactor volume.
        VSource = 'Dialog'
        % Reactor-volume unit.
        VUnit = 'm^3'
        % Tube length.
        L = 1
        % Tube-length unit.
        LUnit = 'm'
        % Tube diameter.
        D = 0.1
        % Tube-diameter unit.
        DUnit = 'm'
        % Number of equal parallel tubes.
        NTubes = 1
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
        % Utility outlet temperature; NaN means constant temperature.
        UtilityTout = NaN
        % Utility-outlet-temperature unit.
        UtilityToutUnit = 'K'
        % Optional outlet-temperature initial guess.
        InitialTGuess = NaN
        % Initial-temperature-guess unit.
        InitialTGuessUnit = 'K'
        % Pressure calculation mode.
        PressureMode = 'Constant'
        % Pressure-drop correlation (Pipe or Ergun).
        PressureDropEqn = 'Pipe'
        % Particle diameter for the Ergun correlation.
        ParticleDiameter = 1
        % Particle-diameter unit.
        ParticleDiameterUnit = 'mm'
        % Fluid density used by liquid pressure-drop correlations.
        Density = 1000
        % Fluid-density unit.
        DensityUnit = 'kg/m^3'
        % Fluid dynamic viscosity used by pressure-drop correlations.
        Viscosity = 1e-3
        % Dynamic-viscosity unit.
        ViscosityUnit = 'Pa*s'
        % Show the heat-duty output port.
        ShowHeatPort (1,1) logical = false
    end
    properties (Constant, Hidden)
        GeometryModeSet=matlab.system.StringSet({'Volume','Length'})
        VUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Volume'))
        VSourceSet=matlab.system.StringSet({'Dialog','Input port'})
        LUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Length'))
        DUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Length'))
        HeatModeSet=matlab.system.StringSet({'Isothermal','Adiabatic','Heat exchange','Specified T','Specified Q'})
        SpecifiedTUnitSet=matlab.system.StringSet({'K',[char(176) 'C']})
        SpecifiedQUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Power'))
        UUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('HeatTransferCoefficient'))
        AUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Area'))
        UtilityTinUnitSet=matlab.system.StringSet({'K',[char(176) 'C']})
        UtilityToutUnitSet=matlab.system.StringSet({'K',[char(176) 'C']})
        InitialTGuessUnitSet=matlab.system.StringSet({'K',[char(176) 'C']})
        PressureModeSet=matlab.system.StringSet({'Constant','Non constant'})
        PressureDropEqnSet=matlab.system.StringSet({'Pipe','Ergun'})
        ParticleDiameterUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Length'))
        DensityUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Density'))
        ViscosityUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Viscosity'))
    end
    properties (Access=private)
        RS; Params; LastInput; LastOutput; LastInfo; HasCache=false
        CalculationCount=0; Model; Block
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.Params=nirp.blocks.internal.thermalParameters(obj);
            if strcmp(obj.Params.heatMode,'Heat exchange'), obj.Params.heatMode='Other'; end
            if strcmp(obj.GeometryMode,'Volume')
                obj.Params.V=UnitConverterHelper.convertToSI('Volume',obj.V,char(obj.VUnit));
            else
                obj.Params.L=UnitConverterHelper.convertToSI('Length',obj.L,char(obj.LUnit));
            end
            obj.Params.D=UnitConverterHelper.convertToSI('Length',obj.D,char(obj.DUnit));
            obj.Params.nTubes=obj.NTubes; obj.Params.pressureMode=char(obj.PressureMode);
            obj.Params.pressureDropEqn=char(obj.PressureDropEqn);
            obj.Params.particleDiameter=UnitConverterHelper.convertToSI('Length',obj.ParticleDiameter,char(obj.ParticleDiameterUnit));
            obj.Params.density=UnitConverterHelper.convertToSI('Density',obj.Density,char(obj.DensityUnit));
            obj.Params.viscosity=UnitConverterHelper.convertToSI('Viscosity',obj.Viscosity,char(obj.ViscosityUnit));
            obj.HasCache=false; obj.CalculationCount=0;
        end
        function varargout=stepImpl(obj,in,varargin)
            nirp.stream.validate(in,obj.RS.nComponents);
            params=obj.Params;
            if strcmp(obj.VSource,'Input port')
                value=varargin{1};
                if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<=0,error('nirp:blocks:invalidParameterPort','PFR V input must be positive m^3.');end
                params.V=value;
            end
            cacheInput={in,varargin{:}};
            if obj.HasCache && isequaln(cacheInput,obj.LastInput), out=obj.LastOutput; info=obj.LastInfo;
            else
                [out,info]=nirp.units.pfr(params,in,obj.RS); obj.LastInput=cacheInput; obj.LastOutput=out; obj.LastInfo=info;
                obj.HasCache=true; obj.CalculationCount=obj.CalculationCount+1;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out,info);
            end
            varargout{1}=out; if obj.ShowHeatPort, varargout{2}=info.heatDuty; end
        end
        function n=getNumInputsImpl(obj),n=1+strcmp(obj.VSource,'Input port');end
        function n=getNumOutputsImpl(obj), n=1+double(obj.ShowHeatPort); end
        function varargout=getOutputDataTypeImpl(obj), varargout{1}='NirpStream'; if obj.ShowHeatPort,varargout{2}='double';end,end
        function varargout=getOutputSizeImpl(obj),varargout=repmat({[1 1]},1,1+double(obj.ShowHeatPort));end
        function varargout=isOutputFixedSizeImpl(obj),varargout=repmat({true},1,1+double(obj.ShowHeatPort));end
        function varargout=isOutputComplexImpl(obj),varargout=repmat({false},1,1+double(obj.ShowHeatPort));end
        function varargout=getInputNamesImpl(obj),varargout{1}='Feed';if strcmp(obj.VSource,'Input port'),varargout{2}='V (m^3)';end,end
        function varargout=getOutputNamesImpl(obj),varargout{1}='Product';if obj.ShowHeatPort,varargout{2}='Heat (W)';end,end
        function icon=getIconImpl(~),icon='PFR';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl()
            groups=matlab.system.display.Section('Title','PFR','PropertyList',{'GeometryMode','VSource','V','VUnit','L','LUnit','D','DUnit','NTubes','HeatMode','SpecifiedT','SpecifiedTUnit','SpecifiedQ','SpecifiedQUnit','U','UUnit','A','AUnit','UtilityTin','UtilityTinUnit','UtilityTout','UtilityToutUnit','BypassRatio','CatalystDensity','CatalystPorosity','InitialTGuess','InitialTGuessUnit','PressureMode','PressureDropEqn','ParticleDiameter','ParticleDiameterUnit','Density','DensityUnit','Viscosity','ViscosityUnit','ShowHeatPort'});
        end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
