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
        OutputSpecs
    end
    methods (Access = protected)
        function setupImpl(obj)
            [obj.Model,pkg,obj.RS] = nirp.blocks.internal.modelPackage() ;
            obj.Block = get_param(gcb,'Name') ;
            obj.Specs=nirp.dof.readSpecs(obj.Specifications);obj.OutputSpecs=nirp.dof.connectedSpecifications(gcb);
            missing=strings(0,1);if isempty(strtrim(obj.Specifications))&&isempty(fieldnames(obj.Specs))&&isempty(fieldnames(obj.OutputSpecs.values)),if strcmp(obj.Mode,'Select...'),missing(end+1)="Mode";elseif strcmp(obj.Mode,'Outlet T')&&~isfinite(obj.Tout),missing(end+1)="Tout";elseif strcmp(obj.Mode,'Duty')&&~isfinite(obj.Duty),missing(end+1)="Duty";end;if ~isfinite(obj.PressureDrop),missing(end+1)="PressureDrop";end,end
            nirp.blocks.internal.requireSpecifications('Heater',obj.Block,missing);
            nirp.blocks.internal.requireThermodynamics(pkg,sprintf('Heater "%s"',obj.Block)) ;
            obj.Params.mode = char(obj.Mode) ;
            obj.Params.Tout = UnitConverterHelper.convertToSI('Temperature',obj.Tout,char(obj.ToutUnit)) ;
            obj.Params.Q = UnitConverterHelper.convertToSI('Power',obj.Duty,char(obj.DutyUnit)) ;
            obj.Params.dP = UnitConverterHelper.convertToSI('Pressure',obj.PressureDrop,char(obj.PressureDropUnit)) ;
            if ~isempty(strtrim(obj.Specifications))||~isempty(fieldnames(obj.Specs))||~isempty(fieldnames(obj.OutputSpecs.values))
                if isempty(fieldnames(obj.Specs))&&isempty(strtrim(obj.Specifications)),obj.Specs=legacySpecs(obj);end
                result=solveDof(obj,[],pkg,obj.RS);requireDof(obj.Block,result);
            end
            obj.HasCache = false ; obj.CalculationCount = 0 ;
        end
        function varargout = stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents) ;
            if obj.HasCache && isequaln(in,obj.LastInput)
                out = obj.LastOutput ; info = obj.LastInfo ;
            else
                evaluated = [obj.Model '/' obj.Block] ;
                [unitOutputs,info] = nirp.blocks.internal.evaluate(evaluated,{in}, ...
                    'ReactionSystem',obj.RS) ;
                out = unitOutputs{1} ;
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
    origins=struct('T_in','external','P_in','external');model=nirp.dof.catalog.heater(context);
    result=nirp.dof.resolveProducer(model,'Heater',obj.Block,obj.Specs,obj.OutputSpecs,values,origins);
end
function specs=legacySpecs(obj)
    specs=struct();
    if strcmp(obj.Mode,'Duty'),specs.Q=struct('si',UnitConverterHelper.convertToSI('Power',obj.Duty,char(obj.DutyUnit)),'unit',char(obj.DutyUnit));
    elseif ~strcmp(obj.Mode,'Select...'),specs.T_out=struct('si',UnitConverterHelper.convertToSI('Temperature',obj.Tout,char(obj.ToutUnit)),'unit',char(obj.ToutUnit));end
    if isfinite(obj.PressureDrop),specs.dP=struct('si',UnitConverterHelper.convertToSI('Pressure',obj.PressureDrop,char(obj.PressureDropUnit)),'unit',char(obj.PressureDropUnit));end
end
function requireDof(block,result)
    if strcmp(result.status,'complete'),return,end
    if strcmp(result.status,'missing'),error('nirp:blocks:missingSpecifications','Heater "%s": %d specifications missing: %s.',block,result.missingCount,strjoin(result.missing,', '));end
    error('nirp:blocks:conflictingSpecifications','Heater "%s": conflict in %s: %s',block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
