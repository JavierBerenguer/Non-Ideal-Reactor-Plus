classdef NirpTracerReactiveExamplesTest < matlab.unittest.TestCase
    % Headless tests for persisted reactive tracer flowsheet examples.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 25, 2026. Last update: November 2, 2026
    % =========================================================================
    properties,Folder;end
    methods (TestMethodSetup)
        function setup(testCase)
            fixture=testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'simulink'));
            testCase.addTeardown(@()cleanup());
        end
    end
    methods (Test)
        function catalogueIncludesClearReactiveDescriptions(testCase)
            [names,descriptions]=nirp.tracerflowsheet.exampleNames();
            testCase.verifyEqual(names(4:6),["reactive_two_cstr_first_order"; ...
                "reactive_two_cstr_second_order";"reactive_pfr_cstr_parallel_second_order"]);
            testCase.verifyEqual(descriptions(4:6),["Two reactive CSTRs in series (first order)"; ...
                "Two reactive CSTRs in series (second order)"; ...
                "Reactive PFR and CSTR in parallel (second order)"]);
            testCase.verifyEqual(names(7),"reactive_exam_jan2024");
            testCase.verifySubstring(descriptions(7),"2A -> D + E");
        end
        function firstOrderExampleRestoresAndMatchesAnalytical(testCase)
            reaction=openRestoreAndSimulate(testCase,"reactive_two_cstr_first_order");
            expected=1-(1+0.4*2)^-2;
            testCase.verifyEqual([reaction.Xseg reaction.Xmm],expected*[1 1],'RelTol',4e-3);
            testCase.verifySubstring(reaction.warning,'First-order');
        end
        function secondOrderSeriesRestoresAndMatchesIndependentReferences(testCase)
            reaction=openRestoreAndSimulate(testCase,"reactive_two_cstr_second_order");
            Cmm1=cstrReference(10,0.05,2);Cmm2=cstrReference(Cmm1,0.05,2);
            Cseg1=segregationReference(10,0.05,2);Cseg2=segregationReference(Cseg1,0.05,2);
            testCase.verifyEqual(reaction.Cseg(1),Cseg2,'RelTol',4e-3);
            testCase.verifyEqual(reaction.Cmm(1),Cmm2,'RelTol',4e-3);
            testCase.verifyGreaterThan(reaction.Xseg,reaction.Xmm);
            testCase.verifyTrue(reaction.validity.guaranteed);testCase.verifySubstring(reaction.warning,'Guaranteed bounds');
        end
        function secondOrderParallelRestoresAndShowsIndependentInterval(testCase)
            reaction=openRestoreAndSimulate(testCase,"reactive_pfr_cstr_parallel_second_order");
            pfr=10/(1+0.05*3*10);cstrMm=cstrReference(10,0.05,3);cstrSeg=segregationReference(10,0.05,3);
            expectedSeg=0.25*pfr+0.75*cstrSeg;expectedMm=0.25*pfr+0.75*cstrMm;
            testCase.verifyEqual(reaction.Cseg(1),expectedSeg,'RelTol',4e-3);
            testCase.verifyEqual(reaction.Cmm(1),expectedMm,'RelTol',4e-3);
            testCase.verifyEqual(reaction.interval,sort([reaction.Xseg reaction.Xmm]),'AbsTol',1e-12);
            testCase.verifyGreaterThan(reaction.interval(2),reaction.interval(1));
            testCase.verifyTrue(reaction.validity.guaranteed);testCase.verifySubstring(reaction.warning,'Guaranteed bounds');
        end
        function validationReportsEveryReactiveMagnitude(testCase)
            [tracer,reactive]=run_tracer_validation(testCase.Folder);
            testCase.verifySize(tracer,[3 5]);testCase.verifyLessThanOrEqual(tracer.maxAbsError,5e-3);
            testCase.verifySize(reactive,[22 9]);testCase.verifyLessThanOrEqual(reactive.relativeError,reactive.tolerance);
            summary=groupsummary(reactive,{'example','micromixing'});
            legacy=summary.example~="reactive_exam_jan2024";
            testCase.verifyEqual(summary.GroupCount(legacy),2*ones(6,1));
            testCase.verifyEqual(summary.GroupCount(~legacy),5*ones(2,1));
        end
        function examCoreMatchesBothVesselsAndReportsValidity(testCase)
            grid=nirp.tracer.grid(0.005,30);rs=examReactionSystem();
            E1=nirp.tracer.rtdModel(grid,'tanks',struct('tau',1,'N',1),0.05);
            first=nirp.tracer.reactiveVessel(grid,E1,rs,[1000 0 0 0 0],298.15,1);
            E2=nirp.tracer.rtdModel(grid,'tanks',struct('tau',2,'N',100),0.05);
            secondSeg=nirp.tracer.reactiveVessel(grid,E2,rs,first.Cseg,298.15,1);
            secondMm=nirp.tracer.reactiveVessel(grid,E2,rs,first.Cmm,298.15,1);
            expectedR1=[0.13824 0.060735 0.060735 0.31779 0.31779; ...
                0.19385 0.069644 0.069644 0.29107 0.29107];
            expectedR2=[0.044859 0.038064 0.16512 0.24168 0.24168; ...
                0.045823 0.038935 0.18121 0.24376 0.24376];
            testCase.verifyEqual([first.Cseg;first.Cmm]/1000,expectedR1,'RelTol',5e-3);
            testCase.verifyEqual([secondSeg.Cseg;secondMm.Cmm]/1000,expectedR2,'RelTol',5e-3);
            validity=first.diagnostic.boundValidity;
            testCase.verifyFalse(validity.guaranteed);
            testCase.verifySubstring(validity.reason,'exactly one reaction');
        end
        function examExampleRestoresAndMatchesIndependentReference(testCase)
            reaction=openRestoreAndSimulate(testCase,"reactive_exam_jan2024");
            expected=[0.044859 0.038064 0.16512 0.24168 0.24168; ...
                0.045823 0.038935 0.18121 0.24376 0.24376];
            testCase.verifyEqual([reaction.Cseg;reaction.Cmm]/1000,expected,'RelTol',5e-3);
            testCase.verifyFalse(reaction.validity.guaranteed);
            testCase.verifySubstring(reaction.warning,'Bounds not guaranteed');
            testCase.verifySubstring(reaction.warning,'exactly one reaction');
        end
    end
