#!/usr/bin/env python3
"""Stage 2 — Categorize the flattened symbol graph (symbols_all.tsv) into matchable
dimensions and write sdk_catalog.json. Columns: module, kind, parent, title, access.

Dimensions: types, modifiers, valueBuilders, propertyWrappers, macros,
environmentKeys, styleValues, protocols. Plus side maps: style_categories.
"""
import json, os
from collections import defaultdict

HERE = os.path.dirname(__file__)
TSV = os.path.join(HERE, "..", "symbols_all.tsv")
OUT = os.path.join(HERE, "..", "sdk_catalog.json")
strip = lambda t: t.split('(')[0]
pub  = lambda s: sorted(x for x in s if x and not x.startswith('_'))

# Instance-method hosts whose methods are chainable "modifiers".
MODIFIER_HOSTS = {"View","Text","Image","Shape","InsettableShape","Scene","Gesture",
                  "ShapeStyle","Font","ToolbarContent","Label","Button","Picker","Toggle",
                  "EnvironmentValues"}

# Value types whose STATIC members are value-builders used as `.system(...)` / `.easeInOut`
# / `.headline` / `.slide` / `.linearGradient(...)` etc. (NOT chained view modifiers).
VALUE_BUILDER_HOSTS = {"Font","Color","Animation","AnyTransition","Gradient","LinearGradient",
                       "RadialGradient","AngularGradient","EllipticalGradient","Material","Angle",
                       "UnitPoint","ControlSize","Weight","Design","Transition"}

# Map a style-value's declaring parent type to a coarse category.
def style_category(parent: str) -> str:
    if parent.endswith("Style"): return "controlStyle"
    if parent == "Color": return "color"
    if parent in {"Material"}: return "material"
    if parent.endswith("Alignment") or parent in {"UnitPoint","Edge","Axis"}: return "alignment"
    if parent in {"Edge.Set"}: return "edge"
    if parent.endswith("Placement") or parent.endswith("ItemPlacement"): return "placement"
    if parent in {"Visibility","Prominence","ControlSize","ContentMode","TextAlignment"}: return "appearance"
    return "other"

def main():
    methods_by_type = defaultdict(set)        # instance methods (swift.method)
    static_by_type  = defaultdict(set)         # static members (swift.type.method / .type.property)
    types, macros, env_keys, protocols = set(), set(), set(), set()
    style_values = set()
    style_parent = {}                          # styleValue name -> declaring parent (first seen)

    STYLE_PARENTS_EXTRA = {"ToolbarItemPlacement","Visibility","Edge","Axis","ContentMode",
        "TextAlignment","Prominence","HorizontalAlignment","VerticalAlignment","ControlSize","Edge.Set"}

    for ln in open(TSV):
        p = ln.rstrip('\n').split('\t')
        if len(p) < 5: continue
        module, kind, parent, title, access = p[0], p[1], p[2], p[3], p[4]
        base = strip(title)
        if kind == "swift.method":
            if base.isidentifier(): methods_by_type[parent].add(base)
        elif kind in ("swift.type.method","swift.type.property"):
            if base.isidentifier(): static_by_type[parent].add(base)
            # style values: static props / type methods on *Style and option types
            if kind == "swift.type.property" and (parent.endswith("Style")
                    or parent.endswith("Configuration") or parent in STYLE_PARENTS_EXTRA):
                if title.isidentifier():
                    style_values.add(title); style_parent.setdefault(title, parent)
        elif kind == "swift.enum.case":
            if (parent.endswith("Style") or parent in STYLE_PARENTS_EXTRA) and title.isidentifier():
                style_values.add(title); style_parent.setdefault(title, parent)
        elif kind in ("swift.struct","swift.enum","swift.class"):
            if title.isidentifier(): types.add(title)
        elif kind == "swift.protocol":
            if title.isidentifier(): types.add(title); protocols.add(title)
        elif kind == "swift.macro":
            if base.isidentifier(): macros.add(base)
        elif kind == "swift.property" and parent == "EnvironmentValues":
            if title.isidentifier(): env_keys.add(title)

    modifiers = set()
    for t in MODIFIER_HOSTS:
        modifiers |= methods_by_type.get(t, set())

    # stdlib-collision removal (protect unambiguous SwiftUI modifiers)
    PROTECT = {"padding","offset","tag","scale","userActivity","frame","background"}
    try:
        stdlib = set(json.load(open(os.path.join(HERE,"..","stdlib_method_names.json"))))
    except Exception:
        stdlib = set()
    removed = (modifiers & stdlib) - PROTECT
    modifiers -= removed
    print(f"  stdlib-collision modifiers removed: {len(removed)} (kept {len(modifiers)})")

    # value-builders = static members of value types, made disjoint from modifiers so genuine
    # View modifiers always win; also drop stdlib-noise names.
    value_builders = set()
    for t in VALUE_BUILDER_HOSTS:
        value_builders |= static_by_type.get(t, set())
    # drop generic enum/singleton statics that collide with non-SwiftUI usage
    GENERIC_STATICS = {"allCases","standard","shared","default","none","zero","init","some"}
    value_builders = ((value_builders - modifiers) - stdlib) - GENERIC_STATICS
    print(f"  valueBuilders collected: {len(value_builders)} (from {len(VALUE_BUILDER_HOSTS)} value types)")

    wrappers = {"State","Binding","StateObject","ObservedObject","EnvironmentObject","Environment",
                "AppStorage","SceneStorage","FocusState","FocusedBinding","FocusedValue",
                "FocusedObject","GestureState","Namespace","ScaledMetric","Bindable",
                "FetchRequest","SectionedFetchRequest","Query","AccessibilityFocusState",
                "NSApplicationDelegateAdaptor","UIApplicationDelegateAdaptor","Observable","Model",
                "Attribute","Relationship","Transient","PreviewState"}

    style_cats = {name: style_category(style_parent.get(name,"")) for name in style_values}

    catalog = {
        "sdk": "macOS 26.5 SDK",
        "modules": ["SwiftUI","SwiftUICore","Observation","SwiftData","Charts"],
        "dimensions": {
            "types": pub(types),
            "modifiers": pub(modifiers),
            "valueBuilders": pub(value_builders),
            "propertyWrappers": sorted(wrappers),
            "macros": pub(macros),
            "environmentKeys": pub(env_keys),
            "styleValues": pub(style_values),
            "protocols": pub(protocols),
        },
        "style_categories": style_cats,
    }
    catalog["counts"] = {k: len(v) for k, v in catalog["dimensions"].items()}
    json.dump(catalog, open(OUT,"w"), indent=2)
    print(f"wrote {OUT}: {catalog['counts']}")
    # quick value-builder probe
    vb = set(catalog["dimensions"]["valueBuilders"])
    print("  vb probes:", {x:(x in vb) for x in ['system','easeInOut','headline','slide','linearGradient','degrees','spring','semibold']})

if __name__ == "__main__":
    main()
