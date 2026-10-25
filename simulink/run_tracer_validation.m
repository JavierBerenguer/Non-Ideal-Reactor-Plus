function [validation,reactiveValidation] = run_tracer_validation(folder)
%RUN_TRACER_VALIDATION Validate tracer and reactive flowsheet examples.
%   VALIDATION retains the original three-row tracer validation table.
%   REACTIVEVALIDATION compares C_A and X_A for each micromixing model with
%   independent analytical or fine-quadrature references. Relative errors
%   must not exceed 0.4%, which covers the common-grid RTD quadrature.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
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
