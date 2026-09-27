#!/usr/bin/env python3
"""Regenerate SudokuGame.xcodeproj/project.pbxproj from the files on disk.

Run from anywhere: python3 tools/generate_xcodeproj.py
"""
import os, re
root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
old = open(f"{root}/SudokuGame.xcodeproj/project.pbxproj").read()
def block(id_):
    m = re.search(r"\t\t" + id_ + r" /\* (Debug|Release) \*/ = \{.*?\n\t\t\};\n", old, re.S)
    return m.group(0)
proj_debug, proj_release = block("A1000025"), block("A1000026")

groups = {g: (gid, sorted(f for f in os.listdir(f"{root}/SudokuGame/{g}") if not f.startswith(".")))
          for g, gid in [("Models", "A1000018"), ("Services", "D1000001"), ("Views", "A1000017"), ("Sounds", "D1000002")]}
top_files = ["SudokuGameApp.swift", "Assets.xcassets", "Info.plist", "PrivacyInfo.xcprivacy"]
for g, (_, files) in groups.items():
    for f in files:
        assert os.path.exists(f"{root}/SudokuGame/{g}/{f}"), f

counter = [0]
entries = []  # (name, fileRef, buildFile or None, phase)
def add(name):
    counter[0] += 1
    ref = f"B1{counter[0]:06d}"
    bf = f"C1{counter[0]:06d}"
    if name.endswith(".swift"): phase = "Sources"
    elif name == "Info.plist": phase, bf = None, None
    else: phase = "Resources"
    entries.append((name, ref, bf, phase))
    return ref
top_refs = [add(f) for f in top_files]
group_refs = {g: [add(f) for f in files] for g, (_, files) in groups.items()}

def ftype(n):
    return {"swift": "sourcecode.swift", "xcassets": "folder.assetcatalog", "plist": "text.plist.xml",
            "xcprivacy": "text.xml", "wav": "audio.wav", "m4a": "file", "json": "text.json"}[n.rsplit(".", 1)[1]]

o = []
o.append("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {\n\t};\n\tobjectVersion = 56;\n\tobjects = {\n\n")
o.append("/* Begin PBXBuildFile section */\n")
for n, ref, bf, ph in entries:
    if bf: o.append(f"\t\t{bf} /* {n} in {ph} */ = {{isa = PBXBuildFile; fileRef = {ref} /* {n} */; }};\n")
o.append("/* End PBXBuildFile section */\n\n/* Begin PBXFileReference section */\n")
o.append('\t\tA1000011 /* SudokuGame.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SudokuGame.app; sourceTree = BUILT_PRODUCTS_DIR; };\n')
for n, ref, bf, ph in entries:
    o.append(f'\t\t{ref} /* {n} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype(n)}; path = {n}; sourceTree = "<group>"; }};\n')
o.append("/* End PBXFileReference section */\n\n")
o.append("/* Begin PBXFrameworksBuildPhase section */\n\t\tA1000013 /* Frameworks */ = {\n\t\t\tisa = PBXFrameworksBuildPhase;\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t};\n/* End PBXFrameworksBuildPhase section */\n\n")
o.append("/* Begin PBXGroup section */\n")
o.append('\t\tA1000014 = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tA1000015 /* SudokuGame */,\n\t\t\t\tA1000016 /* Products */,\n\t\t\t);\n\t\t\tsourceTree = "<group>";\n\t\t};\n')
kids = [f"{top_refs[0]} /* SudokuGameApp.swift */"] + [f"{gid} /* {g} */" for g, (gid, _) in groups.items()] + [f"{r} /* {n} */" for r, n in zip(top_refs[1:], top_files[1:])]
o.append('\t\tA1000015 /* SudokuGame */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n' + "".join(f"\t\t\t\t{k},\n" for k in kids) + '\t\t\t);\n\t\t\tpath = SudokuGame;\n\t\t\tsourceTree = "<group>";\n\t\t};\n')
o.append('\t\tA1000016 /* Products */ = {\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n\t\t\t\tA1000011 /* SudokuGame.app */,\n\t\t\t);\n\t\t\tname = Products;\n\t\t\tsourceTree = "<group>";\n\t\t};\n')
for g, (gid, files) in groups.items():
    o.append(f'\t\t{gid} /* {g} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n' + "".join(f"\t\t\t\t{r} /* {n} */,\n" for r, n in zip(group_refs[g], files)) + f'\t\t\t);\n\t\t\tpath = {g};\n\t\t\tsourceTree = "<group>";\n\t\t}};\n')
