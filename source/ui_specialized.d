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
    UIStyle style;
    Font font;
    VisibleUnit unit;
    string infotext;

    version (raygui) {} else void delegate() onClick;
    
    this (VisibleUnit unit, Vector2 origin) {
        this.area = Rectangle(origin.x, origin.y, 192, 80);
        this.imageFrame = Rectangle(origin.x+4, origin.y+4, 64, 64);
        this.unit = unit;

        style = UIStyle.getDefault;
        this.font = FontSet.getDefault.serif;
        GenTextureMipmaps(&font.texture);

        UnitStats stats = unit.getStats;
        this.infotext ~= "Mv: "~to!string(stats.Mv)~"\n";
        this.infotext ~= "MHP: "~to!string(stats.MHP)~"\n";
        this.infotext ~= "Str: "~to!string(stats.Str)~"\n";
        this.infotext ~= "Def: "~to!string(stats.Def)~"\n";
    }

    version (raygui) {} else this(VisibleUnit unit, Vector2 origin, void delegate() onClick) {
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

    version (raygui) bool draw(Vector2 offset = Vector2(0,0)) {
        if (unit.currentTile !is null) return false;
        DrawRectangleRec(offsetRect(area, offset), Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(offsetRect(area, offset), 1.0f, style.outlineColour);
        DrawTextureV(unit.sprite, Vector2(area.x,area.y)+offset+Vector2(4,2), Colors.WHITE); //change `Vector2(area.x,area.y)` to `area.origin` if my addition to Raylib-D gets merged.
        DrawTextEx(font, unit.name.toStringz, Vector2(area.x+80, area.y+4), 17.0f, 1.0f, style.textColour);
        DrawTextEx(font, infotext.toStringz, Vector2(area.x+80, area.y+20), 12.5f, 1.0f, style.textColour);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        return true;
    } else override void draw(Vector2 offset = Vector2(0,0)) {
        if (unit.currentTile !is null) return;
        DrawRectangleRec(offsetRect(area, offset), Color(r:250, b:230, g:245, a:200));
        DrawRectangleLinesEx(offsetRect(area, offset), 1.0f, style.outlineColour);
        DrawTextureV(unit.sprite, Vector2(area.x,area.y)+offset+Vector2(4,2), Colors.WHITE); //change `Vector2(area.x,area.y)` to `area.origin` if my addition to Raylib-D gets merged.
        DrawTextEx(font, unit.name.toStringz, Vector2(area.x+80, area.y+4), 17.0f, 1.0f, style.textColour);
        DrawTextEx(font, infotext.toStringz, Vector2(area.x+80, area.y+20), 12.5f, 1.0f, style.textColour);
        SetTextureFilter(font.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        if (CheckCollisionPointRec(GetMousePosition(), this.area) && IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) onClick();
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
        DrawTextEx(font, ("HP: "~unit.HP.to!string~"/"~unit.MHP.to!string).toStringz, Vector2(textArea.x+4, textArea.y+1), 14, 1, style.textColour);
        if (unit.Mv == unit.MvRemaining) DrawTextEx(font, ("Mv: "~unit.Mv.to!string).toStringz, Vector2(textArea.x+4, textArea.y+17), 14, 1, style.textColour);
        else DrawTextEx(font, ("Mv: "~unit.MvRemaining.to!string~"/"~unit.Mv.to!string).toStringz, Vector2(textArea.x+4, textArea.y+17), 14, 1, style.textColour);
        if (unit.currentWeapon !is null) DrawTextEx(font, ("Weapon: "~unit.currentWeapon.name).toStringz, Vector2(textArea.x+68, textArea.y+17), 14, 1, style.textColour);
        DrawTextEx(font, ("Str: "~unit.Str.to!string).toStringz, Vector2(textArea.x+4, textArea.y+33), 14, 1, style.textColour);
        DrawTextEx(font, ("Def: "~unit.Def.to!string).toStringz, Vector2(textArea.x+68, textArea.y+33), 14, 1, style.textColour);
        DrawTextEx(font, ("Dex: "~unit.Dex.to!string).toStringz, Vector2(textArea.x+4, textArea.y+49), 14, 1, style.textColour);
        DrawRectangleLinesEx(textArea, style.outlineThickness, style.outlineColour);
    }
}

class AttackInfoPanel
{
    import oe.unit;
    
    static UIStyle style;
    Rectangle area;
    Unit attacker;
    Unit target;
    AttackPotential attackInfo;
    string[3] lines;
    Vector2[3] textAnchor;

    this(AttackPotential attackInfo) {
        this.attackInfo = attackInfo;
        this.style = UIStyle.getDefault;
    }

    this(Unit attacker, Unit target, const bool now, Vector2 origin) {
        this.attacker = attacker;
        this.target = target;
        
        if (now) attackInfo = attacker.getAttackPotential(target);
        else attackInfo = attacker.getAttackPotential(target, 2);
        this.style = UIStyle.getDefault;
        
        this.area = Rectangle(x:origin.x, y:origin.y, width:192, height:48);

        lines[0] = attacker.name ~ " -> " ~ target.name;
        textAnchor[0].x = area.x + (area.width - MeasureTextEx(style.fontSet.sans, lines[0].toStringz, 14, 1).x)/2;
        lines[1] = "Damage: " ~ attackInfo.damage.to!string;
        textAnchor[1] = Vector2(x:area.x+4, y:area.y+17);
        lines[2] = "Hit chance: " ~ ((attackInfo.hitChance)/10.0f).to!string~"%";
        textAnchor[2] = Vector2(x:area.x+4, y:area.y+33);
    }

    void draw() {
        DrawRectangleRec(area, style.baseColour);
        DrawTextEx(style.fontSet.sans, lines[0].toStringz, textAnchor[0], 14, 1, style.textColour);
        DrawTextEx(style.fontSet.sans, lines[1].toStringz, textAnchor[1], 14, 1, style.textColour);
        DrawTextEx(style.fontSet.sans, lines[2].toStringz, textAnchor[2], 14, 1, style.textColour);
        DrawRectangleLinesEx(area, style.outlineThickness, style.outlineColour);
    }
}

class AttackSpectrumPanel : UIElement
{
    import oe.unit;

    Unit attacker; Unit target;
    AttackSpectrum attackSpectrum;
}