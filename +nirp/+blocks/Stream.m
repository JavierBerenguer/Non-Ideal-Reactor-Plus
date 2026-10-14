classdef Stream < matlab.System
    % Stream represents a named stream whose role may follow connectivity.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 9, 2026
    % =========================================================================

    properties (Nontunable)
        % Stream role in the flowsheet. 'Auto' is kept only so that models
        % saved before T-145 still load; the dialog replaces it on opening.
        Role = 'Intermediate'
        % Source of feed temperature (Feed role only).
        TSource = 'Dialog'
        % Source of feed volumetric flow (Feed role only).
        QSource = 'Dialog'
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

    properties (Nontunable)
        % JSON containing only user specifications; empty means legacy.
        Specifications = ''
    end

    properties (Constant, Hidden)
        RoleSet = matlab.system.StringSet({'Select...','Auto','Feed','Intermediate','Product'})
        TSourceSet = matlab.system.StringSet({'Dialog','Input port'})
        QSourceSet = matlab.system.StringSet({'Dialog','Input port'})
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
        RunRole = "Intermediate"
        FeedModel
        Specs
    end

    methods (Access = protected)
        function setupImpl(obj)
            if strcmp(obj.Role,'Select...')
                nirp.blocks.internal.requireSpecifications('Stream',get_param(gcb,'Name'),'Role');
            end
            [~,obj.Package,obj.ReactionSystem] = nirp.blocks.internal.modelPackage() ;
            obj.BlockName = get_param(gcb,'Name') ;
            obj.RunRole = obj.runtimeRole() ;
            if strcmp(obj.Role,'Auto')
                connectedRole = nirp.flowsheet.streamRole(gcb) ;
                if connectedRole ~= "Unconnected", obj.RunRole = connectedRole ; end
            end
            role = obj.RunRole ;
            if role == "Feed"
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
                obj.Specs=nirp.dof.readSpecs(obj.Specifications) ;
                if ~isempty(fieldnames(obj.Specs))
                    context=struct('nComponents',obj.ReactionSystem.nComponents, ...
                        'phase',obj.FeedStream.phase,'Mw',obj.ReactionSystem.componentMw) ;
                    obj.FeedModel=nirp.dof.catalog.feed(context) ;
                    result=solveFeed(obj.FeedModel,obj.Specs,obj.TSource,obj.QSource,NaN,NaN) ;
                    if ~strcmp(result.status,'complete'),throwFeedResult(obj.BlockName,result);end
                end
            else
                obj.Specs=nirp.dof.readSpecs(obj.Specifications) ;
                if ~isempty(fieldnames(obj.Specs))
                    % Validate that the directly connected producer owns a
                    % simple DOF relation capable of meeting these values.
                    nirp.dof.streamSpecificationTarget(gcb,obj.Specs) ;
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
            role = obj.RunRole ;
            if role == "Feed"
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
                if strcmp(obj.QSource,'Input port')
                    index = 1+strcmp(obj.TSource,'Input port') ;
                    flow = varargin{index} ;
                    if ~isnumeric(flow) || ~isscalar(flow) || ...
                            ~isfinite(flow) || flow <= 0
                        error('nirp:blocks:invalidParameterPort', ...
                            'Feed-stream Q input must be positive m^3/s.') ;
                    end
                    if stream.phase == 0
                        concentration = nirp.stream.concentration(obj.FeedStream) ;
                        stream.Q = flow ;
                        stream.F = concentration*flow ;
                    else
                        stream.F = stream.F*(flow/obj.FeedStream.Q) ;
                    end
                    stream = nirp.stream.refresh(stream) ;
                end
                if ~isempty(fieldnames(obj.Specs))
                    externalT=NaN;externalQ=NaN ;
                    if strcmp(obj.TSource,'Input port'),externalT=temperature;end
                    if strcmp(obj.QSource,'Input port'),externalQ=flow;end
                    result=solveFeed(obj.FeedModel,obj.Specs,obj.TSource,obj.QSource,externalT,externalQ) ;
                    if ~strcmp(result.status,'complete'),throwFeedResult(obj.BlockName,result);end
                    flows=zeros(obj.ReactionSystem.nComponents,1) ;
                    for i=1:numel(flows),flows(i)=result.values.(['F' num2str(i)]);end
                    stream=nirp.stream.create(flows,result.values.T,result.values.P, ...
                        obj.FeedStream.phase,result.values.Q) ;
                end
            else
                stream = varargin{1} ;
                nirp.stream.validate(stream,obj.ReactionSystem.nComponents) ;
            end
            obj.publish(stream) ;
            if role ~= "Product" || strcmp(obj.Role,'Auto')
                varargout{1} = stream ;
            end
        end

        function publish(obj,stream)
            if evalin('base','exist(''nirpResults'',''var'')')
                results = evalin('base','nirpResults') ;
            else
                results = struct() ;
            end
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
            item.role = char(obj.RunRole) ;
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
                reference = obj.Reference ;
                referenceField = matlab.lang.makeValidName( ...
                    strtrim(char(string(obj.ReferenceFeed)))) ;
                if isstruct(results) && isfield(results,'Streams') && ...
                        isstruct(results.Streams) && ...
                        isfield(results.Streams,referenceField)
                    reference = results.Streams.(referenceField).streamSI ;
                end
                initial = reference.F(obj.KeyIndex) ;
                if initial <= 0
                    error('nirp:blocks:invalidReference', ...
                        'The reference feed key-component flow must be positive.') ;
                end
                item.conversion = (initial-stream.F(obj.KeyIndex))/initial ;
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
            if strcmp(obj.Role,'Auto')
                % Auto blocks keep one material input and output so users can
                % reconnect them before the next configure/update operation.
                n = 1 ;
                return
            end
            if strcmp(obj.Role,'Feed')
                n = double(strcmp(obj.TSource,'Input port'))+ ...
                    double(strcmp(obj.QSource,'Input port')) ;
            else
                n = 1 ;
            end
        end
        function n = getNumOutputsImpl(obj)
            n = double(strcmp(obj.Role,'Auto') || ~strcmp(obj.Role,'Product')) ;
        end
        function type = getOutputDataTypeImpl(~), type = 'NirpStream' ; end
        function size = getOutputSizeImpl(~), size = [1 1] ; end
        function flag = isOutputFixedSizeImpl(~), flag = true ; end
        function flag = isOutputComplexImpl(~), flag = false ; end
        function name = getOutputNamesImpl(~), name = '' ; end % short icons, no port labels (Claude, T-111 review)
        function varargout = getInputNamesImpl(obj)
            if strcmp(obj.Role,'Auto'), varargout{1} = '' ; return, end
            if ~strcmp(obj.Role,'Feed'), varargout{1} = '' ; return, end
            index = 0 ;
            if strcmp(obj.TSource,'Input port')
                index = index+1 ; varargout{index} = 'T (K)' ;
            end
            if strcmp(obj.QSource,'Input port')
                index = index+1 ; varargout{index} = 'Q (m^3/s)' ;
            end
        end
        function icon = getIconImpl(obj)
            labels = struct('Feed','Feed','Intermediate','Stream','Product','Product') ;
            icon = labels.(char(obj.runtimeRole())) ;
        end
        function sts = getSampleTimeImpl(obj)
            sts = createSampleTime(obj,'Type','Discrete','SampleTime',1) ;
        end
    end

    methods (Access = private)
        function role = runtimeRole(obj)
            role = string(obj.Role) ;
            if role == "Select...",role="Intermediate";return,end
            if role ~= "Auto", return, end
            role = "Intermediate" ;
            try
                connectedRole = nirp.flowsheet.streamRole(gcb) ;
                if connectedRole ~= "Unconnected", role = connectedRole ; end
            catch
            end
        end
    end

    methods (Static, Access = protected)
        function groups = getPropertyGroupsImpl()
            groups = matlab.system.display.Section('Title','Stream', ...
                'PropertyList',{'Role','TSource','T','TUnit','QSource','ReferenceFeed', ...
                    'KeyComponent','FlowUnit','TemperatureUnit','PressureUnit', ...
                    'ConcentrationUnit','Specifications'}) ;
        end
        function mode = getSimulateUsingImpl(), mode = 'Interpreted execution' ; end
        function flag = showSimulateUsingImpl(), flag = false ; end
    end
end

function result=solveFeed(model,specs,tSource,qSource,externalT,externalQ)
    values=struct();origins=struct();names=fieldnames(specs);allowed={model.variables.name} ;
    for i=1:numel(names)
        if ~ismember(names{i},allowed),error('nirp:blocks:invalidSpecifications','Unknown Stream specification "%s".',names{i});end
        values.(names{i})=specs.(names{i}).si;origins.(names{i})='specified';
    end
    if strcmp(tSource,'Input port'),values.T=externalT;origins.T='external';end
    if strcmp(qSource,'Input port'),values.Q=externalQ;origins.Q='external';end
    result=nirp.dof.solve(model,values,origins) ;
end
function throwFeedResult(block,result)
    if strcmp(result.status,'missing')
        error('nirp:blocks:missingSpecifications','Stream "%s": %d specifications missing: %s.',block,result.missingCount,strjoin(result.missing,', '));
    end
    error('nirp:blocks:conflictingSpecifications','Stream "%s": conflict in %s: %s',block,strjoin(result.conflicts,', '),strjoin(result.messages,' '));
end
