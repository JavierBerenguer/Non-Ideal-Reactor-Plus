function [outputs,info,details] = evaluate(blockPath,inputs,varargin)
%EVALUATE Evaluate one flowsheet block with its saved DOF specifications.
%   INPUTS is a cell array of SI material streams. SIGNALS contains the
%   non-material input values, in physical port order. The function reads
%   the block parameters, closes its DOF catalogue and calls the same
%   nirp.units function used during simulation. PREPAREDPARAMETERS lets a
%   System block retain its setup-time conversions while sharing the final
%   unit invocation with preview evaluation.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================

    parser=inputParser;
    addParameter(parser,'Signals',{});
    addParameter(parser,'ReactionSystem',[]);
    addParameter(parser,'Package',[]);
    addParameter(parser,'PreparedParameters',[]);
    parse(parser,varargin{:});
    blockPath=getfullname(blockPath);
    if ~iscell(inputs),inputs={inputs};end
    signals=parser.Results.Signals;if ~iscell(signals),signals={signals};end
    [pkg,rs]=packageAndSystem(blockPath,parser.Results.Package,parser.Results.ReactionSystem);
    type=string(extractAfter(string(get_param(blockPath,'System')),'nirp.blocks.'));
    details=struct('Type',type,'Parameters',struct(),'Dof',[]);
    prepared=parser.Results.PreparedParameters;
    switch type
        case "Stream"
            [outputs,info,details]=evaluateStream(blockPath,inputs,signals,pkg,rs,details);
        case "Mixer"
            requireInputs(inputs,str2double(get_param(blockPath,'NumInputs')),type);
            [out,info]=nirp.units.mixer([],inputs,rs);outputs={out};
        case "Splitter"
            requireInputs(inputs,1,type);
            if isempty(prepared),[params,result]=splitterParameters(blockPath,inputs{1});details.Dof=result;
            else,params=prepared;end
            [outputs,info]=nirp.units.splitter(params,inputs{1},rs);
        case "Separator"
            requireInputs(inputs,1,type);
            if isempty(prepared),[params,result]=separatorParameters(blockPath,inputs{1},rs);details.Dof=result;
            else,params=prepared;end
            [outputs,info]=nirp.units.separator(params,inputs{1},rs);
        case "Heater"
            requireInputs(inputs,1,type);
            if isempty(prepared),[params,result]=heaterParameters(blockPath,inputs{1},rs);details.Dof=result;
            else,params=prepared;end
            [out,info]=nirp.units.heater(params,inputs{1},rs);outputs={out};
        case {"CSTR","PFR"}
            requireInputs(inputs,1,type);
            if isempty(prepared),[params,result,rs]=reactorParameters(blockPath,inputs{1},signals,pkg,rs,type);details.Dof=result;
            else,params=prepared;end
            if type=="CSTR",[out,info]=nirp.units.cstr(params,inputs{1},rs);
            else,[out,info]=nirp.units.pfr(params,inputs{1},rs);end
            outputs={out};
        case "Jacket"
            if ~isempty(inputs),error('nirp:flowsheet:waitingFor','Jacket material inputs are not supported.');end
            [signal,info,result]=jacketSignal(blockPath,signals);outputs={signal};details.Dof=result;
        otherwise
            error('nirp:flowsheet:unsupportedPreview','%s is not evaluated before run.',type);
    end
    if exist('params','var'),details.Parameters=params;end
end

function [pkg,rs]=packageAndSystem(block,pkg,rs)
    if isempty(pkg)
        pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(block)));
    end
    nirp.pkg.validate(pkg);
    if isempty(rs),rs=nirp.pkg.toReactionSys(pkg);end
end

function requireInputs(inputs,count,type)
    if numel(inputs)~=count||any(cellfun(@isempty,inputs))
        error('nirp:flowsheet:waitingFor','%s is waiting for %d material input(s).',type,count);
    end
end

