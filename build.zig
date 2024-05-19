const std = @import("std");
const sycl_badge = @import("sycl_badge");

const WasmPlatform = enum { js, badge };

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const puredoom_dep = b.dependency("puredoom", .{});
    const puredoom_path = puredoom_dep.path(".");

    {
        const exe = b.addExecutable(.{
            .name = "doom",
            .root_source_file = b.path("wasm.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .wasm32,
                .os_tag = .freestanding,
            }),
            .optimize = optimize,
        });

        {
            const options = b.addOptions();
            options.addOption(WasmPlatform, "platform", .js);
            exe.root_module.addOptions("build_options", options);
        }

        exe.entry = .disabled;
        //exe.import_memory = true;
        //exe.initial_memory = 89 * 65536;
        //exe.max_memory = exe.initial_memory;
        //exe.stack_size = 14752;
        exe.rdynamic = true;
        exe.root_module.addImport(
            "doom1wad",
            b.createModule(.{ .root_source_file = puredoom_dep.path("doom1.wad") }),
        );
        exe.addIncludePath(b.path("inc"));
        exe.addIncludePath(puredoom_path);
        exe.addCSourceFiles(.{
            .files = &.{
                "PureDOOM.c",
            },
            .flags = &doom_cflags,
        });
        exe.addCSourceFiles(.{
            .files = &.{
                "printf.c",
            },
        });

        const make_doom_exe = b.addExecutable(.{
            .name = "makedoomhtml",
            .root_source_file = b.path("makedoomhtml.zig"),
            .target = b.host,
        });

        //b.installArtifact(make_doom_exe);
        //b.step("a", "tmp stemp").dependOn(&make_doom_exe.step);

        const run_make_html = b.addRunArtifact(make_doom_exe);
        run_make_html.addArtifactArg(exe);
        run_make_html.addFileArg(b.path("doom.template.html"));
        const out_file = run_make_html.addOutputFileArg("doom.html");
        const install_doom_html = b.addInstallFile(out_file, "doom.html");

        const wasm_step = b.step("wasm", "Build the wasm version/webpage");
        wasm_step.dependOn(&install_doom_html.step);
        //b.getInstallStep().dependOn(&install_doom_html.step);
    }

    {
        const sycl_badge_dep = b.dependency("sycl_badge", .{});
        const cart = sycl_badge.add_cart(sycl_badge_dep, b, .{
            .name = "doom",
            .optimize = optimize,
            .root_source_file = b.path("syclbadge.zig"),
        });
        //cart.wasm.initial_memory = 65 * 65536;
        cart.wasm.initial_memory = 64 * 65536;
        cart.wasm.max_memory = cart.wasm.initial_memory;

        const emdoom_dep = b.dependency("embedded_doom", .{});
        const emdoom_path = emdoom_dep.path(".");

        for ([2]*std.Build.Step.Compile{ cart.wasm, cart.cart_lib}) |artifact| {
            {
                const options = b.addOptions();
                options.addOption(WasmPlatform, "platform", .badge);
                artifact.root_module.addOptions("build_options", options);
            }
            //artifact.root_module.addImport(
            //    "doom1wad",
            //    b.createModule(.{ .root_source_file = puredoom_dep.path("doom1.wad") }),
            //);
            artifact.addCSourceFiles(.{
                .root = emdoom_path,
                .files = &.{
                    "src/i_main.c",
                    //"src/d_main.c",
                },
            });
//            //artifact.addIncludePath(puredoom_path);
            artifact.addIncludePath(b.path("inc"));
//            artifact.addCSourceFiles(.{
//                .files = &.{
//                    "PureDOOM.c",
//                },
//                .flags = &doom_cflags,
//            });
//            artifact.addCSourceFiles(.{
//                .files = &.{
//                    "printf.c",
//                },
//            });
        }
        //cart.install(b);
        b.step("badge-wasm", "").dependOn(&b.addInstallArtifact(cart.wasm, .{}).step);
        b.step("badge-watch", "").dependOn(
            &cart.install_with_watcher(sycl_badge_dep, b, .{
                .build_firmware = false
            }).step,
        );
        //const fw = b.step("badge-fw", "");
        //fw.dependOn(cart.fw.add
        //c.mz.install_firmware(b, c.fw, .{ .format = .elf });
        cart.mz.install_firmware(b, cart.fw, .{ .format = .{ .uf2 = .SAMD51 } });
    }

    {
        const exe = b.addExecutable(.{
            .name = "doom",
            .root_source_file = b.path("mainnative.zig"),
            .target = target,
            .optimize = optimize,
        });
        exe.linkLibC();
        exe.addIncludePath(puredoom_path);
        exe.addCSourceFiles(.{
            .files = &.{
                "PureDOOM.c",
            },
            .flags = &doom_cflags,
        });
        const install = b.addInstallArtifact(exe, .{});
        b.step("native", "Build native exe").dependOn(&install.step);

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }

    {
        const exe = b.addExecutable(.{
            .name = "readwad",
            .root_source_file = b.path("readwad.zig"),
            .target = target,
            .optimize = optimize,
        });
        const install = b.addInstallArtifact(exe, .{});
        b.step("readwad", "Build readwad").dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }
}

const doom_cflags = [_][]const u8 {
    "-Wno-parentheses",
    "-Wno-strict-prototypes",
    "-fno-sanitize=alignment",
    "-fno-sanitize=undefined",
    "-std=c89",
};
