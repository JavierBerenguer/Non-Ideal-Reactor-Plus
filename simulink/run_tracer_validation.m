function [validation,reactiveValidation] = run_tracer_validation(folder)
%RUN_TRACER_VALIDATION Validate tracer and reactive flowsheet examples.
%   VALIDATION retains the original three-row tracer validation table.
%   REACTIVEVALIDATION compares C_A and X_A for each micromixing model with
%   independent analytical or fine-quadrature references. Relative errors
%   must not exceed 0.4% for the original examples. The five-species exam
%   uses 0.5%, which covers its common-grid RTD quadrature.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: November 2, 2026
% =========================================================================
    root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fileparts(mfilename('fullpath')));
    owned=false;if nargin<1||isempty(folder),folder=tempname;mkdir(folder);owned=true;end
    cleanup=onCleanup(@()restore(folder,owned));files=build_tracer_examples(folder); %#ok<NASGU>
    names=nirp.tracerflowsheet.exampleNames();tracerNames=names(1:3);labels=["N = 2 analytical";"Flow-weighted parallel sum";"Former SEC01 exercise"];
    maxAbsError=zeros(3,1);tau=zeros(3,1);sigma2=zeros(3,1);
    for k=1:3
        result=simulateOne(folder,tracerNames(k));grid=result.grid;actual=result.stream.E;
        switch k
            case 1
                expected=nirp.tracer.rtdModel(grid,'tanks',struct('tau',4,'N',2),1);
            case 2
                pfr=nirp.tracer.rtdModel(grid,'pfr',struct('tau',3),1);
                cstr=nirp.tracer.rtdModel(grid,'cstr',struct('tau',3),1);expected=.25*pfr+.75*cstr;
            case 3
                e1=zeros(size(grid.t));selected=grid.t>=2&grid.t<=5;e1(selected)=(grid.t(selected)-2)/18;
                selected=grid.t>5&grid.t<=8;e1(selected)=1/6;selected=grid.t>8&grid.t<=11;e1(selected)=(11-grid.t(selected))/18;
                e2=exp(-grid.t/2)/2;reference=nirp.conv.series(nirp.conv.signal(grid.t,e1),nirp.conv.signal(grid.t,e2));
                expected=reference.C(1:grid.length);expected=expected/(grid.dt*sum(expected));
        end
        maxAbsError(k)=max(abs(actual-expected));mom=nirp.tracer.moments(grid,actual);tau(k)=mom.tau;sigma2(k)=mom.sigma2;
        assert(maxAbsError(k)<=5e-3,'nirp:tracerflowsheet:ValidationMismatch','Tracer example %s differs from its reference.',tracerNames(k));
    end
    validation=table(tracerNames,labels,maxAbsError,tau,sigma2,'VariableNames', ...
        {'names','labels','maxAbsError','tau','sigma2'});
    reactiveValidation=validateReactive(folder,names(4:6));
    reactiveValidation.officialValue=nan(height(reactiveValidation),1);
    reactiveValidation=[reactiveValidation;validateExamJan2024(folder,names(7))];
end

function validation=validateReactive(folder,names)
C0=10;tauSeries=2;tauParallel=3;kFirst=0.4;kSecond=0.05;
firstReference=C0/(1+kFirst*tauSeries)^2;
secondMm1=cstrSecondOrder(C0,kSecond,tauSeries);secondMm2=cstrSecondOrder(secondMm1,kSecond,tauSeries);
secondSeg1=segregatedCstr(C0,kSecond,tauSeries);secondSeg2=segregatedCstr(secondSeg1,kSecond,tauSeries);
pfr=C0/(1+kSecond*tauParallel*C0);cstrMm=cstrSecondOrder(C0,kSecond,tauParallel);
cstrSeg=segregatedCstr(C0,kSecond,tauParallel);
references=[firstReference firstReference;secondSeg2 secondMm2; ...
    0.25*pfr+0.75*cstrSeg 0.25*pfr+0.75*cstrMm];
example=repelem(names,4);magnitude=repmat(["C_A";"X_A";"C_A";"X_A"],3,1);
micromixing=repmat(["Segregation";"Segregation";"Max mixedness";"Max mixedness"],3,1);
diagramValue=zeros(12,1);referenceValue=zeros(12,1);
for k=1:3
    result=simulateOne(folder,names(k));reaction=result.reaction;
    assert(~isempty(reaction),'nirp:tracerflowsheet:MissingReactiveResult', ...
        'Reactive example %s did not publish reaction results.',names(k));
    actual=[reaction.Cseg(1);reaction.Xseg;reaction.Cmm(1);reaction.Xmm];
    refC=references(k,:);expected=[refC(1);1-refC(1)/C0;refC(2);1-refC(2)/C0];
    rows=(k-1)*4+(1:4);diagramValue(rows)=actual;referenceValue(rows)=expected;
    if k>1
        assert(reaction.validity.guaranteed&&reaction.Xseg>reaction.Xmm, ...
            'nirp:tracerflowsheet:InvalidReactiveBounds', ...
            'Second-order example %s must report guaranteed ordered bounds.',names(k));
    end
end
absoluteError=abs(diagramValue-referenceValue);
relativeError=absoluteError./max(abs(referenceValue),eps);
tolerance=4e-3*ones(size(relativeError));
assert(all(relativeError<=tolerance),'nirp:tracerflowsheet:ReactiveValidationMismatch', ...
    'A reactive example differs from its independent reference by more than 0.4%%.');