function [outputs,info,details]=evaluateStream(block,inputs,signals,pkg,rs,details)
    role=nirp.flowsheet.streamRole(block);
    if role=="Feed"
        name=string(get_param(block,'Name'));base=nirp.pkg.feedStream(pkg,name);
        stream=base;signalIndex=1;
        if strcmp(get_param(block,'TSource'),'Input port')
            temperature=requiredPositiveSignal(signals,signalIndex,'Feed-stream T','K');signalIndex=signalIndex+1;
        else
            temperature=str2double(get_param(block,'T'));
            if isfinite(temperature),temperature=UnitConverterHelper.convertToSI('Temperature',temperature,get_param(block,'TUnit'));
            else,temperature=base.T;end
        end
        stream.T=temperature;stream=nirp.stream.refresh(stream);
        if strcmp(get_param(block,'QSource'),'Input port')
            flow=requiredPositiveSignal(signals,signalIndex,'Feed-stream Q','m^3/s');signalIndex=signalIndex+1;
            if stream.phase==0
                stream.F=nirp.stream.concentration(base)*flow;stream.Q=flow;
            else
                stream.F=stream.F*(flow/base.Q);
            end
            stream=nirp.stream.refresh(stream);
        else
            flow=NaN;
        end
        if numel(signals)>=signalIndex
            error('nirp:blocks:invalidParameterPort','Feed stream received too many signal inputs.');
        end
        specs=nirp.dof.readSpecs(get_param(block,'Specifications'));
        if isempty(fieldnames(specs))
            result=[];
        else
            context=struct('nComponents',rs.nComponents,'phase',base.phase,'Mw',rs.componentMw);
            model=nirp.dof.catalog.feed(context);[values,origins]=specValues(specs);
            if strcmp(get_param(block,'TSource'),'Input port'),values.T=temperature;origins.T='external';end
            if strcmp(get_param(block,'QSource'),'Input port'),values.Q=flow;origins.Q='external';end
            result=nirp.dof.solve(model,values,origins);requireComplete(name,result);
            flows=zeros(rs.nComponents,1);for i=1:numel(flows),flows(i)=result.values.(['F' num2str(i)]);end
            stream=nirp.stream.create(flows,result.values.T,result.values.P,base.phase,result.values.Q);
        end
        outputs={stream};info=struct('status',stream.status,'message','');details.Dof=result;
    else
        requireInputs(inputs,1,"Stream");outputs=inputs(1);info=struct('status',inputs{1}.status,'message','');
    end
end

function value=requiredPositiveSignal(signals,index,label,unit)
    if numel(signals)<index
        error('nirp:flowsheet:waitingFor','%s is waiting for its %s signal input.',label,unit);
    end
    value=signals{index};
    if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<=0
        error('nirp:blocks:invalidParameterPort','%s input must be positive %s.',label,unit);
    end
end

function [params,result]=splitterParameters(block,in)
    fractions=str2num(get_param(block,'Fractions')); %#ok<ST2NM>
    specs=nirp.dof.readSpecs(get_param(block,'Specifications'));
    output=nirp.dof.connectedSpecifications(block);
    if isempty(fieldnames(specs))&&isempty(strtrim(get_param(block,'Specifications')))
        for i=1:max(0,numel(fractions)-1),specs.(['f' num2str(i)])=item(fractions(i),'1');end
    end
    model=nirp.dof.catalog.splitter(numel(fractions));
    result=nirp.dof.resolveProducer(model,'Splitter',get_param(block,'Name'),specs,output, ...
        struct('F_in',sum(in.F)),struct('F_in','external'));requireComplete(get_param(block,'Name'),result);
    values=zeros(1,numel(fractions));for i=1:numel(values),values(i)=result.values.(['f' num2str(i)]);end
    params=struct('fractions',values);
end

function [params,result]=separatorParameters(block,in,rs)
    specs=nirp.dof.readSpecs(get_param(block,'Specifications'));recovery=str2num(get_param(block,'Recovery')); %#ok<ST2NM>
    if isempty(fieldnames(specs))&&isempty(strtrim(get_param(block,'Specifications')))
        if isscalar(recovery),recovery=repmat(recovery,1,rs.nComponents);end
        for i=1:numel(recovery),specs.(['r' num2str(i)])=item(recovery(i),'1');end
    end
    values=struct();origins=struct();for i=1:rs.nComponents,key=['F_in' num2str(i)];values.(key)=in.F(i);origins.(key)='external';end
    model=nirp.dof.catalog.separator(rs.nComponents);output=nirp.dof.connectedSpecifications(block);
    result=nirp.dof.resolveProducer(model,'Separator',get_param(block,'Name'),specs,output,values,origins);requireComplete(get_param(block,'Name'),result);
    recovery=zeros(1,rs.nComponents);for i=1:numel(recovery),recovery(i)=result.values.(['r' num2str(i)]);end
    params=struct('recovery',recovery);
end

function [params,result]=heaterParameters(block,in,rs)
    specs=nirp.dof.readSpecs(get_param(block,'Specifications'));text=get_param(block,'Specifications');
    output=nirp.dof.connectedSpecifications(block);
    if isempty(fieldnames(specs))&&isempty(strtrim(text))
        if strcmp(get_param(block,'Mode'),'Duty'),specs.Q=item(convert(block,'Duty','Power','DutyUnit'),'W');
        else,specs.T_out=item(convert(block,'Tout','Temperature','ToutUnit'),'K');end
        specs.dP=item(convert(block,'PressureDrop','Pressure','PressureDropUnit'),'Pa');
    end
    model=nirp.dof.catalog.heater(struct('inlet',in,'RS',rs));
    values=struct('T_in',in.T,'P_in',in.P);origins=struct('T_in','external','P_in','external');
    result=nirp.dof.resolveProducer(model,'Heater',get_param(block,'Name'),specs,output,values,origins);requireComplete(get_param(block,'Name'),result);
    params=struct('dP',result.values.dP);
    if isfield(specs,'Q')&&~isfield(output.values,'T_out'),params.mode='Duty';params.Q=result.values.Q;
    else,params.mode='Outlet T';params.Tout=result.values.T_out;end
