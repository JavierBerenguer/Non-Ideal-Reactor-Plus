% run_examples - Build and compare the NIRP Simulink examples with scripts.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

repoRoot=fileparts(fileparts(mfilename('fullpath'))); addpath(repoRoot);
exampleFolder=fullfile(fileparts(mfilename('fullpath')),'examples');
fileGenerationConfig=Simulink.fileGenControl('getConfig');
generatedFolder=tempname;mkdir(generatedFolder);
Simulink.fileGenControl('set','CacheFolder',fullfile(generatedFolder,'cache'), ...
    'CodeGenFolder',fullfile(generatedFolder,'codegen'),'createDir',true);
fileGenerationCleanup=onCleanup(@() restoreFileGeneration(fileGenerationConfig,generatedFolder));
files=build_examples(exampleFolder);
names=["ex1_cstr_isothermal";"ex2_cstr_adiabatic_cooler";"ex3_pfr_adiabatic"; ...
    "ex4_problem40b_parallel";"ex5_recycle_cstr";"ex6_adjust_volume";"ex7_problem44c"];
diagramF=zeros(7,1);scriptF=zeros(7,1);diagramT=zeros(7,1);scriptT=zeros(7,1);difference=zeros(7,1);
for i=1:numel(names)
    if evalin('base','exist(''nirpResults'',''var'')'),evalin('base','clear nirpResults');end
    load_system(char(files(i))); sim(char(names(i)));
    results=evalin('base','nirpResults');
    [expected,secondary]=scriptResult(i);
    if i==7
        actual=results.ProductSeries.streamSI; actualSecondary=results.Product500.streamSI;
        difference(i)=max([streamDifference(actual,expected),streamDifference(actualSecondary,secondary)]);
    else
        actual=results.Product.streamSI;
        difference(i)=streamDifference(actual,expected);
    end
    diagramF(i)=actual.F(1);scriptF(i)=expected.F(1);diagramT(i)=actual.T;scriptT(i)=expected.T;
    close_system(char(names(i)),0);Simulink.data.dictionary.closeAll('-discard');
end
comparison=table(names,diagramF,scriptF,diagramT,scriptT,difference, ...
    'VariableNames',{'Example','DiagramF1','ScriptF1','DiagramT','ScriptT','MaxRelativeDifference'});
disp(comparison);
assert(all(difference<=1e-9),'nirp:examples:mismatch','A diagram differs from its script result by more than 1e-9.');

function [out,secondary]=scriptResult(index)
    if index<4 || (index>=5 && index<=6)
        pkg=nirp.pkg.examples.firstOrderLiquid();
    elseif index==4
        pkg=nirp.pkg.examples.problem40Gas();
    else
        pkg=problem44ReferencePackage();
    end
    rs=nirp.pkg.toReactionSys(pkg); feed=nirp.pkg.feedStream(pkg,"F1");
    secondary=[];
    switch index
        case 1,out=nirp.units.cstr(struct('V',0.1,'heatMode','Isothermal'),feed,rs);
        case 2
            intermediate=nirp.units.cstr(struct('V',0.1,'heatMode','Adiabatic'),feed,rs);
            out=nirp.units.heater(struct('mode','Outlet T','Tout',300),intermediate,rs);
        case 3,out=nirp.units.pfr(struct('V',0.1,'D',0.1,'nTubes',1,'heatMode','Adiabatic'),feed,rs);
        case 4
            branches=nirp.units.splitter(struct('fractions',[0.5 0.5]),feed,rs);
            first=nirp.units.cstr(struct('V',0.4),branches{1},rs);second=nirp.units.cstr(struct('V',0.4),branches{2},rs);
            out=nirp.units.mixer([],{first,second},rs);
        case 5
            alpha=0.9;k=0.01;V=0.1;Qin=feed.Q/(1-alpha);D=1+k*V/Qin;
            out=feed;out.F(1)=(1-alpha)/(D-alpha)*feed.F(1);out.F(2)=sum(feed.F)-out.F(1);
        case 6,out=nirp.units.cstr(struct('V',0.4),feed,rs);
        otherwise
            [secondary,~]=nirp.units.cstr(struct('V',0.5,'heatMode','Adiabatic','initialTemperatureGuess',495),feed,rs);
            first=nirp.units.cstr(struct('V',0.25,'heatMode','Adiabatic','initialTemperatureGuess',490),feed,rs);
            out=nirp.units.cstr(struct('V',0.25,'heatMode','Adiabatic','initialTemperatureGuess',499),first,rs);
    end
end


function pkg=problem44ReferencePackage()
    pkg.meta=struct('formatVersion',1,'name',"Problem 44c");
    cpA=struct('type',"constant",'value',15,'unit',"cal/(mol*K)");
    cpC=struct('type',"constant",'value',30,'unit',"cal/(mol*K)");
    pkg.components=struct('name',{"A","B","C"},'Mw',{[],[],[]},'cp',{cpA,cpA,cpC},'hf',{[],[],[]});
    pkg.reactions.stoich=[-1 -1 1];pkg.reactions.DH=struct('value',-6,'unit',"kcal/mol");
    pkg.reactions.Tref=struct('value',273.15,'unit',"K");
    pkg.reactions.rateUnits=struct('concentration',"mol/L",'time',"s");
    pkg.reactions.kinetics=struct('type',"powerlaw",'k0',0.01*exp(10000*4.184/(8.314*300.15)), ...
        'Ea',struct('value',10000,'unit',"cal/mol"),'orders',[1 1 0],'reverse',[],'expression',"");
    pkg.feeds=struct('name',"F1",'phase',"L",'T',struct('value',27,'unit',"C"), ...
        'P',struct('value',1,'unit',"atm"),'basis',"concentrations",'values',[1 1 0], ...
        'valuesUnit',"mol/L",'Q',struct('value',2,'unit',"L/s"));
end

function value=streamDifference(actual,expected)
    value=max([relativeDifference(actual.F,expected.F), ...
        relativeDifference(actual.T,expected.T),relativeDifference(actual.P,expected.P)]);
end

function value=relativeDifference(actual,expected)
    value=max(abs(actual(:)-expected(:))./max(abs(expected(:)),1e-15));
end

function restoreFileGeneration(config,folder)
    Simulink.fileGenControl('setConfig','config',config);
    if isfolder(folder),rmdir(folder,'s');end
end
