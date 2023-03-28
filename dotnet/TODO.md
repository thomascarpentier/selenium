# TODO as we migrate to the new `rules_dotnet`

We have the following tasks remaining:

## Clean up the existing code

Clean up the existing PR so we can build on all supported platforms.

## Isolate our rules when they use the `dotnet` binary

You can see the problem when running a build on the local machine
and have a local .Net installation which defaults to (eg.) .Net 7.

Alternatively attempt to run the following if you can directly 
access the RBE:

`bazel build //dotnet/src/webdriver:publish --config=remote`
