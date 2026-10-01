classdef Feed < matlab.System
    % Feed emits a named feed from the model package as an SI stream.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Nontunable)
        % Name of a feed defined in nirpPackage.
        FeedName = 'F1'
        % Source of feed temperature.
        TSource = 'Dialog'
        % Feed temperature.
        T = NaN
        % Feed-temperature unit.
        TUnit = 'K'
    end
    properties (Constant,Hidden)
        TSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        TUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
    end

    properties (Access = private)
        Stream
    end

    methods (Access = protected)
        function setupImpl(obj)
            [~,pkg] = nirp.blocks.internal.modelPackage() ;
            try
                obj.Stream = nirp.pkg.feedStream(pkg,obj.FeedName) ;
            catch exception
                if contains(exception.message,'Unknown feed')
                    names = nirp.pkg.feedNames(pkg) ;
                    error('nirp:blocks:unknownFeed', ...
                        'Unknown feed "%s". Valid names: %s.', ...
                        char(string(obj.FeedName)),strjoin(cellstr(names),', ')) ;
                end
                rethrow(exception) ;
            end
        end

        function out = stepImpl(obj,varargin)
            out = obj.Stream ;
            if strcmp(obj.TSource,'Input port')
                temperature = varargin{1} ;
            else
                if isnan(obj.T), temperature = out.T ;
                else
                    temperature = UnitConverterHelper.convertToSI( ...
                        'Temperature',obj.T,char(obj.TUnit)) ;
                end
            end
            if ~isnumeric(temperature) || ~isscalar(temperature) || ...
                    ~isfinite(temperature) || temperature <= 0
                error('nirp:blocks:invalidParameterPort','Feed T must be positive K.') ;
            end
            out.T = temperature ; out = nirp.stream.refresh(out) ;
        end
        function n = getNumInputsImpl(obj), n = double(strcmp(obj.TSource,'Input port')) ; end
        function type = getOutputDataTypeImpl(~), type = 'NirpStream' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getOutputNamesImpl(~), name = 'Stream' ; end
        function name = getInputNamesImpl(~), name = 'T (K)' ; end
        function icon = getIconImpl(~), icon = 'Feed' ; end
        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj,'Type','Discrete','SampleTime',1) ;
        end
    end

    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Feed', ...
                'PropertyList',{'FeedName','TSource','T','TUnit'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
