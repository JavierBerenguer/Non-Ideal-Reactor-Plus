classdef NirpSimulinkGuideTest < matlab.unittest.TestCase
%NIRPSIMULINKGUIDETEST Verify the flowsheet help entry points and assets.
% =========================================================================
% Javier Berenguer Sabater
% Created: October 12, 2026. Last update: October 22, 2026
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
            docs = fullfile(root,'docs') ;
            guideFiles = [string(fullfile(docs,'FlowsheetGuide.html')); ...
                string(fullfile(docs,'guides', ...
                {'flowsheet-getting-started.html';'flowsheet-reactive-system.html'; ...
                'flowsheet-streams.html';'flowsheet-reactors.html'; ...
                'flowsheet-units.html';'flowsheet-recycle-adjust.html'; ...
                'flowsheet-specifications.html';'flowsheet-running-results.html'; ...
                'flowsheet-examples.html'}))] ;
            html = "" ;
            imageBytes = [] ;
            for guide = reshape(guideFiles,1,[])
                testCase.assertTrue(isfile(guide),sprintf( ...
                    'Missing guide page: %s',guide)) ;
                page = fileread(guide) ;
                html = html+newline+string(page) ;
                imageBytes = [imageBytes validateLocalResources( ...
                    testCase,char(guide),page)] ; %#ok<AGROW>
            end
            required = ["Build and run a chemical-process flowsheet", ...
                "Create or Open a Flowsheet","Reactive System", ...
                "Recognize specified, calculated, waiting, and conflict states", ...
                "Configure Mixer, Splitter, Separator, and Heater", ...
                "Close recycle loops and meet design targets", ...
                "Guided Example: Three-Outlet Splitter", ...
                "Run the model and inspect results","Example Collection","Troubleshooting"] ;
            for heading = required
                testCase.verifySubstring(html,heading) ;
            end

            [~,descriptions] = nirp.flowsheet.exampleNames() ;
            for index = 1:numel(descriptions)
                testCase.verifySubstring(html,descriptions(index)) ;
            end

            forbidden = ["nirp.","NirpLibrary","exampleNames", ...
                "openLibrary","openExample","run_validation","()", ...
                "low-level HYSYS-style"] ;
            for token = forbidden
                testCase.verifyFalse(contains(html,token), ...
                    sprintf('Guide contains forbidden code identifier: %s',token)) ;
            end
            testCase.verifyEmpty(regexp(char(html),'<code(?:\s|>)','once')) ;
            testCase.verifyFalse(contains(lower(html),"auto-run")) ;
            testCase.verifySubstring(lower(html),"run or a defined feed") ;
            testCase.verifySubstring(lower(html),"specified values are blue") ;
            testCase.verifySubstring(html,"loop converges for the first time") ;
            testCase.verifySubstring(lower(html),"specify the outlet fractions") ;
            testCase.verifyNumElements(imageBytes,23) ;
            testCase.verifyLessThan(imageBytes,200*1024) ;
            indexHtml = fileread(fullfile(root,'docs','UserGuide.html')) ;
            testCase.verifySubstring(string(indexHtml), ...
                "The Simulink flowsheet tools are opened from the main Non-Ideal Reactor Plus screen") ;
            testCase.verifyFalse(contains(string(indexHtml), ...
                "low-level HYSYS-style")) ;
        end
    end
end

function imageBytes = validateLocalResources(testCase,guide,page)
    tokens = regexp(page,'(?:href|src)="([^"]+)"','tokens') ;
    imageTokens = regexp(page,'<img[^>]+src="([^"]+)"','tokens') ;
    imageBytes = zeros(1,numel(imageTokens)) ;
    imageIndex = 0 ;
    for index = 1:numel(tokens)
        relative = string(tokens{index}{1}) ;
        if startsWith(relative,"#") || contains(relative,":")
            continue
        end
        localPath = regexp(char(relative),'^[^#?]+','match','once') ;
        target = fullfile(fileparts(guide),strrep(localPath,'/',filesep)) ;
        testCase.verifyTrue(isfile(target),sprintf( ...
            'Missing local guide resource: %s',target)) ;
        if startsWith(tokens{index}{1},'../assets/') || ...
                startsWith(tokens{index}{1},'assets/')
            [~,~,extension] = fileparts(localPath) ;
            if any(strcmpi(extension,{'.png','.jpg','.jpeg','.gif','.svg'}))
                imageIndex = imageIndex+1 ;
                info = dir(target) ;
                imageBytes(imageIndex) = info.bytes ;
            end
        end
    end
    imageBytes = imageBytes(1:imageIndex) ;
end

function deleteValid(value)
    try
        if isvalid(value), delete(value) ; end
    catch
    end
end
