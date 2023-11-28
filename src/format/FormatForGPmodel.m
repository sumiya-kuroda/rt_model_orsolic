function outs=FormatForGPmodel(ResultFolder, matfile)
    load(matfile);
    mice = whos("-regexp", "x");
    for mouse=1:length(mice)
        outs{mouse}=FormatForGPmodelv6_eachmouse(ResultFolder, eval(mice(mouse).name), mice(mouse).name, false);
    end
    T = ConcatenateStructFields([outs{:}]);
    rt = T.rt;
    sig = T.sig.';
    session = T.session;
    hazard = T.hazard;
    outcome = T.outcome;
    ys = T.ys;
    change = T.change;
    clearvars -except rt sig session hazard outcome ys change species ResultFolder
    save(fullfile(ResultFolder,'data_AllMouse.mat')); % no , '-v7.3'
end

function out=FormatForGPmodelv6_eachmouse(ResultFolder, subData, mousename, savefile)

sessions = fieldnames(subData);
disp(["Reading and formatting mouse data for GP model for ", mousename, "; Number of sessions: ", length(sessions)]);

for s = 1:length(sessions)
    clear fsm NI Video MotionOnsets Baseline_ON_times Change_ON_times RTs
    fsm=subData.(sessions{s}).behav_data.trials_data_exp;
    NI=subData.(sessions{s}).NI_events;
    Video= subData.(sessions{s}).Video; 

    Baseline_ON_times = NI.Baseline_ON.rise_t;
    Change_ON_times = NI.Change_ON.rise_t;

    MotionOnsets=Video.MotionOnsetTimes;
    RTs_FromBase=MotionOnsets-Baseline_ON_times;
    RTs_FromChange=MotionOnsets-Change_ON_times;

    
    outcomeAll{s} = {fsm.trialoutcome};
    sigAll{s} = log([fsm.Stim2TF]);
    for ss=1:length(fsm)
    sessionAll{s}{ss} = append(num2str(1*s),'_',mousename);
    end
    hazardAll{s} = {fsm.hazardblock};
    % for k = 1 : numel(hazard)
    %     if strcmp(hazard{k}, 'lateprobes')
    %         hazard{k} = 'late';
    %     elseif strcmp(hazard{k}, 'earlyprobes')
    %         hazard{k} = 'early';
    %     end
    % end

    for t=1:length(fsm)
        if ~isnan(fsm(t).reactiontimes.FA)
            RTAll{s}(t)=RTs_FromBase(t);
        elseif ~isnan(fsm(t).reactiontimes.RT)
            RTAll{s}(t)=RTs_FromBase(t);
        elseif ~isnan(fsm(t).reactiontimes.Ref)
            RTAll{s}(t)=RTs_FromBase(t);
        elseif ~isnan(fsm(t).reactiontimes.Miss)
            RTAll{s}(t)=fsm(t).reactiontimes.Miss;
        elseif ~isnan(fsm(t).reactiontimes.gray)
            RTAll{s}(t)=fsm(t).reactiontimes.gray;
        elseif ~isnan(fsm(t).reactiontimes.abort)
            RTAll{s}(t)=RTs_FromBase(t);
        end
    end


    rtAll{s} = ceil(RTAll{s}*(60/3));
    for k = 1 : numel( rtAll{s})
        if strcmp(outcomeAll{s}{k}, 'Miss')
            rtAll{s}(k) = NaN;
        end
    end
    changeAll{s} = ceil([fsm.stimT].*(60/3));

    for k = 1 : numel(rtAll{s})
        clear StimHappenedTF ExpectedTotalTF ChangeSize_k StTrialVector MissingTF
        TFFull{k}=fsm(k).TF(fsm(k).TF>0);
        StimHappenedTF = TFFull{k}(1:3:end);

        ExpectedTotalTF = ceil((fsm(k).stimT + 2.15)*60/3);
        ChangeSize_k = fsm(k).Stim2TF;
        [StTrialVector,~] = recreate_pseudo_tf(ChangeSize_k);
        if ExpectedTotalTF-length(StimHappenedTF) >= 1
            MissingTF = StTrialVector(end-(ExpectedTotalTF-length(StimHappenedTF))+1:end);
            ysAll{s}{k} = log2(cat(1, StimHappenedTF, MissingTF)).';
        else
            ysAll{s}{k} = log2(StimHappenedTF);
        end

        % if ~fsm(k).IsFA
        %     ExpectedTotalTF = ceil((fsm(k).stimT + 2.15)*60/3);
        %     ChangeSize_k = fsm(k).Stim2TF;
        %     [StTrialVector,~] = recreate_pseudo_tf(ChangeSize_k);
        %     if ExpectedTotalTF-length(StimHappenedTF) >= 1
        %         MissingTF = StTrialVector(end-(ExpectedTotalTF-length(StimHappenedTF))+1:end);
        %         ysAll{s}{k} = log(cat(1, StimHappenedTF, MissingTF)).';
        %     else
        %         ysAll{s}{k} = log(StimHappenedTF);
        %     end
        % else
        %     ExpectedTotalTF = ceil((fsm(k).stimT)*60/3);
        %     [~,StTrialVector] = recreate_pseudo_tf(1);
        %     if ExpectedTotalTF-length(StimHappenedTF) >= 1
        %         MissingTF = StTrialVector(end-(ExpectedTotalTF-length(StimHappenedTF))+1:end);
        %         ysAll{s}{k} = log(cat(1, StimHappenedTF, MissingTF)).';
        %     else
        %         ysAll{s}{k} = log(StimHappenedTF);
        %     end
        % end
    end
    clear TFFull
