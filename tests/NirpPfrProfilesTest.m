classdef NirpPfrProfilesTest < matlab.unittest.TestCase
    % NirpPfrProfilesTest verifies stored and displayed PFR profiles.
    % =========================================================================
    % Javier Berenguer Sabater
    % Created: October 9, 2026. Last update: October 9, 2026
    % =========================================================================

    properties
        Folder
        SimulinkFolder
        FileGenerationConfig
    end

    methods (TestMethodSetup)
        function createTemporaryWorkspace(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture) ;
            testCase.Folder = fixture.Folder ;
            testCase.SimulinkFolder = fullfile( ...
                fileparts(fileparts(mfilename('fullpath'))),'simulink') ;
            addpath(testCase.SimulinkFolder) ; addpath(testCase.Folder) ;
            testCase.FileGenerationConfig = Simulink.fileGenControl('getConfig') ;
            Simulink.fileGenControl('set', ...
                'CacheFolder',fullfile(testCase.Folder,'cache'), ...
                'CodeGenFolder',fullfile(testCase.Folder,'codegen'), ...
                'createDir',true) ;
            testCase.addTeardown(@() Simulink.fileGenControl( ...
                'setConfig','config',testCase.FileGenerationConfig)) ;
            testCase.addTeardown(@() removePath(testCase.SimulinkFolder)) ;
            testCase.addTeardown(@() removePath(testCase.Folder)) ;
            testCase.addTeardown(@() closeArtifacts()) ;
        end
    end

    methods (Test)
        function goldenMasterOutputsAreUnchanged(testCase)
            files = build_examples(testCase.Folder) ;
            verifyModelGolden(testCase,files(12), ...
                'ex12_problem19_adiabatic_pfr', ...
                [6.3964825856387604;6.3964825856387604; ...
                9.6035174143612423;8],779.53069729110405,202650,0) ;
            verifyModelGolden(testCase,files(13), ...
                'ex13_problem21a_isothermal_pfr', ...
                [3.333333333333337;14.999999999999996; ...
                3.7037037037037042],387.37111880600935, ...
                55084868.888888888,160526.82583734844) ;
            verifyModelGolden(testCase,files(43), ...
                'ex43_problem15_number_of_tubes', ...
                [26.321163501802467;9.8704363131759241; ...
                16.450727188626544],823.14999999999998,2026500,0) ;

            pkg = nirp.pkg.examples.problem27Jacketed() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            [product,info] = nirp.units.pfr(struct('V',0.1,'D',0.1, ...
                'heatMode','Other','U',50,'utilityTin',280),feed,rs) ;
            verifyGolden(testCase,product,info, ...
                [0.55309846332496093;16.113568203341703], ...
                410.60731814045687,101325,-15733.330153818022) ;

            pkg = nirp.pkg.examples.problem17AdiabaticGas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            [product,info] = nirp.units.pfr(struct( ...
                'V',0.01,'D',0.1,'heatMode','Isothermal', ...
                'pressureMode','Non constant','pressureDropEqn','Ergun', ...
                'catalystPorosity',0.4,'viscosity',2e-5, ...
                'particleDiameter',0.01),feed,rs) ;
            verifyGolden(testCase,product,info, ...
                [0.014222417009758397;0.014222417009758397; ...
                0.0031386941013527162;0.0031386941013527162], ...
                523.14999999999998,202594.553729448,131.19741343654354) ;
        end

        function profileIsCoherentForThermalAndPressureModes(testCase)
            pkg = nirp.pkg.examples.problem21Gas() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            [product,info] = nirp.units.pfr(struct( ...
                'V',1,'D',0.1,'heatMode','Isothermal'),feed,rs) ;
            profile = info.profile ;

            testCase.verifySize(profile.F,[201 rs.nComponents]) ;
            testCase.verifyEqual(profile.F(1,:),feed.F','AbsTol',1e-12) ;
            testCase.verifyEqual(profile.T(1),feed.T,'AbsTol',1e-12) ;
            testCase.verifyEqual(profile.P(1),feed.P,'AbsTol',1e-12) ;
            testCase.verifyEqual(profile.F(end,:),product.F','RelTol',1e-10) ;
            testCase.verifyEqual(profile.T(end),product.T,'RelTol',1e-10) ;
            testCase.verifyEqual(profile.P(end),product.P,'RelTol',1e-10) ;
            testCase.verifyEqual(profile.V(end),1,'RelTol',1e-12) ;
            testCase.verifyEqual(profile.T,repmat(feed.T,201,1), ...
                'AbsTol',1e-10) ;
            extent = (profile.F(:,1)-feed.F(1))/rs.stochiometricMatrix(1) ;
            expected = feed.F'+extent*rs.stochiometricMatrix ;
            scale = max(abs(profile.F),[],'all') ;
            testCase.verifyLessThanOrEqual( ...
                max(abs(profile.F-expected),[],'all'),1e-9*scale) ;

            exothermicPkg = nirp.pkg.examples.problem27Jacketed() ;
            exothermicRs = nirp.pkg.toReactionSys(exothermicPkg) ;
            exothermicFeed = nirp.pkg.feedStream(exothermicPkg,"F1") ;
            [~,adiabatic] = nirp.units.pfr(struct( ...
                'V',0.1,'D',0.1,'heatMode','Adiabatic'), ...
                exothermicFeed,exothermicRs) ;
            testCase.verifyGreaterThanOrEqual(diff(adiabatic.profile.T),-1e-10) ;
            testCase.verifyEqual(adiabatic.profile.Q(end), ...
                adiabatic.heatDuty,'AbsTol',1e-9) ;
            [~,other] = nirp.units.pfr(struct('V',0.1,'D',0.1, ...
                'heatMode','Other','U',50,'utilityTin',280), ...
                exothermicFeed,exothermicRs) ;
            testCase.verifyEqual(other.profile.Q(end),other.heatDuty, ...
                'RelTol',1e-9,'AbsTol',1e-9) ;

            pressurePkg = nirp.pkg.examples.problem17AdiabaticGas() ;
            pressureRs = nirp.pkg.toReactionSys(pressurePkg) ;
            pressureFeed = nirp.pkg.feedStream(pressurePkg,"F1") ;
            [pressureProduct,pressure] = nirp.units.pfr(struct( ...
                'V',0.01,'D',0.1,'heatMode','Isothermal', ...
                'pressureMode','Non constant','pressureDropEqn','Ergun', ...
                'catalystPorosity',0.4,'viscosity',2e-5, ...
                'particleDiameter',0.01),pressureFeed,pressureRs) ;
            testCase.verifyLessThan(pressure.profile.P(end),pressure.profile.P(1)) ;
            testCase.verifyEqual(pressure.profile.P(end),pressureProduct.P, ...
                'RelTol',1e-10) ;
        end

        function profileCoversTheCompleteTubeBank(testCase)
            pkg = nirp.pkg.examples.problem15Acetylene() ;
            rs = nirp.pkg.toReactionSys(pkg) ;
            feed = nirp.pkg.feedStream(pkg,"F1") ;
            [product,info] = nirp.units.pfr(struct( ...
                'V',1,'D',0.2,'nTubes',4,'heatMode','Isothermal'),feed,rs) ;

            testCase.verifyEqual(info.profile.F(1,:),feed.F','AbsTol',1e-12) ;
            testCase.verifyEqual(info.profile.F(end,:),product.F','RelTol',1e-10) ;
            testCase.verifyEqual(info.profile.V(end),1,'RelTol',1e-12) ;
            testCase.verifyEqual(string(info.profile.componentNames), ...
                string(rs.componentNames)) ;
        end

        function resultsExposeProfileTablesAndWindow(testCase)
            files = build_examples(testCase.Folder) ;
            load_system(char(files(12))) ; sim('ex12_problem19_adiabatic_pfr') ;
            tables = nirp.flowsheet.showResults( ...
                'ex12_problem19_adiabatic_pfr','NoWindow',true) ;
            testCase.assertTrue(isfield(tables,'Profiles')) ;
            testCase.assertTrue(isfield(tables.Profiles,'PFR')) ;
            profileTable = tables.Profiles.PFR ;
            testCase.verifyEqual(height(profileTable),201) ;
            testCase.verifyEqual(profileTable.Properties.VariableUnits(1:5), ...
                {'m^3','m','K','Pa','W'}) ;
            testCase.verifyTrue(all(ismember( ...
                {'V','L','T','P','Q','F_A','F_B','F_C','F_I'}, ...
                profileTable.Properties.VariableNames))) ;

            nirp.flowsheet.showResults( ...
                'ex12_problem19_adiabatic_pfr','Visible','off') ;
            figureHandle = findall(groot,'Type','Figure', ...
                'Name','NIRP results - ex12_problem19_adiabatic_pfr') ;
            testCase.assertNotEmpty(figureHandle) ;
            tabs = findall(figureHandle(1),'Type','uitab') ;
            profileTab = tabs(string({tabs.Title}) == "PFR profiles") ;
            testCase.assertEqual(numel(profileTab),1) ;
            axesHandles = findall(profileTab,'Type','axes') ;
            testCase.verifyEqual(numel(axesHandles),4) ;
            for i = 1:numel(axesHandles)
                testCase.verifyGreaterThan(numel(axesHandles(i).Children),0) ;
            end
            delete(figureHandle) ; close_system('ex12_problem19_adiabatic_pfr',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            evalin('base','clear nirpResults') ;
            load_system(char(files(1))) ; sim('ex1_cstr_isothermal') ;
            tables = nirp.flowsheet.showResults( ...
                'ex1_cstr_isothermal','Visible','off') ;
            testCase.verifyFalse(isfield(tables,'Profiles')) ;
            figureHandle = findall(groot,'Type','Figure', ...
                'Name','NIRP results - ex1_cstr_isothermal') ;
            tabs = findall(figureHandle(1),'Type','uitab') ;
            testCase.verifyFalse(any(string({tabs.Title}) == "PFR profiles")) ;
            delete(figureHandle) ; close_system('ex1_cstr_isothermal',0) ;
            Simulink.data.dictionary.closeAll('-discard') ;

            evalin('base','clear nirpResults') ;
            load_system(char(files(21))) ;
            set_param('ex21_problem17_adiabatic_pfr_volume/PFR', ...
                'PressureMode','Non constant','PressureDropEqn','Ergun', ...
                'CatalystPorosity','0.4','ParticleDiameter','10', ...
                'ParticleDiameterUnit','mm','Viscosity','2e-5', ...
                'ViscosityUnit','Pa*s') ;
            sim('ex21_problem17_adiabatic_pfr_volume') ;
            nirp.flowsheet.showResults( ...
                'ex21_problem17_adiabatic_pfr_volume','Visible','off') ;
            figureHandle = findall(groot,'Type','Figure', ...
                'Name','NIRP results - ex21_problem17_adiabatic_pfr_volume') ;
            tabs = findall(figureHandle(1),'Type','uitab') ;
            profileTab = tabs(string({tabs.Title}) == "PFR profiles") ;
            axesHandles = findall(profileTab,'Type','axes') ;
            titles = string(arrayfun(@(ax) ax.Title.String,axesHandles, ...
                'UniformOutput',false)) ;
            testCase.verifyTrue(any(titles == "Pressure")) ;
            testCase.verifyFalse(any(titles == "Accumulated heat")) ;
        end
    end
end

function verifyModelGolden(testCase,file,name,F,T,P,Q)
    load_system(char(file)) ; sim(name) ;
    results = evalin('base','nirpResults') ;
    product = results.Streams.Product.streamSI ;
    field = matlab.lang.makeValidName(string(name)+"_PFR") ;
    info = results.Diagnostics.(field).lastInfo ;
    verifyGolden(testCase,product,info,F,T,P,Q) ;
    close_system(name,0) ; Simulink.data.dictionary.closeAll('-discard') ;
end

function verifyGolden(testCase,product,info,F,T,P,Q)
    testCase.verifyTrue(isequal(product.F,F)) ;
    testCase.verifyTrue(isequal(product.T,T)) ;
    testCase.verifyTrue(isequal(product.P,P)) ;
    testCase.verifyTrue(isequal(info.heatDuty,Q)) ;
end

function closeArtifacts()
    figures = findall(groot,'Type','Figure') ;
    if ~isempty(figures), delete(figures) ; end
    bdclose('all') ; Simulink.data.dictionary.closeAll('-discard') ;
    evalin('base','clear nirpResults') ;
end

function removePath(folder)
    if contains([path pathsep],[folder pathsep]), rmpath(folder) ; end
end
