version (fluid):

import std.conv: to;
import std.uni;
import fluid;
static if (FLUID_VERSION >= 7) import fluid.theme;
import raylib: Color, Colors, Texture2D;
import constants, sprite, vunit;
static import raylib;

Theme paperTheme() {
    return Theme(
        rule(backgroundColor = Colours.paper),
        rule!Frame(backgroundColor = Colours.paper),
        rule!Grid(

            lineColor = Colors.BLACK, border = 1.0f),
    );
}

T to(T=fluid.Texture)(raylib.Texture rayTexture) if (is(T==fluid.Texture)) {
    fluid.Texture result;
    result.id = rayTexture.id;
    return result;
}

class ConditionalNodeSlot(T: Node) : NodeSlot!T
{
    bool delegate() @safe condition;

    this(bool delegate() @safe condition, T childNode=null) {
        this.condition = condition;
        opAssign(childNode);
    }
    
    protected override void drawImpl(Rectangle outer, Rectangle inner) {
        if (condition !is null && condition()==true) super.drawImpl(outer, inner);
    }
}

class UnitInfoCard : Frame
{
    VisibleUnit unit;
    alias image = unit.sprite;
    
    this(VisibleUnit unit) {
        this.isHorizontal = true;

        sizeLimitX = 256;
        sizeLimitY = 96;

        children ~= imageView((unit.sprite.path));

        children ~= label(unit.name);
        auto statsArea = vspace(paperTheme, .layout!"fill");
        import std.traits;
        static foreach (stat; FieldNameTuple!UnitStats) static if (stat[0].isUpper) {
            mixin("statsArea.children ~= label(.layout!\"fill\", stat~\": \"~"~"unit."~stat~".to!string);");
        }
        children ~= statsArea;
    }

    override void resizeImpl(Vector2 availableSpace) {
        super.resizeImpl(availableSpace);

        //minSize = Vector2(256, 72);
    }

    /*override void drawImpl(Rectangle outer, Rectangle inner) {
        super.drawImpl(outer, inner);
    }*/
}