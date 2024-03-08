import std.stdio;
import std.file;
import std.path : buildNormalizedPath;
import std.string : toStringz;
import std.conv;
import std.json;
import std.algorithm.searching;
import std.datetime.stopwatch;
import raylib;

import map;
import tile;
import unit;
import vector_math;

import vtile;

const int TILESIZE = 64;

class Mission : Map
{
    Texture2D[] sprites;
    Texture2D gridMarker;
    int[string] spriteIndex;
    Unit* selectedUnit;
    Rectangle[][] gridRects;
    GridTile[][] squareGrid;
    Vector2 offset;
    Rectangle mapView;
    Vector2i mapSizePx;

    GridTile[] startingPoints;

    this() {
        JSONValue missionData = parseJSON(readText("../maps/Test_battlefield.json"));
        this(missionData);
    }

    this(string missionPath) {
        JSONValue missionData = parseJSON(readText(missionPath));
        this(missionData);
    }

    this(JSONValue mapData) {
        this.offset = Vector2(0.0f, 0.0f);
        import std.algorithm;
        import std.conv;

        super(mapData["map_name"].get!string);
        super.loadFactionsFromJSON(mapData);

        this.grid.length = mapData.object["tiles"].array.length;
        this.squareGrid.length = mapData.object["tiles"].array.length;
        writeln("Starting to unload tile data");
        foreach (int x, tileRow; mapData.object["tiles"].array) {
            foreach (int y, tileData; tileRow.arrayNoRef) {
                string tileName = "";
                if ("name" in tileData) tileName = tileData["name"].get!string;
                bool allowStand = tileData["canWalk"].get!bool;
                bool allowFly = true;// tile["canFly"].get!bool;
                int stickiness = tileData["stickiness"].get!int;
                string spriteName = tileData["tile_sprite"].get!string;
                ushort spriteID;
                spriteID = loadNumberTexture(spriteName, spriteIndex, this.sprites);
                Tile tile =  new Tile(tileName, allowStand, allowFly, stickiness, spriteID, spriteName);
                GridTile gridTile = new GridTile(tile, x, y);
                this.grid[x] ~= tile;
                this.squareGrid[x] ~= gridTile;
                assert(this.grid[x][y] == this.squareGrid[x][y].tile);
                if ("Unit" in tileData) {
                    Unit occupyingUnit = this.loadUnitFromJSON(tileData["Unit"], spriteIndex);
                    occupyingUnit.setLocation(x, y);
                } else if ("Player Unit" in tileData) {
                    this.grid[x][y].startLocation = true;
                    startingPoints ~= gridTile;
                }
            }
            write("Finished loading row ");
            writeln(x);
        }
        this.mapSizePx.x = cast(int)this.squareGrid.length * TILESIZE;
        this.mapSizePx.y = cast(int)this.squareGrid[0].length * TILESIZE;
        writeln("Finished loading map " ~ this.name);
        {
            import std.conv;
            writeln("Map is "~to!string(this.grid.length)~" by "~to!string(this.grid.length)~" tiles.");
        }
        this.gridMarker = LoadTexture("../sprites/grid-marker.png".toStringz);
        this.fullyLoaded = true;
    }

    void run() {
        startPreparation();
        playerTurn();
    }

