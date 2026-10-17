function target = streamSpecificationTarget(streamBlock,specifications)
%STREAMSPECIFICATIONTARGET Map a connected Stream specification to its producer.
%   Specification values are SI. The returned producer-variable names can
%   be inserted in that producer's DOF catalogue with origin external.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    streamBlock=getfullname(streamBlock) ;
    if nargin<2,specifications=nirp.dof.readSpecs(streamBlock);end
    if string(nirp.flowsheet.streamRole(streamBlock))=="Feed"
        error('nirp:dof:unsupportedStreamSpecification', ...
            'No block can meet this specification directly; use an Adjust.') ;
    end
    model=bdroot(streamBlock);graph=nirp.flowsheet.topology(model) ;
    streamName=string(get_param(streamBlock,'Name')) ;
    streamKey=matlab.lang.makeValidName(streamName) ;
    if ~isfield(graph.Streams,streamKey)||isempty(graph.Streams.(streamKey).Producer)
        error('nirp:dof:unsupportedStreamSpecification', ...
            'No block can meet this specification directly; use an Adjust.') ;
    end
    producerName=string(graph.Streams.(streamKey).Producer) ;
    if numel(producerName)~=1
        error('nirp:dof:unsupportedStreamSpecification', ...
            'No block can meet this specification directly; use an Adjust.') ;
    end
    unitFields=fieldnames(graph.Units);producer=[] ;
    for i=1:numel(unitFields)
        candidate=graph.Units.(unitFields{i}) ;
        if candidate.Name==producerName,producer=candidate;break,end
    end
    if isempty(producer)
        error('nirp:dof:unsupportedStreamSpecification', ...
            'No block can meet this specification directly; use an Adjust.') ;
    end
    port=[] ;
    for i=1:numel(producer.Outputs)
        if any(string(producer.Outputs{i})==streamName),port=i;break,end
    end
    if isempty(port)
        error('nirp:dof:unsupportedStreamSpecification', ...
            'No block can meet this specification directly; use an Adjust.') ;
    end
    target=struct('StreamPath',streamBlock,'StreamName',char(streamName), ...
        'ProducerPath',char(producer.Path),'ProducerName',char(producer.Name), ...
        'ProducerType',char(producer.Type),'OutputPort',port, ...
        'Values',struct(),'Sources',struct(),'StreamKeys',struct()) ;
    names=fieldnames(specifications) ;
    for i=1:numel(names)
        producerVariable=mapName(producer.Type,port,names{i}) ;
        target.Values.(producerVariable)=specifications.(names{i}).si ;
        target.Sources.(producerVariable)=sprintf('from stream %s specification',streamName) ;
        target.StreamKeys.(producerVariable)=names{i} ;
    end
end

function target=mapName(type,port,name)
    switch string(type)
        case "Splitter"
            if ~strcmp(name,'F'),unsupported(name,type);end
            target=sprintf('F_out%d',port) ;
        case "Separator"
            token=regexp(name,'^(F|x)(\d+)$','tokens','once') ;
            if isempty(token)||port>2,unsupported(name,type);end
            side='top';if port==2,side='bot';end
            target=sprintf('%s_%s%s',token{1},side,token{2}) ;
        case "Heater"
            if strcmp(name,'T'),target='T_out';elseif strcmp(name,'P'),target='P_out';else,unsupported(name,type);end
        otherwise
            unsupported(name,type) ;
    end
end

function unsupported(name,type)
    error('nirp:dof:unsupportedStreamSpecification', ...
        ['No block can meet this specification directly; use an Adjust. ' ...
        '%s does not support stream specification "%s".'],type,name) ;
end
