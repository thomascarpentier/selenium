load("@rules_dotnet//dotnet/private:providers.bzl", "DotnetAssemblyInfo")
load(":dotnet_utils.bzl", "dotnet_preamble")
load(":framework_transition.bzl", "target_framework_transition")
load(":providers.bzl", "NugetPackageInfo")

def _guess_dotnet_version(assembly_info):
    if len(assembly_info.libs) == 0:
        fail("Cannot guess .Net version without an output dll: ", assembly_info.name)

    # We're going to rely on the structure of the output names for now
    # rather than scanning through the dependencies. If this works,
    # life will be good.

    # The dirname will be something like `bazel-out/darwin_arm64-fastbuild-ST-5c013bc87029/bin/dotnet/src/webdriver/bazelout/net5.0`
    # Note that the last segment of the path is the framework we're
    # targeting. Happy days!
    full_path = assembly_info.libs[0].dirname

    # And that framework is after the constant string `bazelout`
    index = full_path.index("bazelout")
    guessed_version = full_path[index + len("bazelout") + 1:]
    return guessed_version

def _nuget_pack_impl(ctx):
    # A mapping of files to the paths in which we expect to find them in the package
    paths = {}

    for (lib, name) in ctx.attr.libs.items():
        assembly_info = lib[DotnetAssemblyInfo]

        for dll in assembly_info.libs:
            paths[dll] = "bin/Debug/%s/%s.dll" % (_guess_dotnet_version(assembly_info), name)
        for pdb in assembly_info.pdbs:
            paths[pdb] = "bin/Debug/%s/%s.pdb" % (_guess_dotnet_version(assembly_info), name)

    for (file, name) in ctx.attr.files.items():
        paths[file.files.to_list()[0]] = name

    # Generate a spoof csproj file so the dotnet tooling is happy later
    csproj_file = ctx.file.csproj_file

    # Zip everything up, and then unzip it into a temp directory
    zip_file = ctx.actions.declare_file("%s-intermediate.zip" % ctx.label.name)
    args = ctx.actions.args()
    args.add_all(["Cc", zip_file])
    args.add("%s.csproj=%s" % (ctx.attr.id, csproj_file.path))
    for (file, path) in paths.items():
        args.add("%s=%s" % (path, file.path))

    ctx.actions.run(
        executable = ctx.executable._zip,
        arguments = [args],
        inputs = paths.keys() + [ctx.file.csproj_file],
        outputs = [zip_file],
    )

    # Now we have everything, let's build our package
    toolchain = ctx.toolchains["@rules_dotnet//dotnet:toolchain_type"]

    dotnet = toolchain.runtime.files_to_run.executable
    pkg = ctx.actions.declare_file("%s.nupkg" % ctx.label.name)

    variables = ""
    for (key, value) in ctx.attr.property_group_vars.items():
        variables += " -p:%s=\"%s\" " % (key, value)

    cmd = dotnet_preamble(toolchain) + \
          "mkdir %s-working-dir && " % ctx.label.name + \
          "echo $(pwd) && " + \
          "$(location @bazel_tools//tools/zip:zipper) x %s -d %s-working-dir && " % (zip_file.path, ctx.label.name) + \
          "cd %s-working-dir && " % ctx.label.name + \
          "echo '<configuration><packageSources><clear /></packageSources></configuration>' && " + \
          "$DOTNET pack --no-build -p:PackageId=%s -p:Version=%s %s && " % (ctx.attr.id, ctx.attr.version, variables) + \
          "cp bin/Debug/%s.%s.nupkg ../%s" % (ctx.attr.id, ctx.attr.version, pkg.path)

    cmd = ctx.expand_location(
        cmd,
        targets = [
            ctx.attr._zip,
        ],
    )

    project_assembly_info = ctx.attr.project_sdk[DotnetAssemblyInfo]

    ctx.actions.run_shell(
        outputs = [pkg],
        inputs = [
            zip_file,
            dotnet,
        ],
        tools = [
            ctx.executable._zip,
            dotnet,
        ] + toolchain.default.files.to_list() + toolchain.runtime.default_runfiles.files.to_list() + toolchain.runtime.data_runfiles.files.to_list(),
        command = cmd,
        mnemonic = "CreateNupkg",
    )

    return [
        DefaultInfo(
            files = depset([pkg]),
            runfiles = ctx.runfiles(files = [pkg]),
        ),
        NugetPackageInfo(package = pkg),
    ]

nuget_pack = rule(
    _nuget_pack_impl,
    attrs = {
        "id": attr.string(
            doc = "Nuget ID of the package",
            mandatory = True,
        ),
        "version": attr.string(
            mandatory = True,
        ),
        "libs": attr.label_keyed_string_dict(
            doc = "The .Net libraries that are being published",
            providers = [DotnetAssemblyInfo],
        ),
        "files": attr.label_keyed_string_dict(
            doc = "Mapping of files to paths within the nuget package",
            allow_empty = True,
            allow_files = True,
        ),
        "property_group_vars": attr.string_dict(
            doc = "Keys and values for variables declared in `PropertyGroup`s in the `csproj_file`",
            allow_empty = True,
        ),
        "csproj_file": attr.label(
            doc = "The `.csproj` file to use when packaging",
            mandatory = True,
            allow_single_file = True,
        ),
        "project_sdk": attr.label(
            mandatory = True,
            providers = [DotnetAssemblyInfo],
        ),
        "_zip": attr.label(
            default = "@bazel_tools//tools/zip:zipper",
            executable = True,
            cfg = "exec",
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
    },
    cfg = target_framework_transition,
    toolchains = ["@rules_dotnet//dotnet:toolchain_type"],
)
