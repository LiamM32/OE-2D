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
    Color outlineColour;
    float outlineThickness;
    float padding = 0.0f;
    float lineSpacing = 1.0f;
    FontSet fontSet;

    this(Color baseColour, Color textColour, Color outlineColour, float outlineThickness, FontSet fontSet) {
        this.baseColour = baseColour;
        this.textColour = textColour;
        this.outlineColour = outlineColour;
        this.outlineThickness = outlineThickness;
        this.fontSet = FontSet.getDefault;
    }

    static UIStyle getDefault() {
        if (defaultStyle is null) defaultStyle = new UIStyle(Colours.Paper, Colors.BLACK, Colors.BROWN, 1.0f, FontSet.getDefault);
        return defaultStyle;
    }
}

interface UIElement {
    //void setStyle();
    bool draw(); // Returns whether the mouse is hovering.
    bool draw(Vector2 offset);
}

enum FontStyle { serif, serif_bold, serif_italic, sans, sans_bold, }

class Panel : UIElement
{
    Vector2 origin;
    UIElement[] children;

    this(Vector2 origin, UIElement[] children = []) {
        this.origin = origin;
        this.children = children;
    }
    
    bool draw() {
        return draw(Vector2(0.0f, 0.0f));
    }

    bool draw(Vector2 offset) {
        bool hover;
        foreach (childElement; children) {
            if (childElement.draw(origin+offset)) hover = true;
        }
        return hover;
    }
}

class TextButton : UIElement
{
    Rectangle outline;
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

    this(Rectangle outline, UIStyle style=null, string text, int fontSize, void delegate() action) {
        this.outline = outline;
        this.text = text;

        if (style !is null) this.style = style;
        else this.style = UIStyle.getDefault;
        this.fontSize = fontSize;
        this.onClick = action;
        this.font = style.fontSet.sans_bold;

        Vector2 textDimensions = MeasureTextEx(font, text.toStringz, fontSize, style.lineSpacing);
        this.textAnchor.x = outline.x + (outline.width - textDimensions.x) / 2; // + (textDimensions / 2); // After merging of my version of raylib-d, change to `textAnchor = outline.origin + (outline.dimensions - textDimensions) / 2;`.
        this.textAnchor.y = outline.y + (outline.height - textDimensions.y) / 2;
    }

    bool draw() {return draw(Vector2(0,0));}
    
    bool draw(Vector2 offset) {
        bool hover;
        Rectangle outline = offsetRect(this.outline, offset);
        DrawRectangleRec(outline, style.baseColour);
        DrawTextEx(font, this.text.toStringz, textAnchor+offset, fontSize, style.lineSpacing, style.textColour);
        if(CheckCollisionPointRec(GetMousePosition(), outline)) {
            hover = true;
            DrawRectangleRec(outline, Colours.Highlight);
            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) onClick();
        }
        DrawRectangleLinesEx(outline, style.outlineThickness, style.outlineColour);
        return hover;
    }
}

class MenuList
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
            version (customgui) buttons ~= new TextButton(buttonOutline, style, object.name, 16, delegate {action(cast(ubyte)i);});
            version (raygui) {
                buttonRects ~= buttonOutline;
                optionString ~= object.name~";";
            }
        }
        version (raygui) optionString.length--;
    }

    bool draw(Vector2 offset = Vector2(0.0f,0.0f)) {
        offset += this.origin;
        version (customgui) foreach(i, button; this.buttons) {
            button.draw(offset);
        }
        version (raygui) foreach (i, rect; buttonRects) {
            if (GuiButton(offsetRect(optionRect, offset), optionNames[i].toStringz)) {
                selected = cast(ubyte) i;
                return true;
            }
            writeln("Rectangle is ", optionRect);
        }
        return false;
    }

    bool draw(ref ubyte selected) {
        version (customgui) foreach(i, button; this.buttons) {
            button.draw;
        }
        version (raygui) foreach (i, rect; buttonRects) {
            if (GuiButton(optionRect, optionNames[i].toStringz)) {
                selected = cast(ubyte) i;
                return true;
            }
            writeln("Rectangle is ", optionRect);
        }
        return false;
    }
}



enum Colours {
    Shadow = Color(r:0, b:0, g:0, a:150),
    Highlight = Color(245, 245, 245, 32),
    Startpoint = Color(250, 250, 60, 35),
    Paper = Color(r:240, b:210, g:234, a:250),
    Crimson = Color(160, 7, 16, 255),
}