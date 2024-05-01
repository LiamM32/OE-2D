version (fluid):

debug import std.stdio;
import std.conv: to;
import std.uni, std.path;
import fluid;
static if (FLUID_VERSION >= 7) import fluid.theme;
import raylib: Color, Colors, Texture2D;
import constants, sprite, vunit, renderer;
static import raylib;
import fluid.typeface;

static struct FontStyles {
    static FreetypeTypeface[5] fontStyles;

    static FreetypeTypeface getStyle(uint index, string file, uint size)() {
        if (fontStyles[index] is null) {
            fontStyles[index] = new FreetypeTypeface("../sprites/font/"~file, size);
        }
        return fontStyles[index];
    }

    alias headings = getStyle!(0, "LiberationSans-Regular.ttf", 16);
    alias smallText = getStyle!(0, "LiberationSans-Regular.ttf", 12);
}

Theme paperTheme() {
    return Theme(
        rule(backgroundColor = Colours.paper, typeface = FontStyles.headings),
        rule!Frame(backgroundColor = Colours.paper),
        rule!Grid(lineColor = Colors.BLACK, border = 1.0f),
        //rule!Label(typeface = FontStyles.smallText)
    );
}

T to(T=fluid.Texture)(raylib.Texture rayTexture) if (is(T==fluid.Texture)) {
    fluid.Texture result;
    result.id = rayTexture.id;
    return result;
}

class ConditionalNodeSlot(T: Node) : NodeSlot!T
{
    @property bool delegate() @safe condition;

    this(bool delegate() @safe condition, T childNode=null) {
        this.condition = condition;
        opAssign(childNode);
    }
    
    protected override void drawImpl(Rectangle outer, Rectangle inner) {
        if (condition !is null && condition()==true) super.drawImpl(outer, inner);
    }
}

alias unitInfoCard = simpleConstructor!UnitInfoCard;

class UnitInfoCard : Frame, FluidHoverable
{
    VisibleUnit unit;
    alias image = unit.sprite;

    mixin enableInputActions;
    mixin makeHoverable;

    debug Space statsArea;
    
    this(VisibleUnit unit) {
        this.isHorizontal = true;

        sizeLimitX = 256;
        sizeLimitY = 96;

        children ~= vframe(
            label(unit.name),
            //Todo: Replace `.path` with `toFluid` when it starts working.
            imageView((unit.sprite.path)),
        );

        Theme smallTextTheme = paperTheme.derive(rule!Label(typeface = FontStyles.smallText));
        statsArea = vspace(paperTheme, .layout!"fill");
        import std.traits;
        static foreach (stat; FieldNameTuple!UnitStats) static if (stat[0].isUpper) {
            mixin("statsArea.children ~= label(smallTextTheme, .layout!\"fill\", stat~\": \"~"~"unit."~stat~".to!string);");
            debug {
                statsArea.children[$-1].reloadStyles;
                assert(statsArea.children[$-1].style.typeface == FontStyles.smallText);
            }
        }
        children ~= statsArea;

        Renderer renderer = Renderer.instance;

        
    }

    override void resizeImpl(Vector2 availableSpace) {
        super.resizeImpl(availableSpace);

        //minSize = Vector2(256, 72);
        debug assert(statsArea.children[$-1].style.typeface == FontStyles.smallText);
        debug assert(this.style.typeface == FontStyles.headings);
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        super.drawImpl(outer, inner);

        if (isHovered && tree.isMouseDown!(FluidInputAction.press)) {
            Renderer.instance.cursorOnMap = false;
        }

        debug assert(statsArea.children[$-1].style.typeface == FontStyles.smallText);
        debug assert(this.style.typeface == FontStyles.headings);
    }

    override bool isHovered() const @safe => super.isHovered;

    void mouseImpl() @safe {
        Renderer.instance.cursorOnMap = false;
    }
}