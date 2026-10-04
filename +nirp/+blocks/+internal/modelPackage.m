function [model,pkg,rs] = modelPackage()
%MODELPACKAGE Read and validate the package attached to the current model.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    model = bdroot(gcb) ;
    try
        dictionary = get_param(model,'DataDictionary') ;
        if isempty(dictionary)
            error('nirp:blocks:missingDictionary', ...
                'Model "%s" has no data dictionary. Create it with nirp.flowsheet.new.',model) ;
        end
        pkg = Simulink.data.evalinGlobal(model,'nirpPackage') ;
    catch exception
        if strcmp(exception.identifier,'nirp:blocks:missingDictionary')
            rethrow(exception) ;
        end
        error('nirp:blocks:missingDictionary', ...
            'Model "%s" has no readable nirpPackage data dictionary: %s', ...
            model,exception.message) ;
    end
    nirp.pkg.validate(pkg) ;
    rs = nirp.pkg.toReactionSys(pkg) ;
end