end

function reaction=openRestoreAndSimulate(testCase,name)
evalin('base','clear nirpTracerResults nirpTracerReactiveCalls tracerTestRS RS');
file=nirp.tracerflowsheet.openExample(name,'Folder',testCase.Folder,'NoWindow',true);
testCase.verifyTrue(isfile(file));testCase.verifyTrue(isfile(fullfile(testCase.Folder,[char(name) '.sldd'])));
reactionFile=fullfile(testCase.Folder,[char(name) '_reaction.mat']);testCase.verifyTrue(isfile(reactionFile));
file=nirp.tracerflowsheet.openExample(name,'Folder',testCase.Folder,'NoWindow',true,'PromptFcn',@(~)'Restore');
testCase.verifyTrue(isfile(file));evalin('base','clear nirpTracerResults nirpTracerReactiveCalls tracerTestRS RS');
sim(char(name));all=evalin('base','nirpTracerResults');key=matlab.lang.makeValidName([char(name) '_Monitor']);reaction=all.(key).reaction;
testCase.verifyEqual(get_param([char(name) '/Tracer Flowsheet'],'ReactionOrigin'),'File');
testCase.verifyEqual(get_param([char(name) '/Tracer Flowsheet'],'ReactionReference'),[char(name) '_reaction.mat']);
end

function C=cstrReference(Cin,k,tau)
C=(-1+sqrt(1+4*k*tau*Cin))/(2*k*tau);
end

function C=segregationReference(Cin,k,tau)
t=0:0.001:100*tau;E=exp(-t/tau)/tau;batch=Cin./(1+k*Cin*t);C=trapz(t,E.*batch)/trapz(t,E);
end

function rs=examReactionSystem()
rs=ReactionSys;rs.componentNames={'A','B','C','D','E'};
rs.stochiometricMatrix=[-1 1 0 0 0;0 -1 1 0 0;-2 0 0 1 1;0 1 0 -1 -1];
rs.userDefinedKinetics=@(C,T)[C(1)-2*C(2),C(2), ...
    0.01*C(1)^2,0.001*C(4)*C(5)]; %#ok<INUSD>
end

function cleanup()
figures=findall(groot,'Type','Figure');
for k=1:numel(figures)
    try
        delete(figures(k));
    catch
    end
end
bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpTracerResults nirpTracerReactiveCalls tracerTestRS RS');
end
