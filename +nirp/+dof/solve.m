function result = solve(model,values,origins)
%SOLVE Propagate a local algebraic degree-of-freedom model.
%   Specified and external SI values are retained. Calculated values are
%   cleared and rebuilt from relations having exactly one unknown.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    names={model.variables.name}; n=numel(names) ;
    valueStruct=normaliseValues(names,values) ;
    originStruct=normaliseOrigins(names,origins) ;
    producer=struct(); states=struct(); conflict=false(1,n); messages=strings(0,1) ;
    for i=1:n
        name=names{i}; origin=string(originStruct.(name)) ;
        if origin=="calculated"
            valueStruct.(name)=NaN; origin="empty";
        end
        if ~isKnown(valueStruct.(name)) && origin~="external", origin="empty"; end
        if isKnown(valueStruct.(name)) && origin=="empty", origin="specified"; end
        if ~any(origin==["empty" "specified" "calculated" "external"])
            error('nirp:dof:invalidOrigin','Unknown origin "%s" for variable "%s".',origin,name) ;
        end
        originStruct.(name)=char(origin); producer.(name)='' ;
    end

    changed=true ;
    while changed
        changed=false ;
        for j=1:numel(model.relations)
            relation=model.relations(j); unknown=relation.variables(~cellfun(@(x)isKnown(valueStruct.(x)),relation.variables)) ;
            if numel(unknown)==1 && isfield(relation.solvers,unknown{1})
                target=unknown{1}; candidate=invoke(relation.solvers.(target),valueStruct,relation.variables,target) ;
                if isnumeric(candidate) && isreal(candidate) && isscalar(candidate) && ~isnan(candidate)
                    valueStruct.(target)=double(candidate); originStruct.(target)='calculated';producer.(target)=relation.id;changed=true;
                end
            end
        end
    end

    for j=1:numel(model.relations)
        relation=model.relations(j) ;
        allKnown=all(cellfun(@(x)isKnown(valueStruct.(x)),relation.variables)) ;
        if allKnown && ~isempty(relation.residual)
            residual=invoke(relation.residual,valueStruct,relation.variables,'') ;
            if ~(isnumeric(residual)&&isscalar(residual)&&isfinite(residual)) || abs(residual)>1e-9
                involved=find(ismember(names,relation.variables) & arrayfun(@(k)string(originStruct.(names{k}))=="specified",1:n)) ;
                conflict(involved)=true ;
                messages(end+1)=sprintf('Relation %s is inconsistent.',relation.id) ; %#ok<AGROW>
            end
        end
    end
    for i=1:n
        name=names{i}; value=valueStruct.(name) ;
        if ~isKnown(value), continue, end
        variable=model.variables(i); below=value<variable.bounds(1) || (~variable.boundsClosed(1)&&value==variable.bounds(1));
        above=value>variable.bounds(2) || (~variable.boundsClosed(2)&&value==variable.bounds(2));
        if below || above
            conflict(i)=true ;
            if string(originStruct.(name))=="calculated" && ~isempty(producer.(name))
                relation=model.relations(strcmp({model.relations.id},producer.(name))) ;
                specified=relation.variables(cellfun(@(x)string(originStruct.(x))=="specified",relation.variables));
                conflict(ismember(names,specified))=true ;
            end
            messages(end+1)=sprintf('%s is outside its allowed range.',variable.label) ; %#ok<AGROW>
        end
    end

    isExternal=arrayfun(@(i)string(originStruct.(names{i}))=="external",1:n) ;
    isSpecified=arrayfun(@(i)string(originStruct.(names{i}))=="specified",1:n) ;
    optionalEmpty=arrayfun(@(i)model.variables(i).optional && ~isKnown(valueStruct.(names{i})),1:n) ;
    dof=n-numel(model.relations)-sum(isExternal) ;
    remaining=dof-sum(isSpecified)-sum(optionalEmpty) ;
    if remaining<0
        % Output-Stream specifications are external to the producer but
        % consume its DOF exactly like local user specifications.
        conflict(isSpecified|isExternal)=true ;
        messages(end+1)="Over-specified model." ;
    end
    missingCount=max(0,remaining) ;
    candidates=find(arrayfun(@(i)model.variables(i).specifiable && ~model.variables(i).optional && ...
        string(originStruct.(names{i}))=="empty",1:n)) ;
    missingNames=string(names(candidates(1:min(numel(candidates),missingCount)))) ;
    for i=1:n
        origin=string(originStruct.(names{i})) ;
        if conflict(i), state="conflict"; elseif origin=="external", state="external"; ...
        elseif origin=="calculated", state="calculated"; elseif origin=="specified", state="specified"; else, state="empty"; end
        states.(names{i})=char(state) ;
    end
    if any(conflict)
        status="conflict" ;
    elseif missingCount>0
        status="missing" ;
        suffix='s';if missingCount==1,suffix='';end
        if isempty(missingNames), messages(end+1)=sprintf('%d specification%s missing.',missingCount,suffix); ...
        else, messages(end+1)=sprintf('%d specification%s missing: %s.',missingCount,suffix,strjoin(missingNames,', ')); end
    else
        status="complete" ;
    end
    result=struct('values',valueStruct,'origins',originStruct,'states',states, ...
        'producer',producer,'messages',unique(messages,'stable'),'status',char(status), ...
        'dof',dof,'missingCount',missingCount,'missing',missingNames, ...
        'conflicts',string(names(conflict))) ;
end

function values=normaliseValues(names,input)
    values=struct();
    if nargin<2 || isempty(input),input=struct();end
    for i=1:numel(names)
        if isstruct(input)&&isfield(input,names{i}),values.(names{i})=input.(names{i}); ...
        elseif isnumeric(input)&&numel(input)>=i,values.(names{i})=input(i);else,values.(names{i})=NaN;end
    end
end
function origins=normaliseOrigins(names,input)
    origins=struct();if nargin<2||isempty(input),input=struct();end
    for i=1:numel(names)
        if isstruct(input)&&isfield(input,names{i}),origins.(names{i})=char(string(input.(names{i}))); ...
        elseif (isstring(input)||iscellstr(input))&&numel(input)>=i,origins.(names{i})=char(string(input(i)));else,origins.(names{i})='empty';end
    end
end
function flag=isKnown(value)
    flag=isnumeric(value)&&isreal(value)&&isscalar(value)&&~isnan(value) ;
end
function output=invoke(fun,values,varNames,target)
    try
        output=fun(values);return
    catch first
        args=varNames;
        if ~isempty(target),args(strcmp(args,target))=[];end
        try
            positional=cellfun(@(x)values.(x),args,'UniformOutput',false) ;
            output=fun(positional{:});
        catch
            rethrow(first)
        end
    end
end