end

function [params,result,rs]=reactorParameters(block,in,signals,pkg,rs,type)
    selected=get_param(block,'Reactions');if ~isempty(strtrim(selected)),rs=nirp.pkg.toReactionSys(nirp.pkg.selectReactions(pkg,selected));end
    params=thermal(block);specs=nirp.dof.readSpecs(get_param(block,'Specifications'));result=[];
    signalIndex=1;externalV=NaN;
    if strcmp(get_param(block,'VSource'),'Input port')
        if numel(signals)<signalIndex,error('nirp:flowsheet:waitingFor','%s is waiting for its V signal input.',type);end
        externalV=signals{signalIndex};
        if ~isnumeric(externalV)||~isscalar(externalV)||~isfinite(externalV)||externalV<=0
            error('nirp:blocks:invalidParameterPort','%s V input must be positive m^3.',type);
        end
        signalIndex=signalIndex+1;
    end
    if type=="CSTR"
        params.V=convert(block,'V','Volume','VUnit');context=struct('catalytic',on(get_param(block,'Catalytic')));
    else
        params.L=convert(block,'L','Length','LUnit');params.D=convert(block,'D','Length','DUnit');params.nTubes=str2double(get_param(block,'NTubes'));
        params.pressureMode=get_param(block,'PressureMode');params.pressureDropEqn=get_param(block,'PressureDropEqn');
        params.particleDiameter=convert(block,'ParticleDiameter','Length','ParticleDiameterUnit');params.density=convert(block,'Density','Density','DensityUnit');params.viscosity=convert(block,'Viscosity','Viscosity','ViscosityUnit');
        context=struct('catalytic',on(get_param(block,'Catalytic')),'pressureMode',params.pressureMode,'pressureDropEqn',params.pressureDropEqn,'phase',phaseName(in.phase));
    end
    if ~isempty(fieldnames(specs))
        model=feval(['nirp.dof.catalog.' lower(char(type))],context);values=struct('Q0',in.Q);origins=struct('Q0','external');
        if strcmp(get_param(block,'VSource'),'Input port'),values.V=externalV;origins.V='external';end
        [specified,specifiedOrigins]=specValues(specs);values=merge(values,specified);origins=merge(origins,specifiedOrigins);
        result=nirp.dof.solve(model,values,origins);requireComplete(get_param(block,'Name'),result);
        params.V=result.values.V;
        if type=="PFR",validateTubeCount(result.values.N_tubes);params.L=result.values.L;params.D=result.values.D;params.nTubes=round(result.values.N_tubes);end
        if on(get_param(block,'Catalytic')),params.catalystDensity=result.values.rho_cat;params.catalystPorosity=result.values.epsilon;end
        for name={'density','viscosity','particleDiameter'},if isfield(result.values,name{1}),params.(name{1})=result.values.(name{1});end,end
    elseif strcmp(get_param(block,'VSource'),'Input port')
        params.V=externalV;if type=="PFR",params=rmfield(params,'L');end
    elseif type=="PFR"&&strcmp(get_param(block,'GeometryMode'),'Volume')
        params.V=convert(block,'V','Volume','VUnit');params=rmfield(params,'L');
    end
    needsJacket=strcmp(get_param(block,'HeatMode'),'Heat exchange')||on(get_param(block,'ShowJacketPort'));
    if needsJacket
        if numel(signals)<signalIndex,error('nirp:flowsheet:waitingFor','%s is waiting for a complete Jacket.',type);end
        params=nirp.blocks.internal.applyJacket(params,signals{signalIndex},char(type));
    end
    if type=="PFR",validateTubeCount(params.nTubes);end
    if type=="PFR"&&~isfield(params,'V')
        params.V=pi/4*params.D^2*params.nTubes*params.L;
    end
end

