function model = mixer(context)
%MIXER Result-only catalogue for a mixer with known inlet streams.
%   Mixer has no user degrees of freedom. Outlet component flows (mol/s)
%   and pressure (Pa) are optional, non-specifiable result variables.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    if isnumeric(context),n=context;elseif isstruct(context)&&isfield(context,'nComponents'),n=context.nComponents;elseif isstruct(context)&&isfield(context,'components'),n=numel(context.components);else,error('nirp:dof:invalidContext','Mixer context needs nComponents or components.');end
    if ~(isnumeric(n)&&isscalar(n)&&isfinite(n)&&n==fix(n)&&n>=1),error('nirp:dof:invalidContext','nComponents must be a positive integer.');end
    model=nirp.dof.model();options=struct('bounds',[0 Inf],'specifiable',false,'optional',true,'displayUnit','mol/s');
    for i=1:n,model=nirp.dof.addVariable(model,['F_out' num2str(i)],sprintf('Outlet flow %d',i),'MolarFlow',options);end
    options.displayUnit='Pa';model=nirp.dof.addVariable(model,'P_out','Outlet pressure','Pressure',options);
end
