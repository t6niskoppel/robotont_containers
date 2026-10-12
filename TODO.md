# Plan

Plan for `robotont_containers/`: a laptop-side Docker setup for Robotont: run the
simulation on a laptop, and with the same setup talk to a physical robot. It does
not run on the robot itself.

We build it one small step at a time. A step is done when its check passes **on
both Linux and Windows**. Nothing gets added "for later". Nothing gets committed
except by Tõnis.

Old material, only on Tõnis's Linux laptop in `~/Nextcloud/Robotont/_trash/`:
- `robotont_containers_attempt1/`: the first attempt at this repo (too complex).
- `2026-10-12_old-workspaces/`: the earlier `jazzy/`, `lyrical/` and
  `robotont-dev/` workspaces. **`lyrical/src` holds uncommitted Lyrical fixes**
  in 12 robotont repos. Don't empty the trash before those are saved or pushed.

What we learned from them is under [Lessons](#lessons-from-attempt-1) below.

## 0. Clean slate

- [x] Move the first attempt and the old `jazzy/`, `lyrical/`, `robotont-dev/`
  workspaces to `_trash/`.
- [x] Add the minimal `compose.yaml` (one service, public image, no Dockerfile).
- [x] Add a `.gitignore`.
- [x] Check: `git status` shows only `compose.yaml` and `.gitignore` as new.
- [x] Move this TODO into the repo, so it travels between the Linux, Windows
  and Mac test machines.

## 1. Basic container: ROS, GUI, host network

```bash
docker compose run --rm ros bash
source /opt/ros/jazzy/setup.bash
rviz2
```

- [x] Linux: rviz2 opens a window (it uses software rendering because there's
  no GPU access yet).
- [x] Linux: a talker in one container is heard by a listener in another
  (`ros2 run demo_nodes_cpp talker` / `listener`).
- [x] Windows (Docker Desktop, WSL2 backend, host networking turned on): rviz2
  opens a window on the Windows desktop. Done by Tõnis on 2026-10-12.
- [x] Windows: talker and listener in two containers hear each other. Also
  with `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`, so it isn't only shared memory.
  Done by Claude on 2026-10-12.
- [ ] macOS: `platform/mac.yaml` (XQuartz) is written but untested.

How the display works per OS: `HOST_OS` in `.env` picks `platform/<os>.yaml`,
which `compose.yaml` extends. See [Windows setup](#windows-setup).

- [x] `.env` is no longer tracked: `.env.example` is the template, and each
  machine copies it to `.env` once. Pulling never overwrites local settings.

## 2. Our own image, on Docker Hub (private, for testing)

The image is `t6niskoppel/robotont-dev`, with one tag per ROS version (`jazzy`,
later `lyrical`). It's private: for testing on Windows, not for publishing.
Publishing comes later, probably to GHCR (see [Registry](#registry)).

- [x] Create `t6niskoppel/robotont-dev` as a **private** repo on Docker Hub
  (Tõnis).
- [x] Add a minimal `Dockerfile`: `ARG ROS_DISTRO=jazzy`,
  `FROM osrf/ros:${ROS_DISTRO}-desktop-full`, nothing else yet.
- [x] `compose.yaml`: `image: t6niskoppel/robotont-dev:${ROS_DISTRO:-jazzy}` plus
  a `build:` section, so the ROS version is chosen with `ROS_DISTRO` (in the
  shell or a `.env` file next to `compose.yaml`).
- [x] Linux: `docker compose build`, then `docker compose push`. `jazzy` pushed
  2026-10-12, amd64 only (Apple Silicon Macs would run it under emulation).
- [x] Check (Linux): step 1's checks still pass with our image.
- [x] Check (Windows): `docker login`, `docker compose pull` (no build), and step
  1's checks pass (rviz2, plus talker/listener in two containers). Done by
  Claude on 2026-10-12: the local image's digest matches Docker Hub's, and
  rviz2 maps its window on the WSLg display with no errors in its log.

## 3. GPU for graphics

- [x] Linux: `devices: [/dev/dri]` in `platform/linux.yaml`, and nothing else.
  No video/render group is needed, so there's no machine-specific GID. The
  container can't open `/dev/dri/renderD*` itself; the X server (Xwayland)
  opens the GPU and passes it over the X socket (DRI3). The container only has
  to see the device nodes. Done by Claude on 2026-10-12.
- [x] Check (Linux): rviz2 reports OpenGL 4.6 (was 4.5 with `llvmpipe`), and
  its log no longer says `failed to load driver: radeonsi`. This laptop has an
  AMD (`amdgpu`) and an NVIDIA GPU; Mesa uses the AMD one. The NVIDIA one would
  need the NVIDIA container toolkit, which we haven't tried.
- [ ] Watch at step 6: rendering *without* a window (Gazebo camera sensors,
  headless) may open `/dev/dri/renderD*` directly. That would need the render
  group after all.
- [x] Windows: hardware OpenGL through WSL's GPU layer, in
  `platform/windows.yaml`. Mesa's `d3d12` driver (already in our image, Mesa
  25.2) translates OpenGL to Direct3D 12, so it works with any GPU vendor that
  has a recent Windows driver. Done by Claude on 2026-10-12. Findings:
  - Docker Desktop's VM has both `/dev/dxg` and `/usr/lib/wsl/lib`
    (`libd3d12.so`, `libdxcore.so`, the GPU vendor's driver).
  - All three are needed: `GALLIUM_DRIVER=d3d12` (Mesa picks `llvmpipe`
    otherwise), `LD_LIBRARY_PATH=/usr/lib/wsl/lib`, and `/dev/dxg`. Works as
    the `ubuntu` user.
  - No automatic fallback: with `d3d12` forced and no `/dev/dxg`, rviz2 can't
    create an OpenGL context. Fallback is `GALLIUM_DRIVER=llvmpipe` in `.env`.
  - Speed (glmark2, 1280x940, RTX 3070): `d3d12` stays at ~100-130 FPS on
    every scene, capped by copying each frame to WSLg. `llvmpipe` is faster on
    light scenes but drops to 13-26 FPS on heavy ones (terrain, refract), and
    uses the CPU that the simulation needs. So `d3d12` is the default.
- [x] Check (Windows): `GL_RENDERER` is `D3D12 (NVIDIA GeForce RTX 3070)`, and
  rviz2 reports OpenGL 4.6 (4.5 with `llvmpipe`). `glxinfo` isn't in the image
  (`mesa-utils`); the check used a throwaway container.
- [ ] **Windows hardware graphics needs more work and testing.** It works on
  one machine (RTX 3070), only rviz2 and glmark2 were tried, and it's on by
  default for every Windows user. Still to do:
  - Test on Windows machines with an Intel/AMD GPU, and without a GPU (D3D12
    should then use WARP, Microsoft's software renderer).
  - Test real workloads: rviz2 with robot models and sensor data, and Gazebo
    (step 6). Compare against `llvmpipe` for speed and correctness.
  - Look into the ~100-130 FPS cap from copying frames to WSLg, and whether
    rendering is correct in that copy mode.
  - Decide whether `d3d12` stays the default, given there's no automatic
    fallback.

## 4. Robotont sources on the laptop

```bash
docker compose run --rm ros vcs import --input /repos/jazzy.repos src
```

- [x] `repos/jazzy.repos` lists only what the simulation needs: `robotont_msgs`,
  `robotont_description`, `robotont_nuc_description`, `robotont_driver` (fake
  driver), `robotont_gazebo` (branch `jazzy-devel-sygis`) and `gz_planar_move`
  (its URDF loads the plugin). Found from the package.xml dependencies.
  Navigation, demos, lidar and `robotont_lite_description` get added when a
  step needs them.
- [x] `compose.yaml` mounts `./ws` at `/ws` (the working directory) and `./repos`
  read-only at `/repos`. `ws/src/.gitkeep` is committed because `vcs import`
  won't create `src` itself; the clones in `ws/src` are gitignored.
- [x] Check (Linux): six repos in `ws/src` on the right branches, owned by the
  host user, `git status` clean from the host. Done by Claude on 2026-10-12.
- [ ] Check (Windows): the same command. Watch for:
  - Windows git calling every file modified: line endings (`core.autocrlf`).
  - Windows git refusing with "dubious ownership" (`safe.directory`).
  - The clone being slow on a Windows-folder bind mount.
- [ ] Open question for step 6: `robotont_description`, `_nuc_description` and
  `_driver` also have `jazzy-devel-sygis` branches, like `robotont_gazebo`. We
  use plain `jazzy`, as the old workspace did. Switch if Gazebo needs them.

## 5. Build the workspace

```bash
docker compose pull      # or: docker compose build
docker compose run --rm ros colcon build --symlink-install
```

- [x] Dockerfile installs what `rosdep install --from-paths src --ignore-src -s`
  reported: `libasio-dev`, `asio-cmake-module`, `io-context`,
  `joint-state-publisher`, `realsense2-description`, `serial-driver`. Gazebo
  (`gz-sim-vendor`, `ros-gz-sim`, `ros-gz-bridge`, ...) is already in
  desktop-full. `gz-transport13` (from `gz_planar_move`) has no rosdep key but
  comes with the Gazebo vendor packages. Pushed to Docker Hub 2026-10-12.
- [x] Build output stays in `ws/build`, `ws/install`, `ws/log` on the host
  (gitignored). Nextcloud syncing it is fine (Tõnis).
- [x] Check (Linux): all 6 packages build (~35 s); `rosdep check` is satisfied
  except the known `gz-transport13` key. Done by Claude on 2026-10-12.
- [ ] Check (Windows): `docker compose pull`, then the same build.

## 6. Simulation on the laptop

- [ ] `ros2 launch robotont_gazebo gazebo.launch.py`
- Check (both): the robot appears in Gazebo, and teleop drives it.

## 7. Physical robot, same setup

- [ ] Set `ROS_DOMAIN_ID` to the robot's number (robotont-N means domain N).
- Check (Linux): `ros2 topic list` shows the robot's topics, and teleop from the
  laptop moves the real robot.
- Check (Windows): the same. Expect network trouble; see
  [Windows setup](#windows-setup).

## 8. README

- [ ] A short "how to run" for Linux and Windows, covering only the commands
  that worked above.

## Later, only if needed

Lyrical (a second image tag), a VS Code devcontainer, a `robot.env` config file,
publishing to GHCR.

---

## Windows setup

What worked (Tõnis, 2026-10-12): Docker Desktop with the WSL2 backend, started
from Windows.

1. Copy `.env.example` to `.env` (`HOST_OS=windows` is already set there).
2. Docker Desktop → Settings → Resources → Network → *Enable host networking*,
   then restart Docker Desktop (needs version 4.34 or later).
3. GUI goes through WSLg. Two things make it work, both in the repo:
   - `platform/windows.yaml` mounts `/run/desktop/mnt/host/wslg/.X11-unix`.
     That's the WSLg socket as seen from Docker Desktop's VM; `/tmp/.X11-unix`
     there is the wrong one. It sets `DISPLAY=:0` and needs no X cookie.
   - `QT_X11_NO_MITSHM=1` in `compose.yaml`. X shared memory doesn't cross the
     VM boundary, and without it rviz2's window stays blank.

Not tested yet:
- Cloning inside WSL and running Docker from there.
- File ownership in a bind-mounted `ws/` (step 4). The container user is uid
  1000.
- Talking to a real robot. DDS finds the robot by multicast; the Windows
  firewall may need to allow UDP for DDS.

## Registry

- **Now:** Docker Hub, `t6niskoppel/robotont-dev`, private, pushed by hand from
  Linux. Only for testing on Windows.
- **Later:** publish publicly, probably on GHCR, built by a GitHub Action.
  robotont-management already plans `ghcr.io/robotont/robotont-ros` for the
  robot side. Decide together before anything is public.

## Lessons from attempt 1

Keep these in mind; add each one only when a step needs it.

- **X11 on this Wayland host.** With `network_mode: host` the container has the
  host's hostname, so mounting `$XAUTHORITY` is enough. Without host networking,
  the cookie is bound to the hostname. You then need a wildcarded copy
  (`xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f <file> nmerge -`).
- **User ID.** The container runs as `ubuntu` (uid 1000). This matches the host
  user on this laptop and usually in WSL. A different uid breaks X11 access and
  makes files in the bind-mounted `ws/` owned by the wrong user.
- **Shared memory.** `network_mode: host` does not share `/dev/shm`. Fast DDS
  needs `ipc: host` to talk to other containers or the host.
- **Fast DDS between a root container and a user process** fails over shared
  memory. If discovery fails, set `FASTDDS_BUILTIN_TRANSPORTS=UDPv4`. The
  robotont-management repo does this.
- **Domain ID**: robot N is on `ROS_DOMAIN_ID=N`. Keep it at or below 101,
  because higher values collide with Linux's ephemeral port range. On a
  Robotont 3 Lite the namespace is `rtN`.
- **Sources stay on the host**, never baked into the dev image. Otherwise a
  rebuild throws away branches and edits, and there's nothing to push.
- **Gazebo**: its parts are in desktop-full (not the `ros-gz` metapackage).
  `robotont_gazebo` needs
  `gz_planar_move` (sygism/gz_planar_move) and is on branch
  `jazzy-devel-sygis`.
- **Lyrical** needs a source patch (`scripts/patch_lyrical_compat.py`) and an
  `apt upgrade` of `ros-lyrical-*`. Full notes are in
  `_trash/robotont_containers_attempt1/docs/lyrical-testing.md`.
- **Windows checkouts** can turn scripts to CRLF. Add a `.gitattributes`
  pinning LF once we have shell scripts.
