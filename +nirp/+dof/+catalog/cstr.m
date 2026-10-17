function model = cstr(context)
%CSTR Degree-of-freedom catalogue for a continuous stirred-tank reactor.
%   CONTEXT.catalytic enables catalyst mass W (kg), particle density
%   rho_cat (kg/m^3), and void fraction epsilon. Q0 is external (m^3/s).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    catalytic=option(context,'catalytic',false) ;
    model=nirp.dof.model() ; positive=struct('bounds',[0 Inf],'boundsClosed',[false true]) ;
    model=nirp.dof.addVariable(model,'V','Reactor volume','Volume',unit(positive,'m^3')) ;
    model=nirp.dof.addVariable(model,'tau','Residence time','Time',unit(positive,'s')) ;
    model=nirp.dof.addVariable(model,'SV','Space velocity','Frequency',unit(positive,'1/s')) ;
    model=nirp.dof.addVariable(model,'Q0','Inlet volumetric flow','VolumetricFlow', ...
        merge(unit(positive,'m^3/s'),struct('specifiable',false))) ;
    model=nirp.dof.addRelation(model,'residence_time',{'V','tau','Q0'}, ...
        struct('V',@(v)v.tau*v.Q0,'tau',@(v)v.V/v.Q0,'Q0',@(v)v.V/v.tau), ...
        @(v)relative(v.V,v.tau*v.Q0)) ;
    model=nirp.dof.addRelation(model,'space_velocity',{'SV','tau'}, ...
        struct('SV',@(v)1/v.tau,'tau',@(v)1/v.SV),@(v)relative(v.SV*v.tau,1)) ;
    if catalytic
        model=nirp.dof.addVariable(model,'W','Catalyst mass','Mass',unit(positive,'kg')) ;
        model=nirp.dof.addVariable(model,'rho_cat','Catalyst density','Density',unit(positive,'kg/m^3')) ;
        model=nirp.dof.addVariable(model,'epsilon','Catalyst void fraction','Fraction', ...
            struct('bounds',[0 1],'boundsClosed',[true false],'displayUnit','1')) ;
        model=nirp.dof.addRelation(model,'catalyst_mass',{'W','rho_cat','epsilon','V'}, ...
            struct('W',@(v)v.rho_cat*(1-v.epsilon)*v.V, ...
            'rho_cat',@(v)v.W/((1-v.epsilon)*v.V), ...
            'epsilon',@(v)1-v.W/(v.rho_cat*v.V), ...
            'V',@(v)v.W/(v.rho_cat*(1-v.epsilon))), ...
            @(v)relative(v.W,v.rho_cat*(1-v.epsilon)*v.V)) ;
    end
end

function value=option(context,name,default),value=default;if isstruct(context)&&isfield(context,name),value=context.(name);end,end
function value=unit(options,name),value=options;value.displayUnit=name;end
function value=merge(a,b),value=a;n=fieldnames(b);for i=1:numel(n),value.(n{i})=b.(n{i});end,end
function value=relative(a,b),value=abs(a-b)/max([abs(a) abs(b) 1e-12]);end
