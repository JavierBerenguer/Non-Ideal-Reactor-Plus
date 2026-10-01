classdef Heater < matlab.System
    % Heater wraps nirp.units.heater with display-unit conversion and caching.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
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
    end
    properties (Constant, Hidden)
        ModeSet = matlab.system.StringSet({'Outlet T','Duty'})
        ToutUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        DutyUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Power'))
        PressureDropUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Pressure'))
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
            obj.Params.mode = char(obj.Mode) ;
            obj.Params.Tout = UnitConverterHelper.convertToSI('Temperature',obj.Tout,char(obj.ToutUnit)) ;
            obj.Params.Q = UnitConverterHelper.convertToSI('Power',obj.Duty,char(obj.DutyUnit)) ;
            obj.Params.dP = UnitConverterHelper.convertToSI('Pressure',obj.PressureDrop,char(obj.PressureDropUnit)) ;
            obj.HasCache = false ; obj.CalculationCount = 0 ;
        end
        function varargout = stepImpl(obj,in)
            nirp.stream.validate(in,obj.RS.nComponents) ;
            if obj.HasCache && isequaln(in,obj.LastInput)
                out = obj.LastOutput ; info = obj.LastInfo ;
            else
                [out,info] = nirp.units.heater(obj.Params,in,obj.RS) ;
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
        function icon = getIconImpl(~), icon='Heater / Cooler'; end
    end
    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups=matlab.system.display.Section('Title','Heater / Cooler','PropertyList', ...
                {'Mode','Tout','ToutUnit','Duty','DutyUnit','PressureDrop','PressureDropUnit','ShowHeatPort'});
        end
        function mode=getSimulateUsingImpl(), mode='Interpreted execution'; end
        function flag=showSimulateUsingImpl(), flag=false; end
    end
end
