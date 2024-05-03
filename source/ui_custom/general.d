module ui_custom.general;
// Definitions of general-purpose UI elements

import std.algorithm.comparison;
import raylib;
import ui_custom.base;

class Panel : UIElement
{
    UIElement[] children;
    const Axis axis;
    
    this(Vector2 origin, UIElement[] children = [], const Axis axis = Axis.vertical) {
        this(origin, axis);

        this.children = children;

        foreach(i, ref child; children[1..$]) {
            if (axis == Axis.vertical) {
                child.y = child.y.clamp(children[i-1].bottom, children[i-1].bottom+child.y);
            } else {
                child.x = child.x.clamp(children[i-1].right, children[i-1].bottom+child.x);
            }
        }
    }

    protected this(Vector2 origin, const Axis axis) {
        this.axis = axis;
        //Todo: Change to `this.area.position = origin` when allowed by Raylib-D
        this.area.x = origin.x;
        this.area.y = origin.y;
    }

    void setArea() {
        foreach (child; children) {
            this.x = min(this.x, child.x);
            this.y = min(this.y, child.y);
            this.width = max(this.x+this.width, child.x+child.y) - this.x;
            this.height = max(this.y+this.height, child.x+child.height) - this.y;
        }
    }
    
    override void draw(Vector2 offset = Vector2(0,0)) {
        bool hover;

        if (style !is null) super.drawOutline(offset);

        foreach (childElement; children) {
            childElement.draw(area.origin+offset);
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

        if (style is null) style = UIStyle.buttonStyle;
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
        Rectangle area = this.area + offset;
        DrawRectangleRec(area, style.baseColour);
        DrawTextEx(font, this.text.toStringz, textAnchor+offset, fontSize, style.lineSpacing, style.textColour);
        if(CheckCollisionPointRec(GetMousePosition(), area)) {
            if (updateOnHover && onHover !is null) onHover();
            DrawRectangleRec(area, Colours.whitelight);
            if (IsMouseButtonPressed(MouseButton.MOUSE_BUTTON_LEFT)) onClick();
        }
        DrawRectangleLinesEx(area, style.outlineThickness, style.outlineColour);
    }
}

class MenuList : UIElement
{
    version (customgui) {
        UIStyle style;
        TextButton[] buttons;
        void delegate(ubyte) action;
        UIElement childElement;
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

        if (style is null) style = UIStyle.sheetStyle;
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
        if (childElement !is null) childElement.draw;
    }
}

// Places child elements in a grid.
class ScrollBox : Panel
{
    float scroll; // Scroll position

    this(Vector2 origin, UIElement[] children, const uint maxPerRow, const Axis axis = Axis.vertical) {
        super(origin, axis);
        
        this.children = children;
        this.style = UIStyle.sheetStyle;

        const padding = style.padding;

        struct PositionPtr {
            float* a, b;
            float sizeA, sizeB;

            this(ref Rectangle rect) {
                if (axis == Axis.vertical) {
                    a = &rect.x;
                    sizeA = rect.width;
                    b = &rect.y;
                    sizeB = rect.height;
                } else {
                    a = &rect.y;
                    sizeA = rect.height;
                    b = &rect.x;
                    sizeB = rect.width;
                }
            }

            this(Vector2 position) {
                Rectangle rect = Rectangle(position.tupleof, 0f, 0f);
                
                this(rect);
            }
        }

        Vector2 prevPosition = this.position;
        Vector2 nextRowStart = prevPosition;
        assert(prevPosition.x != 192);
        foreach(i, ref child; children) {
            bool newRow = !(i % maxPerRow);
            ushort compareDist = cast(ushort) (newRow ? maxPerRow : 1);
        
            if (newRow) {
                prevPosition = nextRowStart;
            }

            child.position.x = prevPosition.x + padding;
            child.position.y = prevPosition.y + padding;
            nextRowStart.x = max(nextRowStart.x, child.right);

            prevPosition.x = child.right;
        }
    
        setArea();
    }
}