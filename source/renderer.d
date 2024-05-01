debug {
    import std.stdio;
    import std.conv;
}
import std.algorithm;
import std.array;
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
    import ui, ui_specialized;
}

class Renderer
{
    static Renderer instance;
    
    Map map;
    Faction playerFaction;
    Vector2i screenSize;

    //alias this = map;

    VisibleTile[][] grid;

    version (fluid) {
        MapFrame uiRoot;
        protected ConditionalNodeSlot!Button nextTurnSlot;
    }
    version (customgui) UIElement[] gui;
    
    Camera2D camera;
    Rectangle mapView;
    bool cursorOnMap;
    VisibleTile cursorTile;

    VisibleUnit selectedUnit;
    StopWatch missionTimer;

    VisibleUnit[][] unitsByRow; // Note: The outer array is by vertical screen-space tile location, while the inner row is unsorted.
    VisibleUnit[] unitsToMove; // A cache for units that have just moved tiles.

    void delegate() actionAfterDraw;

    protected alias onMap = cursorOnMap;

    this(Map map, Faction playerFaction) {
        this.instance = this;
        
        this.map = map;
        this.playerFaction = playerFaction;

        screenSize.x = cast(int)GetScreenWidth();
        screenSize.y = cast(int)GetScreenHeight();

        this.grid.length = map.getWidth;
        foreach(x, column; cast(VisibleTile[][])map.getGrid) {
            foreach(y, tile; column) this.grid[x] ~= tile;
        }

        camera = Camera2D(zoom:1.0f, rotation:0.0f);
        camera.offset = Vector2(screenSize.x/2, screenSize.y/2);
        camera.target = Vector2(map.getWidth*TILEWIDTH/2, map.getLength*TILEWIDTH/2);

        version (fluid) {
            nextTurnSlot = new ConditionalNodeSlot!Button(null);
            uiRoot = mapFrame(paperTheme, .layout!("fill","fill"));
            uiRoot.addChild(nextTurnSlot, MapPosition(
                Vector2(screenSize.x, screenSize.y),
                drop: MapDropVector(MapDropDirection.end, MapDropDirection.end)
            ));
        }

        unitsByRow.length = map.getLength;
        foreach (unit; cast(VisibleUnit[])map.allUnits) {
            unitsByRow[cast(uint)(unit.feetPosition.y/TILEHEIGHT)] ~= unit;
        }

        mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight);

        setupPreparation;
    }

    void render() {
        Vector2i gridSize = map.getSize;
        

        while(!WindowShouldClose) {
            updateCameraMouse();
            version(raylib) {
                BeginDrawing();
                ClearBackground(Colors.BLACK);
            }
            
            version(raylib) BeginMode2D(camera);
            
            for(int y=0; y<gridSize.y; y++) {
                for(int x=0; x<gridSize.x; x++) {
                    VisibleTile tile = grid[x][y];
                    version(raylib) {
                        DrawTextureV(tile.sprites[0], tile.origin, Colors.WHITE);
                        foreach(highlight; tile.highlights) DrawRectangleRec(tile.rect, highlight);
                    }
                }
                if (map.getPhase==GamePhase.PlayerTurn && cursorTile !is null && cursorTile.location.y==y) {
                    DrawRectangleRec(cursorTile.rect, Colours.whitelight);
                }
                foreach(unit; unitsByRow[y]) unit.draw;
            }

            switch (map.getPhase) {
                case GamePhase.PlayerTurn: cyclePlayerTurn; break;
                default: break;
            }

            EndMode2D();

            onMap = true;
            version(fluid) uiRoot.draw;

            version(raylib) EndDrawing();

            if (actionAfterDraw !is null) {
                actionAfterDraw();
                actionAfterDraw = null;
            }
        }
    }

    void setupPreparation() {
        import std.file, std.json, mission;

        mapView.height = GetScreenHeight - 96;
        
        missionTimer = StopWatch(AutoStart.yes);

        // Todo: This should later be changed when the `Mission` class is removed.
        auto startTiles = (cast(Mission)map).startingTiles;
        foreach(tile; startTiles) {
            tile.highlights = [Colours.goldlight];
        }

        auto unitCards = new GCArray!UnitInfoCard;
        //UnitInfoCard[] unitCards = new UnitInfoCard[0];
        foreach (unitData; parseJSON(readText("Units.json")).array) {
            VisibleUnit unit = new VisibleUnit(map, unitData, playerFaction);
            unitCards ~= new UnitInfoCard(unit);
        }

        version (customgui) {

        }
        version (fluid) {
            Frame unitSelection = fluid.grid.grid(paperTheme, .layout!("center","start"), unitCards);

            uiRoot.addChild(unitSelection, MapPosition(
                coords: Vector2(screenSize.x/2, screenSize.y),
                drop: MapDropVector(MapDropDirection.center, MapDropDirection.end)
            ));

            debug if (canFind(unitCards, null)) throw new Exception("Empty cards");
            
            nextTurnSlot.condition = delegate() @safe {
                auto deployed = count!(card => card.unit.currentTile !is null)(unitCards);
                return (missionTimer.peek * deployed > msecs(WAITTIME) * startTiles.length);
            };
            nextTurnSlot = button("Start Mission", delegate() @safe {
                //uiRoot.children = null;
                map.endTurn();
                //Todo: This should later be removed when instead it's called using a delegate or signal in the `Map` object.
                actionAfterDraw = &setupPlayerTurn;
            });

            uiRoot.updateSize();
        }
    }

    void cyclePreparation() {
        if (selectedUnit !is null) DrawTextureV(selectedUnit.sprite, selectedUnit.position - TILESIZE, Colors.WHITE);
    }

    void setupPlayerTurn() @safe {
        foreach (tile; grid.join) tile.highlights.length = 0;

        Action currentAction = Action.nothing;
        
        version (fluid) {
            uiRoot.updateSize;
            
            foreach (node; uiRoot.children) if (node !is nextTurnSlot) {
                node.toRemove = true;
            }
            
            NodeSlot!Frame floatingMenu = nodeSlot!Frame();
            Button endTurnButton = button("End turn", delegate {
                map.endTurn;
            });

            nextTurnSlot.condition = delegate() {return (selectedUnit is null && currentAction == Action.nothing);};
            nextTurnSlot = endTurnButton;
            
            uiRoot.addChild(floatingMenu,
                MapPosition(
                    cast(Vector2)screenSize/2,
                    drop: MapDropVector(MapDropDirection.end, MapDropDirection.end)
                )
            );

            uiRoot.updateSize;
        }
        else version (customgui) {

        }
    }

    protected void cyclePlayerTurn() {
        
    }

    void updateCameraMouse() { 
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

class GCArray(T) {
    T[] array;
    alias this = array;
}