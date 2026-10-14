classdef CSTR < matlab.System
    % CSTR wraps nirp.units.cstr with display-unit conversion and caching.
    % Degrees of freedom: specify V and one thermal-mode condition; the
    % material and energy balances determine the outlet stream.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 14, 2026
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
        % Reactions that take place here (package numbers); empty = all.
        Reactions = ''
        % Show the heat-duty output port.
        ShowHeatPort (1,1) logical = false
        % Show the Jacket signal input port.
        ShowJacketPort (1,1) logical = false
        % JSON containing only user specifications; empty means legacy.
        Specifications = ''
        % Select the catalyst form of the DOF catalogue.
        Catalytic (1,1) logical = false
        % Last displayed residence time, space velocity, and catalyst mass.
        Tau = NaN
        TauUnit = 's'
        SpaceVelocity = NaN
        SpaceVelocityUnit = '1/s'
        CatalystMass = NaN
        CatalystMassUnit = 'kg'
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
        HeatModeSet = matlab.system.StringSet({'Select...','Isothermal','Adiabatic', ...
            'Heat exchange'})
        SpecifiedTUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        SpecifiedQUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Power'))
        UUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('HeatTransferCoefficient'))
        AUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Area'))
        UtilityTinUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        UtilityToutUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        InitialTGuessUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        TauUnitSet = matlab.system.StringSet({'s','min','h'})
        SpaceVelocityUnitSet = matlab.system.StringSet({'1/s','1/min','1/h'})
        CatalystMassUnitSet = matlab.system.StringSet({'kg','g'})
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
        Specs
        DofModel
    end

    methods (Access = protected)
        function setupImpl(obj)
            [obj.Model,pkg,obj.RS] = nirp.blocks.internal.modelPackage() ;
            if ~isempty(obj.Reactions) && any(strlength(strtrim(string(obj.Reactions))) > 0)
                % T-147: the reactor only uses the selected reactions.
                obj.RS = nirp.pkg.toReactionSys(nirp.pkg.selectReactions(pkg,obj.Reactions)) ;
            end
            obj.Block = get_param(gcb,'Name') ;
            obj.Specs=nirp.dof.readSpecs(obj.Specifications) ;
            missing=strings(0,1);if strcmp(obj.HeatMode,'Select...'),missing(end+1)="HeatMode";end
            if isempty(fieldnames(obj.Specs))&&strcmp(obj.VSource,'Dialog')&&~isfinite(obj.V),missing(end+1)="V";end
            nirp.blocks.internal.requireSpecifications('CSTR',obj.Block,missing);
            if ~strcmp(obj.HeatMode,'Isothermal') || obj.ShowJacketPort
                nirp.blocks.internal.requireThermodynamics(pkg,sprintf('CSTR "%s"',obj.Block)) ;
            end
            obj.Params = nirp.blocks.internal.thermalParameters(obj) ;
            if isnan(obj.Params.catalystDensity),obj.Params.catalystDensity=1;end
            if isnan(obj.Params.catalystPorosity),obj.Params.catalystPorosity=0;end
            obj.Params.V = UnitConverterHelper.convertToSI('Volume',obj.V,char(obj.VUnit)) ;
            if ~isempty(fieldnames(obj.Specs))
                obj.DofModel=nirp.dof.catalog.cstr(struct('catalytic',obj.Catalytic)) ;
                result=solveDof(obj,obj.Params,NaN,NaN) ;
                requireDof(obj.Block,result) ;
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
            if ~isempty(fieldnames(obj.Specs))
                externalV=NaN;if strcmp(obj.VSource,'Input port'),externalV=params.V;end
                result=solveDof(obj,params,in.Q,externalV);requireDof(obj.Block,result);
                params.V=result.values.V;
                if obj.Catalytic
                    params.catalystDensity=result.values.rho_cat;
                    params.catalystPorosity=result.values.epsilon;
                end
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
                'InitialTGuessUnit','Reactions','ShowJacketPort','ShowHeatPort', ...
                'Specifications','Catalytic','Tau','TauUnit','SpaceVelocity', ...
                'SpaceVelocityUnit','CatalystMass','CatalystMassUnit'}) ;
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

function result=solveDof(obj,~,flow,externalV)
    values=struct('Q0',flow);origins=struct('Q0','external');
    names=fieldnames(obj.Specs);allowed={obj.DofModel.variables.name};
    if strcmp(obj.VSource,'Input port')
        forbidden=intersect(names,{'tau','SV','W'},'stable');
        if ~isempty(forbidden),error('nirp:blocks:conflictingSpecifications','CSTR "%s": %s cannot be specified when V comes from an input port.',obj.Block,strjoin(forbidden,', '));end
        values.V=externalV;origins.V='external';
    end
    for i=1:numel(names)
        index=find(strcmp(allowed,names{i}),1);
        if isempty(index)||~obj.DofModel.variables(index).specifiable
            error('nirp:blocks:invalidSpecifications','Unknown or non-specifiable CSTR specification "%s".',names{i});
        end
        values.(names{i})=obj.Specs.(names{i}).si;origins.(names{i})='specified';
    end
    result=nirp.dof.solve(obj.DofModel,values,origins);
end
function requireDof(block,result)
    if strcmp(result.status,'complete'),return,end
    if strcmp(result.status,'missing'),error('nirp:blocks:missingSpecifications','CSTR "%s": %d specifications missing: %s.',block,result.missingCount,strjoin(result.missing,', '));end
    error('nirp:blocks:conflictingSpecifications','CSTR "%s": conflict in %s: %s',block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
