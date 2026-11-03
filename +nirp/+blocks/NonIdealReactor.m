classdef NonIdealReactor < matlab.System
    % NonIdealReactor wraps the RTD-based liquid-reactor unit operation.
    % All calculation parameters are converted to SI by the shared
    % flowsheet evaluator so Run and preview use the same implementation.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: November 3, 2026. Last update: November 3, 2026
    % =========================================================================

    properties (Nontunable)
        % Source used to define the residence-time distribution.
        RTDOrigin = 'Select...'
        % Analytical RTD model.
        Model = 'Select...'
        % Model size entered as volume or residence time.
        SizeBasis = 'Volume'
        % Source of the selected model-size parameter.
        SizeSource = 'Dialog'
        % Reactor volume and display unit.
        V = NaN
        VUnit = 'm^3'
        % Space time and display unit.
        Tau = NaN
        TauUnit = 's'
        % Number of equal tanks in series.
        N = NaN
        % Peclet number and dispersion boundary condition.
        Pe = NaN
        Boundary = 'open'
        % Tabulated RTD time (display unit) and E (1/display unit).
        DataTime = NaN
        DataE = NaN
        DataTimeUnit = 's'
        % NonIdealReactorApp MAT session containing an RTD.
        SessionFile = ''
        % Micromixing model used by this reactor.
        Micromixing = 'Select...'
        % Isothermal operating-temperature source.
        TemperatureMode = 'Inlet'
        SpecifiedT = NaN
        SpecifiedTUnit = 'K'
        % Reactions that take place here (package numbers); empty = all.
        Reactions = ''
        % Show the heat-duty output port.
        ShowHeatPort (1,1) logical = false
        % Reserved JSON specifications for the structured editor (T-215).
        Specifications = ''
    end

    properties (Constant, Hidden)
        RTDOriginSet = matlab.system.StringSet( ...
            {'Select...','Model','Data','Session'})
        ModelSet = matlab.system.StringSet( ...
            {'Select...','CSTR','PFR','Tanks in series','Dispersion'})
        SizeBasisSet = matlab.system.StringSet({'Volume','Residence time'})
        SizeSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        VUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Volume'))
        TauUnitSet = matlab.system.StringSet({'s','min','h'})
        BoundarySet = matlab.system.StringSet({'open','closed'})
        DataTimeUnitSet = matlab.system.StringSet({'s','min','h'})
        MicromixingSet = matlab.system.StringSet( ...
            {'Select...','Segregation','Maximum mixedness'})
        TemperatureModeSet = matlab.system.StringSet({'Inlet','Specified'})
        SpecifiedTUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
    end

    properties (Access = private)
        RS
        ModelName
        Block
        LastInput
        LastOutput
        LastInfo
        CacheKey
        HasCache = false
        CalculationCount = 0
    end

    methods
        function icon = iconText(obj)
            %ICONTEXT Return the same three-line label rendered in Simulink.
            icon = sprintf('Non-ideal reactor\n%s\n%s', ...
                obj.rtdIconText(),obj.micromixingCode()) ;
        end
    end

    methods (Access = protected)
        function setupImpl(obj)
            [obj.ModelName,pkg,obj.RS] = nirp.blocks.internal.modelPackage() ;
            if ~isempty(strtrim(char(string(obj.Reactions))))
                selected = nirp.pkg.selectReactions(pkg,obj.Reactions) ;
                obj.RS = nirp.pkg.toReactionSys(selected) ;
            end
            obj.Block = get_param(gcb,'Name') ;
            missing = obj.missingSpecifications() ;
            nirp.blocks.internal.requireSpecifications( ...
                'Non-ideal Reactor',obj.Block,missing) ;
            if obj.ShowHeatPort
                nirp.blocks.internal.requireThermodynamics(pkg, ...
                    sprintf('Non-ideal Reactor "%s"',obj.Block)) ;
            end
            obj.CacheKey = obj.parameterCacheKey() ;
            obj.HasCache = false ;
            obj.CalculationCount = 0 ;
        end

        function varargout = stepImpl(obj,in,varargin)
            nirp.stream.validate(in,obj.RS.nComponents) ;
            cacheInput = [{obj.CacheKey,in} varargin] ;
            if obj.HasCache && isequaln(cacheInput,obj.LastInput)
                out = obj.LastOutput ; info = obj.LastInfo ;
            else
                evaluated = [obj.ModelName '/' obj.Block] ;
                [unitOutputs,info] = nirp.blocks.internal.evaluate( ...
                    evaluated,{in},'Signals',varargin, ...
                    'ReactionSystem',obj.RS) ;
                out = unitOutputs{1} ;
                obj.LastInput = cacheInput ; obj.LastOutput = out ;
                obj.LastInfo = info ; obj.HasCache = true ;
                obj.CalculationCount = obj.CalculationCount+1 ;
                nirp.blocks.internal.diagnostic(obj.ModelName,obj.Block, ...
                    obj.CalculationCount,out,info) ;
            end
            varargout{1} = out ;
            if obj.ShowHeatPort, varargout{2} = info.heatDuty ; end
        end

        function n = getNumInputsImpl(obj)
            n = 1+double(strcmp(obj.RTDOrigin,'Model') && ...
                strcmp(obj.SizeSource,'Input port')) ;
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
            if strcmp(obj.RTDOrigin,'Model') && strcmp(obj.SizeSource,'Input port')
                if strcmp(obj.SizeBasis,'Volume'), varargout{2} = 'V (m^3)' ;
                else, varargout{2} = 'Tau (s)' ; end
            end
        end
        function varargout = getOutputNamesImpl(obj)
            varargout{1} = 'Product' ;
            if obj.ShowHeatPort, varargout{2} = 'Heat (W)' ; end
        end
        function icon = getIconImpl(obj)
            icon = obj.iconText() ;
        end
    end

    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Non-ideal Reactor', ...
                'PropertyList',{'RTDOrigin','Model','SizeBasis','SizeSource', ...
                'V','VUnit','Tau','TauUnit','N','Pe','Boundary', ...
                'DataTime','DataE','DataTimeUnit','SessionFile', ...
                'Micromixing','TemperatureMode','SpecifiedT', ...
                'SpecifiedTUnit','Reactions','ShowHeatPort','Specifications'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end

    methods (Access = private)
        function missing = missingSpecifications(obj)
            missing = strings(0,1) ;
            if strcmp(obj.RTDOrigin,'Select...'), missing(end+1) = "RTDOrigin" ; end
            if strcmp(obj.RTDOrigin,'Model')
                if strcmp(obj.Model,'Select...'), missing(end+1) = "Model" ; end
                if strcmp(obj.SizeSource,'Dialog')
                    if strcmp(obj.SizeBasis,'Volume') && ~isfinite(obj.V)
                        missing(end+1) = "V" ;
                    elseif strcmp(obj.SizeBasis,'Residence time') && ~isfinite(obj.Tau)
                        missing(end+1) = "Tau" ;
                    end
                end
                if strcmp(obj.Model,'Tanks in series') && ~isfinite(obj.N)
                    missing(end+1) = "N" ;
                elseif strcmp(obj.Model,'Dispersion') && ~isfinite(obj.Pe)
                    missing(end+1) = "Pe" ;
                end
            elseif strcmp(obj.RTDOrigin,'Data')
                if isempty(obj.DataTime), missing(end+1) = "DataTime" ; end
                if isempty(obj.DataE), missing(end+1) = "DataE" ; end
            elseif strcmp(obj.RTDOrigin,'Session') && ...
                    isempty(strtrim(char(string(obj.SessionFile))))
                missing(end+1) = "SessionFile" ;
            end
            if strcmp(obj.Micromixing,'Select...')
                missing(end+1) = "Micromixing" ;
            end
            if strcmp(obj.TemperatureMode,'Specified') && ~isfinite(obj.SpecifiedT)
                missing(end+1) = "SpecifiedT" ;
            end
        end

        function value = parameterCacheKey(obj)
            names = {'RTDOrigin','Model','SizeBasis','SizeSource','V','VUnit', ...
                'Tau','TauUnit','N','Pe','Boundary','DataTime','DataE', ...
                'DataTimeUnit','SessionFile','Micromixing','TemperatureMode', ...
                'SpecifiedT','SpecifiedTUnit','Reactions','ShowHeatPort', ...
                'Specifications'} ;
            value = cell(size(names)) ;
            for i = 1:numel(names), value{i} = obj.(names{i}) ; end
        end

        function text = rtdIconText(obj)
            switch obj.RTDOrigin
                case 'Model'
                    text = obj.Model ;
                    if strcmp(obj.Model,'Tanks in series') && isfinite(obj.N)
                        text = sprintf('Tanks N=%g',obj.N) ;
                    elseif strcmp(obj.Model,'Dispersion') && isfinite(obj.Pe)
                        text = sprintf('Dispersion Pe=%g',obj.Pe) ;
                    end
                case 'Data', text = 'Data RTD' ;
                case 'Session', text = 'Session RTD' ;
                otherwise, text = 'RTD ?' ;
            end
        end

        function text = micromixingCode(obj)
            if strcmp(obj.Micromixing,'Segregation'), text = 'SEG' ;
            elseif strcmp(obj.Micromixing,'Maximum mixedness'), text = 'MM' ;
            else, text = '?' ; end
        end
    end
end
