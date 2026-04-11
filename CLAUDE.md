# AI Agent Instructions

This repository defines a Nix Flake for NixOS and Home Manager configurations based on the [Snowfall](https://snowfall.org/) framework.

## Critical Build Rule

Whenever you make any changes to the `*.nix` configurations in this repository, you **MUST** verify that the changes build correctly before concluding the task. Nix Flakes ignore untracked files by default, meaning you must sequence your git and build steps properly.

Please refer to the `.agents/workflows/verify-build.md` workflow for the exact steps to verify the build and ensure everything is correct. Run that workflow to validate your work!
