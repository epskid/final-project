// the ticker interface; a vtable for room-local objects

const Self = @This();

ptr: *anyopaque, // pointer to object implementer

// function pointers for implemented methods
tickFn: *const fn (ptr: *anyopaque, game: *Game) anyerror!void,
drawFn: *const fn (ptr: *const anyopaque) void,
shouldDespawnFn: *const fn (ptr: *const anyopaque) bool,

pub fn wrap(ptr: anytype) Self {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);
    if (ptr_info != .pointer) @compileError("ptr must be a pointer");
    if (ptr_info.pointer.size != .one) @compileError("ptr must be a single item pointer");

    // create vtable that calls original methods
    const wrapped = struct {
        pub fn tick(self_: *anyopaque, game: *Game) anyerror!void {
            const self: T = @ptrCast(@alignCast(self_));
            return try ptr_info.pointer.child.tick(self, game);
        }

        pub fn draw(self_: *const anyopaque) void {
            const self: T = @ptrCast(@constCast(@alignCast(self_)));
            return ptr_info.pointer.child.draw(self);
        }

        pub fn shouldDespawn(self_: *const anyopaque) bool {
            const self: T = @ptrCast(@constCast(@alignCast(self_)));
            return ptr_info.pointer.child.shouldDespawn(self);
        }
    };

    return .{
        .ptr = ptr,
        .tickFn = wrapped.tick,
        .drawFn = wrapped.draw,
        .shouldDespawnFn = wrapped.shouldDespawn,
    };
}

// expose methods
pub fn tick(self: Self, game: *Game) anyerror!void {
    return try self.tickFn(self.ptr, game);
}

pub fn draw(self: Self) void {
    return self.drawFn(self.ptr);
}

pub fn shouldDespawn(self: Self) bool {
    return self.shouldDespawnFn(self.ptr);
}

const Game = @import("game.zig");

const std = @import("std");
