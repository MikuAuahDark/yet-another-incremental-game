import json
import traceback

import pydantic

from util import find_game_root

from typing import Annotated

# configurable thing
TARGET_DIR = "assets/prestiges"
# end configurable thing

MAIN_DIR = find_game_root()


def empty_list_is_empty_dict(v):
    if isinstance(v, list) and len(v) == 0:
        return {}
    return v


class Bundle(pydantic.BaseModel):
    money: float | None = None


class Upgrade(pydantic.BaseModel):
    id: str
    level: int
    startLevel: int | None = None
    basePrice: Annotated[Bundle, pydantic.BeforeValidator(empty_list_is_empty_dict)]
    x: int
    y: int
    isRoot: bool | None = None
    maxLevelOverride: int | None = None
    connections: list[int] | None = None
    cps: float | None = None
    priceScaling: float | None = None


class Tree(pydantic.BaseModel):
    upgrades: dict[int, Upgrade]
    connections: list[tuple[int, int]]
    unboundUpgrades: list[Upgrade]


def main():
    target_path = MAIN_DIR / TARGET_DIR

    for json_path in target_path.glob("*.json"):
        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = Tree.model_validate_json(f.read())
        except pydantic.ValidationError as e:
            traceback.print_exception(e)
            continue

        # Sort
        temp_upgrades = sorted(data.upgrades.items(), key=lambda x: x[0])
        data.upgrades = dict(temp_upgrades)
        data.connections = sorted(data.connections)

        with open(json_path, "w", encoding="utf-8", newline="") as f:
            json.dump(data.model_dump(mode="python"), f, indent="\t")

        print(f"Sorted {json_path.name}")


if __name__ == "__main__":
    main()
