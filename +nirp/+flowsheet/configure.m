function configure(modelName)
%CONFIGURE Apply the stationary milestone-1 solver configuration.
%   nirp.flowsheet.configure(MODELNAME) sets one discrete sample at t=0.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    model = char(string(modelName)) ;
    [~,base,extension] = fileparts(model) ;
    if ~isempty(extension)
        load_system(model) ;
        model = base ;
    elseif ~bdIsLoaded(model)
        load_system(model) ;
    end
    set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
        'FixedStep','1','StopTime','0') ;
end
