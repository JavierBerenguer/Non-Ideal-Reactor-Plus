function validation = run_tracer_validation(folder)
%RUN_TRACER_VALIDATION Simulate and validate the three tracer examples.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fileparts(mfilename('fullpath')));
    owned=false;if nargin<1||isempty(folder),folder=tempname;mkdir(folder);owned=true;end
    cleanup=onCleanup(@()restore(folder,owned));files=build_tracer_examples(folder); %#ok<NASGU>
    names=nirp.tracerflowsheet.exampleNames();labels=["N = 2 analytical";"Flow-weighted parallel sum";"Former SEC01 exercise"];
    maxAbsError=zeros(3,1);tau=zeros(3,1);sigma2=zeros(3,1);
    for k=1:3
        result=simulateOne(folder,names(k));grid=result.grid;actual=result.stream.E;
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
        assert(maxAbsError(k)<=5e-3,'nirp:tracerflowsheet:ValidationMismatch','Tracer example %s differs from its reference.',names(k));
    end
    validation=table(names,labels,maxAbsError,tau,sigma2);
end
function result=simulateOne(folder,name)
evalin('base','clear nirpTracerResults');file=fullfile(folder,[char(name) '.slx']);load_system(file);sim(char(name));all=evalin('base','nirpTracerResults');key=matlab.lang.makeValidName([char(name) '_Monitor']);result=all.(key);close_system(char(name),0);Simulink.data.dictionary.closeAll('-discard');
end
function restore(folder,owned),bdclose('all');Simulink.data.dictionary.closeAll('-discard');if contains([path pathsep],[folder pathsep]),rmpath(folder),end;if owned&&isfolder(folder),rmdir(folder,'s'),end
end
