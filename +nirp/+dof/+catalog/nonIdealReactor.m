function model = nonIdealReactor(context)
%NONIDEALREACTOR Degree-of-freedom catalogue for an RTD reactor.
%   V (m^3), tau (s), and SV (1/s) follow the continuous-reactor size
%   relations. Q0 is supplied by the inlet. For measured RTDs tau is also
%   external: the distribution is never rescaled to fit a size entry.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 3, 2026
% =========================================================================

    origin=lower(string(option(context,'origin','model')));
    rtdModel=lower(string(option(context,'model','')));
    positive=struct('bounds',[0 Inf],'boundsClosed',[false true]);
    measured=any(origin==["data" "session"]);
    model=nirp.dof.model();
    volumeOptions=unit(positive,'m^3');if measured,volumeOptions.optional=true;end
    model=nirp.dof.addVariable(model,'V','Reactor volume','Volume',volumeOptions);
    tauOptions=unit(positive,'s');
    if measured,tauOptions.specifiable=false;end
    model=nirp.dof.addVariable(model,'tau','Residence time','Time',tauOptions);
    velocityOptions=unit(positive,'1/s');if measured,velocityOptions.optional=true;end
    model=nirp.dof.addVariable(model,'SV','Space velocity','Frequency',velocityOptions);
    model=nirp.dof.addVariable(model,'Q0','Inlet volumetric flow','VolumetricFlow', ...
        merge(unit(positive,'m^3/s'),struct('specifiable',false)));
    % solve() flags residuals above 1e-9; scaling by 1e3 implements the
    % reactor-size compatibility threshold of 1e-6 relative.
    if measured
        % Measured tau and Q0 already close the reactor. Optional user
        % entries are consistency checks, not extra degrees of freedom.
        model=nirp.dof.addRelation(model,'residence_time',{'V','tau','Q0'}, ...
            struct(),@(v)relative(v.V,v.tau*v.Q0)/1e3,struct('redundant',true));
        model=nirp.dof.addRelation(model,'space_velocity',{'SV','tau'}, ...
            struct(),@(v)relative(v.SV*v.tau,1)/1e3,struct('redundant',true));
    else
        model=nirp.dof.addRelation(model,'residence_time',{'V','tau','Q0'}, ...
            struct('V',@(v)v.tau*v.Q0,'tau',@(v)v.V/v.Q0,'Q0',@(v)v.V/v.tau), ...
            @(v)relative(v.V,v.tau*v.Q0)/1e3);
        model=nirp.dof.addRelation(model,'space_velocity',{'SV','tau'}, ...
            struct('SV',@(v)1/v.tau,'tau',@(v)1/v.SV),@(v)relative(v.SV*v.tau,1)/1e3);
    end
    if origin=="model" && any(rtdModel==["tanks" "tanks in series" "tanks-in-series"])
        integer=merge(unit(positive,'1'),struct('missingLabel','number of tanks'));
        model=nirp.dof.addVariable(model,'N','Number of tanks','Count',integer);
        model=nirp.dof.addRelation(model,'integer_tanks',{'N'},struct(), ...
            @(v)abs(v.N-round(v.N)),struct('redundant',true));
    elseif origin=="model" && rtdModel=="dispersion"
        model=nirp.dof.addVariable(model,'Pe','Peclet number','Dimensionless', ...
            merge(unit(positive,'1'),struct('missingLabel','Peclet number')));
    end
end

function value=option(context,name,default),value=default;if isstruct(context)&&isfield(context,name),value=context.(name);end,end
function value=unit(options,name),value=options;value.displayUnit=name;end
function value=merge(a,b),value=a;n=fieldnames(b);for i=1:numel(n),value.(n{i})=b.(n{i});end,end
function value=relative(a,b),value=abs(a-b)/max([abs(a) abs(b) 1e-12]);end
