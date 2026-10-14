function model = feed(context)
%FEED Degree-of-freedom catalogue for a material feed stream.
%   CONTEXT supplies nComponents (or components), phase ('L'/'G'), and
%   optional molecular weights Mw in g/mol. All catalogue values are SI:
%   mol/s, mol/m^3, kg/s, m^3/s, K, and Pa.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    [n,mw,gas]=contextData(context) ;
    model=nirp.dof.model() ;
    positive=struct('bounds',[0 Inf],'boundsClosed',[false true]) ;
    nonnegative=struct('bounds',[0 Inf]) ;
    fraction=struct('bounds',[0 1],'displayUnit','1') ;
    for i=1:n
        model=nirp.dof.addVariable(model,name('F',i),sprintf('F_%d',i), ...
            'MolarFlow',withUnit(nonnegative,'mol/s')) ;
        model=nirp.dof.addVariable(model,name('C',i),sprintf('C_%d',i), ...
            'Concentration',withUnit(nonnegative,'mol/m^3')) ;
        model=nirp.dof.addVariable(model,name('x',i),sprintf('x_%d',i), ...
            'Fraction',fraction) ;
        if ~isempty(mw)
            model=nirp.dof.addVariable(model,name('mdot',i),sprintf('mass flow %d',i), ...
                'MassFlow',withUnit(nonnegative,'kg/s')) ;
            model=nirp.dof.addVariable(model,name('w',i),sprintf('mass fraction %d',i), ...
                'Fraction',fraction) ;
        end
    end
    model=nirp.dof.addVariable(model,'F','Total molar flow','MolarFlow',withUnit(positive,'mol/s')) ;
    model=nirp.dof.addVariable(model,'C_tot','Total concentration','Concentration',withUnit(positive,'mol/m^3')) ;
    if ~isempty(mw)
        model=nirp.dof.addVariable(model,'mdot','Total mass flow','MassFlow',withUnit(positive,'kg/s')) ;
    end
    model=nirp.dof.addVariable(model,'Q','Volumetric flow','VolumetricFlow',withUnit(positive,'m^3/s')) ;
    model=nirp.dof.addVariable(model,'T','Temperature','Temperature',withUnit(positive,'K')) ;
    model=nirp.dof.addVariable(model,'P','Pressure','Pressure',withUnit(positive,'Pa')) ;

    for i=1:n
        f=name('F',i);c=name('C',i);x=name('x',i) ;
        solvers=struct();solvers.(f)=@(v)v.(c)*v.Q;solvers.(c)=@(v)v.(f)/v.Q;solvers.Q=@(v)v.(f)/v.(c);
        model=nirp.dof.addRelation(model,['concentration_' num2str(i)],{f,c,'Q'},solvers, ...
            @(v) relative(v.(f),v.(c)*v.Q)) ;
        solvers=struct();solvers.(f)=@(v)v.(x)*v.F;solvers.(x)=@(v)v.(f)/v.F;solvers.F=@(v)v.(f)/v.(x);
        model=nirp.dof.addRelation(model,['mole_fraction_' num2str(i)],{f,x,'F'},solvers, ...
            @(v) relative(v.(f),v.(x)*v.F)) ;
        if ~isempty(mw)
            m=name('mdot',i);w=name('w',i);factor=mw(i)*1e-3 ;
            solvers=struct();solvers.(m)=@(v)v.(f)*factor;solvers.(f)=@(v)v.(m)/factor;
            model=nirp.dof.addRelation(model,['molecular_weight_' num2str(i)],{f,m},solvers, ...
                @(v) relative(v.(m),v.(f)*factor)) ;
            solvers=struct();solvers.(m)=@(v)v.(w)*v.mdot;solvers.(w)=@(v)v.(m)/v.mdot;solvers.mdot=@(v)v.(m)/v.(w);
            model=nirp.dof.addRelation(model,['mass_fraction_' num2str(i)],{m,w,'mdot'},solvers, ...
                @(v) relative(v.(m),v.(w)*v.mdot)) ;
        end
    end
    fNames=arrayfun(@(i)name('F',i),1:n,'UniformOutput',false) ;
    model=nirp.dof.addRelation(model,'total_molar_flow',[fNames {'F'}], ...
        sumSolvers(fNames,'F'),@(v) relative(v.F,sumFields(v,fNames))) ;
    model=nirp.dof.addRelation(model,'total_concentration',{'C_tot','F','Q'}, ...
        struct('C_tot',@(v)v.F/v.Q,'F',@(v)v.C_tot*v.Q,'Q',@(v)v.F/v.C_tot), ...
        @(v) relative(v.C_tot,v.F/v.Q)) ;
    if ~isempty(mw)
        mNames=arrayfun(@(i)name('mdot',i),1:n,'UniformOutput',false) ;
        model=nirp.dof.addRelation(model,'total_mass_flow',[mNames {'mdot'}], ...
            sumSolvers(mNames,'mdot'),@(v) relative(v.mdot,sumFields(v,mNames))) ;
    end
    if gas
        gasSolvers=struct('Q',@(v)v.F*8.314*v.T/v.P, ...
            'F',@(v)v.Q*v.P/(8.314*v.T),'T',@(v)v.Q*v.P/(8.314*v.F), ...
            'P',@(v)v.F*8.314*v.T/v.Q) ;
        model=nirp.dof.addRelation(model,'ideal_gas',{'Q','F','T','P'},gasSolvers, ...
            @(v) relative(v.Q,v.F*8.314*v.T/v.P)) ;
    end
