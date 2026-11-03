classdef NirpConvolutionProblemsTest < matlab.unittest.TestCase
    % NirpConvolutionProblemsTest verifies the convolution problem sheet.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: November 3, 2026. Last update: November 3, 2026
    % =========================================================================

    methods (Test)
        function walasTrapezoidHasExpectedAreaAndMean(testCase)
            dt = 0.01 ; % s
            pulse = nirp.conv.fromFunction(@trapezoidInput, 0:dt:11) ;

            values = nirp.conv.moments(pulse) ;
            normalized = nirp.conv.signal(pulse.t, pulse.C / 18) ;
            normalizedValues = nirp.conv.moments(normalized) ;

            testCase.verifyEqual(values.area, 18, 'RelTol', 1e-4) ;
            testCase.verifyEqual(values.mean, 6.5, 'RelTol', 1e-4) ;
            testCase.verifyEqual(normalizedValues.area, 1, 'RelTol', 1e-4) ;
            testCase.verifyEqual(normalizedValues.mean, 6.5, 'RelTol', 1e-4) ;
        end

        function trapezoidThroughCstrMatchesIndependentOde(testCase)
            dt = 0.01 ; % s
            tau = 2 ; % s
            pulse = nirp.conv.fromFunction(@trapezoidInput, 0:dt:11) ;
            cstr = nirp.conv.fromRTD(RTD.ideal_cstr(tau), dt) ;

            outlet = nirp.conv.convolve(cstr, pulse) ;
            reference = cstrRK4(outlet.t, trapezoidInput(outlet.t), tau) ;
            sampleTimes = [3 5 8 10 12 15] ; % s
            actualSamples = interp1(outlet.t, outlet.C, sampleTimes) ;
            referenceSamples = interp1(outlet.t, reference, sampleTimes) ;
            printedReference = ...
                [0.2131 1.4463 2.6533 2.1367 0.8955 0.1998] ;

            testCase.verifyEqual(referenceSamples, printedReference, ...
                'AbsTol', 1e-4) ;
            testCase.verifyEqual(actualSamples, referenceSamples, ...
                'AbsTol', 2e-3) ;
            testCase.verifyEqual(actualSamples, printedReference, ...
                'AbsTol', 2e-3) ;
            [maximum, index] = max(outlet.C) ;
            testCase.verifyEqual(maximum, 2.680, 'AbsTol', 2e-3) ;
            testCase.verifyEqual(outlet.t(index), 8.32, 'AbsTol', 0.02) ;
            outletMoments = nirp.conv.moments(outlet) ;
            testCase.verifyEqual(outletMoments.area, 18, 'AbsTol', 2e-3) ;
        end

        function problemFourCstrMatchesIndependentOde(testCase)
            dt = 0.01 ; % s
            tau = 5 ; % s
            inletValues = [0 0 8 6 4 5 6 3 1 0 0 0] ;
            coarseInlet = nirp.conv.signal(0:11, inletValues) ;
            inlet = nirp.conv.resample(coarseInlet, dt) ;
            cstr = nirp.conv.fromRTD(RTD.ideal_cstr(tau), dt) ;

            outlet = nirp.conv.convolve(cstr, inlet) ;
            referenceInput = interp1(0:11, inletValues, outlet.t, ...
                'linear', 0) ;
            reference = cstrRK4(outlet.t, referenceInput, tau) ;
            sampleTimes = 2:12 ; % s
            actualSamples = interp1(outlet.t, outlet.C, sampleTimes) ;
            referenceSamples = interp1(outlet.t, reference, sampleTimes) ;
            printedReference = [0.7492 1.8763 2.4365 2.8135 3.3035 ...
                3.5114 3.2314 2.7332 2.2378 1.8321 1.5000] ;

            testCase.verifyEqual(referenceSamples, printedReference, ...
                'AbsTol', 1e-4) ;
            testCase.verifyEqual(actualSamples, referenceSamples, ...
                'AbsTol', 5e-3) ;
            testCase.verifyEqual(actualSamples, printedReference, ...
                'AbsTol', 5e-3) ;
        end

        function problemFourReportsOneSecondGridDiagnostic(testCase)
            tau = 5 ; % s
            inletValues = [0 0 8 6 4 5 6 3 1 0 0 0] ;
            inlet = nirp.conv.signal(0:11, inletValues) ;
            cstr = nirp.conv.fromRTD(RTD.ideal_cstr(tau), 1) ;

            outlet = nirp.conv.convolve(cstr, inlet) ;
            sampleTimes = 2:12 ; % s
            coreSamples = interp1(outlet.t, outlet.C, sampleTimes) ;
            referenceTime = 0:0.01:12 ; % s
            referenceInput = interp1(0:11, inletValues, referenceTime, ...
                'linear', 0) ;
            odeReference = cstrRK4(referenceTime, referenceInput, tau) ;
            odeSamples = interp1(referenceTime, odeReference, sampleTimes) ;
            bookE = exp(-(0:12) / tau) / tau ;
            bookOutlet = conv(inletValues, bookE) ;
            bookSamples = bookOutlet(3:13) ;

            fprintf('Problem 4, dt = 1 s, core C_out(t = 2:12): %s\n', ...
                mat2str(coreSamples, 6)) ;
            fprintf('Problem 4, dt = 1 s, ODE C_out(t = 2:12):  %s\n', ...
                mat2str(odeSamples, 6)) ;
            fprintf('Problem 4, dt = 1 s, core minus ODE:       %s\n', ...
                mat2str(coreSamples - odeSamples, 6)) ;
            fprintf('Problem 4, book left sum at t = 2:12:     %s\n', ...
                mat2str(bookSamples, 6)) ;
            testCase.verifySize(coreSamples, [1 11]) ;
            testCase.verifyTrue(all(isfinite(coreSamples))) ;
        end

        function problemFivePfrIsExactFiveSecondShift(testCase)
            inletValues = [0 0 8 6 4 5 6 3 1 0 0 0] ;
            inlet = nirp.conv.signal(0:11, inletValues) ;
            pfr = nirp.conv.fromRTD(RTD.ideal_pfr(5), 1) ;

            outlet = nirp.conv.convolve(pfr, inlet) ;
            expected = [zeros(1, 5) inletValues ...
                zeros(1, numel(outlet.C) - numel(inletValues) - 5)] ;

            testCase.verifyEqual(outlet.C, expected, 'AbsTol', 1e-12) ;
        end

        function problemSixRecoversExactAndPrintedDistributions(testCase)
            inletValues = [0 0 8 6 4 5 6 3 1 0 0 0] ;
            inlet = nirp.conv.signal(0:11, inletValues) ;
            exactValues = [0 .05 .5 .35 .1 0] ;
            exactOutletValues = conv(inletValues, exactValues) ;
            exactOutlet = nirp.conv.signal(0:16, exactOutletValues) ;

            recoveredExact = nirp.conv.deconvolve(inlet, exactOutlet, [0 5]) ;

            testCase.verifyEqual(recoveredExact.C, exactValues, ...
                'AbsTol', 1e-8) ;

            % The printed data are rounded down (5.15 -> 5.1, 4.15 -> 4.1,
            % and so on). The value 5.63 at t = 8 is inconsistent with the
            % E distribution from problem 3, which would give 5.3.
            printedValues = [0 0 0 .4 4.3 6 5.1 4.8 5.63 4.1 ...
                2.1 .6 .1 0 0 0] ;
            printedOutlet = nirp.conv.signal(0:15, printedValues) ;
            recoveredPrinted = nirp.conv.deconvolve( ...
                inlet, printedOutlet, [0 5]) ;
            convolutionMatrix = zeros(numel(printedValues), 6) ;
            for row = 1:size(convolutionMatrix, 1)
                for column = 1:size(convolutionMatrix, 2)
                    inletIndex = row - column + 1 ;
                    if inletIndex >= 1 && inletIndex <= numel(inletValues)
                        convolutionMatrix(row, column) = ...
                            inletValues(inletIndex) ;
                    end
                end
            end
            unconstrained = convolutionMatrix \ printedValues.' ;
            expectedUnconstrained = [-0.00310847 0.04790625 0.51309322 ...
                0.35134118 0.08656060 0.01085816] ;

            testCase.verifyEqual(unconstrained.', expectedUnconstrained, ...
                'AbsTol', 5e-7) ;
            testCase.verifyEqual(recoveredPrinted.C, ...
                [0 .048 .513 .351 .087 .011], 'AbsTol', 0.01) ;
            testCase.verifyEqual(recoveredPrinted.C(1), 0, 'AbsTol', 1e-12) ;
        end

        function savedSessionsMatchIndependentReferences(testCase)
            % SEC04-SEC06 are the Tab 6 sessions of problems 4-6; their
            % stored results must agree with the independent references.
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            inletValues = [0 0 8 6 4 5 6 3 1 0 0 0] ;

            sec04 = sessionReference(root, 'SEC04') ;
            fineTime = 0:0.01:sec04(end, 1) ;
            fineInlet = interp1(0:11, inletValues, fineTime, 'linear', 0) ;
            fineOutlet = cstrRK4(fineTime, fineInlet, 5) ;
            testCase.verifyEqual(sec04(:, 2), ...
                interp1(fineTime, fineOutlet, sec04(:, 1)), 'AbsTol', 0.015) ;

            sec05 = sessionReference(root, 'SEC05') ;
            shifted = interp1(0:11, inletValues, sec05(:, 1) - 5, 'linear', 0) ;
            testCase.verifyEqual(sec05(:, 2), shifted, 'AbsTol', 1e-9) ;

            % SEC06 stores the printed, rounded C_out (5.6 at t = 8 s; the
            % sheet splits the cell as "5.6 / 3") and an E support of 0-4 s:
            % an independent NNLS on the stored data must reproduce it, and
            % it stays within 0.02 of the true E of problem 3.
            sec06 = sessionReference(root, 'SEC06') ;
            saved = load(fullfile(root, 'saves', 'SEC06.mat'), 'sessionData') ;
            printedOutlet = ...
                saved.sessionData.convolution.signals.Cout.tableData(:, 2).' ;
            convolutionMatrix = zeros(numel(printedOutlet), 5) ;
            for column = 1:5
                rows = column:min(column + numel(inletValues) - 1, ...
                    numel(printedOutlet)) ;
                convolutionMatrix(rows, column) = ...
                    inletValues(1:numel(rows)) ;
            end
            independent = lsqnonneg(convolutionMatrix, printedOutlet.') ;
            testCase.verifyEqual(sec06(:, 2), independent, 'AbsTol', 1e-6) ;
            testCase.verifyEqual(sec06(:, 2).', [0 .05 .5 .35 .1], ...
                'AbsTol', 0.02) ;
        end
    end
end

function table = sessionReference(root, name)
    saved = load(fullfile(root, 'saves', [name '.mat']), 'sessionData') ;
    table = saved.sessionData.convolution.referenceTable ;
end

function values = trapezoidInput(time)
    values = zeros(size(time)) ;
    rising = time >= 2 & time < 5 ;
    plateau = time >= 5 & time <= 8 ;
    falling = time > 8 & time <= 11 ;
    values(rising) = time(rising) - 2 ;
    values(plateau) = 3 ;
    values(falling) = 11 - time(falling) ;
end

function outlet = cstrRK4(time, inlet, tau)
    outlet = zeros(size(time)) ;
    for index = 1:numel(time)-1
        step = time(index + 1) - time(index) ;
        midpointInlet = (inlet(index) + inlet(index + 1)) / 2 ;
        k1 = (inlet(index) - outlet(index)) / tau ;
        k2 = (midpointInlet - (outlet(index) + step * k1 / 2)) / tau ;
        k3 = (midpointInlet - (outlet(index) + step * k2 / 2)) / tau ;
        k4 = (inlet(index + 1) - (outlet(index) + step * k3)) / tau ;
        outlet(index + 1) = outlet(index) + ...
            step * (k1 + 2 * k2 + 2 * k3 + k4) / 6 ;
    end
end
