function [modelFile,dictionaryFile] = new(modelName,folder,varargin)
%NEW Create a tracer-only model and its NirpTracer dictionary.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    p=inputParser ; addParameter(p,'Dt',0.1) ; addParameter(p,'TFinal',10) ; addParameter(p,'OpenModel',true) ; parse(p,varargin{:}) ;
    if nargin<2||isempty(folder), folder=pwd ; end
    name=char(string(modelName)) ; if ~isvarname(name), error('nirp:tracerflowsheet:InvalidName','modelName must be a valid MATLAB identifier.'); end
    if ~isfolder(folder), mkdir(folder), end
    if ~contains([path pathsep],[char(folder) pathsep]), addpath(folder), end
    modelFile=fullfile(folder,[name '.slx']) ; dictionaryFile=fullfile(folder,[name '.sldd']) ;
    if isfile(modelFile)||isfile(dictionaryFile), error('nirp:tracerflowsheet:FileExists','Model or dictionary already exists.'); end
    grid=nirp.tracer.grid(p.Results.Dt,p.Results.TFinal) ; nirp.tracerflowsheet.writeDictionary(dictionaryFile,grid) ;
    new_system(name) ; cleanup=onCleanup(@()closeIfLoaded(name)) ; save_system(name,modelFile) ; set_param(name,'DataDictionary',[name '.sldd']) ;
    add_block('simulink/User-Defined Functions/MATLAB System',[name '/Tracer Flowsheet'], ...
        'System','nirp.tracerblocks.Flowsheet','Dt',num2str(grid.dt,17),'TFinal',num2str(grid.tFinal,17),'Position',[40 30 190 85]) ;
    nirp.tracerflowsheet.setupBlock([name '/Tracer Flowsheet']) ; save_system(name) ;
    if p.Results.OpenModel, open_system(name), end
    clear cleanup
end
function closeIfLoaded(name),if bdIsLoaded(name),close_system(name,0),end,end