end

function [n,mw,gas]=contextData(context)
    if isnumeric(context),n=context;mw=[];gas=false;return,end
    if ~isstruct(context)||~isscalar(context),error('nirp:dof:invalidContext','Feed context must be a scalar structure.');end
    if isfield(context,'nComponents'),n=context.nComponents;
    elseif isfield(context,'components'),n=numel(context.components);
    elseif isfield(context,'Mw'),n=numel(context.Mw);
    else,error('nirp:dof:invalidContext','Feed context needs nComponents, components, or Mw.');end
    mw=[] ;
    if isfield(context,'Mw'),candidate=context.Mw;
    elseif isfield(context,'components')&&isfield(context.components,'Mw'),candidate={context.components.Mw};
    else,candidate=[];end
    if iscell(candidate)
        if all(cellfun(@(x)isnumeric(x)&&isscalar(x)&&isfinite(x)&&x>0,candidate)),mw=cellfun(@double,candidate);end
    elseif isnumeric(candidate)&&numel(candidate)==n&&all(isfinite(candidate))&&all(candidate>0),mw=double(candidate(:)');end
    phase='L';if isfield(context,'phase'),phase=context.phase;end
    gas=(isnumeric(phase)&&isscalar(phase)&&phase==1)||strcmpi(char(string(phase)),'G')||strcmpi(char(string(phase)),'Gas') ;
    if ~(isnumeric(n)&&isscalar(n)&&isfinite(n)&&n==fix(n)&&n>=1),error('nirp:dof:invalidContext','nComponents must be a positive integer.');end
end
function output=withUnit(options,unit),output=options;output.displayUnit=unit;end
function output=name(prefix,index),output=[prefix num2str(index)];end
function solvers=sumSolvers(parts,total)
    all=[parts {total}];solvers=struct();
    solvers.(total)=@(v)sumFields(v,parts);
    for i=1:numel(parts),target=parts{i};others=parts;others(i)=[];solvers.(target)=@(v)v.(total)-sumFields(v,others);end
end
function value=sumFields(values,names),value=sum(cellfun(@(x)values.(x),names));end
function value=relative(first,second),value=abs(first-second)/max([abs(first) abs(second) 1e-12]);end
