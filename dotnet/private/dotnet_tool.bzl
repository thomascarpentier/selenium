load("@bazel_skylib//lib:dicts.bzl", "dicts")
load(":framework_transition.bzl", "target_framework_transition")

def _dotnet_tool_impl(ctx):
    binary = ctx.attr.binary[0]
    default_info = binary[DefaultInfo]

    exe = default_info.files_to_run.executable

    script = """#!/usr/bin/env bash -x

{exe} $@
""".format(
        exe = exe.short_path,
    )
    output = ctx.actions.declare_file("%s.sh" % ctx.label.name)
    ctx.actions.write(
        output = output,
        content = script,
        is_executable = True,
    )

    return [
        DefaultInfo(
            files = depset([output]),
            runfiles = ctx.runfiles(files = [output, exe], transitive_files = default_info.files)
                .merge(default_info.default_runfiles),
            executable = output,
        ),
    ]

dotnet_tool = rule(
    _dotnet_tool_impl,
    attrs = {
        "binary": attr.label(
            cfg = target_framework_transition,
        ),
        "target_framework": attr.string(
            mandatory = True,
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    executable = True,
)
