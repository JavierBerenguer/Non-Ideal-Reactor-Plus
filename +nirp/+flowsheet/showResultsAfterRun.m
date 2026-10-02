function showResultsAfterRun(model)
%SHOWRESULTSAFTERRUN Display results when the Flowsheet mask requests it.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    if ~usejava('desktop'), return, end
    blocks = find_system(char(string(model)),'SearchDepth',1, ...
        'BlockType','SubSystem','Mask','on') ;
    for i = 1:numel(blocks)
        if any(strcmp(get_param(blocks{i},'MaskNames'),'ShowResultsAfterRun')) && ...
                strcmp(get_param(blocks{i},'ShowResultsAfterRun'),'on')
            nirp.flowsheet.showResults(model) ;
            return
        end
    end
end
