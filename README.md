# Building and Flashing ARTIQ 9 FPGA Binaries (Kasli V2 / Artix-7 and Kasli SoC / Kintex-7+Zynq) Using AMD Vivado 2024.2 and Docker / Ubuntu 22.04 - Rev 04/03/26

Documentation for successful compilation of Kasli V2 and Kasli SoC binaries using the M-Labs ARTIQ-9 Nix flake, carried out on 04/02/2026 and 04/03/2026 respectively.

Similar setup for UCSB ARTIQ-8 setup (Kasli V2 / Artix-7 only):
https://github.com/nagan319/artiq-build-flash

## Note on README Structure:

The first part, 'Caveman Guide', assumes you are a PhD student either a) setting everythin up from scratch or b) compiling binaries from a ready setup on a Windows 11 workstation. It is very short and does not explain why any decisions were made. 

The second part, 'DevOps Guide', assumes you are proficient with Linux and comfortable with the idea of learning Nix, Docker, etc. for the purpose of modifying or improving upon this configuration. It describes all decisions made in detail.

# Caveman Guide

I assume Windows is being used. Note that many of the commands here will take a long time (like hours) so be ready. 

If some poor soul has already set this up on your machine, skip to "Building Gateware".

Before you start, go to your system settings and find the option 'sleep' or similar and select 'never' so that your computer doesn't fall asleep while compiling something.

## Installing Necessary Things 

### Do you have WSL installed?

If not, you'll need to get it. You can check whether you have it by typing `wsl --version` in PowerShell. 

To install the things we need, type 
```
wsl --install
wsl --install -d Ubuntu
```

It wil ask you to type a username and password so just set something you won't forget.

After this is done type 
```
sudo apt update
```

Then type the following commands
```
exit
wsl --set-default Ubuntu
```

### Do you have Docker installed?

If you do don't have Docker installed, you'll need to download it. Search for `Docker install Windows`.

### When you click on the Docker Desktop icon, can it start the Docker engine fine?

If this is not fine, you probably have a setting called 'virtualization' disabled. You will need to restart your computer, spam F2/F9/F12 (try all of them) while the screen is black, and then navigate the menu to turn it off. Since this is slightly different on all setups you can take a picture and ask chat how to do this.  

### Do you have Git installed?

You can check this by going to the command prompt and typing `git --version`. 
If you do not have it installed, search `git install windows` and run the installer.

### Allowing Docker inside WSL

Type `exit` if you're still in the WSL prompt (`user@...`). 

Click on the Docker Desktop icon. 

Go to the settings (spinny gear on top right). 

Go to 'General' and make sure 'Use the WSL 2 based engine' is checked. 

Go to 'Resources' then 'WSL integration'. Make sure that 'Ubuntu' is toggled on under 'Enable integration with additional distros'.

Now click 'Apply and Restart' on in the bottom right corner. 

Now type `wsl` in PowerShell and type `docker --version`. If it gives you a version you're all good.

## Cloning from Github and Building Vivado 

### Cloning from Github

Go to this Github page in your browser. Press on the green button that says `< > Code` and copy the link. 

Go to PowerShell and type `wsl`.

Now run the following commands:
```
cd ~
mkdir -p artiq-gateware-factory
cd artiq-gateware-factory
git clone [COPIED LINK]
```

### Obtaining AMD Vivado binary

Now it's time to get the AMD Vivado binary.

If not, find `AMD vivado installation` and pick up the version `2024.2`. You will need the Linux version even if you're on Windows! 

The correct title is `FPGAs_AdaptiveSoCs_Unified_2024.2 ... Lin64.bin`.

You'll also need AMD credentials, which you can ask me for. 

Once you have downloaded the file, put it in the same folder as where you cloned the Github repo. Make sure it's inside `artiq-9-gateware-factory`.

The way you do this is (within `wsl`)
```
mv /mnt/c/Users/scientist/Downloads/FPGAs...Lin64.bin ~/artiq-gateware-factory/artiq-9-gateware-factory
```

### Getting authenticated 

Make sure you're in `artiq-9-gateware-factory` and still in `wsl`.

Now run:
```
./generate-auth-token.sh
```

You'll be prompted for a username and password (ask for mine if you don't have your own AMD account).

### Building Vivado 

Copy paste the following command:
```
docker build -t vivado-2024.2-env -f Dockerfile.vivado-base .
```

Leave it running for 1-2 hours. Once it finishes building, run
```
docker save vivado-2024.2-env | gzip > "~/vivado-2024.2-env.tar" 
```
This turns it into a `tarball` so that you have it saved in case you need to build again (much faster next times).

## Building Gateware

After you download the `.json` config files for the gateware, do the following:
```
wsl
mv /mnt/c/Users/[USER]/Downloads/[CONFIG NAME].json ~
```

If you want you can make a separate directory for gateware configs:
```
cd ~
mkdir -p ~/json-configs/
mv *.json json-configs
```

Now you can run the build script:
```
cd ~/artiq-gateware-factory/artiq-9-gateware-factory
./build [CONFIG LOCATION].json
```

The location will be `../[CONFIG NAME].json` or `../json-configs/[CONFIG NAME].json` depending on how it's hooked up.

Your files will appear in `artiq-9-gateware-factory/output/[CONFIG NAME]`.

