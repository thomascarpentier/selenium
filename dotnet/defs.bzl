#load("//dotnet/private:assembly_info.bzl", _generated_assembly_info = "generated_assembly_info")
#load("//dotnet/private:executable_assembly.bzl", _csharp_executable = "csharp_executable")
load("//dotnet/private:dotnet_nunit_test_suite.bzl", _dotnet_nunit_test_suite = "dotnet_nunit_test_suite")
load("//dotnet/private:dotnet_tool.bzl", _dotnet_tool = "dotnet_tool")
load("//dotnet/private:generate_devtools.bzl", _generate_devtools = "generate_devtools")
load("//dotnet/private:nuget_pack.bzl", _nuget_pack = "nuget_pack")
load("//dotnet/private:nuget_push.bzl", _nuget_push = "nuget_push")
load(":selenium-dotnet-version.bzl", "SUPPORTED_DEVTOOLS_VERSIONS")

def devtools_version_targets():
    targets = []
    for devtools_version in SUPPORTED_DEVTOOLS_VERSIONS:
        targets.append("//dotnet/src/webdriver/cdp:generate-{}".format(devtools_version))
    return targets

def framework(framework_moniker, name):
    return "@paket.dotnet_deps_%s//%s" % (framework_moniker, name.lower())

DEFAULT_FRAMEWORKS = [
    "net5.0",
    "net6.0",
]

dotnet_tool = _dotnet_tool
dotnet_nunit_test_suite = _dotnet_nunit_test_suite

#generated_assembly_info = _generated_assembly_info
#csharp_executable = _csharp_executable
generate_devtools = _generate_devtools

#merged_assembly = _merged_assembly
#nuget_package = _nuget_package
nuget_pack = _nuget_pack
nuget_push = _nuget_push

#nunit_test = _nunit_test