validation=table(example,magnitude,micromixing,diagramValue,referenceValue, ...
    absoluteError,relativeError,tolerance);
end

function validation=validateExamJan2024(folder,name)
% Independent calculation ported from exam24_ref.m; no nirp core is used.
reference=examJan2024Reference();
result=simulateOne(folder,name);reaction=result.reaction;
assert(~isempty(reaction),'nirp:tracerflowsheet:MissingReactiveResult', ...
    'Reactive example %s did not publish reaction results.',name);
diagram=[reaction.Cseg(:);reaction.Cmm(:)]/1000;
referenceValue=[reference(2,:)';reference(4,:)'];
officialValue=[0.0688;0.0533;0.112;0.287;0.287; ...
    0.0458;0.0389;0.181;0.244;0.244];
absoluteError=abs(diagram-referenceValue);
relativeError=absoluteError./max(abs(referenceValue),eps);
tolerance=5e-3*ones(10,1);
assert(all(relativeError<=tolerance),'nirp:tracerflowsheet:ExamValidationMismatch', ...
    'Exam Jan 2024 differs from its independent reference by more than 0.5%%.');
assert(~reaction.validity.guaranteed && contains(reaction.warning,'Bounds not guaranteed'), ...
    'nirp:tracerflowsheet:MissingBoundWarning', ...
    'Exam Jan 2024 must report that bounds are not guaranteed.');
example=repmat(name,10,1);
magnitude=repmat(["C_A";"C_B";"C_C";"C_D";"C_E"],2,1);
micromixing=[repmat("Segregation",5,1);repmat("Max mixedness",5,1)];
validation=table(example,magnitude,micromixing,diagram,referenceValue, ...
    absoluteError,relativeError,tolerance,officialValue, ...
    'VariableNames',{'example','magnitude','micromixing','diagramValue', ...
    'referenceValue','absoluteError','relativeError','tolerance','officialValue'});
end

function reference=examJan2024Reference()
% Rows are R1 segregation, R2 segregation, R1 maximum mixedness and R2.
options=odeset('RelTol',1e-11,'AbsTol',1e-13);
rhs=@examRates;
c1s=examSegregation([1 0 0 0 0],1,1,rhs,options);
c2s=examSegregation(c1s,100,2,rhs,options);
c1m=fsolve(@(c)[1 0 0 0 0]-c+rhs(c)',[0.2 0.07 0.07 0.3 0.3], ...
    optimoptions('fsolve','Display','off','FunctionTolerance',1e-14, ...
    'StepTolerance',1e-14));
c2m=examMaximumMixedness(c1m,100,2,rhs,options);
reference=[c1s;c2s;c1m;c2m];
end

function c=examSegregation(c0,n,tau,rhs,options)
tMax=tau*(1+12/sqrt(n))*1.5+30*(n==1);
solution=ode15s(@(~,c)rhs(c),[0 tMax],c0,options);
t=linspace(0,tMax,200001)';C=deval(solution,t)';
tauTank=tau/n;
if n>20
    E=exp((n-1)*log(max(t,realmin))-t/tauTank-n*log(tauTank)-gammaln(n));
else
    E=t.^(n-1).*exp(-t/tauTank)/(tauTank^n*factorial(n-1));
end
c=trapz(t,C.*E);
end

function c=examMaximumMixedness(c0,n,tau,rhs,options)
tauTank=tau/n;lambdaMax=tau*(1+12/sqrt(n))*1.5;
lambda=@(value)exp((n-1)*log(max(value,realmin))-value/tauTank- ...
    n*log(tauTank)-gammaln(n))./max(gammainc(value/tauTank,n,'upper'),realmin);
ode=@(value,c)-rhs(c)+lambda(value)*(c(:)-c0(:));
[~,profile]=ode15s(ode,[lambdaMax 0],c0(:),options);
c=profile(end,:);
end

function rate=examRates(c)
A=c(1);B=c(2);D=c(4);E=c(5);
r1=A-2*B;r2=B;r3=10*A^2;r4=D*E;
rate=[-r1-2*r3,r1-r2+r4,r2,r3-r4,r3-r4]';
end

function C=cstrSecondOrder(Cin,k,tau)
C=(-1+sqrt(1+4*k*tau*Cin))/(2*k*tau);
end

function C=segregatedCstr(Cin,k,tau)
% Fine deterministic quadrature of E(t)*C_batch(t), independent of the core.
t=0:0.001:100*tau;E=exp(-t/tau)/tau;batch=Cin./(1+k*Cin*t);
C=trapz(t,E.*batch)/trapz(t,E);
end
function result=simulateOne(folder,name)
evalin('base','clear nirpTracerResults');file=fullfile(folder,[char(name) '.slx']);load_system(file);sim(char(name));all=evalin('base','nirpTracerResults');key=matlab.lang.makeValidName([char(name) '_Monitor']);result=all.(key);close_system(char(name),0);Simulink.data.dictionary.closeAll('-discard');
end
function restore(folder,owned),bdclose('all');Simulink.data.dictionary.closeAll('-discard');if contains([path pathsep],[folder pathsep]),rmpath(folder),end;if owned&&isfolder(folder),rmdir(folder,'s'),end
end