Once they are there, you can move them back into Windows using `mv top.bit /mtn/c/Users/[USERNAME]/Downloads/` and similar.

# DevOps Guide

I assume Linux is being used and give detailed explanations of how things work. 

# Table of Contents

- Introduction
- What About the M-Labs Guide?
- Device Setup
- Understanding Docker Basics
- Understanding Nix Basics
- How - Installation and Execution Process Explained
- What - Explanation of Directory Contents
- Why - History of Vivado Troubleshooting

# Introduction

This is part 1-3 of 4 of the following process:
1. ✓ Get a working Kasli V2 / Artix-7 build using Docker / Vivado 2024.2 and the M-Labs default ARTIQ-9 Nix flake
2. ✓ Get a working Kasli V2 / Artix-7 build using the `artiq-9-ucsb` Nix flake — build contains different versions of LLVM and is pinned to a stable release
3. ✓ Get a working Kasli SoC / Kintex-7+Zynq build — requires `artiq-zynq` (separate M-Labs repo containing `kasli_soc.py` and Zynq PS firmware)
4. Flash compiled Kasli V2 and SoC gateware onto experimental hardware and test

In order to flash gateware binaries onto the hardware you will need a Nix shell set up; however, this does not require AMD Vivado and is much more straightforward.

Both M-Labs and UCSB Kasli V2 builds are supported via a `--source` flag. Switching between them no longer requires editing any scripts — see the How section. Kasli SoC is detected automatically from the `target` field in the JSON and routed through the `artiq-zynq` build path.

Used the following `ucsb5test.json` configuration for Kasli V2:
```json
{
    "target": "kasli",
    "min_artiq_version": "7.0",
    "variant": "ucsb5test",
    "hw_rev": "v2.0",
    "base": "standalone",
    "core_addr": "192.168.1.75",
    "peripherals": [...]
}
```

Used the following `test_kasli_soc.json` configuration for Kasli SoC:
```json
{
    "target": "kasli_soc",
    "min_artiq_version": "9.0",
    "variant": "test_soc",
    "hw_rev": "v1.1",
    "drtio_role": "standalone",
    "core_addr": "192.168.1.75",
    "peripherals": [
        {
            "type": "dio",
            "ports": [0],
            "bank_direction_low": "input",
            "bank_direction_high": "output"
        }
    ]
}
```

Result (Kasli V2):
```
  top.bit (2.7MB) — valid. Header reads top;COMPRESS=TRUE;Version=2024.2, part xc7a100tfgg484.
  Correct Xilinx Artix-7 bitstream with compression confirmed.

  runtime.bin (1.1MB) — valid. Starts with RISC-V instruction bytes (lui instruction, standard
  bare-metal entry point).

  bootloader.bin (119KB) — valid. Same RISC-V instruction pattern at different load address.
```

Result (Kasli SoC):
```
  top.bit (1.6MB) — valid. Header reads top;COMPRESS=TRUE;Version=2024.2, part xc7z030ffg676.
  Correct Zynq-7030 bitstream. DRC: 0 errors. Timing met.

  runtime.bin (1.6MB) — ARM Cortex-A9 firmware for the Zynq PS.
  runtime.elf (11MB) — ELF with debug symbols for the above.

  jtag/ — szl.elf + runtime.bin + top.bit, for JTAG boot via OpenOCD.
  sd/boot.bin (3.4MB) — Combined Xilinx boot image (SZL + bitstream + firmware) for SD card boot.
```

# What About the M-Labs Guide?

The M-Labs guide for flashing custom binaries is intended specifically for developers interested in modifying ARTIQ source code.

The workflow described is
1. Clone the ARTIQ repo
2. Install Nix on your host machine
3. Install Vivado on your host machine at /opt/Xilinx
4. Run `nix develop` to get a shell with everything wired together
5. Build

This is reasonable if you're an M-Labs engineer with a working Linux/Nix workflow that happens to use base library versions compatible with the versions of ARTIQ and Vivado you are building for. However, it's pretty useless if you want a system-agnostic, reproducible workflow that allows for quickly generating binaries for a known lab setup and can be used by different people without a deep knowledge of Nix or legacy Linux setups.

In this case, the process is flawed for a few major reasons:
- It has host OS dependencies (Nix version, Vivado location, sandbox config)
- The Vivado install step is glossed over ("download and run the installer") despite being the hardest part
- Nothing is pinned — "checkout the most recent release" is not reproducible
- The Kasli-SoC nix build command is genuinely absurd for a first-time user

This is why I decided to try my own workflow.

# Device Setup

The host device needs to be a x86-64 machine. The only necessary setup is installing Docker. Everything else runs within the container.

Realistically you will not be doing this on a Mac - the Docker containers don't work on ARM and any Mac running x86-64 wouldn't have enough processing power to handle containerized Vivado builds.

## Docker Install - Linux

