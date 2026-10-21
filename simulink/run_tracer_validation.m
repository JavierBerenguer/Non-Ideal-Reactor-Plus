function validation = run_tracer_validation(folder)
%RUN_TRACER_VALIDATION Simulate and validate the three tracer examples.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    root=fileparts(fileparts(mfilename('fullpath')));addpath(root);addpath(fileparts(mfilename('fullpath')));
    owned=false;if nargin<1||isempty(folder),folder=tempname;mkdir(folder);owned=true;end
    cleanup=onCleanup(@()restore(folder,owned));files=build_tracer_examples(folder); %#ok<NASGU>
    names=nirp.tracerflowsheet.exampleNames();labels=["N = 2 analytical";"Flow-weighted parallel sum";"Tab 6 SEC01"];
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
                loaded=load(fullfile(root,'saves','SEC01.mat'),'sessionData');reference=loaded.sessionData.convolution.referenceResult;
                expected=interp1(reference.t,reference.C,grid.t,'linear',0);expected=expected/(grid.dt*sum(expected));
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
