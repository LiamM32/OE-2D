debug {
    import std.stdio;
    import std.conv;
}
import std.algorithm;

version (raylib) import raylib;
import oe.common;
import oe.map;
import oe.faction;
import vunit;
import vtile;
import constants;
import sprite;

version (fluid) {
    import fluid;
    import ui_fluid;
}
version (customgui) {
    import ui;
    import ui_specialized;
}

class Renderer
{
    static Renderer instance;
    
    Map map;
    Faction playerFaction;

    alias this = map;

    version (fluid) MapFrame uiRoot;
    
    Camera2D camera;
    bool cursorOnMap;
    Tile cursorTile;

    Unit selectedUnit;

    VisibleUnit[][] unitsByRow; // Note: The outer array is by vertical screen-space tile location, while the inner row is unsorted.
    VisibleUnit[] unitsToMove; // A cache for units that have just moved tiles.

    this(Map map, Faction playerFaction) {
        this.map = map;
        this.playerFaction = playerFaction;

        camera = Camera2D(zoom:1.0f, rotation:0.0f);
        camera.offset = Vector2(GetScreenWidth/2, GetScreenHeight/2);
        camera.target = Vector2(map.getWidth*TILEWIDTH/2, map.getLength*TILEWIDTH/2);

        version (fluid) {
            auto theme = paperTheme;
            uiRoot = mapFrame(theme, .layout!("fill","fill"));
        }

        unitsByRow.length = map.getLength;
        foreach (unit; cast(VisibleUnit[])map.allUnits) {
            unitsByRow[cast(uint)(unit.feetPosition.y/TILEHEIGHT)] ~= unit;
        }

        setupPreparation;
    }

    void render() {
        Vector2i gridSize = map.getSize;

        while(!WindowShouldClose) {
            version(raylib) BeginDrawing();
            for(int y=0; y<gridSize.y; y++) {
                for(int x=0; x<gridSize.x; x++) {
                    VisibleTile tile = cast(VisibleTile)getTile(x,y);
                    DrawTextureV(tile.sprites[0], tile.origin, Colors.WHITE);
                }
                foreach(unit; unitsByRow[y]) unit.draw;
            }

            version(fluid) uiRoot.draw;

            version(raylib) EndDrawing();
        }
    }

    version(fluid) void setupPreparation() {
        import std.file, std.json;
        
        Frame unitSelection = grid(paperTheme, .layout!("center","start"));
        unitSelection.dropSize = Vector2(512, 96);

        foreach (unitData; parseJSON(readText("Units.json")).array) {
            VisibleUnit unit = new VisibleUnit(map, unitData, playerFaction);
            auto unitCard = new UnitInfoCard(unit);
            unitSelection ~= unitCard;
        }

        uiRoot.addChild(unitSelection, MapPosition(
            coords: Vector2(GetScreenWidth/2, GetScreenHeight-96),
            drop: MapDropVector(MapDropDirection.automatic, MapDropDirection.automatic)
        ));

        uiRoot.updateSize();
    }

    Vector2i getGridCoordinates(Vector2 inputPosition, const bool fromScreen) {
        if (fromScreen) inputPosition = inputPosition.GetScreenToWorld2D(camera);
        Vector2i result;
        result.x = cast(int)(inputPosition.x / TILEWIDTH);
        result.y = cast(int)(inputPosition.y / TILEHEIGHT);
        return result;
    }

    void sortUnits() {
        import std.array, std.algorithm;

        VisibleUnit[][int] destinations_units;
        foreach (unit; unitsToMove) {
            int newRow = getGridCoordinates(unit.feetPosition, false).y;
            destinations_units[newRow] ~= unit;
            int arrayPosition;
            if(unit.feetPosition.y%TILEHEIGHT > 0.5) {
                if ((arrayPosition = cast(int)unitsByRow[newRow+1].countUntil(unit)) != -1) unitsByRow[newRow+1].remove(arrayPosition); //unitsByRow[newRow+1][arrayPosition] = null; 
            } else if(unit.feetPosition.y%TILEHEIGHT < 0.5) {
                if ((arrayPosition = cast(int)unitsByRow[newRow-1].countUntil(unit)) != -1) unitsByRow[newRow-1].remove(arrayPosition); //unitsByRow[newRow-1][arrayPosition] = null; 
            } else throw new Exception("Neither condition met.");
        }
        foreach (i, rowUnits; unitsByRow) if (cast(int)i in destinations_units) {
            rowUnits ~= destinations_units[cast(int)i];
        }
    }
}