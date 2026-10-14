function model = pfr(context)
%PFR Degree-of-freedom catalogue for a tubular plug-flow reactor.
%   Values are SI. Q0 is external. CONTEXT may select catalytic and add
%   independent pressure-correlation data for a nonconstant-pressure PFR.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    positive=struct('bounds',[0 Inf],'boundsClosed',[false true]) ;
    model=nirp.dof.model() ;
    definitions={'V','V','Volume','m^3';'L','L','Length','m';'D','D','Length','m'; ...
        'N_tubes','Number of tubes','Count','1';'tau','Residence time','Time','s'; ...
        'SV','Space velocity','Frequency','1/s';'u','Superficial velocity','Velocity','m/s'} ;
    for i=1:size(definitions,1)
        options=unit(positive,definitions{i,4});if strcmp(definitions{i,1},'N_tubes'),options.integer=true;end %#ok<STRNU>
        model=nirp.dof.addVariable(model,definitions{i,1},definitions{i,2},definitions{i,3},options) ;
    end
    model=nirp.dof.addVariable(model,'Q0','Inlet volumetric flow','VolumetricFlow', ...
        merge(unit(positive,'m^3/s'),struct('specifiable',false))) ;
    area=@(v)v.N_tubes*pi/4*v.D^2 ;
    model=nirp.dof.addRelation(model,'geometry',{'V','L','D','N_tubes'}, ...
        struct('V',@(v)area(v)*v.L,'L',@(v)v.V/area(v), ...
        'D',@(v)sqrt(4*v.V/(pi*v.N_tubes*v.L)), ...
        'N_tubes',@(v)4*v.V/(pi*v.D^2*v.L)),@(v)relative(v.V,area(v)*v.L)) ;
    model=nirp.dof.addRelation(model,'residence_time',{'V','tau','Q0'}, ...
        struct('V',@(v)v.tau*v.Q0,'tau',@(v)v.V/v.Q0,'Q0',@(v)v.V/v.tau), ...
        @(v)relative(v.V,v.tau*v.Q0)) ;
    model=nirp.dof.addRelation(model,'space_velocity',{'SV','tau'}, ...
        struct('SV',@(v)1/v.tau,'tau',@(v)1/v.SV),@(v)relative(v.SV*v.tau,1)) ;
    model=nirp.dof.addRelation(model,'superficial_velocity',{'u','Q0','D','N_tubes'}, ...
        struct('u',@(v)v.Q0/area(v),'Q0',@(v)v.u*area(v), ...
        'D',@(v)sqrt(4*v.Q0/(pi*v.N_tubes*v.u)), ...
        'N_tubes',@(v)4*v.Q0/(pi*v.D^2*v.u)),@(v)relative(v.u*area(v),v.Q0)) ;
    if option(context,'catalytic',false)
        model=nirp.dof.addVariable(model,'W','Catalyst mass','Mass',unit(positive,'kg')) ;
        model=nirp.dof.addVariable(model,'rho_cat','Catalyst density','Density',unit(positive,'kg/m^3')) ;
        model=nirp.dof.addVariable(model,'epsilon','Catalyst void fraction','Fraction',struct('bounds',[0 1],'boundsClosed',[true false],'displayUnit','1')) ;
        model=nirp.dof.addRelation(model,'catalyst_mass',{'W','rho_cat','epsilon','V'}, ...
            struct('W',@(v)v.rho_cat*(1-v.epsilon)*v.V,'rho_cat',@(v)v.W/((1-v.epsilon)*v.V), ...
            'epsilon',@(v)1-v.W/(v.rho_cat*v.V),'V',@(v)v.W/(v.rho_cat*(1-v.epsilon))), ...
            @(v)relative(v.W,v.rho_cat*(1-v.epsilon)*v.V)) ;
    end
    if strcmpi(char(string(option(context,'pressureMode','Constant'))),'Non constant')
        model=nirp.dof.addVariable(model,'viscosity','Viscosity','Viscosity',unit(positive,'Pa*s')) ;
        phase=char(string(option(context,'phase','L'))) ;
        if ~any(strcmpi(phase,{'G','Gas'}))
            model=nirp.dof.addVariable(model,'density','Density','Density',unit(positive,'kg/m^3')) ;
        end
        if strcmpi(char(string(option(context,'pressureDropEqn','Pipe'))),'Ergun')
            model=nirp.dof.addVariable(model,'particleDiameter','Particle diameter','Length',unit(positive,'m')) ;
        end
    end
end

function value=option(context,name,default),value=default;if isstruct(context)&&isfield(context,name),value=context.(name);end,end
function value=unit(options,name),value=options;value.displayUnit=name;end
function value=merge(a,b),value=a;n=fieldnames(b);for i=1:numel(n),value.(n{i})=b.(n{i});end,end
function value=relative(a,b),value=abs(a-b)/max([abs(a) abs(b) 1e-12]);end