function params=thermal(block)
    catalystDensity=str2double(get_param(block,'CatalystDensity'));if ~isfinite(catalystDensity),catalystDensity=1;end
    catalystPorosity=str2double(get_param(block,'CatalystPorosity'));if ~isfinite(catalystPorosity),catalystPorosity=0;end
    params=struct('heatMode',get_param(block,'HeatMode'),'bypassRatio',0, ...
        'catalystDensity',catalystDensity, ...
        'catalystPorosity',catalystPorosity, ...
        'specifiedT',convertValue(block,'SpecifiedT',300,'Temperature','SpecifiedTUnit','K'), ...
        'specifiedQ',convertValue(block,'SpecifiedQ',0,'Power','SpecifiedQUnit','W'), ...
        'U',convertValue(block,'U',0,'HeatTransferCoefficient','UUnit','W/(m^2*K)'), ...
        'A',convertValue(block,'A',1,'Area','AUnit','m^2'), ...
        'utilityTin',convertValue(block,'UtilityTin',300,'Temperature','UtilityTinUnit','K'));
    tout=str2double(blockValue(block,'UtilityTout','NaN'));if isfinite(tout),params.utilityTout=UnitConverterHelper.convertToSI('Temperature',tout,blockValue(block,'UtilityToutUnit','K'));else,params.utilityTout=[];end
    guess=str2double(get_param(block,'InitialTGuess'));if isfinite(guess),params.initialTemperatureGuess=UnitConverterHelper.convertToSI('Temperature',guess,get_param(block,'InitialTGuessUnit'));else,params.initialTemperatureGuess=[];end
end

function [signal,info,result]=jacketSignal(block,signals)
    if ~isempty(signals),error('nirp:flowsheet:waitingFor','Jacket signal inputs are available only during Run.');end
    mode=get_param(block,'Mode');specs=nirp.dof.readSpecs(get_param(block,'Specifications'));result=[];
    if strcmp(mode,'Specified T'),value=convert(block,'SpecifiedT','Temperature','SpecifiedTUnit');code=2;
    elseif strcmp(mode,'Specified Q'),value=convert(block,'SpecifiedQ','Power','SpecifiedQUnit');code=3;
    else
        values=[convert(block,'U','HeatTransferCoefficient','UUnit');convert(block,'A','Area','AUnit');convert(block,'UtilityTin','Temperature','UtilityTinUnit');NaN];
        tout=str2double(get_param(block,'UtilityTout'));if isfinite(tout),values(4)=UnitConverterHelper.convertToSI('Temperature',tout,get_param(block,'UtilityToutUnit'));end
        if ~isempty(fieldnames(specs))
            model=nirp.dof.catalog.jacket(struct('mode',mode,'condenses',on(get_param(block,'Condenses'))));[v,o]=specValues(specs);v.Q=NaN;o.Q='external';result=nirp.dof.solve(model,v,o);requireComplete(get_param(block,'Name'),result);
            values=[result.values.U;result.values.A;result.values.T_in_s;result.values.T_out_s];
        end
        signal=[1;values];info=struct('status',1,'message','','mode','Utility');return
    end
    if ~isempty(fieldnames(specs)),model=nirp.dof.catalog.jacket(struct('mode',mode));[v,o]=specValues(specs);result=nirp.dof.solve(model,v,o);requireComplete(get_param(block,'Name'),result);if code==2,value=result.values.T_reactor;else,value=result.values.Q;end,end
    signal=[code;value;NaN;NaN;NaN];info=struct('status',1,'message','','mode',mode);
end

function [values,origins]=specValues(specs)
    values=struct();origins=struct();names=fieldnames(specs);for i=1:numel(names),values.(names{i})=specs.(names{i}).si;origins.(names{i})='specified';end
end
function requireComplete(name,result)
    if strcmp(result.status,'complete'),return,end
    if strcmp(result.status,'missing')
        missing=result.missing;if isfield(result,'missingLabels'),missing=result.missingLabels;end
        error('nirp:flowsheet:waitingFor','%s is waiting for: %s.',name,strjoin(missing,', '));
    end
    error('nirp:flowsheet:conflict','%s has conflicting specifications: %s',name,strjoin(result.messages,' '));
end
function value=convert(block,valueName,category,unitName),value=UnitConverterHelper.convertToSI(category,str2double(get_param(block,valueName)),get_param(block,unitName));end
function value=convertValue(block,valueName,default,category,unitName,defaultUnit),value=UnitConverterHelper.convertToSI(category,str2double(blockValue(block,valueName,num2str(default,17))),blockValue(block,unitName,defaultUnit));end
function value=blockValue(block,name,default)
    try
        value=get_param(block,name);
    catch
        value=default;
    end
end
function value=item(si,unit),value=struct('si',si,'unit',unit);end
function result=merge(a,b),result=a;names=fieldnames(b);for i=1:numel(names),result.(names{i})=b.(names{i});end,end
function flag=on(value),flag=strcmpi(char(string(value)),'on')||isequal(value,true);end
function value=phaseName(phase),if phase==1,value='G';else,value='L';end,end
function validateTubeCount(value),if ~isnumeric(value)||~isscalar(value)||~isfinite(value)||value<1||abs(value-round(value))>1e-9,error('nirp:blocks:invalidGeometry','Number of tubes must be a positive integer.');end,end
