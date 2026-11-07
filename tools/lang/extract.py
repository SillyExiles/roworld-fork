#!/usr/bin/env python3
"""Empires Front: the English texts the player can read (client UI string literals and the Sim's
messages), for translation (tools/lang/<code>.json -> src/client/Lang/<Code>.luau).

usage: python3 tools/lang/extract.py > tools/lang/en.txt
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
SKIP_FILES = {"ShipData.luau", "PixelBuildings.luau", "SiegeGlyphs.luau", "PixelIcons.luau", "SiegeData.luau",
              "IconData.luau", "ShipArt.luau", "SiegeArt.luau", "FlagArt.luau", "UILayoutProbe.luau", "Telemetry.luau",
              "AudioDirector.luau", "Playlist.luau", "MusicMood.luau", "FalloutGlow.luau", "MapSurface.luau",
              "WakeRoute.luau", "TrailBudget.luau", "FrameClock.luau", "AtlasReady.luau", "MapFxImage.luau"}
CODEY = re.compile(r"^(Frame|TextLabel|TextButton|ImageLabel|ImageButton|UI[A-Z]\w*|ScrollingFrame|ScreenGui|Folder|Sound|"
                   r"TextBox|CanvasGroup|ViewportFrame|Part|Camera|Model|BindableEvent|RemoteEvent|RemoteFunction|"
                   r"LocalScript|ModuleScript|Script|Humanoid|Highlight|Attachment|Beam|ParticleEmitter|"
                   r"PlayerGui|PlayerScripts|ReplicatedStorage|RunService|Players|TweenService|UserInputService|"
                   r"GuiService|HttpService|ContentProvider|SoundService|Workspace|Lighting|StarterGui|TextService|"
                   r"MarketplaceService|AssetService|LocalizationService|ContextActionService|SocialService|"
                   r"BadgeService|GroupService|PolicyService|TeleportService|Debris|CollectionService|"
                   r"AnalyticsService|AvatarEditorService|ExperienceNotificationService|VoiceChatService|"
                   r"Rubik|GothamBold|Gotham|SourceSans\w*|Arial|RobotoMono|Ubuntu|Bangers|FredokaOne|LuckiestGuy|"
                   r"Enum|Vector2|Vector3|Color3|UDim2?|Rect|CFrame|NumberSequence|ColorSequence)$")


def strings_of(src):
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", "", src, flags=re.S)
    src = re.sub(r"--[^\n]*", "", src)
    for m in re.finditer(r'"((?:[^"\\\n]|\\.)*)"', src):
        t = m.group(1)
        if len(t) < 2 or not re.search(r"[A-Za-z]{2}", t):
            continue
        if re.fullmatch(r"[a-z_0-9.:/%-]+", t):  # ids, keys, paths
            continue
        if CODEY.match(t) or t.startswith(("rbxasset", "http", "rbxthumb", "@")):
            continue
        if re.fullmatch(r"[A-Z_0-9]+", t) and "_" in t:  # constants
            continue
        if re.fullmatch(r"[A-Za-z]+[A-Z][A-Za-z]*", t) and " " not in t and not t.isupper():  # camelCase / PascalCase names
            continue
        if re.search(r"[.:]\w+\(|==|~=|\.\.", t):
            continue
        yield t


def main():
    seen = {}
    roots = [os.path.join(ROOT, "src", "client"), os.path.join(ROOT, "src", "shared", "Core")]
    for base in roots:
        for root, _, files in os.walk(base):
            if "/Dev" in root:
                continue
            for f in sorted(files):
                if not f.endswith(".luau") or f in SKIP_FILES:
                    continue
                p = os.path.join(root, f)
                src = open(p, encoding="utf-8").read()
                if base.endswith("Core") and "self:msg" not in src and "msg_others" not in src:
                    continue
                for t in strings_of(src):
                    seen.setdefault(t, os.path.relpath(p, ROOT))
    for t, where in seen.items():
        print(where + "\t" + t)


if __name__ == "__main__":
    main()