o.append("/* End PBXGroup section */\n\n")
o.append('/* Begin PBXNativeTarget section */\n\t\tA1000019 /* SudokuGame */ = {\n\t\t\tisa = PBXNativeTarget;\n\t\t\tbuildConfigurationList = A1000020 /* Build configuration list for PBXNativeTarget "SudokuGame" */;\n\t\t\tbuildPhases = (\n\t\t\t\tA1000021 /* Sources */,\n\t\t\t\tA1000013 /* Frameworks */,\n\t\t\t\tA1000022 /* Resources */,\n\t\t\t);\n\t\t\tbuildRules = (\n\t\t\t);\n\t\t\tdependencies = (\n\t\t\t);\n\t\t\tname = SudokuGame;\n\t\t\tproductName = SudokuGame;\n\t\t\tproductReference = A1000011 /* SudokuGame.app */;\n\t\t\tproductType = "com.apple.product-type.application";\n\t\t};\n/* End PBXNativeTarget section */\n\n')
o.append('/* Begin PBXProject section */\n\t\tA1000023 /* Project object */ = {\n\t\t\tisa = PBXProject;\n\t\t\tattributes = {\n\t\t\t\tBuildIndependentTargetsInParallel = 1;\n\t\t\t\tLastSwiftUpdateCheck = 1500;\n\t\t\t\tLastUpgradeCheck = 1500;\n\t\t\t\tTargetAttributes = {\n\t\t\t\t\tA1000019 = {\n\t\t\t\t\t\tCreatedOnToolsVersion = 15.0;\n\t\t\t\t\t};\n\t\t\t\t};\n\t\t\t};\n\t\t\tbuildConfigurationList = A1000024 /* Build configuration list for PBXProject "SudokuGame" */;\n\t\t\tcompatibilityVersion = "Xcode 14.0";\n\t\t\tdevelopmentRegion = en;\n\t\t\thasScannedForEncodings = 0;\n\t\t\tknownRegions = (\n\t\t\t\ten,\n\t\t\t\tBase,\n\t\t\t);\n\t\t\tmainGroup = A1000014;\n\t\t\tproductRefGroup = A1000016 /* Products */;\n\t\t\tprojectDirPath = "";\n\t\t\tprojectRoot = "";\n\t\t\ttargets = (\n\t\t\t\tA1000019 /* SudokuGame */,\n\t\t\t);\n\t\t};\n/* End PBXProject section */\n\n')
for sec, pid, ph in (("PBXResourcesBuildPhase", "A1000022", "Resources"), ("PBXSourcesBuildPhase", "A1000021", "Sources")):
    o.append(f"/* Begin {sec} section */\n\t\t{pid} /* {ph} */ = {{\n\t\t\tisa = {sec};\n\t\t\tbuildActionMask = 2147483647;\n\t\t\tfiles = (\n")
    o.extend(f"\t\t\t\t{bf} /* {n} in {ph} */,\n" for n, ref, bf, p in entries if p == ph)
    o.append(f"\t\t\t);\n\t\t\trunOnlyForDeploymentPostprocessing = 0;\n\t\t}};\n/* End {sec} section */\n\n")
def target_cfg(id_, name):
    return f'''\t\t{id_} /* {name} */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEVELOPMENT_TEAM = "";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = NO;
\t\t\t\tINFOPLIST_FILE = SudokuGame/Info.plist;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.ashrafnaim.sudoku;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = {name};
\t\t}};
'''
o.append("/* Begin XCBuildConfiguration section */\n" + proj_debug + proj_release + target_cfg("A1000027", "Debug") + target_cfg("A1000028", "Release") + "/* End XCBuildConfiguration section */\n\n")
o.append('''/* Begin XCConfigurationList section */
\t\tA1000020 /* Build configuration list for PBXNativeTarget "SudokuGame" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tA1000027 /* Debug */,
\t\t\t\tA1000028 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\tA1000024 /* Build configuration list for PBXProject "SudokuGame" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\tA1000025 /* Debug */,
\t\t\t\tA1000026 /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */
\t};
\trootObject = A1000023 /* Project object */;
}
''')
open(f"{root}/SudokuGame.xcodeproj/project.pbxproj", "w").write("".join(o))
print(len(entries), "files")