```bash
sudo dnf install docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

Use `apt` or another package manager if you are using a different Linux distribution. All `sudo usermod -aG docker $USER` does is allows your user to run Docker without needing `sudo` root user permissions.

## Docker Install - Windows

Set up Docker Desktop by downloading it from the official website. Enter the app once it's installed. You might have some WSL 2 prompts come up - this is normal.

# Understanding Docker Basics

Docker is a tool that allows for containerized deployment of virtualized systems. What this means is that you can install a particular version of some software on your device, along with all of its dependencies, in a separate box that doesn't interfere with the libraries on your main OS. Unlike a virtual machine (VM), Docker only simulates the application layer of an OS while using your system's kernel.

Since ARTIQ 9 requires AMD Vivado 2024.2, which requires Ubuntu 22.04, using Docker in order to run the Ubuntu environment is a reasonable way of separating satisfying this particular version of Vivado without needing to nuke the rest of your system. This also means that the setup can be ported onto any (Linux) system and work exactly the same regardless of the environment. It is theoretically possible to run this setup on Windows using WSL 2, and on Mac OS using a similar compatibility layer, though I have not tried.

I will explain some Docker basics that are necessary for understanding the content of this batch.

## Images and Containers

A Docker image is a read-only configuration for a Docker setup. For example, a Docker image can contain instructions for installing a legacy version of Ubuntu with particular deprecated C libraries (exactly what is done in our case). A Docker image essentially simulates the application layer of an OS intended to run on the host's kernel.

You can view all of the Docker images on your system using `docker images`.

A Docker container is an active deployment of a Docker image. So, any instances of images that are actively being executed by the Docker core are called containers.

You can view all active Docker containers on your system using `docker ps`.

The distinction here is similar to a static recipe and various instances of the resulting meal.

## Saving and Loading Docker Images

Docker images can be saved to a `tar.gz` for storage and then loaded on any compatible system (in this case any x86-64 system with Docker installed).

You can save an image using
```
docker save <IMAGE> | gzip > <SAVE LOCATION>.tar.gz
```

So for example
```
docker save vivado-2024.2-env | gzip > ~/artiq-images/vivado-2024.2-env-$(date +%Y%m%d).tar.gz
```

Once the image is saved, you can load it using
```
docker load < <SAVE LOCATION>.tar.gz
```

The image will once again be on your device. The `tar.gz` file will stay wherever you initially had it - it is not affected.

## Named Volumes

A Docker volume is a piece of persistent storage that's managed independently of any container or image. It exists on the host file system under `/var/lib/docker/volumes/` but is handled entirely by Docker.

Unlike a bind-mounted directory, which is deliberately placed in a location chosen by the user, a named volume is always accessed by Docker - the user simply refers to it by name. It is useful for persistent storage of data that doesn't change between container executions.

## Bind-Mounted Directories

A bind-mounted directory allows for persistent storage in a location specified by the user. In our case, it's used for persistently storing the `json` input file and the output binaries.

## Dockerfiles

Dockerfiles are just configuration files for docker images. An image can be built using `docker build -t` and a Dockerfile passed as an argument.

Dockerfiles usually begin by simulating some Linux distribution with particular installed libraries, then execute a sequence of commands that installs necessary software.

## Commonly Used Commands

I'll list some Docker commands used throughout this setup for reference:

- `docker images`: Lists all Docker images on the host device.
- `docker image inspect <NAME>`: Shows the properties of a particular Docker image on the host device. We redirect the output to `&>/dev/null` and use it to check whether an image exists.
- `docker ps`: Lists all active Docker containers on the host device.
- `docker run`: Runs a Docker container from a specified image. This command takes a lot of arguments. Look at the invocation example in `build.sh`

# Understanding Nix Basics

Nix is a functional programming language that can be used to define deterministic environments. It's pretty complicated but understanding Nix flakes is really the only thing that's necessary for this installation process.

## Nix Flakes

A Nix flake is a method of creating a deterministic environment by specifying the exact version of every dependency it requires. It is separated into inputs, which describe system dependencies, and outputs, which contain compiled binaries, shell environments (`devShells`) and helper functions for other Nix flakes.

A Nix file can be built from the cloud by using `nix develop` and referencing the Github (or other Git) repository where it is stored. For a completely deterministic environment, pinning a Nix flake using `rev=...` with the particular commit hash prevents rolling-release repositories from breaking the flake configuration over time.

In this setup Nix flakes are used to configure ARTIQ within Docker. They are invoked in the `entrypoint.sh` script. For Kasli SoC builds, a second flake (`artiq-zynq`) is used — this is a separate M-Labs repository that contains the Zynq gateware and ARM firmware build system.

# How - Installation and Execution Process Explained

I will describe in detail the order in which everything is installed, configured and run as well as the locations on the host filesystem where this all happens.

There are three main processes that you may need to engage in. For steps 1 and 2, I assume that the working directory is already set up on your system. If not, you'll need to clone it from Github similar to step 3 but with no Vivado binary.

## 1: Building an FPGA binary for an existing ARTIQ Nix flake
This is if you want to build an FPGA binary and already have the `tar.gz` Docker image which matches the Nix flake that your lab uses.

**What you need:**

From this directory:
  - `build.sh` — the only thing you run
  - `Dockerfile` — used by `build.sh` to rebuild the thin `artiq9-builder` layer
  - `entrypoint.sh` — gets baked into `artiq9-builder` by the `Dockerfile`
  - `sources.conf` — defines the Nix flake URLs for each `--source` option; gets baked into `artiq9-builder` by the `Dockerfile`
  - `Vivado_init.tcl` — gets baked into `artiq9-builder` by the `Dockerfile`
  - `.dockerignore` — prevents output/ and the installer binary from bloating the build context

Docker images:
- `vivado-2024.2-env.tar.gz` — Cold storage for the layer containing AMD Vivado

**Process:**

```
docker load < vivado-2024.2-env.tar.gz
./build.sh [FILENAME].json                    # M-Labs flake (default), target auto-detected from JSON
./build.sh --source=ucsb [FILENAME].json      # UCSB flake
```

The `--source` flag selects which Nix flake to build against. It defaults to `m-labs` if omitted. The flake URLs for each source are defined in `sources.conf`. The build target (`kasli`, `kasli_soc`, etc.) is read automatically from the `"target"` field in the JSON — no flag needed.

For Kasli SoC builds, the output directory will contain:
- `top.bit` — the FPGA bitstream
- `runtime.bin` / `runtime.elf` — ARM Cortex-A9 firmware
- `jtag/` — files for JTAG boot (szl.elf + runtime.bin + top.bit)
- `sd/boot.bin` — combined Xilinx boot image for SD card

For Kasli V2 builds, the output is inside `output/<variant>/gateware/` and `output/<variant>/software/`.

## 2: Adding or updating an ARTIQ Nix flake source
This is if you want to add a new flake source or update the pinned commit for an existing one.

**What you need:**

From this directory:
  - `build.sh`
  - `Dockerfile`
  - `entrypoint.sh`
  - `sources.conf` — edit this file to add or update flake URLs
  - `Vivado_init.tcl`
  - `.dockerignore`

Docker images:
- `vivado-2024.2-env.tar.gz`

**Process:**

```
docker load < vivado-2024.2-env.tar.gz
# edit sources.conf to add or update a flake URL
docker rmi artiq9-builder
./build.sh --source=[SOURCE] [FILENAME].json
```

Since `sources.conf` is baked into the `artiq9-builder` image at build time, you must remove and rebuild that image any time `sources.conf` changes. The Vivado image (`vivado-2024.2-env`) is never affected.

**Editing sources.conf:**

`sources.conf` contains one variable per supported source:

```bash
MLABS_FLAKE="git+https://git.m-labs.hk/M-Labs/artiq.git?rev=<COMMIT>#boards"
UCSB_FLAKE="github:ucsb-amo/artiq/<COMMIT>#boards"
ZYNQ_FLAKE="git+https://git.m-labs.hk/M-Labs/artiq-zynq.git?rev=<COMMIT>"
```

To update a pinned commit:
- Go to the repository on GitHub/Gitea
- Find the commit you want and click on the commit ID (e.g. `11b8d2a`)
- Copy the full 40-character hash (`11b8d2af6d098da4d344b1b3a7866570fdda77ed`)
- Replace the existing hash in `sources.conf`

To add a new source:
- Add a new variable to `sources.conf` (e.g. `MYLAB_FLAKE="github:..."`)
- Add a matching `case` entry in `entrypoint.sh` for the new `--source=` name
- Then `docker rmi artiq9-builder` and rebuild

The format for GitHub-hosted flakes is `github:[USER]/[REPO]/[COMMIT]#boards`. For M-Labs Gitea it is `git+https://git.m-labs.hk/M-Labs/artiq.git?rev=[COMMIT]#boards`.

