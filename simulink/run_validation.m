% run_validation - Validate collection-problem flowsheets against scripts.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

repoRoot = fileparts(fileparts(mfilename('fullpath'))) ; addpath(repoRoot) ;
validationFolder = tempname ; mkdir(validationFolder) ; addpath(validationFolder) ;
fileGenerationConfig = Simulink.fileGenControl('getConfig') ;
generatedFolder = tempname ; mkdir(generatedFolder) ;
Simulink.fileGenControl('set','CacheFolder',fullfile(generatedFolder,'cache'), ...
    'CodeGenFolder',fullfile(generatedFolder,'codegen'),'createDir',true) ;
validationCleanup = onCleanup(@() restoreValidationEnvironment( ...
    fileGenerationConfig,generatedFolder,validationFolder)) ;
files = build_examples(validationFolder) ;

pkg37 = nirp.pkg.examples.problem37Liquid() ;
rs37 = nirp.pkg.toReactionSys(pkg37) ;
feedA = nirp.pkg.feedStream(pkg37,"Feed A") ;
feedB = nirp.pkg.feedStream(pkg37,"Feed B") ;
mixed37 = nirp.units.mixer([],{feedA,feedB},rs37) ;
first37 = nirp.units.cstr(struct('V',0.2),mixed37,rs37) ;
out37 = nirp.units.cstr(struct('V',0.2),first37,rs37) ;
diagram37 = simulateValidationExample(files(8),"ex8_problem37a_series") ;

pkg40 = nirp.pkg.examples.problem40Gas() ;
rs40 = nirp.pkg.toReactionSys(pkg40) ; feed40 = nirp.pkg.feedStream(pkg40,"F1") ;
first40a = nirp.units.cstr(struct('V',0.4),feed40,rs40) ;
out40a = nirp.units.cstr(struct('V',0.4),first40a,rs40) ;
diagram40a = simulateValidationExample(files(9),"ex9_problem40a_series") ;
branches40b = nirp.units.splitter(struct('fractions',[0.5 0.5]),feed40,rs40) ;
branch1 = nirp.units.cstr(struct('V',0.4),branches40b{1},rs40) ;
branch2 = nirp.units.cstr(struct('V',0.4),branches40b{2},rs40) ;
out40b = nirp.units.mixer([],{branch1,branch2},rs40) ;
diagram40b = simulateValidationExample(files(4),"ex4_problem40b_parallel") ;

pkg42 = nirp.pkg.examples.problem42SecondOrder() ;
rs42 = nirp.pkg.toReactionSys(pkg42) ; feed42 = nirp.pkg.feedStream(pkg42,"F1") ;
first42cp = nirp.units.cstr(struct('V',1),feed42,rs42) ;
out42cp = nirp.units.pfr(struct('V',1,'D',0.1),first42cp,rs42) ;
diagram42cp = simulateValidationExample(files(10),"ex10_problem42_cstr_pfr") ;
first42pc = nirp.units.pfr(struct('V',1,'D',0.1),feed42,rs42) ;
out42pc = nirp.units.cstr(struct('V',1),first42pc,rs42) ;
diagram42pc = simulateValidationExample(files(11),"ex11_problem42_pfr_cstr") ;

pkg19 = nirp.pkg.examples.problem19Gas() ;
rs19 = nirp.pkg.toReactionSys(pkg19) ; feed19 = nirp.pkg.feedStream(pkg19,"F1") ;
out19 = nirp.units.pfr(struct('V',1.5,'D',0.1,'heatMode','Adiabatic'), ...
    feed19,rs19) ;
diagram19 = simulateValidationExample(files(12),"ex12_problem19_adiabatic_pfr") ;

pkg44 = nirp.pkg.readDictionary(replace(files(7),".slx",".sldd")) ;
rs44 = nirp.pkg.toReactionSys(pkg44) ; feed44 = nirp.pkg.feedStream(pkg44,"F1") ;
out44single = nirp.units.cstr(struct('V',0.5,'heatMode','Adiabatic', ...
    'initialTemperatureGuess',495),feed44,rs44) ;
first44 = nirp.units.cstr(struct('V',0.25,'heatMode','Adiabatic', ...
    'initialTemperatureGuess',490),feed44,rs44) ;
out44series = nirp.units.cstr(struct('V',0.25,'heatMode','Adiabatic', ...
    'initialTemperatureGuess',499),first44,rs44) ;
diagram44 = simulateValidationExample(files(7),"ex7_problem44c") ;

problem = ["P37a";"P37a";"P37a";"P40a";"P40b";"P42";"P42"; ...
    "P19";"P19";"P44c";"P44c"] ;
magnitude = ["C_A1 (mol/L)";"C_A2 (mol/L)";"X_A";"X_A";"X_A"; ...
    "X (CSTR+PFR)";"X (PFR+CSTR)";"X_A";"T_out (K)"; ...
    "X_A (one CSTR)";"X_A (two CSTRs)"] ;
diagram = [concentrationInMolPerL(diagram37.Streams.CSTR1Outlet.streamSI,1); ...
    concentrationInMolPerL(diagram37.Streams.Product.streamSI,1); ...
    diagram37.Streams.Product.conversion;diagram40a.Streams.Product.conversion; ...
    diagram40b.Streams.Product.conversion;diagram42cp.Streams.Product.conversion; ...
    diagram42pc.Streams.Product.conversion;diagram19.Streams.Product.conversion; ...
    diagram19.Streams.Product.streamSI.T;diagram44.Streams.Product500.conversion; ...
    diagram44.Streams.ProductSeries.conversion] ;
script = [concentrationInMolPerL(first37,1);concentrationInMolPerL(out37,1); ...
    conversion(feedA,out37,1);conversion(feed40,out40a,1); ...
    conversion(feed40,out40b,1);conversion(feed42,out42cp,1); ...
    conversion(feed42,out42pc,1);conversion(feed19,out19,1);out19.T; ...
    conversion(feed44,out44single,1);conversion(feed44,out44series,1)] ;
official = [0.828;0.704;0.296;0.663;0.578;0.464;0.472;0.600; ...
    779.53;0.977;0.995] ;
difference = abs(diagram-official) ;
validation = table(problem,magnitude,diagram,script,official,difference, ...
    'VariableNames',{'Problem','Magnitude','Diagram','Script','Official','Difference'}) ;
disp(validation) ;
relative = abs(diagram-script)./max(abs(script),1e-15) ;
assert(all(relative <= 1e-9),'nirp:validation:mismatch', ...
    'A collection-problem diagram differs from its script result by more than 1e-9.') ;

function results = simulateValidationExample(file,name)
    evalin('base','clear nirpResults') ;
    load_system(char(file)) ; sim(char(name)) ;
    results = evalin('base','nirpResults') ;
    close_system(char(name),0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function value = concentrationInMolPerL(stream,index)
    concentrations = nirp.stream.concentration(stream) ;
    value = concentrations(index)/1000 ;
end

function value = conversion(feed,product,index)
    value = (feed.F(index)-product.F(index))/feed.F(index) ;
end

function restoreValidationEnvironment(config,generatedFolder,validationFolder)
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    Simulink.fileGenControl('setConfig','config',config) ;
    if contains([path pathsep],[validationFolder pathsep]), rmpath(validationFolder) ; end
    if isfolder(generatedFolder), rmdir(generatedFolder,'s') ; end
    if isfolder(validationFolder), rmdir(validationFolder,'s') ; end
end
