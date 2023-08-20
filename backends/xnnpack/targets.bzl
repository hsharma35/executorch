load("@fbsource//xplat/executorch/backends/xnnpack/third-party:third_party_libs.bzl", "third_party_dep")
load("@fbsource//xplat/executorch/build:runtime_wrapper.bzl", "runtime")

def define_common_targets():
    runtime.cxx_library(
        name = "dynamic_quant_utils",
        srcs = [
            "runtime/utils/utils.cpp",
        ],
        exported_headers = ["runtime/utils/utils.h"],
        deps = [
            "//executorch/runtime/core/exec_aten:lib",
            "//executorch/runtime/backend:backend_registry",
        ],
        visibility = [
            "//executorch/backends/xnnpack/...",
            "@EXECUTORCH_CLIENTS",
        ],
    )

    runtime.genrule(
        name = "gen_xnnpack_schema",
        srcs = [
            "serialization/schema.fbs",
        ],
        # We're only generating a single file, so it seems like we could use
        # `out`, but `flatc` takes a directory as a parameter, not a single
        # file. Use `outs` so that `${OUT}` is expanded as the containing
        # directory instead of the file itself.
        outs = {
            "xnnpack_schema_generated.h": ["schema_generated.h"],
        },
        cmd = " ".join([
            "$(exe {})".format(runtime.external_dep_location("flatc")),
            "--cpp",
            "--cpp-std c++11",
            "--scoped-enums",
            "-o ${OUT}",
            "${SRCS}",
        ]),
        default_outs = ["."],
    )

    runtime.cxx_library(
        name = "xnnpack_schema",
        srcs = [],
        exported_headers = {
            "xnnpack_schema_generated.h": ":gen_xnnpack_schema[xnnpack_schema_generated.h]",
        },
        exported_external_deps = ["flatbuffers-api"],
    )

    runtime.cxx_library(
        name = "xnnpack_backend",
        srcs = native.glob([
            "runtime/*.cpp",
        ]),
        headers = native.glob([
            "runtime/*.h",
        ]),
        visibility = [
            "//executorch/exir/backend:backend_lib",
            "//executorch/exir/backend/test/...",
            "//executorch/backends/xnnpack/test/...",
            "//executorch/extension/pybindings/...",
            "@EXECUTORCH_CLIENTS",
        ],
        deps = [
            third_party_dep("XNNPACK"),
            ":xnnpack_schema",
            ":dynamic_quant_utils",  # TODO Use (1) portable for choose_qparams(), (2) xnnpack for quantize_per_tensor(),
            "//executorch/runtime/backend:backend_registry",
            "//executorch/backends/xnnpack/threadpool:threadpool",
            "//executorch/util:memory_utils",
            "//executorch/runtime/core/exec_aten/util:tensor_util",
        ],
        # XnnpackBackend.cpp needs to compile with executor as whole
        # @lint-ignore BUCKLINT: Avoid `link_whole=True` (https://fburl.com/avoid-link-whole)
        link_whole = True,
    )
