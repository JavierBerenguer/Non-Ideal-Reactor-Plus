function [values,origin,message] = closeProduct(values,total,powers,tol)
%CLOSEPRODUCT Complete one missing value in a product relationship.
%   [VALUES,ORIGIN,MESSAGE] = CLOSEPRODUCT(VALUES,TOTAL,POWERS,TOL)
%   closes PROD(VALUES.^POWERS) = TOTAL when exactly one value is NaN.
%   VALUES and TOTAL use mutually consistent units. POWERS is a real vector
%   of nonzero exponents. Missing data produces no message; MESSAGE reports
%   only invalid or inconsistent specifications. TOL defaults to 1e-9 and
%   is a relative tolerance (with an absolute floor of TOL).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 3, 2026. Last update: October 3, 2026
% =========================================================================

    if nargin < 4 || isempty(tol)
        tol = 1e-9;
    end
    if ~isnumeric(values) || ~isreal(values) || ~isvector(values) || ...
            isempty(values)
        error('nirp:flowsheet:invalidValues', ...
            'values must be a nonempty real numeric vector.');
    end
    if ~isnumeric(total) || ~isreal(total) || ~isscalar(total) || ...
            ~isfinite(total) || total <= 0
        error('nirp:flowsheet:invalidTotal', ...
            'total must be a finite positive real scalar.');
    end
    if ~isnumeric(powers) || ~isreal(powers) || ~isvector(powers) || ...
            numel(powers) ~= numel(values) || any(~isfinite(powers)) || ...
            any(powers == 0)
        error('nirp:flowsheet:invalidPowers', ...
            'powers must contain one finite nonzero exponent per value.');
    end
    if ~isnumeric(tol) || ~isreal(tol) || ~isscalar(tol) || ...
            ~isfinite(tol) || tol < 0
        error('nirp:flowsheet:invalidTolerance', ...
            'tol must be a finite nonnegative real scalar.');
    end

    values = reshape(values,size(powers));
    origin = repmat("specified",size(values));
    message = "";
    known = ~isnan(values);
    if any(~isfinite(values(known))) || any(values(known) <= 0)
        message = "Product values must be finite and positive.";
        return
    end
    missing = find(~known);
    if numel(missing) > 1
        return
    end
    if isscalar(missing)
        knownProduct = prod(values(known).^powers(known));
        candidate = (total/knownProduct)^(1/powers(missing));
        if ~isreal(candidate) || ~isfinite(candidate) || candidate <= 0
            message = "The product relationship has no positive solution.";
            return
        end
        values(missing) = candidate;
        origin(missing) = "calculated";
        return
    end

    actual = prod(values.^powers);
    if abs(actual-total) > tol*max([1 abs(actual) abs(total)])
        message = "Specified values do not satisfy the product relationship.";
    end
end
