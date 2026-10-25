classdef SegregationModel
% This class implements the Segregation Model (complete segregation / macrofluid)
% for predicting conversion in non-ideal reactors.
%
% The segregation model treats the fluid as a collection of small batch
% reactors (aggregates) that do not exchange material. Each aggregate
% reacts independently for a time equal to its residence time.
%
% Mean conversion:  X_bar = integral( X_batch(t) * E(t) dt )
%
% This model gives the UPPER BOUND of conversion for reaction orders > 1
% and the LOWER BOUND for reaction orders < 1.
% For first-order reactions, it gives the exact conversion regardless of
% mixing state.
%
% Features:
%   - Compute mean conversion from RTD and general kinetics
%   - Works from the same ReactionSys pathway used by NonIdealReactorApp
% =========================================================================
% Javier Berenguer Sabater
% Created: March 21, 2026. Last update: October 25, 2026
% =========================================================================

% Internal units (SI):
%   time: s | volume: m^3 | concentration: mol/m^3
%   flow: m^3/s | pressure: Pa | temperature: K
%   k(1st): 1/s | k(2nd): m^3/(mol*s) | energy: J/mol

    properties
        rtd                 % RTD object
        keyComponentIndex = 1  % Index of the key component for conversion
    end

    properties (SetAccess = private)
        X_mean              % Mean conversion (result)
        C_exit              % [1 x nComp] Mean outlet concentrations from segregation
        X_batch             % [1 x N] Batch conversion profile X(t)
        integrand           % [1 x N] X(t)*E(t) - the integrand
        C_batch             % [N x nComp] Concentration profiles from batch
        selectivity_B    % Overall selectivity S_B = CB/(CB+CC) for parallel reactions
        yield_B          % Overall yield Y_B = CB/(CA0-CA) for parallel reactions
    end

    methods

        %% ============== CONSTRUCTOR ==============

        function obj = SegregationModel(varargin)
            % SegregationModel Constructor
            %   obj = SegregationModel()
            %   obj = SegregationModel(rtd_obj)
            %
            % Extra legacy arguments are ignored. The current non-ideal
            % workflow only requires the RTD object.

            if nargin == 0
                return
            end

            obj.rtd = varargin{1} ;
        end

        %% ============== GENERAL ISOTHERMAL (from ReactionSys) ==============

        function obj = compute_isothermal(obj, RS, C0, T)
            % Compute mean conversion using a general ReactionSys object
            % under isothermal conditions.
            %
            %   X_bar = integral( X_batch(t) * E(t) dt )
            %
            % The batch ODE is:  dC/dt = r(C) * stoich
            % No energy or pressure balance — pure isothermal.
            %
            % Inputs (set via properties or arguments):
            %   RS  - ReactionSys object (any kinetics)
            %   C0  - Initial concentration vector [1 x nComponents] (mol/m^3)
            %   T   - Optional operating temperature (K). Default: 298.15 K.
            %
            % The key component for conversion is obj.keyComponentIndex (default: 1).

            if isempty(obj.rtd)
                error('RTD must be set before computing') ;
            end

            if nargin < 4 || isempty(T)
                T = 298.15 ;
            end
            if ~(isnumeric(T) && isreal(T) && isscalar(T) && isfinite(T) && T > 0)
                error('SegregationModel:InvalidTemperature', ...
                    'Operating temperature must be a positive finite scalar in K.') ;
            end

            t_rtd = obj.rtd.t ;
            Et = obj.rtd.Et ;
            stoich = RS.stochiometricMatrix ;
            nComp = length(C0) ;
            idx_key = obj.keyComponentIndex ;

            % Solve batch ODE
            odeOpts = odeset('NonNegative', 1:nComp, 'RelTol', 1e-8) ;
            [t_ode, C_ode] = ode45(@(t, C) batch_ode(C), ...
                [0, max(t_rtd)], C0(:), odeOpts) ;

            % Conversion of key component
            C_key_vs_t = C_ode(:, idx_key) ;
            X_vs_t = (C0(idx_key) - C_key_vs_t) / C0(idx_key) ;

            % Interpolate at RTD time points. A stationary zero-rate system
            % may make the nonnegative solver return a single sample.
            degenerateTime = numel(unique(t_ode)) < 2 ;
            if C0(idx_key) == 0
                obj.X_batch = nan(1,numel(t_rtd)) ;
            elseif degenerateTime
                obj.X_batch = repmat(X_vs_t(end),1,numel(t_rtd)) ;
            else
                obj.X_batch = interp1(t_ode, X_vs_t, t_rtd, 'pchip', 0) ;
                obj.X_batch = obj.X_batch(:)' ;  % force row [1 x N]
            end
            if degenerateTime
                obj.C_batch = repmat(C_ode(end,:),numel(t_rtd),1) ;
            else
                obj.C_batch = interp1(t_ode, C_ode, t_rtd, 'pchip') ;
            end

            % Store concentration profiles
            if nComp == 1
                obj.C_batch = obj.C_batch(:) ;
            end

            % Integrate
            obj.integrand = obj.X_batch .* Et ;
            obj.X_mean = trapz(t_rtd, obj.integrand) ;

            % Mean outlet concentrations: C_exit(j) = integral(C_batch(t,j) * E(t) dt)
            obj.C_exit = zeros(1, nComp) ;
            for j = 1:nComp
                obj.C_exit(j) = trapz(t_rtd, obj.C_batch(:,j)' .* Et) ;
            end

            % Selectivity and yield for multi-component systems
            if nComp >= 3
                CB_t = obj.C_batch(:, 2)' ;
                CC_t = obj.C_batch(:, 3)' ;
                CB_mean = trapz(t_rtd, CB_t .* Et) ;
                CC_mean = trapz(t_rtd, CC_t .* Et) ;
                if (CB_mean + CC_mean) > 0
                    obj.selectivity_B = CB_mean / (CB_mean + CC_mean) ;
                end
                CA_mean = trapz(t_rtd, obj.C_batch(:, 1)' .* Et) ;
                if (C0(1) - CA_mean) > 0
                    obj.yield_B = CB_mean / (C0(1) - CA_mean) ;
                end
            end

            function dCdt = batch_ode(C)
                RS_temp = RS.computeRate(C(:)', T) ;
                r = RS_temp.r_i ;
                dCdt = (r * stoich)' ;
            end
        end

    end
end
