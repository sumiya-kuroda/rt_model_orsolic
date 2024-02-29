function []=FormatForGPmodel_KurodaDavies(ResultFolder, matfile, species, concat)
% FormatForGPmodel_KurodaDavies  Convert raw behavior dataset into GP-model
%                                compatible format
%
% This function MATLAB function supports >R2023a

%% Path and parameters
arguments
    ResultFolder (1,1) string
    matfile (1,1) string
    species {mustBeMember(species,["humans","mice"])} 
    concat (1,1) logical
end

if ~contains(matfile,'_fsm.mat')
    error(['Error. ', matfile, 'needs to be in final fsm format.']) 
end

disp("Loading fsm behavior dataset...");
fsm = load(matfile);
animals = unique({fsm.fsm.participant});
disp(['Found ', int2str(numel(animals)), ' animals']);

if concat
    sessions = unique({fsm.fsm.session});
    disp(['Reading and formatting data for GP model for all animals; Number of sessions: ', int2str(length(sessions))]);
    for s = 1:length(sessions)
        subData = fsm.fsm(strcmp({fsm.fsm.session}, sessions{s}));
        struct = fsm2GPmodel(subData, sessions{s}, species);
        outcomeAll{s} = struct.outcome;
        sigAll{s} = struct.sig;
        sessionAll{s} = struct.session;
        hazardAll{s} = struct.hazard;
        rtAll{s} = struct.rt;
        changeAll{s} = struct.change;
        ysAll{s} = struct.ys;

        clear struct
    end

    rt = vertcat([rtAll{:}]);
    sig = vertcat([sigAll{:}]).';
    session = vertcat(sessionAll{:});
    hazard = vertcat([hazardAll{:}]).';
    outcome = vertcat([outcomeAll{:}]).';
    change = vertcat([changeAll{:}]).';
    ys = vertcat([ysAll{:}]);
    clearvars -except rt sig session hazard outcome ys change species ResultFolder animals
    
    if trcmp(species, 'humans')
        save(fullfile(ResultFolder,'dataAllHumans_GPmodel.mat')); % no '-v7.3'
    elseif strcmp(species, 'mice')
        save(fullfile(ResultFolder,'data_AllMiceTraining_GPmodel.mat')); % no '-v7.3'
    end
else
    % Run a for loops for all animals
    for a=1:length(animals)
        animal_name = animals{a};
        Data = fsm.fsm(strcmp({fsm.fsm.participant}, animals{a}));
        % List sessions
        sessions = unique({Data.session});
        disp(['Reading and formatting data for GP model for ', animal_name, '; Number of sessions: ', int2str(length(sessions))]);
        for s = 1:length(sessions)
            subData = Data(strcmp({Data.session}, sessions{s}));
            struct = fsm2GPmodel(subData, sessions{s}, species);
            outcomeAll{s} = struct.outcome;
            sigAll{s} = struct.sig;
            sessionAll{s} = struct.session;
            hazardAll{s} = struct.hazard;
            rtAll{s} = struct.rt;
            changeAll{s} = struct.change;
            ysAll{s} = struct.ys;

           clear struct
        end

        rt = vertcat([rtAll{:}]);
        sig = vertcat([sigAll{:}]).';
        session = vertcat(sessionAll{:});
        hazard = vertcat([hazardAll{:}]).';
        outcome = vertcat([outcomeAll{:}]).';
        change = vertcat([changeAll{:}]).';
        ys = vertcat([ysAll{:}]);
        clearvars -except rt sig session hazard outcome ys change ...
                  species ResultFolder animals animal_name fsm

        if strcmp(species, 'mice')
            save(fullfile(ResultFolder,['data_MiceTraining_', animal_name, '_GPmodel.mat']), ...
                "rt","sig","session","hazard","outcome","ys","change"); % no '-v7.3'
        end

    end
end

end