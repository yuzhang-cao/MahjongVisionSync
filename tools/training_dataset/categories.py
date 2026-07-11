"""Stable visual semantic classes for MahjongVisionSync training datasets."""

BASE_34_CLASSES = [
    {"id": 0, "code": "man_1", "label": "1 Man"},
    {"id": 1, "code": "man_2", "label": "2 Man"},
    {"id": 2, "code": "man_3", "label": "3 Man"},
    {"id": 3, "code": "man_4", "label": "4 Man"},
    {"id": 4, "code": "man_5", "label": "5 Man"},
    {"id": 5, "code": "man_6", "label": "6 Man"},
    {"id": 6, "code": "man_7", "label": "7 Man"},
    {"id": 7, "code": "man_8", "label": "8 Man"},
    {"id": 8, "code": "man_9", "label": "9 Man"},
    {"id": 9, "code": "pin_1", "label": "1 Pin"},
    {"id": 10, "code": "pin_2", "label": "2 Pin"},
    {"id": 11, "code": "pin_3", "label": "3 Pin"},
    {"id": 12, "code": "pin_4", "label": "4 Pin"},
    {"id": 13, "code": "pin_5", "label": "5 Pin"},
    {"id": 14, "code": "pin_6", "label": "6 Pin"},
    {"id": 15, "code": "pin_7", "label": "7 Pin"},
    {"id": 16, "code": "pin_8", "label": "8 Pin"},
    {"id": 17, "code": "pin_9", "label": "9 Pin"},
    {"id": 18, "code": "sou_1", "label": "1 Sou"},
    {"id": 19, "code": "sou_2", "label": "2 Sou"},
    {"id": 20, "code": "sou_3", "label": "3 Sou"},
    {"id": 21, "code": "sou_4", "label": "4 Sou"},
    {"id": 22, "code": "sou_5", "label": "5 Sou"},
    {"id": 23, "code": "sou_6", "label": "6 Sou"},
    {"id": 24, "code": "sou_7", "label": "7 Sou"},
    {"id": 25, "code": "sou_8", "label": "8 Sou"},
    {"id": 26, "code": "sou_9", "label": "9 Sou"},
    {"id": 27, "code": "east", "label": "East Wind"},
    {"id": 28, "code": "south", "label": "South Wind"},
    {"id": 29, "code": "west", "label": "West Wind"},
    {"id": 30, "code": "north", "label": "North Wind"},
    {"id": 31, "code": "white", "label": "White Dragon"},
    {"id": 32, "code": "green", "label": "Green Dragon"},
    {"id": 33, "code": "red", "label": "Red Dragon"},
]

MCR_FLOWER_CLASSES = [
    {"id": 34, "code": "spring", "label": "Spring"},
    {"id": 35, "code": "summer", "label": "Summer"},
    {"id": 36, "code": "autumn", "label": "Autumn"},
    {"id": 37, "code": "winter", "label": "Winter"},
    {"id": 38, "code": "plum", "label": "Plum"},
    {"id": 39, "code": "orchid", "label": "Orchid"},
    {"id": 40, "code": "bamboo", "label": "Bamboo"},
    {"id": 41, "code": "chrysanthemum", "label": "Chrysanthemum"},
]

RIICHI_RED_FIVE_CLASSES = [
    {"id": 34, "code": "red_five_man", "label": "Red 5 Man"},
    {"id": 35, "code": "red_five_pin", "label": "Red 5 Pin"},
    {"id": 36, "code": "red_five_sou", "label": "Red 5 Sou"},
]

MCR_CLASSES = BASE_34_CLASSES + MCR_FLOWER_CLASSES
RIICHI_MLEAGUE_CLASSES = BASE_34_CLASSES + RIICHI_RED_FIVE_CLASSES

RULES_PROFILES = {
    "mcr": {
        "visual_domain": "mcr",
        "tile_set_id": "mcr_144_42",
        "class_count": 42,
        "classes": MCR_CLASSES,
    },
    "riichi_mleague": {
        "visual_domain": "riichi_mleague",
        "tile_set_id": "riichi_mleague_136_37",
        "class_count": 37,
        "classes": RIICHI_MLEAGUE_CLASSES,
    },
}


def class_codes(rules_profile):
    return {item["code"] for item in RULES_PROFILES[rules_profile]["classes"]}


def class_by_id(rules_profile):
    return {item["id"]: item for item in RULES_PROFILES[rules_profile]["classes"]}


def class_by_code(rules_profile):
    return {item["code"]: item for item in RULES_PROFILES[rules_profile]["classes"]}
