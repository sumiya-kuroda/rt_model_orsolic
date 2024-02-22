function StTrialVector = RegenerateTFDummy(mean_tf)
    framerate = 60;
    repeat_value = 3;
    LengthBaseline = 15.5*framerate/repeat_value;
    LengthChange = 2.15*framerate/repeat_value;

    pdSimBase = makedist('normal','mu',log2(1),'sigma',.25);
    pdSimChange = makedist('normal','mu',log2(mean_tf),'sigma',.25);

    StTrialVector = cat(1, random(pdSimBase,LengthBaseline,1), random(pdSimChange,LengthChange,1));
    StTrialVectorNoChange = random(pdSimBase,LengthBaseline,1);
end