#!/usr/bin/env python3
"""Inventory of class-related artwork in the WoW Forever client (build in classart_lib.BUILD).

Every asset is checked against the build's CASC via wago.tools (file really downloadable = in Forever).
Writes inventory.csv and previews/<family>.jpg contact sheets.

usage: python3 build_inventory.py            (all families)
       python3 build_inventory.py talent_bg  (only families whose key contains the term)
"""
import csv
import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

import classart_lib as L

HERE = os.path.dirname(os.path.abspath(__file__))
PREV = os.path.join(HERE, "previews")
SHEET_W = 600
BG = (17, 17, 18)
FG = (200, 198, 190)
DIM = (120, 120, 120)

CLASSES = L.CLASSES
ALL = CLASSES + L.RETAIL_CLASSES
TCOORDS = {  # CLASS_ICON_TCOORDS (Blizzard_SharedXML/SharedConstants.lua)
    "warrior": (0, 0.25, 0, 0.25), "mage": (0.25, 0.49609375, 0, 0.25), "rogue": (0.49609375, 0.7421875, 0, 0.25),
    "druid": (0.7421875, 0.98828125, 0, 0.25), "hunter": (0, 0.25, 0.25, 0.5), "shaman": (0.25, 0.49609375, 0.25, 0.5),
    "priest": (0.49609375, 0.7421875, 0.25, 0.5), "warlock": (0.7421875, 0.98828125, 0.25, 0.5),
    "paladin": (0, 0.25, 0.5, 0.75), "deathknight": (0.25, .5, 0.5, .75), "monk": (0.5, 0.73828125, 0.5, .75),
    "demonhunter": (0.7421875, 0.98828125, 0.5, 0.75), "evoker": (0, 0.25, 0.75, 1),
}
# Classic talent trees in Forever (TalentTab.BackgroundFile), order = OrderIndex
TREES = {}


def font(size):
    return L.font(size)


# --- item helpers ------------------------------------------------------------------------------

def A(cls, variant, name):
    return dict(cls=cls, variant=variant, kind="atlas", ref=name.lower())


def F(cls, variant, fdid_or_path, crop=None):
    fdid = fdid_or_path if isinstance(fdid_or_path, int) else L.fdid_of(fdid_or_path)
    return dict(cls=cls, variant=variant, kind="file", ref=fdid, crop=crop,
                path=fdid_or_path if isinstance(fdid_or_path, str) else None)


def Q(cls, variant, base):
    """classic talent background: 4 quadrants <base>-TopLeft/TopRight/BottomLeft/BottomRight"""
    parts = [L.fdid_of(f"Interface/TalentFrame/{base}-{p}") for p in ("TopLeft", "TopRight", "BottomLeft", "BottomRight")]
    return dict(cls=cls, variant=variant, kind="quad", ref=parts, path=f"Interface/TalentFrame/{base}-*")


def atlas_family(pattern, classes=ALL):
    """all atlases matching a regex with a <C> placeholder for the class token; variant = rest"""
    out = []
    rx = re.compile("^" + pattern.replace("<C>", "(?P<c>" + "|".join(classes) + ")").replace("<V>", "(?P<v>.+?)") + "$")
    for name in sorted(L.atlases()):
        m = rx.match(name)
        if m:
            out.append(A(m.group("c"), m.groupdict().get("v") or "", name))
    return out


def trees():
    if not TREES:
        mask = {1: "warrior", 2: "paladin", 4: "hunter", 8: "rogue", 16: "priest", 64: "shaman", 128: "mage",
                256: "warlock", 1024: "druid"}
        rows = sorted(L.db2("TalentTab"), key=lambda r: int(r["OrderIndex"]))
        for r in rows:
            c = mask.get(int(r["ClassMask"]))
            if c:
                TREES.setdefault(c, []).append((r["Name_lang"], r["BackgroundFile"], int(r["SpellIconID"])))
    return TREES


def class_icon_ids():
    by = {r["Filename"].lower(): int(r["IconFileDataID"]) for r in L.db2("ChrClasses")}
    return by


