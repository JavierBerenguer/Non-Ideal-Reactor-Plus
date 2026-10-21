classdef NirpTracerCoreTest < matlab.unittest.TestCase
    % NirpTracerCoreTest verifies the non-ideal tracer flowsheet core.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 22, 2026. Last update: October 22, 2026
    % =========================================================================

    methods (Test)
        function twoCstrsMatchTwoTanksAndAddMoments(testCase)
            common = nirp.tracer.grid(0.02,40) ;
            source = nirp.tracer.source(common,1,ones(size(common.t)),1) ;
            cstr = nirp.tracer.rtdModel(common,'cstr',struct('tau',2),1) ;

            [first,firstInfo] = nirp.tracer.vessel(common,source,cstr) ;
            [second,secondInfo] = nirp.tracer.vessel(common,first,cstr) ;
            analytical = nirp.tracer.rtdModel(common,'tanks', ...
                struct('tau',4,'N',2),1) ;
            numericalMoments = nirp.tracer.moments(common,second.E) ;
            analyticalMoments = nirp.tracer.moments(common,analytical) ;

            testCase.verifyLessThan(max(abs(second.E-analytical)),5e-3) ;
            testCase.verifyEqual(numericalMoments.area,1,'AbsTol',5e-8) ;
            testCase.verifyEqual(numericalMoments.tau,4,'AbsTol',0.03) ;
            testCase.verifyEqual(numericalMoments.sigma2,8,'AbsTol',0.08) ;
            testCase.verifyEqual(numericalMoments.tau, ...
                2*nirp.tracer.moments(common,cstr).tau,'AbsTol',0.02) ;
            testCase.verifyEqual(numericalMoments.sigma2, ...
                2*nirp.tracer.moments(common,cstr).sigma2,'AbsTol',0.04) ;
            testCase.verifyEqual(numericalMoments.tau, ...
                analyticalMoments.tau,'AbsTol',0.03) ;
            testCase.verifyLessThan(firstInfo.fractionELost,1e-7) ;
            testCase.verifyLessThan(secondInfo.fractionELost,1e-7) ;
        end

        function pfrAndCstrParallelAreFlowWeighted(testCase)
            common = nirp.tracer.grid(0.01,30) ;
            source = nirp.tracer.source(common,2,ones(size(common.t)),10) ;
            [branches,fractions] = nirp.tracer.splitter(common,source,0.5) ;
            pfr = nirp.tracer.rtdModel(common,'pfr',struct('tau',3),1) ;
            cstr = nirp.tracer.rtdModel(common,'cstr',struct('tau',3),1) ;
            pfrOut = nirp.tracer.vessel(common,branches{1},pfr) ;
            cstrOut = nirp.tracer.vessel(common,branches{2},cstr) ;

            mixed = nirp.tracer.mixer(common,{pfrOut,cstrOut}) ;

            testCase.verifyEqual(fractions,[0.5 0.5],'AbsTol',1e-14) ;
            testCase.verifyEqual(mixed.E,0.5*pfr+0.5*cstr,'AbsTol',1e-13) ;
            testCase.verifyEqual(nirp.tracer.moments(common,mixed.E).area, ...
                1,'AbsTol',1e-12) ;
            testCase.verifyEqual(mixed.Q,source.Q,'AbsTol',1e-14) ;
        end

        function convolutionConservesFullAreaAndReportsTruncation(testCase)
            common = nirp.tracer.grid(0.1,5) ;
            concentration = zeros(size(common.t)) ;
            concentration(common.t <= 1) = 2 ;
            source = nirp.tracer.source(common,1,concentration,1) ;
            vesselRtd = nirp.tracer.rtdModel(common,'cstr',struct('tau',1),1) ;
            [out,info] = nirp.tracer.vessel(common,source,vesselRtd) ;
            areaIn = nirp.tracer.moments(common,source).area ;
            areaRtd = nirp.tracer.moments(common,vesselRtd).area ;

            testCase.verifyEqual(info.areaCFull,areaIn*areaRtd,'AbsTol',1e-12) ;
            testCase.verifyEqual(info.areaCFull, ...
                nirp.tracer.moments(common,out.C).area+info.areaCLost, ...
                'AbsTol',1e-12) ;
            testCase.verifyGreaterThan(info.areaCLost,0) ;
            testCase.verifyGreaterThan(info.fractionCLost,0) ;
        end

        function vesselMatchesSeriesConvolutionReference(testCase)
            dt = 0.05 ;
            common = nirp.tracer.grid(dt,41) ;
            e1 = zeros(size(common.t)) ;
            selected = common.t >= 2 & common.t <= 5 ;
            e1(selected) = (common.t(selected)-2)/18 ;
            selected = common.t > 5 & common.t <= 8 ;
            e1(selected) = 1/6 ;
            selected = common.t > 8 & common.t <= 11 ;
            e1(selected) = (11-common.t(selected))/18 ;
            e2 = zeros(size(common.t)) ;
            selected = common.t <= 30 ;
            e2(selected) = exp(-common.t(selected)/2)/2 ;
            stream = nirp.tracer.source(common,1,ones(size(common.t)),1) ;
            stream.E = e1 ;

            out = nirp.tracer.vessel(common,stream,e2) ;
            direct = nirp.conv.convolve( ...
                nirp.conv.signal(common.t,e2),nirp.conv.signal(common.t,e1)) ;

            testCase.verifyEqual(out.E,direct.C(1:common.length),'AbsTol',2e-14) ;
        end

        function differentSourcesMakeAccumulatedRtdUndefined(testCase)
            common = nirp.tracer.grid(0.1,2) ;
            first = nirp.tracer.source(common,1,ones(size(common.t)),1) ;
            second = nirp.tracer.source(common,3,2*ones(size(common.t)),2) ;

            mixed = nirp.tracer.mixer(common,{first,second}) ;

            testCase.verifyTrue(mixed.valid) ;
            testCase.verifyEqual(mixed.status,uint8(2)) ;
            testCase.verifyEqual(mixed.sourceId,uint32(0)) ;
            testCase.verifyEqual(mixed.C,1.75*ones(size(common.t)), ...
                'AbsTol',1e-14) ;
            testCase.verifyEqual(mixed.E,zeros(size(common.t))) ;
        end

        function sourcesModelsSessionsMomentsAndBusSatisfyContract(testCase)
            common = nirp.tracer.grid(0.5,10) ;
            fromFunction = nirp.tracer.sourceFunction(common,0.01, ...
                [0 2 4],{@(t) t,@(t) 4-t},7) ;
            fromData = nirp.tracer.sourceData(common,0.01, ...
                [0 2 4],[0 2 0],7) ;
            fromVolume = nirp.tracer.rtdModel(common,'cstr', ...
                struct('V',0.02),0.01) ;
            pfr = nirp.tracer.rtdModel(common,'pfr',struct('tau',2),0.01) ;
            tanks = nirp.tracer.rtdModel(common,'tanks', ...
                struct('tau',2,'N',2),0.01) ;
            openDispersion = nirp.tracer.rtdModel(common,'dispersion', ...
                struct('tau',2,'Pe',10,'boundary','open'),0.01) ;
            closedDispersion = nirp.tracer.rtdModel(common,'dispersion', ...
                struct('tau',2,'Pe',10,'boundary','closed'),0.01) ;
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            loaded = nirp.tracer.rtdSession(common,fullfile(root,'saves','SE51.mat')) ;
            values = nirp.tracer.moments(common,fromFunction.C) ;
            bus = nirp.tracer.bus(common) ;

            testCase.verifyEqual(fromFunction.C,fromData.C,'AbsTol',1e-14) ;
            testCase.verifyEqual(nirp.tracer.moments(common,fromFunction.E).area, ...
                1,'AbsTol',1e-14) ;
            testCase.verifyEqual(nirp.tracer.moments(common,fromVolume).tau, ...
                2,'AbsTol',0.3) ;
            testCase.verifyEqual(nirp.tracer.moments(common,loaded).area, ...
                1,'AbsTol',1e-12) ;
            testCase.verifyEqual([nirp.tracer.moments(common,pfr).area ...
                nirp.tracer.moments(common,tanks).area ...
                nirp.tracer.moments(common,openDispersion).area ...
                nirp.tracer.moments(common,closedDispersion).area], ...
                ones(1,4),'AbsTol',1e-12) ;
            testCase.verifyEqual(values.area,4,'AbsTol',1e-14) ;
            testCase.verifyEqual({bus.Elements.Name}, ...
                {'Q','C','E','sourceId','valid','status'}) ;
            testCase.verifyEqual(bus.Elements(2).Dimensions,[common.length 1]) ;
            testCase.verifyEqual(bus.Elements(3).Dimensions,[common.length 1]) ;
        end
    end
end
