function tf = isValid(s)
%ISVALID Return true when input is a structurally valid NIRP stream.
%   Empty (status 0) and warning (status -1) streams are structurally valid.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    try
        nirp.stream.validate(s) ;
        tf = true ;
    catch exception
        if strcmp(exception.identifier,'nirp:stream:invalid')
            tf = false ;
        else
            rethrow(exception) ;
        end
    end
end
