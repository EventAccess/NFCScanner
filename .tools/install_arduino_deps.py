import os
import sys
from pathlib import Path
import subprocess
from typing import TypeAlias, cast

import yaml

#####

HERE = Path(os.path.realpath(os.path.dirname(sys.argv[0])))
CONFIG_FILE = HERE / ".." / "arduino-meta.yaml"

#####

StrPath: TypeAlias = str | os.PathLike


def arduino_cli(*cmd):
    print(">>> ", *cmd)
    return subprocess.run(["arduino-cli", *cmd])


def enable_git():
    return arduino_cli("config", "set", "library.enable_unsafe_install", "true")


def update_library_index():
    return arduino_cli("lib", "update-index")


def install_library(name, version):
    return arduino_cli("lib", "install", f"{name}@{version}")


def install_library_git(url):
    return arduino_cli("lib", "install", "--git-url", url)


def install_core(name, version):
    return arduino_cli("core", "install", f"{name}@{version}")


def add_board_reposity(url):
    return arduino_cli("config", "add", "board_manager.additional_urls", url)


def load_config(path: StrPath | None = None) -> dict:
    path = path or CONFIG_FILE
    with open(path, "rt", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def main():
    conf = load_config()

    enable_git()
    update_library_index()

    for core in conf.get("cores", []):
        core = cast(dict[str, str], core)
        if "repository" in core:
            add_board_reposity(core.get("repository"))
        install_core(core["id"], core["version"])

    for lib in conf.get("libraries", []):
        lib = cast(dict[str, str], lib)
        source = lib.get("source", "arduino")
        if source == "git":
            url = lib.get("url")
            digest = lib.get("digest")
            install_library_git(f"{url}#{digest}")
        if source == "arduino":
            install_library(lib.get("name"), lib.get("version"))


if __name__ == "__main__":
    main()
