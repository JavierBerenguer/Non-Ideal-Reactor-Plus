classdef NirpDofFeedSeparatorTest < matlab.unittest.TestCase
%NIRPDOFFEEDSEPARATORTEST Feed, Separator, and Mixer DOF catalogues (T-153).
% =========================================================================
% Javier Berenguer Sabater
% Created: October 14, 2026. Last update: October 14, 2026
% =========================================================================
    methods (Test)
        function feedCatalogueClosesMolarConcentrationAndFractionBases(testCase)
            liquid=nirp.dof.catalog.feed(struct('nComponents',2,'phase','L'));
            gas=nirp.dof.catalog.feed(struct('nComponents',2,'phase','G'));
            testCase.verifyEqual(catalogDof(liquid),5);
            testCase.verifyEqual(catalogDof(gas),4);

            r=solve(liquid,struct('F1',1,'F2',2,'Q',0.01,'T',300,'P',1e5));
            testCase.verifyEqual(r.status,'complete');testCase.verifyEqual([r.values.C1 r.values.C2],[100 200],'RelTol',1e-12);
            testCase.verifyEqual([r.values.x1 r.values.x2],[1/3 2/3],'RelTol',1e-12);testCase.verifyEqual(r.values.C_tot,300,'RelTol',1e-12);

            r=solve(liquid,struct('C1',100,'C2',200,'Q',0.01,'T',300,'P',1e5));
            testCase.verifyEqual([r.values.F1 r.values.F2],[1 2],'RelTol',1e-12);
            r=solve(liquid,struct('x1',1/3,'F',3,'Q',0.01,'T',300,'P',1e5));
            testCase.verifyEqual([r.values.F1 r.values.F2],[1 2],'RelTol',1e-12);

            r=solve(gas,struct('F1',1,'F2',2,'T',300,'P',101325));
            testCase.verifyEqual(r.values.Q,3*8.314*300/101325,'RelTol',1e-12);
            r=solve(gas,struct('C1',101325/(8.314*300)/3,'C2',2*101325/(8.314*300)/3,'Q',3*8.314*300/101325,'T',300));
            testCase.verifyEqual(r.values.P,101325,'RelTol',1e-12);
        end

        function gasFeedClosesRemainingFractionFromSpecifiedVolume(testCase)
            components=struct('name',{'A','B','Inert'});
            gas=nirp.dof.catalog.feed(struct('components',components,'phase','G'));
            specified=struct('x1',0.6,'x3',0.4,'P',25*101325,'T',623.15,'Q',0.01);
            r=solve(gas,specified);expectedF=specified.Q*specified.P/(8.314*specified.T);
            testCase.verifyEqual(r.status,'complete');
            testCase.verifyEqual(r.values.x2,0,'AbsTol',1e-14);
            testCase.verifyEqual(r.values.F,expectedF,'RelTol',1e-12);
            testCase.verifyEqual([r.values.F1 r.values.F2 r.values.F3],expectedF*[0.6 0 0.4],'RelTol',1e-12,'AbsTol',1e-14);
            testCase.verifyEqual([r.values.C1 r.values.C2 r.values.C3],[r.values.F1 r.values.F2 r.values.F3]/specified.Q,'RelTol',1e-12,'AbsTol',1e-14);

            missing=rmfield(specified,'Q');r=solve(gas,missing);
            testCase.verifyEqual(r.status,'missing');testCase.verifyEqual(r.missingCount,1);
            testCase.verifySubstring(r.messages(end),'a flow (total molar flow, volumetric flow or a component flow)');
            testCase.verifyFalse(contains(r.messages(end),'F1'));
        end

        function massBasisAppearsOnlyWithCompleteMolecularWeights(testCase)
            withMw=nirp.dof.catalog.feed(struct('nComponents',2,'phase','L','Mw',[18 44]));
            withoutMw=nirp.dof.catalog.feed(struct('nComponents',2,'phase','L','Mw',[18 NaN]));
            testCase.verifyTrue(any(strcmp({withMw.variables.name},'mdot1')));
            testCase.verifyFalse(any(strcmp({withoutMw.variables.name},'mdot1')));
            testCase.verifyEqual(catalogDof(withMw),5);
            r=solve(withMw,struct('w1',18/106,'mdot',0.106,'Q',0.01,'T',300,'P',1e5));
            testCase.verifyEqual([r.values.F1 r.values.F2],[1 2],'RelTol',1e-12);
            testCase.verifyEqual([r.values.mdot1 r.values.mdot2],[0.018 0.088],'RelTol',1e-12);
            r=solve(withMw,struct('mdot1',0.018,'mdot2',0.088,'Q',0.01,'T',300,'P',1e5));
            testCase.verifyEqual([r.values.w1 r.values.w2],[18/106 88/106],'RelTol',1e-12);
        end

        function separatorClosesEverySupportedSpecificationDirection(testCase)
            model=nirp.dof.catalog.separator(2);testCase.verifyEqual(numel(model.variables)-numel(model.relations)-2,2);
            inlet=struct('F_in1',2,'F_in2',3);external=struct('F_in1','external','F_in2','external');
            r=solveWithOrigins(model,merge(inlet,struct('r1',0.25,'r2',0.5)),merge(external,specified({'r1','r2'})));
            testCase.verifyEqual([r.values.F_top1 r.values.F_top2],[0.5 1.5],'AbsTol',1e-14);
            r=solveWithOrigins(model,merge(inlet,struct('F_top1',0.5,'F_top2',1.5)),merge(external,specified({'F_top1','F_top2'})));
            testCase.verifyEqual([r.values.r1 r.values.r2],[0.25 0.5],'RelTol',1e-12);
            r=solveWithOrigins(model,merge(inlet,struct('F_bot1',1.5,'F_bot2',1.5)),merge(external,specified({'F_bot1','F_bot2'})));
            testCase.verifyEqual([r.values.r1 r.values.r2],[0.25 0.5],'RelTol',1e-12);
            r=solveWithOrigins(model,merge(inlet,struct('x_top1',0.25,'F_top2',1.5)),merge(external,specified({'x_top1','F_top2'})));
            testCase.verifyEqual([r.values.r1 r.values.r2],[0.25 0.5],'RelTol',1e-12);
            conflict=solveWithOrigins(model,merge(inlet,struct('r1',0.25,'r2',0.5,'F_top1',1)),merge(external,specified({'r1','r2','F_top1'})));
            testCase.verifyEqual(conflict.status,'conflict');
            noInlet=solveWithOrigins(model,struct('r1',0.25,'r2',0.5),merge(struct('F_in1','external','F_in2','external'),specified({'r1','r2'})));
            testCase.verifyEqual(noInlet.status,'complete');testCase.verifyTrue(isnan(noInlet.values.F_top1));
        end

        function mixerCatalogueHasNoRequiredSpecification(testCase)
            model=nirp.dof.catalog.mixer(3);result=nirp.dof.solve(model,struct(),struct());
            testCase.verifyEqual(result.status,'complete');testCase.verifyEqual(result.missingCount,0);
            testCase.verifyTrue(all(~[model.variables.specifiable]));
        end

        function catalogueStatusMessagesUseUserLabels(testCase)
            components=struct('name',{'A','B'});
            models={nirp.dof.catalog.feed(struct('components',components,'phase','G')), ...
                nirp.dof.catalog.cstr(struct('catalytic',true)), ...
                nirp.dof.catalog.pfr(struct('catalytic',true)), ...
                nirp.dof.catalog.heater(struct()),nirp.dof.catalog.jacket(struct('mode','Utility')), ...
                nirp.dof.catalog.mixer(struct('components',components)), ...
                nirp.dof.catalog.splitter(2),nirp.dof.catalog.separator(struct('components',components))};
            pattern='(?<![A-Za-z0-9_])(F1|C1|x1|mdot1|w1|F_out1|F_top1|F_bot1|x_top1|x_bot1|Q0|T_out|P_out|T_in_s)(?![A-Za-z0-9_])';
            for i=1:numel(models)
                result=nirp.dof.solve(models{i},struct(),struct());message=strjoin(result.messages,' ');
                testCase.verifyFalse(strcmp(models{i}.variables(1).label,models{i}.variables(1).name), ...
                    sprintf('Catalogue %d starts with an internal label.',i));
                testCase.verifyEmpty(regexp(message,pattern,'once'), ...
                    sprintf('Catalogue %d exposed an internal variable in "%s".',i,message));
            end
        end
    end
end

function result=solve(model,values),names=fieldnames(values);origins=struct();for i=1:numel(names),origins.(names{i})='specified';end;result=nirp.dof.solve(model,values,origins);end
function result=solveWithOrigins(model,values,origins),result=nirp.dof.solve(model,values,origins);end
function value=specified(names),value=struct();for i=1:numel(names),value.(names{i})='specified';end,end
function value=merge(first,second),value=first;names=fieldnames(second);for i=1:numel(names),value.(names{i})=second.(names{i});end,end
function value=catalogDof(model),value=numel(model.variables)-sum(~[model.relations.redundant]);end
