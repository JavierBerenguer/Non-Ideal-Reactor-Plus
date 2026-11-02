function modelFile = newFromDialog(varargin)
%NEWFROMDIALOG Ask for a destination and create a blank tracer flowsheet.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    p=inputParser;addParameter(p,'ModelName','');addParameter(p,'Folder','');addParameter(p,'OpenModel',true);parse(p,varargin{:});
    name=char(string(p.Results.ModelName));folder=char(string(p.Results.Folder));
    if isempty(name)
        if ~usejava('desktop'),error('nirp:tracerflowsheet:noDesktop','Creating a named flowsheet requires MATLAB desktop.');end
        [file,folder]=uiputfile('*.slx','New tracer flowsheet','tracer_flowsheet.slx');if isequal(file,0),modelFile='';return,end
        [~,name]=fileparts(file);
    end
    [modelFile,~]=nirp.tracerflowsheet.new(name,folder,'OpenModel',p.Results.OpenModel);
end
