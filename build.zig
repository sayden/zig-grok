const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const exe = b.addExecutable("main", "main.zig");

    exe.addIncludeDir("/usr/include/tirpc");
    exe.addIncludeDir("/home/caster/software/grok");
    exe.addIncludeDir("/usr/include");

    exe.linkSystemLibrary("grok");
    exe.linkLibC();

    b.default_step.dependOn(&exe.step);

    const run_cmd = exe.run();

    const test_step = b.step("main", "Test the program");
    test_step.dependOn(&run_cmd.step);
}