    void startPreparation() {   
        Rectangle menuBox = {x:0, y:GetScreenHeight()-96, width:GetScreenWidth(), height:96};
        Unit[] availableUnits;
        UnitCard[Unit] unitCards;
        
        JSONValue playerUnitsData = parseJSON(readText("Units.json"));
        writeln("Opened Units.json");
        foreach (int k, unitData; playerUnitsData.array) {
            Unit unit = loadUnitFromJSON(unitData, spriteIndex, false);
            availableUnits ~= unit;
            unitCards[unit] = new UnitCard(unit, k*258, GetScreenHeight()-88);
        }
        writeln("There are "~to!string(unitCards.length)~" units available.");
        
        scope(exit) CloseWindow();

        this.phase = GamePhase.Preparation;
        
        auto timer = StopWatch(AutoStart.yes);
        bool startButtonAvailable = false;
        Vector2 mousePosition = GetMousePosition();
        const Vector2 dragOffset = {x: -TILESIZE/2, y: -TILESIZE*0.75 };
        this.offset = Vector2(0.0, -96.0);
        this.mapView = Rectangle(0, 0, GetScreenWidth, GetScreenHeight-96);
        ushort unitsDeployed = 0;

        while(!WindowShouldClose()) {
            unitsDeployed = 0;
            BeginDrawing();
            this.offsetMap(mapView);
            drawTiles();
            foreach(startTile; startingPoints) {
                DrawRectangleRec(startTile.getRect, Color(250, 250, 60, 60));
                DrawRectangleLinesEx(startTile.getRect, 1.5f, Color(240, 240, 40, 120));
                if (startTile.occupant !is null) {
                    unitsDeployed++;
                    Vector2 destination = startTile.getOriginSS + Vector2(0, -24);
                    Color tint;
                    if (startTile.tile.occupant == this.selectedUnit) tint = Color(250, 250, 250, 190);
                    else tint = Color(255, 255, 255, 255);
                    DrawTextureV(this.sprites[startTile.tile.occupant.spriteID], destination, tint);
                }
                if (CheckCollisionPointRec(mousePosition, startTile.getRect)) {
                    DrawRectangleRec(startTile.getRect, Color(250, 30, 30, 30));
                }
            }
            drawGridMarkers(timer.peek.total!"msecs");
            drawUnits();

            DrawRectangleRec(menuBox, Colours.PAPER);
            foreach (card; unitCards) if (card.available) {
                card.draw();
            }

            if (IsKeyDown(KeyboardKey.KEY_SPACE)) {
                DrawRectangleRec(mapView, Color(250, 20, 20, 50));
            }

            mousePosition = GetMousePosition();
            if (this.selectedUnit is null) {
                if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                    bool searching = true;
                    foreach (card; unitCards) if (CheckCollisionPointRec(mousePosition, card.outerRect)) {
                        searching = false;
                        if (card.available) {
                            this.selectedUnit = &card.unit;
                            card.available = false;
                            break;
                        }
                    }
                    if (searching) foreach (startTile; startingPoints) if (CheckCollisionPointRec(mousePosition, startTile.getRect)) {
                        this.selectedUnit = startTile.tile.occupant;
                    }
                }
            } else {
                DrawTextureV(this.sprites[this.selectedUnit.spriteID], mousePosition+dragOffset, Colors.WHITE);
                if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                    bool deployed;
                    if (CheckCollisionPointRec(mousePosition, menuBox)) deployed = false;
                    else deployed = (this.selectedUnit.currentTile !is null);
                    foreach (gridTile; startingPoints) if (CheckCollisionPointRec(mousePosition, gridTile.getRect)) {
                        Unit* previousOccupant = gridTile.tile.occupant;
                        if (gridTile.occupant !is null) {
                            unitCards[*previousOccupant].available = true;
                        }
                        if (this.selectedUnit.currentTile !is null) this.selectedUnit.currentTile.occupant = null;
                        gridTile.tile.occupant = this.selectedUnit;
                        this.selectedUnit.currentTile = &gridTile.tile;
                        unitCards[*selectedUnit].available = false;
                        deployed = true;
                        writeln("Unit "~gridTile.tile.occupant.name~" is being deployed.");
                        if (previousOccupant !is null) previousOccupant.currentTile = null;
                        this.selectedUnit = previousOccupant;
                        break;
                    }
                    if (!deployed) {
                        unitCards[*selectedUnit].available = true;
                        if (this.selectedUnit.currentTile !is null) {
                            this.selectedUnit.currentTile.occupant = null;
                            this.selectedUnit.currentTile = null;
                        }
                        this.selectedUnit = null;
                    }
                }
            }
            if (unitsDeployed > 0 && timer.peek() >= msecs(1000*startingPoints.length/unitsDeployed)) {
                Rectangle startButton = {GetScreenWidth-92, GetScreenHeight-160, 80, 48};
                DrawRectangleRec(startButton, Colours.CRIMSON);
                DrawText("Start mission".toStringz, GetScreenWidth-92, GetScreenHeight-140, 16, Colours.PAPER);
                if (CheckCollisionPointRec(mousePosition, startButton) && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                    this.nextTurn;
                    break;
                };
            }
            EndDrawing();
        }

        foreach (startTile; this.startingPoints) {
            startTile.occupant.map = this;
            writeln("Just assigned Unit.map to the Mission object.");
            this.factionUnits["player"] ~= *startTile.occupant;
        }
        this.startingPoints = [];
    }

    void playerTurn() {
        this.turnReset();

        //scope(exit) CloseWindow();

        auto missionTimer = StopWatch(AutoStart.yes);
        
        Vector2 mousePosition = GetMousePosition();
        Vector2 highlightedTile;

        bool oscDirection = false;
        ubyte markerOpacity;

        while(!WindowShouldClose())
        {
            BeginDrawing();
            mousePosition = GetMousePosition();

            if (oscDirection) {
                markerOpacity += 2;
                if (markerOpacity == 128) oscDirection = false;
            } else {
                markerOpacity -= 2;
                if (markerOpacity == 32) oscDirection = true;
            }

            drawTiles();
            foreach (int gridx, row; this.squareGrid) {
                foreach (int gridy, gridTile; row) {
                    if (CheckCollisionPointRec(mousePosition, gridTile.getRect)) {
                        if (gridTile.tile.occupant !is null) {
                            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) {
                                this.selectedUnit = gridTile.tile.occupant;
                                this.selectedUnit.updateDistances();
                            }
                            if (this.selectedUnit !is null) {
                                if (this.selectedUnit.getDistance(gridx, gridy).reachable) {
                                    DrawRectangleRec(gridTile.getRect, Color(100, 100, 245, 32));
                                }
                            }
                        }
                        DrawRectangleRec(gridTile.getRect, Color(245, 245, 245, 32));
                    }
                    DrawTextureEx(gridMarker, Vector2(gridx*TILESIZE, gridy*TILESIZE), 0.0, 1.0, Color(10,10,10, markerOpacity));
                }
            }
            drawUnits();
            EndDrawing();
        }
        CloseWindow();
    }

    void drawTiles() {
        foreach (int x, row; this.squareGrid) {
            foreach (int y, gridTile; row) {
                DrawTextureV(gridTile.sprite, gridTile.getOriginSS, Colors.WHITE);
            }
        }
    }

    void drawGridMarkers(long time) {
        import std.math.trigonometry:sin;
        float sinwave = 60*(sin(cast(float)time/300.0f)+1.0);
        int opacity = sinwave.to!int + 20;
        foreach (int x, row; this.squareGrid) {
            foreach (int y, gridTile; row) {
                DrawTextureV(this.gridMarker, gridTile.getOriginSS, Color(10,10,10, cast(ubyte)sinwave));
            }
        }
    }

    void drawUnits() {
        foreach (unit; this.allUnits) {
            Vector2 origin = {x: unit.xlocation*TILESIZE+this.offset.x, y: unit.ylocation*TILESIZE+this.offset.y-24};
            DrawTextureV(this.sprites[unit.spriteID], origin, Colors.WHITE);
        }
    }

    void drawOnMap(Texture2D sprite, Rectangle rect) {
        Vector2 destination = rectDest(rect, this.offset);
        DrawTextureRec(sprite, rect, destination, Colors.WHITE);
    }
    void drawOnMap(Rectangle rect, Color colour) {
        rect.x += this.offset.x;
        rect.y += this.offset.y;
        DrawRectangleRec(rect, colour);
    }

    void offsetMap(Rectangle mapView) { 
        Vector2 offsetOffset;
        Vector2 SECornerSS = this.squareGrid[$-1][$-1].SECornerSS + this.offset;
        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_RIGHT)) {
            offsetOffset = GetMouseDelta();
        } else {
            float framelength = GetFrameTime();
            if (IsKeyDown(KeyboardKey.KEY_A)) {
                offsetOffset.x = -framelength * 32.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_D)) {
                offsetOffset.x = framelength * 32.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_W)) {
                offsetOffset.y = -framelength * 32.0;
            }
            if (IsKeyDown(KeyboardKey.KEY_S)) {
                offsetOffset.y = framelength * 32.0;
            }
        }
        this.offset += offsetOffset;
        if (offset.x > mapView.x) offset.x = 0.0f;
        else if (offset.x + mapSizePx.x < mapView.width) offset.x = mapView.width - mapSizePx.x;
        if (offset.y > mapView.y) offset.y = 0.0f;
        else if (offset.y + mapSizePx.y < mapView.height) offset.y = mapView.height - mapSizePx.y;
    }

    Unit loadUnitFromJSON (JSONValue unitData, ref int[string] spriteIndex, bool addToMap=true) {
        Unit newUnit;
        if (addToMap) newUnit = new Unit(this, unitData);
        else newUnit = new Unit(unitData);
        string spriteName = unitData["Sprite"].get!string;
        if (spriteName in spriteIndex) {
            newUnit.spriteID = spriteIndex[spriteName];
        } else {
            newUnit.spriteID = cast(uint)this.sprites.length;
            assert(newUnit.spriteID > 0);
            writeln("Player unit spriteID = "~to!string(newUnit.spriteID));
            spriteIndex[spriteName] = newUnit.spriteID;
            string spritePath = ("../sprites/units/" ~ spriteName).buildNormalizedPath;
            if (!spritePath.endsWith(".png")) spritePath ~= ".png";
            this.sprites ~= LoadTexture(spritePath.toStringz);
        }
        //allUnits ~= newUnit; Removed because this was added to Unit.this
        return newUnit;
    }

    class GridTile
    {
        Tile tile;
        private Vector2i origin;
        int x;
        int y;

        this(Tile tile, int x, int y) {
            this.tile = tile;
            this.origin = Vector2i(x*TILESIZE, y*TILESIZE);
            this.x = x;
            this.y = y;
        }

        Rectangle getRect() {
            float x = this.origin.x + this.outer.offset.x;
            float y = this.origin.y + this.outer.offset.y;
            return Rectangle(x:x, y:y, width:TILESIZE, height:TILESIZE);
        }
        Vector2i getOriginAbs() {
            return this.origin;
        }
        Vector2 getOriginSS() {
            float x = this.origin.x + this.outer.offset.x;
            float y = this.origin.y + this.outer.offset.y;
            return Vector2(x, y);
        }
        Vector2 SECornerSS() {
            float x = this.origin.x + TILESIZE + this.outer.offset.x;
            float y = this.origin.y + TILESIZE + this.outer.offset.y;
            return Vector2(x, y);
        }

        Unit* occupant() {
            return this.tile.occupant;
        }
        int spriteID() {
            return cast(int)this.tile.textureID;
        }
        Texture2D sprite() {
            return this.outer.sprites[this.tile.textureID];
        }
    }

    class UnitCard
    {
        Rectangle outerRect;
        Rectangle imageFrame;
        int x;
        int y;
        int width;
        int height;
        Unit unit;
        bool available = true;
        string infotext;

        this (Unit unit, int screenx, int screeny ) {
            this.outerRect = Rectangle(screenx, screeny, 192, 80);
            this.imageFrame = Rectangle(screenx+4, screeny+4, 64, 64);
            this.unit = unit;
            this.x = screenx;
            this.y = screeny;
            this.width = 256;
            this.height = 72;

            UnitStats stats = unit.getStats;
            this.infotext ~= "Mv: "~to!string(stats.Mv)~"\n";
            this.infotext ~= "MHP: "~to!string(stats.MHP)~"\n";
            this.infotext ~= "Str: "~to!string(stats.Str)~"\n";
            this.infotext ~= "Def: "~to!string(stats.Def)~"\n";
        }

        UnitStats stats() {
            return this.unit.getStats;
        }

        void draw() {
            DrawRectangleRec(outerRect, Color(r:250, b:230, g:245, a:200));
            DrawRectangleLinesEx(outerRect, 1.0f, Colors.BLACK);
            DrawTexture(this.outer.sprites[this.unit.spriteID], cast(int)outerRect.x+4, cast(int)outerRect.y+2, Colors.WHITE);
            DrawText(this.unit.name.toStringz, x+80, y+4, 14, Colors.BLACK);
            DrawText(this.infotext.toStringz, x+80, y+20, 11, Colors.BLACK);
        }
    }
}

ushort loadNumberTexture (string spriteName, ref int[string] spriteIndex, ref Texture2D[] sprites) {
    ushort spriteID;
    if (spriteName in spriteIndex) {
        spriteID = cast(ushort)spriteIndex[spriteName];
    } else {
        string spritePath = ("../sprites/tiles/" ~ spriteName).buildNormalizedPath;
        spriteID = cast(ushort)sprites.length;
        sprites ~= LoadTexture(spritePath.toStringz);
        spriteIndex[spriteName] = spriteID;
    }
    return spriteID;
}

enum Colours {
    SHADOW = Color(r:20, b:20, g:20, a:25),
    PAPER = Color(r:240, b:210, g:234, a:250),
    SHINE = Color(250, 250, 60, 35),
    CRIMSON = Color(230, 10, 15, 255),
}


unittest
{
    validateRaylibBinding();
    Mission mission = new Mission("../maps/test-map.json");
    writeln("Mission unittest: Finished Mission constructor.");
    foreach (unit; mission.allUnits) {
        assert(unit.map == mission);
        if(mission != unit.map) writeln("These objects do not match"); 
    }
}