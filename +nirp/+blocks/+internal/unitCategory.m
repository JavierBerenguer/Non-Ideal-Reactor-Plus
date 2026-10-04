function category = unitCategory(unit,allowedCategories)
%UNITCATEGORY Return the UnitConverterHelper category containing a unit.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 2, 2026. Last update: October 2, 2026
% =========================================================================

    unit = char(string(unit)) ;
    category = '' ;
    for i = 1:numel(allowedCategories)
        candidate = allowedCategories{i} ;
        if any(strcmp(UnitConverterHelper.getUnits(candidate),unit))
            category = candidate ;
            return
        end
    end
    error('nirp:blocks:invalidUnit','Unknown or unsupported unit "%s".',unit) ;
end