Note: `ZYNQ_FLAKE` is used automatically for any JSON with `"target": "kasli_soc"` — it does not correspond to a `--source` flag. It always points to the M-Labs `artiq-zynq` repo.

## 3: Running from Scratch (Includes Vivado Install)
This is if you need to re-install AMD Vivado from the binary. Hopefully you will never need to do this unless you are installing from scratch on a new setup.

**What you need:**

From this directory:
- Nothing. We will clone it from Github.

From AMD:
  - `FPGAs_AdaptiveSoCs_Unified_2024.2_1113_2356_Lin64.bin` — the installer binary itself

**Process:**

```
git clone https://github.com/nagan319/artiq-9-gateware-factory
cd artiq-9-gateware-factory
```

Clone from Github.

```
mv FPGAs_AdaptiveSoCs_Unified_2024.2_1113_2356_Lin64.bin ~/.../artiq-9-gateware-factory/
```

Head to the AMD website and download the Vivado 2024.2 unified installer for Linux. Move it into this directory.

```
./generate_auth_token.sh
docker build -t vivado-2024.2-env -f Dockerfile.vivado-base .
docker save vivado-2024.2-env | gzip > ~/.../vivado-2024.2-env.tar.gz
./build.sh system.json
```

If your authentication token has expired run the `generate_auth_token` script. Then build the `vivado-2024.2-env` Vivado image (should take a couple of hours) using the `Dockerfile.vivado-base` configuration. Once this is done save it to a `tar.gz` (also takes a while).

Unlike ARTIQ 8, there is no separate step to compile `fake_udev.so` on the host — it is compiled from `fake_udev.c` inside `Dockerfile.vivado-base` using the container's own GCC, so binary compatibility with Vivado's glibc is guaranteed automatically.

Finally you can run the build script.

# What - Explanation of Directory Contents
Read this to understand what goes on during execution.

## 1. Docker Configs
Read this first. These are all of the config files necessary for setting up the containerized environment. Make sure you understand what exactly makes it reproducible and system-agnostic.

### Dockerfile.vivado-base

