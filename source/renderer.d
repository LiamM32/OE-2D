debug {
    import std.stdio;
    import std.conv;
}
import std.algorithm;
import std.datetime.stopwatch;

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
    import raylib: MouseButton, KeyboardKey;
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
    version (customgui) UIElement[] gui;
    
    Camera2D camera;
    bool cursorOnMap;
    VisibleTile cursorTile;

    Unit selectedUnit;
    StopWatch missionTimer;

    VisibleUnit[][] unitsByRow; // Note: The outer array is by vertical screen-space tile location, while the inner row is unsorted.
    VisibleUnit[] unitsToMove; // A cache for units that have just moved tiles.

    protected alias onMap = cursorOnMap;

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
            version(raylib) {
                BeginDrawing();
                ClearBackground(Colors.BLACK);
            }
            updateCameraMouse();
            version(raylib) BeginMode2D(camera);
            
            for(int y=0; y<gridSize.y; y++) {
                for(int x=0; x<gridSize.x; x++) {
                    VisibleTile tile = cast(VisibleTile)getTile(x,y);
                    version(raylib) DrawTextureV(tile.sprites[0], tile.origin, Colors.WHITE);
                }
                foreach(unit; unitsByRow[y]) unit.draw;
            }

            switch (map.getPhase) {
                case GamePhase.PlayerTurn: renderPlayerTurn; break;
                default: break;
            }

            EndMode2D();

            onMap = true;
            version(fluid) uiRoot.draw;

            version(raylib) EndDrawing();
        }
    }

    version(fluid) void setupPreparation() {
        import std.file, std.json;
        
        missionTimer = StopWatch(AutoStart.yes);

        UnitInfoCard[] unitCards;
        foreach (unitData; parseJSON(readText("Units.json")).array) {
            VisibleUnit unit = new VisibleUnit(map, unitData, playerFaction);
            unitCards ~= new UnitInfoCard(unit);
        }
        Frame unitSelection = grid(paperTheme, .layout!("center","start"), unitCards);

        uiRoot.addChild(unitSelection, MapPosition(
            coords: Vector2(GetScreenWidth/2, GetScreenHeight),
            drop: MapDropVector(MapDropDirection.center, MapDropDirection.end)
        ));

        auto startButtonSlot = new ConditionalNodeSlot(
            delegate() @safe {
                return (missionTimer.peek > msecs(WAITTIME));
            },
            button("Start Mission", delegate() @safe {
                uiRoot.children = null;
                map.endTurn;
            })
        );
        uiRoot.addChild(startButtonSlot, MapPosition(
            coords: Vector2(GetScreenWidth, GetScreenHeight-96),
            drop: MapDropVector(MapDropDirection.end, MapDropDirection.start)
        ));

        uiRoot.updateSize();
    }
    version (customgui) void setupPreparation() {

    }

    void setupPlayerTurn() {
        NodeSlot!Frame floatingMenu;
        
        Button endTurnButton = button("End turn", delegate {getGridCoordinates(Vector2(0,0),true);});
        
        uiRoot.children ~= floatingMenu;
        uiRoot.children ~= endTurnButton;
    }

    protected void renderPlayerTurn() {
        Vector2i cursorLocation = getGridCoordinates(GetMousePosition, true);
        cursorTile = onMap ? cast(VisibleTile)getTile(cursorLocation, true) : null;
        if (cursorTile !is null && cursorOnMap) DrawRectangleRec(cursorTile.rect, Colours.Highlight);
    }

    void updateCameraMouse (Rectangle mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight)) { 
        alias mousePosition = GetMousePosition;
        
        Vector2i mouseLocation = getGridCoordinates(mousePosition, true);
        cursorTile = cast(VisibleTile)map.getTile(mouseLocation, true);
        
        Vector2 targetOffset;
        
        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_RIGHT)) {
            targetOffset = GetMouseDelta();
        } else {
            float framelength = GetFrameTime();
            if (IsKeyDown(KeyboardKey.KEY_A)) {
                targetOffset.x = -framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_D)) {
                targetOffset.x = framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_W)) {
                targetOffset.y = -framelength * 24.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_S)) {
                targetOffset.y = framelength * 24.0;
            }
        }
        camera.target -= targetOffset;

        auto mapArea = Rectangle(0, 0, map.getWidth*TILEWIDTH, map.getLength*TILEHEIGHT);

        Vector2 margins = {0, 0}; // This step can later be reworked to happen less frequently.
        if (mapArea.width < mapView.width) margins.x = (mapView.width-mapArea.width)/2;
        if (mapArea.height < mapView.height) margins.y = (mapView.height-mapArea.height)/2;

        Vector2 topLeftPosition = GetScreenToWorld2D(Vector2(mapView.x, mapView.y), camera);
        Vector2 bottomRightPosition = GetScreenToWorld2D(Vector2(mapView.x+mapView.width, mapView.y+mapView.height), camera);
        if (topLeftPosition.x < (mapArea.x - margins.x)) camera.target.x -= topLeftPosition.x - margins.x;
        else if (bottomRightPosition.x > mapArea.width + margins.x) camera.target.x -= bottomRightPosition.x + margins.x - mapArea.width;
        if (topLeftPosition.y < (mapArea.y - margins.y)) camera.target.y -= topLeftPosition.y + margins.y;
        else if (bottomRightPosition.y > (mapArea.y + mapArea.height)) camera.target.y -= bottomRightPosition.y - (mapArea.y + mapArea.height + margins.y);
    }

    Vector2i getGridCoordinates(Vector2 inputPosition, const bool fromScreen) @trusted {
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