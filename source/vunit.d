debug import std.stdio;
import std.datetime.stopwatch;

import std.json;
import raylib;
import constants;
public import oe.unit;
import spriteSet;
import mission;
import oe.tile;
import oe.common;
import oe.faction;
import vector_math;

class VisibleUnit : Unit
{
    //UnitSpriteSet spriteSet;
    Texture2D sprite;
    Vector2 position;
    ActionStep[] queue;
    Message message;

    SpriteAction spriteState;
    StopWatch spriteTimer;

    version (fluid) void delegate() onClick;

    static this() {
        version (signals) {}
        else {
            onHit = delegate(Unit unit) {
                auto vunit = cast(VisibleUnit)unit;
                vunit.message = vunit.newMessage("Hit");
            };
            onMiss = delegate(Unit unit) {
                auto vunit = cast(VisibleUnit)unit;
                vunit.message = vunit.newMessage("Missed");
            };
            onDeath = delegate(Unit unit) {
                auto vunit = cast(VisibleUnit)unit;
                vunit.setSpriteState(SpriteAction.fall);
            };
        }
    }
    
    this(Mission map, JSONValue unitData, Faction faction = null) {
        import std.string:toStringz;
        import std.path : buildNormalizedPath;
        import std.algorithm.searching;
        import std.stdio;

        super(map, unitData);
        string spritePath = ("../sprites/units/" ~ unitData["Sprite"].get!string); //.buildNormalizedPath;
        if (!spritePath.endsWith(".png")) spritePath ~= ".png";
        writeln("Sprite for unit "~this.name~" is "~spritePath);
        this.sprite = LoadTexture(spritePath.toStringz);

        if (this.faction is null) this.faction = faction;

        spriteTimer = StopWatch(AutoStart.yes);
    }

    void draw() {
        if (queue.length > 0) act;
        
        DrawTextureV(sprite, position+Vector2(0.0f, -30.0f), Colors.WHITE);

        if (message !is null) message.draw;
    }

    bool acting() {
        return this.queue.length > 0;
    }

    bool act() {
        if (queue.length == 0) return false;
        bool done;
        switch (queue[0].action) {
            case Action.Move:
                setSpriteState(SpriteAction.walk);
                stepTowards(queue[0].tile);
                if (position == gridToPixels(queue[0].tile.location)) done = true;
                break;
            case Action.Attack:
                setSpriteState(SpriteAction.attack);
                super.attack(queue[0].tile.x, queue[0].tile.y);
                done = true;
                break;
            default: break;
        }
        if (done) {
            for (int i=0; i<queue.length-1; i++) {
                queue[i] = queue[i+1];
            }
            queue.length--;
        }
        import std.math;
        if (abs(position.x-xlocation*TILEWIDTH)+abs(position.y-ylocation*TILEHEIGHT) == 0) {
            debug writeln(this.name~" diff ", (position.x-xlocation*TILEWIDTH), ", ", (position.y-ylocation*TILEHEIGHT));
        }
        return true;
    }

    override void turnReset() {
        super.turnReset();
        position.x = this.xlocation*TILEWIDTH;
        position.y = this.ylocation*TILEHEIGHT;
    }

    override bool move(int x, int y) {
        import core.thread.osthread;

        spriteTimer.reset;
        
        if (this.tileReach[x][y].reachable) {
            Tile[] path = getPath!Tile(Vector2i(x,y));
            debug writeln("Path length is ", path.length);
            foreach(tile; path) {
                debug assert(tile !is null);
                this.queue ~= ActionStep(action:Action.Move, tile:tile);
            }
            super.move(x, y);
            return true;
        } else return false;
    }

    override bool attack(uint x, uint y) {
        if (canAttack(x, y)) {
            queue ~= ActionStep(action:Action.Attack, tile:map.getTile(x,y));
            return true;
        } else return false;
    }

    void stepTowards (Tile tile) { stepTowards(tile.x, tile.y);}
    
    float stepTowards (int x, int y, bool trig=false) {
        import std.algorithm.comparison;
        import std.math.algebraic;
        
        Vector2 initial = this.position;
        float stepDistance = GetFrameTime;
        //debug writeln(stepDistance);
        if (this.tileReach[x][y].directionTo.diagonal) stepDistance /= 1.41421356237f;
        if (x*TILEWIDTH > position.x) this.position.x = min(position.x+stepDistance*TILEWIDTH, cast(float)(x*TILEWIDTH));
        else if (x*TILEWIDTH < position.x) this.position.x = max(position.x-stepDistance*TILEWIDTH, cast(float)(x*TILEWIDTH));
        if (y*TILEHEIGHT > position.y) position.y = min(position.y+stepDistance*TILEHEIGHT, cast(float)(y*TILEHEIGHT));
        else if (y*TILEHEIGHT < position.y) this.position.y = max(position.y-stepDistance*TILEHEIGHT, cast(float)(y*TILEHEIGHT));
        Vector2 step = position - initial;
        
        return abs(max(position.x/TILEWIDTH, position.y/TILEHEIGHT));
    }

    bool setSpriteState (SpriteAction action) {
        if (spriteState != action ) {
            spriteTimer.reset;
            spriteState = action;
            return true;
        } else return false;
    }

    debug {
        void verify() {
            assert(this.currentTile !is null, "Unit "~name~"'s `currentTile` property is not set.");
            assert(this.currentTile.occupant == this, "Unit "~name~" has it's `currentTile` property set to a Tile object, but that Tile object does not have "~name~" in it's `occupant` property.");
            assert(this.xlocation == this.currentTile.x, "Unit "~name~"'s `xlocation` property is not the same as it's tile's.");
            assert(this.ylocation == this.currentTile.y, "Unit "~name~"'s `ylocation` property is not the same as it's tile's.");
        }
    }

    struct ActionStep {
        Action action;
        Tile tile;
    }

    Message newMessage(string text) {return new Message(text);}
    
    class Message {
        import core.memory;
        import std.datetime.stopwatch;
        import ui;
        
        string text;
        Vector2 position;
        StopWatch timer;

        this(string text) {
            timer = StopWatch(AutoStart.yes);
            this.text = text;
            float textWidth = MeasureTextEx(FontSet.getDefault.sans, cast(char*)text, 12, 1).x;
            position = this.outer.position;
            position.x += (TILEWIDTH - textWidth) / 2;
            this.position.y -= 24;
        }

        void draw() {
            DrawTextEx(FontSet.getDefault.sans, cast(char*)text, position, 12, 1, Color(240,5,5,250));
            position.y -= GetFrameTime*8;
            if (timer.peek.total!"msecs" > 1500) {
                this.outer.message = null;
                //GC.free(this);
                destroy(this);
            }
        }
    }
}