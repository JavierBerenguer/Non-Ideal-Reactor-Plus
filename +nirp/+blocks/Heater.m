classdef Heater < matlab.System
    % Heater wraps nirp.units.heater with display-unit conversion and caching.
    % Degrees of freedom: specify outlet T or duty plus pressure loss; the
    % energy balance determines the other thermal variable.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 14, 2026
    % =========================================================================

    properties (Nontunable)
        % Calculation mode.
        Mode = 'Outlet T'
        % Specified outlet temperature.
        Tout = 300
        % Outlet-temperature unit.
        ToutUnit = 'K'
        % Specified heat duty; positive heat enters the stream.
        Duty = 0
        % Heat-duty unit.
        DutyUnit = 'W'
        % Pressure loss.
        PressureDrop = 0
        % Pressure-loss unit.
        PressureDropUnit = 'Pa'
        % Show the heat-duty output port.
        ShowHeatPort (1,1) logical = false
        % JSON containing only user specifications; empty means legacy.
        Specifications = ''
    end
    properties (Constant, Hidden)
        ModeSet = matlab.system.StringSet({'Select...','Outlet T','Duty'})
        ToutUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        DutyUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Power'))
        PressureDropUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Pressure'))
    end
    properties (Nontunable, Hidden)
        TemperatureChange = NaN
        TemperatureChangeUnit = 'K'
        OutletPressure = NaN
        OutletPressureUnit = 'Pa'
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
    end
    methods (Access = protected)
        function setupImpl(obj)
            [obj.Model,pkg,obj.RS] = nirp.blocks.internal.modelPackage() ;
            obj.Block = get_param(gcb,'Name') ;
            obj.Specs=nirp.dof.readSpecs(obj.Specifications);
            missing=strings(0,1);if isempty(fieldnames(obj.Specs)),if strcmp(obj.Mode,'Select...'),missing(end+1)="Mode";elseif strcmp(obj.Mode,'Outlet T')&&~isfinite(obj.Tout),missing(end+1)="Tout";elseif strcmp(obj.Mode,'Duty')&&~isfinite(obj.Duty),missing(end+1)="Duty";end;if ~isfinite(obj.PressureDrop),missing(end+1)="PressureDrop";end,end
            nirp.blocks.internal.requireSpecifications('Heater',obj.Block,missing);
            nirp.blocks.internal.requireThermodynamics(pkg,sprintf('Heater "%s"',obj.Block)) ;
            obj.Params.mode = char(obj.Mode) ;
            obj.Params.Tout = UnitConverterHelper.convertToSI('Temperature',obj.Tout,char(obj.ToutUnit)) ;
            obj.Params.Q = UnitConverterHelper.convertToSI('Power',obj.Duty,char(obj.DutyUnit)) ;
            obj.Params.dP = UnitConverterHelper.convertToSI('Pressure',obj.PressureDrop,char(obj.PressureDropUnit)) ;
            if ~isempty(fieldnames(obj.Specs))
                result=solveDof(obj,[],pkg,obj.RS);requireDof(obj.Block,result);
            end
            obj.HasCache = false ; obj.CalculationCount = 0 ;
        end
        function varargout = stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents) ;
            if obj.HasCache && isequaln(in,obj.LastInput)
                out = obj.LastOutput ; info = obj.LastInfo ;
            else
                params=obj.Params;
                if ~isempty(fieldnames(obj.Specs))
                    result=solveDof(obj,in,[],obj.RS);requireDof(obj.Block,result);
                    params.dP=result.values.dP;
                    if isfield(obj.Specs,'Q'),params.mode='Duty';params.Q=result.values.Q;else,params.mode='Outlet T';params.Tout=result.values.T_out;end
                end
                [out,info] = nirp.units.heater(params,in,obj.RS) ;
                obj.LastInput = in ; obj.LastOutput = out ; obj.LastInfo = info ;
                obj.HasCache = true ; obj.CalculationCount = obj.CalculationCount+1 ;
                nirp.blocks.internal.diagnostic(obj.Model,obj.Block,obj.CalculationCount,out,info) ;
            end
            varargout{1} = out ;
            if obj.ShowHeatPort, varargout{2} = info.heatDuty ; end
        end
        function n = getNumOutputsImpl(obj), n = 1+double(obj.ShowHeatPort) ; end
        function varargout = getOutputDataTypeImpl(obj), varargout{1}='NirpStream'; if obj.ShowHeatPort, varargout{2}='double'; end, end
        function varargout = getOutputSizeImpl(obj), varargout=repmat({[1 1]},1,1+double(obj.ShowHeatPort)); end
        function varargout = isOutputFixedSizeImpl(obj), varargout=repmat({true},1,1+double(obj.ShowHeatPort)); end
        function varargout = isOutputComplexImpl(obj), varargout=repmat({false},1,1+double(obj.ShowHeatPort)); end
        function name = getInputNamesImpl(~), name='Feed'; end
        function varargout = getOutputNamesImpl(obj), varargout{1}='Product'; if obj.ShowHeatPort, varargout{2}='Heat (W)'; end, end
        function icon = getIconImpl(~), icon=sprintf('Heater\nCooler'); end
    end
    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups=matlab.system.display.Section('Title','Heater / Cooler','PropertyList', ...
                {'Mode','Tout','ToutUnit','Duty','DutyUnit','PressureDrop','PressureDropUnit','ShowHeatPort','Specifications'});
        end
        function mode=getSimulateUsingImpl(), mode='Interpreted execution'; end
        function flag=showSimulateUsingImpl(), flag=false; end
    end
end

function result=solveDof(obj,in,~,rs)
    if isempty(in),context=struct('inlet',[],'RS',rs);values=struct('T_in',NaN,'P_in',NaN);else,context=struct('inlet',in,'RS',rs);values=struct('T_in',in.T,'P_in',in.P);end
    origins=struct('T_in','external','P_in','external');model=nirp.dof.catalog.heater(context);names=fieldnames(obj.Specs);allowed={model.variables.name};
    for i=1:numel(names),index=find(strcmp(allowed,names{i}),1);if isempty(index)||~model.variables(index).specifiable,error('nirp:blocks:invalidSpecifications','Unknown or non-specifiable Heater specification "%s".',names{i});end;values.(names{i})=obj.Specs.(names{i}).si;origins.(names{i})='specified';end
    result=nirp.dof.solve(model,values,origins);
end
function requireDof(block,result)
    if strcmp(result.status,'complete'),return,end
    if strcmp(result.status,'missing'),error('nirp:blocks:missingSpecifications','Heater "%s": %d specifications missing: %s.',block,result.missingCount,strjoin(result.missing,', '));end
    error('nirp:blocks:conflictingSpecifications','Heater "%s": conflict in %s: %s',block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
