classdef Recycle < matlab.System
    % Recycle breaks a stream loop using direct or bounded Wegstein updates.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================
    properties (Nontunable)
        Method = 'Direct'
        Tolerance = 1e-8
        QMin = -20
        QMax = 0
        AccelerationEvery = 1
        InitialGuess = 'Empty stream'
        InitialT = 300
        InitialTUnit = 'K'
        InitialP = 101325
        InitialPUnit = 'Pa'
        InitialFeedName = 'F1'
    end
    properties (Constant,Hidden)
        MethodSet = matlab.system.StringSet({'Direct','Wegstein'})
        InitialGuessSet = matlab.system.StringSet({'Empty stream','Feed'})
        InitialTUnitSet = matlab.system.StringSet({'K',[char(176) 'C']})
        InitialPUnitSet = matlab.system.StringSet(UnitConverterHelper.getUnits('Pressure'))
    end
    properties (Access=private)
        Estimate
        PreviousEstimate
        PreviousRaw
        HavePrevious = false
        Iteration = 0
        Consecutive = 0
        Converged = false
        Model = ''
        Key = ''
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,pkg,rs] = nirp.blocks.internal.modelPackage() ;
            obj.Key = gcb ;
            if ~isscalar(obj.Tolerance) || ~isfinite(obj.Tolerance) || obj.Tolerance <= 0
                error('nirp:blocks:invalidTolerance','Tolerance must be positive.') ;
            end
            if obj.QMin > obj.QMax || obj.QMax > 0
                error('nirp:blocks:invalidWegsteinBounds','Require QMin <= QMax <= 0.') ;
            end
            if obj.AccelerationEvery < 1 || obj.AccelerationEvery ~= fix(obj.AccelerationEvery)
                error('nirp:blocks:invalidAcceleration','AccelerationEvery must be a positive integer.') ;
            end
            if strcmp(obj.InitialGuess,'Feed')
                obj.Estimate = nirp.pkg.feedStream(pkg,obj.InitialFeedName) ;
            else
                temperature = UnitConverterHelper.convertToSI( ...
                    'Temperature',obj.InitialT,char(obj.InitialTUnit)) ;
                pressure = UnitConverterHelper.convertToSI( ...
                    'Pressure',obj.InitialP,char(obj.InitialPUnit)) ;
                obj.Estimate = nirp.stream.empty(rs.nComponents,temperature,pressure,0) ;
            end
            obj.PreviousEstimate = obj.Estimate ;
            obj.PreviousRaw = obj.Estimate ;
            obj.HavePrevious = false ; obj.Iteration = 0 ;
            obj.Consecutive = 0 ; obj.Converged = false ;
            obj.publish() ;
        end
        function estimate = outputImpl(obj,~)
            estimate = obj.Estimate ;
        end
        function updateImpl(obj,raw)
            nirp.stream.validate(raw,numel(obj.Estimate.F)) ;
            next = raw ;
            shouldAccelerate = strcmp(obj.Method,'Wegstein') && ...
                obj.HavePrevious && mod(obj.Iteration,obj.AccelerationEvery) == 0 ;
            if shouldAccelerate
                current = obj.vector(obj.Estimate) ;
                previous = obj.vector(obj.PreviousEstimate) ;
                mapped = obj.vector(raw) ;
                previousMapped = obj.vector(obj.PreviousRaw) ;
                slope = (mapped-previousMapped)./(current-previous) ;
                q = slope./(slope-1) ;
                q(~isfinite(q)) = 0 ;
                q = min(obj.QMax,max(obj.QMin,q)) ;
                accelerated = q.*current+(1-q).*mapped ;
                n = numel(raw.F) ;
                next.F = accelerated(1:n) ; next.Q = accelerated(n+1) ;
                next.T = accelerated(n+2) ; next.P = accelerated(n+3) ;
                if any(next.F < 0) || next.Q < 0 || next.T <= 0 || next.P <= 0
                    next = raw ;
                end
            end
            if obj.relativeError(next,obj.Estimate) <= obj.Tolerance
                obj.Consecutive = obj.Consecutive+1 ;
            else
                obj.Consecutive = 0 ;
            end
            obj.PreviousEstimate = obj.Estimate ; obj.PreviousRaw = raw ;
            obj.Estimate = next ; obj.HavePrevious = true ;
            obj.Iteration = obj.Iteration+1 ;
            obj.Converged = obj.Consecutive >= 2 ;
            obj.publish() ;
        end
        function flag = isInputDirectFeedthroughImpl(~,~), flag = false ; end
        function type = getOutputDataTypeImpl(~), type = 'NirpStream' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getInputNamesImpl(~), name = 'Calculated' ; end
        function name = getOutputNamesImpl(~), name = 'Estimate' ; end
        function icon = getIconImpl(~), icon = 'Recycle' ; end
    end
    methods (Access=private)
        function publish(obj)
            value = struct('converged',obj.Converged,'status',double(obj.Converged), ...
                'kind','Recycle','iteration',obj.Iteration) ;
            nirp.flowsheet.registry('set',obj.Model,obj.Key,value) ;
        end
    end
    methods (Static,Access=private)
        function value = vector(stream)
            value = [stream.F(:);stream.Q;stream.T;stream.P] ;
        end
        function value = relativeError(first,second)
            a = nirp.blocks.Recycle.vector(first) ;
            b = nirp.blocks.Recycle.vector(second) ;
            scale = max([abs(a),abs(b),ones(size(a))*1e-12],[],2) ;
            value = max(abs(a-b)./scale) ;
        end
    end
    methods (Static,Access=protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Recycle', ...
                'PropertyList',{'Method','Tolerance','QMin','QMax', ...
                'AccelerationEvery','InitialGuess','InitialT','InitialTUnit', ...
                'InitialP','InitialPUnit','InitialFeedName'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
