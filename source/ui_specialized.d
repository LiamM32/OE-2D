import raylib;
import ui;
import std.string;
import std.conv;
import vector_math;

version (raygui) const bool INHERIT = false;
else const bool INHERIT = true;

class UnitInfoCard : UIElement
{
    import vunit;
    
    Rectangle imageFrame;
    Font font;
    VisibleUnit unit;
    string infotext;

    version (notRaygui) void delegate() onClick;
    
    this (VisibleUnit unit, Vector2 origin) {
        this.area = Rectangle(origin.x, origin.y, 192, 80);
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

    version (notRaygui) this(VisibleUnit unit, Vector2 origin, void delegate() onClick) {
        this.onClick = onClick;
        this(unit, origin);
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

    version (notRaygui) override void draw(Vector2 offset = Vector2(0,0)) {
        if (unit.currentTile !is null) return;
        DrawRectangleRec(offsetRect(area, offset), Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(offsetRect(area, offset), 1.0f, Colors.BLACK);
        DrawTextureV(unit.sprite, Vector2(area.x,area.y)+offset+Vector2(4,2), Colors.WHITE); //change `Vector2(area.x,area.y)` to `area.origin` if my addition to Raylib-D gets merged.
        DrawTextEx(font, unit.name.toStringz, Vector2(area.x+80, area.y+4), 17.0f, 1.0f, Colors.BLACK);
        DrawTextEx(font, infotext.toStringz, Vector2(area.x+80, area.y+20), 12.5f, 1.0f, Colors.BLACK);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        if (CheckCollisionPointRec(GetMousePosition(), this.area) && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) onClick();
    }

    version (raygui) bool draw(Vector2 offset = Vector2(0,0)) {
        if (unit.currentTile !is null) return false;
        DrawRectangleRec(offsetRect(area, offset), Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(offsetRect(area, offset), 1.0f, Colors.BLACK);
        DrawTextureV(unit.sprite, Vector2(area.x,area.y)+offset+Vector2(4,2), Colors.WHITE); //change `Vector2(area.x,area.y)` to `area.origin` if my addition to Raylib-D gets merged.
        DrawTextEx(font, unit.name.toStringz, Vector2(area.x+80, area.y+4), 17.0f, 1.0f, Colors.BLACK);
        DrawTextEx(font, infotext.toStringz, Vector2(area.x+80, area.y+20), 12.5f, 1.0f, Colors.BLACK);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        return true;
    }
}

class UnitInfoPanel
{
    import vunit;

    UIStyle style;
    Rectangle textArea;
    VisibleUnit unit;

    this(Vector2 origin) {
        this.style = UIStyle.getDefault;
        this.textArea = Rectangle(origin.x, origin.y-64, 192, 64);
    }

    this(Vector2 origin, Unit unit) {
        this(origin);
        resetToUnit(unit);
    }

    void resetToUnit(Unit unit) {
        this.unit = cast(VisibleUnit)unit;
    }

    void draw() {
        Font font = style.fontSet.sans;
        DrawRectangleRec(textArea, style.baseColour);
        DrawTextEx(font, ("HP: "~unit.HP.to!string~"/"~unit.MHP.to!string).toStringz, Vector2(textArea.x+4, textArea.y+2), 14, 1, Colors.BLACK);
        if (unit.Mv == unit.MvRemaining) DrawTextEx(font, ("Mv: "~unit.Mv.to!string).toStringz, Vector2(textArea.x+4, textArea.y+18), 14, 1, Colors.BLACK);
        else DrawTextEx(font, ("Mv: "~unit.MvRemaining.to!string~"/"~unit.Mv.to!string).toStringz, Vector2(textArea.x+4, textArea.y+18), 14, 1, Colors.BLACK);
        if (unit.currentWeapon !is null) DrawTextEx(font, ("Weapon: "~unit.currentWeapon.name).toStringz, Vector2(textArea.x+68, textArea.y+18), 14, 1, Colors.BLACK);
        DrawTextEx(font, ("Str: "~unit.Str.to!string).toStringz, Vector2(textArea.x+4, textArea.y+34), 14, 1, Colors.BLACK);
        DrawTextEx(font, ("Def: "~unit.Def.to!string).toStringz, Vector2(textArea.x+68, textArea.y+34), 14, 1, Colors.BLACK);
    }
}