classdef Reactor
   
% This class defines the reactor. 
% Features:
%   - Fix the parameters of the different reactors (some are specified by default)
%   - Compute the output stream of individual reactors or other configurations (bypass, recycle, association)
% =========================================================================
% Isabela Fons Moreno-Palancas
% Created: March 14, 2020. Last update: July 4th, 2020
% Updated: October 1, 2026 (T-102)
% =========================================================================

    properties
        V = 1 ;
        V_Units = 'm^3' ;
        bypassRatio = 0 ;
        
        densityCatalyst = 1 ;
        porosityCatalyst = 0 ;
        
        heatMode
        specifiedT = [] ; % Specified reactor temperature (K)
        specifiedQ = [] ; % Specified total heat entering the reactor (W)
        initialTemperatureGuess = [] ; % CSTR initial temperature estimate (K)
        heatDuty = [] ; % Total heat entering the reactor in the last calculation (W)
        U = 0 ;
        heatTransferArea = 1 ;
        inletUtilityTemperature = 1 ;
        outletUtilityTemperature
        costUtility
        pressureMode = 'Constant' ;
              
        activatePlots  = 'off' ;
    end
        
    methods
                
        function R = set.activatePlots(R,mode)
            activatePlots_options = {'off','on'};
            switch mode
                case activatePlots_options
                    R.activatePlots = mode ;
                otherwise
                    error('Invalid input.Plots can be enabled (on) or disabled (off)') ;
            end
        end
        
        function R = set.V(R,V)
            R.V = V ;
        end
            
        function R = set.V_Units(R,V_Units)
%             if strcmp(V_Units,'L') == 1
%                 R.V = R.V/1000 ;
%                 R.V_Units = 'm^3';
%             elseif strcmp(V_Units,'m^3') == 1
                R.V_Units = V_Units ;
