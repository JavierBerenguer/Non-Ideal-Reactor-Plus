classdef NirpSimulinkGuideTest < matlab.unittest.TestCase
%NIRPSIMULINKGUIDETEST Verify the flowsheet help entry points and assets.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 12, 2026. Last update: October 12, 2026
% =========================================================================

    methods (Test)
        function reactiveSystemProvidesHelpButton(testCase)
            dialog = nirp.flowsheet.ReactiveSystemDialog('Visible','off') ;
            testCase.addTeardown(@() deleteValid(dialog)) ;
            button = findall(dialog.Figure,'Type','uibutton','Text','Help') ;
            testCase.verifyNumElements(button,1) ;
            testCase.verifyNotEmpty(button.ButtonPushedFcn) ;
        end

        function guideContainsExamplesAndValidLocalResources(testCase)
            root = fileparts(fileparts(mfilename('fullpath'))) ;
            guide = fullfile(root,'docs','guides','simulink-flowsheet.html') ;
            testCase.verifyTrue(isfile(guide)) ;
            html = fileread(guide) ;
            required = ["Overview","Creating a flowsheet","Reactive System", ...
                "Blocks","Recycles and Adjust","Results","Examples", ...
                "Troubleshooting"] ;
            for heading = required
                testCase.verifySubstring(string(html),heading) ;
            end

            [names,descriptions] = nirp.flowsheet.exampleNames() ;
            for index = 1:numel(names)
                testCase.verifySubstring(string(html),names(index)) ;
                testCase.verifySubstring(string(html),descriptions(index)) ;
            end

            tokens = regexp(html,'(?:href|src)="([^"]+)"','tokens') ;
            for index = 1:numel(tokens)
                relative = string(tokens{index}{1}) ;
                if startsWith(relative,"#") || contains(relative,":")
                    continue
                end
                target = fullfile(fileparts(guide),strrep(char(relative),'/',filesep)) ;
                testCase.verifyTrue(isfile(target),sprintf( ...
                    'Missing local guide resource: %s',target)) ;
            end

            images = dir(fullfile(root,'docs','assets','simulink','*.png')) ;
            testCase.verifyGreaterThanOrEqual(numel(images),4) ;
            testCase.verifyLessThanOrEqual(numel(images),6) ;
            testCase.verifyLessThan([images.bytes],200*1024) ;
            indexHtml = fileread(fullfile(root,'docs','UserGuide.html')) ;
            testCase.verifySubstring(string(indexHtml), ...
                "guides/simulink-flowsheet.html") ;
        end
    end
end

function deleteValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
