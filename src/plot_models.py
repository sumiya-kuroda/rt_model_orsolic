#!/usr/bin/env python3

from pathlib import Path

import defopt
import numpy as np
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import seaborn as sb
from scipy.special import expit
import gp_predict
from gp_model import build_model, _prepare_X, predict_logpmf


def extract_filters(params):
    """extract and sort filters from a projected model"""

    filters = next(
        value for param, value in params.items() if param.endswith('W')
    )

    # sort by filter standard deviation
    filters_idx = np.argsort(-filters.std(axis=0))
    filters_sorted = filters[:, filters_idx]

    # flip to make bigger deviation positive
    mask_idx = np.arange(filters_sorted.shape[1])
    flip_mask = filters_sorted[7, mask_idx] < 0
    filters_sorted[:, flip_mask] = -filters_sorted[:, flip_mask]

    return filters_sorted, filters_idx, flip_mask


def extract_warping(params):
    """extract warping coefficients from a warped time model"""
    key_coeffs_a = next(key for key in params if key.endswith('coeffs_a'))
    coeffs_a = params[key_coeffs_a]
    coeffs_b = params[key_coeffs_a.replace('coeffs_a', 'coeffs_b')]
    coeffs_c = params[key_coeffs_a.replace('coeffs_a', 'coeffs_c')]
    return np.array([coeffs_a, coeffs_b, coeffs_c])


def map_proj_gp(model, sample, filters, dims, grid_size, flip_mask):
    """map the mean function of the projected kernel of the model"""

    proj_stim = sample.projected_stim

    xs_coords = np.linspace(
        -2., 6.,
        grid_size
    )
    ys_coords = np.linspace(
        -4., 4.,
        grid_size
    )

    [xs, ys] = np.meshgrid(xs_coords, ys_coords)
    if flip_mask[0]:
        xs = -xs
    if flip_mask[1]:
        ys = -ys

    xs_ys = np.stack([xs, ys], -1).reshape(-1, 2)
    y_target = np.zeros((len(xs_ys), filters.shape[1]))
    y_target[:, dims] = xs_ys

    X_synth = np.empty((len(xs_ys), filters.shape[0] + 3))
    X_synth[:, :-3] = np.linalg.lstsq(filters.T, y_target.T)[0].T
    X_synth[:, -3] = 0  # set time to 0
    X_synth[:, -2:] = [sample.hazard_code, sample.mouse_code]

    #proj_mean, _ = model.predict_f_partial(X_synth)
    _, proj_mean = model.predict_f(X_synth)
    proj_mean = proj_mean.reshape(grid_size, grid_size)

    return proj_mean, xs_coords, ys_coords


def plot_model_parts(sample, model, model_params, model_opts, axes):
    """plot components of a projected/warped-time GP model, for one trial"""

    period = 0.05
    np.random.seed(12345)
    sample.ys = np.random.randn(14*20)*.25
    sample.ys[-40:] = sample.ys[-40:] + 1
    sample.hazard_code = 1 # late block
    nt = len(sample.ys)

    xs = np.arange(nt) * period

    colors = {'stim': '#1f77b4', 'time': '#d62728', 'all': '#9467bd'}

    # stimulus components plots
    filters, filters_idx, flip_mask = extract_filters(model_params)
    axes[0].plot(filters[:,0:3])
    axes[0].set_ylim(-.5, .75)
    axes[0].set_yticks([-.5, 0, .75])
    n_lags = filters.shape[0]
    X = np.zeros((nt, n_lags))
    for i in range(min(n_lags, nt)):
        X[i:, i] = sample.ys[:nt-i]
    sample.projected_stim = X.dot(filters)

    Xfull = _prepare_X(sample, n_lags, nt)
    sample.logit_hazard = model.predict_f(Xfull)[0]
    logit_hazard = model.predict_f_partial(Xfull)
    for hazard, k_input in zip(logit_hazard, model_opts['kernels_input']):
        sample['logit_hazard_{}'.format(k_input)] = hazard
    sample['log_pmf'] = expit(sample.logit_hazard)

    for i, blue in enumerate(['#1f77b4', '#6baed6']):
        filter_label = 'Filter {}'.format(i)
        axes[1].plot(
            xs, sample.projected_stim[:, i], color=blue,
            label=filter_label
        )
    axes[1].set_ylabel('arb. unit')

    # mean function of projected kernel
    proj_mean, xs_coords, ys_coords = map_proj_gp(
        model, sample, filters, filters_idx[:2], 200, flip_mask
    )
    extent = [xs_coords[0], xs_coords[-1], ys_coords[0], ys_coords[-1]]
    img_ax = axes[2].imshow(
        proj_mean, extent=extent, origin='lower', aspect='auto'
    )
    axes[2].figure.colorbar(img_ax, ax=axes[2])

    axes[2].plot(
        sample.projected_stim[:, 0],
        sample.projected_stim[:, 1],
        '-o', ms=2, color=colors['stim']
    )
    axes[2].set_xlabel('Filter 1')
    axes[2].set_ylabel('Filter 2')

    # estimated lick PMF
    axes[3].plot(xs, sample.log_pmf, color=colors['all'])
    axes[3].set_xlabel('Time from onset (s)')
    axes[3].set_ylabel('Probability')
    axes[3].yaxis.set_major_locator(ticker.MultipleLocator(0.05))
    axes[3].set_ylim(0., .25)
    # axes[1, 2].legend()


def main(result_dir, fig_dir):
    """Generate plots showing internal computation of a proj-ard/wtime model

    :param str result_dir: directory containing results of a model
    :param str fig_dir: output directory
    """

    models = [
        'IO_075__constant__matern52__proj_wtime__ard',
        'IO_078__constant__matern52__proj_wtime__ard',
        'IO_079__constant__matern52__proj_wtime__ard',
        'IO_080__constant__matern52__proj_wtime__ard',
        'IO_081__constant__matern52__proj_wtime__ard',
        'IO_083__constant__matern52__proj_wtime__ard'
    ] #


    # set seaborn style, fix sans-serif font to avoid missing minus sign in pdf
    rc_params = {
        'font.sans-serif': ['Arial'],
        'axes.titleweight': 'bold'
    }
    sb.set(context='paper', style='ticks', rc=rc_params, font_scale=1.2)
    plt.rcParams['pdf.fonttype'] = 'truetype'
    fig, axes = plt.subplots(
        len(models), 4, figsize=(9., 13.),
    )

    with PdfPages(fig_dir + '/summary.pdf') as pdf_file:
        for i, model_name in enumerate(models):
            # fix seed for reproducibility
            seed = 12345
            np.random.seed(seed)

            # load model and predictions
            result_path = Path(result_dir)
            model_path = result_path / model_name / 'model'
            #gp_predict.main(model_path, result_path / 'predictions.pickle', nsamples=200)

            dset = pd.read_pickle(model_path / 'dataset.pickle')
            model_opts = np.load(model_path / 'model_options.npz')
            model_params = dict(np.load(model_path / 'model_params_best.npz'))
            model = build_model(dset[dset.train], fast_init=True, **model_opts)
            model.assign(model_params)

            predictions = pd.read_pickle(result_path / model_name / 'predictions.pickle')

            sample = predictions.loc[1]
            plot_model_parts(sample, model, model_params, model_opts, axes[i, :])
        sb.despine(fig, offset=3, trim=False)
        fig.tight_layout(pad=0.5)
        pdf_file.savefig(fig)
        plt.close(fig)



if __name__ == "__main__":
    defopt.run(main)
