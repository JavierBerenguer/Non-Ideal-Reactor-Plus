function model = separator(context)
%SEPARATOR Degree-of-freedom catalogue for a two-outlet separator.
%   Component flows are mol/s; recoveries and mole fractions are unitless.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================

    [n,names]=componentData(context);model=nirp.dof.model();flows=struct('bounds',[0 Inf],'displayUnit','mol/s');fractions=struct('bounds',[0 1],'displayUnit','1');
    for i=1:n
        model=nirp.dof.addVariable(model,nm('r',i),sprintf('Recovery of %s',names{i}),'Fraction',fractions);
        model=nirp.dof.addVariable(model,nm('F_top',i),sprintf('Top molar flow of %s',names{i}),'MolarFlow',flows);
        model=nirp.dof.addVariable(model,nm('F_bot',i),sprintf('Bottom molar flow of %s',names{i}),'MolarFlow',flows);
        model=nirp.dof.addVariable(model,nm('x_top',i),sprintf('Top mole fraction of %s',names{i}),'Fraction',fractions);
        model=nirp.dof.addVariable(model,nm('x_bot',i),sprintf('Bottom mole fraction of %s',names{i}),'Fraction',fractions);
        model=nirp.dof.addVariable(model,nm('F_in',i),sprintf('Inlet molar flow of %s',names{i}),'MolarFlow',struct('bounds',[0 Inf],'specifiable',false,'displayUnit','mol/s'));
    end
    top=arrayfun(@(i)nm('F_top',i),1:n,'UniformOutput',false);bot=arrayfun(@(i)nm('F_bot',i),1:n,'UniformOutput',false);
    for i=1:n
        r=nm('r',i);ft=top{i};fb=bot{i};fi=nm('F_in',i);xt=nm('x_top',i);xb=nm('x_bot',i);
        s=struct();s.(ft)=@(v)v.(r)*v.(fi);s.(r)=@(v)ratio(v.(ft),v.(fi));s.(fi)=@(v)ratio(v.(ft),v.(r));
        model=nirp.dof.addRelation(model,['top_recovery_' num2str(i)],{r,fi,ft},s,@(v)rel(v.(ft),v.(r)*v.(fi)));
        s=struct();s.(fb)=@(v)v.(fi)-v.(ft);s.(fi)=@(v)v.(fb)+v.(ft);s.(ft)=@(v)v.(fi)-v.(fb);
        model=nirp.dof.addRelation(model,['component_balance_' num2str(i)],{fi,ft,fb},s,@(v)rel(v.(fi),v.(ft)+v.(fb)));
        topVars=[{xt ft} top];topVars=unique(topVars,'stable');
        s=struct();s.(xt)=@(v)ratio(v.(ft),sumFields(v,top));s.(ft)=@(v)ratio(v.(xt)*sumOtherWithTarget(v,top,ft),1-v.(xt));
        model=nirp.dof.addRelation(model,['top_fraction_' num2str(i)],topVars,s,@(v)rel(v.(ft),v.(xt)*sumFields(v,top)));
        botVars=[{xb fb} bot];botVars=unique(botVars,'stable');
        s=struct();s.(xb)=@(v)ratio(v.(fb),sumFields(v,bot));s.(fb)=@(v)ratio(v.(xb)*sumOtherWithTarget(v,bot,fb),1-v.(xb));
        model=nirp.dof.addRelation(model,['bottom_fraction_' num2str(i)],botVars,s,@(v)rel(v.(fb),v.(xb)*sumFields(v,bot)));
    end
end
function [n,names]=componentData(context)
    if isnumeric(context),n=context;elseif isstruct(context)&&isfield(context,'nComponents'),n=context.nComponents;elseif isstruct(context)&&isfield(context,'components'),n=numel(context.components);else,error('nirp:dof:invalidContext','Separator context needs nComponents or components.');end
    if ~(isnumeric(n)&&isscalar(n)&&isfinite(n)&&n==fix(n)&&n>=1),error('nirp:dof:invalidContext','nComponents must be a positive integer.');end
    names=arrayfun(@(i)sprintf('component %d',i),1:n,'UniformOutput',false);
    if isstruct(context)&&isfield(context,'components')&&isfield(context.components,'name'),candidate=cellstr(string({context.components.name}));if numel(candidate)==n,names=candidate;end,end
end
function output=nm(prefix,index),output=[prefix num2str(index)];end
function value=sumFields(values,names),value=sum(cellfun(@(x)values.(x),names));end
function value=sumOtherWithTarget(values,names,target),other=names;other(strcmp(other,target))=[];value=sumFields(values,other);end
function value=rel(a,b),value=abs(a-b)/max([abs(a) abs(b) 1e-12]);end
function value=ratio(numerator,denominator),if denominator==0&&numerator==0,value=0;else,value=numerator/denominator;end,end
