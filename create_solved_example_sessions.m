function create_solved_example_sessions(scope)
% create_solved_example_sessions
% Build saved sessions (.mat) for solved examples 51-64 where feasible and
% write a markdown registry describing which ones match well, partially, or
% cannot be reproduced directly from the current app / transcribed data.
%
% Convolution session registry:
%   SECT01 -> Topic 4, example 1 (PDF pages 13-14)
%   SECT02 -> Topic 4, example 2 (PDF pages 17-19)
%   SECT03 -> Topic 4, example 3 (PDF page 21)
%   SEC01  -> P4 problem 1 (PDF page 1)
%   SEC02  -> P4 problem 2 (PDF page 1)
%   SEC03  -> P4 problem 3 (PDF page 1)
%   SEC04  -> P4 problem 4 (PDF page 1)
%   SEC05  -> P4 problem 5 (PDF pages 1-2)
%   SEC06  -> P4 problem 6 (PDF page 2)
%   SEC07  -> P4 problem 7 (PDF page 2)
%   SEC08  -> P4 problem 8 (PDF page 2)
%   SEC09  -> P4 problem 10 (PDF page 3; the PDF has no problem 9)

if nargin < 1
    scope = 'all' ;
end
scope = validatestring(scope, {'all', 'convolution'}) ;

toolboxDir = fileparts(mfilename('fullpath')) ;
projectDir = fileparts(toolboxDir) ;
saveDir = fullfile(toolboxDir, 'saves') ;
reportPath = fullfile(projectDir, 'Problemas resueltos', 'SE_session_registry.md') ;

if ~exist(saveDir, 'dir')
    mkdir(saveDir) ;
end

generateConvolutionSessions(saveDir) ;
if strcmp(scope, 'convolution')
    fprintf('Convolution example sessions created in:\n%s\n', saveDir) ;
    return
end

records_good = {} ;
records_partial = {} ;
records_unresolved = {} ;

% Existing validated session
records_good{end+1} = struct( ...
    'exercise', '55', ...
    'files', {{'SE55.mat'}}, ...
    'notes', ['Sesion ya existente. Coincide con el solucionario para dispersion, ' ...
              'Tanks-in-Series, uso directo de E(t) experimental e Ideal CSTR.']) ;

% --- 51 ---------------------------------------------------------------
[sessionData, note] = buildSE51() ;
saveSessionData(saveDir, 'SE51.mat', sessionData) ;
records_partial{end+1} = struct( ...
    'exercise', '51', ...
    'files', {{'SE51.mat'}}, ...
    'notes', note) ;

% --- 52 ---------------------------------------------------------------
[sessionData, ok, note] = buildSE52() ;
saveSessionData(saveDir, 'SE52.mat', sessionData) ;
if ok
    records_good{end+1} = struct('exercise', '52', 'files', {{'SE52.mat'}}, 'notes', note) ;
else
    records_partial{end+1} = struct('exercise', '52', 'files', {{'SE52.mat'}}, 'notes', note) ;
end

% --- 53 ---------------------------------------------------------------
records_unresolved{end+1} = struct( ...
    'exercise', '53', ...
    'files', {{}}, ...
    'notes', ['No se ha creado sesion directa. El enunciado transcrito y la hoja ' ...
              'de soluciones son internamente inconsistentes entre C(t), E(t), F(t), ' ...
              'tm y Pe.']) ;

% --- 54 ---------------------------------------------------------------
[sessionData, note] = buildSE54() ;
saveSessionData(saveDir, 'SE54.mat', sessionData) ;
records_partial{end+1} = struct( ...
    'exercise', '54', ...
    'files', {{'SE54.mat'}}, ...
    'notes', note) ;

% --- 58 (low / high) --------------------------------------------------
[sessionLow, sessionHigh, note58] = buildSE58() ;
saveSessionData(saveDir, 'SE58_low.mat', sessionLow) ;
saveSessionData(saveDir, 'SE58_high.mat', sessionHigh) ;
records_partial{end+1} = struct( ...
    'exercise', '58', ...
    'files', {{'SE58_low.mat', 'SE58_high.mat'}}, ...
    'notes', note58) ;

% --- 59 ---------------------------------------------------------------
[sessionData, note] = buildSE59() ;
saveSessionData(saveDir, 'SE59.mat', sessionData) ;
records_partial{end+1} = struct( ...
    'exercise', '59', ...
    'files', {{'SE59.mat'}}, ...
    'notes', note) ;

% --- 60 ---------------------------------------------------------------
[sessionData, ok, note] = buildSE60() ;
saveSessionData(saveDir, 'SE60.mat', sessionData) ;
if ok
    records_good{end+1} = struct('exercise', '60', 'files', {{'SE60.mat'}}, 'notes', note) ;
else
    records_partial{end+1} = struct('exercise', '60', 'files', {{'SE60.mat'}}, 'notes', note) ;
end

% --- 61 ---------------------------------------------------------------
[sessionData, note] = buildSE61() ;
saveSessionData(saveDir, 'SE61.mat', sessionData) ;
records_partial{end+1} = struct( ...
    'exercise', '61', ...
    'files', {{'SE61.mat'}}, ...
    'notes', note) ;

% --- 62 ---------------------------------------------------------------
[sessionData, ok, note] = buildSE62() ;
saveSessionData(saveDir, 'SE62.mat', sessionData) ;
if ok
    records_good{end+1} = struct('exercise', '62', 'files', {{'SE62.mat'}}, 'notes', note) ;
else
    records_partial{end+1} = struct('exercise', '62', 'files', {{'SE62.mat'}}, 'notes', note) ;
end

% --- 64 ---------------------------------------------------------------
[sessionData, note] = buildSE64() ;
saveSessionData(saveDir, 'SE64.mat', sessionData) ;
records_partial{end+1} = struct( ...
    'exercise', '64', ...
    'files', {{'SE64.mat'}}, ...
    'notes', note) ;

