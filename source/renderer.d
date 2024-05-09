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
    import ui_custom;
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

    Turn turnObject;
    
    Camera2D camera;
    Rectangle mapView;
    bool cursorOnMap;
    Vector2 mousePosition;
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

        missionTimer = StopWatch(AutoStart.yes);

        setupPreparation;
    }

    void render() {
        Vector2i gridSize = map.getSize;

        Faction activeFaction;

        while(!WindowShouldClose) {
            if (map.activeFaction !is activeFaction) {
                activeFaction = map.activeFaction;
                if (activeFaction is playerFaction) setupPlayerTurn();
                else if (activeFaction !is null) {
                    destroy(turnObject);
                    turnObject = null;
                }
            }
            
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
                        tile.draw;
                        //DrawTextureV(tile.sprites[0], tile.origin, Colors.WHITE);
                        //foreach(highlight; tile.highlights) DrawRectangleRec(tile.rect, highlight);
                    }
                }
                if (map.getPhase==GamePhase.PlayerTurn && cursorTile !is null && cursorTile.location.y==y) {
                    DrawRectangleRec(cursorTile.rect, Colours.whitelight);
                }
                foreach(unit; unitsByRow[y]) unit.draw;
            }

            EndMode2D();

            onMap = true;
            version(fluid) uiRoot.draw;
            version(customgui) foreach (element; gui) element.draw;

            if (turnObject !is null) turnObject.drawTop;

            version(raylib) EndDrawing();

            if (actionAfterDraw !is null) {
                actionAfterDraw();
                actionAfterDraw = null;
            }
        }
    }

    void setupPreparation() {
        turnObject = cast(Turn) new Preparation();
        assert(turnObject !is null);
    }

    void setupPlayerTurn() @trusted {
        mapView = Rectangle(0f, 0f, GetScreenWidth, GetScreenHeight);
        
        if (turnObject) {
            destroy(turnObject);
        }
        turnObject = cast(Turn) new PlayerTurn();
    }

    void updateCameraMouse() { 
        /*alias*/ mousePosition = GetMousePosition;
        
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

    void updateUnitPlacement() {
        unitsByRow.length = map.getLength;
        foreach (uint y; 0..map.getLength) {
            unitsByRow[y] = [];
            foreach (uint x; 0..map.getWidth) {
                Tile tile = map.getTile(x,y);
                if (tile.occupant) {
                    unitsByRow[y] ~= cast(VisibleUnit) tile.occupant;
                    (cast(VisibleUnit)tile.occupant).position = Vector2(x*TILEWIDTH, y*TILEHEIGHT-30f);
                }
            }
        }
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

    void setCursorOffMap() {
        cursorOnMap = false;
        cursorTile = null;
    }

    interface Turn {
        /*final VisibleUnit selectedUnit() {
            return this.outer.selectedUnit;
        }*/

        // For drawing on top of everything else.
        void drawTop();
    }

    class Preparation : Turn
    {

        Renderer renderer;
        alias this = renderer;

        VisibleTile[] startTiles;

        UnitInfoCard[Unit] cardsByUnit;
        
        this() {
            renderer = this.outer;
            
            import std.file, std.json, mission;

            //alias mapView = this.outer.mapView;

            mapView.height = GetScreenHeight - 96;
            
            missionTimer = StopWatch(AutoStart.yes);

            // Todo: This should later be changed when the `Mission` class is removed.
            startTiles = (cast(Mission)map).startingTiles;
            foreach(tile; startTiles) {
                tile.highlights = [Colours.goldlight];
            }

            UnitInfoCard[] unitCards = new UnitInfoCard[0];
            foreach (unitData; parseJSON(readText("Units.json")).array) {
                VisibleUnit unit = new VisibleUnit(map, unitData, playerFaction);
                auto card = new UnitInfoCard(unit, delegate(Unit cardUnit) => selectUnit(cardUnit));
                cardsByUnit[unit] = card;
                unitCards ~= card;
            }

            version (customgui) {
                ScrollBox unitSelection = new ScrollBox(Vector2(96, screenSize.y-96), cast(UIElement[])unitCards, 3, Axis.vertical);
                gui ~= unitSelection;
            }
            version (fluid) {
                Frame unitSelection = gridFrame(paperTheme, .layout!("center","start"), unitCards);

                uiRoot.addChild(unitSelection, MapPosition(
                    coords: Vector2(screenSize.x/2, screenSize.y),
                    drop: MapDropVector(MapDropDirection.center, MapDropDirection.end)
                ));

                debug if (canFind(unitCards, null)) throw new Exception("Empty cards");
                
                const startTilesCount = cast(ushort)startTiles.length;
                nextTurnSlot.condition = delegate() @safe {
                    auto deployed = count!(card => card.unit.currentTile !is null)(unitCards.array);
                    return (missionTimer.peek * deployed > msecs(WAITTIME) * startTilesCount);
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

        ~this() {
            foreach (tile; startTiles) if (tile.occupant) {
                tile.occupant.map = map;
                map.addUnit(tile.occupant);
                tile.occupant.updateReach;
            }
        }

        void selectUnit(Unit unit) @safe {
            if (unit is null) throw new Exception("Tried to select null unit");
            
            if (selectedUnit !is null) {
                cardsByUnit[selectedUnit].enable;
            }

            selectedUnit = cast(VisibleUnit) unit;
            if (selectedUnit.currentTile) selectedUnit.currentTile.occupant = null;
            unit.currentTile = null;
            cardsByUnit[unit].disable;
        }

        void drawTop() {
            if (selectedUnit !is null) {
                DrawTextureV(selectedUnit.sprite, mousePosition - Vector2(TILEWIDTH/2, selectedUnit.sprite.height), Colors.WHITE);
            }
        
            if (IsMouseButtonReleased(MouseButton.MOUSE_BUTTON_LEFT) && cursorOnMap) {
                if (canFind(startTiles, cursorTile)) {
                    auto temp = cast(VisibleUnit) cursorTile.occupant;
                    if (temp) {
                        temp.currentTile.occupant = null;
                        temp.currentTile = null;
                    }
                    if (selectedUnit) {
                        selectedUnit.setLocation(cursorTile, false);
                        writeln("Deployed "~selectedUnit.name);
                    }
                    selectedUnit = temp;

                    debug map.verifyEverything();
                    updateUnitPlacement();
                }
            }
        }
    }

    class PlayerTurn : Turn
    {
        Renderer renderer;
        alias this = renderer;

        NodeSlot!Node floatingMenu;
        Frame unitActionsMenu;
        Button innerBackButton;

        Action currentAction;
        
        this() {
            renderer = this.outer;
            
            foreach (tile; grid.join) tile.highlights.length = 0;

            currentAction = Action.nothing;
            
            version (fluid) {
                
                foreach (node; uiRoot.children) if (node !is nextTurnSlot) {
                    node.toRemove = true;
                }
                
                floatingMenu = nodeSlot!Node();
                Button endTurnButton = button("End turn", delegate {
                    map.endTurn;
                });

                nextTurnSlot.condition = delegate() {return (selectedUnit is null && currentAction == Action.nothing);};
                nextTurnSlot = endTurnButton;
                
                uiRoot.addChild(floatingMenu,
                    MapPosition(
                        Vector2(GetScreenWidth * 0.75f, GetScreenHeight),
                        drop: MapDropVector(MapDropDirection.end, MapDropDirection.end)
                    )
                );

                Button moveButton = button("Move", &moveAction);
                //Button attackButton = button("Attack", &attackAction);
                //Button itemsButton = button("Items", &itemsAction);
                Button outerBackButton = button("Back", &deselectUnit);

                unitActionsMenu = vframe(
                    paperTheme,
                    moveButton,
                    //attackButton,
                    //itemsButton,
                    outerBackButton
                );

                innerBackButton = button("Back", () {
                    currentAction = Action.nothing;
                    floatingMenu = unitActionsMenu;
                });

                uiRoot.updateSize;
            }
            else version (customgui) {

            }
        }

        void drawTop() {
            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT) && cursorTile) {
                if (cursorTile.occupant && cursorTile.occupant.faction == playerFaction) {
                    selectedUnit = cast(VUnit) cursorTile.occupant;
                    currentAction = Action.nothing;
                    floatingMenu = unitActionsMenu;
                    debug writeln("Clicked on "~cursorTile.occupant.name);
                } else switch (currentAction) {
                    case Action.moving: {
                        selectedUnit.move(cursorTile.location.tupleof);
                        break;
                    }
                    default: break;
                }
            }
        }

        @safe:

        void deselectUnit() {
            selectedUnit = null;
            currentAction = Action.nothing;
        }

        void moveAction() {
            foreach (tile; map.getGrid.join) (cast(VTile)tile).highlights = [];

            currentAction = Action.moving;

            foreach(tile; selectedUnit.getReachable!Tile) {
                (cast(VTile)tile).highlights ~= TileHighlights.movable;
            }

            floatingMenu = innerBackButton;
        }
    }
}
