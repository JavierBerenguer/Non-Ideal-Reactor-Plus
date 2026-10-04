function TAC = computeCost(R,Feed,Product)
%% @computeCost computes the TAC of a given reactor
% 
% =========================================================================
% Isabela Fons Moreno-Palancas
% Last update: May 8th, 2020
% Updated: October 1, 2026 (T-102)
% =========================================================================% 
%% DATA
baseCEPCI = 397 ; % Appendix A. Tourton. All costs referred to 2001.

%>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
currentCEPCI = 595.4 ; % January 2020
interestRate = 0.1 ;
totalYears   = 10 ; %years
%<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<

%% 1. CAPITAL COST ESTIMATION (CAPEX)
V = R.V ;

if isa(R,'PFR')
    % Parameters taken for a horizontal process vessel made of carbon steel.
    % Estimation of the purchased cost (Cpº).
    K1 = 3.5565 ;
    K2 = 0.3776 ;
    K3 = 0.0905 ;
    CP = 10^(K1 + K2*log10(V) + K3*(log10(V))^2) ;
    
    % Estimation of the pressure factor (Fp or Fp,vessel)
    
    S = 994 ; % Maximum allowable stress for carbon steel (bar)
    E = 0.9 ; % Weld efficiency
    tmin = 0.0063 ; % Minimum thickness (m)
    CA = 0.00315 ; % Corrosion allowance (m)
    D = R.diameterTubes * R.nTubes ;
    
    P = max(Feed.P,Product.P) ;   % Pressure in Pa
    P = P/1e5 - 1 ;     % Pressure in barg (1 bar = 0 barg)
    
    FP = (P*D/(2*S*E-1.2*P) + CA)/tmin ;
    if FP < 1
        FP = 1 ;
    elseif P < -0.5
        FP = 1.25 ;
    end
    
    % Estimation of the barre module cost factor (FBM)
    B1 = 1.49 ;
    B2 = 1.52 ;
    FM = 1 ; % Material factor is =1 when the reactor is made of carbon steel
    FBM = B1 + B2 * FM * FP ;
    
elseif isa(R,'CSTR') || isa(R,'Batch')
    % Parameters taken for an agitated jacketed reactor made of carbon steel.
    % Estimation of the purchased cost (Cpº)
    K1      =  4.1052 ;
    K2      =  0.5320 ;
    K3      = -0.0005 ;
    Amin    =  0.5 ;
    Amax    =  35 ;
    CP = 10^(K1 + K2*log10(V) + K3*(log10(V))^2) ;
    
    % Estimation of the barre module cost factor (FBM)
    FBM = 4 ;
end

CBM_Reactor = CP * FBM ; % $ in 2001

if strcmp(R.heatMode,'Other')
    
    if isa(R,'PFR')
        A = 2*pi*(R.diameterTubes/2)*R.L * R.nTubes ;
    else
        A = R.heatTransferArea ;
    end
    
    K1      =  4.3247 ;
    K2      =  -0.3030 ;
    K3      =  0.1634 ;
    CP_Utility = 10^(K1 + K2*log10(A) + K3*(log10(A))^2) ;
    
    % Estimation of the barre module cost factor (FBM)
    FP_Utility = 1 ;
    B1_Utility  = 1.63 ;
    B2_Utility  = 1.66 ;
    FM_Utility  = 1 ; % Material factor is =1 when the reactor is made of carbon steel
    FBM_Utility  = B1_Utility  + B2_Utility  * FM_Utility  * FP_Utility  ;
    
    CBM_Utility = CP_Utility * FBM_Utility  ;
else
    CBM_Utility = 0 ;
end

CBM_2001 = CBM_Utility + CBM_Reactor ; % $ in 2001
CAPEX = CBM_2001* currentCEPCI/baseCEPCI ; % $ in 2020

%% 2. ANNUALIZATION FACTOR (F)
F = (interestRate*(1+interestRate)^totalYears)/((1+interestRate)^totalYears -1) ; % years^-1

%% 4. HEAT FLUX PROVIDED OR REMOVED
% Compute the heat flux (Q) to estimate operational costs in SI units (W or J/s)
% Q > 0 implies the reactor is being HEATED
% Q < 0 implies the reactor is being COOLED
if (isa(R,'CSTR') || isa(R,'PFR')) && ~isempty(R.heatDuty)
    Q = R.heatDuty ;
elseif strcmp(R.heatMode,'Adiabatic')
    Q = 0 ;
else
    
    if isa(R,'PFR')
        
        dQdL = R.heatArray ;
        L = linspace(0,R.L,length(dQdL)) ;
        Q = trapz(L,dQdL) ;
        
    elseif isa(R,'CSTR')
        
        Q = R.heatFlux ;
        
    elseif isa(R,'Batch')
        
        time = linspace(0,R.timeBatch,length(R.heatArray)) ;
        Q = trapz(time,R.heatArray) / R.timeBatch ; % Average value of the heat flux along the reaction time
        
    end 
end
%% 5. OPERATIONAL COST ESTIMATION 
if isempty(R.costUtility)
    if Q > 0
        price = 80 ; % $/kW/year
    else
        price = 10 ; % $/kW/year
    end
else
    price = R.costUtility ; % $/kW/year
end

OPEX = (abs(Q)/1000) * price ; % $/year

%% 6. TOTAL ANNUALIZED COST (TAC)
TAC = OPEX + CAPEX*F ; % $/year

end
        
