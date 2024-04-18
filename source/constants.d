const int TILEWIDTH = 64;
const int TILEHEIGHT = 56;

debug const int WAITTIME = 800;
else const int WAITTIME = 1600;

enum Action:ubyte {Nothing, Move, Attack, Items, EndTurn};

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