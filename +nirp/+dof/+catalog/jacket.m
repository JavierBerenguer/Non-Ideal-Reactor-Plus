function model = jacket(context)
%JACKET Degree-of-freedom catalogue for the selected Jacket mode.
%   Utility values use SI. Q is an external result supplied by the last
%   connected-reactor calculation; service mass flow is result-only.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    mode=char(string(option(context,'mode','Utility')));model=nirp.dof.model();
    positive=struct('bounds',[0 Inf],'boundsClosed',[false true]);
    if strcmp(mode,'Specified T')
        model=nirp.dof.addVariable(model,'T_reactor','Reactor temperature','Temperature',unit(positive,'K'));return
    elseif strcmp(mode,'Specified Q')
        model=nirp.dof.addVariable(model,'Q','Heat duty','Power',struct('displayUnit','W'));return
    elseif ~strcmp(mode,'Utility')
        error('nirp:dof:invalidContext','Unknown Jacket mode "%s".',mode);
    end
    model=nirp.dof.addVariable(model,'U','Heat-transfer coefficient','HeatTransferCoefficient',unit(struct('bounds',[0 Inf]),'W/(m^2*K)'));
    model=nirp.dof.addVariable(model,'A','Area','Area',unit(positive,'m^2'));
    model=nirp.dof.addVariable(model,'UA','Conductance','Conductance',unit(positive,'W/K'));
    model=nirp.dof.addVariable(model,'T_in_s','Utility inlet temperature','Temperature',unit(positive,'K'));
    optional=struct('optional',true);
    model=nirp.dof.addVariable(model,'T_out_s','Utility outlet temperature','Temperature',unit(merge(optional,positive),'K'));
    model=nirp.dof.addVariable(model,'Cp_s','Utility heat capacity','HeatCapacity',unit(merge(optional,positive),'J/(kg*K)'));
    model=nirp.dof.addVariable(model,'lambda','Utility latent heat','SpecificEnergy',unit(merge(optional,positive),'J/kg'));
    model=nirp.dof.addVariable(model,'mdot_s','Utility mass flow','MassFlow',merge(unit(positive,'kg/s'),struct('specifiable',false)));
    model=nirp.dof.addVariable(model,'Q','Reactor heat duty','Power',struct('specifiable',false,'displayUnit','W'));
    model=nirp.dof.addRelation(model,'conductance',{'UA','U','A'}, ...
        struct('UA',@(v)v.U*v.A,'U',@(v)v.UA/v.A,'A',@(v)v.UA/v.U),@(v)relative(v.UA,v.U*v.A));
    if option(context,'condenses',false)
        model=nirp.dof.addRelation(model,'service_flow',{'mdot_s','Q','lambda'}, ...
            struct('mdot_s',@(v)abs(v.Q)/v.lambda,'Q',@(v)signOrOne(v.Q)*v.mdot_s*v.lambda, ...
            'lambda',@(v)abs(v.Q)/v.mdot_s),@(v)relative(v.mdot_s,abs(v.Q)/v.lambda));
    else
        model=nirp.dof.addRelation(model,'service_flow',{'mdot_s','Q','Cp_s','T_in_s','T_out_s'}, ...
            struct('mdot_s',@(v)abs(v.Q)/(v.Cp_s*abs(v.T_in_s-v.T_out_s)), ...
            'Cp_s',@(v)abs(v.Q)/(v.mdot_s*abs(v.T_in_s-v.T_out_s))), ...
            @(v)relative(v.mdot_s,abs(v.Q)/(v.Cp_s*abs(v.T_in_s-v.T_out_s))));
    end
end

function value=option(context,name,default),value=default;if isstruct(context)&&isfield(context,name),value=context.(name);end,end
function value=unit(options,name),value=options;value.displayUnit=name;end
function value=merge(a,b),value=a;n=fieldnames(b);for i=1:numel(n),value.(n{i})=b.(n{i});end,end
function value=relative(a,b),value=abs(a-b)/max([abs(a) abs(b) 1e-12]);end
function value=signOrOne(value),value=sign(value);if value==0,value=1;end,end
