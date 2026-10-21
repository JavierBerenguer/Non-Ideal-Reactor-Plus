function modelFile = openExample(name,varargin)
%OPENEXAMPLE Generate or restore a tracer example in a writable folder.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    p=inputParser;addParameter(p,'Folder','');addParameter(p,'NoWindow',false);addParameter(p,'PromptFcn',[]);parse(p,varargin{:});
    [names,descriptions]=nirp.tracerflowsheet.exampleNames();name=string(name);
    if ~isscalar(name)||~any(name==names),error('nirp:tracerflowsheet:UnknownExample','Unknown tracer example "%s".',name);end
    folder=char(string(p.Results.Folder));if isempty(folder),folder=defaultFolder();end
    if ~isfolder(folder),mkdir(folder),end
    modelFile=fullfile(folder,[char(name) '.slx']);dictionaryFile=fullfile(folder,[char(name) '.sldd']);
    if isfile(modelFile)&&isfile(dictionaryFile)
        message=sprintf('Example "%s" already exists. Restore the original example (your changes in it will be lost) or open your copy?',descriptions(names==name));
        if ~isempty(p.Results.PromptFcn),answer=char(string(p.Results.PromptFcn(message)));
        elseif p.Results.NoWindow||~usejava('desktop'),answer='Restore';
        else,answer=questdlg(message,'Open tracer example','Restore','Open existing','Cancel','Open existing');end
        if isempty(answer)||strcmp(answer,'Cancel'),modelFile='';return,end
        if strcmp(answer,'Open existing'),loadExample(modelFile,name,p.Results.NoWindow);return,end
    end
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));simFolder=fullfile(root,'simulink');
    if ~contains([path pathsep],[simFolder pathsep]),addpath(simFolder),end
    build_tracer_examples(folder,name);loadExample(modelFile,name,p.Results.NoWindow);
end
function folder=defaultFolder(),folder=char(userpath);if contains(folder,pathsep),folder=char(extractBefore(string(folder),pathsep));end;if isempty(folder),folder=tempdir;end;folder=fullfile(folder,'NIRP_tracer_examples');end
function loadExample(file,name,noWindow),folder=fileparts(file);if contains([path pathsep],[folder pathsep]),rmpath(folder),end;addpath(folder,'-begin');load_system(file);if ~noWindow&&usejava('desktop'),open_system(char(name)),end,end
