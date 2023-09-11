# Reaction-time modeling with Gaussian process models

This repository contains code to analysis reaction-time from experimental data
collected by Ivana Orsolic. Updated by Sumiya Kuroda (@sumiya-kuroda).

This code accompanies the paper *Mesoscale cortical dynamics reflect the interaction of sensory evidence and temporal expectation during perceptual decision-making*,
Ivana Orsolic, Maxime Rio, Thomas D. Mrsic-Flogel, Petr Znamenskiy (https://doi.org/10.1101/552026).



## Installation

To retrieve the code, just clone the repository:
```sh
git clone https://github.com/BaselLaserMouse/rt_model_orsolic
```

To run the analysis code, you will need `python 3.5`, `pipenv`, and `cuda` (to use tensorflow with gpu computations), running on an appropriate generation of NVIDIA GPU(s). e.g., NVIDIA GTX 1060 6GB. We recommend you to run everything on Docker as it will save a lot of your time dealing with CUDA compatibility, etc. Download and install Docker, and run the command below to run the container and mount the working directory. `tensorflow/tensorflow:1.9.0-gpu-py3` already has CUDA 9.0 and libcudnn 7, which is needed to run tensorflow-1.9.0. You can check with `nvidia-smi` and `nvcc --version`.

```sh
docker run -it --gpus all -v ${PWD}:/mnt/dmdm --shm-size=1g -m "16g" --rm tensorflow/tensorflow:1.9.0-gpu-py3 bash
```

The remaining dependencies can be installed from the command line in a virtual
environment, using `pipenv`:
```sh
cd /mnt/dmdm/
pip install -U pip
pip install pipenv
export LC_ALL=C.UTF-8 # needed for pipenv
export LANG=C.UTF-8 # needed for pipenv
pipenv install  # create a virtual environment and populate it
```

Remark: A virtual environment is a good practice to isolate the code and its
dependencies from your system.


## Getting started

You can either:

- run `snakemake` in the top folder to compute all analyses (fitting, scores,
  figures, ...). If you want to specify GPU(s) to use, 

```sh
CUDA_VISIBLE_DEVICES="1" pipenv run snakemake
```

- run any of the python scripts in `src` folder to test different parameters.

Scripts have a `-h/--help` flag to provide more information about the available
options, expected input files and output files.

To reproduce the figures from the paper, you will also need the corresponding
data available on [figshare](https://figshare.com/s/45f53f720d75498ac3c4).
Unzip the `data` and `results` folders directly into the repository folder.


## Code organisation

Provided scripts in `src` folder are:

- `plot_orsolic_paper.py` generates the figures for the paper,
- `gp_fit.py` fits the parameters of a Gaussian process model on behavioral
  data,
- `gp_predict.py` estimates predictive distributions from fitted models,
- `gp_score.py` computes scores for different models and output figures for
  comparison purpose,
- `gp_ppc.py` samples from the models to check if they realistically capture
  the behavior,
- `gp_convert.py` transforms models with variational posteriors for the kernel
  hyperparameters into models with point estimates, 
- `show_posterior.py` displays the variational posterior distributions of the
  kernel hyperparameters,
- `gp_advi_example.py` is a dummy example of a GP model with ADVI inference
  applied on the kernel hyperparameters.

The remaining `.py` files are modules containing common code.


## Troubleshooting
If you want to quickly check whether tensorflow recognizes your GPU:
```py
from tensorflow.python.client import device_lib
print(device_lib.list_local_devices()) # for 1
```

Installing cuda reliably can tricky, here is a summary of command lines to
achieve it on an Ubuntu 16.04:
```sh
sudo dpkg -i cuda-repo-ubuntu1604-9-0-local_9.0.176-1_amd64-deb
sudo apt-key add /var/cuda-repo-9-0-local/7fa2af80.pub
sudo apt update
sudo apt install cuda
sudo dpkg -i libcudnn7*9.0*
```

It assumes that you downloaded cuda and cudnn packages from Nvidia website.

Another common issue is the number of threads used by `gp_fit.py` script. This
can be due to the `openblas` library linked with your `numpy` package. You can
limit this using the `OPENBLAS_NUM_THREADS` environment variable as follows:
```sh
OPENBLAS_NUM_THREADS=4 src/gp_fit.py <ouput folder> <input datasets> ...
```

## Troubleshooting (advanced)

If you have a recent GPU requiring cuda 10.0, you will have to recompile
tensorflow, as it's compiled for cuda 9.0 (2018/11/20).

First, install cuda 10.0 and libcudnn7 from Nvidia. The following steps are
described on [tensorflow website](https://www.tensorflow.org/install/source)
and [bazel website](https://docs.bazel.build/versions/master/install-ubuntu.html).
The bug in bazel 0.19 is described in [an issue](https://github.com/tensorflow/tensorflow/issues/23401).

In a terminal, install bazel:
```sh
sudo apt-get install openjdk-8-jdk  # install JDK 8
echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
curl https://bazel.build/bazel-release.pub.gpg | sudo apt-key add -
sudo apt-get update && sudo apt-get install bazel
```

Then clone tensorflow:
```sh
git clone https://github.com/tensorflow/tensorflow.git
cd tensorflow
git checkout r1.9
```

Populate a virtual environment with dependencies:
```sh
python3 -m venv .venv
. .venv/bin/activate
pip install -U pip six numpy wheel mock
pip install -U keras_applications==1.0.5 --no-deps
pip install -U keras_preprocessing==1.0.3 --no-deps
```

Test, configure and build tensorflow:
```sh
bazel test -c opt -- //tensorflow/... -//tensorflow/compiler/... -//tensorflow/contrib/lite/...
./configure
cat tools/bazel.rc .tf_configure.bazelrc > tf_configure.bazelrc; mv tf_configure.bazelrc .tf_configure.bazelrc  # needed for bazel 0.19
bazel build --config=opt --config=cuda //tensorflow/tools/pip_package:build_pip_package
./bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
```

The final package is saved as `/tmp/tensorflow_pkg/tensorflow-1.9.0-<tags>.whl`
and can be installed with `pip install <package path>`. You should uninstall
any version of tensorflow before, e.g. using `pip uninstall tensorflow-gpu`.


## License

This project is published under the MIT License. See the [LICENSE](LICENSE) file
for details.
