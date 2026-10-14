function result = resolveProducer(model,producerType,producerName,internalSpecs,output,values,origins)
%RESOLVEPRODUCER Solve a producer catalogue with connected Stream specs.
%   INTERNALSPECS are user specifications stored on the producer. OUTPUT
%   contains external specifications returned by connectedSpecifications.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    if nargin<6||isempty(values),values=struct();end
    if nargin<7||isempty(origins),origins=struct();end
    if nargin<5||isempty(output),output=emptyOutput();end
    allowed={model.variables.name};names=fieldnames(internalSpecs) ;
    duplicates=strings(0,1) ;
    for i=1:numel(names)
        index=find(strcmp(allowed,names{i}),1) ;
        if isempty(index)||~model.variables(index).specifiable
            error('nirp:blocks:invalidSpecifications', ...
                'Unknown or non-specifiable %s specification "%s".',producerType,names{i}) ;
        end
        values.(names{i})=internalSpecs.(names{i}).si ;origins.(names{i})='specified' ;
    end
    externalNames=fieldnames(output.values) ;
    for i=1:numel(externalNames)
        name=externalNames{i} ;
        if ~ismember(name,allowed)
            error('nirp:blocks:invalidSpecifications','Unknown external %s specification "%s".',producerType,name) ;
        end
        if isfield(internalSpecs,name)
            duplicates(end+1)=string(name) ; %#ok<AGROW>
        else
            values.(name)=output.values.(name);origins.(name)='external' ;
        end
    end
    result=nirp.dof.solve(model,values,origins) ;
    if ~isempty(duplicates)
        for name=duplicates'
            key=char(name);result.states.(key)='conflict';result.conflicts(end+1)=name;
            result.messages(end+1)=sprintf('%s "%s" and Stream "%s" both specify %s.', ...
                producerType,producerName,output.streams.(key),key) ; %#ok<AGROW>
        end
        result.status='conflict' ;
    end
    if strcmp(result.status,'conflict')&&~isempty(externalNames)
        streamNames=strings(0,1) ;
        for i=1:numel(externalNames)
            key=externalNames{i};result.states.(key)='conflict';result.conflicts(end+1)=string(key);
            streamNames(end+1)=string(output.streams.(key)); %#ok<AGROW>
        end
        streamNames=unique(streamNames,'stable') ;
        result.messages(end+1)=sprintf('%s "%s" conflicts with Stream %s.', ...
            producerType,producerName,strjoin('"'+streamNames+'"',', ')) ;
    end
    result.conflicts=unique(result.conflicts,'stable') ;
    result.messages=unique(result.messages,'stable') ;
    result.external=output ;
end

function value=emptyOutput()
    value=struct('values',struct(),'origins',struct(),'sources',struct(), ...
        'streams',struct(),'streamKeys',struct()) ;
end
