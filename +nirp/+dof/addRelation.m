function model = addRelation(model,id,varNames,solvers,residual,options)
%ADDRELATION Add an algebraic relation and its per-variable solvers.
%   Solver and residual functions may accept either the complete values
%   structure or positional values in the relation variable order.
%   OPTIONS.redundant marks a dependent relation: it participates in
%   propagation and consistency checks but does not reduce the model DOF.
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
    if nargin < 6 || isempty(options), options=struct() ; end
    if ~isstruct(solvers)
        error('nirp:dof:invalidSolver','Solvers for relation "%s" must be a structure.',id) ;
    end
    redundant=false ;
    if isfield(options,'redundant'),redundant=options.redundant;end
    if ~(islogical(redundant)||isnumeric(redundant))||~isscalar(redundant)
        error('nirp:dof:invalidRelation','redundant must be a logical scalar.') ;
    end
    fields=fieldnames(solvers) ;
    if ~all(ismember(fields,names))
        error('nirp:dof:invalidSolver','Relation "%s" has a solver for a variable outside the relation.',id) ;
    end
    model.relations(end+1)=struct('id',id,'variables',{names}, ...
        'solvers',solvers,'residual',residual,'redundant',logical(redundant)) ;
end
