function diagnostic(model,block,count,varargin)
%DIAGNOSTIC Publish a block calculation count for tests and diagnostics.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    if evalin('base','exist(''nirpResults'',''var'')')
        results = evalin('base','nirpResults') ;
        if ~isstruct(results)
            results = struct() ;
        end
    else
        results = struct() ;
    end
    if ~isfield(results,'Diagnostics') || ~isstruct(results.Diagnostics)
        results.Diagnostics = struct() ;
    end
    key = matlab.lang.makeValidName([model '_' block]) ;
    item = struct('calculationCount',count) ;
    if nargin >= 4, item.lastOutput = varargin{1} ; end
    if nargin >= 5, item.lastInfo = varargin{2} ; end
    results.Diagnostics.(key) = item ;
    assignin('base','nirpResults',results) ;
end
