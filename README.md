# Building and Flashing ARTIQ 9 FPGA Binaries (Kasli V2 / Artix-7 and Kasli SoC / Kintex-7+Zynq) Using AMD Vivado 2024.2 and Docker / Ubuntu 22.04 - Rev 04/17/26

## Todo:
- set up UCSB nix flake properly 
- write command to do tedious WSL setup as much as possible 
- do artiq_flash script rewrite accounting for middleware 
- figure out which particular commit to pull from

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

### Installing Nix Inside WSL 

You'll need to use Nix inside WSL if you want to flash your gateware from the same device as where you build it.

Run:
```
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install 
```

Now open a new WSL shell (cmd and type `wsl`) and type `nix --version` to check that you have it.

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

The file name on the website is  `AMD Unified Installer for FPGAs & Adaptive SoCs 2024.2: Linux Self Extracting Web Installer`. The filename is `FPGAs_AdaptiveSoCs_Unified_2024.2 ... Lin64.bin`.

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
./build.sh [CONFIG LOCATION].json
```

The location will be `../[CONFIG NAME].json` or `../json-configs/[CONFIG NAME].json` depending on how it's hooked up.

Your files will appear in `artiq-9-gateware-factory/output/[CONFIG NAME]/` (the subfolder name matches the JSON filename without `.json`).

You can copy them back to Windows using the following command:
```
cp -r /output/[CONFIG NAME] /mnt/c/Users/[USER]/Downloads/
```
This will allow you to see the files in File Explorer by clicking around the folders.

Just make sure you don't have multiple copies with the same title so that they don't get overwritten or combined into one folder.

After you're done you can type `exit`, or just close the terminal. Your files will be in your `Downloads` folder (or wherever you put them).

If everything on your system has been configured and you now want to flash your binaries to the ARTIQ crate, go to 'flashing gateware'.

## Setting Up Gateware Flash Utilities

This section has instructions for setting up necessary USB permissions so you can flash the binaries to your ARTIQ crate.

Go to PowerShell and make sure you have a USB listing utility called `usbipd`. This is what's used on PowerShell to list plugged in devices.

You can install and verify you have it using the following commands in an admin shell. To open an admin shell, right-click on the PowerShell option in CMD '+' button and select 'Run as Administrator'.

```
winget install usbipd
usbipd --version 
```

You will now need to run WSL and install some things on that side:
```
wsl
sudo apt install usbutils
sudo apt install linux-tools-virtual
```

Make sure the command `usbip` works when typed in console
```
sudo ln -sf "$(find /usr/lib/linux-tools -name usbip | tail -1)" /usr/local/bin/usbip
```

Another step is to copy a temporary file ARTIQ uses for flashing to a place where it can see it.

Run the following steps in WSL:
```
find /nix/store -name "bscan_spi_xc7a100t.bit" 2>/dev/null
```

Then copy the filepath it gives you to `~/artiq-gateware-factory/artiq-9-gateware-factory`. For example:
```
cd ~/artiq-gateware-factory/artiq-9-gateware-factory
cp /nix/store/.../share/bscan-spi-bitstreams/bscan_spi_xc7a100t.bit .
```

Now copy tihs to some 'backup' folders where the system tries to find this file:
```
mkdir -p ~/.migen
cp bscan_spi_xc7a100t.bit ~/.migen/

