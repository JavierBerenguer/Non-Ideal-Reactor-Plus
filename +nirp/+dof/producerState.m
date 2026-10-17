function state = producerState(producerBlock,varargin)
%PRODUCERSTATE Resolve a Splitter, Separator, or Heater including Streams.
%   This dialog-time helper uses a known inlet when available. Passing
%   Inlet=[] explicitly keeps inlet externals unknown, as setupImpl does.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    parser=inputParser ;
    addParameter(parser,'Inlet',[]) ;
    addParameter(parser,'InternalSpecifications',struct()) ;
    addParameter(parser,'OverrideStream','') ;
    addParameter(parser,'OverrideSpecifications',struct()) ;
    parse(parser,varargin{:}) ;
    providedInlet=hasOption(varargin,'Inlet') ;
    providedInternal=hasOption(varargin,'InternalSpecifications') ;
    producerBlock=getfullname(producerBlock);type=string(extractAfter(string(get_param(producerBlock,'System')),'nirp.blocks.')) ;
    if ~any(type==["Splitter" "Separator" "Heater"])
        error('nirp:dof:unsupportedStreamSpecification', ...
            'No block can meet this specification directly; use an Adjust.') ;
    end
    if providedInlet,inlet=parser.Results.Inlet;source="";else,[inlet,source]=nirp.dof.knownInlet(producerBlock);end
    if providedInternal,internal=parser.Results.InternalSpecifications;else,internal=storedSpecifications(producerBlock,type);end
    output=nirp.dof.connectedSpecifications(producerBlock, ...
        'OverrideStream',parser.Results.OverrideStream, ...
        'OverrideSpecifications',parser.Results.OverrideSpecifications) ;
    values=struct();origins=struct();pkg=[];rs=[] ;
    switch type
        case "Splitter"
            fractions=str2num(get_param(producerBlock,'Fractions')); %#ok<ST2NM>
            model=nirp.dof.catalog.splitter(numel(fractions));values.F_in=scalarFlow(inlet);origins.F_in='external';
        case "Separator"
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(producerBlock)));rs=nirp.pkg.toReactionSys(pkg);
            model=nirp.dof.catalog.separator(rs.nComponents);
            for i=1:rs.nComponents,key=['F_in' num2str(i)];if isempty(inlet),values.(key)=NaN;else,values.(key)=inlet.F(i);end;origins.(key)='external';end
        case "Heater"
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(producerBlock)));rs=nirp.pkg.toReactionSys(pkg);
            context=struct('inlet',inlet,'RS',rs);model=nirp.dof.catalog.heater(context);
            if isempty(inlet),values.T_in=NaN;values.P_in=NaN;else,values.T_in=inlet.T;values.P_in=inlet.P;end
            origins.T_in='external';origins.P_in='external';
    end
    name=get_param(producerBlock,'Name') ;
    result=nirp.dof.resolveProducer(model,char(type),name,internal,output,values,origins) ;
    state=struct('Result',result,'Model',model,'Output',output,'Internal',internal, ...
        'Inlet',inlet,'InletSource',source,'Package',pkg,'ReactionSystem',rs) ;
end

function specs=storedSpecifications(block,type)
    text=get_param(block,'Specifications') ;
    if ~isempty(strtrim(text)),specs=nirp.dof.readSpecs(text);return,end
    specs=struct() ;
    switch type
        case "Splitter"
            values=str2num(get_param(block,'Fractions')); %#ok<ST2NM>
            for i=1:max(0,numel(values)-1),if isfinite(values(i)),specs.(['f' num2str(i)])=item(values(i),'1');end,end
        case "Separator"
            pkg=nirp.pkg.readDictionary(nirp.flowsheet.modelDictionary(bdroot(block)));n=numel(pkg.components);
            values=str2num(get_param(block,'Recovery')); %#ok<ST2NM>
            if isscalar(values),values=repmat(values,1,n);end
            for i=1:min(n,numel(values)),if isfinite(values(i)),specs.(['r' num2str(i)])=item(values(i),'1');end,end
        case "Heater"
            if strcmp(get_param(block,'Mode'),'Duty')
                value=str2double(get_param(block,'Duty'));if isfinite(value),value=UnitConverterHelper.convertToSI('Power',value,get_param(block,'DutyUnit'));specs.Q=item(value,get_param(block,'DutyUnit'));end
            else
                value=str2double(get_param(block,'Tout'));if isfinite(value),value=UnitConverterHelper.convertToSI('Temperature',value,get_param(block,'ToutUnit'));specs.T_out=item(value,get_param(block,'ToutUnit'));end
            end
            value=str2double(get_param(block,'PressureDrop'));if isfinite(value),value=UnitConverterHelper.convertToSI('Pressure',value,get_param(block,'PressureDropUnit'));specs.dP=item(value,get_param(block,'PressureDropUnit'));end
    end
end
function value=item(si,unit),value=struct('si',si,'unit',char(unit));end
function flag=hasOption(arguments,name),flag=false;for i=1:2:numel(arguments),if strcmpi(char(string(arguments{i})),name),flag=true;return,end,end,end
function value=scalarFlow(inlet),if isempty(inlet),value=NaN;else,value=sum(inlet.F);end,end
