function struct = fsm2GPmodel(data, session_name, species)
outcome = {data.trialoutcome};
for k = 1 : numel(outcome)
    if strcmp(outcome{k}, 'Abort')
        outcome{k} = 'abort';
    end
end

sig = log([data.Stim2TF]);

session = cellstr(repmat(session_name,numel(outcome),1));

hazard = {data.hazard};
for k = 1 : numel(hazard)
    if strcmp(hazard{k}, 'lateprobes')
        hazard{k} = 'late';
    elseif strcmp(hazard{k}, 'earlyprobes')
        hazard{k} = 'early';
    end
end

RT = [data.RTbaseline];
rt = ceil(RT*(60/3));
for k = 1 : numel(rt)
    if strcmp(outcome{k}, 'Miss')
        rt(k) = NaN;
    end
end
change = ceil([data.stimT].*(60/3));

if strcmp(species, 'humans')
    y_mat = [data.MergedTrialVector];
    y_mat_log = log2(y_mat(1:3:end,:));
    y_mat_log(~isfinite(y_mat_log)) = NaN; % convert inf to nan for now
    y = num2cell(y_mat_log,1);
    ys = cellfun(@(y) y(~isnan(y)),y,'UniformOutput',false);
elseif strcmp(species, 'mice')
    for k = 1 : numel(change)
        clearvars y_k_log ExpectedTrialDuration ChangeSize_k StTrialVector ...
                  MissingTF
        y_k = [data(k).MergedTrialVector];
        y_k_log = log2(y_k(1:3:end));

        ExpectedTrialDuration = ceil((data(k).stimT + 2.15).*(60/3));
        ChangeSize_k = data(k).Stim2TF;
        StTrialVector = RegenerateTFDummy(ChangeSize_k);

        if ExpectedTrialDuration-length(y_k_log) >= 1
            MissingTF = StTrialVector(end-(ExpectedTrialDuration-length(y_k_log))+1:end);
            ys{k} = cat(1, y_k_log.', MissingTF);
        else
            ys{k} = y_k_log.';
        end
    end
end
struct.outcome = outcome;
struct.sig = sig;
struct.session = session;
struct.hazard = hazard;
struct.rt = rt;
struct.change = change;
struct.ys = ys;

end