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
- [ ] Windows: talker and listener in two containers hear each other.
- [ ] macOS: `platform/mac.yaml` (XQuartz) is written but untested.

How the display works per OS: `HOST_OS` in `.env` picks `platform/<os>.yaml`,
which `compose.yaml` extends. See [Windows setup](#windows-setup).

- [ ] Decide: `.env` is committed with `HOST_OS=windows`, so every Linux
  checkout has to edit a tracked file. Option: commit `.env.example`, and
  gitignore `.env`.

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
- [ ] Check (Windows): `docker login`, `docker compose pull` (no build), and step
  1's checks pass (rviz2, plus talker/listener in two containers).

## 3. GPU for graphics

- [ ] Pass `/dev/dri` into the container and add the video/render groups.
- Check (Linux): rviz2's log no longer says `failed to load driver: radeonsi`.
- Check (Windows): find out what WSLg needs (`/dev/dxg` and `/usr/lib/wsl`
  instead of `/dev/dri`). Software rendering is acceptable if that turns out to
  be hard.

## 4. Robotont sources on the laptop

- [ ] Add `repos/jazzy.repos` (start from
  `_trash/robotont_containers_attempt1/repos/jazzy.repos`).
- [ ] Clone it into `ws/src` on the host (`vcs import`, run inside the container
  so the host needs no ROS tools).
- Check (both): `ws/src` holds the repos, and `git status` works in them from
  the host.

## 5. Build the workspace

- [ ] Dockerfile: add `ros-jazzy-ros-gz` and the rosdep dependencies. Push the
  new image.
- [ ] Run `colcon build` inside the container.
- [ ] Decide: `build/`, `install/` and `log/` are large and Nextcloud would sync
  them. Put them in Docker volumes, or exclude them from sync.
- Check (both): the build finishes with no failed packages.

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

1. `.env`: `HOST_OS=windows`.
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
- **Build output** (`build/`, `install/`, `log/`) must not land in the
  Nextcloud-synced folder.
- **Sources stay on the host**, never baked into the dev image. Otherwise a
  rebuild throws away branches and edits, and there's nothing to push.
- **Gazebo**: `ros-jazzy-ros-gz` isn't in desktop-full. `robotont_gazebo` needs
  `gz_planar_move` (sygism/gz_planar_move) and is on branch
  `jazzy-devel-sygis`.
- **Lyrical** needs a source patch (`scripts/patch_lyrical_compat.py`) and an
  `apt upgrade` of `ros-lyrical-*`. Full notes are in
  `_trash/robotont_containers_attempt1/docs/lyrical-testing.md`.
- **Windows checkouts** can turn scripts to CRLF. Add a `.gitattributes`
  pinning LF once we have shell scripts.
