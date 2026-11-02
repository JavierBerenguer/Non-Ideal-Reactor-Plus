function target = helpTarget(anchor)
%HELPTARGET Central location of the tracer flowsheet guide.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================
    anchor = string(anchor) ;
    switch anchor
        case "flowsheet"
            page = 'tracer-flowsheet.html' ;
        case "source"
            page = 'tracer-source.html' ;
        case "vessel"
            page = 'tracer-vessel.html' ;
        case "splitter"
            page = 'tracer-splitter.html' ;
        case "mixer"
            page = 'tracer-mixer.html' ;
        case "monitor"
            page = 'tracer-monitor-results.html' ;
        otherwise
            error('nirp:tracerflowsheet:UnknownHelpTarget', ...
                'No tracer flowsheet guide is registered for %s.', anchor) ;
    end
    target = ['guides/' page '#dialog'] ;
end
