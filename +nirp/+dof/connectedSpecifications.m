function output = connectedSpecifications(producerBlock,varargin)
%CONNECTEDSPECIFICATIONS Read specifications on a producer's output Streams.
%   The returned values use producer-catalogue variable names and SI units.
%   OverrideStream/OverrideSpecifications let a Stream dialog validate
%   edits before persisting them.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    parser=inputParser ;
    addParameter(parser,'OverrideStream','') ;
    addParameter(parser,'OverrideSpecifications',struct()) ;
    parse(parser,varargin{:}) ;
    producerBlock=getfullname(producerBlock) ;
    override=char(string(parser.Results.OverrideStream)) ;
    if ~isempty(override),override=getfullname(override);end
    graph=nirp.flowsheet.topology(bdroot(producerBlock)) ;
    key=matlab.lang.makeValidName(get_param(producerBlock,'Name')) ;
    output=struct('values',struct(),'origins',struct(),'sources',struct(), ...
        'streams',struct(),'streamKeys',struct()) ;
    if ~isfield(graph.Units,key),return,end
    unit=graph.Units.(key) ;
    for port=1:numel(unit.Outputs)
        names=string(unit.Outputs{port}) ;
        for j=1:numel(names)
            streamKey=matlab.lang.makeValidName(names(j)) ;
            if ~isfield(graph.Streams,streamKey),continue,end
            streamPath=char(graph.Streams.(streamKey).Path) ;
            if strcmp(streamPath,override),specs=parser.Results.OverrideSpecifications;else,specs=nirp.dof.readSpecs(streamPath);end
            if isempty(fieldnames(specs)),continue,end
            target=nirp.dof.streamSpecificationTarget(streamPath,specs) ;
            targetNames=fieldnames(target.Values) ;
            for k=1:numel(targetNames)
                name=targetNames{k} ;
                if isfield(output.values,name)
                    error('nirp:dof:conflictingStreamSpecifications', ...
                        'Streams "%s" and "%s" both specify the same output quantity on %s "%s".', ...
                        output.streams.(name),target.StreamName,unit.Type,unit.Name) ;
                end
                output.values.(name)=target.Values.(name) ;
                output.origins.(name)='external' ;
                output.sources.(name)=target.Sources.(name) ;
                output.streams.(name)=target.StreamName ;
                output.streamKeys.(name)=target.StreamKeys.(name) ;
            end
        end
    end
end
