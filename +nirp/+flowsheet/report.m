function T = report()
%REPORT Return one summary row for every Stream in nirpResults.Streams.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    if ~evalin('base','exist(''nirpResults'',''var'')')
        T = table() ; return
    end
    results = evalin('base','nirpResults') ;
    if ~isstruct(results) || ~isfield(results,'Streams') || ~isstruct(results.Streams)
        T = table() ; return
    end
    fields = fieldnames(results.Streams) ;
    names = strings(0,1) ; temperatures=[] ; pressures=[] ; statuses=[] ; conversions=[] ;
    temperatureUnits=strings(0,1); pressureUnits=strings(0,1) ;
    for i=1:numel(fields)
        item=results.Streams.(fields{i}) ;
        if ~isstruct(item) || ~isfield(item,'streamSI'), continue, end
        names(end+1,1)=string(fields{i}); temperatures(end+1,1)=item.T; pressures(end+1,1)=item.P;
        statuses(end+1,1)=item.status; if isempty(item.conversion),conversions(end+1,1)=NaN;else,conversions(end+1,1)=item.conversion;end
        temperatureUnits(end+1,1)=string(item.units.T); pressureUnits(end+1,1)=string(item.units.P);
    end
    T=table(names,temperatures,temperatureUnits,pressures,pressureUnits,statuses,conversions, ...
        'VariableNames',{'StreamName','T','TUnit','P','PUnit','Status','Conversion'}) ;
end
