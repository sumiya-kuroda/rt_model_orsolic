#!/usr/bin/env python3
from pathlib import Path
import defopt
import numpy as np
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
import matplotlib.pyplot as plt
from gp_ppc import load_data
from gp_model import extract_filters
from plot_orsolic_paper import plot_psycho, plot_chrono
from strenum import strenum
import seaborn as sb

def get_lick_stims(row, filter_idx):
    """
    Get filter activations at the time of licks

    row - row of dataframe for a given trial
    filter_idx - filter activations to extract
    """
    if ~np.isnan(row.rt):
        return row.projected_stim[int(row.rt), filter_idx]
    else:
        return np.nan

def make_plots(model_dir, block, axes, axes_early, folds, n_samples):
    """Plot the effects of zeroing top filters"""
    pred_filename = model_dir + 'predictions.pickle'
    pred_filename_0 = model_dir + 'predictions_drop_filter_0.pickle'
    pred_filename_1 = model_dir + 'predictions_drop_filter_1.pickle'
    dset, dset_pred_full = load_data(pred_filename, n_samples, folds)
    _, dset_pred_0 = load_data(pred_filename_0, n_samples, folds)
    _, dset_pred_1 = load_data(pred_filename_1, n_samples, folds)
    if block == 'split':
        dset = dset[dset.hazard != 'nonsplit'].copy()
        dset_pred_full = dset_pred_full[dset_pred_full.hazard != 'nonsplit'].copy()
        dset_pred_0 = dset_pred_0[dset_pred_0.hazard != 'nonsplit'].copy()
        dset_pred_1 = dset_pred_1[dset_pred_1.hazard != 'nonsplit'].copy()
    else:
        dset = dset[dset.hazard == 'nonsplit'].copy()
        dset_pred_full = dset_pred_full[dset_pred_full.hazard == 'nonsplit'].copy()
        dset_pred_0 = dset_pred_0[dset_pred_0.hazard == 'nonsplit'].copy()
        dset_pred_1 = dset_pred_1[dset_pred_1.hazard == 'nonsplit'].copy()

    dsets = [ dset_pred_full, dset_pred_0, dset_pred_1 ]
    (f0_color, f1_color) = (sb.xkcd_rgb['mauve'], sb.xkcd_rgb['green'])
    colors = [ 'k', f0_color, f1_color ]
    labels = [ 'Full', '-Filter 1', '-Filter 2']

    # psychometric functions
    hitlicks_test = (
        dset[~dset['early']]
        .groupby('sig').agg({'hit': 'mean'})
    )
    axes[0].plot(hitlicks_test, '--.r')
    # chronometric functions
    period = 0.05
    hitrt_test = period * (
        dset[dset['hit'] & (dset['sig'] > 0)]
        .groupby('sig').agg({'rt_change': 'mean'})
    )
    period = 0.05
    axes[1].plot(hitrt_test, '--.r')

    for (d, c, l) in zip(dsets, colors, labels):
        plot_psycho(d, axes[0], l, color=c)
        plot_chrono(d, period, axes[1], color=c)

    axes[0].set_ylim(0, 1)
    axes[0].set_xlim(0, 2)
    axes[1].set_xlim(0, 2)

    # plot filter activations at the time of licks
    model_params = dict(np.load(model_dir + 'model/model_params_best.npz'))
    filters, filters_idx, flip_mask = extract_filters(model_params)
    predictions = pd.read_pickle(pred_filename)
    predictions['sig'] /= np.log(2)

    if block == 'split':
        predictions = predictions[predictions.hazard != 'nonsplit'].copy()
    else:
        predictions = predictions[predictions.hazard != 'split'].copy()
    for (f, c) in zip([0, 1], [f0_color, f1_color]):
        col_name = 'lick_stim_{}'.format(f)
        predictions[col_name] = predictions.apply(get_lick_stims,
            args=(filters_idx[f],), axis=1)
        # make sure sign of filter activations is consistent
        if flip_mask[f]:
            predictions[col_name] = -predictions[col_name]
        hitlicks_pred = (
            predictions[predictions['outcome']=='Hit']
            .groupby(['sig']).agg({col_name: 'mean'})
        )
        fa_licks = predictions[predictions['outcome']=='FA'][col_name].mean()
        axes[2].plot(hitlicks_pred, color=c)
        axes[2].plot(-.25, fa_licks, '.', color=c)
    axes[2].axhline(0, linestyle=':')

    # plot proportion of early licks
    early_licks_full = dset_pred_full.groupby('sample_id').agg({'early': np.mean})
    early_licks_full['dset'] = 'Full'
    early_licks_0 = dset_pred_0.groupby('sample_id').agg({'early': np.mean})
    early_licks_0['dset'] = 'Without filter 1'
    early_licks_1 = dset_pred_1.groupby('sample_id').agg({'early': np.mean})
    early_licks_1['dset'] = 'Without filter 2'

    my_pal = {"Full": "k",
              "Without filter 1": sb.xkcd_rgb['mauve'],
              "Without filter 2": sb.xkcd_rgb['green']}

    axes_early.plot(-1, dset['early'].mean(), '.r')
    vp = sb.violinplot(x = 'dset', y = 'early',
        data=pd.concat((early_licks_full, early_licks_0, early_licks_1)),
        inner=None, ax=axes_early, palette=my_pal)
    vp.set(xlabel=None, ylabel=None)
    axes_early.set_xlim(-1.5, 2.5)
    axes_early.set_xticks(np.arange(-1, 3))
    axes_early.set_xticklabels([])

