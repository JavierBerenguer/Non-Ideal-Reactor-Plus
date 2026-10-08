classdef PFR < matlab.System
    % PFR wraps nirp.units.pfr with display-unit conversion and caching.
    % Degrees of freedom: specify V or tube geometry, one thermal mode, and
    % pressure-correlation data when pressure is nonconstant.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 8, 2026
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
        % Catalyst bulk density.
        CatalystDensity = 1
        % Catalyst void fraction.
        CatalystPorosity = 0
        % Thermal operating mode.
        HeatMode = 'Isothermal'
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
        % Show the Jacket signal input port.
        ShowJacketPort (1,1) logical = false
    end
    properties (Nontunable, Hidden)
        % Hidden since T-131 (D-057): no bypass or specified T/Q in the
        % flowsheet. Kept so the shared helper and older models still load.
        BypassRatio = 0
        SpecifiedT = 300
        SpecifiedTUnit = 'K'
        SpecifiedQ = 0
        SpecifiedQUnit = 'W'
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
        GeometryModeSet=matlab.system.StringSet({'Volume','Length'})
        VUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Volume'))
        VSourceSet=matlab.system.StringSet({'Dialog','Input port'})
        ASourceSet=matlab.system.StringSet({'Dialog','Input port'})
        UtilityTinSourceSet=matlab.system.StringSet({'Dialog','Input port'})
        LUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Length'))
        DUnitSet=matlab.system.StringSet(UnitConverterHelper.getUnits('Length'))
        % Heat exchange remains accepted only to diagnose saved old models.
        HeatModeSet=matlab.system.StringSet({'Isothermal','Adiabatic','Heat exchange'})
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
            if strcmp(obj.HeatMode,'Heat exchange')
                error('nirp:blocks:jacketRequired', ...
                    ['PFR Heat exchange mode is obsolete. Add a Jacket block, ' ...
                    'enable the Jacket input port, and connect it to the reactor.']);
            end
            [obj.Model,~,obj.RS]=nirp.blocks.internal.modelPackage(); obj.Block=get_param(gcb,'Name');
            obj.Params=nirp.blocks.internal.thermalParameters(obj);
            geometry=[UnitConverterHelper.convertToSI('Volume',obj.V,char(obj.VUnit)) ...
                UnitConverterHelper.convertToSI('Length',obj.L,char(obj.LUnit)) ...
                UnitConverterHelper.convertToSI('Length',obj.D,char(obj.DUnit)) obj.NTubes];
            if any(isnan(geometry))
                [geometry,~,message]=nirp.flowsheet.closeProduct(geometry,pi/4,[1 -1 -2 -1]);
                if strlength(message)>0||any(~isfinite(geometry))
                    if strlength(message)==0,message="PFR geometry is incomplete.";end
                    error('nirp:blocks:invalidGeometry','%s',message);
                end
                useLength=true;
            else
                useLength=strcmp(obj.GeometryMode,'Length');
            end
            if geometry(4)<1||abs(geometry(4)-round(geometry(4)))>1e-9
                error('nirp:blocks:invalidGeometry','Number of tubes must be a positive integer.');
            end
            if useLength,obj.Params.L=geometry(2);else,obj.Params.V=geometry(1);end
            obj.Params.D=geometry(3);
            obj.Params.nTubes=round(geometry(4)); obj.Params.pressureMode=char(obj.PressureMode);
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
            index=1+strcmp(obj.VSource,'Input port');
            if obj.ShowJacketPort
                jacket=varargin{index};
                if ~isnumeric(jacket)||~isequal(size(jacket),[4 1])|| ...
                        any(~isfinite(jacket(1:3)))||jacket(1)<0||any(jacket(2:3)<=0)|| ...
                        (~isnan(jacket(4))&&(~isfinite(jacket(4))||jacket(4)<=0))
                    error('nirp:blocks:invalidJacket','PFR Jacket input must be [U; A; Tin; Tout] in SI, with Tout optionally NaN.');
                end
                params.heatMode='Other';params.U=jacket(1);params.A=jacket(2);params.utilityTin=jacket(3);
                if isnan(jacket(4)),params.utilityTout=[];else,params.utilityTout=jacket(4);end
            end
            if ~isfield(params,'V'),params.V=pi/4*params.D^2*params.nTubes*params.L;end
            cacheInput={in,varargin{:}};
            if obj.HasCache && isequaln(cacheInput,obj.LastInput), out=obj.LastOutput; info=obj.LastInfo;
            else
                [out,info]=nirp.units.pfr(params,in,obj.RS); info.V=params.V; obj.LastInput=cacheInput; obj.LastOutput=out; obj.LastInfo=info;
                obj.HasCache=true; obj.CalculationCount=obj.CalculationCount+1;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out,info);
            end
            varargout{1}=out; if obj.ShowHeatPort, varargout{2}=info.heatDuty; end
        end
        function n=getNumInputsImpl(obj),n=1+strcmp(obj.VSource,'Input port')+double(obj.ShowJacketPort);end
        function n=getNumOutputsImpl(obj), n=1+double(obj.ShowHeatPort); end
        function varargout=getOutputDataTypeImpl(obj), varargout{1}='NirpStream'; if obj.ShowHeatPort,varargout{2}='double';end,end
        function varargout=getOutputSizeImpl(obj),varargout=repmat({[1 1]},1,1+double(obj.ShowHeatPort));end
        function varargout=isOutputFixedSizeImpl(obj),varargout=repmat({true},1,1+double(obj.ShowHeatPort));end
        function varargout=isOutputComplexImpl(obj),varargout=repmat({false},1,1+double(obj.ShowHeatPort));end
        function varargout=getInputNamesImpl(obj),varargout{1}='Feed';index=1;if strcmp(obj.VSource,'Input port'),index=index+1;varargout{index}='V (m^3)';end;if obj.ShowJacketPort,index=index+1;varargout{index}='Jacket';end,end
        function varargout=getOutputNamesImpl(obj),varargout{1}='Product';if obj.ShowHeatPort,varargout{2}='Heat (W)';end,end
        function icon=getIconImpl(~),icon='PFR';end
    end
    methods (Static,Access=protected)
        function groups=getPropertyGroupsImpl()
            groups=matlab.system.display.Section('Title','PFR','PropertyList',{'GeometryMode','VSource','V','VUnit','L','LUnit','D','DUnit','NTubes','HeatMode','CatalystDensity','CatalystPorosity','InitialTGuess','InitialTGuessUnit','PressureMode','PressureDropEqn','ParticleDiameter','ParticleDiameterUnit','Density','DensityUnit','Viscosity','ViscosityUnit','ShowJacketPort','ShowHeatPort'});
        end
        function mode=getSimulateUsingImpl(),mode='Interpreted execution';end
        function flag=showSimulateUsingImpl(),flag=false;end
    end
end
