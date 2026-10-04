classdef Adjust < matlab.System
    % Adjust drives a scalar SI parameter to a measured stream target.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 3, 2026
    % =========================================================================
    properties (Nontunable)
        TargetVariable = 'Conversion'
        KeyComponent = 'A'
        ReferenceFeed = 'F1'
        TargetValue = 0.8
        TargetUnit = 'as entered'
        InitialValue = 0.1
        MinValue = 0
        MaxValue = 1
        ParameterUnit = 'm^3'
        Damping = 1
        Tolerance = 1e-8
        Strategy = 'Simultaneous'
    end
    properties (Constant,Hidden)
        TargetVariableSet = matlab.system.StringSet({'Conversion', ...
            'Component molar flow','Temperature','Component concentration'})
        TargetUnitSet = matlab.system.StringSet([{'as entered'}, ...
            UnitConverterHelper.getUnits('MolarFlow'), ...
            UnitConverterHelper.getUnits('Temperature'), ...
            UnitConverterHelper.getUnits('Concentration')])
        ParameterUnitSet = matlab.system.StringSet([ ...
            UnitConverterHelper.getUnits('Volume'), ...
            UnitConverterHelper.getUnits('Temperature'), ...
            UnitConverterHelper.getUnits('VolumetricFlow'), ...
            UnitConverterHelper.getUnits('Area')])
        StrategySet = matlab.system.StringSet({'Simultaneous','Nested'})
    end
    properties (Access=private)
        Current
        Previous
        PreviousError = NaN
        HavePrevious = false
        Converged = false
        Consecutive = 0
        Iteration = 0
        Minimum
        Maximum
        Target
        TargetScale
        KeyIndex = []
        Reference
        Model = ''
        Key = ''
        Block = ''
        LastMeasured = NaN
    end
    methods (Access=protected)
        function setupImpl(obj)
            [obj.Model,pkg,~] = nirp.blocks.internal.modelPackage() ; obj.Key = gcb ;
            obj.Block = get_param(gcb,'Name') ;
            category = nirp.blocks.internal.unitCategory(obj.ParameterUnit, ...
                {'Volume','Temperature','VolumetricFlow','Area'}) ;
            obj.Current = UnitConverterHelper.convertToSI(category,obj.InitialValue,char(obj.ParameterUnit)) ;
            obj.Minimum = UnitConverterHelper.convertToSI(category,obj.MinValue,char(obj.ParameterUnit)) ;
            obj.Maximum = UnitConverterHelper.convertToSI(category,obj.MaxValue,char(obj.ParameterUnit)) ;
            if obj.Minimum >= obj.Maximum || obj.Current < obj.Minimum || obj.Current > obj.Maximum
                error('nirp:blocks:invalidAdjustBounds', ...
                    'Require MinValue <= InitialValue <= MaxValue in the selected unit.') ;
            end
            if obj.Damping <= 0 || obj.Damping > 1 || obj.Tolerance <= 0
                error('nirp:blocks:invalidAdjustSetting','Damping must be in (0,1] and Tolerance positive.') ;
            end
            names = nirp.pkg.componentNames(pkg) ;
            if any(strcmp(obj.TargetVariable,{'Conversion','Component molar flow','Component concentration'}))
                obj.KeyIndex = find(names == string(obj.KeyComponent),1) ;
                if isempty(obj.KeyIndex), error('nirp:blocks:unknownComponent','Unknown key component "%s".',obj.KeyComponent); end
            end
            switch obj.TargetVariable
                case 'Conversion'
                    obj.Reference = nirp.pkg.feedStream(pkg,obj.ReferenceFeed) ;
                    if ~strcmp(obj.TargetUnit,'as entered') || ...
                            obj.TargetValue < 0 || obj.TargetValue > 1 || ...
                            obj.Reference.F(obj.KeyIndex) <= 0
                        error('nirp:blocks:invalidTarget', ...
                            'Conversion requires an as-entered target in [0,1] and a positive reference flow.') ;
                    end
                    obj.Target = obj.TargetValue ; obj.TargetScale = 1 ;
                case 'Component molar flow'
                    obj.Target = obj.convertTarget('MolarFlow') ; obj.TargetScale = max(abs(obj.Target),1e-12) ;
                case 'Temperature'
                    obj.Target = obj.convertTarget('Temperature') ; obj.TargetScale = max(abs(obj.Target),1) ;
                otherwise
                    obj.Target = obj.convertTarget('Concentration') ; obj.TargetScale = max(abs(obj.Target),1e-12) ;
            end
            obj.Previous = obj.Current ; obj.PreviousError = NaN ; obj.HavePrevious = false ;
            obj.Converged = false ; obj.Consecutive = 0 ; obj.Iteration = 0 ;
            obj.LastMeasured = NaN ; obj.publish() ;
        end
        function value = outputImpl(obj,~), value = obj.Current ; end
        function updateImpl(obj,measured)
            nirp.stream.validate(measured) ;
            if strcmp(obj.Strategy,'Nested')
                entries = nirp.flowsheet.registry('list',obj.Model) ;
                recycle = entries(strcmp({entries.kind},'Recycle')) ;
                if ~isempty(recycle) && ~all([recycle.converged]), return, end
            end
            obj.LastMeasured = obj.measure(measured) ;
            errorValue = obj.LastMeasured-obj.Target ;
            if abs(errorValue)/obj.TargetScale <= obj.Tolerance
                obj.Consecutive = obj.Consecutive+1 ;
            else
                obj.Consecutive = 0 ;
            end
            obj.Converged = obj.Consecutive >= 2 ;
            if ~obj.Converged
                if ~obj.HavePrevious
                    span = obj.Maximum-obj.Minimum ;
                    direction = 1 ;
                    if obj.Current+0.05*span > obj.Maximum, direction = -1 ; end
                    candidate = obj.Current+direction*0.05*span ;
                    obj.HavePrevious = true ;
                else
                    denominator = errorValue-obj.PreviousError ;
                    if abs(denominator) <= eps(max([abs(errorValue),abs(obj.PreviousError),1]))
                        candidate = (obj.Minimum+obj.Maximum)/2 ;
                    else
                        candidate = obj.Current-errorValue*(obj.Current-obj.Previous)/denominator ;
                    end
                    candidate = obj.Current+obj.Damping*(candidate-obj.Current) ;
                end
                candidate = min(obj.Maximum,max(obj.Minimum,candidate)) ;
                obj.Previous = obj.Current ; obj.PreviousError = errorValue ;
                obj.Current = candidate ;
            end
            obj.Iteration = obj.Iteration+1 ; obj.publish() ;
        end
        function flag = isInputDirectFeedthroughImpl(~,~), flag = false ; end
        function type = getOutputDataTypeImpl(~), type = 'double' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getInputNamesImpl(~), name = 'Measured stream' ; end
        function name = getOutputNamesImpl(~), name = 'Parameter (SI)' ; end
        function icon = getIconImpl(~), icon = 'Adjust' ; end
    end
    methods (Access=private)
        function target = convertTarget(obj,category)
            supplied = nirp.blocks.internal.unitCategory(obj.TargetUnit, ...
                {'RawScalar','MolarFlow','Temperature','Concentration'}) ;
            if ~strcmp(supplied,category)
                error('nirp:blocks:invalidUnit','TargetUnit is incompatible with TargetVariable.') ;
            end
            target = UnitConverterHelper.convertToSI(category,obj.TargetValue,char(obj.TargetUnit)) ;
        end
        function value = measure(obj,stream)
            switch obj.TargetVariable
                case 'Conversion'
                    base = obj.Reference.F(obj.KeyIndex) ;
                    value = (base-stream.F(obj.KeyIndex))/base ;
                case 'Component molar flow', value = stream.F(obj.KeyIndex) ;
                case 'Temperature', value = stream.T ;
                otherwise, value = nirp.stream.concentration(stream) ; value = value(obj.KeyIndex) ;
            end
        end
        function publish(obj)
            value = struct('converged',obj.Converged,'status',double(obj.Converged), ...
                'kind','Adjust','iteration',obj.Iteration,'value',obj.Current, ...
                'targetVariable',char(obj.TargetVariable),'target',obj.Target, ...
                'measured',obj.LastMeasured,'parameterUnit',char(obj.ParameterUnit), ...
                'targetUnit',char(obj.TargetUnit)) ;
            nirp.flowsheet.registry('set',obj.Model,obj.Key,value) ;
            info = struct('status',double(obj.Converged),'message','', ...
                'value',obj.Current,'targetVariable',char(obj.TargetVariable), ...
                'target',obj.Target,'measured',obj.LastMeasured, ...
                'parameterUnit',char(obj.ParameterUnit), ...
                'targetUnit',char(obj.TargetUnit),'converged',obj.Converged, ...
                'iteration',obj.Iteration) ;
            nirp.blocks.internal.diagnostic( ...
                obj.Model,obj.Block,obj.Iteration,[],info) ;
        end
    end
    methods (Static,Access=protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Adjust', ...
                'PropertyList',{'TargetVariable','KeyComponent','ReferenceFeed', ...
                'TargetValue','TargetUnit','InitialValue','MinValue','MaxValue', ...
                'ParameterUnit','Damping','Tolerance','Strategy'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end