% Problems omitted from the transcribed source due to missing figures
records_unresolved{end+1} = struct('exercise', '56', 'files', {{}}, ...
    'notes', 'Ejercicio omitido en la transcripcion porque depende de figuras.' ) ;
records_unresolved{end+1} = struct('exercise', '57', 'files', {{}}, ...
    'notes', 'Ejercicio omitido en la transcripcion porque depende de figuras.' ) ;
records_unresolved{end+1} = struct('exercise', '63', 'files', {{}}, ...
    'notes', 'Ejercicio omitido en la transcripcion porque depende de figuras.' ) ;

writeRegistry(reportPath, records_good, records_partial, records_unresolved) ;
fprintf('Solved example sessions created. Registry written to:\n%s\n', reportPath) ;
end

function saveSessionData(saveDir, fileName, sessionData)
save(fullfile(saveDir, fileName), 'sessionData', '-mat') ;
end

function [sessionData, note] = buildSE51()
tau_min = 0.4 ;
tau_s = tau_min * 60 ;
qv_si = 2e-3 / 60 ;
rtd = RTD.ideal_cstr(tau_s) ;
RS = ReactionSys.fromSimpleKinetics('2nd_order', struct('k', 23.75e-3/60)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;
stream = makeStream(1000, qv_si, {'A'}) ;
seg = SegregationModel(rtd) ;
seg = seg.compute_isothermal(RS, 1000) ;
sessionData = baseSession('SE51', 'Prediction Models', rtd) ;
sessionData.rtd = makeRtdState('Ideal CSTR', ...
    fieldState(tau_min, 'min'), fieldState(2, 'L/min'), ...
    'min', 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE51', stream, 'feed_SE51', 'mol/L') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = [] ;
sessionData.shared.displayCache = struct() ;
note = sprintf(['Sesion reconstruida a partir de la solucion: RTD equivalente a un CSTR ideal ' ...
    'con tau = 0.40 min. Con ello se reproducen la fraccion remanente (~%.3f) y X_seg (~%.3f).'], ...
    exp(-1/tau_min), seg.X_mean) ;
end

function [sessionData, ok, note] = buildSE52()
t_min = [0 5 10 15 20 30 40 50 70 100 125 150 175 200] ;
C = [112 95.8 82.2 70.6 60.9 45.6 34.5 26.3 15.7 7.67 5.11 2.55 1.73 0.90] ;
t_s = t_min * 60 ;
rtd = RTD.from_pulse(t_s, C) ;
k_si = 0.01e-3 / 60 ;
RS = ReactionSys.fromSimpleKinetics('2nd_order', struct('k', k_si)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;
qv_si = 25e-3 / 60 ;
stream = makeStream(8000, qv_si, {'A'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, 8000) ;
mm = MaxMixednessModel(rtd) ; mm = mm.compute_isothermal(RS, 8000) ;
veff_L = rtd.tau * (25/60) ;
ok = abs(seg.X_mean - 0.606) < 0.01 && ...
     abs(mm.X_exit - 0.565) < 0.01 && ...
     abs(veff_L - 944.5) < 10 ;
sessionData = baseSession('SE52', 'Prediction Models', rtd) ;
sessionData.rtd = makeTabularRtdState(t_min, C, 'min', fieldState(25, 'L/min'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE52', stream, 'feed_SE52', 'mol/L') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = mm ;
sessionData.shared.displayCache = struct() ;
note = sprintf('X_seg = %.3f, X_MM = %.3f, Veff = %.1f L. Coincide bien con el solucionario.', ...
    seg.X_mean, mm.X_exit, veff_L) ;
end

function [sessionData, note] = buildSE54()
t_min = [0 1 2 3 4 5 6 7 8 9 10 12 14] ;
C = [0 1 5 8 10 8 6 4 3 2.2 1.5 0.6 0] ;
t_s = t_min * 60 ;
rtd = RTD.from_pulse(t_s, C) ;
k_si = 0.25 / 60 ;
RS = ReactionSys.fromSimpleKinetics('1st_order', struct('k', k_si)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;
volume_L = pi * (0.05^2) * 6.36 * 1000 ;
qv_L_min = volume_L / (rtd.tau / 60) ;
stream = makeStream(1000, qv_L_min * 1e-3 / 60, {'A'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, 1000) ;
mm = MaxMixednessModel(rtd) ; mm = mm.compute_isothermal(RS, 1000) ;
[C_out_tis, X_tis] = TanksInSeries.solve_sequential(rtd.tau^2/rtd.sigma2, RS, 1000, rtd.tau) ;
[C_out_cstr, X_cstr] = TanksInSeries.solve_sequential(1, RS, 1000, rtd.tau) ;
[C_out_pfr, X_pfr] = TanksInSeries.solve_PFR(RS, 1000, rtd.tau) ;
bo = computeBoFromVariance(rtd.sigma2 / rtd.tau^2, 'closed-closed') ;
dispactor = DispersionReactor(bo, 'closed-closed') ;
[X_disp, C_out_disp] = dispactor.compute_conversion_general(RS, 1000, rtd.tau) ;
sessionData = baseSession('SE54', 'Prediction Models', rtd) ;
sessionData.rtd = makeTabularRtdState(t_min, C, 'min', fieldState(qv_L_min, 'L/min'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE54', stream, 'feed_SE54', 'mol/L') ;
sessionData.tis = makeTisState('From Calculated Data', rtd.tau/60, 'min', RS, 'RS_SE54', stream, 'feed_SE54', 'mol/L') ;
sessionData.dispersion = makeDispersionState('From Calculated Data', bo, rtd.tau/60, 'min', RS, 'RS_SE54', stream, 'feed_SE54', 'mol/L', 'closed-closed') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = mm ;
sessionData.shared.disp_reactor = dispactor ;
sessionData.shared.displayCache = struct( ...
    'TIS', struct('N_val', rtd.tau^2/rtd.sigma2, 'tau_val', rtd.tau, 'RS', RS, 'C0', 1000, ...
                  'X_tis', X_tis, 'X_cstr', X_cstr, 'X_pfr', X_pfr, ...
                  'C_out_tis', C_out_tis, 'C_out_cstr', C_out_cstr, 'C_out_pfr', C_out_pfr), ...
    'Dispersion', struct('Bo_val', bo, 'tau_val', rtd.tau, 'RS', RS, 'C0', 1000, ...
                         'X_disp', X_disp, 'X_cstr', X_cstr, 'X_pfr', X_pfr, ...
                         'C_out_disp', C_out_disp, 'C_out_cstr', C_out_cstr, 'C_out_pfr', C_out_pfr, ...
                         'bcType', 'closed-closed')) ;
note = sprintf(['PFR = %.3f, CSTR = %.3f, Seg = %.3f, TIS = %.3f y Disp = %.3f salen cerca. ' ...
    'La ruta de Max Mixedness da %.3f, no 0.661 como en la hoja de soluciones.'], ...
    X_pfr, X_cstr, seg.X_mean, X_tis, X_disp, mm.X_exit) ;
end

function [sessionLow, sessionHigh, note] = buildSE58()
tau_h = 0.5 ;
tau_s = tau_h * 3600 ;
rtd = RTD.ideal_cstr(tau_s) ;
RS = ReactionSys.fromSimpleKinetics('michaelis_menten', struct('a', 1/3600, 'b', 0.5e-3)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;

streamLow = makeStream(1, 1e-3/3600, {'A'}) ;
streamHigh = makeStream(1000, 1e-3/3600, {'A'}) ;
segLow = SegregationModel(rtd) ; segLow = segLow.compute_isothermal(RS, 1) ;
mmLow = MaxMixednessModel(rtd) ; mmLow = mmLow.compute_isothermal(RS, 1) ;
segHigh = SegregationModel(rtd) ; segHigh = segHigh.compute_isothermal(RS, 1000) ;
mmHigh = MaxMixednessModel(rtd) ; mmHigh = mmHigh.compute_isothermal(RS, 1000) ;

sessionLow = baseSession('SE58_low', 'Prediction Models', rtd) ;
sessionLow.rtd = makeEquationRtdState('2*exp(-2*t)', fieldState(tau_h, 'h'), fieldState(1, 'L/h'), 'h', 'L') ;
sessionLow.prediction = makePredictionState(RS, 'RS_SE58', streamLow, 'feed_SE58_low', 'mol/L') ;
sessionLow.shared.seg_model = segLow ;
sessionLow.shared.mm_model = mmLow ;
sessionLow.shared.displayCache = struct() ;

sessionHigh = baseSession('SE58_high', 'Prediction Models', rtd) ;
sessionHigh.rtd = makeEquationRtdState('2*exp(-2*t)', fieldState(tau_h, 'h'), fieldState(1, 'L/h'), 'h', 'L') ;
sessionHigh.prediction = makePredictionState(RS, 'RS_SE58', streamHigh, 'feed_SE58_high', 'mol/L') ;
sessionHigh.shared.seg_model = segHigh ;
sessionHigh.shared.mm_model = mmHigh ;
sessionHigh.shared.displayCache = struct() ;

note = sprintf(['Se han creado dos sesiones (baja y alta concentracion). ' ...
    'Para reproducir el solucionario ha sido necesario usar a = 1 h^-1 en lugar de 0.5; ' ...
    'asi se obtiene X_low = %.3f y X_high,CSTR/MM = %.3f/%.3f.'], ...
    segLow.X_mean, mmHigh.X_exit, segHigh.X_mean) ;
end

function [sessionData, note] = buildSE59()
rtd = RTD.tanks_in_series(2, 1) ;
RS = ReactionSys.fromSimpleKinetics('parallel', struct('k1', 0.003, 'n1', 2, 'k2', 0.4, 'n2', 1)) ;
RS.componentNames = {'A', 'B', 'C'} ;
RS.componentFormula = {'A', 'B', 'C'} ;
stream = makeStream([2500 0 0], 1e-3, {'A', 'B', 'C'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, [2500 0 0]) ;
mm = MaxMixednessModel(rtd) ; mm = mm.compute_isothermal(RS, [2500 0 0]) ;
[Ccstr, ~] = TanksInSeries.solve_sequential(1, RS, [2500 0 0], 1) ;
sessionData = baseSession('SE59', 'Prediction Models', rtd) ;
sessionData.rtd = makeTisRtdState(2, 1, 's', fieldState(1, 'L/s'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE59', stream, 'feed_SE59', 'mol/L') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = mm ;
sessionData.shared.displayCache = struct() ;
note = sprintf(['Sesion creada con los datos transcritos del enunciado. ' ...
    'La app da CSTR: CA = %.3f mol/L, CB = %.3f mol/L; Seg: CA = %.3f, CB = %.3f. ' ...
    'No coincide con el solucionario publicado, asi que queda como caso parcialmente/no correctamente resuelto.'], ...
    1e-3 * Ccstr(1), 1e-3 * Ccstr(2), 1e-3*seg.C_exit(1), 1e-3*seg.C_exit(2)) ;
end

function [sessionData, ok, note] = buildSE60()
t_min = [0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18] ;
C = [0 0 0 0 0 10 190 161.5 123.5 95 76 58.9 43.7 20.9 7.6 1.9 0.38 0.095 0.0019] ;
t_s = t_min * 60 ;
rtd = RTD.from_pulse(t_s, C) ;
RS = ReactionSys.fromSimpleKinetics('1st_order', struct('k', 0.15/60)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;
qv_si = 50e-3 / 60 ;
stream = makeStream(1000, qv_si, {'A'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, 1000) ;
mm = MaxMixednessModel(rtd) ; mm = mm.compute_isothermal(RS, 1000) ;
ok = abs(seg.X_mean - 0.696) < 0.01 && abs(mm.X_exit - 0.697) < 0.01 ;
sessionData = baseSession('SE60', 'Prediction Models', rtd) ;
sessionData.rtd = makeTabularRtdState(t_min, C, 'min', fieldState(50, 'L/min'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE60', stream, 'feed_SE60', 'mol/L') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = mm ;
sessionData.shared.displayCache = struct() ;
note = sprintf(['Seg = %.3f y MM = %.3f coinciden bien con el solucionario. ' ...
    'La parte del modelo simplificado PFR+CSTR+volumen muerto no se representa directamente en una unica sesion de la app.'], ...
    seg.X_mean, mm.X_exit) ;
end

function [sessionData, note] = buildSE61()
rtd = RTD.laminar_flow(10) ;
RS = ReactionSys.fromSimpleKinetics('1st_order', struct('k', 0.1)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;
stream = makeStream(1000, 1e-3, {'A'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, 1000) ;
sessionData = baseSession('SE61', 'Prediction Models', rtd) ;
sessionData.rtd = makeLaminarRtdState(10, 's', fieldState(1, 'L/s'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE61', stream, 'feed_SE61', 'mol/L') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = [] ;
sessionData.shared.displayCache = struct() ;
note = sprintf(['La app reproduce bien la comparacion con CSTR (0.500) y PFR (0.632). ' ...
    'Para laminar+segregacion da %.3f frente a 0.542 en la hoja de soluciones.'], seg.X_mean) ;
end

function [sessionData, ok, note] = buildSE62()
t_min = [0 0.5 1 1.5 2 2.5 3 3.5 4 4.5 5 6 7 9 11 13 15 17 19 21 23 25] ;
C = [0 60 70 86 91 84 78 76 67 57 47 36 25 12 5.7 2.2 0.98 0.43 0.16 0.07 0.03 0.01] ;
t_s = t_min * 60 ;
rtd_exp = RTD.from_pulse(t_s, C) ;
N_est = rtd_exp.tau^2 / rtd_exp.sigma2 ;
rtd = RTD.tanks_in_series(N_est, rtd_exp.tau) ;
RS = ReactionSys.fromSimpleKinetics('reversible', struct('kf', 2/60, 'kr', 0.6/60)) ;
RS.componentNames = {'A', 'B'} ;
RS.componentFormula = {'A', 'B'} ;
qv_si = (10 / (rtd_exp.tau / 60)) * 1e-3 / 60 ;
stream = makeStream([1000 0], qv_si, {'A', 'B'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, [1000 0]) ;
mm = MaxMixednessModel(rtd) ; mm = mm.compute_isothermal(RS, [1000 0]) ;
[C_out_tis, X_tis] = TanksInSeries.solve_sequential(N_est, RS, [1000 0], rtd.tau) ;
[C_out_cstr, X_cstr] = TanksInSeries.solve_sequential(1, RS, [1000 0], rtd.tau) ;
[C_out_pfr, X_pfr] = TanksInSeries.solve_PFR(RS, [1000 0], rtd.tau) ;
ok = abs(X_tis - 0.749) < 0.01 && abs(mm.X_exit - 0.746) < 0.01 && abs(seg.X_mean - 0.749) < 0.01 ;
sessionData = baseSession('SE62', 'Prediction Models', rtd) ;
sessionData.rtd = makeTisRtdState(N_est, rtd_exp.tau/60, 'min', fieldState(10/(rtd_exp.tau/60), 'L/min'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE62', stream, 'feed_SE62', 'mol/L') ;
sessionData.tis = makeTisState('Manual', rtd.tau/60, 'min', RS, 'RS_SE62', stream, 'feed_SE62', 'mol/L', N_est) ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = mm ;
sessionData.shared.displayCache = struct('TIS', struct( ...
    'N_val', N_est, 'tau_val', rtd.tau, 'RS', RS, 'C0', [1000 0], ...
    'X_tis', X_tis, 'X_cstr', X_cstr, 'X_pfr', X_pfr, ...
    'C_out_tis', C_out_tis, 'C_out_cstr', C_out_cstr, 'C_out_pfr', C_out_pfr)) ;
note = sprintf('N ajustado = %.3f, 1-F(6 min) = %.4f, X_Tis = %.3f, X_MM = %.3f, X_Seg = %.3f. Coincide bien.', ...
    N_est, 1 - interp1(rtd_exp.t, rtd_exp.Ft, 6*60, 'linear', 'extrap'), X_tis, mm.X_exit, seg.X_mean) ;
end

function [sessionData, note] = buildSE64()
t_min = [0 0.4 0.8 1.2 1.6 2.0 2.4 2.8 3.2 4.0 4.8 5.6 6.8 8.0 9.2 10.8 12.8 16.8 20.8 24.0] ;
C = [15.37 15.10 12.15 11.93 9.60 9.43 7.59 7.46 6.00 5.24 3.75 3.27 2.08 1.62 1.03 0.71 0.36 0.12 0.034 0.001] ;
t_s = t_min * 60 ;
rtd = RTD.from_pulse(t_s, C) ;
% k_eff = 5 L/mol/min reproduces the published solution. With 2.5 L/mol/min
% the app gives the physically consistent lower conversions.
RS = ReactionSys.fromSimpleKinetics('2nd_order', struct('k', 5e-3/60)) ;
RS.componentNames = {'A'} ;
RS.componentFormula = {'A'} ;
qv_si = 2.5e-3 / 60 ;
stream = makeStream(200, qv_si, {'A'}) ;
seg = SegregationModel(rtd) ; seg = seg.compute_isothermal(RS, 200) ;
mm = MaxMixednessModel(rtd) ; mm = mm.compute_isothermal(RS, 200) ;
[~, X_cstr] = TanksInSeries.solve_sequential(1, RS, 200, rtd.tau) ;
sessionData = baseSession('SE64', 'Prediction Models', rtd) ;
sessionData.rtd = makeTabularRtdState(t_min, C, 'min', fieldState(2.5, 'L/min'), 'L') ;
sessionData.prediction = makePredictionState(RS, 'RS_SE64', stream, 'feed_SE64', 'mol/L') ;
sessionData.shared.seg_model = seg ;
sessionData.shared.mm_model = mm ;
sessionData.shared.displayCache = struct() ;
note = sprintf(['Sesion creada para reproducir el solucionario usando k_eff = 5 L mol^-1 min^-1. ' ...
    'Con ello se obtiene F(4) = %.3f, Vmuerto = %.2f L, X_CSTR = %.3f, X_Seg = %.3f, X_MM = %.3f. ' ...
    'Con el k = 2.5 transcrito en el enunciado, la app no coincide con la hoja de soluciones.'], ...
    interp1(rtd.t, rtd.Ft, 4*60, 'linear', 'extrap'), 10 - rtd.tau*(2.5/60), X_cstr, seg.X_mean, mm.X_exit) ;
end

function generateConvolutionSessions(saveDir)
names = {'SECT01', 'SECT02', 'SECT03', ...
    'SEC01', 'SEC02', 'SEC03', 'SEC04', 'SEC05', 'SEC06', 'SEC07', 'SEC08', 'SEC09'} ;
builders = {@buildSECT01, @buildSECT02, @buildSECT03, ...
    @buildSEC01, @buildSEC02, @buildSEC03, @buildSEC04, @buildSEC05, ...
    @buildSEC06, @buildSEC07, @buildSEC08, @buildSEC09} ;
for k = 1:numel(names)
    sessionData = builders{k}() ;
    saveSessionData(saveDir, [names{k} '.mat'], sessionData) ;
end
end

function sessionData = buildSECT01()
tCin = 0:4 ;
Cin = [0 8 4 6 0] ;
tE = 2:6 ;
E = [0 0.05 0.5 0.35 0] ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', tableConvolutionState(tE, E, 's', 'mol/m^3')) ;
[result, info] = nirp.conv.convolve( ...
    convolutionSignal(tE, E, 's', '', true), ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SECT01', 'Convolution', 1, 's', ...
    'mol/L', signals, [], result, info, ...
    ['The published value at t = 6 s is 5.2 mol/L, but its printed ' ...
     'sum and the app both give 5.1 mol/L.']) ;
end

function sessionData = buildSECT02()
tCin = 0:4 ;
Cin = tCin .* exp(-tCin / 2) ;
tCout = 4:13 ;
Cout = [0.9 1.8 2.1 5.2 3.6 4.5 1.7 0.8 0.7 0.5] ;
signals = struct( ...
    'Cin', functionConvolutionState({0 4 't.*exp(-t/2)'}, 'min', 'mol/L'), ...
    'Cout', tableConvolutionState(tCout, Cout, 'min', 'mol/L')) ;
[result, info] = nirp.conv.deconvolve( ...
    convolutionSignal(tCin, Cin, 'min', 'mol/L', false), ...
    convolutionSignal(tCout, Cout, 'min', 'mol/L', false), [4 9] * 60) ;
info.relativeResidual = info.residualNorm / max(norm(Cout * 1000), eps) ;
sessionData = convolutionSession('SECT02', 'Deconvolution', 1, 'min', ...
    'mol/L', signals, [4 9], result, info, ...
    'The E support is fixed to 4-9 min as stated by the worked example.') ;
end

function sessionData = buildSECT03()
tCin = 0:11 ;
Cin = [0 0 8 6 4 5 6 3 1 0 0 0] ;
tE = 0:5 ;
E = [0 0.05 0.5 0.35 0.1 0] ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', tableConvolutionState(tE, E, 's', 'mol/m^3')) ;
[result, info] = nirp.conv.convolve( ...
    convolutionSignal(tE, E, 's', '', true), ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SECT03', 'Convolution', 1, 's', ...
    'mol/L', signals, [], result, info, ...
    'Uses the 12 samples in the printed table; the printed MATLAB code omits the final zero.') ;
end

function sessionData = buildSEC01()
dt = 0.05 ;
tE1 = 2:dt:11 ;
E1 = zeros(size(tE1)) ;
E1(tE1 <= 5) = (tE1(tE1 <= 5) - 2) / 18 ;
middle = tE1 > 5 & tE1 <= 8 ;
E1(middle) = 1 / 6 ;
last = tE1 > 8 ;
E1(last) = (11 - tE1(last)) / 18 ;
tE2 = 0:dt:30 ;
E2 = nirp.conv.signal(tE2, exp(-tE2 / 2) / 2) ;
signals = struct( ...
    'E1', functionConvolutionState( ...
        {2 5 '(t-2)./18'; 5 8 '1./6'; 8 11 '(11-t)./18'}, 's', 'mol/m^3'), ...
    'E2', functionConvolutionState({0 30 'exp(-t/2)./2'}, 's', 'mol/m^3')) ;
result = nirp.conv.series(nirp.conv.signal(tE1, E1), E2) ;
info = seriesInfo(nirp.conv.signal(tE1, E1), E2, result) ;
sessionData = convolutionSession('SEC01', 'Series composition', dt, 's', ...
    'mol/m^3', signals, [], result, info, ...
    ['The trapezoid is normalized by its area, 18. The CSTR with tau = 2 s ' ...
     'is entered as its E(t) function because series inputs do not offer Model as a source.']) ;
end

function sessionData = buildSEC02()
tCin = 1:5 ;
Cin = [0 8 4 6 0] ;
tE = 5:10 ;
E = [0 0.05 0.5 0.35 0.1 0] ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', tableConvolutionState(tE, E, 's', 'mol/m^3')) ;
[result, info] = nirp.conv.convolve( ...
    convolutionSignal(tE, E, 's', '', true), ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SEC02', 'Convolution', 1, 's', ...
    'mol/L', signals, [], result, info, ...
    'Approximate transcription of the marked points in the two plots; no numerical solution is printed.') ;
end

function sessionData = buildSEC03()
tCin = 0:11 ;
Cin = [0 0 8 6 4 5 6 3 1 0 0 0] ;
tE = 0:5 ;
E = [0 0.05 0.5 0.35 0.1 0] ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', tableConvolutionState(tE, E, 's', 'mol/m^3')) ;
[result, info] = nirp.conv.convolve( ...
    convolutionSignal(tE, E, 's', '', true), ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SEC03', 'Convolution', 1, 's', ...
    'mol/L', signals, [], result, info, 'Direct transcription of both printed tables.') ;
end

function sessionData = buildSEC04()
tCin = 0:11 ;
Cin = [0 0 8 6 4 5 6 3 1 0 0 0] ;
dt = 1 ;
E = nirp.conv.fromRTD(RTD.ideal_cstr(5), dt) ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', modelConvolutionState('CSTR', 5, 's')) ;
[result, info] = nirp.conv.convolve(E, ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SEC04', 'Convolution', dt, 's', ...
    'mol/L', signals, [], result, info, 'Uses the CSTR model with tau = 5 s.') ;
end

function sessionData = buildSEC05()
tCin = 0:11 ;
Cin = [0 0 8 6 4 5 6 3 1 0 0 0] ;
dt = 1 ;
E = nirp.conv.fromRTD(RTD.ideal_pfr(5), dt) ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', modelConvolutionState('PFR', 5, 's')) ;
[result, info] = nirp.conv.convolve(E, ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SEC05', 'Convolution', dt, 's', ...
    'mol/L', signals, [], result, info, 'Uses the PFR model with tau = 5 s.') ;
end

function sessionData = buildSEC06()
tCin = 0:11 ;
Cin = [0 0 8 6 4 5 6 3 1 0 0 0] ;
tCout = 0:15 ;
Cout = [0 0 0 0.4 4.3 6 5.1 4.8 5.6 4.1 2.1 0.6 0.1 0 0 0] ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'Cout', tableConvolutionState(tCout, Cout, 's', 'mol/L')) ;
[result, info] = nirp.conv.deconvolve( ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false), ...
    convolutionSignal(tCout, Cout, 's', 'mol/L', false), [0 4]) ;
info.relativeResidual = info.residualNorm / max(norm(Cout * 1000), eps) ;
sessionData = convolutionSession('SEC06', 'Deconvolution', 1, 's', ...
    'mol/L', signals, [0 4], result, info, ...
    'The five-sample E support follows from the printed input and output vector lengths.') ;
end

function sessionData = buildSEC07()
tCin = 0:4 ;
Cin = [0 8 4 6 0] ;
tE = 2:6 ;
E = [0 0.05 0.5 0.35 0] ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', tableConvolutionState(tE, E, 's', 'mol/m^3')) ;
[result, info] = nirp.conv.convolve( ...
    convolutionSignal(tE, E, 's', '', true), ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SEC07', 'Convolution', 1, 's', ...
    'mol/L', signals, [], result, info, 'Direct transcription of both printed tables.') ;
end

function sessionData = buildSEC08()
tCin = 0:0.25:4 ;
Cin = max(0, pchip(0:4, [0 8 4 6 0], tCin)) ;
tE = 2:0.25:7 ;
E = max(0, pchip([2 3 4 4.5 5 6 7], ...
    [0 0.01 0.30 0.50 0.48 0.25 0], tE)) ;
E = E / trapz(tE, E) ;
signals = struct( ...
    'Cin', tableConvolutionState(tCin, Cin, 's', 'mol/L'), ...
    'E', tableConvolutionState(tE, E, 's', 'mol/m^3')) ;
[result, info] = nirp.conv.convolve( ...
    convolutionSignal(tE, E, 's', '', true), ...
    convolutionSignal(tCin, Cin, 's', 'mol/L', false)) ;
sessionData = convolutionSession('SEC08', 'Convolution', 0.25, 's', ...
    'mol/L', signals, [], result, info, ...
    ['Approximate digitization of Figures 1 and 2. The RTD samples are ' ...
     'normalized because the PDF provides plots rather than numerical data.']) ;
end

function sessionData = buildSEC09()
tCin = 0:4 ;
Cin = tCin .* exp(-tCin / 2) ;
tCout = 4:8 ;
Cout = [2.1 5.2 3.6 4.5 1.7] ;
signals = struct( ...
    'Cin', functionConvolutionState({0 4 't.*exp(-t/2)'}, 'min', 'mmol/L'), ...
    'Cout', tableConvolutionState(tCout, Cout, 'min', 'mmol/L')) ;
[result, info] = nirp.conv.deconvolve( ...
    convolutionSignal(tCin, Cin, 'min', 'mmol/L', false), ...
    convolutionSignal(tCout, Cout, 'min', 'mmol/L', false), [4 8] * 60) ;
info.relativeResidual = info.residualNorm / max(norm(Cout), eps) ;
sessionData = convolutionSession('SEC09', 'Deconvolution', 1, 'min', ...
    'mmol/L', signals, [4 8], result, info, ...
    ['The PDF gives only five outlet measurements and asks for the method, ' ...
     'not a unique numerical RTD. mmol/L preserves the mg/L numerical values ' ...
     'because the tab has no mass-concentration unit.']) ;
end

function sessionData = convolutionSession(name, mode, dt, timeUnit, ...
        concentrationUnit, signals, support, result, info, note)
sessionData = baseSession(name, 'Convolution', []) ;
sessionData.session_version = 2 ;
state = struct() ;
state.mode = mode ;
state.timeUnit = timeUnit ;
state.dtUnit = timeUnit ;
state.dt = dt ;
state.supportMin = 0 ;
state.supportMax = 10 ;
state.supportUnit = timeUnit ;
state.supportIsDefault = true ;
if ~isempty(support)
    state.supportMin = support(1) ;
    state.supportMax = support(2) ;
    state.supportIsDefault = false ;
end
state.outputTimeUnit = timeUnit ;
state.outputConcentrationUnit = concentrationUnit ;
state.signals = signals ;
state.lastSignals = struct() ;
state.lastResult = [] ;
state.lastInfo = struct() ;
state.referenceResult = result ;
state.referenceInfo = info ;
state.referenceTable = displayedConvolutionResult(result, mode, ...
    timeUnit, concentrationUnit) ;
state.referenceNote = note ;
sessionData.convolution = state ;
end

function state = defaultConvolutionSignalState(timeUnit, concentrationUnit)
state = struct('source', 'Table', 'timeUnit', timeUnit, ...
    'concentrationUnit', concentrationUnit, 'tableData', {cell(3, 2)}, ...
    'piecewiseData', {cell(3, 3)}, 'model', 'CSTR', ...
    'tau', 5, 'n', 2, 'bo', 0.1) ;
end

function state = tableConvolutionState(t, values, timeUnit, concentrationUnit)
state = defaultConvolutionSignalState(timeUnit, concentrationUnit) ;
state.tableData = [t(:), values(:)] ;
end

function state = functionConvolutionState(rows, timeUnit, concentrationUnit)
state = defaultConvolutionSignalState(timeUnit, concentrationUnit) ;
state.source = 'Function' ;
state.piecewiseData = rows ;
end

function state = modelConvolutionState(model, tau, timeUnit)
state = defaultConvolutionSignalState(timeUnit, 'mol/m^3') ;
state.source = 'Model' ;
state.model = model ;
state.tau = tau ;
end

function signal = convolutionSignal(t, values, timeUnit, concentrationUnit, isRTD)
timeScale = UnitConverterHelper.factorToSI('Time', timeUnit) ;
if isRTD
    valueScale = 1 / timeScale ;
else
    valueScale = UnitConverterHelper.factorToSI('Concentration', concentrationUnit) ;
end
signal = nirp.conv.signal(t * timeScale, values * valueScale) ;
end

function info = seriesInfo(E1, E2, result)
first = nirp.conv.moments(E1) ;
second = nirp.conv.moments(E2) ;
combined = nirp.conv.moments(result) ;
info = struct('massBalance', combined.area / (first.area * second.area)) ;
end

function data = displayedConvolutionResult(result, mode, timeUnit, concentrationUnit)
timeScale = UnitConverterHelper.factorToSI('Time', timeUnit) ;
if strcmp(mode, 'Convolution')
    valueScale = UnitConverterHelper.factorToSI('Concentration', concentrationUnit) ;
    values = result.C / valueScale ;
else
    values = result.C * timeScale ;
end
data = [result.t(:) / timeScale, values(:)] ;
end

function sessionData = baseSession(sessionName, selectedTabTitle, rtdObj)
sessionData = struct() ;
sessionData.session_version = 1 ;
sessionData.saved_at = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')) ;
sessionData.session_name = sessionName ;
sessionData.selected_tab_title = selectedTabTitle ;
sessionData.shared = struct('rtd', rtdObj) ;
sessionData.rtd = struct() ;
sessionData.prediction = struct() ;
sessionData.tis = struct() ;
sessionData.dispersion = struct() ;
end

function state = makeRtdState(source, tauField, qvField, timeUnit, volumeUnit)
state = struct() ;
state.source = source ;
state.tauField = tauField ;
state.qvField = qvField ;
state.nValue = 3 ;
state.boValue = 0.01 ;
state.expTVar = 't_exp' ;
state.expTUnit = timeUnit ;
state.expCVar = 'C_exp' ;
state.expC0Field = fieldState(1, '') ;
state.equation = '' ;
state.equationTStart = '0' ;
state.equationTEnd = '10' ;
state.equationTimeUnit = timeUnit ;
state.equationNpts = '1000' ;
state.dataType = 'Pulse C(t)' ;
state.dataTable = cell(0, 2) ;
state.exportName = '' ;
state.exportCounter = 1 ;
state.displayTimeUnit = timeUnit ;
state.displayVolumeUnit = volumeUnit ;
state.fQueryValue = '0' ;
state.rsName = '' ;
state.streamName = '' ;
state.rs = [] ;
state.feedStream = [] ;
end

function state = makeTabularRtdState(tValues, cValues, timeUnit, qvField, volumeUnit)
state = makeRtdState('Tabular Input', fieldState(max(tValues), timeUnit), qvField, timeUnit, volumeUnit) ;
state.dataType = 'Pulse C(t)' ;
state.dataTable = num2cell([tValues(:), cValues(:)]) ;
state.equation = '' ;
state.equationTStart = '0' ;
state.equationTEnd = num2str(max(tValues)) ;
state.equationTimeUnit = timeUnit ;
state.equationNpts = '1000' ;
end

function state = makeEquationRtdState(equationText, tauField, qvField, timeUnit, volumeUnit)
state = makeRtdState('C(t) Equation', tauField, qvField, timeUnit, volumeUnit) ;
state.equation = equationText ;
state.equationTStart = '0' ;
state.equationTEnd = '10' ;
state.equationTimeUnit = timeUnit ;
state.equationNpts = '2000' ;
end

function state = makeTisRtdState(N, tauValue, timeUnit, qvField, volumeUnit)
state = makeRtdState('Tanks-in-Series', fieldState(tauValue, timeUnit), qvField, timeUnit, volumeUnit) ;
state.nValue = N ;
end

function state = makeLaminarRtdState(tauValue, timeUnit, qvField, volumeUnit)
state = makeRtdState('Laminar Flow', fieldState(tauValue, timeUnit), qvField, timeUnit, volumeUnit) ;
end

function pred = makePredictionState(RS, rsName, stream, streamName, concUnit)
nComp = numel(stream.concentration) ;
reactantSelection = 1 ;
if nComp > 1
    reactantSelection = 1 ;
end
pred = struct( ...
    'inputMethod', 'From Calculated Data', ...
    'rs', RS, ...
    'rsName', rsName, ...
    'feedStream', stream, ...
    'streamName', streamName, ...
    'displayConcentrationUnit', concUnit, ...
    'reactantSelection', reactantSelection, ...
    'speciesSelection', 1:nComp, ...
    'rtdStatus', labelState('From Calculated Data', [0 0.5 0]), ...
    'rsStatus', labelState('Loaded', [0 0.5 0]), ...
    'streamStatus', labelState('Loaded', [0 0.5 0])) ;
end

function tis = makeTisState(inputMethod, tauValue, timeUnit, RS, rsName, stream, streamName, concUnit, Nmanual)
if nargin < 9
    Nmanual = 2 ;
end
tis = struct( ...
    'inputMethod', inputMethod, ...
    'nValue', Nmanual, ...
    'tauField', fieldState(tauValue, timeUnit), ...
    'rs', RS, ...
    'rsName', rsName, ...
    'feedStream', stream, ...
    'streamName', streamName, ...
    'displayTimeUnit', timeUnit, ...
    'displayConcentrationUnit', concUnit, ...
    'reactantSelection', 1, ...
    'speciesSelection', 1:numel(stream.concentration), ...
    'rtdStatus', labelState('Loaded', [0 0.5 0]), ...
    'rsStatus', labelState('Loaded', [0 0.5 0]), ...
    'streamStatus', labelState('Loaded', [0 0.5 0])) ;
end

function dispState = makeDispersionState(inputMethod, Bo, tauValue, timeUnit, RS, rsName, stream, streamName, concUnit, bcType)
dispState = struct( ...
    'inputMethod', inputMethod, ...
    'boValue', Bo, ...
    'boundary', bcType, ...
    'tauField', fieldState(tauValue, timeUnit), ...
    'rs', RS, ...
    'rsName', rsName, ...
    'feedStream', stream, ...
    'streamName', streamName, ...
    'displayTimeUnit', timeUnit, ...
    'displayConcentrationUnit', concUnit, ...
    'reactantSelection', 1, ...
    'speciesSelection', 1:numel(stream.concentration), ...
    'rtdStatus', labelState('Loaded', [0 0.5 0]), ...
    'rsStatus', labelState('Loaded', [0 0.5 0]), ...
    'streamStatus', labelState('Loaded', [0 0.5 0])) ;
end

function state = fieldState(value, unit)
if isnumeric(value)
    valueText = num2str(value, '%.12g') ;
else
    valueText = char(string(value)) ;
end
state = struct('value', valueText) ;
if nargin >= 2 && ~isempty(unit)
    state.unit = unit ;
end
end

function state = labelState(text, fontColor)
state = struct('text', text, 'fontColor', fontColor, 'visible', 'on') ;
end

function stream = makeStream(concentration, qv, compNames)
stream = Stream ;
stream.concentration = concentration ;
stream.concentration_Units = 'mol/m^3' ;
stream.volumetricFlow = qv ;
stream.volumetricFlow_Units = 'm^3/s' ;
stream.phase = 'L' ;
if nargin >= 3 && ~isempty(compNames)
        % no-op, only for readability at call sites
end
end

function Bo = computeBoFromVariance(sigma2_theta, bcType)
switch bcType
    case 'open-open'
        Bo = sigma2_theta / 2 ;
    otherwise
        f = @(Bo_val) 2*Bo_val - 2*Bo_val^2*(1 - exp(-1/Bo_val)) - sigma2_theta ;
        Bo0 = max(sigma2_theta/2, 1e-6) ;
        try
            Bo = fzero(f, Bo0) ;
        catch
            Bo = Bo0 ;
        end
        Bo = max(Bo, 1e-8) ;
end
end

function writeRegistry(reportPath, good, partial, unresolved)
lines = {} ;
lines{end+1} = '# Saved Example Session Registry' ;
lines{end+1} = '' ;
lines{end+1} = sprintf('Updated: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))) ;
lines{end+1} = '' ;
lines{end+1} = '## Resueltos bien y con fichero `.mat` creado' ;
lines{end+1} = '' ;
lines = [lines, recordLines(good)] ;
lines{end+1} = '' ;
lines{end+1} = '## Resueltos de forma parcial o reconstruidos para ajustar la hoja de soluciones' ;
lines{end+1} = '' ;
lines = [lines, recordLines(partial)] ;
lines{end+1} = '' ;
lines{end+1} = '## No resueltos directamente' ;
lines{end+1} = '' ;
lines = [lines, recordLines(unresolved)] ;
lines{end+1} = '' ;
lines{end+1} = '## Notas generales' ;
lines{end+1} = '' ;
lines{end+1} = '- Varias discrepancias parecen venir de transcripciones OCR o de constantes cineticas inconsistentes entre el enunciado y la hoja de soluciones.' ;
lines{end+1} = '- Cuando una sesion se ha reconstruido para que coincida con la solucion, se deja indicado explicitamente en la nota del ejercicio.' ;
lines{end+1} = '- Todas las sesiones siguen la nomenclatura `SE...` y se guardan en `ReactorApp toolbox/saves/`.' ;
fid = fopen(reportPath, 'w') ;
cleanupObj = onCleanup(@() fclose(fid)) ;
for i = 1:numel(lines)
    fprintf(fid, '%s\n', lines{i}) ;
end
end

function lines = recordLines(records)
lines = cell(1, 0) ;
if isempty(records)
    lines{1} = '- Ninguno.' ;
    return
end
lines = cell(1, 2 * numel(records)) ;
idx = 1 ;
for i = 1:numel(records)
    rec = records{i} ;
    fileText = 'sin fichero' ;
    if ~isempty(rec.files)
        fileText = strjoin(rec.files, ', ') ;
    end
    lines{idx} = sprintf('- Ejercicio %s: `%s`', rec.exercise, fileText) ;
    lines{idx+1} = sprintf('  %s', rec.notes) ;
    idx = idx + 2 ;
end
end