sudo mkdir -p /root/.migen 
sudo cp bscan_spi_xc7a100t.bit /root/.migen/
```

## Flashing Gateware (Kalsi V2)

Get your Kasli V2 crate, plug in power and connect to your (Windows) device using a USB-B to USB-A wire. Make sure the lights are turned on.

Open PowerShell as an admin and run:
```
usbipd list
```
You should see something labeled `... USB Serial Converter B ...`. This is the right port. You'll see a `BUSID` in the left column of the listed table. Use this value and run
```
usbipd bind --busid [BUSID]
usbipd attach --wsl --busid [BUSID]
```
You'll get an output like `Using WSL Distribution 'Ubuntu' to attach...`. This allows you to use WSL for interacting with this port.

Open a new cmd prompt and run the following:
```
wsl 
lsusb 
```
You'll see something like `Future Technology Devices ...`. This is the ARTIQ crate.

Run the Nix shell for flashing ARTIQ. Replace `output/[CONFIG]` with the location of your config files:
```
sudo env "PATH=$PATH" nix shell \
    git+https://git.m-labs.hk/M-Labs/artiq.git?ref=release-9#artiq \
    git+https://git.m-labs.hk/M-Labs/artiq.git?ref=release-9#openocd-bscanspi \
    --command artiq_flash -t kasli -d output/[CONFIG] --srcbuild write=gateware,bootloader,firmware
```

You'll get a bunch of `Info : sector ...` messages, which means that the gateware is being flashed.

## Troubleshooting Flash 

After flashing, it's not actually trivial to connect to the crate using Wifi. 

There are a few troubleshooting steps that can be taken to make sure its configured correctly.

Enter the Nix shell again:
```
sudo env "PATH=$PATH" nix shell \
    git+https://git.m-labs.hk/M-Labs/artiq.git?ref=release-9#artiq \
    git+https://git.h-labs.hk/M-Labs/artiq.git?ref=release-9#openocd-bscanspi \
```

Make sure it's activated (you should see a file location pop up for this command)
```
which artiq_flash
```

Testing to see if the Kasli is visible:
```
openocd -f board/kasli.cfg
```
After you get an output like 'listening on port ...', press Ctrl+C to exit. 

Test to see the ARTIQ boot sequence:

You'll need to get something like `minicom` to read USB IO
```
sudo apt install minicom 
```

Now open a port (try changing the USB number to 1 or 3 if 2 doesn't work)
```
sudo minicom -D /dev/ttyUSB2 -b 115200
```
Turn on carriage return (proper display) using Ctrl+Z A U.

Turn off the Kasli and turn it back on again. You should see text appear.

Look at the IP displayed in the output. This is the real IP! It might actually be different from your config IP, because the config IP gets overriden by another value inside the crate.

You can ping this IP, for example 
```
ping 192.168.1.86
```
If this works, your ARTIQ crate is fully online.

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
  top.bit (3.1MB) — valid. Zynq-7030 bitstream. DRC: 0 errors.
  Timing met: WNS=0.235 ns, WHS=0.017 ns, zero failing endpoints.

  runtime.bin (1.7MB) — ARM Cortex-A9 firmware for the Zynq PS.
  runtime.elf (14MB) — ELF with debug symbols for the above.

  jtag/ — szl.elf + runtime.bin + top.bit, for JTAG boot via OpenOCD.
  sd/boot.bin — Combined Xilinx boot image (SZL + bitstream + firmware) for SD card boot.
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

For Kasli V2 builds, the output is inside `output/<json-name>/gateware/` and `output/<json-name>/software/`, where `<json-name>` is the JSON filename without `.json`.

Regardless of build target, the flake URL and build metadata are recorded in `output/nix-flakes/<json-name>/` for version tracking and reproducibility.

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
    --privileged \
    --shm-size=2g \
    -v artiq9-nix-store:/nix \
    -v "${JSON_DIR}/${JSON_FILENAME}:/input/${JSON_FILENAME}:ro" \
    -v "${OUTPUT_DIR}:/output" \
    "$IMAGE_NAME" \
    "--source=${SOURCE}" \
    "$JSON_FILENAME"
```

This launches the container and passes both the `--source` flag and the JSON filename to `entrypoint.sh`. `docker run` parameters:

