import std.file;
import std.json;
import std.string:toStringz;
import raylib;
import oe.common: Direction;

public import spriteSet;

class SpriteLoader
{
    static SpriteLoader instance;
    
    string[string] pathsToSprite;
    alias spritesByName = Sprite.spritesByName;
    alias spritesByGLID = Sprite.spritesById;
    
    this() {
        JSONValue spritesJSON = parseJSON(readText("sprites.json"));
        import std.stdio;

        foreach (name, path; spritesJSON.object) {
            writeln(name);
            writeln(path);
            pathsToSprite[name] = path.get!string;
        }

        if (instance is null) instance = this;
    }

    ~this() {instance = null;}

    static SpriteLoader current() {
        if (instance is null) instance = new SpriteLoader;
        return instance;
    }

    Sprite getSprite(string name, Direction rotation=Direction.N) {
        if (name in spritesByName) return spritesByName[name];
        else if (name in pathsToSprite) {
            spritesByName[name] = new Sprite(pathsToSprite[name], name);
        }
        return spritesByName[name];
    }
}

class Sprite
{
    static Sprite[string] spritesByName;
    static Sprite[uint] spritesById;
    
    Texture2D texture;
    alias this = texture;
    string name;
    string path;

    alias GLId = texture.id;

    this(string path, string name = "") {
        texture = LoadTexture(path.toStringz);
        this.path = path;
        this.name = name;
    }
    
    this(Image image, string path = "", string name = "") {
        texture = LoadTextureFromImage(image);
        this.path = path;
        this.name = name;
    }

    Texture opCast(Texture)() {
        return this.texture;
    }

    ~this() {
        if (IsWindowReady) UnloadTexture(texture);
        if (name in spritesByName) spritesByName.remove(name);
        if (path in spritesByName) spritesByName.remove(path);
    }
}