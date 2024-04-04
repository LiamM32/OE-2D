module ui;

debug import std.stdio;
import raylib;
version (raygui) import raygui;
import std.string: toStringz;
import std.algorithm.comparison;
import std.conv;
import vunit;
import unit;
import common;
import vector_math;

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

class UIStyle
{
    static UIStyle defaultStyle;
    
    Color baseColour;
    Color textColour;
    Color hoverColour;
    Color areaColour;
    float areaThickness;
    float padding = 0.0f;
    float lineSpacing = 1.0f;
    FontSet fontSet;

    this(Color baseColour, Color textColour, Color areaColour, float areaThickness, FontSet fontSet) {
        this.baseColour = baseColour;
        this.textColour = textColour;
        this.areaColour = areaColour;
        this.areaThickness = areaThickness;
        this.fontSet = FontSet.getDefault;
    }

    static UIStyle getDefault() {
        if (defaultStyle is null) defaultStyle = new UIStyle(Colours.Paper, Colors.BLACK, Colors.BROWN, 1.0f, FontSet.getDefault);
        return defaultStyle;
    }
}

class UIElement {
    static void delegate() onHover;
    protected bool updateOnHover = true;
    UIStyle style;
    Rectangle area;
    
    //void setStyle();
    //void draw() {draw(Vector2(0,0));} // Returns whether the mouse is hovering.
    version (notRaygui) abstract void draw(Vector2 offset = Vector2(0,0));

    bool checkHover() {
        if (updateOnHover && onHover !is null && CheckCollisionPointRec(GetMousePosition, area)) {
            onHover();
            return true;
        } else return false;
    }
}

enum FontStyle { serif, serif_bold, serif_italic, sans, sans_bold, }

version (customgui) class Panel : UIElement
{
    Vector2 origin;
    UIElement[] children;

    this(Vector2 origin, UIElement[] children = []) {
        this.origin = origin;
        this.children = children;
    }
    
    override void draw(Vector2 offset = Vector2(0,0)) {
        bool hover;
        foreach (childElement; children) {
            childElement.draw(origin+offset);
        }
    }
}

version (customgui) class TextButton : UIElement
{
    Rectangle area;
    UIStyle style;
    Font font;
    string text;
    float fontSize;
    Vector2 textAnchor;
    void delegate() onClick;

    version(FontSet) {
        static this() {
            font = FontSet.getDefault.sans_bold;
        }
    }

    this(Rectangle area, string text, int fontSize, void delegate() action, UIStyle style=null, const bool updateOnHover=true) {
        this.area = area;
        this.text = text;

        if (style is null) style = UIStyle.getDefault;
        this.style = style;
        this.fontSize = fontSize;
        this.onClick = action;
        this.font = style.fontSet.sans_bold;
        this.updateOnHover = updateOnHover;

        Vector2 textDimensions = MeasureTextEx(font, text.toStringz, fontSize, style.lineSpacing);
        this.textAnchor.x = area.x + (area.width - textDimensions.x) / 2; // + (textDimensions / 2); // After merging of my version of raylib-d, change to `textAnchor = area.origin + (area.dimensions - textDimensions) / 2;`.
        this.textAnchor.y = area.y + (area.height - textDimensions.y) / 2;
    }

    override void draw(Vector2 offset = Vector2(0,0)) {
        bool hover;
        Rectangle area = offsetRect(this.area, offset);
        DrawRectangleRec(area, style.baseColour);
        DrawTextEx(font, this.text.toStringz, textAnchor+offset, fontSize, style.lineSpacing, style.textColour);
        if(CheckCollisionPointRec(GetMousePosition(), area)) {
            if (updateOnHover && onHover !is null) onHover();
            DrawRectangleRec(area, Colours.Highlight);
            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) onClick();
        }
        DrawRectangleLinesEx(area, style.areaThickness, style.areaColour);
    }
}

class MenuList : UIElement
{
    version (customgui) {
        UIStyle style;
        TextButton[] buttons;
        void delegate(ubyte) action;
    } version (raygui) {
        Rectangle[] buttonRects;
        string optionString;
    }
    Vector2 origin;

    version (raygui) this(int x, int y) {
        origin.x = x;
        origin.y = y;
    }

    this(ArrayType)(Vector2 origin, ref ArrayType[] array, void delegate(ubyte) action, UIStyle style=null) {
        this.origin = origin;
        this.action = action;

        if (style is null) style = UIStyle.getDefault;
        this.style = style;
        
        foreach (i, object; array) {
            Rectangle buttonOutline = {x:0, y:0, width:96, height:24};
            version (customgui) buttons ~= new TextButton(buttonOutline, object.name, 16, delegate {action(cast(ubyte)i);}, style, false);
            version (raygui) {
                buttonRects ~= buttonOutline;
                optionString ~= object.name~";";
            }
        }
        version (customgui) this.area = Rectangle(x:origin.x, y:origin.y, width:96, height:24*buttons.length);
        version (raygui) optionString.length--;
    }

    version (customgui) override void draw(Vector2 offset = Vector2(0,0)) {
        offset += this.origin;
        foreach(i, button; this.buttons) {
            button.draw(offset);
        }
        checkHover();
    }
}

/*struct TextBox
{
    Rectangle area;
    string text;
    float fontSize;
    Vector2 textAnchor;

    this (Rectangle area, string text, float fontSize, Font font) {
        this.area = area;
        this.fontSize = fontSize;
        Vector2 textDimensions = MeasureTextEx(font, text.toStringz, fontSize, style.lineSpacing);
        this.textAnchor.x = area.x + (area.width - textDimensions.x) / 2; // + (textDimensions / 2); // After merging of my version of raylib-d, change to `textAnchor = area.origin + (area.dimensions - textDimensions) / 2;`.
        this.textAnchor.y = area.y + (area.height - textDimensions.y) / 2;
    }

    void draw(UIStyle style, Font font, Vector2 offset) {
        DrawRectangleRec(offsetRect(area, offset), style.baseColour);
        DrawTextEx(font, this.text.toStringz, textAnchor+offset, fontSize, style.lineSpacing, style.textColour);
        if(CheckCollisionPointRec(GetMousePosition(), area)) DrawRectangleRec(area, Colours.Highlight);
        DrawRectangleLinesEx(area, style.areaThickness, style.areaColour);
    }
}*/

enum Colours {
    Shadow = Color(r:0, b:0, g:0, a:150),
    Highlight = Color(245, 245, 245, 32),
    Startpoint = Color(250, 250, 60, 35),
    Paper = Color(r:240, b:210, g:234, a:250),
    Crimson = Color(160, 7, 16, 255),
}