- `--rm`: Deletes the container when it exits. This prevents a buildup of unused containers on the host system.
- `--privileged`: Grants the full Linux capability set to the container. Required for Kasli SoC builds, where the `artiq-zynq` Vivado FHS wrapper calls `bubblewrap` (`bwrap`) to create a mount namespace (`CLONE_NEWNS`). Docker containers do not have `CAP_SYS_ADMIN` by default, which is required for mount namespace creation. Kasli V2 builds run Vivado directly without bwrap, but `--privileged` is kept unconditionally so the same command works for both targets.
- `--shm-size=2g`: Sets `/dev/shm` (shared memory) to 2 GB. Vivado's router relies on this shared memory. Docker sets it to 64 MB by default, which leads to segmentation faults.
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

# Rename variant-named dir to JSON-named dir
if [ -n "$VARIANT" ] && [ "$VARIANT" != "$JSON_BASE" ] && [ -d "/output/$VARIANT" ]; then
    rm -rf "/output/$JSON_BASE"
    mv "/output/$VARIANT" "/output/$JSON_BASE"
fi
```

`nix develop` fetches the main ARTIQ flake at the pinned commit, opens a shell with all ARTIQ dependencies available, sources Vivado 2024.2, installs the udev stub via `LD_PRELOAD`, and invokes the Python gateware builder. `--impure` loosens Nix's sandbox to allow access to Vivado at `/tools/Xilinx`.

The Python gateware builder names its output subdirectory after the `"variant"` field in the JSON, not the JSON filename. The rename step moves that directory to match the JSON filename, so output paths are always `output/<json-name>/` regardless of what `"variant"` is set to.

After the build, `nix flake metadata --json` is run against the flake URL and saved to `output/nix-flakes/<json-name>/flake-metadata.json` alongside a `build-info.txt` recording the date, source, and flake URL. For kasli_soc builds the generated `wrapper-flake.nix` is also preserved there.

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
bwrap: Creating new namespace failed: Operation not permitted
```

The `artiq-zynq` Vivado FHS wrapper uses `buildFHSEnv` which calls `bubblewrap` (`bwrap`) to construct a mount namespace for the fake FHS root needed by Vivado. Even running as root inside the container, Docker's default capability set does not include `CAP_SYS_ADMIN`, which is required for `CLONE_NEWNS` (mount namespace creation). The fix is `--privileged` in the `docker run` invocation, which grants the full Linux capability set to the container.

## sipyco Test Failures Blocking the Build

