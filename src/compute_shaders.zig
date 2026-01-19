// most loading code transcribed from https://github.com/raysan5/raylib/blob/master/examples/others/rlgl_compute_shader.c
// stand-alone general implementation of compute shaders

// compute shader that does not render anything
// isn't used directly as of the time i am writing this comment
// kept around in case i need it
pub fn HeadlessComputeShader(
    comptime Logic: type, // the type stored in the "logic" buffer(s) in the compute shader
    comptime Command: type, // the type used to send data to the GPU
    comptime logic_chunk_x: u32, // group size for each GPU core
    comptime logic_chunk_y: u32, // ^
    comptime logic_buffer_length: usize, // size of logic buffer
    comptime max_commands: usize, // how many commands can be buffered before sending
) type {
    return struct {
        const Self = @This();
        const Commands = extern struct {
            count: u32,
            commands: [max_commands]Command,
        };

        // shader program ids
        logic_program: u32,
        transfer_program: u32,

        // SSBOs
        buffer_a: u32,
        buffer_b: u32,
        buffer_commands: u32,

        // command buffer
        commands: Commands,

        // time uniform
        time: u32 = 0,

        pub fn load(logic: [:0]const u8, transfer: [:0]const u8) Self {
            // load logic shader
            const logic_source = rl.loadFileText(logic);
            defer rl.unloadFileText(logic_source);
            const logic_id = rl.gl.rlCompileShader(logic_source, rl.gl.rl_compute_shader);
            const logic_program = rl.gl.rlLoadComputeShaderProgram(logic_id);

            // load command shader
            const transfer_source = rl.loadFileText(transfer);
            defer rl.unloadFileText(transfer_source);
            const transfer_id = rl.gl.rlCompileShader(transfer_source, rl.gl.rl_compute_shader);
            const transfer_program = rl.gl.rlLoadComputeShaderProgram(transfer_id);

            return .{
                .logic_program = logic_program,
                .transfer_program = transfer_program,

                // initialize SSBOs
                .buffer_a = rl.gl.rlLoadShaderBuffer(logic_buffer_length * @sizeOf(Logic), null, rl.gl.rl_dynamic_copy),
                .buffer_b = rl.gl.rlLoadShaderBuffer(logic_buffer_length * @sizeOf(u32), null, rl.gl.rl_dynamic_copy),
                .buffer_commands = rl.gl.rlLoadShaderBuffer(@sizeOf(Commands), null, rl.gl.rl_dynamic_copy),

                .commands = .{
                    .count = 0,
                    .commands = undefined,
                },
            };
        }

        pub fn pushCommand(self: *Self, command: Command) void {
            // push a command to the buffer; flush to GPU if it's full
            if (self.commands.count == max_commands) self.writeCommands();
            self.commands.commands[self.commands.count] = command;
            self.commands.count += 1;
        }

        pub fn writeCommands(self: *Self) void {
            // write the command buffer to the transfer (command) shader

            {
                rl.gl.rlUpdateShaderBuffer(self.buffer_commands, &self.commands, @sizeOf(Commands), 0);

                rl.gl.rlEnableShader(self.transfer_program);
                defer rl.gl.rlDisableShader();

                rl.gl.rlBindShaderBuffer(self.buffer_a, 1);
                rl.gl.rlBindShaderBuffer(self.buffer_commands, 3);
                rl.gl.rlComputeShaderDispatch(self.commands.count, 1, 1);
            }

            self.commands.count = 0;
        }

        pub fn tick(self: *Self) void {
            // run the logic program once
            rl.gl.rlEnableShader(self.logic_program);
            rl.gl.rlSetUniform(0, &self.time, @intFromEnum(rl.gl.rlShaderUniformDataType.rl_shader_uniform_uint), 1);

            rl.gl.rlBindShaderBuffer(self.buffer_a, 1);
            rl.gl.rlBindShaderBuffer(self.buffer_b, 2);
            rl.gl.rlComputeShaderDispatch(logic_chunk_x, logic_chunk_y, 1);

            rl.gl.rlDisableShader();

            self.time = (self.time + 1) % 67;
        }

        pub fn readA(self: *const Self, dest: []Logic) void {
            // read SSBO a out into a provided buffer

            std.debug.assert(dest.len == logic_buffer_length);
            rl.gl.rlReadShaderBuffer(self.buffer_a, dest.ptr, logic_buffer_length * @sizeOf(Logic), 0);
        }

        pub fn readB(self: *const Self, comptime T: type, dest: []T) void {
            // read some of SSBO b out into a provided buffer
            rl.gl.rlReadShaderBuffer(self.buffer_b, dest.ptr, @intCast(dest.len * @sizeOf(T)), 0);
        }

        pub fn unload(self: *const Self) void {
            rl.gl.rlUnloadShaderBuffer(self.buffer_a);
            rl.gl.rlUnloadShaderBuffer(self.buffer_b);
            rl.gl.rlUnloadShaderBuffer(self.buffer_commands);

            rl.gl.rlUnloadShaderProgram(self.transfer_program);
            rl.gl.rlUnloadShaderProgram(self.logic_program);
        }
    };
}

// compute shader that renders the output SSBO as well
pub fn RenderedComputeShader(
    comptime Logic: type,
    comptime Command: type,
    comptime logic_chunk_x: u32,
    comptime logic_chunk_y: u32,
    comptime logic_buffer_length: usize,
    comptime max_commands: usize,
) type {
    return struct {
        const Self = @This();
        const ComputeShader = HeadlessComputeShader(Logic, Command, logic_chunk_x, logic_chunk_y, logic_buffer_length, max_commands);

        compute: ComputeShader,
        render: rl.Shader,
        render_texture: rl.Texture,

        pub fn load(logic: [:0]const u8, transfer: [:0]const u8, render: [:0]const u8) !Self {
            const image = rl.genImageColor(consts.width, consts.height, .white);
            defer rl.unloadImage(image);
            const renderer = try rl.loadShader(null, render);
            const render_texture = try rl.loadTextureFromImage(image);

            return .{
                .compute = ComputeShader.load(logic, transfer),
                .render = renderer,
                .render_texture = render_texture,
            };
        }

        pub fn draw(self: *const Self) void {
            const time: f32 = @floatCast(rl.getTime());
            rl.setShaderValue(self.render, 1, &time, .float);
            rl.gl.rlBindShaderBuffer(self.compute.buffer_a, 1);

            rl.beginShaderMode(self.render);
            defer rl.endShaderMode();

            rl.drawTexture(self.render_texture, 0, 0, .white);
        }

        pub fn unload(self: Self) void {
            rl.unloadShader(self.render);
            rl.unloadTexture(self.render_texture);
            self.compute.unload();
        }
    };
}

const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
