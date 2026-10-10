classdef NirpRecycleExamplesTest < matlab.unittest.TestCase
%NIRPRECYCLEEXAMPLESTEST Validates the recycle examples ex48-ex50 (T-143).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 10, 2026. Last update: October 10, 2026
% =========================================================================
    properties
        Folder
    end
    methods (TestClassSetup)
        function buildExamples(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            repo=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(repo,'simulink'));
            build_examples(testCase.Folder,["ex48_recycle_pfr","ex49_reactor_separator_recycle","ex50_recycle_with_adjust"]);
            testCase.addTeardown(@() cleanup(testCase.Folder));
        end
    end
    methods (Test)
        function recyclePfrMatchesLevenspiel(testCase)
            pkg=nirp.pkg.examples.firstOrderLiquid();rs=nirp.pkg.toReactionSys(pkg);feed=nirp.pkg.feedStream(pkg,"F1");
            k=0.01;tau=0.1/feed.Q;
            for R=[1 1e-6 500]
                set=@() set_param('ex48_recycle_pfr/Splitter','Fractions',mat2str([1 R]/(R+1),17));
                simulate(testCase,'ex48_recycle_pfr',set);results=evalin('base','nirpResults');
                X=1-results.Streams.Product.streamSI.F(1)/feed.F(1);
                ratio=fzero(@(r) k*tau/(R+1)-log((1+R*r)/((R+1)*r)),[1e-9 1]); % r = C_Af/C_A0
                % With R = 500 the loop ratio is 0.998: a 1e-8 change per iteration still
                % leaves ~1e-4 from the exact solution, so the limit is checked at 1e-3.
                tolerance=1e-6;if R>10,tolerance=1e-3;end
                testCase.verifyEqual(X,1-ratio,'AbsTol',tolerance,sprintf('R = %g',R));
                if R<1e-3
                    pfr=nirp.units.pfr(struct('V',0.1,'D',0.1,'heatMode','Isothermal'),feed,rs);
                    testCase.verifyEqual(X,1-pfr.F(1)/feed.F(1),'AbsTol',1e-3);
                elseif R>10
                    cstr=nirp.units.cstr(struct('V',0.1,'heatMode','Isothermal'),feed,rs);
                    testCase.verifyEqual(X,1-cstr.F(1)/feed.F(1),'AbsTol',1e-3);
                end
            end
        end
        function separatorLoopMatchesScript(testCase)
            simulate(testCase,'ex49_reactor_separator_recycle',[]);results=evalin('base','nirpResults');
            [product,purge,recycle]=separatorLoop(0.1);
            testCase.verifyEqual(results.Streams.Product.streamSI.F,product.F,'RelTol',1e-8,'AbsTol',1e-12);
            testCase.verifyEqual(results.Streams.Purge.streamSI.F,purge.F,'RelTol',1e-8,'AbsTol',1e-12);
            testCase.verifyEqual(results.Streams.(matlab.lang.makeValidName('Recycle feed')).streamSI.F,recycle.F,'RelTol',1e-8,'AbsTol',1e-12);
        end
        function adjustAndRecycleConvergeTogether(testCase)
            simulate(testCase,'ex50_recycle_with_adjust',[]);results=evalin('base','nirpResults');
            feed=nirp.pkg.feedStream(nirp.pkg.examples.firstOrderLiquid(),"F1");
            V=fzero(@(v) 1-productA(v)/feed.F(1)-0.95,[1e-3 10]);
            X=1-results.Streams.Product.streamSI.F(1)/feed.F(1);
            testCase.verifyEqual(X,0.95,'AbsTol',1e-6);
            tables=nirp.flowsheet.showResults('ex50_recycle_with_adjust','NoWindow',true);
            testCase.verifyEqual(tables.Adjust.Converged,1);testCase.verifyEqual(tables.Recycles.Converged,1);
            testCase.verifyEqual(tables.Adjust.Parameter,V,'RelTol',1e-5);
        end
    end
end
function simulate(testCase,name,configure)
    load_system(fullfile(testCase.Folder,[name '.slx']));
    if ~isempty(configure),configure();end
    sim(name);
end
function [product,purge,recycle]=separatorLoop(V)
    % Script reference without Simulink: successive substitution on the recycle stream.
    pkg=nirp.pkg.examples.firstOrderLiquid();rs=nirp.pkg.toReactionSys(pkg);feed=nirp.pkg.feedStream(pkg,"F1");
    recycle=nirp.stream.empty(rs.nComponents,feed.T,feed.P,0);
    for iteration=1:5000
        mixed=nirp.units.mixer(struct(),{feed,recycle},rs);
        out=nirp.units.cstr(struct('V',V,'heatMode','Isothermal'),mixed,rs);
        parts=nirp.units.separator(struct('recovery',[0.95 0.02]),out,rs);
        split=nirp.units.splitter(struct('fractions',[0.1 0.9]),parts{1},rs);
        change=max(abs(split{2}.F-recycle.F));recycle=split{2};
        if change<1e-15*max(1,max(abs(recycle.F))),break,end
    end
    product=parts{2};purge=split{1};
end
function value=productA(V)
    product=separatorLoop(V);value=product.F(1);
end
function cleanup(folder)
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');
    if contains([path pathsep],[folder pathsep]),rmpath(folder);end
end
