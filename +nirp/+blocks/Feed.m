classdef Feed < matlab.System
    % Feed emits a named feed from the model package as an SI stream.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================

    properties (Nontunable)
        % Name of a feed defined in nirpPackage.
        FeedName = 'F1'
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

        function out = stepImpl(obj), out = obj.Stream ; end
        function n = getNumInputsImpl(~), n = 0 ; end
        function type = getOutputDataTypeImpl(~), type = 'NirpStream' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getOutputNamesImpl(~), name = 'Stream' ; end
        function icon = getIconImpl(~), icon = 'Feed' ; end
        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj,'Type','Discrete','SampleTime',1) ;
        end
    end

    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Feed', ...
                'PropertyList',{'FeedName'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
