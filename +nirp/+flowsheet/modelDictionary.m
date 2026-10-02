function path = modelDictionary(model)
%MODELDICTIONARY Return the absolute data-dictionary path for a model.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    model = char(string(model)) ;
    if ~bdIsLoaded(model), load_system(model) ; end
    root = bdroot(model) ;
    dictionary = get_param(root,'DataDictionary') ;
    if isempty(dictionary)
        error('nirp:flowsheet:noDictionary', ...
            'Model "%s" has no data dictionary.',root) ;
    end
    if isfile(dictionary)
        path = dictionary ;
    else
        path = fullfile(fileparts(get_param(root,'FileName')),dictionary) ;
    end
end
