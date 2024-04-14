const int TILEWIDTH = 64;
const int TILEHEIGHT = 56;

debug const int WAITTIME = 800;
else const int WAITTIME = 1600;

enum Action:ubyte {Nothing, Move, Attack, Items, EndTurn};

const uint FLUID_VERSION_MAJOR = CheckFluidVersion();

uint CheckFluidVersion() {
    import std.json, std.file, std.conv, std.algorithm;
    string DUBSelectionsFileText = import("dub.selections.json");
    JSONValue DUBSelections = parseJSON(DUBSelectionsFileText);
    uint FluidVersion;
    if ("versions" in DUBSelections && "fluid" in DUBSelections["versions"]) {
        string versionString = DUBSelections["versions"]["fluid"].get!string;
        FluidVersion = versionString.until(".").to!int;
    }
    return FluidVersion;
}