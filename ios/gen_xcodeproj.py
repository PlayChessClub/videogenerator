#!/usr/bin/env python3
"""Generate ClipForgeiOS.xcodeproj/project.pbxproj with a local Swift Package dependency on ../ClipForgeCore.

Scans ClipForgeiOS/Sources for *.swift and wires them into a single iOS app target
(min iOS 16.0). Re-run after adding/removing App sources.
"""
import glob
import os
import uuid

BASE = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(BASE, "ClipForgeiOS")
SRC_ROOT = os.path.join(APP_DIR, "Sources")
OUT = os.path.join(APP_DIR, "ClipForgeiOS.xcodeproj", "project.pbxproj")

# stable uuid generator
def uid():
    return uuid.uuid4().hex[:24].upper()

files = sorted(glob.glob(os.path.join(SRC_ROOT, "**", "*.swift"), recursive=True))
if not files:
    raise SystemExit("no swift sources found under " + SRC_ROOT)

file_uuid = {f: uid() for f in files}
build_uuid = {f: uid() for f in files}

app_ref = uid()
core_pkg_ref = uid()          # PBXFileReference for ../ClipForgeCore
local_pkg_ref = uid()         # XCLocalSwiftPackageReference
pkg_dep = uid()               # XCSwiftPackageProductDependency -> ClipForgeCore
src_phase = uid()
fw_phase = uid()
res_phase = uid()
app_target = uid()
app_cfg_list = uid()
proj_cfg_list = uid()
main_group = uid()
app_group = uid()
proj = uid()
app_debug = uid()
app_release = uid()
proj_debug = uid()
proj_release = uid()

def relpath(f):
    return os.path.relpath(f, SRC_ROOT)

file_refs = []
build_files = []
for f in files:
    r = relpath(f)
    file_refs.append(
        f'\t{file_uuid[f]} /* {r} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
        f'path = {r}; sourceTree = "<group>"; }};\n'
    )
    build_files.append(
        f'\t\t{build_uuid[f]} /* {r} in Sources */,\n'
    )

file_refs.append(
    f'\t{app_ref} /* ClipForgeiOS.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; '
    f'includeInIndex = 0; path = ClipForgeiOS.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n'
)
file_refs.append(
    f'\t{core_pkg_ref} /* ClipForgeCore */ = {{isa = PBXFileReference; lastKnownFileType = folder:package.swift; '
    f'name = ClipForgeCore; path = ../ClipForgeCore; sourceTree = "<group>"; }};\n'
)

file_refs_str = "".join(file_refs)
build_files_str = "".join(build_files)

# app group children
app_children = "".join(f"\t\t\t\t{file_uuid[f]} /* {relpath(f)} */,\n" for f in files)

pbx = f"""// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{build_files_str}\t/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_refs_str}\t/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{src_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{build_files_str}\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{fw_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
\t\t{res_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_group},
\t\t\t\t{core_pkg_ref} /* ClipForgeCore */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{app_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{app_children}\t\t\t);
\t\t\tpath = Sources;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{app_target} /* ClipForgeiOS */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {app_cfg_list};
\t\t\tbuildPhases = (
\t\t\t\t{src_phase} /* Sources */,
\t\t\t\t{fw_phase} /* Frameworks */,
\t\t\t\t{res_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = ClipForgeiOS;
\t\t\tpackageProductDependencies = (
\t\t\t\t{pkg_dep} /* ClipForgeCore */,
\t\t\t);
\t\t\tproductName = ClipForgeiOS;
\t\t\tproductReference = {app_ref};
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin XCSwiftPackageProductDependency section */
\t\t{pkg_dep} /* ClipForgeCore */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {local_pkg_ref};
\t\t\tproductName = ClipForgeCore;
\t\t}};
/* End XCSwiftPackageProductDependency section */

/* Begin XCLocalSwiftPackageReference section */
\t\t{local_pkg_ref} /* ClipForgeCore */ = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = ../ClipForgeCore;
\t\t}};
/* End XCLocalSwiftPackageReference section */

/* Begin PBXProject section */
\t\t{proj} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 2600;
\t\t\t\tTargetAttributes = {{
\t\t\t\t\t{app_target} = {{
\t\t\t\t\t\tCreatedOnToolsVersion = 26.6;
\t\t\t\t\t}};
\t\t\t\t}};
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_cfg_list};
\t\t\tcompatibilityVersion = "Xcode 16.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tminimizedProjectReferenceProxies = 1;
\t\t\tpackageReferences = (
\t\t\t\t{local_pkg_ref} /* ClipForgeCore */,
\t\t\t);
\t\t\tproductRefGroup = {app_group};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{app_target} /* ClipForgeiOS */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin XCConfigurationList section */
\t\t{app_cfg_list} /* Build configuration list for PBXNativeTarget "ClipForgeiOS" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{app_debug} /* Debug */,
\t\t\t\t{app_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{proj_cfg_list} /* Build configuration list for PBXProject "ClipForgeiOS" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_debug} /* Debug */,
\t\t\t\t{proj_release} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

/* Begin XCBuildConfiguration section */
\t\t{app_debug} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.7.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.clipforge.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphonesimulator;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{app_release} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 1.7.3;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.clipforge.ios;
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphonesimulator;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{proj_debug} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tSDKROOT = iphonesimulator;
\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tUSE_HEADERMAP = NO;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{proj_release} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;
\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tSDKROOT = iphonesimulator;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tUSE_HEADERMAP = NO;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */
\t}};
\trootObject = {proj};
}}
"""

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as fp:
    fp.write(pbx)
print("wrote", OUT, "with", len(files), "swift files")
