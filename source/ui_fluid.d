version (fluid):

import std.conv: to;
import std.uni;
import fluid;
static if (FLUID_VERSION >= 7) import fluid.theme;
import raylib: Color, Colors, Texture2D;
import constants, sprite, vunit;
import ui: Colours;
static import raylib;

Theme paperTheme() {
    return Theme(
        rule(backgroundColor = Colours.Paper),
        rule!Grid(lineColor = Colors.BLACK, border = 1.0f),
    );
}

T to(T=fluid.Texture)(raylib.Texture rayTexture) if (is(T==fluid.Texture)) {
    fluid.Texture result;
    result.id = rayTexture.id;
    return result;
}

class UnitInfoCard : Frame
{
    VisibleUnit unit;
    alias image = unit.sprite;
    
    this(VisibleUnit unit) {
        this.isHorizontal = true;

        sizeLimitX = 256;
        sizeLimitY = 72;

        children ~= imageView((unit.sprite.path));

        children ~= label(unit.name);
        auto statsArea = vframe(paperTheme, .layout!"fill");
        import std.traits;
        static foreach (stat; FieldNameTuple!UnitStats) static if (stat[0].isUpper) {
            mixin("statsArea.children ~= label(.layout!\"fill\", stat~\": \"~"~"unit."~stat~".to!string);");
        }
        children ~= statsArea;
    }

    override void resizeImpl(Vector2 availableSpace) {
        super.resizeImpl(availableSpace);

        minSize = Vector2(256, 64);
    }

    /*override void drawImpl(Rectangle outer, Rectangle inner) {
        super.drawImpl(outer, inner);
    }*/
}