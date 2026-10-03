classdef CSTR < Reactor
    % This subclass defines a CSTR
    % Features:
    %   - Fix the parameters particular to a CSTR
    %   - Compute the output stream of individual CSTRs
    % =========================================================================
    % Isabela Fons Moreno-Palancas
    % Created: March 14, 2020. Last update: April 20, 2020
    % Corrected: October 1, 2026 (T-101)
    % Updated: October 1, 2026 (T-102)
    % Updated: October 1, 2026 (T-103)
    % Corrected: October 3, 2026 (T-118)
    % =========================================================================
    properties (Hidden = true) % This property is not displayed on the property list
        heatFlux % Stores the value of Q >> Useful to compute OPEX
    end
    
    methods
        
        function [Product,R] = compute_output(R,Feed,RS)
            %% @compute_output computes the composition, T and P of a CSTR
            % Features:
            %   - Pressure of the feed and product streams is assumed to be equal
            % =========================================================================
            % Isabela Fons Moreno-Palancas
            % Last update: March 27, 2020
            % =========================================================================%
            
            if strcmp(R.heatMode,'Specified T') && isempty(R.specifiedT)
                error('Reactor:missingSpecification', ...
                    'specifiedT is required for heat mode ''Specified T''.') ;
            elseif strcmp(R.heatMode,'Specified Q') && isempty(R.specifiedQ)
                error('Reactor:missingSpecification', ...
                    'specifiedQ is required for heat mode ''Specified Q''.') ;
            end

            %%
            Guess = [Feed.molarFlow , Feed.T, Feed.P] ;
            % T-118: give fsolve dimensionless residuals so material,
            % energy, temperature, and pressure equations have comparable
            % numerical weight. Physical balances remain unchanged.
            convergenceTolerance = 1e-9 ;
            moles_inlet = Feed.molarFlow/(1+R.bypassRatio) ; % mol/s
            flowScale = max(max(abs(moles_inlet)),1e-8) ; % mol/s
            materialScale = max(abs(moles_inlet),flowScale) ; % mol/s
            inletCp = RS.compute_HeatCapacity(Feed.T,Feed.P) ; % J/(mol*K)
            energyScale = max(sum(abs(moles_inlet).*abs(inletCp))* ...
                max(abs(Feed.T),1),1) ; % W
            temperatureScale = max(abs(Feed.T),1) ; % K
            pressureScale = max(abs(Feed.P),1) ; % Pa
            if ~isempty(R.initialTemperatureGuess)
                fixedTemperature = R.initialTemperatureGuess ; % K
                matterGuess = Feed.molarFlow ; % mol/s
                matterTypicalX = max(abs(matterGuess),1e-8) ;
                matterOptions = optimoptions('fsolve','Display','none', ...
                    'FunctionTolerance',1e-12,'StepTolerance',1e-12, ...
                    'OptimalityTolerance',1e-12,'TypicalX',matterTypicalX(:)) ;
                [matterGuess,matterResidual,matterExitflag] = fsolve( ...
                    @fixedTemperatureMassBalance,matterGuess,matterOptions) ;
                maximumMatterResidual = norm(matterResidual,inf) ;
                if ~isfinite(maximumMatterResidual) || ...
                        maximumMatterResidual > convergenceTolerance
                    warning('CSTR:initialGuessNotConverged', ...
                        ['The fixed-temperature material balance did not converge ' ...
                        '(exitflag %d, maximum scaled residual %.3e).'], ...
                        matterExitflag,maximumMatterResidual) ;
                end
                Guess = [matterGuess(:)' fixedTemperature Feed.P] ;
            end
            typicalX = abs(Guess) ;
            typicalX(typicalX == 0) = flowScale ;
            options = optimoptions('fsolve','Display','none', ...
                'FunctionTolerance',1e-12,'StepTolerance',1e-12,'OptimalityTolerance',1e-12, ...
                'TypicalX',typicalX(:)) ; % column: fsolve scales internally by columns (Claude fix, T-101 review)
            [y,residual,exitflag] = fsolve(@fsolveCSTR,Guess,options) ;
            % Exact specifications should not retain roundoff introduced by
            % residual scaling. Recheck all balances at the snapped state.
            if strcmp(R.heatMode,'Isothermal')
                y(RS.nComponents+1) = Feed.T ;
            elseif strcmp(R.heatMode,'Specified T')
                y(RS.nComponents+1) = R.specifiedT ;
            end
            y(RS.nComponents+2) = Feed.P ;
            residual = fsolveCSTR(y) ;
            maximumScaledResidual = norm(residual,inf) ;
            if ~isfinite(maximumScaledResidual) || ...
                    maximumScaledResidual > convergenceTolerance
                warning('CSTR:notConverged', ...
                    ['fsolve did not converge (exitflag %d, maximum scaled ' ...
                    'residual %.3e).'],exitflag,maximumScaledResidual) ;
            end

            if strcmp(R.heatMode,'Adiabatic')
                R.heatFlux = 0 ;
            elseif strcmp(R.heatMode,'Other')
                R.heatFlux = computeHeatFlux(y(RS.nComponents+1)) ;
            elseif strcmp(R.heatMode,'Specified Q')
                R.heatFlux = R.specifiedQ ;
            else
                [r_i,DH] = reactionProperties(y) ;
                moles_inlet = Feed.molarFlow/(1+R.bypassRatio) ;
                sensibleEnthalpy = RS.compute_SensibleEnthalpy(Feed.T, ...
                    y(RS.nComponents+1),y(RS.nComponents+2)) ;
                R.heatFlux = moles_inlet*sensibleEnthalpy' + ...
                    R.V*(r_i*DH') ;
            end
            R.heatDuty = R.heatFlux ;
            
            % Mass balance in the mixer
            moles_beforeMix = y(1:RS.nComponents) ;
            moles_bypass = Feed.molarFlow*R.bypassRatio/(1+R.bypassRatio) ;
            moles_out = moles_beforeMix + moles_bypass ;
            % Momentum balance in the mixer
            P_out = y(RS.nComponents+2) ;
            % Energy balance in the mixer
            T_beforeMix = y(RS.nComponents+1) ;
            T_out = Reactor.mixTemperature(RS, ...
                [moles_beforeMix ; moles_bypass], ...
                [T_beforeMix ; Feed.T],P_out) ;
            
            % Definition of the product stream
            Product = Stream ;
            Product.molarFlow = moles_out ;
            Product.molarFlow_Units = Feed.molarFlow_Units ;
            Product.T = T_out ;
            Product.P = P_out ;
            Product.phase = Feed.phase ;
            Product.viscosity = Feed.viscosity ;
            Product.volumetricFlow_Units = Feed.volumetricFlow_Units ;
            Product.concentration_Units = Feed.concentration_Units ;
            Product.volumetricFlow = [] ;
            Product.concentration = [] ;
            if strcmp(Product.phase,'L')
                Product.volumetricFlow = Feed.volumetricFlow ; 
                Product.density = Feed.density ;
            end
            %% Solve the NonLinear System
            function y = fsolveCSTR(x)
                
                moles = x(1:RS.nComponents) ;
                T = x(RS.nComponents+1) ;
                P = x(RS.nComponents+2) ;
                
                [r_i,DH] = reactionProperties(x) ;
                r_j = r_i*RS.stochiometricMatrix ; %[1 x nComponents]
                               
                % Mass balance
                moles_inlet = Feed.molarFlow/(1+R.bypassRatio) ;
                materialResidual = moles_inlet - moles + r_j*R.V ;
                y(1:RS.nComponents) = materialResidual./materialScale ;
                
                %Energy balance
                if strcmp(R.heatMode,'Isothermal')
                    y(RS.nComponents+1) = (T-Feed.T)/temperatureScale ;
                elseif strcmp(R.heatMode,'Specified T')
                    specifiedTemperatureScale = max(abs(R.specifiedT),1) ;
                    y(RS.nComponents+1) = ...
                        (T-R.specifiedT)/specifiedTemperatureScale ;
                else
                    if strcmp(R.heatMode,'Adiabatic')
                        Q = 0;
                    elseif strcmp(R.heatMode,'Other')
                        Q = computeHeatFlux(T) ;
                    elseif strcmp(R.heatMode,'Specified Q')
                        Q = R.specifiedQ ;
                    end

                    % Table 1 of the ReactorApp article: sensible heat plus
                    % V*sum(r_i*DH_i), minus heat entering the reactor.
                    sensibleEnthalpy = RS.compute_SensibleEnthalpy( ...
                        Feed.T,T,P) ;
                    energyResidual = moles_inlet*sensibleEnthalpy' + ...
                        R.V*(r_i*DH')-Q ;
                    y(RS.nComponents+1) = energyResidual/energyScale ;
                end
                
                % Momentum balance
                y(RS.nComponents+2) = (P-Feed.P)/pressureScale ;
                
                y = y';
                
            end

            function residual = fixedTemperatureMassBalance(moles)
                state = [moles(:)' fixedTemperature Feed.P] ;
                r_i = reactionProperties(state) ;
                r_j = r_i*RS.stochiometricMatrix ;
                moles_inlet = Feed.molarFlow/(1+R.bypassRatio) ;
                physicalResidual = moles_inlet-moles(:)' + r_j*R.V ;
                residual = (physicalResidual./materialScale)' ;
            end

            function [r_i,DH] = reactionProperties(x)
                moles = x(1:RS.nComponents) ;
                T = x(RS.nComponents+1) ;
                P = x(RS.nComponents+2) ;

                if Feed.phase == 'L'
                    Qv = Feed.volumetricFlow ;
                elseif Feed.phase == 'G'
                    Qv = sum(moles)*8.314*T/P ; % m^3/s
                end
                concentration = moles./Qv ; % mol/m^3
                RS = RS.computeRate(concentration,T) ;
                constant_WtoV = (1-R.porosityCatalyst)*R.densityCatalyst ;
                r_i = constant_WtoV*RS.r_i ; % mol/(m^3*s)
                DH = RS.compute_ReactionEnthalpy(T,P) ; % J/mol
            end

            function Q = computeHeatFlux(T)
                if isempty(R.outletUtilityTemperature)
                    meanTemperatureDifference = R.inletUtilityTemperature-T ;
                else
                    deltaTIn = R.inletUtilityTemperature-T ;
                    deltaTOut = R.outletUtilityTemperature-T ;
                    % At a temperature cross (or equal end differences),
                    % use the arithmetic mean because the LMTD is singular.
                    if deltaTIn*deltaTOut <= 0 || deltaTIn == deltaTOut
                        meanTemperatureDifference = (deltaTIn+deltaTOut)/2 ;
                    else
                        meanTemperatureDifference = ...
                            (deltaTIn-deltaTOut)/log(deltaTIn/deltaTOut) ;
                    end
                end
                Q = R.U*R.heatTransferArea*meanTemperatureDifference ; % W
            end
        end
        
    end
end

