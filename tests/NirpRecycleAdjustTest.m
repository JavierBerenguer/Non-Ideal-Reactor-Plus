classdef (SharedTestFixtures={nirptest.ExamplesFixture}) ...
        NirpRecycleAdjustTest < matlab.unittest.TestCase
    % NirpRecycleAdjustTest verifies iterative flowsheet blocks and CSTR recovery.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 2, 2026. Last update: October 2, 2026
    % =========================================================================
    properties
        Folder
        ExamplesFolder
        Files
    end
    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture=testCase.applyFixture(TemporaryFolderFixture);testCase.Folder=fixture.Folder;
            examples=testCase.getSharedTestFixtures('nirptest.ExamplesFixture');
            testCase.ExamplesFolder=examples.Folder;
            testCase.Files=examples.Files;addpath(testCase.Folder);
            testCase.addTeardown(@() removePath(testCase.Folder));
            testCase.addTeardown(@() closeModels());
        end
    end
    methods (Test)
        function recycleReferencesAccelerationAndAutoStop(testCase)
            alphas=[0.5 0.9 0.99];
            for i=1:numel(alphas)
                name=sprintf('recycle_%d',i);NirpRecycleAdjustTest.buildRecycle(testCase.Folder,name,alphas(i),200,'Wegstein');
                simulation=sim(name);results=evalin('base','nirpResults');actual=results.Streams.Product.streamSI.F(1);
                qin=1e-3/(1-alphas(i));reference=(1-alphas(i))/(1+0.01*0.1/qin-alphas(i));
                testCase.verifyEqual(actual,reference,'RelTol',1e-8);
                entries=nirp.flowsheet.registry('list',name);recycle=entries(strcmp({entries.kind},'Recycle'));
                if alphas(i)==0.99,testCase.verifyLessThanOrEqual(recycle.iteration,30);end
                testCase.verifyLessThan(simulation.tout(end),200);
                close_system(name,0);Simulink.data.dictionary.closeAll('-discard');
            end
        end

        function twoRecycleTopologiesMatchReferences(testCase)
            for topology=["nested","series"]
                name=['two_' char(topology)];NirpRecycleAdjustTest.buildTwoRecycle(testCase.Folder,name,topology);
                sim(name);results=evalin('base','nirpResults');
                if topology=="nested",reference=0.337837837837838;else,reference=0.277777777777778;end
                testCase.verifyEqual(results.Streams.Product.streamSI.F(1),reference,'RelTol',1e-8);
                close_system(name,0);Simulink.data.dictionary.closeAll('-discard');
            end
        end

        function adjustWithoutAndWithRecycle(testCase)
            for strategy=["Simultaneous","Nested"]
                name=['adjust_' lower(char(strategy))];NirpRecycleAdjustTest.buildAdjustRecycle(testCase.Folder,name,strategy);
                sim(name);results=evalin('base','nirpResults');
                testCase.verifyEqual(results.Streams.Product.conversion,0.9,'AbsTol',1e-8);
                testCase.verifyEqual(results.Diagnostics.([name '_CSTR']).lastInfo.V,0.9,'RelTol',1e-8);
                close_system(name,0);Simulink.data.dictionary.closeAll('-discard');
            end
            files=testCase.Files;load_system(char(files(6)));sim('ex6_adjust_volume');
            results=evalin('base','nirpResults');
            testCase.verifyEqual(results.Streams.Product.conversion,0.8,'AbsTol',1e-8);
            testCase.verifyEqual(results.Diagnostics.ex6_adjust_volume_CSTR.lastInfo.V,0.4,'RelTol',1e-8);
        end

        function problem44AndCstrRecovery(testCase)
            pkg=NirpRecycleAdjustTest.problem44Package();rs=nirp.pkg.toReactionSys(pkg);feed=nirp.pkg.feedStream(pkg,"F1");
            [out,info]=nirp.units.cstr(struct('V',0.5,'heatMode','Adiabatic'),feed,rs);
            testCase.verifyEqual(info.status,1);testCase.verifyGreaterThanOrEqual(min(out.F),0);
            testCase.verifyGreaterThan(out.T,0);testCase.verifyEqual(1-out.F(1)/feed.F(1),0.977074,'AbsTol',1e-6);
            [failed,failedInfo]=nirp.units.cstr(struct('V',0.5,'heatMode','Adiabatic', ...
                'initialTemperatureGuess',-1e9),feed,rs);
            testCase.verifyEqual(failedInfo.status,-1);testCase.verifyTrue(nirp.stream.isValid(failed));
            files=testCase.Files;load_system(char(files(7)));sim('ex7_problem44c');
            results=evalin('base','nirpResults');
            testCase.verifyEqual(results.Streams.Product500.conversion,0.977074,'AbsTol',1e-6);
            testCase.verifyEqual(results.Streams.ProductSeries.conversion,0.994737,'AbsTol',1e-6);
        end

        function maximumIterationsWarnsAndMarksResults(testCase)
            name='not_converged';NirpRecycleAdjustTest.buildRecycle(testCase.Folder,name,0.99,3,'Direct');
            testCase.verifyWarning(@() sim(name),'nirp:flowsheet:notConverged');
            results=evalin('base','nirpResults');testCase.verifyEqual(results.Flowsheet.status,-1);
            testCase.verifyEqual(results.Streams.Product.status,-1);
        end
    end
    methods (Static,Access=private)
        function createModel(folder,name,pkg,maxIterations)
            nirp.pkg.writeDictionary(pkg,fullfile(folder,[name '.sldd']));new_system(name);
            save_system(name,fullfile(folder,[name '.slx']));set_param(name,'DataDictionary',[name '.sldd']);
            nirp.flowsheet.addBlock(name,'Flowsheet',[20 20 140 75],maxIterations);
        end
        function add(model,name,className,position,varargin)
            add_block('simulink/User-Defined Functions/MATLAB System',[model '/' name], ...
                'System',className,'Position',position,varargin{:});
        end
        function buildRecycle(folder,name,alpha,maxIterations,method)
            NirpRecycleAdjustTest.createModel(folder,name,nirp.pkg.examples.firstOrderLiquid(),maxIterations);
            NirpRecycleAdjustTest.add(name,'F1','nirp.blocks.Stream',[20 150 100 200],'Role','Feed');
            NirpRecycleAdjustTest.add(name,'Mixer','nirp.blocks.Mixer',[150 130 250 210]);
            NirpRecycleAdjustTest.add(name,'CSTR','nirp.blocks.CSTR',[300 135 410 205],'V','0.1');
            NirpRecycleAdjustTest.add(name,'Splitter','nirp.blocks.Splitter',[460 125 570 215],'Fractions',mat2str([1-alpha alpha],17));
            NirpRecycleAdjustTest.add(name,'Recycle','nirp.blocks.Recycle',[450 270 590 330], ...
                'Method',method,'QMin','-1000');
            NirpRecycleAdjustTest.add(name,'Product','nirp.blocks.Stream',[640 145 740 195],'Role','Product');
            add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');add_line(name,'Mixer/1','CSTR/1');
            add_line(name,'CSTR/1','Splitter/1');add_line(name,'Splitter/1','Product/1');add_line(name,'Splitter/2','Recycle/1');
            nirp.flowsheet.configure(name);save_system(name);
        end
        function buildTwoRecycle(folder,name,topology)
            NirpRecycleAdjustTest.createModel(folder,name,nirp.pkg.examples.firstOrderLiquid(),200);
            NirpRecycleAdjustTest.add(name,'F1','nirp.blocks.Stream',[20 180 90 225],'Role','Feed');
            volumes=[0.1 0.08];fractions=[0.5 0.8];
            for i=1:2
                NirpRecycleAdjustTest.add(name,sprintf('Mixer%d',i),'nirp.blocks.Mixer',[130+360*(i-1) 150 220+360*(i-1) 220]);
                NirpRecycleAdjustTest.add(name,sprintf('CSTR%d',i),'nirp.blocks.CSTR',[250+360*(i-1) 150 340+360*(i-1) 220],'V',num2str(volumes(i)));
                NirpRecycleAdjustTest.add(name,sprintf('Splitter%d',i),'nirp.blocks.Splitter',[370+360*(i-1) 140 460+360*(i-1) 230],'Fractions',mat2str([1-fractions(i) fractions(i)]));
                NirpRecycleAdjustTest.add(name,sprintf('Recycle%d',i),'nirp.blocks.Recycle',[300+360*(i-1) 280 430+360*(i-1) 335], ...
                    'Method','Wegstein','QMin','-1000');
            end
            if topology=="series"
                add_line(name,'F1/1','Mixer1/1');add_line(name,'Recycle1/1','Mixer1/2');add_line(name,'Mixer1/1','CSTR1/1');add_line(name,'CSTR1/1','Splitter1/1');add_line(name,'Splitter1/2','Recycle1/1');
                add_line(name,'Splitter1/1','Mixer2/1');add_line(name,'Recycle2/1','Mixer2/2');
            else
                add_line(name,'F1/1','Mixer2/1');add_line(name,'Recycle2/1','Mixer2/2');add_line(name,'Mixer2/1','Mixer1/1');add_line(name,'Recycle1/1','Mixer1/2');add_line(name,'Mixer1/1','CSTR1/1');add_line(name,'CSTR1/1','Splitter1/1');add_line(name,'Splitter1/2','Recycle1/1');add_line(name,'Splitter1/1','CSTR2/1');
            end
            if topology=="series",add_line(name,'Mixer2/1','CSTR2/1');end
            add_line(name,'CSTR2/1','Splitter2/1');add_line(name,'Splitter2/2','Recycle2/1');
            NirpRecycleAdjustTest.add(name,'Product','nirp.blocks.Stream',[850 160 950 210],'Role','Product');add_line(name,'Splitter2/1','Product/1');
            nirp.flowsheet.configure(name);save_system(name);
        end
        function buildAdjustRecycle(folder,name,strategy)
            NirpRecycleAdjustTest.createModel(folder,name,nirp.pkg.examples.firstOrderLiquid(),1000);
            NirpRecycleAdjustTest.add(name,'F1','nirp.blocks.Stream',[20 160 90 205],'Role','Feed');
            NirpRecycleAdjustTest.add(name,'Mixer','nirp.blocks.Mixer',[130 140 220 215]);
            NirpRecycleAdjustTest.add(name,'CSTR','nirp.blocks.CSTR',[300 140 410 215],'VSource','Input port');
            NirpRecycleAdjustTest.add(name,'Splitter','nirp.blocks.Splitter',[470 130 570 220],'Fractions','[0.5 0.5]');
            NirpRecycleAdjustTest.add(name,'Recycle','nirp.blocks.Recycle',[450 270 580 330], ...
                'Method','Wegstein','QMin','-1000','Tolerance','1e-10');
            NirpRecycleAdjustTest.add(name,'Adjust','nirp.blocks.Adjust',[230 290 380 355], ...
                'TargetValue','0.9','InitialValue','0.2','MinValue','0.01','MaxValue','2','ParameterUnit','m^3', ...
                'Damping','0.35','Tolerance','1e-10','Strategy',char(strategy));
            NirpRecycleAdjustTest.add(name,'Product','nirp.blocks.Stream',[650 145 750 200], ...
                'Role','Product','ReferenceFeed','F1','KeyComponent','A');
            add_line(name,'F1/1','Mixer/1');add_line(name,'Recycle/1','Mixer/2');add_line(name,'Mixer/1','CSTR/1');
            add_line(name,'Adjust/1','CSTR/2');add_line(name,'CSTR/1','Splitter/1');add_line(name,'Splitter/1','Adjust/1');
            add_line(name,'Splitter/1','Product/1');add_line(name,'Splitter/2','Recycle/1');
            nirp.flowsheet.configure(name);save_system(name);
        end
        function pkg=problem44Package()
            pkg.meta=struct('formatVersion',1,'name',"Problem 44c");
            cpA=struct('type',"constant",'value',15,'unit',"cal/(mol*K)");cpC=struct('type',"constant",'value',30,'unit',"cal/(mol*K)");
            pkg.components=struct('name',{"A","B","C"},'Mw',{[],[],[]},'cp',{cpA,cpA,cpC},'hf',{[],[],[]});
            pkg.reactions.stoich=[-1 -1 1];pkg.reactions.DH=struct('value',-6,'unit',"kcal/mol");pkg.reactions.Tref=struct('value',273.15,'unit',"K");
            pkg.reactions.rateUnits=struct('concentration',"mol/L",'time',"s");
            pkg.reactions.kinetics=struct('type',"powerlaw",'k0',0.01*exp(10000*4.184/(8.314*300.15)), ...
                'Ea',struct('value',10000,'unit',"cal/mol"),'orders',[1 1 0],'reverse',[],'expression',"");
            pkg.feeds=struct('name',"F1",'phase',"L",'T',struct('value',27,'unit',"C"),'P',struct('value',1,'unit',"atm"), ...
                'basis',"concentrations",'values',[1 1 0],'valuesUnit',"mol/L",'Q',struct('value',2,'unit',"L/s"));
        end
    end
end

function closeModels()
    bdclose('all');Simulink.data.dictionary.closeAll('-discard');evalin('base','clear nirpResults');
end
function removePath(folder)
    if contains([path pathsep],[folder pathsep]),rmpath(folder);end
end
