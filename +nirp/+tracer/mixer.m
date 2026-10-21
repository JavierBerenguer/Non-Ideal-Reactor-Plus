function out = mixer(grid,inputs)
%MIXER Flow-weight tracer streams on a common grid.
%   Q is summed; C is flow weighted. E is flow weighted only when every
%   inlet has the same sourceId. Status 2 and zero E denote mixed sources.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 22, 2026
% =========================================================================

    grid = nirp.tracer.validateGrid(grid) ;
    if ~iscell(inputs) || isempty(inputs)
        error('nirp:tracer:InvalidMixerInputs','Mixer inputs must be a nonempty cell array.') ;
    end
    values = cell(size(inputs)) ;
    for k = 1:numel(inputs)
        values{k} = nirp.tracer.validateStream(inputs{k},grid) ;
        if ~values{k}.valid
            error('nirp:tracer:InvalidMixerInputs','Every mixer inlet must be valid.') ;
        end
    end
    flows = cellfun(@(s) s.Q,values) ;
    total = sum(flows) ;
    if ~(isfinite(total) && total > 0)
        error('nirp:tracer:ZeroMixerFlow','Mixer total flow must be positive.') ;
    end
    out = nirp.tracer.emptyStream(grid) ;
    out.Q = total ;
    for k = 1:numel(values)
        out.C = out.C+flows(k)*values{k}.C/total ;
    end
    ids = cellfun(@(s) double(s.sourceId),values(flows > 0)) ;
    if ~isempty(ids) && all(ids == ids(1))
        for k = 1:numel(values)
            out.E = out.E+flows(k)*values{k}.E/total ;
        end
        out.sourceId = uint32(ids(1)) ;
        out.status = uint8(1) ;
    else
        out.sourceId = uint32(0) ;
        out.E(:) = 0 ;
        out.status = uint8(2) ;
    end
    out.valid = true ;
    out = nirp.tracer.validateStream(out,grid) ;
end
