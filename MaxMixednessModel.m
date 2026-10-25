classdef MaxMixednessModel
% This class implements the Maximum Mixedness Model for predicting
% conversion in non-ideal reactors.
%
% In maximum mixedness, fluid mixes as early as possible. The model uses
% life expectancy (lambda), the time remaining before a fluid element
% exits the reactor.
%
% The current toolbox workflow uses the general ReactionSys-based
% isothermal route implemented in compute_isothermal().
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
        X_exit              % Exit conversion X(lambda=0) (result)
        C_exit              % [1 x nComp] Exit concentrations at lambda=0
        lambda_profile      % [1 x M] life expectancy vector
        X_profile           % [1 x M] conversion profile X(lambda)
    end

    methods

        function obj = MaxMixednessModel(varargin)
            % MaxMixednessModel Constructor
            %   obj = MaxMixednessModel()
            %   obj = MaxMixednessModel(rtd_obj)
            %
            % Extra legacy arguments are ignored. The current non-ideal
            % workflow only requires the RTD object.

            if nargin == 0
                return
            end

            obj.rtd = varargin{1} ;
        end

        function obj = compute_isothermal(obj, RS, C0, T)
            % Compute exit conversion using a general ReactionSys object
            % under isothermal conditions.
            %
            % ODE (in X space for key component):
            %   dX/d(lambda) = rA(C)/CA0 + E(lambda)/(1-F(lambda)) * X
            %
            % Inputs:
            %   RS  - ReactionSys object (any kinetics)
            %   C0  - Initial concentration vector [1 x nComponents] (mol/m^3)
            %   T   - Optional operating temperature (K). Default: 298.15 K.

            if isempty(obj.rtd)
                error('RTD must be set before computing') ;
            end

            if nargin < 4 || isempty(T)
                T = 298.15 ;
            end
            if ~(isnumeric(T) && isreal(T) && isscalar(T) && isfinite(T) && T > 0)
                error('MaxMixednessModel:InvalidTemperature', ...
                    'Operating temperature must be a positive finite scalar in K.') ;
            end

            t_rtd = obj.rtd.t ;
            Et = obj.rtd.Et ;
            Ft = obj.rtd.Ft ;
            stoich = RS.stochiometricMatrix ;
            idx_key = obj.keyComponentIndex ;
            CA0 = C0(idx_key) ;

            E_interp = griddedInterpolant(t_rtd, Et, 'pchip', 'nearest') ;
            F_interp = griddedInterpolant(t_rtd, Ft, 'pchip', 'nearest') ;

            valid_idx = find((1 - Ft) > 1e-6, 1, 'last') ;
            if isempty(valid_idx)
                lambda_max = max(t_rtd) * 0.95 ;
            else
                lambda_max = t_rtd(valid_idx) ;
            end

            % Backward integration in lambda cannot use NonNegative:
            % it would freeze species at zero and block physically valid
            % growth of products when stepping from lambda_max to 0.
            options = odeset('RelTol', 1e-10, 'AbsTol', 1e-12) ;

            % Unified vector-C ODE: state = full concentration vector C [nComp x 1]
            % Backward integration from lambda_max (feed) to 0 (exit).
            % Zwietering equation in concentration form using SPECIES rates.
            % ReactionSys returns reaction-progress rates r_i, so the
            % species-rate vector is (r * stoich). The maximum-mixedness
            % ODE needs the opposite sign under backward lambda integration:
            %   dC/dlambda = -(r(C)*stoich) + E(lambda)/(1-F(lambda))*(C - C0)
            [lambda_sol, C_sol] = ode45(@ode_C, [lambda_max, 0], C0(:), options) ;

            C_sol = max(C_sol, 0) ;
            obj.C_exit = C_sol(end, :) ;
            obj.X_exit = (CA0 - C_sol(end, idx_key)) / max(CA0, 1e-12) ;
            obj.X_exit = max(min(obj.X_exit, 1), 0) ;

            obj.lambda_profile = flip(lambda_sol') ;
            X_from_C = (CA0 - C_sol(:, idx_key)) / max(CA0, 1e-12) ;
            obj.X_profile = flip(max(min(X_from_C, 1), 0)') ;

            function dCdlambda = ode_C(lambda, C)
                E_val  = E_interp(lambda) ;
                F_val  = F_interp(lambda) ;
                denom  = max(1 - F_val, 1e-12) ;
                C_safe = max(C(:)', 0) ;
                RS_local = RS.computeRate(C_safe, T) ;
                r    = RS_local.r_i ;                    % [1 x nReactions]
                speciesRate = (r * stoich)' ;            % [nComp x 1]
                dCdlambda = -speciesRate + (E_val / denom) * (C(:) - C0(:)) ;
            end
        end

    end
end
