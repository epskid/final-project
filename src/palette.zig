// the palette

inline fn fromInt(num: u32) rl.Color {
    return .{
        .r = num >> 16,
        .g = (num >> 8) & 0xFF,
        .b = num & 0xFF,
        .a = 0xFF,
    };
}

pub const x21181B = fromInt(0x21181B);
pub const x3B2027 = fromInt(0x3B2027);
pub const x7D3833 = fromInt(0x7D3833);
pub const xAB5130 = fromInt(0xAB5130);
pub const xCF752B = fromInt(0xCF752B);
pub const xF0B541 = fromInt(0xF0B541);
pub const xFFEE83 = fromInt(0xFFEE83);
pub const xC8D45D = fromInt(0xC8D45D);
pub const x63AB3F = fromInt(0x63AB3F);
pub const x3B7D4F = fromInt(0x3B7D4F);
pub const x2F5753 = fromInt(0x2F5753);
pub const x283540 = fromInt(0x283540);
pub const x1B1F21 = fromInt(0x1B1F21);
pub const x2B2B45 = fromInt(0x2B2B45);
pub const x3A3F5E = fromInt(0x3A3F5E);
pub const x4C6885 = fromInt(0x4C6885);
pub const x4FA4B8 = fromInt(0x4FA4B8);
pub const x92E8C0 = fromInt(0x92E8C0);
pub const xF5FFE8 = fromInt(0xF5FFE8);
pub const xDFE0E8 = fromInt(0xDFE0E8);
pub const xA3A7C2 = fromInt(0xA3A7C2);
pub const x686F99 = fromInt(0x686F99);
pub const x404973 = fromInt(0x404973);
pub const x2C354D = fromInt(0x2C354D);
pub const x14182E = fromInt(0x14182E);
pub const x4B1D52 = fromInt(0x4B1D52);
pub const x692464 = fromInt(0x692464);
pub const x9C2A70 = fromInt(0x9C2A70);
pub const xCC2F7B = fromInt(0xCC2F7B);
pub const xFF5277 = fromInt(0xFF5277);
pub const xFFC2A1 = fromInt(0xFFC2A1);
pub const xFF8933 = fromInt(0xFF8933);
pub const xE64539 = fromInt(0xE64539);
pub const xAD2F45 = fromInt(0xAD2F45);
pub const x781D4F = fromInt(0x781D4F);
pub const x4F1D4C = fromInt(0x4F1D4C);
pub const x291D2B = fromInt(0x291D2B);
pub const x3D2936 = fromInt(0x3D2936);
pub const x52333F = fromInt(0x52333F);
pub const x8F4D57 = fromInt(0x8F4D57);
pub const xBD6A62 = fromInt(0xBD6A62);
pub const xFFAE70 = fromInt(0xFFAE70);

const rl = @import("raylib");
