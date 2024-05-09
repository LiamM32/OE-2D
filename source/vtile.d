import std.json;
import raylib;
public import oe.tile;
import oe.common;
import constants;
import sprite;

alias VTile = VisibleTile;

class VisibleTile : Tile//T!VisibleTile
{
    Sprite[2] sprites; // `sprite[0]` is the ground sprite.
    Color[] highlights;
    Rectangle rect;

    this(uint x, uint y, JSONValue tileData) {
        string tileName = "";
        if ("name" in tileData) tileName = tileData["name"].get!string;
        this.allowStand = tileData["canWalk"].get!bool;
        if ("canFly" in tileData) this.allowFly = tileData["canFly"].get!bool;
        if ("canShoot" in tileData) this.allowShoot = tileData["canShoot"].get!bool;
        else this.allowShoot = this.allowStand;
        this.stickyness = tileData["stickiness"].get!int;
        this.rect.x = cast(float) x * TILEWIDTH;
        this.rect.y = cast(float) y * TILEHEIGHT;
        this.rect.width = TILEWIDTH;
        this.rect.height = TILEHEIGHT;

        this.sprites[0] = SpriteLoader.current.getSprite(tileData["ground"].get!string);
        this.textureID = cast(ushort)SpriteLoader.current.getSprite(tileData["ground"].get!string).id;
        if ("obstacle" in tileData) this.sprites[1] = SpriteLoader.current.getSprite(tileData["obstacle"].get!string);

        super(cast(int)x, cast(int)y);
    }

    void draw() {
        DrawTextureV(sprites[0], rect.origin, Colors.WHITE);
        if (sprites[1] !is null) DrawTextureV(sprites[1], Vector2(rect.x, rect.bottom - sprites[1].height), Colors.WHITE);

        foreach (highlight; highlights) {
            debug assert(highlight.a > 0);
            DrawRectangleRec(rect, highlight);
        }
    }

    Vector2 origin() {
        return Vector2(x:rect.x, y:rect.y);
    }

    Rectangle getRect() {
        return this.rect;
    }

    Rectangle getRect(Vector2 offset) {
        Rectangle rect = this.rect;
        rect.x += offset.x;
        rect.y += offset.y;
        return rect;
    }

    /*import vunit;
    VisibleUnit occupant() {
        return cast(VisibleUnit) occupant;
    }
    void occupant(Unit unit) {
        super.occupant = unit;
    }*/
}

VisibleTile[] visible(Tile[] tileArray) @trusted {
    return cast(VisibleTile[]) tileArray;
}

enum TileHighlights : Color
{
    movable = Color(60, 240, 120, 30),
}