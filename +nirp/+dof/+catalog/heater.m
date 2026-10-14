function model = heater(context)
%HEATER Degree-of-freedom catalogue for a Heater/Cooler.
%   CONTEXT may contain an SI inlet stream and ReactionSys. T_in and P_in
%   remain external; energy solvers delegate to nirp.units.heater.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    model=nirp.dof.model();positive=struct('bounds',[0 Inf],'boundsClosed',[false true]);
    external=struct('bounds',[0 Inf],'boundsClosed',[false true],'specifiable',false);
    model=nirp.dof.addVariable(model,'T_in','Inlet temperature','Temperature',unit(external,'K'));
    model=nirp.dof.addVariable(model,'P_in','Inlet pressure','Pressure',unit(external,'Pa'));
    model=nirp.dof.addVariable(model,'T_out','Outlet temperature','Temperature',unit(positive,'K'));
    model=nirp.dof.addVariable(model,'dT','Temperature change','TemperatureDifference',struct('displayUnit','K'));
    model=nirp.dof.addVariable(model,'Q','Heat duty','Power',struct('displayUnit','W'));
    model=nirp.dof.addVariable(model,'dP','Pressure drop','Pressure',struct('bounds',[0 Inf],'displayUnit','Pa'));
    model=nirp.dof.addVariable(model,'P_out','Outlet pressure','Pressure',unit(positive,'Pa'));
    model=nirp.dof.addRelation(model,'temperature_change',{'T_in','T_out','dT'}, ...
        struct('T_out',@(v)v.T_in+v.dT,'dT',@(v)v.T_out-v.T_in,'T_in',@(v)v.T_out-v.dT), ...
        @(v)relative(v.T_out,v.T_in+v.dT));
    energy=struct('Q',@(v)duty(context,v),'T_out',@(v)outletTemperature(context,v));
    model=nirp.dof.addRelation(model,'energy',{'T_in','T_out','P_in','P_out','Q'},energy, ...
        @(v)relative(v.Q,duty(context,v)));
    model=nirp.dof.addRelation(model,'pressure',{'P_in','dP','P_out'}, ...
        struct('P_out',@(v)v.P_in-v.dP,'dP',@(v)v.P_in-v.P_out,'P_in',@(v)v.P_out+v.dP), ...
        @(v)relative(v.P_out,v.P_in-v.dP));
end

function value=duty(context,v)
    [in,rs]=thermo(context,v);[~,info]=nirp.units.heater(struct('mode','Outlet T','Tout',v.T_out,'dP',v.P_in-v.P_out),in,rs);value=info.heatDuty;
end
function value=outletTemperature(context,v)
    [in,rs]=thermo(context,v);out=nirp.units.heater(struct('mode','Duty','Q',v.Q,'dP',v.P_in-v.P_out),in,rs);value=out.T;
end
function [in,rs]=thermo(context,v)
    if ~isstruct(context)||~isfield(context,'inlet')||isempty(context.inlet)||~isfield(context,'RS')||isempty(context.RS)
        error('nirp:dof:missingThermodynamics','Heater energy closure needs a known inlet and reaction system.');
    end
    in=context.inlet;in.T=v.T_in;in.P=v.P_in;rs=context.RS;
end
function value=unit(options,name),value=options;value.displayUnit=name;end
function value=relative(a,b),value=abs(a-b)/max([abs(a) abs(b) 1e-12]);end