This Dockerfile contains instructions for setting up the environment necessary to run Vivado 2024.2. It produces the `vivado-2024.2-env` image, which is the heavy base layer that takes hours to build and is saved to `tar.gz` for reuse.

```bash
FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
```

Bases environment on Ubuntu 22.04, since this is what Vivado 2024.2 needs to run. `DEBIAN_FRONTEND=noninteractive` turns off prompts for any packages that ask for timezone selection, locale confirmation etc. so that `apt-get install` doesn't hang.

```bash
RUN apt-get update && apt-get install -y \
    curl git locales libtinfo5 libncurses5 libxtst6 libxrender1 \
    libxi6 libfontconfig1 libxft2 xz-utils sudo gcc \
    && rm -rf /var/lib/apt/lists/*
```

Even when running headlessly, Vivado is still technically a graphical application that uses these libraries for rendering on X11. If they aren't on the image, the installer segfaults before it can run. `gcc` and `xz-utils` are added compared to the ARTIQ 8 base — `gcc` is needed to compile `fake_udev.c` inside the container, and `xz-utils` is needed by Nix.
`rm -rf /var/lib/apt/lists/*` removes the `apt` package index to reduce image size.

```bash
COPY fake_udev.c /tmp/fake_udev.c
RUN gcc -shared -fPIC -o /usr/local/lib/fake_udev.so /tmp/fake_udev.c && rm /tmp/fake_udev.c
```

`fake_udev.so` is compiled directly inside the Ubuntu 22.04 container using the container's own GCC. This guarantees binary compatibility with Vivado's glibc — the `.so` is stamped with the glibc version symbols present in Ubuntu 22.04 at compile time. In ARTIQ 8 this step had to be done outside the container with a separate `docker run` command; here it is baked into the base image automatically.

```bash
RUN locale-gen en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
```

Vivado assumes a UTF-8 locale for handling strings so this is necessary.

```bash
COPY FPGAs_AdaptiveSoCs_Unified_2024.2_1113_2356_Lin64.bin /tmp/vivado_installer.bin
COPY install_config.txt /tmp/install_config.txt
COPY wi_authentication_key /root/.Xilinx/wi_authentication_key
```

The Vivado installer itself, installation config, and authentication key are brought into the container so that the installer can be run.

```bash
RUN chmod +x /tmp/vivado_installer.bin \
    && /tmp/vivado_installer.bin --keep --noexec --target /tmp/vivado_extracted \
    && /tmp/vivado_extracted/xsetup \
        -a XilinxEULA,3rdPartyEULA \
        -b Install \
        -c /tmp/install_config.txt \
    && rm -rf /tmp/vivado_installer.bin /tmp/vivado_extracted /root/.Xilinx
```

- `chmod +x /tmp/vivado_installer.bin` makes the binary executable
- `--keep --noexec --target /tmp/vivado_extracted` extracts the installer archive without running it.
- `-a ... -c`: Runs the installer. `-a` auto-accepts EULA, `-b Install` means non-interactive install, `-c` passes the config file.
- `rm -rf`: Post installation, all no longer necessary files such as the authentication token and initial binary are removed.

The rest of the base image creates the `builder` user, installs Nix, enables flakes, and pre-warms the ARTIQ Nix environment so that builds don't have to download everything from scratch every time.

### Dockerfile

This Dockerfile builds the thin layer on top of `vivado-2024.2-env`. It contains ARTIQ configuration, Vivado tweaks, and the build scripts. It is built separate from the Vivado image to allow for recompiling the build setup for different Nix flakes without re-building Vivado from scratch every time.

```bash
FROM vivado-2024.2-env
```

Starts building on top of `vivado-2024.2-env` — inherits everything from `Dockerfile.vivado-base`.

```bash
USER root
RUN cp /usr/local/lib/fake_udev.so /lib/x86_64-linux-gnu/libudev.so.1
```

Switches to root to copy the `fake_udev` stub to the system library path. This makes sure the fake `udev` file is in place before Vivado starts. Unlike ARTIQ 8, the `.so` was already compiled in the base image so there is no COPY step here.

```bash
RUN ln -s /tools/Xilinx /opt/Xilinx
```

Creates a symlink `/opt/Xilinx -> /tools/Xilinx`. Our Vivado install lives at `/tools/Xilinx` (set in `install_config.txt`), but the `artiq-zynq` flake's Vivado FHS wrapper expects it at `/opt/Xilinx/Vivado/2024.2/`. Both paths need to resolve to the same installation. The `nixConfig` in `artiq-zynq` sets `extra-sandbox-paths = "/opt"`, which makes `/opt` visible inside the Nix build sandbox — pointing it at `/tools/Xilinx` via symlink makes the Vivado binary available there.

```bash
USER builder
RUN mkdir -p /home/builder/.Xilinx/Vivado
COPY --chown=builder:builder Vivado_init.tcl /home/builder/.Xilinx/Vivado/Vivado_init.tcl
```

Creates the `/.Xilinx/Vivado` directory Vivado expects and copies our custom `Vivado_init.tcl` file into it. `--chown=builder:builder` gives the `builder` user ownership. This is necessary because Vivado is run as the `builder` user.

