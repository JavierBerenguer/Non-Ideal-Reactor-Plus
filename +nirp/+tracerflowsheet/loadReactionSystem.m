function RS = loadReactionSystem(origin,reference,model)
%LOADREACTIONSYSTEM Resolve a persisted ReactionSys reference.
%   ORIGIN is Session, Workspace, or File. REFERENCE is a MAT-file path
%   or base-workspace variable name. Relative files resolve beside MODEL.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 25, 2026. Last update: October 25, 2026
% =========================================================================

    origin = lower(strtrim(char(string(origin)))) ;
    reference = char(string(reference)) ;
    switch origin
        case 'workspace'
            if ~isvarname(reference) || ~evalin('base', ...
                    sprintf('exist(''%s'',''var'')',reference))
                error('nirp:tracerflowsheet:MissingReactionSystem', ...
                    'Workspace variable "%s" does not exist.',reference) ;
            end
            RS = evalin('base',reference) ;
        case {'session','file','new file'}
            path = resolvePath(reference,model) ;
            if ~isfile(path)
                error('nirp:tracerflowsheet:MissingReactionSystem', ...
                    'Reaction-system file does not exist: %s',path) ;
            end
            loaded = load(path,'-mat') ;
            if strcmp(origin,'session')
                RS = fromSession(loaded) ;
            else
                RS = findReactionSystem(loaded) ;
            end
        otherwise
            error('nirp:tracerflowsheet:InvalidReactionOrigin', ...
                'Reaction origin must be Session, Workspace, or File.') ;
    end
    RS = restoreReactionSystem(RS) ;
    if ~isa(RS,'ReactionSys') || RS.nComponents < 1
        error('nirp:tracerflowsheet:InvalidReactionSystem', ...
            'The reference does not contain a valid ReactionSys object.') ;
    end
end

function path = resolvePath(reference,model)
    path = reference ;
    if isempty(path), return, end
    if ~isfile(path) && nargin >= 2 && ~isempty(model)
        file = get_param(bdroot(model),'FileName') ;
        if ~isempty(file), path = fullfile(fileparts(file),reference) ; end
    end
end

function value = fromSession(loaded)
    value = [] ;
    if isfield(loaded,'sessionData') && isstruct(loaded.sessionData)
        session = loaded.sessionData ;
        sections = {'prediction','rtd','tis','dispersion'} ;
        for k = 1:numel(sections)
            if isfield(session,sections{k}) && isstruct(session.(sections{k})) && ...
                    isfield(session.(sections{k}),'rs') && ...
                    ~isempty(session.(sections{k}).rs)
                value = session.(sections{k}).rs ;
                return
            end
        end
    end
    if isempty(value), value = findReactionSystem(loaded) ; end
end

function value = findReactionSystem(container)
    value = [] ;
    if isa(container,'ReactionSys'), value = container ; return, end
    if ~isstruct(container), return, end
    fields = fieldnames(container) ;
    for k = 1:numel(fields)
        candidate = container.(fields{k}) ;
        if isa(candidate,'ReactionSys') || ...
                (isstruct(candidate) && isfield(candidate,'stochiometricMatrix'))
            value = candidate ;
            return
        end
    end
end

function RS = restoreReactionSystem(value)
    if isa(value,'ReactionSys'), RS = value ; return, end
    if ~isstruct(value), RS = []; return, end
    if isfield(value,'object_class') && ...
            ~strcmp(char(string(value.object_class)),'ReactionSys')
        RS = [] ;
        return
    end
    RS = ReactionSys ;
    fields = fieldnames(value) ;
    for k = 1:numel(fields)
        name = fields{k} ;
        if isprop(RS,name) && ~strcmp(name,'object_class')
            try, RS.(name) = value.(name) ; catch, end
        end
    end
end