%             else 
%                 error('Invalid units. Volume must be expressed in m^3')
%             end
        end
                
        function R = set.bypassRatio(R,bypassRatio)
            R.bypassRatio = bypassRatio ;
        end
        
        function R = set.densityCatalyst(R,densityCatalyst)
            R.densityCatalyst = densityCatalyst ;
        end

        function R = set.porosityCatalyst(R,porosityCatalyst)
            R.porosityCatalyst = porosityCatalyst ;
        end
        
        function R = set.heatMode(R,heatMode)
            heatMode_options = {'Isothermal' 'Adiabatic' 'Other' ...
                'Specified T' 'Specified Q'};
            switch heatMode
                case heatMode_options
                    R.heatMode = heatMode ;
                otherwise
                    error('Invalid heat transfer mode') ;
            end
        end
        
        function R = set.U(R,U)
            R.U = U ;
        end

        function R = set.heatTransferArea(R,heatTransferArea)
            R.heatTransferArea = heatTransferArea ;
        end
        
        function R = set.inletUtilityTemperature(R,inletUtilityTemperature)
            R.inletUtilityTemperature = inletUtilityTemperature ;
        end
        
        function R = set.pressureMode(R,pressureMode)
            pressureMode_options = {'Constant','Non constant'};
            switch pressureMode
                case pressureMode_options
                    R.pressureMode = pressureMode ;
                otherwise
                    error('Invalid pressure evolution mode') ;
            end
        end
               
        function [Product,sequence] = compute_series(~,Feed,RS,sequence)
            newFeed = Feed ;
            for i = 1:length(sequence) 
                [Product, sequence{i}] = compute_output(sequence{i},newFeed,RS) ;
                newFeed.molarFlow = Product.molarFlow ;
                newFeed.volumetricFlow = Product.volumetricFlow ;
                newFeed.concentration = Product.concentration ;
                newFeed.T = Product.T ;
                newFeed.P = Product.P ;
            end
        end 
        
        function [Product,sequence] = compute_parallel(~,Feed,RS,sequence,varargin)
            % - There's no mechanical energy balance implemented in the mixer. 
            % Final pressure computes as the minimum among the outlet pressure of the reactors considered
            % - By default this function assumes an equal split: total feed
            % divides equally among all reactors unless anything else is
            % specified
            if isempty(varargin)
                split = 1/length(sequence) * ones(1,length(sequence)) ;
            elseif length(varargin) == 1 
                split = cell2mat(varargin) ; 
            end
            
            %Define the new feed & compute the output stream of each reactor
            n_mix = 0 ;
            energyBalanceNumerator = 0 ;
            energyBalanceDenominator = 0 ;
            for i = 1:length(split)
                newFeed(i) = Feed ;
                newFeed(i).molarFlow = Feed.molarFlow*split(i) ;
                newFeed(i).volumetricFlow = Feed.volumetricFlow*split(i) ;
                [individualProduct(i),sequence{i}] = compute_output(sequence{i},newFeed(i),RS) ;
                n_mix = n_mix + individualProduct(i).molarFlow;
                
                % Molar Heat Capacity 
                T = individualProduct(i).T ;
                P = individualProduct(i).P ;
                componentCp = compute_HeatCapacity(RS,T,P) ;
                energyBalanceNumerator = energyBalanceNumerator + componentCp*individualProduct(i).molarFlow'*individualProduct(i).T ;
                energyBalanceDenominator = energyBalanceDenominator + componentCp*individualProduct(i).molarFlow' ;
            end
            
            %Compute the final output stream (mix of the output of each reactor)
            Product = Stream ; 
            Product.phase = Feed.phase ;
            Product.molarFlow = n_mix ;
            if strcmp(Product.phase,'L')
                Product.volumetricFlow = Feed.volumetricFlow ;
            end
            Product.T = energyBalanceNumerator / energyBalanceDenominator ;
            Product.P = min(individualProduct.P) ; 
        end
        
                function [Product,R] = compute_recycling(R,Feed,RS,recycleRatio)
        global F_new % Declared global only to create the plots
            % Deactivate plots before initating the iterative process
            if strcmp(R.activatePlots,'on')
                R.activatePlots = 'off' ;
                initialState = 'on' ; % Used later on in line XXXX
            end
            
            % Solve a non-linear system of equations
            Guess = R.compute_output(Feed,RS) ;
            x0 = [Guess.molarFlow' ; Guess.T ; Guess.P ] ;
            options = optimoptions('fsolve','Display','iter');
            y = fsolve(@sysEqnRecycle,x0,options) ;
            n = y(1:RS.nComponents) ;
            T = y(RS.nComponents+1) ;
            P = y(RS.nComponents+2) ;
            
            % Definition of the outlet stream of the system            
            Product = Stream ;
            Product.phase = Feed.phase ;
            Product.molarFlow = n/(1+recycleRatio) ;
            Product.T = T ;
            Product.P = P ;
                        
            %% Function to store the equations that define the non-linear system
            function y = sysEqnRecycle(x)
     
                % NOTES:
                % - Comment line 200 and uncomment line 199 if Energy Balance in the mixer can be neglected
                % - Error detected when order of magnitude of the molar flow is really small compared to T. In this case, the solver is unable to converge. 
                % This limitation has been overcome in a very unprofessional way (go to line 215) so the code is totally open for improvements and modifications!

                % UNKNOWNS = nComponents + 2
                % Outlet stream of the reactor -> n = molesRecycled + molesLeavingSystem
                n          = x(1:RS.nComponents) ;
                T          = x(RS.nComponents+1) ;
                P          = x(RS.nComponents+2) ;
                
                % PREVIOUS OPERATIONS
                componentCp_Feed    = compute_HeatCapacity(RS,Feed.T,Feed.P) ;
                componentCp_Recycle = compute_HeatCapacity(RS,T,P) ;
                
                ninReactor = Feed.molarFlow(:) + recycleRatio/(1+recycleRatio) * n ;
%                 TinReactor = Feed.T ; 
                TinReactor = (Feed.molarFlow*componentCp_Feed'*Feed.T + componentCp_Recycle*n*T)/(Feed.molarFlow*componentCp_Feed' + componentCp_Recycle*n) ;
                PinReactor = Feed.P ;
                
                F_new               = Feed ;
                F_new.molarFlow     = ninReactor' ; 
                F_new.T             = TinReactor ;
                F_new.P             = PinReactor ;
                outletStreamReactor = compute_output(R,F_new,RS) ; % This is the function where all mass, energy and momentum balances are implemented and, thus, makes the problem non-linear
                
                % NON-LINEAR SYSTEM OF EQUATIONS
                % Number of equations = Number of unknowns
                y(1:RS.nComponents) = (outletStreamReactor.molarFlow(:) - n) ;
                y(RS.nComponents+1) = (outletStreamReactor.T - T) ;
                y(RS.nComponents+2) = (outletStreamReactor.P - P) ;
                
                % Very non-professional solution is implemented below
                orderOfMagnitude_n = floor(log(abs(max(Feed.molarFlow)))./log(10));
                orderOfMagnitude_T = floor(log(abs(max(Feed.T)))./log(10));
                differenceOfMagnitudes = abs(orderOfMagnitude_n-orderOfMagnitude_T) ;
                if differenceOfMagnitudes > 2
                    y(RS.nComponents+1) = y(RS.nComponents+1) / 10^(differenceOfMagnitudes-2) ;
                end
            end
            
            %% Displaying plots with the result only if it was initially asked
            if exist('initialState','var')
                R.activatePlots = initialState ;
                R.compute_output(F_new,RS) ;
            end
        end

                
        function  [optimalSize,optimalResidenceTime] = minimize_residenceTime(R,Feed,RS,goalProduct)
            % This function computes the optimal residence time for a given reactor after specifying the desired output.
            % 
            % WARNING: If any variable is fixed by default in the output stream, it must be changed or erased.
            %          If the molar flow of any component in the product stream doesn't need to be specified, write NaN.(Authomatically made if app is used)
            % 
            % Syntax hint: fmincon(fun,x0,A,b,Aeq,beq,lb,ub,nonlcon,options)
            % Unknowns: x
            fun = @(x) optimize_residenceTime(x,Feed,R) ;
            x0 = [R.V] ;
            A = [] ;
            b = [] ;
            Aeq = [] ;
            beq = [] ;
            lb = [] ;
            ub = [] ;
            nonlcon = @(x) nonlconstraints(x,Feed,RS,R,goalProduct) ;
            options = optimoptions('fmincon','MaxIterations',100);
            
            [x,fval] = fmincon(fun,x0,A,b,Aeq,beq,lb,ub,nonlcon,options) ;
            if isa(R,'Batch')
                fprintf('The minimum residence time for the given batch reactor is %f ', fval) %Cambiar por fprintf
            elseif isa(R,'PFR')||isa(R,'CSTR')
                fprintf('The minimum residence time for the given reactor is %f \n',fval)
                fprintf('and the optimal reactor size is %f',x)
            end
            optimalSize = x ;
            optimalResidenceTime = fval ;
            
            %% Definition of the objective function and constraints
            function f = optimize_residenceTime(x,Feed,R)
                
                if isa(R,'Batch')
                    R.timeBatch = x ;
                    residenceTime = R.timeBatch ;
                else
                    R.V = x ;
                    if isa(R,'PFR')
                        R.L = R.V / (R.nTubes * pi*(R.diameterTubes/2)^2) ;
                    end
                    residenceTime = R.V/Feed.volumetricFlow ;
                end
                
                % Function fmincon works in the minimization direction. Therfore...
                f = residenceTime ;
                
            end
                        
            function [c,ceq] = nonlconstraints(x,Feed,RS,R,goalProduct)
                % @nonlconstraints computes the nonlinear  constraints.
                % fmincon optimizes such that ceq(x) = 0 and c(x)<0
                
                if isa(R,'Batch')
                    R.timeBatch = x ;
                else
                    R.V = x ;
                    if isa(R,'PFR')
                        R.L = R.V / (R.nTubes * pi*(R.diameterTubes/2)^2) ;
                    end
                end
                
                currentProduct = R.compute_output(Feed,RS) ;
                
                % Target composition constraints
                specifiedGoalProductMolarFlow = goalProduct.molarFlow(~isnan(goalProduct.molarFlow)) ; %Only consider specified molar flow rates
                specifiedCurrentProductMolarFlow = currentProduct.molarFlow(~isnan(goalProduct.molarFlow)) ; %Only consider specified molar flow rates
                ceq = specifiedGoalProductMolarFlow - specifiedCurrentProductMolarFlow ;
                number_ceq = length(specifiedGoalProductMolarFlow) ;
                
                % Target temperature and pressure constraints
                if ~isempty(goalProduct.T)
                    number_ceq = number_ceq + 1 ;
                    ceq(number_ceq) = goalProduct.T - currentProduct.T ;
                end
                if ~isempty(goalProduct.P)
                    number_ceq = number_ceq + 1 ;
                    ceq(number_ceq) = goalProduct.P - currentProduct.P ;
                end
                
                ceq = ceq' ;
                c = [] ;
            end
        end
        
        function  [optimalSize,minimumCost] = minimize_cost(R,Feed,RS,goalProduct)
            % This function computes the optimal residence time for a given reactor after specifying the desired output.
            % 
            % WARNING: If any variable is fixed by default in the output stream, it must be changed or erased.
            %          If the molar flow of any component in the product stream doesn't need to be specified, write NaN.(Authomatically made if app is used)
            % 
            % Syntax hint: fmincon(fun,x0,A,b,Aeq,beq,lb,ub,nonlcon,options)
            % Unknowns: x
            fun = @(x) optimize_cost(x,Feed,RS,R);
            x0 = [R.V] ;
            A = [] ;
            b = [] ;
            Aeq = [] ;
            beq = [] ;
            lb = [] ;
            ub = [] ;
            nonlcon = @(x) nonlconstraints(x,Feed,RS,R,goalProduct) ;
            options = optimoptions('fmincon','MaxIterations',100);
            
            [x,fval] = fmincon(fun,x0,A,b,Aeq,beq,lb,ub,nonlcon,options) ;
            optimalSize = x ;
            minimumCost = fval ;
            
            fprintf('The minimum cost time for the given reactor is %.3e $/year \n ',minimumCost) ;
            if isa(R,'Batch')
                fprintf('and the optimum reaction time is %f',x) ;
            else
                fprintf('and the optimum volume is %f',x) ;
            end
            
            %% Definition of the objective function and constraints
            
            function f = optimize_cost(x,Feed,RS,R)
                if isa(R,'Batch')
                    R.timeBatch = x ;
                else
                    R.V = x ;
                    if isa(R,'PFR')
                        R.L = R.V / (R.nTubes * pi*(R.diameterTubes/2)^2) ;
                    end
                end
                
                [Product,R] = R.compute_output(Feed,RS) ; 
                TAC = computeCost(R,Feed,Product) ;
                % Function fmincon works in the minimization direction. Therfore...
                f = TAC ;
            end
            
            function [c,ceq] = nonlconstraints(x,Feed,RS,R,goalProduct)
                % @nonlconstraints computes the nonlinear  constraints.
                % fmincon optimizes such that ceq(x) = 0 and c(x)<0
                
                if isa(R,'Batch')
                    R.timeBatch = x ;
                else
                    R.V = x ;
                    if isa(R,'PFR')
                        R.L = R.V / (R.nTubes * pi*(R.diameterTubes/2)^2) ;
                    end
                end
                
                currentProduct = R.compute_output(Feed,RS) ;
                
                % Target composition constraints
                specifiedGoalProductMolarFlow = goalProduct.molarFlow(~isnan(goalProduct.molarFlow)) ; %Only consider specified molar flow rates
                specifiedCurrentProductMolarFlow = currentProduct.molarFlow(~isnan(goalProduct.molarFlow)) ; %Only consider specified molar flow rates
                ceq = specifiedGoalProductMolarFlow - specifiedCurrentProductMolarFlow ;
                number_ceq = length(specifiedGoalProductMolarFlow) ;
                
                % Target temperature and pressure constraints
                if ~isempty(goalProduct.T)
                    number_ceq = number_ceq + 1 ;
                    ceq(number_ceq) = goalProduct.T - currentProduct.T ;
                end
                if ~isempty(goalProduct.P)
                    number_ceq = number_ceq + 1 ;
                    ceq(number_ceq) = goalProduct.P - currentProduct.P ;
                end
                
                ceq = ceq' ;
                c = [] ;
            end
        end
        
        % First attempt to solve a reactor with recyling streams
        % The iterative method has been dismissed since solving a
        % non-linear system is preferred
        function [Product,R] = compute_recyclingIterativeMethod(R,Feed,RS,recycleRatio)
            
            % ASSUMPTION: There is a compressor before the mixer that
            % assures that the pressure of the recycled stream is the same
            % as the feed stream before mixing.
            
            F_new = Feed ;
            
            error = 1 ;
            tolerance = 1e-6 ;
            
            % Deactivate plots before initating the iterative process
            if strcmp(R.activatePlots,'on')
                R.activatePlots = 'off' ;
                initialState = 'on' ; % Used later on in line 192
            end
            
            % Guess: value of the variables defining the output stream of the reactor R (not of the system Y)
            Guess = R.compute_output(Feed,RS) ;
            moles_guess = Guess.molarFlow ;
            %T_guess = Guess.T ;
            
            % Iterative method to compute the outlet stream of the reactor
            while error > tolerance
                
                moles_recycle = (recycleRatio/(1+recycleRatio))*moles_guess ;
                %T_recycle = T_guess ;
                
                F_new.molarFlow = Feed.molarFlow + moles_recycle ;
                %F_new.temperature = (RS.componentCp*moles_recycle'*T_recycle + RS.componentCp*F.molarFlow'*F.temperature)/(RS.componentCp*F_new.molarFlow') ;
                
                [outletStreamReactor,R] = R.compute_output(F_new,RS) ;
                
                error =  sum((moles_guess - outletStreamReactor.molarFlow).^2);% + abs(T_guess - R.T_out) ;
                
                moles_guess = outletStreamReactor.molarFlow ;
                %T_guess = outletStreamReactor.T ;
            end
            
            % Displaying plots with the result only if it was initially asked
            if exist('initialState','var')
                R.activatePlots = initialState ;
                R.compute_output(F_new,RS) ;
            end
            % Definition of the outlet stream of the system Y
            Product = Stream ;
            Product.phase = Feed.phase ;
            Product.molarFlow = outletStreamReactor.molarFlow - moles_recycle ;
            Product.T = outletStreamReactor.T ;
            Product.P = outletStreamReactor.P ;
            
        end
        
        
    end
end