```bash
COPY --chown=builder:builder sources.conf /home/builder/sources.conf
COPY --chown=builder:builder entrypoint.sh /home/builder/entrypoint.sh
RUN chmod +x /home/builder/entrypoint.sh

ENTRYPOINT ["/home/builder/entrypoint.sh"]
```

`sources.conf` is copied alongside `entrypoint.sh` into the `builder` home directory. Both files are baked into the image, so `docker rmi artiq9-builder` is required after editing either one.

`entrypoint.sh` is made executable and set as the container entry point. Running `docker run artiq9-builder --source=ucsb system.json` executes as `/home/builder/entrypoint.sh --source=ucsb system.json` inside the container.

### .dockerignore

```
output/
*.log
FPGAs_AdaptiveSoCs_Unified_2024.2_1113_2356_Lin64.bin
```

As you can probably tell this is the Docker analogue of `.gitignore`. When `docker build` is run in a directory, it is packaged and sent to the Docker daemon before it reads the Dockerfile. By including `output/` we prevent it from packaging potentially massive previously built FPGA binaries. The installer binary is excluded to avoid re-sending 10+ GB to the daemon when rebuilding the thin layer.

### sources.conf

This file defines the Nix flake URLs for each named source. It is sourced by `entrypoint.sh` at runtime inside the container. To add a source or update a pinned commit, edit this file and run `docker rmi artiq9-builder` — `build.sh` needs no changes.

```bash
MLABS_FLAKE="git+https://git.m-labs.hk/M-Labs/artiq.git?rev=961551dd...#boards"
UCSB_FLAKE="github:ucsb-amo/artiq/<BRANCH_OR_COMMIT>#boards"
ZYNQ_FLAKE="git+https://git.m-labs.hk/M-Labs/artiq-zynq.git?rev=11b8d2af..."
```

`MLABS_FLAKE` and `UCSB_FLAKE` correspond to `--source=m-labs` and `--source=ucsb` flags and are used for Kasli V2 builds via `nix develop`. `ZYNQ_FLAKE` is used automatically for any JSON with `"target": "kasli_soc"` regardless of `--source` — it always points to the M-Labs `artiq-zynq` repository, which contains the Zynq gateware Python script and ARM firmware build system.

## 2. Build Scripts
These are all of the scripts that are run whenever you decide to compile an FPGA binary from an ARTIQ `json` file.

### build.sh

This is the shell script that you execute whenever you want to compile an ARTIQ binary. It's run entirely outside of Docker. This is the only part of the system that is dependent on the host configuration. It runs on effectively any version of Linux since it only requires `bash`, `docker`, `realpath`, `basename`, `dirname`, and `mkdir`.

```bash
if ! docker image inspect "vivado-2024.2-env" &>/dev/null; then
    echo "ERROR: Base image 'vivado-2024.2-env' not found."
    ...
fi
```

We run a check to see whether the `vivado-2024.2-env` image exists on the device. This image contains the full installation of AMD Vivado 2024.2 for ARTIQ 9 running on Ubuntu 22.04. It takes 1-2 hours to build, which is why it is kept separate from the `artiq9-builder` container.

```bash
docker run --rm \
    --shm-size=2g \
    --security-opt seccomp=unconfined \
    -v artiq9-nix-store:/nix \
    -v "${JSON_DIR}/${JSON_FILENAME}:/input/${JSON_FILENAME}:ro" \
    -v "${OUTPUT_DIR}:/output" \
    "$IMAGE_NAME" \
    "--source=${SOURCE}" \
    "$JSON_FILENAME"
```

This launches the container and passes both the `--source` flag and the JSON filename to `entrypoint.sh`. `docker run` parameters:

- `--rm`: Deletes the container when it exits. This prevents a buildup of unused containers on the host system.
- `--shm-size=2g`: Sets `/dev/shm` (shared memory) to 2 GB. Vivado's router relies on this shared memory. Docker sets it to 64 MB by default, which leads to segmentation faults.
- `--security-opt seccomp=unconfined`: Removes Docker's default seccomp syscall filter. This is required for Kasli SoC builds, where the Nix build sandbox and the `artiq-zynq` Vivado FHS wrapper both use `bubblewrap` (`bwrap`) to create isolated filesystem namespaces. `bwrap` requires the `unshare` syscall, which Docker's default seccomp profile blocks. Kasli V2 builds work without this flag since they run Vivado directly outside the Nix sandbox, but it is kept unconditionally so the same command works for both targets.
- `-v artiq9-nix-store:/nix`: Mounts the named Docker volume `artiq9-nix-store` at `/nix` within the container. Stores all ARTIQ dependencies from the Nix flake so they don't need to be re-fetched on every build.
- `-v "${JSON_DIR}/${JSON_FILENAME}:/input/${JSON_FILENAME}:ro"`: Bind mounts the input `json` file at `/input` inside the container, read-only.
- `-v "${OUTPUT_DIR}:/output"`: Bind mounts the output directory for persistent storage of built binaries.

### entrypoint.sh

This script is the true entry point to the Docker container. It's the first thing that's executed by Docker when `docker run` is called within `build.sh`.

After setting up Nix and parsing arguments, it extracts the target from the JSON:

```bash
TARGET=$(grep -oP '"target"\s*:\s*"\K[^"]+' "$INPUT_PATH" 2>/dev/null || echo "kasli")
```

