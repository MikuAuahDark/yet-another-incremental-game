import glob
import os.path
import pathlib
import shutil
import subprocess

import tqdm

from util import find_game_root

# configurable thing
INPUT_DIR = "assets/vectors"
OUTPUT_DIR = "assets/images/rasterized_vectors"
SCALE = 2  # SVG scale
# end configurable thing

magick = shutil.which("magick")
if magick is None:
    raise Exception("ImageMagick 7 is missing")

MAIN_DIR = find_game_root()


def main():
    assert magick is not None

    main_input_dir = MAIN_DIR / INPUT_DIR

    for path in tqdm.tqdm(
        glob.glob(os.path.join(main_input_dir, "**", "*.svg"), recursive=True)
    ):
        relpath = pathlib.Path(path).relative_to(main_input_dir).with_suffix(".png")
        output_path = MAIN_DIR / OUTPUT_DIR / relpath
        output_path.parent.mkdir(parents=True, exist_ok=True)

        tqdm.tqdm.write(f"{path} ", end="")
        p = subprocess.run(
            [
                magick,
                "-density",
                str(SCALE * 96),
                "-background",
                "none",
                path,
                "-background",
                "rgba(255,255,255,0)",
                "-flatten",
                output_path,
            ]
        )
        if p.returncode != 0:
            tqdm.tqdm.write("❌")
        else:
            tqdm.tqdm.write("✅")


if __name__ == "__main__":
    main()
