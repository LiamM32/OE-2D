module ui_fluid;

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
    alias smallText = getStyle!(1, "LiberationSans-Regular.ttf", 11);
}

Theme paperTheme() {
    return Theme(
        rule(
            typeface = FontStyles.headings,
            //padding = 2f
        ),
        rule!Frame(
            backgroundColor = Colours.paper,
            border = 1f,
            borderStyle = colorBorder(Colors.BLACK)
        ),
        rule!UnitInfoCard(
            backgroundColor = Colours.lightPaper,
            typeface = FontStyles.smallText,
            margin = 4f,
            borderStyle = colorBorder(Colors.BLACK)
        ),
        rule!Label(
            backgroundColor = Color(0,0,0,0)
        )
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

        children ~= vspace(
            .layout!(2, "fill"),
            label(.layout!("centre","start"), unit.name),
            //Todo: Replace `.path` with `toFluid` when it starts working.
            imageView(.layout!("centre","centre"), unit.sprite.path),
        );

        Theme smallTextTheme = paperTheme.derive(rule!Label(typeface = FontStyles.smallText));
        statsArea = vspace(.layout!(3, "end"));
        import std.traits;
        static foreach (stat; FieldNameTuple!UnitStats) static if (stat[0].isUpper) {
            mixin("statsArea.children ~= label(smallTextTheme, .layout!\"start\", stat~\": \"~"~"unit."~stat~".to!string);");
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
    }

    override void drawImpl(Rectangle outer, Rectangle inner) {
        super.drawImpl(outer, inner);

        if (isHovered && tree.isMouseDown!(FluidInputAction.press)) {
            Renderer.instance.cursorOnMap = false;
        }
    }

    override bool isHovered() const @safe => super.isHovered;

    void mouseImpl() @safe {
        Renderer.instance.cursorOnMap = false;
    }
}