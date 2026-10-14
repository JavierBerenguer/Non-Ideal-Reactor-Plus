function value = model()
%MODEL Create an empty local degree-of-freedom model.
%   Models contain SI variables and algebraic relations only. They have no
%   dependency on Simulink or the graphical interface.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    variables = struct('name',{},'label',{},'missingLabel',{},'category',{},'bounds',{}, ...
        'boundsClosed',{},'specifiable',{},'optional',{},'displayUnit',{}) ;
    relations = struct('id',{},'variables',{},'solvers',{},'residual',{},'redundant',{}) ;
    value = struct('variables',variables,'relations',relations) ;
end
