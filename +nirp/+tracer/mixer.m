function out = mixer(grid,inputs)
%MIXER Flow-weight tracer streams on a common grid.
%   Q is summed; C is flow weighted. E is flow weighted only when every
%   inlet has the same sourceId. Status 2 and zero E denote mixed sources.
%   When every inlet also contains Cseg and Cmm [1 x nComp] in mol/m^3,
%   both reactive chains are independently weighted by volumetric flow.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 22, 2026. Last update: October 25, 2026
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
    reactiveFlags = cellfun(@(s) isfield(s,'Cseg') || isfield(s,'Cmm'),values) ;
    nComp = 1 ;
    if any(reactiveFlags), nComp = numel(values{find(reactiveFlags,1)}.Cseg) ; end
    out = nirp.tracer.emptyStream(grid,nComp) ;
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
    if any(reactiveFlags)
        required = {'C0','Cseg','Cmm','reactiveMode','rtdTruncated'} ;
        if ~all(cellfun(@(s) all(isfield(s,required)),values))
            error('nirp:tracer:IncompleteReactiveComposition', ...
                'Every reactive mixer inlet must contain the complete reactive state.') ;
        end
        modes = cellfun(@(s) double(s.reactiveMode),values) ;
        if any(modes ~= modes(1))
            error('nirp:tracer:InconsistentReactiveMode', ...
                'Every mixer inlet must use the same micromixing mode.') ;
        end
        out.C0 = zeros(1,nComp) ;
        out.Cseg = zeros(1,nComp) ;
        out.Cmm = zeros(1,nComp) ;
        for k = 1:numel(values)
            C0 = composition(values{k}.C0,nComp,'C0') ;
            Cseg = composition(values{k}.Cseg,nComp,'Cseg') ;
            Cmm = composition(values{k}.Cmm,nComp,'Cmm') ;
            out.C0 = out.C0+flows(k)*C0/total ;
            out.Cseg = out.Cseg+flows(k)*Cseg/total ;
            out.Cmm = out.Cmm+flows(k)*Cmm/total ;
        end
        out.reactiveMode = uint8(modes(1)) ;
        out.rtdTruncated = any(cellfun(@(s) logical(s.rtdTruncated),values)) ;
    end
    out.valid = true ;
    out = nirp.tracer.validateStream(out,grid) ;
end

function value = composition(value,n,label)
    if ~(isnumeric(value) && isreal(value) && isvector(value) && ...
            numel(value) == n && all(isfinite(value(:))) && all(value(:) >= 0))
        error('nirp:tracer:InvalidReactiveComposition', ...
            '%s must be a nonnegative finite composition vector.',label) ;
    end
    value = reshape(double(value),1,[]) ;
end