end

outcomeFull=[outcomeAll{:}]';
sigFull=[sigAll{:}]';
sessionFull=[sessionAll{:}]';
hazardFull=[hazardAll{:}];
rtFull=[rtAll{:}];
RTFull=[RTAll{:}];
changeFull=[changeAll{:}]';
ysFull=[ysAll{:}];

%% remove trials with no available motiononset estimation
outcome={outcomeFull{~isnan(RTFull)}};
sig=sigFull(~isnan(RTFull))';
session={sessionFull{~isnan(RTFull)}}';
hazard={hazardFull{~isnan(RTFull)}};
rt=rtFull(~isnan(RTFull));
change=changeFull(~isnan(RTFull));
ys={ysFull{~isnan(RTFull)}};

clear outcomeFull sigFull sessionFull hazardFull rtFull changeFull ysFull RTFull


clearvars -except rt sig session hazard outcome ys change species ResultFolder mousename savefile
if savefile
    save(fullfile(ResultFolder,[mousename  '.mat'])); % no , '-v7.3'
end
out.rt = rt;
out.sig = sig;
out.session = session;
out.hazard = hazard';
out.outcome = outcome';
out.ys = ys;
out.change = change;
end

function T = ConcatenateStructFields(S)
    fields = fieldnames(S);
    numfields = width(S);
    for k = 1:numel(fields)
      aField     = fields{k};
      if strcmp(aField, 'session') || strcmp(aField, 'hazard') || strcmp(aField, 'outcome')
          tmp = S(1).(aField);
          for n = 2:numfields
              tmp  = vertcat(tmp, S(n).(aField));
          end
          T.(aField) = tmp;
      elseif strcmp(aField, 'ys')
          tmp = S(1).(aField);
          for n = 2:numfields
              tmp  = horzcat(tmp, S(n).(aField));
          end
          T.(aField) = tmp;
      elseif strcmp(aField, 'change')
          T.(aField) = vertcat(S.(aField));
      else 
          T.(aField) = [S.(aField)];
      end
    end
end

function [StTrialVector,StTrialVectorNoChange] = recreate_pseudo_tf(mean_tf)

    framerate = 60;
    repeat_value = 3;
    LengthBaseline = 15.5*framerate/repeat_value;
    LengthChange = 2.15*framerate/repeat_value;

    pdSimBase = makedist('normal','mu',log2(1),'sigma',.25);
    pdSimChange = makedist('normal','mu',log2(mean_tf),'sigma',.25);

    StTrialVector = cat(1, (2.^random(pdSimBase,LengthBaseline,1)), (2.^random(pdSimChange,LengthChange,1)));
    StTrialVectorNoChange = 2.^random(pdSimBase,LengthBaseline,1);
end