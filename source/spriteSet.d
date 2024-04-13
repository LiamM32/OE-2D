import std.conv;
import std.string : toStringz;
import raylib;
import oe.unit;
import oe.common;

class UnitSpriteSet
{
    Image[8][4] attack_spear;
    Image[8][4] attack_bow;
    Image[6][4] attack_knife;
    Texture[][4] attack;
    Texture[9][4] walk;
    Texture[6] fall;
    Texture[7][4] stretch;

    this (string spriteSheetPath) {
        Image spriteSheet = LoadImage (spriteSheetPath.toStringz);
        Rectangle cutter = Rectangle(0, 0, 64, 64);

        void processRow(ImageType, int length)(ref ImageType[length] spriteRow) {
            for (int i=0; i<length; ++i) {
                Image sprite = ImageCopy(spriteSheet);
                ImageCrop(&sprite, cutter);
                static if (is(ImageType==Texture)) spriteRow[i] = LoadTextureFromImage(sprite);
                static if (is(ImageType==Image)) spriteRow[i] = sprite;
            }
            cutter.y++;
        }

        foreach (d; 1..4) processRow(stretch[d]);
        foreach (d; 1..4) processRow(attack_spear[d]);
        foreach (d; 1..4) processRow(walk[d]);
        foreach (d; 1..4) processRow(attack_knife[d]);
        foreach (d; 1..4) processRow(attack_bow[d]);
        processRow(fall);
    }

    Texture2D getFrame (Unit* unit, float timer, SpriteAction action) {
        int direction = unit.facing.to!int;
        int frameNum;
        final switch (action) {
            case SpriteAction.wait:
                frameNum = cast(int)(timer/4) % 2;
                return stretch[direction][frameNum];
            case SpriteAction.stretch:
                frameNum = cast(int)timer % 7;
                return stretch[direction][frameNum];
            case SpriteAction.walk:
                frameNum = cast(int)timer % 9;
                return walk[direction][frameNum];
            case SpriteAction.attack:
                frameNum = cast(int)timer % 8;
                return attack[direction][frameNum];
            case SpriteAction.fall:
                frameNum = cast(int)timer % 6;
                return fall[frameNum];
        }
    }
}

enum SpriteAction : ubyte
{
    wait,
    stretch,
    walk,
    attack,
    fall,
}

unittest
{
    UnitSpriteSet spriteSet = new UnitSpriteSet("../sprites/units/male_crimson-leather.png");
}