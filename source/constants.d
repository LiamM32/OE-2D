const int TILEWIDTH = 64;
const int TILEHEIGHT = 56;

debug const int WAITTIME = 800;
else const int WAITTIME = 1600;

enum Action:ubyte {nothing, moving, attacking, items, endTurn};

const uint FLUID_VERSION = 7;
/*const uint FLUID_VERSION = CheckFluidVersion();

uint CheckFluidVersion() {
    import std.json, std.file, std.conv, std.algorithm;
    string DUBSelectionsFileText = import("dub.selections.json");
    JSONValue DUBSelections = parseJSON(DUBSelectionsFileText);
    uint FluidVersion;
    if ("versions" in DUBSelections && "fluid" in DUBSelections["versions"] && DUBSelections["versions"]["fluid"].type == JSONType.string) {
        string versionString = DUBSelections["versions"]["fluid"].get!string;
        FluidVersion = versionString.until(".").to!int;
    }
    return FluidVersion;
}*/

import raylib: Color, Colors;
enum Colours {
    shadow = Color(r:0, b:0, g:0, a:150),
    whitelight = Color(245, 245, 245, 32),
    bluelight = Color(180, 200, 255, 24),
    goldlight = Color(250, 250, 60, 35),
    paper = Color(r:240, b:210, g:234, a:240),
    crimson = Color(160, 7, 16, 255),
}