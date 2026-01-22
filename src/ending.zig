// the ending screen
const Self = @This();

end_background: rl.Texture,
should_exit: bool,

pub fn init() !Self {
    return .{
        .end_background = try util.texFromImg("resources/images/backgrounds/end.png"),
        .should_exit = false,
    };
}

pub fn tick(self: *Self) !void {
    self.should_exit = rl.isKeyDown(.q);
}

pub fn draw(self: *const Self) void {
    // sorry for how this code looks
    // layouting is not raylib's strong suit...

    rl.drawTexture(self.end_background, 0, 0, .white);
    util.drawText("THE XYLYL HERALD - NEWS FROM ACROSS THE UNIVERSE", 16, 16, 12, .gray);
    util.drawText("LOCAL BUSINESS MOGUL TAKEN TO COURT", 16, 16 + 12, 24, .black);
    util.drawText("EXPERTS SAY YOU CAN PRESS 'Q' TO EXIT", 16, 16 + 10 + 24, 12, .dark_gray);
    rl.drawText(
        "A PROLIFIC ENTREPENEUR FROM ANDROMEDA HAS TURNED TO UNORTHODOX WAYS OF STOCKING HIS--\nEMPOURIUM OF RARITIES.",
        16,
        16 + 12 + 24 + 12 + 4,
        10,
        .black,
    );
    rl.drawText(
        "CORNELIOUS KIDNAPPER, NOW APPROACHING 4.5e3 YEARS OF AGE, HAS BEEN CHARGED WITH PLANETARY LARCENY.",
        16,
        16 + 12 + 24 + 12 + 4 + 12 + 12 + 4,
        10,
        .black,
    );
    rl.drawText(
        "THE CRAB NEBULA NATIVE ALLEGEDLY KIDNAPPED MASS AMOUNTS OF MILKY-WAY NATIVES (\"HUMANS\") TO--\nPERFORM HEISTS ON HIS BEHALF.",
        16,
        16 + 12 + 24 + 12 + 4 + 12 + 12 + 12 + 4,
        10,
        .black,
    );
    rl.drawText(
        "ASSISTING HIM WAS HIS SON, MALICIOUS KIDNAPPER III, GOING BY THE NAME \"STOXON BONDS\", A HUMAN NAME--\nNO DOUBT USED TO LULL THE HUMANS INTO A FALSE SENSE OF SECURITY.",
        16,
        16 + 12 + 24 + 12 + 4 + 12 + 12 + 12 + 12 + 12 + 4 + 4,
        10,
        .black,
    );
    rl.drawText(
        "TOGETHER, THEY ABDUCTED OVER TEN THOUSAND HUMANS AND RAIDED AND DESTROYED AT LEAST THREE MO--\nNUMENTS. THEIR ILL-GOTTEN GAINS WERE SOLD FOR EXORBITANT PRICES AT THEIR BUSINESS,\n\"KIDNAPPER & KIDNAPPER EMPOURIUM OF ILL-GOTTEN GAINS\"",
        16,
        16 + 12 + 24 + 12 + 4 + 12 + 12 + 12 + 12 + 12 + 12 + 12 + 4 + 4 + 4,
        10,
        .black,
    );
    rl.drawText(
        "AS A PUNISHMENT, THEY MUST DONATE ALL OF THEIR UNSOLD ARTIFACTS TO THE LOCAL MUSEUM.",
        16,
        16 + 12 + 24 + 12 + 4 + 12 + 12 + 12 + 12 + 12 + 12 + 12 + 12 + 12 + 12 + 4 + 4 + 4 + 4,
        10,
        .black,
    );

    util.drawText("GRAPHIC DESIGNER STRIKE ONGOING", 16, consts.height - 24 - 12, 24, .black);
    util.drawText("MUGSHOT PHOTOGRAPHERS JOIN IN SOLIDAARITY", 16, consts.height - 12, 12, .dark_gray);
}

pub fn getNewState(self: *const Self) ?s.NewStateInfo {
    if (self.should_exit) {
        return .{
            .new_state = .{
                .needs_init = .menu,
            },
            .deinit = true,
        };
    }

    return null;
}

pub fn deinit(self: *Self, _: std.mem.Allocator) void {
    rl.unloadTexture(self.end_background);
}

const s = @import("state.zig");
const util = @import("util.zig");
const consts = @import("consts.zig");

const rl = @import("raylib");
const std = @import("std");