Fold = strenum('Fold', 'train val test')

def main(figure_dir, *, folds=('test','val','train'), n_samples=200):
    """Evaluate the contribution of the top two stimulus filters to model performance

    :param str figure_dir: directory for generated figures
    :param list[Fold] folds: data folds to use
    :param int n_samples: number of samples

    """
    # set seaborn style, fix sans-serif font to avoid missing minus sign in pdf
    rc_params = {
        'font.sans-serif': ['Arial'],
        'font.size': 8,
        'lines.linewidth': 0.5,
        'axes.linewidth': 0.5,
        'xtick.major.width': 0.5,
        'ytick.major.width': 0.5,
        'axes.titlesize': 8,
        'axes.labelsize': 8,
        'xtick.major.size': 1,
        'ytick.major.size': 1
    }
    sb.set(style='ticks')
    sb.set_context('paper', rc=rc_params)
    plt.rcParams['pdf.fonttype'] = 'truetype'

    mice = ['IO_075', 'IO_078', 'IO_079', 'IO_080', 'IO_081', 'IO_083']

    figure_path = Path(figure_dir)
    figure_path.mkdir(parents=True, exist_ok=True)

    with PdfPages(str(figure_path / 'drop_filters.pdf')) as pdf_1, \
        PdfPages(str(figure_path / 'early_licks.pdf')) as pdf_2 :
        fig_plots, axes_plots = plt.subplots(
            len(mice), 6, figsize=(20/2.54, 3/2.54 * len(mice))
        )
        fig_early, axes_early = plt.subplots(
            2, 6, figsize=(20/2.54, 6/2.54)
        )
        for ii, mouse in enumerate(mice):
            model_dir = 'manuscript/results/' + mouse + \
                '__constant__matern52__proj_wtime__ard/'
            # running version, no hazard rate blocks
            make_plots(model_dir, 'nonsplit',
                axes_plots[ii,0:3], axes_early[0,ii], folds, n_samples)
            # stationary version with hazard rate blocks
            make_plots(model_dir, 'split',
                axes_plots[ii,3:], axes_early[1,ii], folds, n_samples)

        sb.despine(fig_plots, offset=3, trim=False)
        fig_plots.tight_layout()
        pdf_1.savefig(fig_plots)
        plt.close(fig_plots)

        sb.despine(fig_early, offset=3, trim=False)
        fig_early.tight_layout()
        pdf_2.savefig(fig_early)
        plt.close(fig_early)


if __name__ == "__main__":
    defopt.run(main)
