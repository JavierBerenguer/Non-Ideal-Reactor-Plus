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

pkg21 = nirp.pkg.examples.problem21Gas() ;
rs21 = nirp.pkg.toReactionSys(pkg21) ; feed21 = nirp.pkg.feedStream(pkg21,"F1") ;
temperature21a = fzero(@(temperature) pfrConversionAtTemperature( ...
    temperature,feed21,rs21,'Isothermal')-0.9,[330 450]) ;
temperature21b = fzero(@(temperature) pfrConversionAtTemperature( ...
    temperature,feed21,rs21,'Adiabatic')-0.9,[380 520]) ;
diagram21a = simulateValidationExample(files(13), ...
    "ex13_problem21a_isothermal_pfr") ;
diagram21b = simulateValidationExample(files(14), ...
    "ex14_problem21b_adiabatic_pfr") ;

pkg27 = nirp.pkg.examples.problem27Jacketed() ;
rs27 = nirp.pkg.toReactionSys(pkg27) ; feed27 = nirp.pkg.feedStream(pkg27,"F1") ;
temperature27 = fzero(@(temperature) cstr27ConversionAtTemperature( ...
    temperature,feed27,rs27)-0.8,[285 305]) ;
diagram27 = simulateValidationExample(files(15), ...
    "ex15_problem27_jacketed_cstr") ;

pkg30 = nirp.pkg.examples.problem30Liquid() ;
rs30 = nirp.pkg.toReactionSys(pkg30) ;
feedPO = nirp.pkg.feedStream(pkg30,"Feed PO") ;
feedW = nirp.pkg.feedStream(pkg30,"Feed W") ;
mixed30 = nirp.units.mixer([],{feedPO,feedW},rs30) ;
out30 = nirp.units.cstr(struct('V',1.136,'heatMode','Adiabatic'),mixed30,rs30) ;
out31 = nirp.units.cstr(struct('V',1.136,'heatMode','Other', ...
    'U',567.7,'A',3.7,'utilityTin',302.65),mixed30,rs30) ;
diagram30 = simulateValidationExample(files(16), ...
    "ex16_problem30_adiabatic_cstr") ;
diagram31 = simulateValidationExample(files(17), ...
    "ex17_problem31_cooled_cstr") ;

pkg44a = nirp.pkg.examples.problem44Liquid() ;
rs44a = nirp.pkg.toReactionSys(pkg44a) ; feed44a = nirp.pkg.feedStream(pkg44a,"F1") ;
volume44pfr = fzero(@(volume) reactorConversion(feed44a, ...
    nirp.units.pfr(struct('V',volume,'D',0.1,'heatMode','Adiabatic'), ...
    feed44a,rs44a),1)-0.85,[0.005 0.1]) ;
volume44cstr = fzero(@(volume) reactorConversion(feed44a, ...
    nirp.units.cstr(struct('V',volume,'heatMode','Adiabatic'), ...
    feed44a,rs44a),1)-0.85,[0.01 0.03]) ;
diagram44a = simulateValidationExample(files(18),"ex18_problem44a_volumes") ;

pkg45 = nirp.pkg.examples.problem45Liquid() ;
rs45 = nirp.pkg.toReactionSys(pkg45) ; feed45 = nirp.pkg.feedStream(pkg45,"F1") ;
volume45 = fzero(@(volume) threeCstrConversion(volume,feed45,rs45)-0.9, ...
    [0.1 0.5]) ;
temperature45 = fzero(@(temperature) cstr45OutletTemperature( ...
    temperature,feed45,rs45)-368.15,[335 355]) ;
diagram45a = simulateValidationExample(files(19), ...
    "ex19_problem45a_three_cstrs") ;
diagram45b = simulateValidationExample(files(20), ...
    "ex20_problem45b_feed_temperature") ;

problem = ["P37a";"P37a";"P37a";"P40a";"P40b";"P42";"P42"; ...
    "P19";"P19";"P44c";"P44c";"P21a";"P21b";"P27"; ...
    "P30";"P30";"P31";"P31";"P44a";"P44a";"P45a";"P45b"] ;
magnitude = ["C_A1 (mol/L)";"C_A2 (mol/L)";"X_A";"X_A";"X_A"; ...
    "X (CSTR+PFR)";"X (PFR+CSTR)";"X_A";"T_out (K)"; ...
    "X_A (one CSTR)";"X_A (two CSTRs)";"Adjusted T (K)"; ...
    "Adjusted T (K)";"Adjusted T (K)";"T_out (K)";"X_PO"; ...
    "T_out (K)";"X_PO";"Adjusted PFR V (L)";"Adjusted CSTR V (L)"; ...
    "Adjusted V per CSTR (L)";"Adjusted feed T (K)"] ;
diagram = [concentrationInMolPerL(diagram37.Streams.CSTR1Outlet.streamSI,1); ...
    concentrationInMolPerL(diagram37.Streams.Product.streamSI,1); ...
    diagram37.Streams.Product.conversion;diagram40a.Streams.Product.conversion; ...
    diagram40b.Streams.Product.conversion;diagram42cp.Streams.Product.conversion; ...
    diagram42pc.Streams.Product.conversion;diagram19.Streams.Product.conversion; ...
    diagram19.Streams.Product.streamSI.T;diagram44.Streams.Product500.conversion; ...
    diagram44.Streams.ProductSeries.conversion; ...
    diagram21a.Streams.F1.streamSI.T;diagram21b.Streams.F1.streamSI.T; ...
    diagram27.Streams.F1.streamSI.T;diagram30.Streams.Product.streamSI.T; ...
    diagram30.Streams.Product.conversion;diagram31.Streams.Product.streamSI.T; ...
    diagram31.Streams.Product.conversion; ...
    diagnosticVolume(diagram44a,"ex18_problem44a_volumes","PFR")*1000; ...
    diagnosticVolume(diagram44a,"ex18_problem44a_volumes","CSTR")*1000; ...
    diagnosticVolume(diagram45a,"ex19_problem45a_three_cstrs","CSTR 1")*1000; ...
    diagram45b.Streams.F1.streamSI.T] ;
