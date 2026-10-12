ARG ROS_DISTRO=jazzy
FROM osrf/ros:${ROS_DISTRO}-desktop-full
ARG ROS_DISTRO

# What the sources in repos/<distro>.repos need beyond desktop-full, from
# `rosdep install --from-paths src --ignore-src -s`. Gazebo itself is already in desktop-full.
RUN apt-get update && apt-get install -y --no-install-recommends \
        libasio-dev \
        ros-${ROS_DISTRO}-asio-cmake-module \
        ros-${ROS_DISTRO}-io-context \
        ros-${ROS_DISTRO}-joint-state-publisher \
        ros-${ROS_DISTRO}-realsense2-description \
        ros-${ROS_DISTRO}-serial-driver \
    && rm -rf /var/lib/apt/lists/*
