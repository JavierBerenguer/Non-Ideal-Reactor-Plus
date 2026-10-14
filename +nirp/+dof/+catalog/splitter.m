function model = splitter(nOutlets)
%SPLITTER Degree-of-freedom catalogue for an N-outlet material splitter.
%   Flows are mol/s and fractions are dimensionless.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    if ~(isnumeric(nOutlets)&&isscalar(nOutlets)&&nOutlets==fix(nOutlets)&&nOutlets>=2&&nOutlets<=20)
        error('nirp:dof:invalidOutletCount','A Splitter requires 2 to 20 outlets.') ;
    end
    model=nirp.dof.model(); fractionNames=cell(1,nOutlets) ;
    for i=1:nOutlets
        fractionNames{i}=sprintf('f%d',i) ;
        model=nirp.dof.addVariable(model,fractionNames{i},sprintf('Split fraction for outlet %d',i),'Fraction', ...
            struct('bounds',[0 1],'displayUnit','1')) ;
    end
    model=nirp.dof.addVariable(model,'F_in','Inlet molar flow','MolarFlow', ...
        struct('bounds',[0 Inf],'specifiable',false,'displayUnit','mol/s')) ;
    solvers=struct();
    for i=1:nOutlets
        name=fractionNames{i};others=fractionNames;others(i)=[];
        solvers.(name)=@(v) 1-sum(cellfun(@(x)v.(x),others));
    end
    model=nirp.dof.addRelation(model,'fraction_sum',fractionNames,solvers, ...
        @(v) abs(sum(cellfun(@(x)v.(x),fractionNames))-1)) ;
    for i=1:nOutlets
        f=fractionNames{i};out=sprintf('F_out%d',i) ;
        model=nirp.dof.addVariable(model,out,sprintf('Molar flow from outlet %d',i),'MolarFlow', ...
            struct('bounds',[0 Inf],'specifiable',false,'displayUnit','mol/s')) ;
        relationSolvers=struct();relationSolvers.(out)=@(v)v.(f)*v.F_in;
        relationSolvers.(f)=@(v)v.(out)/v.F_in;
        model=nirp.dof.addRelation(model,['outlet_' num2str(i)],{f,'F_in',out}, ...
            relationSolvers,@(v) abs(v.(out)-v.(f)*v.F_in)/max([abs(v.(out)) abs(v.(f)*v.F_in) 1e-12])) ;
    end
end
