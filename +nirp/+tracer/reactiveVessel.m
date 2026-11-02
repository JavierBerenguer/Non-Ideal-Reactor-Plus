function out = reactiveVessel(grid,E,RS,Cin,T,keyIndex)
%REACTIVEVESSEL Compute stationary micromixing limits for one vessel RTD.
%   OUT = REACTIVEVESSEL(GRID,E,RS,CIN,T,KEYINDEX) returns Cseg and Cmm in
%   mol/m^3 and the key-component conversions Xseg and Xmm. GRID time is in
%   seconds, E is in 1/s on that grid, and T is in K. E is normalized by the
%   RTD class for calculation; diagnostic.areaRetained reports its original
%   rectangular mass on the flowsheet grid so truncated tails remain visible.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 25, 2026. Last update: October 25, 2026
% =========================================================================

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
    if all(Cin == 0)
        out.diagnostic.warnings(end+1) = zeroKeyNotice() ;
        return
    end

    rtd = RTD(grid.t,E) ;
    segregation = SegregationModel(rtd) ;
    segregation.keyComponentIndex = keyIndex ;
    segregation = segregation.compute_isothermal(RS,Cin,T) ;
    out.Cseg = max(reshape(segregation.C_exit,1,[]),0) ;

    concentrated = nnz(E > max(E)*1e-12) == 1 ;
    if concentrated
        out.Cmm = out.Cseg ;
    else
        maximumMixedness = MaxMixednessModel(rtd) ;
        maximumMixedness.keyComponentIndex = keyIndex ;
        maximumMixedness = maximumMixedness.compute_isothermal(RS,Cin,T) ;
        out.Cmm = max(reshape(maximumMixedness.C_exit,1,[]),0) ;
    end

    if Cin(keyIndex) == 0
        out.diagnostic.warnings(end+1) = zeroKeyNotice() ;
    else
        out.Xseg = min(1,max(0,1-out.Cseg(keyIndex)/Cin(keyIndex))) ;
        out.Xmm = min(1,max(0,1-out.Cmm(keyIndex)/Cin(keyIndex))) ;
    end
end

function value = notice(identifier,message)
    value = struct('identifier',identifier,'message',message) ;
end

function value = zeroKeyNotice()
    value = notice('nirp:tracer:UndefinedKeyConversion', ...
        'Key-component inlet concentration is zero; conversion is undefined.') ;
end