# --- families ----------------------------------------------------------------------------------
# key, title, fit (good / ok darkened / poor), why, blizzard usage, collect()

FAMILIES = [
    dict(key="crest_classicon", title="Klassen-Icon (Atlas classicon-<class>)", fit="good",
         why="Square class icon art (Blizzard masks it round where needed); reads well at 16-64 px on a dark flat panel.",
         usage="GetClassAtlas() in SharedConstants.lua; damage meter, commentator, many retail lists",
         collect=lambda: atlas_family("classicon-<C>")),
    dict(key="crest_iconfile", title="Klassen-Icons als Datei (Interface/Icons/ClassIcon_<class>)", fit="good",
         why="Square spell-style icon, same look as action buttons; crop 8% and add a 1-px border like all mUI icons.",
         usage="ChrClasses.IconFileDataID / ChrSpecialization icon (Forever has one pseudo-spec per class)",
         collect=lambda: [F(c, "", fid) for c, fid in class_icon_ids().items() if c in ALL] +
         [F(c, "", f"Interface/Icons/ClassIcon_{c}") for c in L.RETAIL_CLASSES if c not in class_icon_ids()]),
    dict(key="crest_circles", title="Klassische Klassen-Kreise (UI-Classes-Circles)", fit="ok darkened",
         why="Vanilla-era round icons with a baked gold ring; ring clashes a bit with the 1-px look.",
         usage="Interface/TargetingFrame/UI-Classes-Circles via CLASS_ICON_TCOORDS (arena frames, PortraitFrame)",
         collect=lambda: [F(c, "", 237669, TCOORDS[c]) for c in ALL]),
    dict(key="crest_charcreate", title="Klassen-Icons Charaktererstellung alt (UI-CharacterCreate-Classes)", fit="good",
         why="Square, borderless classic icons; the most 'Classic' looking set and tiny in memory.",
         usage="Interface/Glues/CharacterCreate/UI-CharacterCreate-Classes (raid UI, guild member list, calendar)",
         collect=lambda: [F(c, "", 131146, TCOORDS[c]) for c in ALL]),
    dict(key="crest_worldstate", title="Klassen-Icons Schlachtfeld-Tabelle (Icons-Classes)", fit="ok darkened",
         why="Small flat icons for score tables; low detail, fine at 16 px only.",
         usage="Interface/WorldStateFrame/Icons-Classes (PVPMatchTable.lua)",
         collect=lambda: [F(c, "", 137221, TCOORDS[c]) for c in ALL]),
    dict(key="crest_groupfinder", title="Gruppensuche-Klassensymbole (groupfinder-icon-class-*)", fit="good",
         why="Round class icons with a thin class-colored ring (29 px), a plain class-colored disc (-color-) and the smaller Forever restyle (-c60, 22 px) - ideal inline in lists and text.",
         usage="Blizzard_GroupFinder_VanillaStyle (LFG browse) and LFGList.lua; -c60 used by the Forever group finder",
         collect=lambda: atlas_family("groupfinder-icon-class-<C>") + atlas_family("groupfinder-icon-class-color-<C>") +
         atlas_family("groupfinder-icon-class-<C>-c60")),
    dict(key="crest_portrait", title="Spieler-Portrait-Klassenicon (ui-hud-unitframe-player-portrait-classicon-*)", fit="good",
         why="Round, high-res (120 px) class icon meant to sit inside a portrait circle; good as a small crest on the player frame.",
         usage="Atlas exists (portrait class icon option of the retail HUD); not referenced in the Forever Lua",
         collect=lambda: atlas_family("ui-hud-unitframe-player-portrait-classicon-<C>-2x")),
    dict(key="crest_classhall", title="Ordenshallen-Wappen (classhall-circle-*)", fit="ok darkened",
         why="Ornate round crest with baked ring - strong 'class moment', too busy for small sizes.",
         usage="Blizzard_OrderHallMissionUI (Legion order hall); no Forever usage",
         collect=lambda: atlas_family("classhall-circle-<C>")),
    dict(key="crest_classtrial", title="Klassen-Ring Klassentest (classtrial-*-ring)", fit="ok darkened",
         why="Big (188 px) ringed emblem with glow; nice for one splash/welcome moment, too loud elsewhere.",
         usage="Blizzard_ClassTrial (class trial thanks frame)",
         collect=lambda: atlas_family("classtrial-<C>-ring")),
    dict(key="crest_garrmission", title="Missions-Klassenicons (garrmission_classicon-*)", fit="good",
         why="Rounded-square class and spec icons without a heavy frame; the only icon set that has one icon per classic tree name (arms, fury, holy ...).",
         usage="Garrison/Order hall follower UI (retail systems, not active in Forever)",
         collect=lambda: atlas_family("garrmission_classicon-<C>") + atlas_family("garrmission_classicon-<C>-<V>")),
    dict(key="crest_microbutton", title="Alte Mikromenü-Klassenknöpfe (ui-microbutton-*)", fit="poor",
         why="Button art with bevel and pressed states from Cataclysm; doesn't fit the flat look.",
         usage="Interface/Buttons/UI-MicroButton-<Class> (old talent micro button)",
         collect=lambda: [F(c, "", f"Interface/Buttons/UI-MicroButton-{c}") for c in CLASSES]),

    dict(key="talent_bg_forever", title="Forever-Talenthintergrund pro Klasse (talent-background-<class>)", fit="ok darkened",
         why="Panorama with three zones (one per tree); already used by mUI dimmed to 50% - works only darkened.",
         usage="Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentUtil.lua (Forever talent frame); mUI Talents/Talents.lua",
         collect=lambda: atlas_family("talent-background-<C>")),
    dict(key="talent_bg_classic", title="Klassische Talentbaum-Hintergründe (Interface/TalentFrame/<Klasse><Baum>)", fit="ok darkened",
         why="Original 2004 tree paintings (one per tree, 27 total); soft and dark, perfect per-tree accent at 30-40% brightness.",
         usage="Classic/Cata TalentFrameBase.lua via TalentTab.BackgroundFile; Forever TalentTab still lists them",
         collect=lambda: [Q(c, n, b) for c in CLASSES for n, b, _ in trees().get(c, [])]),
    dict(key="talent_bg_cata", title="Cataclysm-Spezialisierungsbilder (Interface/TalentFrame/bg-<class>-<spec>)", fit="ok darkened",
         why="Painted spec scenes, brighter and busier than the classic ones; needs strong darkening.",
         usage="Cataclysm talent frame spec pane; no Forever usage",
         collect=lambda: [F(c, re.sub(r".*bg-[a-z]+-", "", p)[:-4], fid) for fid, p in sorted(L.file_search("interface/talentframe/bg-").items(), key=lambda x: x[1])
                          for c in [re.match(r".*bg-([a-z]+)-", p).group(1)] if c in ALL]),
    dict(key="talent_bg_df", title="Retail-Talenthintergründe pro Spec (talents-background-<class>-<spec>)", fit="ok darkened",
         why="Wide spec paintings (1612x774) from Dragonflight; retail spec names (outlaw, guardian) don't match Forever trees 1:1.",
         usage="Blizzard_PlayerSpells/Mainline ClassTalents (retail); not used by Forever",
         collect=lambda: atlas_family("talents-background-<C>-<V>")),
    dict(key="spec_thumbnail", title="Spec-Vorschaubilder (spec-thumbnail-<class>-<spec>)", fit="ok darkened",
         why="Small cropped spec paintings with a hard frame edge; usable as card headers when darkened.",
         usage="Blizzard_ClassSpecializationsFrame (retail spec choice); not used by Forever",
         collect=lambda: atlas_family("spec-thumbnail-<C>-<V>")),
    dict(key="talent_tree_icons", title="Talentbaum-Icons (TalentTab.SpellIconID)", fit="good",
         why="The classic tree icons (27); square icons = native mUI icon style for tree tabs/headers.",
         usage="TalentTab DB2 of Forever (tree tab icons)",
         collect=lambda: [F(c, n, ic) for c in CLASSES for n, _, ic in trees().get(c, [])]),
    dict(key="talent_activation", title="Talent-Aktivierungseffekt (talents-animations-class-*)", fit="ok darkened",
         why="Golden class crest (461 px) used as additive flash; as a still image it is a nice crest but its glow makes it look brighter than the bronze/gold sets.",
         usage="Blizzard_PlayerSpells/Camelot/ClassTalents (activationFX of the Forever talent frame)",
         collect=lambda: atlas_family("talents-animations-class-<C>")),
    dict(key="talent_orderhall", title="Ordenshallen-Talenthintergrund (orderhalltalents-background-*)", fit="ok darkened",
         why="Portrait-format class paintings (322x382) - nice side panel art when dimmed.",
         usage="Blizzard_OrderHallTalents (Legion); no Forever usage",
         collect=lambda: atlas_family("orderhalltalents-background-<C>")),

    dict(key="charinfo_c60", title="Charakterfenster-Klassenhintergrund Forever (ui-character-info-<class>-bg-c60)", fit="good",
         why="Very dark, low-contrast carved class crest panel (233x383) made for Forever - already nearly flat, the best single background for a class theme.",
         usage="Camelot/CharacterFrame.lua: UI-Character-Info-<CLASS>-BG behind the stats pane (Forever uses the -c60 art)",
         collect=lambda: atlas_family("ui-character-info-<C>-bg-c60")),
    dict(key="charinfo_retail", title="Charakterfenster-Klassenhintergrund Retail (ui-character-info-<class>-bg)", fit="ok darkened",
         why="Legion stat-pane class painting, more colorful than the c60 version.",
         usage="Mainline CharacterFrame stats pane (retail)",
         collect=lambda: atlas_family("ui-character-info-<C>-bg")),
    dict(key="dressingroom", title="Anprobe-Hintergrund pro Klasse (dressingroom-background-*)", fit="ok darkened",
         why="Full scene behind the model (478x500); good behind a 3D model when darkened to ~45%.",
         usage="Mainline DressUpFrames.lua (also loaded in Forever: SetDressUpBackground by class)",
         collect=lambda: atlas_family("dressingroom-background-<C>")),
    dict(key="petstats", title="Begleiter-Hintergründe (petstatsbg-*, Jäger-Stall)", fit="ok darkened",
         why="Only for pet classes; stable art per pet type.",
         usage="Old PetPaperDollFrame; hunter-stable-bg-art_* in the stable UI",
         collect=lambda: [F(c, "petstatsbg", f"Interface/PetPaperDollFrame/PetStatsBG-{c}") for c in ("hunter", "warlock", "mage")] +
         atlas_family("<C>-stable-bg-art_<V>")),

    dict(key="orderhall_landing", title="Ordenshallen-Wappen bronze (legionmission-landingpage-background-*)", fit="good",
         why="Cut-out monochrome bronze class crest (230x203) on transparency; desaturated and tinted with the accent at 10-20% alpha it is a perfect flat watermark.",
         usage="Garrison landing page (Legion order hall); no Forever usage",
         collect=lambda: atlas_family("legionmission-landingpage-background-<C>")),
    dict(key="orderhall_complete", title="Ordenshallen-Abschlussbild (legionmission-complete-background-*)", fit="ok darkened",
         why="Wide class scene for mission completion; good as splash background, darkened.",
         usage="Order hall mission complete dialog (Legion)",
         collect=lambda: atlas_family("legionmission-complete-background-<C>")),
    dict(key="orderhall_button", title="Ordenshallen-Minimap-Knopf (legionmission-landingbutton-*)", fit="poor",
         why="Round minimap button with heavy frame.",
         usage="GarrisonLandingPageMinimapButton (Legion)",
         collect=lambda: atlas_family("legionmission-landingbutton-<C>-up")),
    dict(key="artifact_book", title="Artefaktbuch-Wappen gold (Interface/Pictures/artifactbook-<class>-cover)", fit="good",
         why="Large cut-out golden class crest on transparency (same designs as the bronze ones, higher resolution); the strongest single 'class moment', desaturate/tint for mUI.",
         usage="Artifact quest books (Legion)",
         collect=lambda: [F(c, "cover", f"Interface/Pictures/ArtifactBook-{c}-Cover") for c in CLASSES]),
    dict(key="artifact_header", title="Artefakt-Kopfleisten und -Hintergründe (artifacts-<class>-header/-bg)", fit="poor",
         why="Thin glowing header lines and murky textures from the artifact UI; nothing a flat UI needs.",
         usage="Blizzard_ArtifactUI (Legion)",
         collect=lambda: atlas_family("artifacts-<C>-header") + atlas_family("artifacts-<C>-bg")),
    dict(key="loading_class", title="Ladebildschirme mit Klassenbezug (Ordenshallen)", fit="ok darkened",
         why="Full-screen class hall art (not all classes); good blurred/darkened behind an AFK or login splash.",
         usage="Loading screens of Legion order halls",
         collect=lambda: [F(re.search("|".join(ALL), p.lower()).group(0), os.path.basename(p)[:-4].lower(), fid)
                          for fid, p in sorted(L.manifest().items())
                          if "loadingscreens/" in p.lower() and re.search(r"(orderhall|artifact)", p.lower())
                          and re.search("|".join(ALL), p.lower())]),
    dict(key="charcreate_forms", title="Charaktererstellung: Druidengestalten / Hexer-Begleiter", fit="good",
         why="Round flat icons (druid forms, warlock pets) - usable as accents for those two classes.",
         usage="Blizzard_CharacterCustomize (druid form / warlock pet choices)",
         collect=lambda: atlas_family("charactercreate-<C>form-<V>") + atlas_family("charactercreate-<C>pet-<V>")),

    dict(key="resource_c60", title="Ressourcen: Forever-Kombopunkte (uf-roguecp-*-c60)", fit="ok darkened",
         why="Red combo point orbs restyled for Forever; mUI draws own flat pips, so only as optional skin.",
         usage="RogueComboPoint.xml (combo points under the player frame); -c60 variants for Forever",
         collect=lambda: [A("rogue", n.replace("uf-roguecp-", ""), n) for n in sorted(L.atlases()) if n.startswith("uf-roguecp-") and n.endswith("-c60")]),
    dict(key="resource_hud", title="Ressourcen-Texturen (Seelensplitter, Heilige Kraft, Mond/Sonne, Arkanladungen ...)", fit="poor",
         why="Detailed retail HUD resource art; most resources don't exist in Classic content (holy power, shards as resource).",
         usage="Interface/HUD + Interface/PlayerFrame (retail class bars)",
         collect=lambda: [F(c, os.path.basename(p)[:-4].lower(), p) for c, p in [
             ("warlock", "Interface/PlayerFrame/UI-WarlockShard.blp"), ("paladin", "Interface/PlayerFrame/PaladinPowerTextures.blp"),
             ("druid", "Interface/PlayerFrame/UI-DruidEclipse.blp"), ("priest", "Interface/PlayerFrame/Priest-ShadowUI.blp"),
             ("mage", "Interface/PlayerFrame/MageArcaneCharges.blp"), ("warlock", "Interface/HUD/UIWarlockSoulShard.blp"),
             ("paladin", "Interface/HUD/UIPaladinHolyPower.blp"), ("rogue", "Interface/HUD/UIRogueCombpoints.blp"),
             ("druid", "Interface/HUD/UIDruidCombopoints.blp"), ("mage", "Interface/HUD/UIMageArcaneCharge.blp"),
             ("shaman", "Interface/HUD/UIShamanMaelstrom.blp"), ("druid", "Interface/HUD/UIDruidAstralPower.blp")]]),
    dict(key="spellbook_bg", title="Zauberbuch-Hintergrund mit Klassenbezug", fit="poor",
         why="Only one class version exists (druid) and it is almost empty dark art - not usable as a per-class theme.",
         usage="Interface/Spellbook/SpellbookBackgroundDruid (retail spellbook)",
         collect=lambda: [F("druid", "spellbookbackground", "Interface/Spellbook/SpellbookBackgroundDruid.blp")]),
]


