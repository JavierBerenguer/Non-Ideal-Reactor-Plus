function out = parallel(signals,fractions)
%PARALLEL Combine RTD signals using nonnegative flow fractions.
%   All signals must have an identical common time grid in seconds.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 9, 2026. Last update: October 9, 2026
% =========================================================================

    if ~iscell(signals) || isempty(signals)
        error('nirp:conv:InvalidSignals','Signals must be a nonempty cell array.') ;
    end
    if ~(isnumeric(fractions) && isreal(fractions) && isvector(fractions) && ...
            numel(fractions) == numel(signals) && all(isfinite(fractions(:))) && ...
            all(fractions >= 0))
        error('nirp:conv:InvalidFractions', ...
            'Fractions must be one finite nonnegative value per signal.') ;
    end
    fractions = reshape(double(fractions),1,[]) ;
    if abs(sum(fractions)-1) > 1e-12
        error('nirp:conv:InvalidFractions','Flow fractions must sum to one.') ;
    end

    first = nirp.conv.signal(signals{1}.t,signals{1}.C) ;
    C = fractions(1)*first.C ;
    for k = 2:numel(signals)
        current = nirp.conv.signal(signals{k}.t,signals{k}.C) ;
        if numel(current.t) ~= numel(first.t) || ...
                any(abs(current.t-first.t) > 100*eps(max([1 abs(first.t)])))
            error('nirp:conv:GridMismatch', ...
                'Parallel RTD signals must use the same time grid.') ;
        end
        C = C+fractions(k)*current.C ;
    end
    out = nirp.conv.signal(first.t,C) ;
end
