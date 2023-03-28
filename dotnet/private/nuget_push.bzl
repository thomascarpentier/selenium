load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(":dotnet_utils.bzl", "dotnet_preamble")
load(":providers.bzl", "NugetPackageInfo")

def _nuget_push_impl(ctx):
    script = ctx.actions.declare_file("%s.sh" % ctx.label.name)

    toolchain = ctx.toolchains["@rules_dotnet//dotnet:toolchain_type"]
    dotnet = toolchain.runtime.files_to_run.executable
    package = ctx.attr.src[NugetPackageInfo].package

    content = """#!/usr/bin/env bash
set -eufo pipefail
set -x

{preamble}

"$DOTNET" nuget push -k '{api_key}' --skip-duplicate -s {server} {path}
""".format(
        api_key = ctx.attr.api_key[BuildSettingInfo].value,
        path = package.path,
        preamble = dotnet_preamble(toolchain),
        server = ctx.attr.package_repository_url,
    )

    ctx.actions.write(
        output = script,
        content = content,
        is_executable = True,
    )

    return [
        DefaultInfo(
            executable = script,
            files = depset([script]),
            runfiles = ctx.runfiles(
                files = [script, package] + toolchain.dotnetinfo.runtime_files,
            ),
        ),
    ]

nuget_push = rule(
    _nuget_push_impl,
    executable = True,
    attrs = {
        "src": attr.label(
            mandatory = True,
            allow_single_file = True,
            providers = [
                [NugetPackageInfo],
            ],
        ),
        "package_repository_url": attr.string(
            default = "https://nuget.org",
        ),
        "api_key": attr.label(
            mandatory = True,
        ),
    },
    toolchains = ["@rules_dotnet//dotnet:toolchain_type"],
)
