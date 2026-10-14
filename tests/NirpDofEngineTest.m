classdef NirpDofEngineTest < matlab.unittest.TestCase
%NIRPDOFENGINETEST Tests the pure local degree-of-freedom engine.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    methods (Test)
        function propagatesAndClearsCalculatedValues(testCase)
            m=productModel();
            values=struct('x',2,'y',3,'z',99);origins=struct('x','specified','y','specified','z','calculated');
            r=nirp.dof.solve(m,values,origins);
            testCase.verifyEqual(r.values.z,6,'AbsTol',1e-15);
            testCase.verifyEqual(r.origins.z,'calculated');
            testCase.verifyEqual(r.producer.z,'product');
            testCase.verifyEqual(r.status,'complete');
        end

        function detectsResidualConflict(testCase)
            m=productModel();r=nirp.dof.solve(m,struct('x',2,'y',3,'z',7), ...
                struct('x','specified','y','specified','z','specified'));
            testCase.verifyEqual(r.status,'conflict');
            testCase.verifyEqual(sort(r.conflicts),["x" "y" "z"]);
            testCase.verifyTrue(any(contains(r.messages,'inconsistent')));
        end

        function detectsCalculatedRangeConflict(testCase)
            m=nirp.dof.model();
            m=nirp.dof.addVariable(m,'x','x','Value',struct());
            m=nirp.dof.addVariable(m,'y','y','Value',struct('bounds',[0 1]));
            m=nirp.dof.addRelation(m,'double',{'x','y'},struct('y',@(v)2*v.x),@(v)abs(v.y-2*v.x));
            r=nirp.dof.solve(m,struct('x',1),struct('x','specified'));
            testCase.verifyEqual(r.status,'conflict');
            testCase.verifyEqual(sort(r.conflicts),["x" "y"]);
        end

        function detectsCoherentOverSpecification(testCase)
            m=productModel();r=nirp.dof.solve(m,struct('x',2,'y',3,'z',6), ...
                struct('x','specified','y','specified','z','specified'));
            testCase.verifyEqual(r.status,'conflict');
            testCase.verifyTrue(any(contains(r.messages,'Over-specified')));
        end

        function countsOptionalAndExternalVariables(testCase)
            m=nirp.dof.model();
            m=nirp.dof.addVariable(m,'feed','Feed','Flow',struct('specifiable',false));
            m=nirp.dof.addVariable(m,'setting','Setting','Value',struct());
            m=nirp.dof.addVariable(m,'result','Result','Value',struct('specifiable',false));
            m=nirp.dof.addVariable(m,'note','Optional','Value',struct('optional',true));
            m=nirp.dof.addRelation(m,'sum',{'feed','setting','result'}, ...
                struct('result',@(v)v.feed+v.setting),@(v)abs(v.result-v.feed-v.setting));
            r=nirp.dof.solve(m,struct('feed',NaN),struct('feed','external'));
            testCase.verifyEqual(r.status,'missing');testCase.verifyEqual(r.missingCount,1);
            r=nirp.dof.solve(m,struct('feed',NaN,'setting',2),struct('feed','external','setting','specified'));
            testCase.verifyEqual(r.status,'complete');testCase.verifyEqual(r.states.note,'empty');
        end

        function emptyingSpecifiedValueReturnsItToEmpty(testCase)
            m=productModel();r=nirp.dof.solve(m,struct('x',[],'y',3),struct('x','specified','y','specified'));
            testCase.verifyEqual(r.states.x,'empty');testCase.verifyEqual(r.status,'missing');
        end

        function specificationsRoundTrip(testCase)
            specs=struct('V',struct('si',0.1,'unit','L'),'tau',struct('si',120,'unit','s'));
            text=nirp.dof.writeSpecs(specs);actual=nirp.dof.readSpecs(text);
            testCase.verifyEqual(actual,specs);
            testCase.verifyEqual(nirp.dof.writeSpecs(struct()),'');
        end
    end
end

function m=productModel()
    m=nirp.dof.model();
    m=nirp.dof.addVariable(m,'x','x','Value',struct());
    m=nirp.dof.addVariable(m,'y','y','Value',struct());
    m=nirp.dof.addVariable(m,'z','z','Value',struct());
    solvers=struct('x',@(v)v.z/v.y,'y',@(v)v.z/v.x,'z',@(v)v.x*v.y);
    m=nirp.dof.addRelation(m,'product',{'x','y','z'},solvers, ...
        @(v)abs(v.z-v.x*v.y)/max([abs(v.z) abs(v.x*v.y) 1e-12]));
end