`grep -oP` with a Perl-compatible lookahead extracts the `"target"` field value directly. This replaces the `python3 -c "import json..."` approach used in ARTIQ 8, which failed silently because `python3` is not available in the container before `nix develop` runs.

The script then branches on the target:

**For `kasli` and other non-SoC targets:**
```bash
nix develop "$FLAKE_URL" --impure --command bash -c "
    source /tools/Xilinx/Vivado/2024.2/settings64.sh
    export LD_PRELOAD=/usr/local/lib/fake_udev.so
    python3 -m artiq.gateware.targets.${TARGET} ${INPUT_PATH} --output-dir /output
"
```

`nix develop` fetches the main ARTIQ flake at the pinned commit, opens a shell with all ARTIQ dependencies available, sources Vivado 2024.2, installs the udev stub via `LD_PRELOAD`, and invokes the Python gateware builder. `--impure` loosens Nix's sandbox to allow access to Vivado at `/tools/Xilinx`.

**For `kasli_soc`:**
```bash
# Generate a temp flake.nix that calls makeArtiqZynqPackage with our JSON
cat > "$TMPDIR/flake.nix" << EOF
{
  inputs.artiq-zynq.url = "$ZYNQ_FLAKE";
  outputs = { self, artiq-zynq }:
    let
      pkgSet = artiq-zynq.makeArtiqZynqPackage {
        target = "kasli_soc";
        variant = "user";
        json = ./system.json;
      };
    in {
      packages.x86_64-linux = pkgSet;
    };
}
EOF

for pkg in gateware firmware jtag sd; do
    nix build "$TMPDIR#kasli_soc-user-${pkg}" \
        --accept-flake-config \
        --impure \
        --option extra-sandbox-paths "/opt /tools/Xilinx" \
        -L \
        --out-link "$TMPDIR/result-${pkg}"
done
```

`kasli_soc` is in the separate `M-Labs/artiq-zynq` repository and uses `nix build` rather than `nix develop + python`. The script generates a temporary `flake.nix` that wraps `artiq-zynq`'s exported `makeArtiqZynqPackage` function with the user's JSON file. This produces an attrset of four derivations (`kasli_soc-user-gateware`, `-firmware`, `-jtag`, `-sd`) which are built individually. `--accept-flake-config` allows the `nixConfig` in `artiq-zynq` (which sets substituters and sandbox paths) to take effect. `--option extra-sandbox-paths "/opt /tools/Xilinx"` makes Vivado visible inside the Nix build sandbox.

After building, the outputs are copied using `install -m 644` rather than `cp`. Nix store files are read-only, and `cp` preserves that permission, making subsequent runs fail trying to overwrite an immutable file. `install` writes the file with normal permissions regardless of the source.

## 3. Vivado-Related Files

These are the files used to trick Vivado into running within a containerized environment. Make sure you understand how this works.

### Vivado_init.tcl

`Vivado_init.tcl` is a script that Vivado automatically sources at startup before doing anything else. It looks for it at the fixed path `~/.Xilinx/Vivado/Vivado_init.tcl` every time it launches.

```bash
# Disable WebTalk data collection
config_webtalk -user off
config_webtalk -install off
```

Webtalk is disabled at both the user and device level so that Vivado doesn't try to phone home to `libudev.so.1` and crash the build process (look in `fake_udev.c`).

```bash
# Disable version check network call
set_param allow_version_check false
```

Vivado periodically phones home to its server to check if a newer version is available. This causes unnecessary lag so we disable it.

```bash
# Use all available cores for synthesis and implementation
set_param general.maxThreads [exec nproc]
```

`[exec nproc]` runs the shell command `nproc` and returns its output. This command checks the number of available cores on the host CPU. Without this, Vivado defaults to only using 2 cores and takes forever to build the FPGA binaries.

The thing with this file is that it must be baked into the Docker image at the specified fixed path. Because `nix develop` called in `entrypoint.sh` modifies the `$HOME` directory, Vivado ends up looking in the wrong place unless the file location is explicitly defined within Docker.

Basically:
- `nix develop` sets `$HOME` to a temporary directory within the Nix store, which means that Vivado tries looking in the Nix-modified home and doesn't find the file
- Because `$HOME` only modifies the `~` path, it's necessary to specify the absolute `/home/builder/...` path in the Dockerfile.
- The home directory is `/home/builder` simply because of how Docker handles this for builder users.

### fake_udev.c

`udev` is the Linux device manager. It handles any hardware devices connected to the system such as USB ports, disks, network interfaces, etc. Other programs query it through `libudev.so.1` to ask questions about what devices are attached, what the serial number of a USB is and so on.

Vivado calls `udev` for two purposes:
- License fingerprinting - using hardware properties such as disk serial numbers, network card MAC addresses etc. to verify whether this is the machine the software is licensed to run on
- Webtalk - collecting usage analytics and hardware info before phoning home to Xilinx

Because Docker shares the host kernel but not the host `udev` daemon, these processes naturally crash when you try to run Vivado inside a Docker container. This means that when Vivado tries to access `libudev.so.1` to read from `/run/udev/data/` or similar it gets garbage corrupted data which crashes the build process.