# --- sizes, presence, images -------------------------------------------------------------------

def resolve(it):
    """fill fdid, path, width, height, present, image"""
    if it["kind"] == "atlas":
        a = L.atlases().get(it["ref"])
        it["fdid"] = a["fdid"] if a else None
        it["path_or_atlas"] = f"atlas:{it['ref']}"
        it["texpath"] = L.path_of(a["fdid"]) if a else ""
        it["w"], it["h"] = (a["w"], a["h"]) if a else (0, 0)
        it["img"] = L.atlas_image(it["ref"]) if a else None
    elif it["kind"] == "file":
        fid = it["ref"]
        it["fdid"] = fid
        it["path_or_atlas"] = L.path_of(fid) if fid else (it.get("path") or "")
        if not it["path_or_atlas"] and it.get("path"):
            it["path_or_atlas"] = it["path"]
        img = L.texture(fid) if fid else None
        if img is not None and it.get("crop"):
            l, r, t, b = it["crop"]
            img = img.crop((round(l * img.width), round(t * img.height), round(r * img.width), round(b * img.height)))
            it["path_or_atlas"] += " [texcoord %s]" % ",".join(f"{v:g}" for v in it["crop"])
        it["img"] = img
        it["w"], it["h"] = (img.size if img else (0, 0))
    elif it["kind"] == "quad":
        ims = [L.texture(f) if f else None for f in it["ref"]]
        it["fdid"] = "/".join(str(f) for f in it["ref"])
        it["path_or_atlas"] = it["path"]
        if all(ims):
            tl, tr, bl, br = ims
            img = Image.new("RGBA", (tl.width + tr.width, tl.height + bl.height))
            img.paste(tl, (0, 0)); img.paste(tr, (tl.width, 0)); img.paste(bl, (0, tl.height)); img.paste(br, (tl.width, tl.height))
            # visible area of the classic frame (296x?): crop the transparent/unused right part
            it["img"] = img
        else:
            it["img"] = None
        it["w"], it["h"] = it["img"].size if it["img"] else (0, 0)
    it["present"] = it["img"] is not None
    return it


