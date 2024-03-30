import raylib;
import ui;
import std.string;
import std.conv;
import vector_math;

class UnitInfoCard : UIElement
{
    import vunit;
    
    Rectangle outline;
    Rectangle imageFrame;
    Font font;
    VisibleUnit unit;
    string infotext;
    
    this (VisibleUnit unit, Vector2 origin ) {
        this.outline = Rectangle(origin.x, origin.y, 192, 80);
        this.imageFrame = Rectangle(origin.x+4, origin.y+4, 64, 64);
        this.unit = unit;

        this.font = FontSet.getDefault.serif;
        GenTextureMipmaps(&font.texture);

        UnitStats stats = unit.getStats;
        this.infotext ~= "Mv: "~to!string(stats.Mv)~"\n";
        this.infotext ~= "MHP: "~to!string(stats.MHP)~"\n";
        this.infotext ~= "Str: "~to!string(stats.Str)~"\n";
        this.infotext ~= "Def: "~to!string(stats.Def)~"\n";
    }
    ~this() {
        if (available) destroy(this.unit);
    }

    bool available() {
        if (unit.currentTile is null) return true;
        else return false;
    }
    
    UnitStats stats() {
        return this.unit.getStats;
    }

    bool draw() {return draw(Vector2(0,0));}
    
    bool draw(Vector2 offset = Vector2(0,0)) {
        if (unit.currentTile !is null) return false;
        DrawRectangleRec(offsetRect(outline, offset), Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(offsetRect(outline, offset), 1.0f, Colors.BLACK);
        DrawTextureV(unit.sprite, Vector2(outline.x,outline.y)+offset+Vector2(4,2), Colors.WHITE); //change `Vector2(outline.x,outline.y)` to `outline.origin` if my addition to Raylib-D gets merged.
        DrawTextEx(font, unit.name.toStringz, Vector2(outline.x+80, outline.y+4), 17.0f, 1.0f, Colors.BLACK);
        DrawTextEx(font, infotext.toStringz, Vector2(outline.x+80, outline.y+20), 12.5f, 1.0f, Colors.BLACK);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        return true;
    }
}
