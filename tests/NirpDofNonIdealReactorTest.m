classdef NirpDofNonIdealReactorTest < matlab.unittest.TestCase
%NIRPDOFNONIDEALREACTORTEST RTD-reactor size catalogue regression tests.
% =========================================================================
% Javier Berenguer Sabater
% Created: November 3, 2026. Last update: November 3, 2026
% =========================================================================
    methods (Test)
        function modelClosesFromEachSizeBasis(testCase)
            model=nirp.dof.catalog.nonIdealReactor(struct('origin','model','model','CSTR'));
            cases={struct('V',2),struct('tau',4),struct('SV',0.25)};
            for i=1:numel(cases)
                names=fieldnames(cases{i});origins=struct('Q0','external');origins.(names{1})='specified';
                values=cases{i};values.Q0=0.5;result=nirp.dof.solve(model,values,origins);
                testCase.verifyEqual(result.status,'complete');
                testCase.verifyEqual(result.values.V,2,'RelTol',1e-12);
                testCase.verifyEqual(result.values.tau,4,'RelTol',1e-12);
                testCase.verifyEqual(result.values.SV,0.25,'RelTol',1e-12);
            end
        end
        function measuredTauIsExternalAndIncompatibleSizeConflicts(testCase)
            model=nirp.dof.catalog.nonIdealReactor(struct('origin','data'));
            result=nirp.dof.solve(model,struct('tau',4,'Q0',0.5),struct('tau','external','Q0','external'));
            testCase.verifyEqual(result.status,'complete');testCase.verifyEqual(result.origins.tau,'external');
            conflict=nirp.dof.solve(model,struct('tau',4,'Q0',0.5,'V',3), ...
                struct('tau','external','Q0','external','V','specified'));
            testCase.verifyEqual(conflict.status,'conflict');testCase.verifyTrue(any(conflict.conflicts=="V"));
            compatible=nirp.dof.solve(model,struct('tau',4,'Q0',0.5,'V',2*(1+5e-7)), ...
                struct('tau','external','Q0','external','V','specified'));
            testCase.verifyEqual(compatible.status,'complete');testCase.verifyFalse(any(compatible.conflicts=="V"));
            session=nirp.dof.catalog.nonIdealReactor(struct('origin','session'));
            testCase.verifyFalse(session.variables(strcmp({session.variables.name},'tau')).specifiable);
        end
        function modelSpecificVariablesAndIntegerRule(testCase)
            cstr=nirp.dof.catalog.nonIdealReactor(struct('origin','model','model','CSTR'));
            tanks=nirp.dof.catalog.nonIdealReactor(struct('origin','model','model','Tanks in series'));
            dispersion=nirp.dof.catalog.nonIdealReactor(struct('origin','model','model','Dispersion'));
            testCase.verifyFalse(any(strcmp({cstr.variables.name},'N')));testCase.verifyFalse(any(strcmp({cstr.variables.name},'Pe')));
            testCase.verifyTrue(any(strcmp({tanks.variables.name},'N')));testCase.verifyFalse(any(strcmp({tanks.variables.name},'Pe')));
            testCase.verifyTrue(any(strcmp({dispersion.variables.name},'Pe')));testCase.verifyFalse(any(strcmp({dispersion.variables.name},'N')));
            values=struct('Q0',1,'tau',2,'N',1.5);origins=struct('Q0','external','tau','specified','N','specified');
            result=nirp.dof.solve(tanks,values,origins);testCase.verifyEqual(result.status,'conflict');
        end
        function unknownInletIsDistinctFromMissingSize(testCase)
            model=nirp.dof.catalog.nonIdealReactor(struct('origin','model','model','CSTR'));
            pending=nirp.dof.solve(model,struct('Q0',NaN,'tau',2),struct('Q0','external','tau','specified'));
            missing=nirp.dof.solve(model,struct('Q0',NaN),struct('Q0','external'));
            testCase.verifyEqual(pending.status,'complete');testCase.verifyEqual(pending.missingCount,0);
            testCase.verifyEqual(missing.status,'missing');testCase.verifyGreaterThan(missing.missingCount,0);
        end
        function specificationsJsonRoundTrip(testCase)
            specs=struct('tau',struct('si',120,'unit','min'),'N',struct('si',4,'unit','1'));
            text=nirp.dof.writeSpecs(specs);actual=nirp.dof.readSpecs(text);
            testCase.verifyEqual(actual.tau.si,120);testCase.verifyEqual(actual.tau.unit,'min');
            testCase.verifyEqual(actual.N.si,4);testCase.verifyEqual(actual.N.unit,'1');
        end
    end
end
