import mimetypes
import os
import sys
import tarfile
import tempfile
import zipfile
from os import PathLike
from pathlib import Path
from typing import IO, Literal, TypeAlias, cast

import requests

import yaml

#####

XDG_BIN_HOME = Path(os.environ.get("XDG_BIN_HOME", os.path.expanduser("~/.local/bin")))

HERE = Path(os.path.realpath(os.path.dirname(sys.argv[0])))
CONFIG_FILE = HERE / "tools.yaml"

#####

StrPath: TypeAlias = str | PathLike


class ArchiveItem:
    _item: zipfile.ZipInfo | tarfile.TarInfo

    def __init__(self, item):
        self._item = item

    @property
    def size(self) -> int:
        if isinstance(self._item, zipfile.ZipInfo):
            return self._item.file_size
        elif isinstance(self._item, tarfile.TarInfo):
            return self._item.size

        raise NotImplementedError

    @property
    def name(self) -> str:
        if isinstance(self._item, zipfile.ZipInfo):
            return self._item.filename
        elif isinstance(self._item, tarfile.TarInfo):
            return self._item.name

        raise NotImplementedError

    @property
    def mode(self) -> int | None:
        if isinstance(self._item, zipfile.ZipInfo):
            return None
        elif isinstance(self._item, tarfile.TarInfo):
            return self._item.mode

        raise NotImplementedError


class Archive:
    _archive: zipfile.ZipFile | tarfile.TarFile

    def __init__(self, file: StrPath | IO[bytes]):
        if isinstance(file, StrPath):
            file_handle: IO[bytes] = open(file, "rb")
        else:
            file_handle = file

        if tarfile.is_tarfile(file_handle):
            file_handle.seek(0)
            self._archive = tarfile.open(fileobj=file_handle)
            return

        if zipfile.is_zipfile(file_handle):
            file_handle.seek(0)
            self._archive = zipfile.ZipFile(file_handle)
            return

        raise ValueError("Not a recognized archive type")

    def __enter__(self, *args, **kwargs):
        self._archive.__enter__(*args, **kwargs)
        return self

    def __exit__(self, *args, **kwargs):
        self._archive.__exit__(*args, **kwargs)

    @property
    def members(self):
        if isinstance(self._archive, zipfile.ZipFile):
            return [ArchiveItem(x) for x in self._archive.infolist()]

        if isinstance(self._archive, tarfile.TarFile):
            return [ArchiveItem(x) for x in self._archive.getmembers()]

        raise NotImplementedError

    def open(self, name: str):
        if isinstance(self._archive, zipfile.ZipFile):
            return self._archive.open(name)

        if isinstance(self._archive, tarfile.TarFile):
            return self._archive.extractfile(name)

        raise NotImplementedError


#####


def _url_guess_mime(url) -> str | None:
    type, encoding = mimetypes.guess_type(url)

    if type:
        return type

    if encoding == "gzip":
        return "application/gzip"

    if "#" in url:
        return _url_guess_mime(url.split("#", 1)[0])

    if "?" in url:
        return _url_guess_mime(url.split("?", 1)[0])

    return None


def url_guess_mime(url: str) -> str | None:
    type = _url_guess_mime(url)
    if type:
        return type
    return None


def load_config(path: StrPath | None = None):
    path = path or CONFIG_FILE
    with open(path, "rt", encoding="utf-8") as fh:
        return yaml.safe_load(fh)


def download(
    url: str,
    output: StrPath | IO[bytes],
    mode: Literal["w+b", "wb"] = "w+b",
    return_handle=False,
) -> IO[bytes] | None:
    if mode not in ("w+b", "wb"):
        raise ValueError("mode must be of a writable binary type")

    fh = None
    if not isinstance(output, StrPath):
        fh = output

    try:
        if fh is None:
            fh = open(cast(StrPath, output), mode)
        print(f"Downloading {url} to {fh.name}")

        req = requests.get(url, stream=True, allow_redirects=True)
        req.raise_for_status()
        for chunk in req.iter_content(4096):
            fh.write(chunk)

    except Exception:
        if isinstance(output, StrPath) and fh:
            try:
                fh.close()
            except Exception:
                pass
        raise

    if return_handle:
        return fh
    else:
        return None


def main() -> None:
    os.makedirs(XDG_BIN_HOME, exist_ok=True)

    conf = load_config()

    for tool in conf.get("tools", []):
        tool_name = tool.get("name")
        tool_version = tool.get("version")
        print(f"Installing {tool_name} version {tool_version}")

        tool_url = tool.get("url_pattern").format(**tool)

        with tempfile.TemporaryDirectory() as tmp_dir:
            download_path = Path(tmp_dir) / "download"

            download_fh = download(tool_url, download_path, return_handle=True)

            if download_fh is None:
                raise Exception("Download failed")

            with Archive(download_fh) as archive:
                print("Files in archive:")
                for file in archive.members:
                    print(file.name)

                exe_fn = tool.get("executable")
                print(f"Extracting {exe_fn} to {XDG_BIN_HOME}/{exe_fn}")

                exe_fh = archive.open(exe_fn)

                with open(XDG_BIN_HOME / exe_fn, "wb") as ofh:
                    os.chmod(ofh.fileno(), 0o755)

                    while chunk := exe_fh.read(10240):
                        ofh.write(chunk)


if __name__ == "__main__":
    main()
