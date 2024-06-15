import re


def method_labels(wildcards, input):
    """convert result path into label"""
    labels = []
    for path in input:
        match_nonlinear = re.search('__constant__matern52__(.*)/', path)
        if match_nonlinear:
            label = match_nonlinear.group(1)
        elif re.search('constant__linear_matern52__stim_time/', path):
            label = 'linear-stim_time'
        elif re.search('linear__constant__full/', path):
            label = 'linear-full'
        else:
            label = 'non-recognized-method'
        labels.append(label)
    return ' '.join(labels)


MICE = [
    # 'data_AllHumans_GPmodel', 
    # 'data_AllMiceTraining_GPmodel'
    'data_AllMiceTraining_GPmodel_GLMHMMx0',
    'data_AllMiceTraining_GPmodel_GLMHMMx1',
    'data_AllMiceTraining_GPmodel_GLMHMMx2'
    # 'data_MiceTraining_M_AK004_GPmodel',
    # 'data_MiceTraining_M_AK005_GPmodel',
    # 'data_MiceTraining_M_AK008_GPmodel',
    # 'data_MiceTraining_M_ML007_GPmodel',
    # 'data_MiceTraining_M_ML008_GPmodel',
    # 'data_MiceTraining_M_ML009_GPmodel'
    ]
EXPERIMENTS = [
    'full', 'stim_time', 'stim_wtime', 'proj_wtime__ard' #,'time', 'wtime', 
    ]
FOLDS = ['test', 'train_val']
GPU_NUM = 3

EXPERIMENTS_ARD = [kern for kern in EXPERIMENTS if kern.endswith('__ard')]

rule all:
    input:
        expand('results/{mouse}__constant__matern52__{kernels_input}/ppc_{folds}',
               mouse=MICE, kernels_input=EXPERIMENTS, folds=FOLDS),
        expand('results/{mouse}__constant__linear_matern52__stim_time/ppc_{folds}',
               mouse=MICE, folds=FOLDS),
        expand('results/{mouse}__linear__constant__full/ppc_{folds}',
               mouse=MICE, folds=FOLDS),
        expand('results/{mouse}__constant__matern52__{kernels_input}/posteriors',
               mouse=MICE, kernels_input=EXPERIMENTS_ARD),
        expand('results/{mouse}__constant__matern52__proj_wtime__ard/filter_dropped',
               mouse=MICE),
        expand('results/{mouse}__scores', mouse=MICE)
        # 'results/all_mice__scores'


rule fit_ml:
    "fit a Gaussian process model using maximum marginal likelihood"
    input:
        'data/{mouse}.mat'
    params:
        kernels_type=lambda wildcards: wildcards.kernels_type.replace('_', ' ').title(),
        kernels_input=lambda wildcards: wildcards.kernels_input.split('_'),
        nz=lambda wildcards: 1 if wildcards.kernels_type == 'constant' else 150
    output:
        directory('results/{mouse}__{mean_type}__{kernels_type}__{kernels_input}/model')
    threads: 10
    resources:
        gpu=GPU_NUM
    shell:
        """
        OPENBLAS_NUM_THREADS={threads} src/gp_fit.py \
                      --hierarchy hzrd --hazard all \
                      --mean-type {wildcards.mean_type} \
                      --combination add \
                      --kernels-type {params.kernels_type} \
                      --kernels-input {params.kernels_input} \
                      --nproj 15 \
                      --nz {params.nz} \
                      --batch-size 1200 \
                      --patience 10000 \
                      --max-duration 1000 \
                      {output} {input}
        """


rule fit_ard:
    "fit a Gaussian process model with ARD prior using ADVI"
    input:
        'data/{mouse}.mat'
    params:
        kernels_type=lambda wildcards: wildcards.kernels_type.replace('_', ' ').title(),
        kernels_input=lambda wildcards: wildcards.kernels_input.split('_'),
        nz=lambda wildcards: 1 if wildcards.kernels_type == 'constant' else 150
    output:
        directory('results/{mouse}__{mean_type}__{kernels_type}__{kernels_input}__ard/model_ard')
    threads: 10
    resources:
        gpu=GPU_NUM
    shell:
        """
        OPENBLAS_NUM_THREADS={threads} src/gp_fit.py \
                      --hierarchy hzrd --hazard all \
                      --mean-type {wildcards.mean_type} \
                      --combination add \
                      --kernels-type {params.kernels_type} \
                      --kernels-input {params.kernels_input} \
                      --nproj 15 \
                      --nz {params.nz} \
                      --batch-size 1200 \
                      --patience 10000 \
                      --max-duration 1000 \
                      --use-ard \
                      {output} {input}
        """


rule posterior:
    "plot posterior distributions from a Gaussian process fit"
    input:
        'results/{folder}/model_ard'
    output:
        directory('results/{folder}/posteriors')
    shell:
        'src/show_posterior.py {input} {output}'


rule convert_ard:
    "convert model with ARD prior to simple model"
    input:
        'results/{folder}/model_ard'
    output:
        directory('results/{folder}/model')
    shell:
        'src/gp_convert.py {input} {output}'


rule predict:
    "predict hazard and lick probability from a Gaussian process fit"
    input:
        'results/{folder}/model'
    output:
        'results/{folder}/predictions.pickle'
    resources:
        gpu=GPU_NUM
    shell:
        'src/gp_predict.py -n 500 {input} {output}'


rule ppc:
    "generate posterior predictive checks from a Gaussian process fit"
    input:
        'results/{folder}/predictions.pickle'
    output:
        directory('results/{folder}/ppc_{folds}')
    params:
        folds=lambda wildcards: wildcards.folds.split('_')
    shell:
        'src/gp_ppc.py {input} {output} --folds {params.folds}'


rule score:
    "generate predictive scores from a Gaussian process fit for a mouse"
    input:
        expand('results/{{mouse}}__constant__matern52__{kernels_input}/predictions.pickle',
               kernels_input=EXPERIMENTS),
        'results/{mouse}__constant__linear_matern52__stim_time/predictions.pickle',
        'results/{mouse}__linear__constant__full/predictions.pickle'
    params:
        labels=' '.join(EXPERIMENTS + ['linear-stim_time', 'linear-full'])
    output:
        directory('results/{mouse}__scores')
    shell:
        'src/gp_score.py {output} {input} --labels {params.labels}'


rule predict_drop:
    "predict hazard and lick probability from a Gaussian process fit with excluding filters"
    input: 
        'results/{mouse}__constant__matern52__proj_wtime__ard/model'
    output:
        directory('results/{mouse}__constant__matern52__proj_wtime__ard/filter_dropped')
    params:
        dropping_filters = [0, 1]
    resources:
        gpu=GPU_NUM
    run:
        shell('mkdir {output}')
        for f in params.dropping_filters:
            shell('src/gp_predict.py -n 500 -z {f} {input} {output}/predictions_drop_filter_{f}.pickle')