`nix develop` / `nix build` compile every package in the dependency graph, including `sipyco` (ARTIQ's RPC library). `sipyco`'s test suite opens TCP connections on localhost to exercise its asyncio RPC layer. The asyncio tests consistently fail inside Docker with ECONNREFUSED, even when loopback networking is available, likely due to a Python 3.13 asyncio race condition in the test server startup:

```
OSError: Multiple exceptions: [Errno 111] Connect call failed ('::1', 7777, 0, 0), [Errno 111] Connect call failed ('127.0.0.1', 7777)
FAILED (errors=4)
```

This cascades: `sipyco` → `artiq` → the gateware derivation, aborting the entire build.

The fix is to pull `sipyco` (and all other ARTIQ packages) from the M-Labs binary cache instead of building them locally — pre-built packages have no test phase. The M-Labs cache is at `https://nixbld.m-labs.hk`.

The cache must be configured in two places. First, the thin `Dockerfile` writes it into the system-level Nix config (which root reads) alongside the other required settings:

```dockerfile
RUN mkdir -p /etc/nix && printf \
  'sandbox = false\nexperimental-features = nix-command flakes\nbuild-users-group =\n\
extra-substituters = https://nixbld.m-labs.hk\n\
extra-trusted-public-keys = nixbld.m-labs.hk-1:5aSRVA5b320xbNvu30tqxVPXpld73bhtOeH6uAjRyHc=\n' \
  > /etc/nix/nix.conf
```

Second, the wrapper `flake.nix` generated by `entrypoint.sh` for kasli_soc builds includes a `nixConfig` block so that `--accept-flake-config` picks it up for that build path:

```nix
nixConfig = {
  extra-substituters = "https://nixbld.m-labs.hk";
  extra-trusted-public-keys = "nixbld.m-labs.hk-1:5aSRVA5b320xbNvu30tqxVPXpld73bhtOeH6uAjRyHc=";
};
```

Without both entries, `nix build` on the wrapper flake only uses the nixos.org cache, builds sipyco from source, and hits the test failure. The artiq-zynq flake does specify the M-Labs cache in its own `nixConfig`, but `--accept-flake-config` only applies the `nixConfig` from the flake currently being built — not from its inputs — so the artiq-zynq cache config is invisible to our wrapper flake without the explicit re-declaration.

`sandbox = false` remains in `nix.conf`. It is a privileged Nix setting — writing it to `~/.config/nix/nix.conf` as the `builder` user has no effect; it only takes effect from the system-level config written as root. It disables Nix's build sandbox so that local builds (when the cache misses) have full network access.

## Dockerfile Changes Not Applied to Running Builds

`build.sh` previously checked whether `artiq9-builder` existed and skipped `docker build` if it did:

```bash
if ! docker image inspect "$IMAGE_NAME" &>/dev/null; then
    docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
fi
```

This meant any change to the `Dockerfile`, `entrypoint.sh`, or `sources.conf` was silently ignored on subsequent runs — the stale image was reused. Nix configuration changes (e.g. adding the M-Labs binary cache to `/etc/nix/nix.conf`) written into the `Dockerfile` had no effect until the image was manually deleted with `docker rmi artiq9-builder`.

The fix is to always run `docker build`. Docker's own layer cache makes this efficient — unchanged layers are reused, and only the layers downstream of a change are rebuilt:

```bash
echo "==> Building ARTIQ builder image (uses Docker layer cache, only changed layers rebuilt)..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"
```

When updating `Dockerfile`, `entrypoint.sh`, or `sources.conf`, no manual `docker rmi` is needed — the next `./build.sh` run picks up the change automatically.

## Nix Store Volume Shadowing

On first run on a new machine, the `artiq9-nix-store` named volume starts empty. `build.sh` mounts it at `/nix` inside the container, which shadows the Nix store baked into the `vivado-2024.2-env` image during `docker build`. With `/nix` empty, the symlink chain `~/.nix-profile -> /nix/var/nix/profiles/per-user/builder/profile` is broken — and since the `nix` binary itself lives in the Nix store, it is also unavailable. The container exits immediately with:

```
/home/builder/entrypoint.sh: line 5: /home/builder/.nix-profile/etc/profile.d/nix.sh: No such file or directory
```

The fix, added to `build.sh`, is to detect an empty volume before the main build run and seed it by copying the image's `/nix` into the volume — mounting the volume at `/nix-target` rather than `/nix` so the image's own store remains accessible during the copy. Subsequent runs find the volume already populated and skip the seeding step.

## Output Directory Named After Variant, Not JSON Filename

For Kasli V2 (`kasli`) builds, the ARTIQ Python gateware script (`artiq.gateware.targets.kasli`) creates its output subdirectory using the `"variant"` field from the JSON, not the JSON filename. For example, building `laser_satellite_ucsb5.json` with `"variant": "ucsb5satellite"` produced output at `output/ucsb5satellite/`, while the JSON that drove the build was named `laser_satellite_ucsb5.json`.

This is a mismatch: the natural key for a build is its input JSON, but the output was named after an internal field that the user has no particular reason to keep synchronized with the filename.

The fix in `entrypoint.sh` is to extract the `"variant"` field with `grep`, then after the Python script completes, rename `output/$VARIANT` to `output/$JSON_BASE` if the two differ:

```bash
VARIANT=$(grep -oP '"variant"\s*:\s*"\K[^"]+' "$INPUT_PATH" 2>/dev/null || echo "")
JSON_BASE="${JSON_FILE%.json}"
# ... build runs, creating /output/$VARIANT/ ...
if [ -n "$VARIANT" ] && [ "$VARIANT" != "$JSON_BASE" ] && [ -d "/output/$VARIANT" ]; then
    rm -rf "/output/$JSON_BASE"
    mv "/output/$VARIANT" "/output/$JSON_BASE"
fi
```

Kasli SoC builds are not affected — they write directly to the specified output path.

## Nix Store File Permissions

After the first successful kasli_soc build, subsequent runs failed with:
```
cp: cannot create regular file '/output/top.bit': Permission denied
```

Files copied from the Nix store inherit its read-only permissions. On the second run, `cp` could not overwrite the read-only `top.bit` already present in `/output`. The fix is to use `install -m 644` instead of `cp`, which always writes the destination with the specified permissions regardless of the source.

# Debugging Timing Issues

ARTIQ gateware builds produce Vivado timing reports and a routed design checkpoint in `output/<variant>/gateware/`. These can be used to investigate non-deterministic delays or unexpected behavior on hardware.

## Reading the Timing Reports

Key output files:

- `top_timing.rpt` — post-route timing report. The summary shows WNS (Worst Negative Slack), TNS (Total Negative Slack), and WHS (Worst Hold Slack). All values must be ≥ 0 for a timing-clean build.
- `top_route_status.rpt` — routing completion status.
- `top_drc.rpt` — design rule check results including CDC warnings.

A timing-clean build (all positive slack, zero failing endpoints) rules out metastability from setup violations. If WNS or WHS are negative, the gateware needs re-running — try different implementation strategy or placement seeds in `Vivado_init.tcl`.

## Opening the Vivado GUI via Docker

The routed design checkpoint `top_route.dcp` can be opened in Vivado for interactive routing and timing inspection. Vivado lives inside the `vivado-2024.2-env` Docker image, so it is run with X11 forwarding:

```bash
xhost +local:
docker run --rm -e DISPLAY=:0 -e LIBGL_ALWAYS_SOFTWARE=1 -e _JAVA_AWT_WM_NONREPARENTING=1 -v /tmp/.X11-unix:/tmp/.X11-unix -v /path/to/output/<variant>/gateware:/dcp:ro --entrypoint bash vivado-2024.2-env -c "source /tools/Xilinx/Vivado/2024.2/settings64.sh && vivado /dcp/top_route.dcp"
```

`LIBGL_ALWAYS_SOFTWARE=1` and `_JAVA_AWT_WM_NONREPARENTING=1` are required to prevent the Vivado window from rendering as a blank white screen under XWayland.

## Inspecting Routing in the GUI

Once the checkpoint opens:

- **Device view**: shows the physical floorplan with routing traces overlaid. Select any net in the Netlist panel and press **F4** to highlight its routing on the device.
- **Timing paths**: `Reports → Timing → Report Timing Summary`, then click any path to cross-probe to its routed net in the device view.
- **Schematic**: `Tools → Schematic` traces the logic between specific registers.

Useful TCL console commands:

```tcl
# Inter-clock timing — all cross-domain paths and their slack
report_clock_interaction -delay_type min_max

# Highlight specific nets (e.g. Urukul SPI/DDS paths)
highlight_objects -color blue [get_nets -hierarchical -filter {NAME =~ *urukul*}]

# Worst timing paths from/to a specific hierarchy
report_timing -from [get_cells -hierarchical -filter {NAME =~ *rtio*}] -max_paths 20

# All clock domains in the design
report_clock_networks
```

## Non-Deterministic Delays Not Caused by Routing

If the timing report shows a clean build, routing is not the cause. Non-deterministic frequency output behavior is more likely caused by:

- **RTIO timeline drift**: using `delay()` instead of `at_mu()` to schedule DDS updates causes latency to accumulate non-deterministically across the event queue.
- **Urukul SYNC calibration**: the AD9910/AD9912 `SYNC_IN` delay must be calibrated per board. Without this, frequency and phase updates land in unpredictable SYSCLK cycles.
- **SPI transaction timing**: DDS profile writes over SPI need adequate slack in the RTIO schedule or completion time varies.
