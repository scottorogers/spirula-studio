# Spirula Studio, Vulkan backend, CLI only (no GUI, no display).
# Needs a host with an NVIDIA GPU + nvidia-container-toolkit, or any Vulkan GPU
# passed through to the container. A GPU-less VPS cannot train.
#
#   docker build -t spirula .
#   docker run --rm --gpus all -v "$PWD/data:/data" spirula --help

FROM ubuntu:24.04 AS build
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential cmake ninja-build git curl ca-certificates \
        python3 unzip xz-utils libvulkan-dev \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /src
COPY . .
# Fetches the pinned slangc (and Vulkan headers if too old) from GitHub at build time.
# Not enabling SS_ENABLE_PATENTED: AVC/HEVC patent exposure is yours if you do.
RUN bash build_develop.bash -DSS_BACKEND=vulkan -DSS_BUILD_GUI=OFF \
    && test -x build_vulkan/spirula

FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        libvulkan1 libgomp1 ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/build_vulkan/spirula /usr/local/bin/spirula

# Lets the NVIDIA runtime expose Vulkan, and gives the loader an ICD if the
# toolkit does not inject one.
ENV NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=graphics,compute,utility,video
RUN mkdir -p /etc/vulkan/icd.d && printf '%s\n' \
    '{"file_format_version":"1.0.0","ICD":{"library_path":"libGLX_nvidia.so.0","api_version":"1.3.0"}}' \
    > /etc/vulkan/icd.d/nvidia_icd.json

WORKDIR /data
ENTRYPOINT ["spirula"]
CMD ["--help"]
