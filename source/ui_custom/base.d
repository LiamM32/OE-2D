module ui_custom.base;
// Basic classes for custom GUI system

public import std.algorithm.comparison;
public import std.string: toStringz;
debug import std.stdio, std.conv;
public import raylib;
import oe.common;
public import constants;

class FontSet {
    private static FontSet defaultSet;
    
    Font[5] fonts;

    Font serif() { return fonts[0]; }
    Font serif_bold() { return fonts[1]; }
    Font serif_italic() { return fonts[2]; }
    Font sans() { return fonts[3]; }
    Font sans_bold() { return fonts[4]; }

    this() {
        fonts[FontStyle.serif] = LoadFont("../sprites/font/LiberationSerif-Regular.ttf");
        fonts[FontStyle.serif_bold] = LoadFont("../sprites/font/LiberationSerif-Bold.ttf");
        fonts[FontStyle.serif_italic] = LoadFont("../sprites/font/LiberationSerif-Italic.ttf");
        fonts[FontStyle.sans] = LoadFont("../sprites/font/LiberationSans-Regular.ttf");
        fonts[FontStyle.sans_bold] = LoadFont("../sprites/font/LiberationSans-Bold.ttf");
        foreach (ref fontStyle; this.fonts) {
            GenTextureMipmaps(&fontStyle.texture);
            SetTextureFilter(fontStyle.texture, TextureFilter.TEXTURE_FILTER_BILINEAR);
        }
    }

    static FontSet getDefault() {
        if (defaultSet is null) defaultSet = new FontSet();
        return defaultSet;
    }
}

enum FontStyle { serif, serif_bold, serif_italic, sans, sans_bold, }

class UIStyle
{
    protected static UIStyle _sheetStyle;
    protected static UIStyle _cardStyle;
    
    Color baseColour;
    Color textColour;
    Color hoverColour;
    Color outlineColour;
    float outlineThickness;
    float padding = 0.0f;
    float lineSpacing = 1.0f;
    FontSet fontSet;

    this(Color baseColour, Color textColour, Color outlineColour, float outlineThickness, FontSet fontSet, float padding = 0f) {
        this.baseColour = baseColour;
        this.textColour = textColour;
        this.outlineColour = outlineColour;
        this.outlineThickness = outlineThickness;
        this.fontSet = FontSet.getDefault;
        this.padding = padding;
    }

    static UIStyle sheetStyle() {
        if (_sheetStyle is null) _sheetStyle = new UIStyle(Colours.paper, Colors.BLACK, Colors.BROWN, 1.0f, FontSet.getDefault, 2.0f);
        return _sheetStyle;
    }

    alias buttonStyle = sheetStyle;

    static UIStyle cardStyle() {
        if (_cardStyle is null) _cardStyle = new UIStyle(Colours.paper, Colors.BLACK, Colors.BROWN, 1.0f, FontSet.getDefault);
        return _cardStyle;
    }
}

class UIElement {
    static void delegate() onHover;
    protected bool updateOnHover = true;
    UIStyle style;
    Rectangle area;
    alias this = area;

    alias origin = area.origin;
    
    //void setStyle();
    //void draw() {draw(Vector2(0,0));} // Returns whether the mouse is hovering.
    version (raygui) {} else abstract void draw(Vector2 offset = Vector2(0,0));

    bool checkHover() {
        if (updateOnHover && onHover !is null && CheckCollisionPointRec(GetMousePosition, area)) {
            onHover();
            return true;
        } else return false;
    }

    protected void drawOutline(Vector2 offset = Vector2(0,0)) {
        DrawRectangleRec(area + offset, style.baseColour);
    }
}

enum Axis : bool {vertical, horizontal};
