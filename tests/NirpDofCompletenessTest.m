classdef NirpDofCompletenessTest < matlab.unittest.TestCase
%NIRPDOFCOMPLETENESSTEST Rank-based catalogue completeness audit.
%   Specification sets are judged independently from nirp.dof.solve by a
%   finite-difference Jacobian of the catalogue relations at a coherent SI
%   reference state. Large combination spaces use 500 reproducible sets.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 15, 2026. Last update: October 15, 2026
% =========================================================================
    methods (Test)
        function determinateSetsCloseToReference(testCase)
            cases=catalogueCases();
            for k=1:numel(cases)
                item=cases(k);sets=specificationSets(item,500,k);determinate=0;closed=0;limitations=0;firstLimitation="";firstMessage="";
                for row=1:size(sets,1)
                    specs=item.Candidates(sets(row,:));
                    if ~isDeterminate(item,specs),continue,end
                    determinate=determinate+1;
                    result=solveSubset(item,specs);
                    diagnostic=sprintf('%s: %s',item.Name,strjoin(specs,', '));
                    if strcmp(result.status,'missing')
                        limitations=limitations+1;
                        if strlength(firstLimitation)==0,firstLimitation=strjoin(specs,', ');firstMessage=result.messages(end);end
                        testCase.verifyGreaterThan(result.missingCount,0,diagnostic);
                        testCase.verifySubstring(result.messages(end),'specification',diagnostic);
                        continue
                    end
                    testCase.verifyEqual(result.status,'complete',diagnostic);
                    if ~strcmp(result.status,'complete'),continue,end
                    closed=closed+1;
                    for name=item.AuditNames
                        actual=result.values.(name);expected=item.Reference.(name);
                        testCase.verifyEqual(actual,expected,'RelTol',1e-9, ...
                            'AbsTol',1e-11,diagnostic);
                    end
                end
                fprintf('[DOF AUDIT] %s sampled=%d determinate=%d closed=%d limitations=%d\n', ...
                    item.Name,size(sets,1),determinate,closed,limitations);
                if limitations>0,fprintf('[DOF LIMITATION] %s specs={%s} message="%s"\n',item.Name,firstLimitation,firstMessage);end
            end
        end

        function underdeterminedSetsStayMissing(testCase)
            cases=catalogueCases();
            for k=1:numel(cases)
                item=cases(k);if item.SpecCount<1,continue,end
                count=min(item.SpecCount-1,numel(item.Candidates));
                result=solveSubset(item,item.Candidates(1:count));
                testCase.verifyEqual(result.status,'missing',item.Name);
                testCase.verifyGreaterThanOrEqual(result.missingCount,1,item.Name);
            end
        end

        function incompatibleAndExcessSpecificationsConflict(testCase)
            cases=catalogueCases();
            for index=[1 9 11 12 14]
                item=cases(index);names=item.Candidates;
                result=solveSubset(item,names);
                if numel(names)>item.SpecCount
                    testCase.verifyEqual(result.status,'conflict',item.Name);
                end
            end
            item=cases(1);specs=["x1" "x2" "Q" "T" "P"];
            values=item.Reference;values.x2=values.x2+0.1;
            result=solveSubset(item,specs,values);
            testCase.verifyEqual(result.status,'conflict');
        end
    end
end

function cases=catalogueCases()
    cases=repmat(emptyCase(),0,1);
    for phase=["L" "G"]
        for n=[2 3]
            cases(end+1)=feedCase(phase,n,false); %#ok<AGROW>
            cases(end+1)=feedCase(phase,n,true); %#ok<AGROW>
        end
    end
    cases(end+1)=splitterCase(2);
    cases(end+1)=splitterCase(3);
    cases(end+1)=separatorCase(2);
    cases(end+1)=reactorCase('CSTR',false);
    cases(end+1)=reactorCase('CSTR',true);
    cases(end+1)=reactorCase('PFR',false);
    cases(end+1)=reactorCase('PFR',true);
    cases(end+1)=heaterCase();
    cases(end+1)=jacketCase(false);
    cases(end+1)=jacketCase(true);
    cases(end+1)=simpleCase('Jacket specified T', ...
        nirp.dof.catalog.jacket(struct('mode','Specified T')),struct('T_reactor',350),strings(0,1));
    cases(end+1)=simpleCase('Jacket specified Q', ...
        nirp.dof.catalog.jacket(struct('mode','Specified Q')),struct('Q',-1e5),strings(0,1));
