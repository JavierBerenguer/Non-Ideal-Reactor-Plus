function tables = showResults(model,varargin)
%SHOWRESULTS Return and optionally display Product result tables.
%   TABLES = nirp.flowsheet.showResults(MODEL) returns one table per Product
%   in nirpResults. Flow and concentration values use each Product block's
%   selected units; temperature and pressure are repeated per component.
%   ...showResults(MODEL,'NoWindow',true) never creates a UI window.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    if nargin < 1 || isempty(model), model = bdroot ; end
    noWindow = parseNoWindow(varargin{:}) ;
    if ~evalin('base','exist(''nirpResults'',''var'')')
        error('nirp:flowsheet:noResults', ...
            'No Product results are available. Run the flowsheet first.') ;
    end
    results = evalin('base','nirpResults') ;
    fields = fieldnames(results) ;
    tables = struct() ;
    for i = 1:numel(fields)
        item = results.(fields{i}) ;
        if ~isstruct(item) || ~isfield(item,'streamTable'), continue, end
        n = height(item.streamTable) ;
        conversion = NaN ;
        if ~isempty(item.conversion), conversion = item.conversion ; end
        tableValue = item.streamTable ;
        tableValue.FUnit = repmat(string(item.units.F),n,1) ;
        tableValue.CUnit = repmat(string(item.units.C),n,1) ;
        tableValue.T = repmat(item.T,n,1) ;
        tableValue.TUnit = repmat(string(item.units.T),n,1) ;
        tableValue.P = repmat(item.P,n,1) ;
        tableValue.PUnit = repmat(string(item.units.P),n,1) ;
        tableValue.Phase = repmat(string(item.phase),n,1) ;
        tableValue.Status = repmat(item.status,n,1) ;
        tableValue.Conversion = repmat(conversion,n,1) ;
        tables.(fields{i}) = tableValue ;
    end
    if isempty(fieldnames(tables))
        error('nirp:flowsheet:noResults','nirpResults contains no Product results.') ;
    end
    if noWindow || ~usejava('desktop'), return, end

    figureHandle = uifigure('Name',sprintf('NIRP results - %s',char(string(model))), ...
        'Position',[100 100 1050 420]) ;
    tabs = uitabgroup(figureHandle,'Position',[10 10 1030 400]) ;
    names = fieldnames(tables) ;
    for i = 1:numel(names)
        tab = uitab(tabs,'Title',names{i}) ;
        uitable(tab,'Data',tables.(names{i}),'Position',[10 10 1000 350]) ;
    end
end

function value = parseNoWindow(varargin)
    value = false ;
    if mod(numel(varargin),2) ~= 0
        error('nirp:flowsheet:invalidOption','Options must be name-value pairs.') ;
    end
    for i = 1:2:numel(varargin)
        if ~strcmpi(char(string(varargin{i})),'NoWindow')
            error('nirp:flowsheet:invalidOption', ...
                'Unknown option "%s".',char(string(varargin{i}))) ;
        end
        supplied = varargin{i+1} ;
        if ~isscalar(supplied) || (~islogical(supplied) && ~isnumeric(supplied))
            error('nirp:flowsheet:invalidOption','NoWindow must be scalar logical.') ;
        end
        value = logical(supplied) ;
    end
end
