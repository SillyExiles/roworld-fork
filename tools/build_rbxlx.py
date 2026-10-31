#!/usr/bin/env python3
"""Minimal Rojo-compatible place builder: project.json + src tree -> .rbxlx (or .rbxmx of one subtree).

Supports what the Empires Front project uses: $path folders of .luau files (init / .server / .client
conventions), $className, $properties (bool, number, string, Color3 triples, enums by name for a few
known properties) and globIgnorePaths ("**/Dev").
Usage: build_rbxlx.py <project.json> <out.rbxlx>
"""
import fnmatch
import json
import os
import sys
from xml.sax.saxutils import escape

ref_counter = [0]


def ref():
    ref_counter[0] += 1
    return "RBX%08X" % ref_counter[0]


def cdata(s):
    return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"


ENUMS = {
    ("Lighting", "Technology"): {"Legacy": 0, "Voxel": 1, "Compatibility": 2, "ShadowMap": 3, "Future": 4},
    ("ColorGradingEffect", "TonemapperPreset"): {"Default": 0, "Retro": 1},
    ("StarterGui", "ScreenOrientation"): {"LandscapeLeft": 0, "LandscapeRight": 1, "LandscapeSensor": 2,
                                          "Portrait": 3, "Sensor": 4},
}
FLOATS = {"Brightness", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ClockTime",
          "ExposureCompensation", "Gravity"}


def prop_xml(cls, name, v):
    if isinstance(v, bool):
        return '<bool name="%s">%s</bool>' % (name, "true" if v else "false")
    if isinstance(v, list) and len(v) == 3:
        return '<Color3 name="%s"><R>%s</R><G>%s</G><B>%s</B></Color3>' % (name, v[0], v[1], v[2])
    if isinstance(v, (int, float)) and name in FLOATS:
        return '<float name="%s">%s</float>' % (name, v)
    if isinstance(v, str) and (cls, name) in ENUMS:
        return '<token name="%s">%d</token>' % (name, ENUMS[(cls, name)][v])
    if isinstance(v, str):
        return '<string name="%s">%s</string>' % (name, escape(v))
    if isinstance(v, (int, float)):
        return '<double name="%s">%s</double>' % (name, v)
    raise ValueError("unsupported property %s.%s=%r" % (cls, name, v))


class Inst:
    def __init__(self, cls, name, props=None, source=None):
        self.cls, self.name, self.props, self.source = cls, name, props or {}, source
        self.children = []

    def xml(self, out, depth=0):
        out.append('<Item class="%s" referent="%s"><Properties>' % (self.cls, ref()))
        out.append('<string name="Name">%s</string>' % escape(self.name))
        if self.source is not None:
            out.append('<ProtectedString name="Source">%s</ProtectedString>' % cdata(self.source))
        for k, v in self.props.items():
            out.append(prop_xml(self.cls, k, v))
        out.append("</Properties>")
        for c in self.children:
            c.xml(out, depth + 1)
        out.append("</Item>")


def ignored(path, ignores, root):
    rel = os.path.relpath(path, root).replace(os.sep, "/")
    return any(fnmatch.fnmatch(rel, g) or fnmatch.fnmatch(rel, g.replace("**/", "")) for g in ignores)


def script_for(fname, path):
    src = open(path, encoding="utf-8").read()
    for suffix, cls in ((".server.luau", "Script"), (".client.luau", "LocalScript"), (".luau", "ModuleScript"),
                        (".server.lua", "Script"), (".client.lua", "LocalScript"), (".lua", "ModuleScript")):
        if fname.endswith(suffix):
            return cls, fname[: -len(suffix)], src
    return None


def from_path(path, name, ignores, root):
    if os.path.isfile(path):
        s = script_for(os.path.basename(path), path)
        return Inst(s[0], name, source=s[2])
    entries = sorted(os.listdir(path))
    node = None
    for init in ("init.server.luau", "init.client.luau", "init.luau"):
        if init in entries:
            cls, _, src = script_for(init, os.path.join(path, init))
            node = Inst(cls, name, source=src)
            entries.remove(init)
            break
    if node is None:
        node = Inst("Folder", name)
    for e in entries:
        p = os.path.join(path, e)
        if ignored(p, ignores, root) or e.startswith("."):
            continue
        if os.path.isdir(p):
            node.children.append(from_path(p, e, ignores, root))
        else:
            s = script_for(e, p)
            if s:
                node.children.append(Inst(s[0], s[1], source=s[2]))
    return node


def from_tree(name, tree, root, ignores, parent_cls=None):
    cls = tree.get("$className")
    if "$path" in tree:
        node = from_path(os.path.join(root, tree["$path"]), name, ignores, root)
    else:
        node = Inst(cls or name, name)
    if cls:
        node.cls = cls
    node.props.update(tree.get("$properties", {}))
    for k, v in tree.items():
        if not k.startswith("$"):
            node.children.append(from_tree(k, v, root, ignores))
    return node


def main():
    proj_path, out_path = sys.argv[1], sys.argv[2]
    proj = json.load(open(proj_path))
    root = os.path.dirname(os.path.abspath(proj_path))
    ignores = proj.get("globIgnorePaths", [])
    tree = proj["tree"]
    out = ['<roblox version="4">']
    for k, v in tree.items():
        if k.startswith("$"):
            continue
        from_tree(k, v, root, ignores).xml(out)
    out.append("</roblox>")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("".join(out))
    print("wrote", out_path, os.path.getsize(out_path), "bytes")




def build_models(root, out_dir, ignores=("**/Dev/**", "**/Dev")):
    """One .rbxmx per game tree (for InsertService:LoadLocalAsset hot reloads in Studio)."""
    os.makedirs(out_dir, exist_ok=True)
    for path, name in (("src/shared", "Airfront"), ("src/server", "AirfrontServer"), ("src/client", "AirfrontClient")):
        ref_counter[0] = 0
        node = from_path(os.path.join(root, path), name, list(ignores), root)
        out = ['<roblox version="4">']
        node.xml(out)
        out.append("</roblox>")
        p = os.path.join(out_dir, name + ".rbxmx")
        with open(p, "w", encoding="utf-8") as f:
            f.write("".join(out))
        print("wrote", p, os.path.getsize(p))


if __name__ == "__main__":
    if sys.argv[1] == "--models":
        build_models(sys.argv[2], sys.argv[3])
    else:
        main()