end

function item=feedCase(phase,n,withMw)
    context=struct('nComponents',n,'phase',char(phase));
    if withMw,context.Mw=18+(0:n-1)*10;end
    model=nirp.dof.catalog.feed(context);f=1:n;reference=struct();
    reference.F=sum(f);reference.T=350;reference.P=2e5;
    if phase=="G",reference.Q=reference.F*8.314*reference.T/reference.P;else,reference.Q=0.01;end
    reference.C_tot=reference.F/reference.Q;
    for i=1:n
        reference.(['F' num2str(i)])=f(i);reference.(['C' num2str(i)])=f(i)/reference.Q;
        reference.(['x' num2str(i)])=f(i)/reference.F;
    end
    if withMw
        mass=f.*context.Mw*1e-3;reference.mdot=sum(mass);
        for i=1:n,reference.(['mdot' num2str(i)])=mass(i);reference.(['w' num2str(i)])=mass(i)/reference.mdot;end
    end
    item=finishCase(sprintf('Feed %s n=%d Mw=%d',phase,n,withMw),model,reference,strings(0,1));
end

function item=splitterCase(n)
    model=nirp.dof.catalog.splitter(n);reference=struct('F_in',10);fractions=(1:n);fractions=fractions/sum(fractions);
    for i=1:n,reference.(['f' num2str(i)])=fractions(i);reference.(['F_out' num2str(i)])=10*fractions(i);end
    item=finishCase(sprintf('Splitter n=%d',n),model,reference,"F_in");
end

function item=separatorCase(n)
    model=nirp.dof.catalog.separator(n);reference=struct();fin=2:1+n;recovery=linspace(0.25,0.65,n);
    top=fin.*recovery;bottom=fin-top;
    for i=1:n
        reference.(['F_in' num2str(i)])=fin(i);reference.(['r' num2str(i)])=recovery(i);
        reference.(['F_top' num2str(i)])=top(i);reference.(['F_bot' num2str(i)])=bottom(i);
        reference.(['x_top' num2str(i)])=top(i)/sum(top);reference.(['x_bot' num2str(i)])=bottom(i)/sum(bottom);
    end
    item=finishCase(sprintf('Separator n=%d',n),model,reference,"F_in"+(1:n));
end

function item=reactorCase(type,catalytic)
    context=struct('catalytic',catalytic);q=0.03;
    if strcmp(type,'CSTR')
        model=nirp.dof.catalog.cstr(context);reference=struct('V',0.6,'tau',20,'SV',0.05,'Q0',q);
    else
        context.pressureMode='Constant';model=nirp.dof.catalog.pfr(context);d=0.2;nt=3;l=2;
        v=nt*pi/4*d^2*l;reference=struct('V',v,'L',l,'D',d,'N_tubes',nt, ...
            'tau',v/q,'SV',q/v,'u',q/(nt*pi/4*d^2),'Q0',q);
    end
    if catalytic,reference.rho_cat=1000;reference.epsilon=0.2;reference.W=reference.rho_cat*(1-reference.epsilon)*reference.V;end
    item=finishCase(sprintf('%s catalytic=%d',type,catalytic),model,reference,"Q0");
end

