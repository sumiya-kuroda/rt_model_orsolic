function fsm_glmhmm = ReadGLMHMMOutput(fsm, fpath)
    fdata = fileread(fpath);
    AllStateData = jsondecode(fdata);
    States = fieldnames(AllStateData);
    disp("Loading GLMHMM results...");
    for Zk=1:numel(States)
        ZkStateData = split(AllStateData.(States{Zk}),'-');
        ZkParticipant = ZkStateData(:,1);
        ZkSession = ZkStateData(:,2);
        ZkTrial = ZkStateData(:,3);
        
        ZkSessions = unique(ZkSession);
        for Zks = 1:numel(ZkSessions)
            disp(ZkSessions{Zks});
            idx = strcmp(ZkSession, ZkSessions{Zks});
            ZkParticipant_i = {ZkParticipant{idx}};
            ZkTrial_i = {ZkTrial{idx}};

            % tmp = ismember({fsm.participant},ZkParticipant)
            % No need as the participant name is included in the sesion name
            % Also gives an error when participants are concat
            ZkSessLoc = ismember({fsm.session},ZkSessions{Zks});
            fsm_trials = arrayfun(@num2str, [fsm.trial], 'UniformOutput', 0);
            ZkTrialLoc = ismember(fsm_trials,ZkTrial_i);
        
            ZkLoc = and(ZkSessLoc, ZkTrialLoc).';
            fsm_Zk_tmp{Zks} = fsm(ZkLoc,:);
        end
        AllTrialData=cat(1,fsm_Zk_tmp{:});
        clearvars fsm_Zk_tmp
        fsm_glmhmm.(States{Zk})=[AllTrialData];
    end
    disp("fsm filtered based on GLMHMM results!");
end


