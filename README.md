# robotont-containers
Docker containers for robotont development

The repo has containers for running ROS2 jazzy and ROS2 lyrical robotont stack. 

## Setup

Machine-specific settings live in [`.env`](.env). Set `HOST_OS` to your operating system:

```sh
HOST_OS=linux     # or windows, mac
```

This picks the matching display settings from `platform/`.

### Linux

Set `HOST_OS=linux`. The container uses your `DISPLAY` and `XAUTHORITY`.

### Windows (Docker Desktop)

1. Set `HOST_OS=windows`.
2. **Enable host networking** (required): Docker Desktop → Settings → Resources → Network →
   *Enable host networking*, then restart Docker Desktop. Without it ROS 2 can't discover the
   robot or other nodes on the network.
3. Make sure Docker Desktop uses the WSL 2 backend (the default); GUI apps are shown via WSLg.

### macOS (Docker Desktop)

1. Set `HOST_OS=mac`.
2. Enable host networking in Docker Desktop as on Windows.
3. Install [XQuartz](https://www.xquartz.org/), open its Settings → Security and enable
   *Allow connections from network clients*, then log out and back in.
4. Run `xhost +localhost` (again after every XQuartz restart).

## Usage

Open a shell in a fresh container:

```sh
docker compose run --rm ros
```

Or keep a container running in the background (this is also what Docker Desktop and
VS Code's *Compose Up* do) and open shells into it, e.g. from Docker Desktop's *Exec* tab:

```sh
docker compose up -d
docker compose exec ros bash
docker compose down
```

GUI tools like `rviz2` open on your desktop.