Even though `Vivado_init.tcl` disables webtalk at the TCL server level, the licensing issue still isn't fixed. Also, in case `Vivado_init.tcl` fails for some reason, `fake_udev.c` ensures that Vivado still doesn't crash. So they're both useful, just in different ways.

The file spoofs all `libudev.so.1` entry points with safe no-op implementations that return null pointers and zero values, satisfying Vivado's calls without crashing.

Unlike ARTIQ 8 where `fake_udev.so` was compiled on the host and copied into the image, here `fake_udev.c` is compiled inside `Dockerfile.vivado-base` using the container's own GCC. This guarantees that the resulting `.so` references only glibc symbols present in Ubuntu 22.04, which is what Vivado's `dlopen("libudev.so.1")` requires for binary compatibility.

### install_config.txt

This file contains installation instructions that are passed into Vivado's `xsetup` installer as a configuration when `Dockerfile.vivado-base` is invoked. It specifies the install destination (`/tools/Xilinx`), device families to include, and disables desktop shortcuts since it is running headlessly.

The module names in this file are version-specific. Vivado 2024.2 renamed several modules and added new ones compared to 2022.2 (e.g. `Versal AI Edge Series`, `Power Design Manager (PDM)`, `Vitis Model Composer(Toolbox for MATLAB and Simulink. Includes the functionality of System Generator for DSP)`). Passing an invalid module name causes the installer to fail with a non-obvious error. The correct names were obtained by running `xsetup -b ConfigGen` from the extracted installer.

### generate_auth_token.sh

If you are building AMD Vivado from scratch, it's necessary to authenticate using the `wi_authentication_key`. This script allows for generating the authentication key before building the Docker environment.

The script extracts the Vivado installer binary, runs `xsetup -b AuthTokenGen` which prompts for AMD account credentials, and copies the resulting `wi_authentication_key` file into this directory for use by `Dockerfile.vivado-base`.

### wi_authentication_key (produced by generate_auth_token.sh)

```json
{"expiration":"XX\/XX\/XXXX XX:XX AM","username":"XXXX@XXX.com","token":"XXXXXXXXXXXXXXX"}
```

Before installing AMD Vivado from the binary, the user is required to authenticate with an AMD account. The `wi_authentication_key` file is the token that proves this.

This token typically expires a week after it is generated. The file is only used in `Dockerfile.vivado-base`, where it is copied to `/root/.Xilinx` for authentication and then deleted. This is only necessary if you are rebuilding AMD Vivado from the binary.

# Why - History of Vivado Troubleshooting

## Vivado 2024.2 Module Names

The first attempt to build `vivado-2024.2-env` failed immediately with a non-obvious error: "The value specified in the configuration file for Modules is not valid". The `install_config.txt` from ARTIQ 8 was copied directly and passed to the 2024.2 installer, which rejected it because Xilinx renamed and added several module entries between versions. The correct module names were recovered by extracting the installer and running `xsetup -b ConfigGen` to generate a fresh config file.

## Kasli SoC Target Discovery

Early attempts to build kasli_soc using `python3 -m artiq.gateware.targets.kasli_soc` failed with `No module named artiq.gateware.targets.kasli_soc`. This is because `kasli_soc.py` does not exist in the main `M-Labs/artiq` repository at any release — it lives in a separate repository, `M-Labs/artiq-zynq`, which has a completely different build system based on `nix build` rather than `nix develop + python`.

## Silent Target Extraction Failure

The original `entrypoint.sh` extracted the build target from the JSON using:
```bash
TARGET=$(python3 -c "import json,sys; ..." 2>/dev/null || echo "kasli")
```

`python3` is not installed in the container before `nix develop` runs. The `2>/dev/null` silenced the error and the `|| echo "kasli"` fallback fired silently, so every build defaulted to `kasli` regardless of what was in the JSON. This was replaced with `grep -oP` which is always available.

## Vivado Path Mismatch

The `artiq-zynq` flake's Vivado FHS wrapper expects Vivado at `/opt/Xilinx/Vivado/2024.2/` and its `nixConfig` sets `extra-sandbox-paths = "/opt"` to make that path visible inside the Nix build sandbox. Our Docker image installs Vivado at `/tools/Xilinx/` (configured in `install_config.txt`). The fix is a symlink `/opt/Xilinx -> /tools/Xilinx` added in the thin Dockerfile, combined with `--option extra-sandbox-paths "/opt /tools/Xilinx"` passed to `nix build`.

## bubblewrap / User Namespace Permissions

Kasli SoC builds failed inside Docker with:
```
bwrap: No permissions to creating new namespace, likely because the kernel does not allow
non-privileged user namespaces.
```

The `artiq-zynq` Vivado FHS wrapper uses `bubblewrap` (`bwrap`) to construct a fake FHS root inside the Nix build sandbox. `bwrap` needs to create user namespaces (`unshare` syscall), which Docker's default seccomp profile blocks. The fix is `--security-opt seccomp=unconfined` in the `docker run` invocation.

## Nix Store File Permissions

After the first successful kasli_soc build, subsequent runs failed with:
```
cp: cannot create regular file '/output/top.bit': Permission denied
```

Files copied from the Nix store inherit its read-only permissions. On the second run, `cp` could not overwrite the read-only `top.bit` already present in `/output`. The fix is to use `install -m 644` instead of `cp`, which always writes the destination with the specified permissions regardless of the source.