def thumb(img, w, h):
    im = img.copy()
    im.thumbnail((w, h), Image.LANCZOS)
    return im


def contact_sheet(fam, items):
    items = [i for i in items if i["present"]]
    if not items:
        return None
    order = {c: n for n, c in enumerate(ALL)}
    items.sort(key=lambda i: (order.get(i["cls"], 99), i["variant"]))
    by_cls = {}
    for i in items:
        by_cls.setdefault(i["cls"], []).append(i)
    multi = max(len(v) for v in by_cls.values()) > 1
    f_lab, f_title = font(12), font(14)
    pad, lab_h, title_h = 6, 16, 26
    max_src = max(max(i["img"].width, i["img"].height) for i in items)
    if multi:
        # one row per class, variants side by side (wrap)
        per_row = min(max(len(v) for v in by_cls.values()), 6 if max_src <= 128 else 3)
        cw = (SHEET_W - pad * (per_row + 1) - 70) // per_row
        if max_src <= 128:
            per_row = min(max(len(v) for v in by_cls.values()), 8)
            cw = min((SHEET_W - pad * (per_row + 1) - 70) // per_row, max(48, max_src * 2))
        ratio = max(i["img"].height / max(1, i["img"].width) for i in items)
        ch = min(int(cw * ratio), 260)
        rows = []
        for c, lst in by_cls.items():
            for k in range(0, len(lst), per_row):
                rows.append((c if k == 0 else "", lst[k:k + per_row]))
        H = title_h + len(rows) * (ch + lab_h + pad) + pad
        sheet = Image.new("RGB", (SHEET_W, H), BG)
        d = ImageDraw.Draw(sheet)
        d.text((pad, 6), fam["title"], fill=FG, font=f_title)
        y = title_h
        for c, lst in rows:
            d.text((pad, y + ch // 2), c, fill=FG, font=f_lab)
            x = 70
            for i in lst:
                src = i["img"]
                if max(src.size) <= 64:
                    src = src.resize((src.width * 2, src.height * 2), Image.NEAREST)
                t = thumb(src, cw, ch)
                sheet.paste(t, (x + (cw - t.width) // 2, y + (ch - t.height) // 2), t)
                d.text((x, y + ch + 1), i["variant"][: max(6, cw // 7)], fill=DIM, font=f_lab)
                x += cw + pad
            y += ch + lab_h + pad
        return sheet
    cols = 9 if max_src <= 64 else (5 if max_src <= 130 else 3)
    cols = min(cols, len(items))
    cw = (SHEET_W - pad * (cols + 1)) // cols
    ratio = max(i["img"].height / max(1, i["img"].width) for i in items)
    ch = min(int(cw * ratio), 300)
    if max_src <= 64:
        ch = min(ch, max_src * 2)
    nrows = (len(items) + cols - 1) // cols
    H = title_h + nrows * (ch + lab_h + pad) + pad
    sheet = Image.new("RGB", (SHEET_W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 6), fam["title"], fill=FG, font=f_title)
    for n, i in enumerate(items):
        x = pad + (n % cols) * (cw + pad)
        y = title_h + (n // cols) * (ch + lab_h + pad)
        src = i["img"]
        if max(src.size) <= 64:  # small icons: scale up crisp to 2x for visibility
            src = src.resize((src.width * 2, src.height * 2), Image.NEAREST)
        t = thumb(src, cw, ch)
        sheet.paste(t, (x + (cw - t.width) // 2, y + (ch - t.height) // 2), t)
        lab = i["cls"] + ("" if i["cls"] in CLASSES else " (retail)")
        d.text((x, y + ch + 1), lab, fill=FG if i["cls"] in CLASSES else DIM, font=f_lab)
    return sheet


def main():
    only = sys.argv[1] if len(sys.argv) > 1 else None
    os.makedirs(PREV, exist_ok=True)
    out_rows = []
    csv_path = os.path.join(HERE, "inventory.csv")
    keep = []
    if only and os.path.exists(csv_path):  # partial run: keep rows of other families
        with open(csv_path, newline="") as f:
            keep = [r for r in csv.DictReader(f) if only not in r["family"]]
    summary = []
    for fam in FAMILIES:
        if only and only not in fam["key"]:
            continue
        items = [resolve(i) for i in fam["collect"]()]
        sheet = contact_sheet(fam, items)
        if sheet:
            sheet.save(os.path.join(PREV, fam["key"] + ".jpg"), quality=84, optimize=True)
        n_forever = sum(1 for i in items if i["present"] and i["cls"] in CLASSES)
        summary.append((fam["key"], len(items), n_forever))
        print(f"{fam['key']:22s} items={len(items):3d} present={sum(i['present'] for i in items):3d} forever-classes={n_forever}")
        for i in items:
            retail_class = i["cls"] not in CLASSES
            out_rows.append(dict(
                family=fam["key"], **{"class": i["cls"]}, variant=i["variant"],
                path_or_atlas=i["path_or_atlas"] + (f" -> {i['texpath']}" if i.get("texpath") else ""),
                fileDataID=i["fdid"], width=i["w"], height=i["h"],
                in_forever="yes" if i["present"] else "no",
                blizzard_usage=fam["usage"],
                fit=("n/a (class not in Forever)" if retail_class else fam["fit"]) if i["present"] else "n/a (missing)"))
    fields = ["family", "class", "variant", "path_or_atlas", "fileDataID", "width", "height", "in_forever", "blizzard_usage", "fit"]
    with open(csv_path, "w", newline="") as f:
        w = csv.DictWriter(f, fields)
        w.writeheader()
        for r in keep + out_rows:
            w.writerow(r)
    print("rows:", len(keep) + len(out_rows))


if __name__ == "__main__":
    main()
