function s = fromStream(obj)
%FROMSTREAM Convert a Stream object to the NIRP SI stream structure.
%   Stream getters are used, so concentration and Q are used to derive F
%   when the stored molar-flow value is empty.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 1, 2026
% =========================================================================

    if ~isa(obj,'Stream') || ~isscalar(obj)
        error('nirp:stream:invalid', ...
            'Input must be a scalar Stream object.') ;
    end
    if strcmp(obj.phase,'L')
        phase = 0 ;
    elseif strcmp(obj.phase,'G')
        phase = 1 ;
    else
        error('nirp:stream:invalid', ...
            'Stream phase must be ''L'' or ''G''.') ;
    end
    F = obj.molarFlow ;
    Q = obj.volumetricFlow ;
    if isempty(F) || ~isnumeric(F)
        error('nirp:stream:invalid', ...
            'Stream molar flow could not be derived.') ;
    end
    if all(F == 0) && (isempty(Q) || Q == 0)
        s = nirp.stream.empty(numel(F),obj.T,obj.P,phase) ;
    else
        s = nirp.stream.create(F,obj.T,obj.P,phase,Q) ;
    end
end
