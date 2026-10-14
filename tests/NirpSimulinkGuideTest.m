classdef NirpSimulinkGuideTest < matlab.unittest.TestCase
%NIRPSIMULINKGUIDETEST Verify the flowsheet help entry points and assets.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 12, 2026. Last update: October 13, 2026
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
                "Specifications and degrees of freedom","Blocks", ...
                "Recycles and Adjust","Guided example: three-outlet Splitter", ...
                "Results","Examples","Troubleshooting"] ;
            for heading = required
                testCase.verifySubstring(string(html),heading) ;
            end

            [~,descriptions] = nirp.flowsheet.exampleNames() ;
            for index = 1:numel(descriptions)
                testCase.verifySubstring(string(html),descriptions(index)) ;
            end

            forbidden = ["nirp.","NirpLibrary","exampleNames", ...
                "openLibrary","openExample","run_validation","()", ...
                "low-level HYSYS-style"] ;
            for token = forbidden
                testCase.verifyFalse(contains(string(html),token), ...
                    sprintf('Guide contains forbidden code identifier: %s',token)) ;
            end
            testCase.verifyEmpty(regexp(html,'<code(?:\s|>)','once')) ;
            testCase.verifyFalse(contains(lower(string(html)),"auto-run")) ;
            testCase.verifySubstring(lower(string(html)),"run or a defined feed") ;
            testCase.verifySubstring(lower(string(html)),"specified values are blue") ;
            testCase.verifySubstring(string(html),"loop converges for the first time") ;
            testCase.verifySubstring(lower(string(html)),"specify the outlet fractions") ;
            testCase.verifySubstring(string(html), ...
                "basic chemical-process flowsheet") ;

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

            imageTokens = regexp(html,'<img[^>]+src="([^"]+)"','tokens') ;
            testCase.verifyNumElements(imageTokens,22) ;
            imageBytes = zeros(1,numel(imageTokens)) ;
            for index = 1:numel(imageTokens)
                relative = string(imageTokens{index}{1}) ;
                target = fullfile(fileparts(guide), ...
                    strrep(char(relative),'/',filesep)) ;
                testCase.verifyTrue(isfile(target),sprintf( ...
                    'Missing linked guide image: %s',target)) ;
                info = dir(target) ;
                imageBytes(index) = info.bytes ;
            end
            testCase.verifyLessThan(imageBytes,200*1024) ;
            indexHtml = fileread(fullfile(root,'docs','UserGuide.html')) ;
            testCase.verifySubstring(string(indexHtml), ...
                "guides/simulink-flowsheet.html") ;
            testCase.verifySubstring(string(indexHtml), ...
                "basic chemical-process flowsheet") ;
            testCase.verifyFalse(contains(string(indexHtml), ...
                "low-level HYSYS-style")) ;
        end
    end
end

function deleteValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
