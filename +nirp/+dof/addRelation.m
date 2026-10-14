function model = addRelation(model,id,varNames,solvers,residual)
%ADDRELATION Add an algebraic relation and its per-variable solvers.
%   Solver and residual functions may accept either the complete values
%   structure or positional values in the relation variable order.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    id = char(string(id)) ;
    names = cellstr(string(varNames(:)')) ;
    if isempty(names) || numel(unique(names))~=numel(names)
        error('nirp:dof:invalidRelation','Relation "%s" must name distinct variables.',id) ;
    end
    known = {model.variables.name} ;
    if ~all(ismember(names,known))
        error('nirp:dof:unknownVariable','Relation "%s" references an unknown variable.',id) ;
    end
    if any(strcmp({model.relations.id},id))
        error('nirp:dof:duplicateRelation','Relation "%s" already exists.',id) ;
    end
    if nargin < 4 || isempty(solvers), solvers=struct() ; end
    if nargin < 5 || isempty(residual), residual=[] ; end
    if ~isstruct(solvers)
        error('nirp:dof:invalidSolver','Solvers for relation "%s" must be a structure.',id) ;
    end
    fields=fieldnames(solvers) ;
    if ~all(ismember(fields,names))
        error('nirp:dof:invalidSolver','Relation "%s" has a solver for a variable outside the relation.',id) ;
    end
    model.relations(end+1)=struct('id',id,'variables',{names}, ...
        'solvers',solvers,'residual',residual) ;
end
