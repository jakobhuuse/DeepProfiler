FROM python:3.11-slim

# System libraries required by OpenCV / image-processing dependencies.
# procps provides `ps`, which Nextflow needs to collect per-task metrics
# for trace/report logging.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
        procps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . /src

# The package uses setuptools-scm to derive its version from git tags. The
# build context has no .git (see .dockerignore), so supply the version
# explicitly. The publish workflow passes the release tag here.
ARG DEEPPROFILER_VERSION=0.0.0
ENV SETUPTOOLS_SCM_PRETEND_VERSION=${DEEPPROFILER_VERSION}

# Install DeepProfiler from this checkout. The package pins tensorflow<2.16
# (Keras 2) and numpy<2. We add the CUDA-enabled tensorflow build within that
# range and cap pandas below 3.0, whose positional read_csv breaks DeepProfiler.
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        . \
        "tensorflow[and-cuda]==2.15.1" \
        "pandas>=2.0,<3.0"

# tensorflow[and-cuda] installs the CUDA/cuDNN runtime as nvidia-*-cu12 pip
# wheels but does not put their lib dirs on the dynamic linker path, so
# TensorFlow cannot dlopen them and silently falls back to CPU. Register the
# wheel lib dirs with ldconfig.
RUN python3 -c "import os, glob, nvidia; b = os.path.dirname(nvidia.__file__); \
        print('\n'.join(sorted(glob.glob(os.path.join(b, '*', 'lib')))))" \
        > /etc/ld.so.conf.d/nvidia-wheels.conf \
    && ldconfig

ENTRYPOINT ["deepprofiler"]
CMD ["--help"]
