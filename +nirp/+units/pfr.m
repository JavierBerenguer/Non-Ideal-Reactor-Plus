function [out,info] = pfr(params,in,rs)
%PFR Solve a plug-flow reactor through the common API.
%   PARAMS is SI and requires L (m) or V (m^3); L takes precedence. D
%   (m) defaults to 0.1 and nTubes to 1. pressureMode defaults to Constant
%   and pressureDropEqn to Pipe. Thermal parameters and defaults match
%   nirp.units.cstr. Nonconstant liquid pressure requires density (kg/m^3)
%   and viscosity (Pa*s); Ergun also requires particleDiameter (m).
%   Degrees of freedom: geometry supplies one size specification (V, or L
%   with D and nTubes), while the selected thermal and pressure modes add
%   their equations and required data. With the inlet fixed, every current
%   mode has zero remaining DOF after its displayed values are specified.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 1, 2026. Last update: October 9, 2026
% =========================================================================

    if ~isstruct(params) || ~isscalar(params)
        error('nirp:units:invalidParameter','params must be a scalar struct.') ;
    end
    requireReactionSystem(rs) ;
    nirp.stream.validate(in,rs.nComponents) ;
    if in.status == 0
        out = emptyLike(in,rs.nComponents) ;
        info = baseInfo(0) ;
        return
    end

    hasL = isfield(params,'L') && ~isempty(params.L) ;
    hasV = isfield(params,'V') && ~isempty(params.V) ;
    if ~hasL && ~hasV
        error('nirp:units:missingParameter', ...
            'Either L or V is required for a PFR.') ;
    end
    reactor = PFR ;
    reactor.diameterTubes = parameter(params,'D',0.1,false) ;
    reactor.nTubes = parameter(params,'nTubes',1,false) ;
    if hasL
        reactor.L = params.L ;
    else
        reactor.L = [] ;
        reactor.V = params.V ;
    end
    if ~isnumeric(reactor.diameterTubes) || ...
            ~isreal(reactor.diameterTubes) || ...
            ~isscalar(reactor.diameterTubes) || ...
            ~isfinite(reactor.diameterTubes) || reactor.diameterTubes <= 0 || ...
            ~isnumeric(reactor.nTubes) || ~isreal(reactor.nTubes) || ...
            ~isscalar(reactor.nTubes) || ~isfinite(reactor.nTubes) || ...
            reactor.nTubes <= 0 || ...
            reactor.nTubes ~= fix(reactor.nTubes) || ...
            (hasL && (~isnumeric(reactor.L) || ~isscalar(reactor.L) || ...
            ~isfinite(reactor.L) || reactor.L <= 0)) || ...
            (~hasL && (~isnumeric(reactor.V) || ~isscalar(reactor.V) || ...
            ~isfinite(reactor.V) || reactor.V <= 0))
        error('nirp:units:invalidParameter', ...
            'PFR dimensions must be finite and positive; nTubes must be an integer.') ;
    end
    reactor = configureThermalReactor(reactor,params) ;
    reactor.pressureMode = parameter(params,'pressureMode','Constant',false) ;
    reactor.pressureDropEqn = parameter(params,'pressureDropEqn','Pipe',false) ;
    reactor.particleDiameter = parameter(params,'particleDiameter',[],false) ;
    feed = nirp.stream.toStream(in) ;
    if strcmp(reactor.pressureMode,'Non constant')
        feed.viscosity = parameter(params,'viscosity',[],true) ;
        feed.viscosity_Units = 'Pa*s' ;
        if in.phase == 0
            feed.density = parameter(params,'density',[],true) ;
            feed.density_Units = 'kg/m^3' ;
        end
        if strcmp(reactor.pressureDropEqn,'Ergun')
            reactor.particleDiameter = parameter( ...
                params,'particleDiameter',[],true) ;
        end
        if ~isnumeric(feed.viscosity) || ~isscalar(feed.viscosity) || ...
                ~isfinite(feed.viscosity) || feed.viscosity <= 0 || ...
                (in.phase == 0 && (~isnumeric(feed.density) || ...
                ~isscalar(feed.density) || ~isfinite(feed.density) || ...
                feed.density <= 0)) || ...
                (strcmp(reactor.pressureDropEqn,'Ergun') && ...
                (~isnumeric(reactor.particleDiameter) || ...
                ~isscalar(reactor.particleDiameter) || ...
                ~isfinite(reactor.particleDiameter) || ...
                reactor.particleDiameter <= 0))
            error('nirp:units:invalidParameter', ...
                'Pressure-drop properties must be finite positive SI scalars.') ;
        end
    end

    [product,reactor] = reactor.compute_output(feed,rs) ;
    out = nirp.stream.fromStream(product) ;
    info = baseInfo(in.status) ;
    info.heatDuty = reactor.heatDuty ;
    info.profile = reactor.profile ;
    if ~isempty(rs.componentNames)
        info.profile.componentNames = rs.componentNames ;
    end
    if in.status == -1
        info.status = -1 ;
    end
    out.status = info.status ;
end
