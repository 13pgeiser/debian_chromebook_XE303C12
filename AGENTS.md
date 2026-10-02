# AGENTS.md

Builds a Debian armhf (32-bit ARM) OS image for a Samsung ARM Chromebook XE303C12 (Exynos 5250) via Docker + QEMU binfmt + debootstrap. Shell + Make only — no package manager, no test suite. Heavily based on Kali's ARM build scripts.

## Layout

- `scripts/docker_build.sh` — build entrypoint (also the `.buildbot` command). Takes **no arguments**; always builds trixie.
- `scripts/build.sh` — runs **inside** the privileged container: fetches TI firmwares, cross-compiles the kernel (armhf, linux-source-6.12), debootstraps the rootfs, packages `xe303c12.zip` + kernel .debs into `release/`. Fails early if the container base is not trixie.
- `scripts/Dockerfile.trixie` — the real Dockerfile. `scripts/Dockerfile` is **generated** (copied by `docker_build.sh`, gitignored) — never edit it directly; edit `Dockerfile.trixie`.
- `scripts/install.sh` — target-side script (wipes a disk and installs the image); also the user-facing USB-prep script. Copied verbatim into the package by `build.sh`.
- `configs/6.12` — kernel `.config` for the trixie build, consumed by `build.sh` via `cp /configs/$version ./.config` (version = major.minor of the kernel).

## Commands

- `make check` — the only "verification": `shfmt -d` + `shellcheck` on `build.sh`, `docker_build.sh`, `install.sh` (runs in Docker).
- `make format` — autofix with `shfmt -w`.
- `make run` — full image build. **The Makefile swallows build failures (`|| true`)**: to confirm success, check that `release/xe303c12.zip` and the kernel .debs exist, or run `bash scripts/docker_build.sh` directly for a real exit code.
- `make` = `check` + `run`.

## Build requirements & gotchas

- Docker required. The container runs `--privileged` with a 16 GB memory cap and needs `binfmt_misc` for transparent armhf execution. Builds are long.
- `docker_build.sh` runs `docker system prune -f -a` — it wipes all unused Docker images on the host. Don't run it casually on a machine with other work.
- Needs network: downloads `linux-source-6.12`, debootstraps the rootfs; device firmware comes from the apt `firmware-*` packages installed in the third stage (no manual firmware fetching — the old `git.ti.com` download step was removed: those AM335x/AM43x files are for TI Sitara boards, not this Exynos 5250 Chromebook).
- Only trixie is supported; the release↔kernel coupling is hardcoded in three places if you ever add one: a `Dockerfile.<codename>` (matching `linux-source-<kernel>`), the release guard / kernel extraction / apt sources in `build.sh`, and a `configs/<major>.<minor>` kernel config.
- The 6.12 kernel tree puts DTBs under `arch/arm/boot/dts/samsung/` (handled in `build.sh`).
- `release/` is gitignored. CI (`.github/workflows/publish.yml`) triggers on **tag push**, runs `make check` then `make run`, uploads `release/*` as release artifacts.
- Resulting image's default credentials: `root` / `toor` (set in `build.sh`, documented in `Readme.rst`).
