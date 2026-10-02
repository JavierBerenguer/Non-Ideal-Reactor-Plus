classdef Stream < matlab.System
    % Stream represents a named feed, intermediate, or product stream.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Nontunable)
        % Stream role in the flowsheet.
        Role = 'Intermediate'
        % Source of feed temperature (Feed role only).
        TSource = 'Dialog'
        % Feed temperature when explicitly overridden (Feed role only).
        T = NaN
        % Unit of the feed-temperature override.
        TUnit = 'K'
        % Optional package feed used as the conversion reference.
        ReferenceFeed = ''
        % Optional key component used to calculate conversion.
        KeyComponent = ''
        % Preferred presentation units.
        FlowUnit = 'mol/s'
        TemperatureUnit = 'K'
        PressureUnit = 'Pa'
        ConcentrationUnit = 'mol/m^3'
    end

    properties (Constant, Hidden)
        RoleSet = matlab.system.StringSet({'Feed','Intermediate','Product'})
        TSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        TUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        FlowUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('MolarFlow'))
        TemperatureUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Temperature'))
        PressureUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Pressure'))
        ConcentrationUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Concentration'))
    end

    properties (Access = private)
        Package
        ReactionSystem
        BlockName
        FeedStream
        Reference
        KeyIndex = []
    end

    methods (Access = protected)
        function setupImpl(obj)
            [~,obj.Package,obj.ReactionSystem] = nirp.blocks.internal.modelPackage() ;
            obj.BlockName = get_param(gcb,'Name') ;
            if strcmp(obj.Role,'Feed')
                try
                    obj.FeedStream = nirp.pkg.feedStream(obj.Package,obj.BlockName) ;
                catch exception
                    if contains(exception.message,'Unknown feed')
                        error('nirp:blocks:unknownFeed', ...
                            ['Feed stream "%s" is not defined in the package. ' ...
                            'Open this block and save the feed data first.'],obj.BlockName) ;
                    end
                    rethrow(exception) ;
                end
            end
            referenceName = strtrim(char(string(obj.ReferenceFeed))) ;
            if ~isempty(referenceName)
                obj.Reference = nirp.pkg.feedStream(obj.Package,referenceName) ;
                keyName = strtrim(char(string(obj.KeyComponent))) ;
                if isempty(keyName)
                    error('nirp:blocks:missingKeyComponent', ...
                        'KeyComponent is required when ReferenceFeed is set.') ;
                end
                names = nirp.pkg.componentNames(obj.Package) ;
                obj.KeyIndex = find(names == string(keyName),1) ;
                if isempty(obj.KeyIndex)
                    error('nirp:blocks:unknownComponent', ...
                        'Unknown key component "%s". Valid names: %s.', ...
                        keyName,strjoin(cellstr(names),', ')) ;
                end
            end
        end

        function varargout = stepImpl(obj,varargin)
            if strcmp(obj.Role,'Feed')
                stream = obj.FeedStream ;
                if strcmp(obj.TSource,'Input port')
                    temperature = varargin{1} ;
                elseif isnan(obj.T)
                    temperature = stream.T ;
                else
                    temperature = UnitConverterHelper.convertToSI( ...
                        'Temperature',obj.T,char(obj.TUnit)) ;
                end
                if ~isnumeric(temperature) || ~isscalar(temperature) || ...
                        ~isfinite(temperature) || temperature <= 0
                    error('nirp:blocks:invalidParameterPort', ...
                        'Feed-stream T must be positive K.') ;
                end
                stream.T = temperature ;
                stream = nirp.stream.refresh(stream) ;
            else
                stream = varargin{1} ;
                nirp.stream.validate(stream,obj.ReactionSystem.nComponents) ;
            end
            obj.publish(stream) ;
            if ~strcmp(obj.Role,'Product')
                varargout{1} = stream ;
            end
        end

        function publish(obj,stream)
            names = nirp.pkg.componentNames(obj.Package)' ;
            flow = UnitConverterHelper.convertFromSI( ...
                'MolarFlow',stream.F,char(obj.FlowUnit)) ;
            if stream.Q > 0
                concentration = nirp.stream.concentration(stream) ;
            else
                concentration = nan(size(stream.F)) ;
            end
            concentration = UnitConverterHelper.convertFromSI( ...
                'Concentration',concentration,char(obj.ConcentrationUnit)) ;
            item = struct() ;
            item.name = obj.BlockName ;
            item.role = obj.Role ;
            item.streamSI = stream ;
            item.streamTable = table(names,flow,concentration, ...
                'VariableNames',{'Component','F','C'}) ;
            item.units = struct('F',char(obj.FlowUnit),'C',char(obj.ConcentrationUnit), ...
                'T',char(obj.TemperatureUnit),'P',char(obj.PressureUnit)) ;
            item.T = UnitConverterHelper.convertFromSI( ...
                'Temperature',stream.T,char(obj.TemperatureUnit)) ;
            item.P = UnitConverterHelper.convertFromSI( ...
                'Pressure',stream.P,char(obj.PressureUnit)) ;
            phases = {'Liquid','Gas'} ;
            item.phase = phases{stream.phase+1} ;
            item.status = stream.status ;
            item.conversion = [] ;
            if ~isempty(obj.KeyIndex)
                initial = obj.Reference.F(obj.KeyIndex) ;
                if initial <= 0
                    error('nirp:blocks:invalidReference', ...
                        'The reference feed key-component flow must be positive.') ;
                end
                item.conversion = (initial-stream.F(obj.KeyIndex))/initial ;
            end
            if evalin('base','exist(''nirpResults'',''var'')')
                results = evalin('base','nirpResults') ;
            else
                results = struct() ;
            end
            if ~isstruct(results), results = struct() ; end
            if ~isfield(results,'Streams') || ~isstruct(results.Streams)
                results.Streams = struct() ;
            end
            field = matlab.lang.makeValidName(obj.BlockName) ;
            results.Streams.(field) = item ;
            assignin('base','nirpResults',results) ;
        end

        function n = getNumInputsImpl(obj)
            if strcmp(obj.Role,'Feed')
                n = double(strcmp(obj.TSource,'Input port')) ;
            else
                n = 1 ;
            end
        end
        function n = getNumOutputsImpl(obj), n = double(~strcmp(obj.Role,'Product')) ; end
        function type = getOutputDataTypeImpl(~), type = 'NirpStream' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getOutputNamesImpl(~), name = '' ; end % short icons, no port labels (Claude, T-111 review)
        function name = getInputNamesImpl(obj)
            if strcmp(obj.Role,'Feed'), name = 'T (K)' ; else, name = '' ; end
        end
        function icon = getIconImpl(obj)
            labels = struct('Feed','Feed','Intermediate','Stream','Product','Product') ;
            icon = labels.(char(obj.Role)) ;
        end
        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj,'Type','Discrete','SampleTime',1) ;
        end
    end

    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Stream', ...
                'PropertyList',{'Role','TSource','T','TUnit','ReferenceFeed', ...
                'KeyComponent','FlowUnit','TemperatureUnit','PressureUnit', ...
                'ConcentrationUnit'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
