# Mobile Game Factory

A reusable and automation-focused mobile game production pipeline.

The goal of this project is to build a reusable Godot master game that can generate multiple mobile game variants using configuration files, generated assets, automated balancing, and build scripts.

## Goals

- Keep development cost near $0 during prototyping.
- Minimize manual work.
- Use one reusable game engine for multiple games.
- Keep gameplay values data-driven instead of hard-coded.
- Automate game generation, balancing, assets, and Android builds.
- Support rapid experimentation and mass production.

## Tech Stack

- Godot 4
- GDScript
- Python
- JSON configuration
- ComfyUI for local AI asset generation
- Git / GitHub

## Project Structure

```text
mobile-game-factory/
├── godot/
│   └── masterGame/
│
├── configs/
│   ├── games/
│   ├── enemies/
│   ├── weapons/
│   └── economy/
│
├── automation/
│   ├── generators/
│   ├── simulation/
│   ├── assets/
│   └── build/
│
├── assets/
│   ├── generated/
│   ├── shared/
│   └── raw/
│
├── templates/
├── builds/
│   └── android/
├── tests/
├── .gitignore
└── README.md