function out = reactiveVessel(grid,E,RS,Cin,T,keyIndex,varargin)
%REACTIVEVESSEL Compute stationary micromixing limits for one vessel RTD.
%   OUT = REACTIVEVESSEL(GRID,E,RS,CIN,T,KEYINDEX) returns Cseg and Cmm in
%   mol/m^3 and the key-component conversions Xseg and Xmm. GRID time is in
%   seconds, E is in 1/s on that grid, and T is in K. E is normalized by the
%   RTD class for calculation; diagnostic.areaRetained reports its original
%   rectangular mass on the flowsheet grid so truncated tails remain visible.
%   The optional name-value Mode is 'both' (default), 'segregation', or
%   'maxmixedness'. A selective call leaves the unrequested result empty.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 25, 2026. Last update: November 3, 2026
% =========================================================================

    mode = parseMode(varargin{:}) ;
    grid = nirp.tracer.validateGrid(grid) ;
    validateattributes(E,{'numeric'},{'real','vector','numel',grid.length, ...
        'finite','nonnegative'},mfilename,'E') ;
    E = reshape(double(E),1,[]) ;
    if ~isa(RS,'ReactionSys')
        error('nirp:tracer:InvalidReactionSystem','RS must be a ReactionSys object.') ;
    end
    if ~(isnumeric(Cin) && isreal(Cin) && isvector(Cin) && ...
            numel(Cin) == RS.nComponents && all(isfinite(Cin(:))) && ...
            all(Cin(:) >= 0))
        error('nirp:tracer:InvalidComposition', ...
            'Cin must be a nonnegative finite vector with one value per component.') ;
    end
    Cin = reshape(double(Cin),1,[]) ;
    if ~(isnumeric(T) && isreal(T) && isscalar(T) && isfinite(T) && T > 0)
        error('nirp:tracer:InvalidTemperature', ...
            'T must be a positive finite scalar in K.') ;
    end
    if ~(isnumeric(keyIndex) && isreal(keyIndex) && isscalar(keyIndex) && ...
            isfinite(keyIndex) && keyIndex == fix(keyIndex) && ...
            keyIndex >= 1 && keyIndex <= RS.nComponents)
        error('nirp:tracer:InvalidKeyComponent', ...
            'keyIndex must identify one ReactionSys component.') ;
    end

    areaRetained = grid.dt*sum(E) ;
    if areaRetained <= 0
        error('nirp:tracer:ZeroRTDArea','Vessel E must have positive area.') ;
    end
    diagnostic = struct('areaRetained',areaRetained, ...
        'rtdTrapzArea',trapz(grid.t,E), ...
        'warnings',struct('identifier',{},'message',{}), ...
        'boundValidity',nirp.tracer.boundValidity(RS,keyIndex)) ;
    massTolerance = 1e-6 ;
    if areaRetained < 1-massTolerance
        diagnostic.warnings(end+1) = notice( ...
            'nirp:tracer:TruncatedRTD',sprintf( ...
            'The grid retains %.8g of the vessel RTD area.',areaRetained)) ;
    elseif areaRetained > 1+massTolerance
        diagnostic.warnings(end+1) = notice( ...
            'nirp:tracer:UnnormalizedRTD',sprintf( ...
            'The supplied vessel RTD area is %.8g and will be normalized.',areaRetained)) ;
    end

    out = struct('Cseg',zeros(size(Cin)),'Cmm',zeros(size(Cin)), ...
        'Xseg',NaN,'Xmm',NaN,'diagnostic',diagnostic) ;
    if strcmp(mode,'segregation')
        out.Cmm = [] ;
    elseif strcmp(mode,'maxmixedness')
        out.Cseg = [] ;
    end
    if all(Cin == 0)
        out.diagnostic.warnings(end+1) = zeroKeyNotice() ;
        return
    end

    rtd = RTD(grid.t,E) ;
    if ~strcmp(mode,'maxmixedness')
        segregation = SegregationModel(rtd) ;
        segregation.keyComponentIndex = keyIndex ;
        segregation = segregation.compute_isothermal(RS,Cin,T) ;
        out.Cseg = max(reshape(segregation.C_exit,1,[]),0) ;
    end

    concentrated = nnz(E > max(E)*1e-12) == 1 ;
    if strcmp(mode,'both') && concentrated
        out.Cmm = out.Cseg ;
    elseif ~strcmp(mode,'segregation')
        maximumMixedness = MaxMixednessModel(rtd) ;
        maximumMixedness.keyComponentIndex = keyIndex ;
        maximumMixedness = maximumMixedness.compute_isothermal(RS,Cin,T) ;
        out.Cmm = max(reshape(maximumMixedness.C_exit,1,[]),0) ;
    end

    if Cin(keyIndex) == 0
        out.diagnostic.warnings(end+1) = zeroKeyNotice() ;
    else
        if ~isempty(out.Cseg)
            out.Xseg = min(1,max(0,1-out.Cseg(keyIndex)/Cin(keyIndex))) ;
        end
        if ~isempty(out.Cmm)
            out.Xmm = min(1,max(0,1-out.Cmm(keyIndex)/Cin(keyIndex))) ;
        end
    end
end

function mode = parseMode(varargin)
    parser = inputParser ;
    parser.FunctionName = mfilename ;
    addParameter(parser,'Mode','both',@(x) ischar(x) || ...
        (isstring(x) && isscalar(x))) ;
    parse(parser,varargin{:}) ;
    mode = lower(strtrim(char(parser.Results.Mode))) ;
    if ~ismember(mode,{'both','segregation','maxmixedness'})
        error('nirp:tracer:InvalidMicromixingMode', ...
            'Mode must be both, segregation, or maxmixedness.') ;
    end
end

function value = notice(identifier,message)
    value = struct('identifier',identifier,'message',message) ;
end

function value = zeroKeyNotice()
    value = notice('nirp:tracer:UndefinedKeyConversion', ...
        'Key-component inlet concentration is zero; conversion is undefined.') ;
end