script = [concentrationInMolPerL(first37,1);concentrationInMolPerL(out37,1); ...
    conversion(feedA,out37,1);conversion(feed40,out40a,1); ...
    conversion(feed40,out40b,1);conversion(feed42,out42cp,1); ...
    conversion(feed42,out42pc,1);conversion(feed19,out19,1);out19.T; ...
    conversion(feed44,out44single,1);conversion(feed44,out44series,1); ...
    temperature21a;temperature21b;temperature27;out30.T; ...
    conversion(feedPO,out30,1);out31.T;conversion(feedPO,out31,1); ...
    volume44pfr*1000;volume44cstr*1000;volume45*1000;temperature45] ;
official = [0.828;0.704;0.296;0.663;0.578;0.464;0.472;0.600; ...
    779.53;0.977;0.995;387;433;298.3;340.45;NaN;310.75;0.31; ...
    30.5;17.6;250.5;346.8] ;
difference = abs(diagram-official) ;
note = strings(size(problem)) ;
note(problem == "P30" | problem == "P31") = ...
    "Known difference: graphical official solution" ;
note(problem == "P27") = ...
    "Hand check of the statement data gives 298.62 K (official 298.3 K)" ;
validation = table(problem,magnitude,diagram,script,official,difference,note, ...
    'VariableNames',{'Problem','Magnitude','Diagram','Script','Official', ...
    'Difference','Note'}) ;
disp(validation) ;
relative = abs(diagram-script)./max(abs(script),1e-15) ;
adjusted = ismember(problem,["P21a","P21b","P27","P44a","P45a","P45b"]) ;
assert(all(relative(~adjusted) <= 1e-9),'nirp:validation:mismatch', ...
    'A non-adjusted diagram differs from its script result by more than 1e-9.') ;
assert(all(relative(adjusted) <= 1e-5),'nirp:validation:adjustMismatch', ...
    'An adjusted parameter differs from its fzero result by more than 1e-5.') ;

function results = simulateValidationExample(file,name)
    evalin('base','clear nirpResults') ;
    load_system(char(file)) ; simulation = sim(char(name)) ;
    results = evalin('base','nirpResults') ;
    if any(strcmp(simulation.who,'nirpAdjustedPfrVolume'))
        values = simulation.get('nirpAdjustedPfrVolume') ;
        results.AdjustedPfrVolume = values(end) ;
    end
    close_system(char(name),0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function value = concentrationInMolPerL(stream,index)
    concentrations = nirp.stream.concentration(stream) ;
    value = concentrations(index)/1000 ;
end

function value = conversion(feed,product,index)
    value = (feed.F(index)-product.F(index))/feed.F(index) ;
end

function value = reactorConversion(feed,product,index)
    value = conversion(feed,product,index) ;
end

function stream = atTemperature(stream,temperature)
    stream.T = temperature ;
    stream = nirp.stream.refresh(stream) ;
end

function value = pfrConversionAtTemperature(temperature,feed,rs,heatMode)
    inlet = atTemperature(feed,temperature) ;
    product = nirp.units.pfr(struct('V',1,'D',0.1, ...
        'heatMode',heatMode),inlet,rs) ;
    value = conversion(inlet,product,1) ;
end

function value = cstr27ConversionAtTemperature(temperature,feed,rs)
    inlet = atTemperature(feed,temperature) ;
    product = nirp.units.cstr(struct('V',0.2,'heatMode','Other', ...
        'U',300,'A',9,'utilityTin',273),inlet,rs) ;
    value = conversion(inlet,product,1) ;
end

function value = threeCstrConversion(volume,feed,rs)
    params = struct('V',volume,'heatMode','Specified T','specifiedT',368.15) ;
    first = nirp.units.cstr(params,feed,rs) ;
    second = nirp.units.cstr(params,first,rs) ;
    product = nirp.units.cstr(params,second,rs) ;
    value = conversion(feed,product,1) ;
end

function value = cstr45OutletTemperature(temperature,feed,rs)
    inlet = atTemperature(feed,temperature) ;
    product = nirp.units.cstr(struct('V',0.250480335, ...
        'heatMode','Adiabatic'),inlet,rs) ;
    value = product.T ;
end

function value = diagnosticVolume(results,model,block)
    if block == "PFR" && isfield(results,'AdjustedPfrVolume')
        value = results.AdjustedPfrVolume ;
        return
    end
    field = matlab.lang.makeValidName(model+"_"+block) ;
    value = results.Diagnostics.(field).lastInfo.V ;
end

function restoreValidationEnvironment(config,generatedFolder,validationFolder)
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    Simulink.fileGenControl('setConfig','config',config) ;
    if contains([path pathsep],[validationFolder pathsep]), rmpath(validationFolder) ; end
    if isfolder(generatedFolder), rmdir(generatedFolder,'s') ; end
    if isfolder(validationFolder), rmdir(validationFolder,'s') ; end
end
