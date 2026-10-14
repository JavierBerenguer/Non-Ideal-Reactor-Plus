function model = addVariable(model,name,label,category,options)
%ADDVARIABLE Add one SI variable to a degree-of-freedom model.
%   OPTIONS supports bounds [MIN MAX], boundsClosed [LOW HIGH],
%   specifiable, optional, and displayUnit.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    if nargin < 5 || isempty(options), options = struct() ; end
    name = char(string(name)) ;
    if ~isvarname(name)
        error('nirp:dof:invalidVariable','Variable name "%s" is not a valid MATLAB identifier.',name) ;
    end
    if any(strcmp({model.variables.name},name))
        error('nirp:dof:duplicateVariable','Variable "%s" already exists.',name) ;
    end
    bounds = option(options,'bounds',[-Inf Inf]) ;
    closed = option(options,'boundsClosed',[true true]) ;
    if ~(isnumeric(bounds) && isreal(bounds) && numel(bounds)==2 && bounds(1)<=bounds(2))
        error('nirp:dof:invalidBounds','Bounds for "%s" must be an ordered two-element real vector.',name) ;
    end
    if ~(islogical(closed) || isnumeric(closed)) || numel(closed)~=2
        error('nirp:dof:invalidBounds','boundsClosed must contain two logical values.') ;
    end
    variable = struct('name',name,'label',char(string(label)), ...
        'category',char(string(category)),'bounds',double(reshape(bounds,1,2)), ...
        'boundsClosed',logical(reshape(closed,1,2)), ...
        'specifiable',logical(option(options,'specifiable',true)), ...
        'optional',logical(option(options,'optional',false)), ...
        'displayUnit',char(string(option(options,'displayUnit',''))) ) ;
    model.variables(end+1) = variable ;
end

function value = option(options,name,default)
    if isfield(options,name), value=options.(name); else, value=default; end
end