function item=heaterCase()
    package=nirp.pkg.examples.firstOrderLiquid();inlet=nirp.pkg.feedStream(package,"F1");rs=nirp.pkg.toReactionSys(package);
    model=nirp.dof.catalog.heater(struct('inlet',inlet,'RS',rs));values=struct('T_in',inlet.T,'P_in',inlet.P,'T_out',inlet.T+20,'dP',1000);
    origins=struct('T_in','external','P_in','external','T_out','specified','dP','specified');
    solved=nirp.dof.solve(model,values,origins);
    item=finishCase('Heater',model,solved.values,["T_in" "P_in"]);
end

function item=jacketCase(condenses)
    model=nirp.dof.catalog.jacket(struct('mode','Utility','condenses',condenses));
    reference=struct('U',200,'A',5,'UA',1000,'T_in_s',300,'T_out_s',320, ...
        'Cp_s',4000,'lambda',2e6,'Q',-8e4);
    if condenses,reference.mdot_s=abs(reference.Q)/reference.lambda;else,reference.mdot_s=abs(reference.Q)/(reference.Cp_s*20);end
    item=finishCase(sprintf('Jacket utility condenses=%d',condenses),model,reference,"Q");
    item.Candidates=["U" "A" "UA" "T_in_s"];
    item.AuditNames=item.Candidates;
    item.SpecCount=3;
end

function item=simpleCase(name,model,reference,external)
    item=finishCase(name,model,reference,external);
end

function item=finishCase(name,model,reference,external)
    variables=string({model.variables.name});specifiable=[model.variables.specifiable];optional=[model.variables.optional];
    item=emptyCase();item.Name=name;item.Model=model;item.Reference=reference;item.External=string(external(:))';
    item.Candidates=variables(specifiable&~optional);item.AuditNames=variables(~optional);
    item.SpecCount=numel(variables)-sum(~[model.relations.redundant])-numel(item.External)-sum(optional);
end

function item=emptyCase()
    item=struct('Name','','Model',[],'Reference',struct(),'External',strings(1,0), ...
        'Candidates',strings(1,0),'AuditNames',strings(1,0),'SpecCount',0);
end

function sets=specificationSets(item,limit,seed)
    n=numel(item.Candidates);k=item.SpecCount;if k==0,sets=zeros(1,0);return,end
    total=nchoosekCount(n,k);
    if total<=limit,sets=nchoosek(1:n,k);return,end
    previous=rng;rng(15000+seed,'twister');cleaner=onCleanup(@()rng(previous)); %#ok<NASGU>
    keys=strings(0,1);sets=zeros(0,k);
    while size(sets,1)<limit
        candidate=sort(randperm(n,k));key=strjoin(string(candidate),',');
        if ~any(keys==key),sets(end+1,:)=candidate;keys(end+1)=key;end %#ok<AGROW>
    end
end

function value=nchoosekCount(n,k)
    value=round(exp(gammaln(n+1)-gammaln(k+1)-gammaln(n-k+1)));
end

function result=solveSubset(item,specs,values)
    if nargin<3,values=item.Reference;end
    input=struct();origins=struct();
    for name=item.External,input.(name)=values.(name);origins.(name)='external';end
    for name=string(specs),input.(name)=values.(name);origins.(name)='specified';end
    result=nirp.dof.solve(item.Model,input,origins);
end

function flag=isDeterminate(item,specs)
    unknown=setdiff(item.AuditNames,[string(specs) item.External],'stable');
    if isempty(unknown),flag=true;return,end
    relations=item.Model.relations(~[item.Model.relations.redundant]);
    base=residualVector(relations,item.Reference);jacobian=zeros(numel(base),numel(unknown));
    for column=1:numel(unknown)
        changed=item.Reference;name=unknown(column);step=1e-6*max(abs(changed.(name)),1);
        changed.(name)=changed.(name)+step;jacobian(:,column)=residualVector(relations,changed)-base;
    end
    flag=rank(jacobian,1e-8)==numel(unknown);
end

function values=residualVector(relations,state)
    values=zeros(numel(relations),1);
    for i=1:numel(relations)
        try,values(i)=relations(i).residual(state);catch,values(i)=NaN;end
    end
    values(~isfinite(values))=0;
end
