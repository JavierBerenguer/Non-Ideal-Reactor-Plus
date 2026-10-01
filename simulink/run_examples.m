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
names=["ex1_cstr_isothermal";"ex2_cstr_adiabatic_cooler";"ex3_pfr_adiabatic";"ex4_problem40b_parallel"];
diagramF=zeros(4,1);scriptF=zeros(4,1);diagramT=zeros(4,1);scriptT=zeros(4,1);difference=zeros(4,1);
for i=1:numel(names)
    if evalin('base','exist(''nirpResults'',''var'')'),evalin('base','clear nirpResults');end
    load_system(char(files(i))); sim(char(names(i)));
    results=evalin('base','nirpResults'); actual=results.Product.streamSI;
    [expected,~]=scriptResult(i); diagramF(i)=actual.F(1);scriptF(i)=expected.F(1);diagramT(i)=actual.T;scriptT(i)=expected.T;
    difference(i)=max([relativeDifference(actual.F,expected.F),relativeDifference(actual.T,expected.T),relativeDifference(actual.P,expected.P)]);
    close_system(char(names(i)),0);Simulink.data.dictionary.closeAll('-discard');
end
comparison=table(names,diagramF,scriptF,diagramT,scriptT,difference, ...
    'VariableNames',{'Example','DiagramF1','ScriptF1','DiagramT','ScriptT','MaxRelativeDifference'});
disp(comparison);
assert(all(difference<=1e-9),'nirp:examples:mismatch','A diagram differs from its script result by more than 1e-9.');

function [out,info]=scriptResult(index)
    if index<4
        pkg=nirp.pkg.examples.firstOrderLiquid();
    else
        pkg=nirp.pkg.examples.problem40Gas();
    end
    rs=nirp.pkg.toReactionSys(pkg); feed=nirp.pkg.feedStream(pkg,"F1");
    switch index
        case 1,[out,info]=nirp.units.cstr(struct('V',0.1,'heatMode','Isothermal'),feed,rs);
        case 2
            intermediate=nirp.units.cstr(struct('V',0.1,'heatMode','Adiabatic'),feed,rs);
            [out,info]=nirp.units.heater(struct('mode','Outlet T','Tout',300),intermediate,rs);
        case 3,[out,info]=nirp.units.pfr(struct('V',0.1,'D',0.1,'nTubes',1,'heatMode','Adiabatic'),feed,rs);
        otherwise
            branches=nirp.units.splitter(struct('fractions',[0.5 0.5]),feed,rs);
            first=nirp.units.cstr(struct('V',0.4),branches{1},rs);second=nirp.units.cstr(struct('V',0.4),branches{2},rs);
            [out,info]=nirp.units.mixer([],{first,second},rs);
    end
end

function value=relativeDifference(actual,expected)
    value=max(abs(actual(:)-expected(:))./max(abs(expected(:)),1e-15));
end

function restoreFileGeneration(config,folder)
    Simulink.fileGenControl('setConfig','config',config);
    if isfolder(folder),rmdir(folder,'s');end
end
