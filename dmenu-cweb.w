% dmenu-cweb.w: A litterate programing version of dmenu

% \nocon % omit table of contents
\datethis % print date on listing

\newcount\linenum \linenum=0
\font\linefont=cmss8
\def\6{\ifmmode\else\par\hangindent\ind em\noindent
\hbox to 0pt{\hss\global\advance\linenum by 1
\linefont\the\linenum\hskip 7mm}
\hangindent\ind em\noindent\kern\ind em\copy\bakk\ignorespaces\fi}
% USEFUL COMMANDS
\def\newline{\vskip\baselineskip}
\def\header#1{\hbox{\tt #1.h}}
\def\chapterbyname#1{\hbox{\sl \underbar{#1}}}
\def\ampersand{\char38}
\def\bracketleft{[}
\def\nop{}
\def\item{\smallskip\par\hang\textindent}
\def\beginitemize{\begingroup\parindent=36pt\medskip}
\def\enditemize{\medskip\endgroup}

@* Introduction. This is a literate programming version of {\tt dmenu},
a suckless dynamic menu tool for X. Working on this, my main goal is to
learn the rudiments of X Windows programming, but I also hope to further
customize {\tt dmenu} to my own needs. Files untangled from this {\tt CWEB}
source should match those obtained by {\tt git clone https://git.suckless.org/dmenu}
as of commit $${\tt bbc464dc80225b8cf9390f14fac6c682f63940d2}.$$

@ As an (almost) single-file \Cee\  program (it contains one other
module in file {\tt drv.c}), {\tt dmenu} matches the usual template

@c
@<Copyright notice@>@/
@<Header files to include@>@/
@<Enum \ampersand\ struct declarations@>@/
@<Global variables@>@/
@<Functions@>@/
@<The main program@>

@ After some preparatory work, main program calls two functions {\tt setup}
and {\tt run}. The former puts menu widget on the screen; the latter runs 
program's main event loop. The remaining parts of this introductory section
further elaborate different parts of function |main| listed below, with a
single exception of a command line handling that is relegated to the last
section \chapterbyname{Miscellaneous utility functions} as a pretty
straightforward and largely uninteresting code. For a comprehensive list
of supported options, please see table on page 25.

@<The main...@>=
int
main(int argc, char *argv[])
{
	@<Variables local to |main|@>@;@#

	@<Process command line arguments@>;
	@<Connect to X Server@>;
	@<Load fonts@>;
	@<Read menu items from |stdin| \ampersand\ grab keyboard@>;@#
	setup();
	run();
}

@ Immediately after opening connection to X server, we retrieve and store
for future use default screen, it's root window and root window's width
and height.

@s Display int
@<Global variables@>=

static Display *dpy;

@ @<Connect to X...@>=
	@<Initialize locale management@>; @#

	if (!(dpy = XOpenDisplay(NULL))) @/
		die("cannot open display"); @#

	@<Get Default screen and it's root window@>;
	@<Get root window width and height@>;

@ This is a standard way to make X Window client portable across different
locales. First we initialize ANSI-C locale from appropriate environment
variables (that is the meaning of an empty string passed to |setlocale|),
and if that locale is supported by local Xlib installation, we further
initialize Xlib's locale management. For more information, see 
{\sl Xlib Programming Manual for Version 11, Rel 5, volume \bf1 } by
Adrian Nye, section 10.2, page 246.

@<Initialize locale...@>=

	if (!setlocale(LC_CTYPE, "") || !XSupportsLocale()) @/
		fputs("warning: no locale support\n", stderr); @#
	if (!XSetLocaleModifiers("")) @/
		fputs("warning: no locale modifiers support\n", stderr);

@ Default screen and it's root window are stored in global variables

@s Window int
@<Global variables@>+=

static int screen;
static Window root;

@ @<Get Default screen...@>=

	screen = DefaultScreen(dpy);
	root = RootWindow(dpy, screen);

@ For the time being, we ignore the possibility of embedding menu into
user window via {\tt -w} command line option, simply setting |parentwin==root|
and always place menu onto the root window we just acquired above.
If \.{XINERAMA} extension is active on X Window server, this is a logical
window containing within it's extent all attached monitors \footnote*{
Note that original version of {\tt dmenu} supports multiple monitors
only through \.{XINERAMA} extension. In it's absence menu always goes
to default screen.}. This extent is what we are fetching here from
server; where exactly within these boundaries to place menu widget
in order for it to appear on the desired monitor is question left for
later time and function |setup|. Data is passed to function |drw_create|
and stored internally in that module.

@s XWindowAttributes int
@<Variables local to...@>=

	XWindowAttributes wa;

@ @<Get root window...@>=

	parentwin = root;
	if (!XGetWindowAttributes(dpy, parentwin, &wa))
		die("could not get embedding window attributes: 0x%lx",
		    parentwin);
	drw = drw_create(dpy, screen, root, wa.width, wa.height);

@ Loading of fonts is abstracted to module {\tt drw.c}. All main program
needs to know is font height that is also used to determine the amount
of horizontal padding between all text fields.

@<Variables local to...@>+=

static int lrpad; /* sum of left and right padding */

@ @<Load fonts@>=

	if (!drw_fontset_create(drw, fonts, LENGTH(fonts)))
		die("no fonts could be loaded.");
	lrpad = drw->fonts->h;

@ Concerning {\tt -f} option that causes {\tt dmenu} to grab keyboard
before reading |stdin|, man page states: "\dots this is faster, but will
lock up X until |stdin| reaches end-of-file." While I can see how this
could tie X up for an undetermined amount of time, grabbing keyboard and
reading |stdin| happens sequentially, one after the other, and this
procedure takes (in total) exactly the same time, irrespective of order.
What matters here is {\sl User Experience}; if {\tt dmenu} invocation
is triggered by a hot-key, one can just continue typing, and subsequent
keypresses will end up selecting menu item; without {\tt -f}, they would
be consumed by whichever window had focus at a time, until {\tt dmenu}
is finished reading from |stdin|.

@<Read menu items...@>=

	if (fast) {
		grabkeyboard();
		readstdin();
	} else {
		readstdin();
		grabkeyboard();
	}

@ Function |grabkeyboard| is given below; for function |readstdin| please refer
to section \chapterbyname{Menu items}, p. 8. Attempting to grab keyboard, we may
have to wait for another process to ungrab.

@<Functions@>=
void
grabkeyboard()
{
	struct timespec ts = { 0, 1000000 };
	int i;

	if (embed)
		return;
	;@/
	for (i = 0; i < 1000; i++) {
		if (XGrabKeyboard(dpy, DefaultRootWindow(dpy), True, GrabModeAsync,
		                  GrabModeAsync, CurrentTime) == GrabSuccess)
			return;
		nanosleep(&ts, NULL);
	}
	die("cannot grab keyboard");
}

@* Setting up menu widget. This chapter, just like the one preceding it, deals with
a single function, namely  --- |setup|. It's purpose is to set up the menu widget and put it
on the screen. By widget we here mean something very generic: it consists of a single
window and a PixMap to draw onto; the core of menu functionality, thus, actually
resides in a function |drawmenu|, where entire menu gets drawn onto PixMap based on
it's present state.

Surprisingly, by far the largest and the most complex part of this function is
determining menu geometry, due to {\tt XINERAMA}.

@<Functions@>+=
static void
setup(void)
{
	@<Local variables (setup)@>@;@#

	@<Initialize color schemes@>;@/
	@<Prepare to fetch X selection@>;@/
	@<Calculate menu geometry with respect to {\tt XINERAMA}@>;
	@<Apply geometry as specified on the command line@>;
	@<Create menu window@>;
	@<Open input methods@>;
	@<Put menu on the screen@>;

	drw_resize(drw, mw, mh);
	drawmenu();
}

@ Colorschemes are arrays of colorvalues used to draw different parts of menu.
We use three: one for currently selected menu item (\nop|SchemeSel|\nop), one
for already confirmed menu items (\nop|SchemeOut|\nop), and one for everything
else (\nop|SchemeNorm|\nop).

In the original version of program, colorscheme array |colors|'s initialization
was grouped together with other configuration parameters in file {\tt config.h};
in this version, for the sake of simplicity, it is moved here. Finally, note
that colorschemes can be modified at run-time using command line parameters.

@s Clr int
@<Global variables@>+=

enum { SchemeNorm, SchemeSel, SchemeOut, SchemeLast };@#

static const char *colors[SchemeLast][2] = { @t\1@>@/
	[SchemeNorm] = { "#bbbbbb", "#222222" },@/
	[SchemeSel] = { "#eeeeee", "#005577" },@/
	[SchemeOut] = { "#000000", "#00ffff" },@t\2@>@/
};@#

static Clr *scheme[SchemeLast];

@ @<Initialize color...@>=
 
	int j;
	for (j = 0; j < SchemeLast; j++) @/
		scheme[j] = drw_scm_create(drw, colors[j], 2);

@ For pasting text from clipboard we shall need two atoms.  

@<Prepare to fetch X selection@>=

	clip = XInternAtom(dpy, "CLIPBOARD",   False);
	utf8 = XInternAtom(dpy, "UTF8_STRING", False);

@ Menu height depends on line height and number of lines, if menu is vertical.
We calculate it first, since menu vertical position depends on it, in case it
is being placed at the bottom of the screen. Default line height of font height
plus 2 pixels can be overriden by configuration parameter {\tt lineheight}.

@<Calculate menu geometry...@>=

	bh = drw->fonts->h + 2;
	bh = MAX(bh, lineheight);
	lines = MAX(lines, 0);
	mh = (lines + 1) * (bh + intlinegap);

@ If client wasn't compiled with {\tt XINERAMA} support or {\tt XINERAMA}
extension isn't active on the server, simply set menu's geometry according
to dimensions of X server's default screen.

@<Calculate menu geometry...@>=

#ifdef XINERAMA
	if (parentwin == root && (info = XineramaQueryScreens(dpy, &n))) {
		@<Get menu geometry from {\tt XINERAMA}@>;
	} else
#endif
	{
		if (!XGetWindowAttributes(dpy, parentwin, &wa))
			die("could not get embedding window attributes: 0x%lx",
			    parentwin);
		x = 0;
		y = topbar ? 0 : wa.height - mh;
		mw = wa.width;
		sh = wa.height;
	}

@ Now that we have dimensions and positions of all monitors on the logical
{\tt XINERAMA} screen in an array |info|, we are are left with a single
decision to make --- which of these to put the menu widget on?\hfil\break
We use the following rules:

\beginitemize

\item{1.} If monitor is explicitly specified on the command line using
{\tt -m} option, use that.

\item{2.} Otherwise, if some window has focus, find corresponding top-level
window and put menu on the monitor with which it intersects the most.

\item{3.} Otherwise, use the monitor where pointer is currently located.

\enditemize

@<Get menu geometry from...@>=

	XGetInputFocus(dpy, &w, &di);
	if (mon >= 0 && mon < n)
		i = mon;
	else if (w != root && w != PointerRoot && w != None) {
		@<find top-level window containing current input focus@>;
		@<set |i| to {\tt XINERAMA} screen with which window intersects the most@>;
	}
	@<if no focused window is on screen, use pointer location instead@>;

@ After we have chosen the monitor |i|, we set menu geometry accordingly

@<Get menu geometry from...@>+=

	x = info[i].x_org;
	y = info[i].y_org + (topbar ? 0 : info[i].height - mh);
	mw = info[i].width;
	sh = info[i].height;
	XFree(info);

@ Xlib function |XQueryTree| is used to traverse hierarchy of windows on the screen;
given window, it gives parent window and list of it's children. Since we are climbing
up the tree towards it's root, we have no need for children and thus immediately free
this list. The top-level window we are looking for is a direct descendant of root
window or, if something goes wrong, the parentless window.

@<find top-level window...@>=

	do {
		if (XQueryTree(dpy, (pw = w), &dw, &w, &dws, &du) && dws)@#
				XFree(dws);
	} while (w != root && w != pw);

@ It is easy to see that intersection of two intervals $[a_1,b_1]\cap[a_2,b_2]$ has
it's length given by $$\max \bigl( 0, \min (b_1, b_2) - \max (a_1, a_2) \bigr).$$
Accordingly, an area covered by an intersection of two rectangles
$[a^x_1,b^x_1]\times[a^y_1,b^y_1] \cap [a^x_2,b^x_2]\times[a^y_2,b^y_2]$ is given by
$$ \max \bigl( 0, \min (b^x_1,b^x_2) - \max (a^x_1,a^x_2) \bigr) \times
   \max \bigl( 0, \min (b^y_1,b^y_2) - \max (a^y_1,a^y_2) \bigr). $$
We use this at two different places in the code.
 
@d INTERSECT(x,y,w,h,r)  (MAX(0, MIN((x)+(w),(r).x_org+(r).width) @/ 
                        - MAX((x),(r).x_org)) @/
                        * MAX(0, MIN((y)+(h),(r).y_org+(r).height)@/ 
                        - MAX((y),(r).y_org)))
@<set |i| to {\tt XINERAMA} screen...@>=

	if (XGetWindowAttributes(dpy, pw, &wa))
		for (j = 0; j < n; j++)
			if ((a = INTERSECT(wa.x, wa.y, wa.width, wa.height, info[j])) > area) {
				area = a;
				i = j;
			}

@ @<if no focused window is on screen...@>=

	if (mon < 0 && !area && XQueryPointer(dpy, root, &dw, &dw, &x, &y, &di, &di, &du))
		for (i = 0; i < n; i++)
			if (INTERSECT(x, y, 1, 1, info[i]))
				break;

@ Having decided on the menu widget geometry, we now turn to the job of placing
the widget on actual screen. At this stage, it amounts to creating a window;
being a prototypical transient window, we set |override_redirect| to
|True|.

@<Create menu window@>=

	swa.override_redirect = True;
	swa.background_pixel = scheme[SchemeNorm][ColBg].pixel;
	swa.event_mask = ExposureMask | KeyPressMask | VisibilityChangeMask;
	win = XCreateWindow(dpy, parentwin, x, y, mw, mh, 0,
	                    CopyFromParent, CopyFromParent, CopyFromParent,
	                    CWOverrideRedirect | CWBackPixel | CWEventMask, &swa);
	XSetClassHint(dpy, win, &ch);

@ In further support of internationalization, we open connection to input method
manager, supporting the simplest interaction style where input method is left to
draw directly on the root window.

@<Open input methods@>=

	xim = XOpenIM(dpy, NULL, NULL, NULL);
	xic = XCreateIC(xim, XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
	                XNClientWindow, win, XNFocusWindow, win, NULL);

@ Besides mapping window on the screen, and making it focused, we have one more
thing to worry about when menu's parent window is not the root window. Difference
between root window and all other windows is, amongst other things, that root
window can not loose focus; others can, and when they regain it we want menu
to regrab focus if it is still active. In order to do so, we need to receive
|FocusChange| events, so we make sure that appropriate bit is set in event 
masks of menu widget and all of it's siblings. (Why not just the menu widget?)

@<Put menu on the screen@>=
	XMapRaised(dpy, win);
	XSetInputFocus(dpy, win, RevertToParent, CurrentTime);
	if (embed) {
		XSelectInput(dpy, parentwin, FocusChangeMask);
		if (XQueryTree(dpy, parentwin, &dw, &w, &dws, &du) && dws) {
			for (i = 0; i < du && dws[i] != win; ++i)
				XSelectInput(dpy, dws[i], FocusChangeMask);
			XFree(dws);
		}
		grabfocus();
	}

@ We keep width of an input field to at most one third of an entire widget,
correcting, if necessary, the value set previously while reading in the
menu items (to the size of the widest one). We also compute the width of
an optional prompt, if it was specified.

@<Put menu on the screen@>+=
	promptw = (prompt && *prompt) ? TEXTW(prompt) - lrpad / 4 : 0;
	inputw = MIN(inputw, mw/3);

@* Drawing the menu. In this program, menu widget gets redrawn every time
it changes state, always in response to some keyboard event. This is the
sole responsibility of function |drawmenu|, that assumes there is doubly
linked list of all menu items matching input text, and three global pointers
|curr|, |next| and |sel| pointing, respectively, to the members of this
list representing the first, the one following the last displayed menu item,
as well as one currently selected. Before calling |drawmenu|, we should
always make sure this list is up-to-date; as we shall see later, this is
done by calling |match|.

@ Widget itself consists of three distinct parts: optional prompt, input field
and horizontal or vertical list of menu items; we draw them each one after
the other.

@<Functions@>+=
static void
drawmenu(void)
{
	@<Local variables (drawmenu)@>@;@#

	@<Clear PixMap@>;
	@<Draw prompt@>;
	@<Draw input field@>;
	@<Draw cursor@>;@#

	if (lines > 0) @<Draw vertical list@>;
	else if (matches) @<Draw horizontal list@>;@#

	@<Resize window, if necessary@>;
	drw_map(drw, win, 0, 0, mw, mh);
}

@ Menu every time gets redrawn from scratch. First, we clear PixMap with
background color from {\it Normal} colorscheme.

@<Clear PixMap@>=
	drw_setscheme(drw, scheme[SchemeNorm]);
	drw_rect(drw, 0, 0, mw, mh, 1, 1);

@ Local variable |x| keeps track of how far to the right did we get at any
particular time while drawing the menu; it determines where to place the next
menu element. Similarly, local variable |y| keeps track of our vertical
progress, when list is vertical.

@<Local variables (drawmenu)@>=

	int x = 0, y = intlinegap/2;
	int w;

@ First, we draw the prompt, if it was specified on the command line; note how
|x| is advanced by the width of the prompt.

@<Draw prompt@>=
	if (prompt && *prompt) {
		drw_setscheme(drw, scheme[SchemeSel]);
		x = drw_text(drw, x, y, promptw, bh, lrpad / 2, prompt, 0);
	}

@ Input field occupies the entire first line when list is vertical or when
there is no matching menu items; otherwise, we confine it to at most one
third of that line.

@<Draw input field@>=

	w = (lines > 0 || !matches) ? mw - x : inputw;
	drw_setscheme(drw, scheme[SchemeNorm]);
	drw_text(drw, x, y, w, bh, lrpad / 2, text, 0);
	x += inputw;

@ Cursor is drawn as a two-pixel wide vertical line. {\it Since min. line
height patch, {\tt fh} below stands for a font height; vertical offset alligns
cursor with text now centered within potentially heigher
{\tt dmenu} line.}

@<Draw cursor@>=

	curpos = TEXTW(text) - TEXTW(&text[cursor]);
	if ((curpos += lrpad / 2 - 1) < w) {
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_rect(drw, x + curpos, y + 2 + (bh-fh)/2, 2, fh - 4, 1, 0);
	}

@ Vertical list is easier to draw.

@<Draw vertical list@>=
	for (item = curr; item != next; item = item->right, linesdrawn++) @/
		drawitem(item, x, y += intlinegap+bh, mw - x);

@ Horizontal list consists of optional two characters |'<'| and |'>'| at it's
left and right end signaling that there are more menu items in the appropriate
direction, and menu items themselves in between. (Note how |x| is advanced
even if character |'<'| is not drawn; in that case, it is replaced with an
empty space.)

@<Draw horizontal list@>=
	w = TEXTW("<");
	if (curr->left) {
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_text(drw, x, y, w, bh, lrpad / 2, "<", 0);
	}
	x += w;

@ @<Draw horizontal list@>+=

	for (item = curr; item != next; item = item->right)
		x = drawitem(item, x, y, MIN(TEXTW(item->text), mw - x - TEXTW(">")));

@ @<Draw horizontal list@>+=

	if (next) {
		w = TEXTW(">");
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_text(drw, mw - w, y, w, bh, lrpad / 2, ">", 0);
	}

@ Finally, resulting PixMap is copied onto the menu window

@<Draw horizontal list@>+=

	drw_map(drw, win, 0, 0, mw, mh);

@ The code above uses following function in order to draw individual menu items.

@<Functions@>+=
static int
drawitem(struct item *item, int x, int y, int w)
{
	if (item == sel) @/
		drw_setscheme(drw, scheme[SchemeSel]);
	else if (item->out) @/
		drw_setscheme(drw, scheme[SchemeOut]);
	else @/
		drw_setscheme(drw, scheme[SchemeNorm]);@#

	return drw_text(drw, x, y, w, bh, lrpad / 2, item->text, 0);
}

@* Main data structures. There are two main data structures: an array of
menu items where they are stored after being read from |stdin| at the
start of the program, and a doubly linked list of those among these items
that match current content of a text field. There are also four pointers
associated with this list:

\beginitemize

\item{1.} Pointer |sel| keeps track of currently selected menu item, while

\item{2.} pointers |curr|, |prev| and |next| keep track of the first menu
item on the currently displayed menu "page", and on the ones immediately 
before and after it.

\enditemize

To further clarify the meaning of the word "page" in the previous sentence,
keep in mind that menu displays items in pages defined by the amount of text
that fits the widget. Items are paginated in the same way as pages in books
--- imagine going from one to the other end of the list, inserting page
breaks and starting a new page before every item that doesn't (entirely) fit
on the current page. When selected item is at the edge of display, widget
doesn't scroll it's content but displays next (or previous) page of items instead.

@ Menu item is a typical node of a doubly linked list; it's payload consists
of menu item's text and boolean flag specifying whether that item is part of
multiple selection.

@<Enum \ampersand\ struct declarations@>=
struct item {
	char *text;
	struct item *left, *right;
	int out;
};

@ Let's define data structures mentioned above. 

@<Global variables@>+=

static struct item *items = NULL;
static struct item *matches, *matchend;
static struct item *prev, *curr, *next, *sel;

@ The purpose of the following function is to read the menu items from
|stdin| at the start of program. The very last item in an array has
text field set to |NULL| to signal the end of useful data.

The function  has two side effects affecting |inputw| and |lines|. The
former is initialized to the width of the widest menu item; the latter
is constrained to never exceed total number of menu item.

@<Functions@>+=
static void
readstdin(void)
{
	char buf[sizeof text], *p;
	size_t i, imax = 0, size = 0;
	unsigned int tmpmax = 0;@#

	for (i = 0; fgets(buf, sizeof buf, stdin); i++) {
		@<Enlarge storage space, if exausted@>;
		@<Add item to the list@>;
		@<Keep track of widest item@>;
	}@#

	if (items) items[i].text = NULL;
	inputw = items ? TEXTW(items[imax].text) : 0;
	lines = MIN(lines, i);
}

@ Storage is allocated dynamically in increments of |BUFSIZ|\footnote*{{\tt BUFSIZ} 
is a macro defined in {\tt stdio.h} where it stands for default IO buffer size.}
bytes using realloc.

@<Enlarge storage space, if exausted@>=
	if (i + 1 >= size / sizeof *items)
		if (!(items = realloc(items, (size += BUFSIZ))))@/
			die("cannot realloc %u bytes:", size);

@ @<Add item to the list@>=
	if ((p = strchr(buf, '\n'))) *p = '\0';
	if (!(items[i].text = strdup(buf)))@/
		die("cannot strdup %u bytes:", strlen(buf) + 1);
	items[i].out = 0;

@ As already mentioned, while reading menu items, we keep track which
of these has the widest textual representation; we need this information
to determine how much space is needed for a text input field.

@<Keep track of widest item@>=
	drw_font_getexts(drw->fonts, buf, strlen(buf), &tmpmax, NULL);
	if (tmpmax > inputw) {
		inputw = tmpmax;
		imax = i;
	} 

@ Doubly linked list |matches| is built from scratch on every change of
text field content. For this purpose, we consider that menu item matches
content of text field if every word of the latter occurs somewhere within
the former. In ordering this list, we give priority first to exact matches,
then to full prefixes. 

@<Functions@>+=
static void
match(void)
{
	char **tokv = NULL;
	int i, tokc = 0;
	struct item *itema;

	@<Other local variables (match)@>;@#

	@<Separate input text into tokens to be matched individually@>;
	@<Clear various lists@>;@#

	for (itema = items; itema && itema->text; itema++) {
		for (i = 0; i < tokc; i++)
			if (!fstrstr(itema->text, tokv[i]))
				break;@#
		if (i != tokc) /* not all tokens match */
			continue;
		@<Add menu item to appropriate list@>;
	}@#

	@<Concatenate lists@>;
	curr = sel = matches;
	calcoffsets();
}

@ Since we use function |strtok| to parse words from input field, and this is a
function that modifies its argument, we need a temporary buffer to hold another
copy of this string.

@<Other local variables (match)@>=

	char buf[sizeof text], *s;

@ We split content of input field into words, so that array |tokv| contains pointers
to individual words and |tokc| total number of words. Note the rather unfortunate use
of realloc.

@<Separate input text...@>=
	strcpy(buf, text);
	for (s = strtok(buf, " "); s; tokv[tokc - 1] = s, s = strtok(NULL, " "))
		if (++tokc > tokn && !(tokv = realloc(tokv, ++tokn * sizeof *tokv)))
			die("cannot realloc %u bytes:", tokn * sizeof *tokv);@#
	len = tokc ? strlen(tokv[0]) : 0;
	textsize = strlen(text) + 1;

@ Matched items are kept in three separate lists: one for exact matches, one for
full prefixes and one for all others. At the start, we clear all tree lists.

@<Clear various lists@>=
	matches = lprefix = lsubstr = matchend = prefixend = substrend = NULL;

@ Matched item is added to the list it belongs to; this determines it's position
within the master list.

@<Add menu item to appropriate list@>=
	if (!tokc || !fstrncmp(text, itema->text, textsize))@/
		appenditem(itema, &matches, &matchend);
	else if (!fstrncmp(tokv[0], itema->text, len))@/
		appenditem(itema, &lprefix, &prefixend);
	else
		appenditem(itema, &lsubstr, &substrend);

@ The following function used above adds an item to the end of a doubly linked
list in an usual way. 

@<Functions@>+=
appenditem(struct item *itema, struct item **list, struct item **last)
{
	if (*last)
		(*last)->right = itema;
	else
		*list = itema;@#

	itema->left = *last;
	itema->right = NULL;
	*last = itema;
}

@ Finally, three lists are concatenated together to form a master list.

@<Concatenate lists@>=
	if (lprefix) {
		if (matches) {
			matchend->right = lprefix;
			lprefix->left = matchend;
		} else
			matches = lprefix;
		matchend = prefixend;
	}

@ @<Concatenate lists@>+=
	if (lsubstr) {
		if (matches) {
			matchend->right = lsubstr;
			lsubstr->left = matchend;
		} else
			matches = lsubstr;
		matchend = substrend;
	}

@ Since item pagination is dynamic, now that the new master list is created (and
also every time new page is displayed) we have to recalculate pointers to the first
item on previous and next page, |prev| and |next|. This is done by calling function
|calcoffsets|.

@<Functions@>+=
static void
calcoffsets(void)
{
	int i, n;

	if (lines > 0)
		n = lines * bh;
	else
		n = mw - (promptw + inputw + TEXTW("<") + TEXTW(">"));@#

	for (i = 0, next = curr; next; next = next->right)
		if ((i += (lines > 0) ? bh : MIN(TEXTW(next->text), n)) > n)
			break;@#
	for (i = 0, prev = curr; prev && prev->left; prev = prev->left)
		if ((i += (lines > 0) ? bh : MIN(TEXTW(prev->left->text), n)) > n)
			break;
}

@* The input text field. Although program creates just one window and the widget
is painted all in one peace, conceptually it consists of two different parts:
an input text field to the left and a list of menu items to the right; they both
act together as a kind of {\sl combo-box}.\footnote*{As we shell see later on,
when there is no matching menu items, input line takes over the entire widget.}

@ The state of an input line represents one line of text and a cursor position.

@<Global variables@>+=

	static char text[BUFSIZ] = "";
	static size_t cursor;

@ Text is UTF-8 encoded, hence we need a function to find location of next UTF-8
rune in the given direction (+1 for forward, -1 for backwards).

@<Functions@>+=
static size_t
nextrune(int inc)
{
	ssize_t n;

	for (n = cursor + inc; n + inc >= 0 && (text[n] & 0xc0) == 0x80; n += inc)
		;
	return n;
}

@ The following function is used to move through UTF-8 text a word at a time.

@<Functions@>+=
static void
movewordedge(int dir)
{
	if (dir < 0) { /* move cursor to the start of the word*/
		while (cursor > 0 && strchr(worddelimiters, text[nextrune(-1)]))
			cursor = nextrune(-1);
		while (cursor > 0 && !strchr(worddelimiters, text[nextrune(-1)]))
			cursor = nextrune(-1);
	} else { /* move cursor to the end of the word */
		while (text[cursor] && strchr(worddelimiters, text[cursor]))
			cursor = nextrune(+1);
		while (text[cursor] && !strchr(worddelimiters, text[cursor]))
			cursor = nextrune(+1);
	}
}

@ Finally, we will need to insert text at cursor position. Existing text is first
moved out of the way, new text is inserted and cursor updated.

@<Functions@>+=
static void
insert(const char *str, ssize_t n)
{
	if (strlen(text) + n > sizeof text - 1)
		return;@#

	memmove(&text[cursor + n], &text[cursor], sizeof text - cursor - MAX(n, 0));
	if (n > 0)@/
		memcpy(&text[cursor], str, n);
	cursor += n;
	match();
}

@ As we shall see shortly, most of input line behaviors are implemented in
the next section that treats main event loop where program reacts to (mostly)
keyboard events received from X server.
 
@* Main event loop. As with all X clients, an event loop lies at the heart
of the program.

@s XEvent int
@<Functions@>+=
static void
run(void)
{
	XEvent ev;

	while (!XNextEvent(dpy, &ev)) {
		if (XFilterEvent(&ev, None))@/
			continue;
		switch(ev.type) {
			@<Process events according to type@>;
		}
	}
}

@ As per X protocol, we redraw widget on receiving an |Expose| event. One such
event is generated for every rectangular area that needs to be redrawn; we
just wait for the last of these events (\nop|xexpose.count| field contains the
number of |Expose| events still to come from the server), and then redraw the
entire widget. This is a common technique in X programming.

@<Process events...@>=

	case Expose:
		if (ev.xexpose.count == 0)@/
			drw_map(drw, win, 0, 0, mw, mh);
		break;

@ When parent window regains focus, make sure our menu widget regrabs it for
itself, provided it is still active. This can only happen with non-root parent
window, since root window can not loose focus in the first place.

@<Process events...@>+=

	case FocusIn:
		if (ev.xfocus.window != win)@/
			grabfocus();
		break;

@ Try to keep menu widget always on top of the window stack.

@<Process events...@>+=

	case VisibilityNotify:
		if (ev.xvisibility.state != VisibilityUnobscured)@/
			XRaiseWindow(dpy, win);
		break;

@ On receiving |SelectionNotify| event we complete the process of pasting
selection.

@<Process events...@>+=

	case SelectionNotify:
		if (ev.xselection.property == utf8)@/
			paste();
		break;

@ Given the current selection, we now insert it into the input line at current
cursor position.

@<Functions@>+=

static void
paste(void)
{
	char *p, *q;
	int di;
	unsigned long dl;
	Atom da;

	if (XGetWindowProperty(dpy, win, utf8, 0, (sizeof text / 4) + 1, False,
	                   utf8, &da, &di, &dl, &dl, (unsigned char **)&p)
	    == Success && p) {
		insert(p, (q = strchr(p, '\n')) ? q - p : (ssize_t)strlen(p));
		XFree(p);
	}
	drawmenu();
}

@ Since this is a keyboard-only program, it is only natural that most complexity
(and program logic) lies in handling of keyboard events. This is delegated to a
separate function.

@<Process events...@>+=

	case KeyPress:@/
		keypress(&ev.xkey);@/
		break;

@ @s KeySym int
@s Status int
@s XKeyEvent int
@<Functions@>+=
static void
keypress(XKeyEvent *ev)
{
	char buf[32];
	int len;
	KeySym ksym;
	Status status;

	len = XmbLookupString(xic, ev, buf, sizeof buf, &ksym, &status);@t\1@>
	switch (status) {
	default: return; /* XLookupNone, XBufferOverflow */
	case XLookupChars:
		goto insert;
	case XLookupKeySym:@/@t\4@>
	case XLookupBoth:
		break;@t\4@>
	}@t\4@>
	@<Process key event@>;@t\4@>
draw:@/@t\4@>
	drawmenu();@t\4@>
}

@ We treat separately ctrl+key, alt+key and normal key events.

@<Process key event@>=

	if (ev->state & ControlMask)
		switch(ksym) { @+@<Process ctrl+key events@>;@+ }
	else if (ev->state & Mod1Mask) 
		switch(ksym) { @+@<Process alt+key events@>;@+ }

	switch(ksym) { @+@<Process remaining key events@>;@+ }

@ Many ctrl+key shortcuts are just aliases for other control keys.

@<Process ctrl+key events@>=

	case XK_a: ksym = XK_Home;@+      break;
	case XK_b: ksym = XK_Left;@+      break;
	case XK_c: ksym = XK_Escape;@+    break;
	case XK_d: ksym = XK_Delete;@+    break;
	case XK_e: ksym = XK_End;@+       break;
	case XK_f: ksym = XK_Right;@+     break;
	case XK_g: ksym = XK_Escape;@+    break;
	case XK_h: ksym = XK_BackSpace;@+ break;
	case XK_i: ksym = XK_Tab;@+       break;@/
	case XK_j: @/@t\4@>
	case XK_J: @/@t\4@>
	case XK_m: @/@t\4@>
	case XK_M: ksym = XK_Return; @+ev->state &= ~ControlMask; @+break;
	case XK_n: ksym = XK_Down;@+      break;
	case XK_p: ksym = XK_Up;@+        break;@+

@ Kill text to the right until the end of line.

@<Process ctrl+key events@>+=

	case XK_k:@/
		text[cursor] = '\0';
		match();
		break;

@ Kill text to the left until the start of line.

@<Process ctrl+key events@>+=

	case XK_u: /* delete left */
		insert(NULL, 0 - cursor);
		break;

@ Kill word to the left. First delete delimiters at the end of the word,
then word itself.

@<Process ctrl+key events@>+=
	case XK_w: /* delete word */
		while (cursor > 0 && strchr(worddelimiters, text[nextrune(-1)]))@/
			insert(NULL, nextrune(-1) - cursor);
		while (cursor > 0 && !strchr(worddelimiters, text[nextrune(-1)]))@/
			insert(NULL, nextrune(-1) - cursor);@/
		break;

@ Paste selection. Here we initiate the process, by sending server a request.
It will be completed in an event handler, after receiving |SelectionNotify| event.

@<Process ctrl+key events@>+=

	case XK_y:@/@t\4@>
	case XK_Y:
		XConvertSelection(dpy, (ev->state & ShiftMask) ? clip : XA_PRIMARY,
				  utf8, utf8, win, CurrentTime);
		return;

@ Move left/right to the start/end of previous/next word.

@<Process ctrl+key events@>+=

	case XK_Left:
		movewordedge(-1);
		goto draw;@#
	case XK_Right:
		movewordedge(+1);
		goto draw;

@ Ctrl-Enter is handled together with plain Enter.

@<Process ctrl+key events@>+=

	case XK_Return:@/@t\4@>
	case XK_KP_Enter:@/
		break;

@ Shortcut {ctrl+\bracketleft} is an alias for ESC.

@<Process ctrl+key events@>+=

	case XK_bracketleft:@/
		cleanup();
		exit(1);

@ Alt+key shortcuts are also aliases for other keys.

@<Process alt+key events@>=
	case XK_g: ksym = XK_Home;@+  break;
	case XK_G: ksym = XK_End;@+   break;
	case XK_h: ksym = XK_Up;@+    break;
	case XK_j: ksym = XK_Next;@+  break;
	case XK_k: ksym = XK_Prior;@+ break;
	case XK_l: ksym = XK_Down;@+  break;

@ When the pressed key represents an ordinary letter, it is inserted in the
text field at cursor position.

@<Process remaining key events@>=

insert:
	if (!iscntrl(*buf))
		insert(buf, len);
	break;

@ Delete and Backspace keys do what they usually do. Do note the fallthrough
between cases for Delete and Backspace.

@<Process remaining key events@>+=

	case XK_Delete:
		if (text[cursor] == '\0')
			return;
		cursor = nextrune(+1);@#

	case XK_BackSpace:
		if (cursor == 0)
			return;
		insert(NULL, nextrune(-1) - cursor);
		break;

@ ESC exits the program.

@<Process remaining key events@>+=

	case XK_Escape:@/
		cleanup();
		exit(1);

@ Pressing End moves cursor to the end of an input line, if it wasn't already there.
If it was, it moves selection to the last menu item. In this latter case, we want
|sel=matchend| and we want to paginate items so that last page comes out (almost)
full. In order to do that, we proceed as follows.

First, we temporarily leave the final page completely empty except for the very
last item, and move back to the beginning of the previous page using function
|calcoffsets|. If all menu items fit on a single page, we are done. Otherwise,
we know that to the right of current position we have more than a page worth of
items, so beginning of the last page we are looking for must also be to the right;
we proceed in that direction item by item until |next==NULL| returned by |calcoffsets|
signals that we have landed on the last page.

@<Process remaining key events@>+=

	case XK_End:
		if (text[cursor] != '\0') {
			cursor = strlen(text);
			break;
		}
		if (next) {
			curr = matchend;
			calcoffsets();
			curr = prev;
			calcoffsets();
			while (next && (curr = curr->right))
				calcoffsets();
		}
		sel = matchend;
		break;

@ Home key works in similar manner, but this time we have no problem with pagination.

@<Process remaining key events@>+=

	case XK_Home:
		if (sel == matches) {
			cursor = 0;
			break;
		}
		sel = curr = matches;
		calcoffsets();
		break;

@ When menu is vertical, keys Left/Right move cursor, while Up/Down move
selection; when it is horizontal, Left/Right also move selection and does
not move the cursor unless there are no matching menu items, in which case
they still do (move the cursor). We also move the cursor if selection is
already at the first/last menu item unable to move any further.

Finally, note the fall though between Left and Up and Right and Down cases,
respectively.

@ This is code for handling Left/Right and Up/Down keypresses, continued
from previous page.

@<Process remaining key events@>+=

	case XK_Left:
		if (cursor > 0 && (!sel || !sel->left || lines > 0)) {
			cursor = nextrune(-1);
			break;
		}
		if (lines > 0)
			return;
		/* fallthrough */@#
	case XK_Up:
		if (sel && sel->left && (sel = sel->left)->right == curr) {
			curr = prev;
			calcoffsets();
		}
		break;

@ @<Process remaining key events@>+=

	case XK_Right:
		if (text[cursor] != '\0') {
			cursor = nextrune(+1);
			break;
		}
		if (lines > 0)
			return;
		/* fallthrough */@#
	case XK_Down:
		if (sel && sel->right && (sel = sel->right) == next) {
			curr = next;
			calcoffsets();
		}
		break;

@ Pageup/Pagedown keys move selection to the start of previous/next display page.

@<Process remaining key events@>+=

	case XK_Next:
		if (!next)
			return;
		sel = curr = next;
		calcoffsets();
		break;@#

	case XK_Prior:
		if (!prev)
			return;
		sel = curr = prev;
		calcoffsets();
		break;

@ Tab key copies the selected item into the input field.

@<Process remaining key events@>+=

	case XK_Tab:
		if (!sel)
			return;
		strncpy(text, sel->text, sizeof text - 1);
		text[sizeof text - 1] = '\0';
		cursor = strlen(text);
		match();
		break;

@ Both Enter and Ctrl+Enter print selected menu item to |stdout|;
the former also exits, returning success. Previously selected
items are marked with |sel->out=1|.

@<Process remaining key events@>+=
	@t\2@>case XK_Return:@/
	@t\1@>case XK_KP_Enter:@#
		puts((sel && !(ev->state & ShiftMask)) ? sel->text : text);
		if (!(ev->state & ControlMask)) {
			cleanup();
			exit(0);
		}
		if (sel)
			sel->out = 1;
		break;

@* Module {\tt drw}. This module contains graphical primitives used to draw
the widget. Even though this is an X client, it's UI is essentially 
{\sl Text-based user interface}, so everything boils down to drawing text.
We use libXft library, which in turn uses libfontconfig and libfreetype
to render glyphs, and {\tt RENDER} extension on the server to put glyphs
on the actual screen.\smallskip

Module's public API contains the following functions:

\beginitemize

\item{$\bullet$} 3 module's initialization/clean-up functions: |drw_create|,
|drw_resize|, |drw_free|;

\item{$\bullet$} 3 functions setting graphical context: |drw_fontset_create|,
|drw_scm_create|, |drw_setscheme|;

\item{$\bullet$} 4 drawing functions: |drw_rect|, |drw_text|, |drw_map| and
|drw_fontset_getwidth|.

\enditemize

@ We abstract details of libXft by providing a rectangular Pixmap you can
draw text on (in various colors) using simplified function |drw_text|; when
finished, you put Pixmap on the screen using |drw_map|. At any one time there
can be any number of these Pixmaps in use; each is represented by the following
structure that also keeps track of fonts and colors used in the process.

@s Drawable int
@s GC int
@s Clr int
@s Fnt int
@<Definition of |struct Drw|@>=

typedef struct {
	unsigned int w, h;
	Display *dpy;
	int screen;
	Window root;
	Drawable drawable;
	GC gc;
	Clr *scheme;
	Fnt *fonts;
} Drw;

@ Constructing these objects involves little more than allocating Pixmap, with
fonts and colors having been deferred for later; default graphic context is
created, and it's {\it line style} set (this is used by function |drw_rect|).

{\bf Additional note:} An argument can be made that even Pixmap allocation should
be moved out of constructor and also deferred for later. As {\tt dmenu} code now
stands, Pixmap is allocated with dimensions inferred from the root window, only
to be immediately deallocated and allocated again when program determines right
dimensions for the widget, even if they are the same.

@<Drw module functions@>=
Drw *
drw_create(Display *dpy, int screen, Window root, unsigned int w, unsigned int h)
{
	Drw *drw = ecalloc(1, sizeof(Drw));@#

	drw->dpy = dpy;
	drw->screen = screen;
	drw->root = root;
	drw->w = w; @+
	drw->h = h; @#
	drw->drawable = XCreatePixmap(dpy, root, w, h, DefaultDepth(dpy, screen));
	drw->gc = XCreateGC(dpy, root, 0, NULL);
	XSetLineAttributes(dpy, drw->gc, 1, LineSolid, CapButt, JoinMiter);@#

	return drw;
}

@ This function sets Pixmap dimensions at a later time, when |struct Drw| has
already been created. Existing Pixmap, if any, is first freed, then new one
allocated with proper dimensions.

@<Drw module functions@>+=
void
drw_resize(Drw *drw, unsigned int w, unsigned int h)
{
	if (!drw)
		return;

	drw->w = w;
	drw->h = h;
	if (drw->drawable)
		XFreePixmap(drw->dpy, drw->drawable);
	drw->drawable = XCreatePixmap(drw->dpy, drw->root, w, h, DefaultDepth(drw->dpy, drw->screen));
}

@ Destructor for |struct Drw| first frees Pixmap, then graphic context and
structure itself.

@<Drw module functions@>+=
void
drw_free(Drw *drw)
{
	XFreePixmap(drw->dpy, drw->drawable);
	XFreeGC(drw->dpy, drw->gc);
	free(drw);
}

@ Recall that color schemes are color pairs (Foreground/Background color) used
to draw different parts of the widget. Before going further, in order to improve
readability and in the name of abstracting libXft details, we introduce two
definitions.

@<Drw module enums \ampersand typedefs@>=

	enum {@+ ColFg, ColBg @+}; /* Clr scheme index */
	typedef XftColor Clr;

@ In configuration file (since this program adheres to the {\it suckless 
philosophy}, that would be {\tt config.h}) and on the command line, colors 
are specified by their X names or in hexadecimal notation. Both are strings,
but functions from libXft need pointers to |struct XftColor| (alias |Clr|)
as returned by |XftColorAllocName|, so we need function to convert former
into the latter.

@<Drw module functions@>+=
void
drw_clr_create(Drw *drw, Clr *dest, const char *clrname)
{
	if (!drw || !dest || !clrname)
		return;@#

	if (!XftColorAllocName(drw->dpy, DefaultVisual(drw->dpy, drw->screen),@|
	                       DefaultColormap(drw->dpy, drw->screen),
	                       clrname, dest))@\
		die("error, cannot allocate color '%s'", clrname);
}

@ The following wrapper around previous function above takes a pointer to an
array of strings containing color names and returns a newly allocated array of
corresponding |Clr| structures. Keep in mind that it is the responsibility of
the caller to free returned array when done using it.

@<Drw module functions@>+=
Clr *
drw_scm_create(Drw *drw, const char *clrnames[], size_t clrcount)
{
	size_t i;
	Clr *ret;

	/* need at least 2 colors for a scheme */
	if (!drw || !clrnames || clrcount < 2 || !(ret = ecalloc(clrcount, sizeof(Clr))))@/
		return NULL;@#

	for (i = 0; i < clrcount; i++)@/
		drw_clr_create(drw, &ret[i], clrnames[i]);@#
	return ret;
}

@ Fonts you can draw characters with are represented by |struct Fnt|. Fonts
belongs to fontsets --- it is them that are specified when drawing text
instead of individual fonts; when certain glyph is not found in the first
font, the other fonts function as a fallback, and glyph is rendered from
the first one that has it. Fontsets are linked lists, hence field |next|
in the structure; field |h| contains font height.

@s XftFont int
@s FcPattern int
@<Definition of |struct Fnt|@>=

typedef struct Fnt {
	Display *dpy;
	unsigned int h;
	XftFont *xfont;
	FcPattern *pattern;
	struct Fnt *next;
} Fnt;

@ Initializing |struct Fnt| involves opening font for use with libXft through
it's functions {\it XftFontOpenName} or {\it XftFontOpenPattern}; returned
|struct XftFont| is stored in the field {\it xfont}. The following function
allows us to use both fontconfig name or |struct FcPattern| when specifying
font, the latter primarily because it is needed by {\tt drw} module itself
when handling the case where glyph is not found in any of the fonts from the
set. (In that case we have to rely on fontconfig substitution mechanism and
functions {\it FcConfigSubstitute}, {\it FcDefaultSubstitute}, {\it FcMatch}
involved take their arguments and return value in the form of |struct FcPattern|.
In the end, we need to open thus computed fallback font in order to draw the
glyph.)

@<Drw module functions@>+=
static Fnt *
xfont_create(Drw *drw, const char *fontname, FcPattern *fontpattern)
{
	Fnt *font;
	XftFont *xfont = NULL;
	FcPattern *pattern = NULL;

	if (fontname) { @<Initialize |xfont| and |pattern| using |fontname|@> }
	else if (fontpattern) { @<Initalize |xfont| using |fontpattern|@> }
	else die("no font specified");@#

	font = ecalloc(1, sizeof(Fnt));
	font->xfont = xfont; @+
	font->pattern = pattern;
	font->h = xfont->ascent + xfont->descent;@+
	font->dpy = drw->dpy;@#

	return font;
}

@ When font is specified by name, we cache pattern |FcNameParse(fontname)|
since using \\{font}\MG\\{xfont}\MG\penalty0\\{pattern} for fontconfig fallback calculations
is not really an option; this would simply result in missing-character
rectangles instead of a desired fallback behavior (probably because this
pattern represents fully matched font). 

@<Initialize |xfont| and |pattern| using |fontname|@>=

	if (!(xfont = XftFontOpenName(drw->dpy, drw->screen, fontname))) {
		fprintf(stderr, "error, cannot load font from name: '%s'\n", fontname);
		return NULL;
	}@#

	if (!(pattern = FcNameParse((FcChar8 *) fontname))) {
		fprintf(stderr, "error, cannot parse font name to pattern: '%s'\n", fontname);
		XftFontClose(drw->dpy, xfont);
		return NULL;
	}

@ @<Initalize |xfont| using |fontpattern|@>=

	if (!(xfont = XftFontOpenPattern(drw->dpy, fontpattern))) {
		fprintf(stderr, "error, cannot load font from pattern.\n");
		return NULL;
	}

@ Again a wrapper around previous function takes a pointer to an array of strings
specifying font names and uses them to initialize new font set.

@<Drw module functions@>+=
Fnt*
drw_fontset_create(Drw* drw, const char *fonts[], size_t fontcount)
{
	Fnt *cur, *ret = NULL;
	size_t i;

	if (!drw || !fonts)
		return NULL;@#

	for (i = 1; i <= fontcount; i++) {
		if ((cur = xfont_create(drw, fonts[fontcount - i], NULL))) {
			cur->next = ret;
			ret = cur;
		}
	}
	return (drw->fonts = ret);
}

@ Corresponding destructors.

@<Drw module functions@>+=
static void
xfont_free(Fnt *font)
{
	if (!font)
		return;
	if (font->pattern)
		FcPatternDestroy(font->pattern);
	XftFontClose(font->dpy, font->xfont);
	free(font);
}

@ @<Drw module functions@>+=
void
drw_fontset_free(Fnt *font)
{
	if (font) {
		drw_fontset_free(font->next);
		xfont_free(font);
	}
}

@ Function |drw_text| does all the work drawing actual characters, or when
it's not rendering anything, it has dual purpose to calculate the width in
pixels of text it would otherwise draw. Basically, for each unicode code
point in text we determine whether this glyph is present in the first font
of the set, and if not, which font to use as fallback. Consecutive characters
to be drawn using the same font are grouped together, and text is drawn
onto Pixmap using libXft. Text is clipped inside given rectangle with
padding of |lpad| pixels at both ends; colors are inverted if |invert|
argument is set.

@<Drw module functions@>+=
int
drw_text(Drw *drw, int x, int y, unsigned int w, unsigned int h, unsigned int lpad, const char *text, int invert)
{
	@<Local variables (drwtext)@>;
	int render = x || y || w || h;

	if (!drw || (render && !drw->scheme) || !text || !drw->fonts)@/
		return 0;@#

	@<Prepare to draw text@>;@#

	while (*text)
	{
		@<Advance |text| past it's maximal prefix to be drawn with the same font@>;
		@<Draw this prefix using libXft@>;
	}
	
	@<Perform neccessary cleanup@>;@#

	return x + (render ? w : 0);
}

@ In preparation for drawing text, we clear clipping rectangle, filling it
with background color (or foreground color if colors are inverted). Since
libXft functions draw on special |struct XftDraw| objects, one is created
from |drw->drawable| pixmap; finaly, clipping rectangle is adjusted for
left/right padding.\smallskip

When function is called with an empty clipping rectangle in order to just
compute pixel extent of the string, none of this is necessary; instead we
set clipping width |w| to a maximal value (note that |w| is |unsigned int|)
so as to not interfere with calculations and trigger clipping. 

@<Prepare to draw text@>=

	if (render) {
		XSetForeground(drw->dpy, drw->gc, drw->scheme[invert ? ColFg : ColBg].pixel);
		XFillRectangle(drw->dpy, drw->drawable, drw->gc, x, y, w, h);
		d = XftDrawCreate(drw->dpy, drw->drawable,
		                  DefaultVisual(drw->dpy, drw->screen),
		                  DefaultColormap(drw->dpy, drw->screen));
		x += lpad;
		w -= lpad;
	} else  w = ~w;

@ Before going any further, let's declare some local variables to be used by the
code in the loop above.

@<Local variables (drwtext)@>=

	Fnt *usedfont = NULL, *curfont, *drawfont;
	int utf8strlen, utf8charlen;
	long utf8codepoint = 0;
	const char *utf8str;
	int onedge = 0;

@ The first step in the loop consists of grouping together unicode codepoints
from the start of the string that can subsequently be rendered in one go
using the same font (we shall call these glyphs {\it a prefix}). At the
end of this code, |utf8str| points to the start of the prefix, |utf8strlen|
contains it's length, and |drawfont| and |usedfont| fonts appropriate for
drawing prefix and the next glyph following it's end, respectively.
Since finding these fonts can be quite expensive (especially when it involves
asking for fontconfig fallback font), we make a point of reusing |usedfont|
as |curfont| in the first iteration of loop below. First prefix, though,
represents an edge case where we can't do that --- first glyph in the text is,
in the first iteration of our loop, really encountered for the very first time,
so we can't know in advance which font is appropriate. For this reason, we
initialize (somewhat conunterintuitively) |onedge| to |0| and |usedfont|
to |NULL|; in this way, first pass through the code below results in a
zero-length prefix, but |usedfont| is set to the right font.

@<Advance |text|...@>=
		
	utf8strlen = 0;
	utf8str = text;@#

	while (*text)@/
	{
		utf8charlen = utf8decode(text, &utf8codepoint, UTF_SIZ);
		if (onedge) onedge = 0;
		else curfont = find_font_fora_glyph(utf8codepoint, drw);@#

		if (curfont == usedfont) {
			utf8strlen += utf8charlen;
			text += utf8charlen;
		} else {
			drawfont = usedfont;
			usedfont = curfont; @+onedge = 1;
			break;
		}
	}

@ Finding the right font for each glyph is delegated to a function |find_font_fora_glyph|.

@<Drw module functions@>+=
Fnt *find_font_fora_glyph(long utf8codepoint, Drw *drw)
{
	Fnt *font;

	for (font = drw->fonts; font; font = font->next)
		if (XftCharExists(drw->dpy, font->xfont, utf8codepoint))@/
			break;@#

	if (!font) font = find_fontconfig_fallback(utf8codepoint, drw);
	return font;
}

@ If fontconfig finds glyph in fallback font, this font is added to the
end of fontset, caching it for possible future reuse.

@s FFcPattern int
@<Drw module functions@>+=
Fnt *find_fontconfig_fallback(long utf8codepoint, Drw *drw)
{
	FFcPattern *match;
	Fnt *font, *itr;

	match = query_fontconfig(utf8codepoint, drw);@#

	if (match) {
		font = xfont_create(drw, NULL, match);
		if (font && XftCharExists(drw->dpy, font->xfont, utf8codepoint)) {
			for (itr = drw->fonts; itr->next; itr = itr->next) ; 
			itr->next = font;
			return font;
		} else  xfont_free(font);
	}
	return drw->fonts;
}

@ In order to actually get fallback font from fontconfig we take |struct FcPattern|
parsed from original primary font specification, add to it |CharSet| property
requesting the presence of the glyph in question, apply to it substitution rules
currently in place, and finally, match it against installed fonts. If pattern
matches no font, function returns |NULL|.

@s FcCharSet int
@<Drw module functions@>+=
FcPattern *query_fontconfig(long utf8codepoint, Drw *drw)
{
	FcCharSet *fccharset;
	FcPattern *fcpattern;
	FcPattern *match;

	fccharset = FcCharSetCreate();
	FcCharSetAddChar(fccharset, utf8codepoint);@#

	if (!drw->fonts->pattern)
		die("the first font in the cache must be loaded from a font string.");@#

	fcpattern = FcPatternDuplicate(drw->fonts->pattern);
	FcPatternAddCharSet(fcpattern, FC_CHARSET, fccharset);
	FcPatternAddBool(fcpattern, FC_SCALABLE, FcTrue);@#

	FcConfigSubstitute(NULL, fcpattern, FcMatchPattern);
	FcDefaultSubstitute(fcpattern);
	match = XftFontMatch(drw->dpy, drw->screen, fcpattern, &result);@#

	FcCharSetDestroy(fccharset);
	FcPatternDestroy(fcpattern);
	return match;
}

@ Now that we have font, glyphs needs to be drawn; it all boils down to calling
{\it XftDrawStringUtf8}. Zero-length prefixes are ignored and text is
centered vertically within clipping rectangle by using an offset of |ty| below.

@<Draw this prefix...@>=
	if (utf8strlen) {
		@<Shorten text if necessary@>;
		if (newlen) {
			@<Copy text to temporary buffer |buf| adding ellipsis if shortend@>;
			if (render) {
				ty = y + (h - drawfont->h) / 2 + drawfont->xfont->ascent;
				XftDrawStringUtf8(d, &drw->scheme[invert ? ColBg : ColFg],
						  drawfont->xfont, x, ty, @[(XftChar8 *) buf@], len);
			}
			x += ew;
			w -= ew;
		}
	}

@ @<Shorten text if necessary@>=

	drw_font_getexts(drawfont, utf8str, utf8strlen, &ew, NULL);
	for (newlen = MIN(utf8strlen, sizeof(buf) - 1); newlen && ew > w; newlen--)
		drw_font_getexts(drawfont, utf8str, len, &ew, NULL);

@ I am not quiet sure this codes appends an ellipsis in the form of three '.'
characters to the shortened text in a correct way. What, for example, if last
code point in the text is a 4-byte one?
 
@<Copy text to temporary buffer...@>=
	memcpy(buf, utf8str, newlen);
	buf[newlen] = '\0';
	if (newlen < utf8strlen)
		for (i = newlen; i && i > newlen - 3; buf[--i] = '.') ;

@ In the code above we use function |drw_font_getexts| to get extents of text
as would be drawn by |XftDrawStringUtf8|; it's a simple wrapper around
|XftTextExtentsUtf8|.

@s XGlyphInfo int
@<Drw module functions@>+=
void
drw_font_getexts(Fnt *font, const char *text, unsigned int len, unsigned int *w, unsigned int *h)
{
	XGlyphInfo ext;

	if (!font || !text)
		return;@#

	XftTextExtentsUtf8(font->dpy, font->xfont, @[(XftChar8 *)text@], len, &ext);@#
	if (w)
		*w = ext.xOff;
	if (h)
		*h = font->h;
}

@ Similarly, |drw_fontset_getwidth| is a wrapper around |drw_text|
returning extents of text as would be drawn by |drw_text|. Unlike previous
function, which is intended for internal use within this module only, this
one is part of user facing API. In {\tt dmenu} it is used primarily through
the macro defined below.\smallskip

@d TEXTW(X)  (drw_fontset_getwidth(drw, (X)) + lrpad)
@<Drw module functions@>+=
unsigned int
drw_fontset_getwidth(Drw *drw, const char *text)
{
	if (!drw || !drw->fonts || !text)@/
		return 0;
	return drw_text(drw, 0, 0, 0, 0, 0, text, 0);
}

@ Function |drw_map| displays the content of Pixbuf at the given place
on the screen. Keep in mind that coordinates |x, y| are relative to the
top-left edge of menu widget, not screen!

@<Drw module functions@>+=
void
drw_map(Drw *drw, Window win, int x, int y, unsigned int w, unsigned int h)
{
	if (!drw)
		return;@#

	XCopyArea(drw->dpy, drw->drawable, win, drw->gc, x, y, w, h, x, y);
	XSync(drw->dpy, False);
}

@ Function |drw_rect| draws the outline of the specified rectangle; if |filled|
is non-zero, this rectangle is also filled. 

@<Drw module functions@>+=
void
drw_rect(Drw *drw, int x, int y, unsigned int w, unsigned int h, int filled, int invert)
{
	if (!drw || !drw->scheme)
		return;@#
	XSetForeground(drw->dpy, drw->gc, invert ? drw->scheme[ColBg].pixel : drw->scheme[ColFg].pixel);@#
	if (filled)
		XFillRectangle(drw->dpy, drw->drawable, drw->gc, x, y, w, h);
	else
		XDrawRectangle(drw->dpy, drw->drawable, drw->gc, x, y, w - 1, h - 1);
}

@* UTF8 decoder. UTF8 is a multi-byte character encoding capable of encoding all
valid code points in unicode using 1-4 bytes. The bit pattern of the first byte
indicates the number of continuation bytes. Entire format can be summarized by
the following table (the {\tt x} placeholders are the bits of the encoded code
point):\medskip

$$\vbox{\settabs\+\indent&length\qquad&{\tt 0xxxxxxx}\qquad&{\tt 0xxxxxxx}\qquad&
{\tt 0xxxxxxx}\qquad&{\tt 0xxxxxxx}\cr
\+&length&byte[0]&byte[1]&byte[2]&byte[3]\cr
\smallskip
\+&1&{\tt 0xxxxxxx}\cr
\+&2&{\tt 110xxxxx}&{\tt 10xxxxxx}\cr
\+&3&{\tt 1110xxxx}&{\tt 10xxxxxx}&{\tt 10xxxxxx}\cr
\+&4&{\tt 11110xxx}&{\tt 10xxxxxx}&{\tt 10xxxxxx}&{\tt 10xxxxxx}\cr
}$$\medskip

Note that not all sequences of bytes are valid UTF8. In particular,

\beginitemize

\item{$\bullet$} bytes of the form {\tt 11111xxx} can not appear anywhere
within a valid UTF8 string; they certainly are not continuation bytes,
and as a beginning of 4-byte sequence, they yield code points outside of
valid Unicode range.

\item{$\bullet$} Multi-byte sequences yielding code points that could have
been encoded with fewer bytes are also invalid (the so-called {\it overlong
encodings}), as well as

\item{$\bullet$} sequences where leading byte is not followed by enough
continuation bytes (which can happen in simple string truncation), and

\item{$\bullet$} an unexpected continuation in place of a leading byte.

\item{$\bullet$} Since RFC 3629 the high and low surrogate halves used by
UTF16, D800--DFFF are not valid unicode code points and their UTF8 encodings
must also be treated as invalid.

\enditemize

All of this yields following valid ranges for each multi-byte sequence:
\medskip

$$\vbox{\settabs\+\indent&{\bf length}\qquad&Minimum\qquad&Maximum\cr
\+&{\bf length}&{\bf Range}\cr
\smallskip
\+&\hfill1\qquad\hfill&{\tt 0}--{\tt 0x7F}\cr
\+&\hfill2\qquad\hfill&{\tt 0x80}--{\tt 0x7FF}\cr
\+&\hfill3\qquad\hfill&{\tt 0x800}--{\tt 0xFFFF}, excluding {\tt 0xD800}--{\tt 0xDFFF}\cr
\+&\hfill4\qquad\hfill&{\tt 0x10000}--{\tt 0x10FFFF}\cr}$$

@ The following 4 arrays contain data from two tables above.

@<Drw module functions@>+=

#define UTF_SIZ 4@#

	static const unsigned char utfbyte[UTF_SIZ + 1] = {0x80,    0, 0xC0, 0xE0, 0xF0};
	static const unsigned char utfmask[UTF_SIZ + 1] = {0xC0, 0x80, 0xE0, 0xF0, 0xF8};
	static const long utfmin[UTF_SIZ + 1] = {       0,    0,  0x80,  0x800,  0x10000};
	static const long utfmax[UTF_SIZ + 1] = {0x10FFFF, 0x7F, 0x7FF, 0xFFFF, 0x10FFFF};

@ @<Drw module functions@>+= 
static long
utf8decodebyte(const char c, size_t *i)
{
	for (*i = 0; *i < (UTF_SIZ + 1); ++(*i))
		if (((unsigned char)c & utfmask[*i]) == utfbyte[*i])@/
			return (unsigned char)c & ~utfmask[*i];@#
	return 0;
}

@ @<Drw module functions@>+= 
static size_t
utf8validate(long *u, size_t i)
{
	if (!BETWEEN(*u, utfmin[i], utfmax[i]) || BETWEEN(*u, 0xD800, 0xDFFF))@/
		*u = UTF_INVALID;
	for (i = 1; *u > utfmax[i]; ++i)
		;@#
	return i;
}

@ The following function decodes first code point in UTF8 encoded string pointed
to by parameter |c|; UTF32 encoded code point is placed at address pointed by |u|,
and function returns a number of decoded bytes. Invalid UTF8 byte sequence
produces value |UTF_INVALID|.

@<Drw module functions@>+=
 
#define UTF_INVALID 0xFFFD@#

static size_t
utf8decode(const char *c, long *u, size_t clen)
{
	size_t i, j, len, type;
	long udecoded;

	*u = UTF_INVALID;
	if (!clen)
		return 0;@#
	udecoded = utf8decodebyte(c[0], &len);
	if (!BETWEEN(len, 1, UTF_SIZ))
		return 1;
	for (i = 1, j = 1; i < clen && j < len; ++i, ++j) {
		udecoded = (udecoded << 6) | utf8decodebyte(c[i], &type);
		if (type)
			return j;
	}@#
	if (j < len)
		return 0;
	*u = udecoded;
	utf8validate(u, len);@#

	return len;
}

@* Miscellaneous utility functions. What remains are various utility functions
necessary for program operation, that didn't fit anywhere in this exposition up
to this point; most perform functions that are on the periphery of what this
program really does.

@ First, we turn to command line processing in function |main| that was
previously left unelaborated. Here, we deviate slightly from original source, 
introducing |OPT| macro to improve readability a bit; otherwise, code speaks
for itself. (See table immediately below for an overview of supported options.)

@d OPT(o) (!strcmp(argv[i],"-" o))
@<Process command line...@>=
	int i;@#

	for (i = 1; i < argc; i++) 
	{
		@<Check for options that take no arguments@>;
		@<Check for options that take one argument@>;
	}

@ @<Check for options that take no arguments@>=
	if (OPT("v")) {				/* prints version information */
		puts("dmenu-"VERSION);
		exit(0);
	} else if (OPT("b"))			/* appears at the bottom of the screen */
		topbar = 0;
	else if (OPT("f"))			/* grabs keyboard before reading stdin */
		fast = 1;
	else if (OPT("i")) {			/* case-insensitive item matching */
		fstrncmp = strncasecmp;
		fstrstr = cistrstr;
	}
	else @<Check for centering options@>@;
	else if (i + 1 == argc)
		usage();

@ @<Check for options that take one argument@>=
	if (OPT("l"))       /* number of lines in vertical list */
		lines = atoi(argv[++i]);
	else if (OPT("m"))   /* place widget on given monitor */
		mon = atoi(argv[++i]);
	else if (OPT("p"))   /* adds prompt to left of input field */
		prompt = argv[++i];
	else if (OPT("fn"))  /* font or font set */
		fonts[0] = argv[++i];
	else if (OPT("nb"))  /* normal background color */
		colors[SchemeNorm][ColBg] = argv[++i];
	else if (OPT("nf"))  /* normal foreground color */
		colors[SchemeNorm][ColFg] = argv[++i];
	else if (OPT("sb"))  /* selected background color */
		colors[SchemeSel][ColBg] = argv[++i];
	else if (OPT("sf"))  /* selected foreground color */
		colors[SchemeSel][ColFg] = argv[++i];
	else if (OPT("wi"))  /* embedding window id */
		embed = argv[++i];
	else @<Check for min line height patch option@>@;
	else @<Check for inter-line gap option@>@;
	else @<Check for geometry options@>;
	else usage();

@ Two-line instructions regarding use of this program are printed to |stderr|
upon user request (via an option {\tt -h}) or when invalid option is specified.

@<Functions@>+=
static void
usage(void)
{
	fputs("usage: dmenu [-bfiv] [-l lines] [-p prompt] [-fn font]\n"@/
	      "             [-m monitor] [-h height] [-gp gap]\n"@/
	      "             [-x xofffset] [-y yoffset] [-w width] [-xc] [-yc]\n"@/
	      "             [-nb color] [-nf color] [-sb color] [-sf color] [-wi windowid]\n", stderr);
	exit(1);
}

@ This is how we clean up things before program exit.

@<Functions@>+=
static void
cleanup(void)
{
	size_t i;

	XUngrabKey(dpy, AnyKey, AnyModifier, root);
	for (i = 0; i < SchemeLast; i++)
		free(scheme[i]);
	drw_free(drw);
	XSync(dpy, False);
	XCloseDisplay(dpy);
}

@ By default, when matching menu items we use case sensitive comparisons.

@<Global variables@>+=

static int (*fstrncmp)(const char *, const char *, size_t) = strncmp;
static char *(*fstrstr)(const char *, const char *) = strstr;

@ If case insensitive comparison is specified on the command line, function
|strncmp| is replaced with another standard library function |strncasecmp|,
while |strstr| is replaced with the following case-insensitive version.

@<Functions@>+=
static char *
cistrstr(const char *s, const char *sub)
{
	size_t len;

	for (len = strlen(sub); *s; s++)
		if (!strncasecmp(s, sub, len))
			return (char *)s;
	return NULL;
}

@ Next function wraps around standard library function |calloc| so that it
dies on error, emitting an appropriate message on |stderr|.

@<Functions@>+=
void *
ecalloc(size_t nmemb, size_t size)
{
	void *p;

	if (!(p = calloc(nmemb, size)))
		die("calloc:");
	return p;
}

@ The following function used above and also elsewhere throughout the program,
exits with an exit status of 1, printing the supplied error message accompanied,
if applicable, with an description of last error encountered during a call to a
system or library function.

@<Functions@>+=
void
die(const char *fmt, ...) {
	va_list ap;

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);

	if (fmt[0] && fmt[strlen(fmt)-1] == ':') {
		fputc(' ', stderr);
		perror(NULL);
	} else {
		fputc('\n', stderr);
	}

	exit(1);
}

@ @<Functions@>+=
static void
grabfocus(void)
{
	struct timespec ts = { 0, 10000000  };
	Window focuswin;
	int i, revertwin;

	for (i = 0; i < 100; ++i) {
		XGetInputFocus(dpy, &focuswin, &revertwin);
		if (focuswin == win)
			return;
		XSetInputFocus(dpy, win, RevertToParent, CurrentTime);
		nanosleep(&ts, NULL);
	}
	die("cannot grab focus");
}

@ Main module {\tt dmenu.c} needs to include various header files.

@<Header files to include@>=
#include <ctype.h>
#include <locale.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#ifdef __OpenBSD__
#include <unistd.h>
#endif@#

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#ifdef XINERAMA
#include <X11/extensions/Xinerama.h>
#endif
#include <X11/Xft/Xft.h>@#

#include "drw.h"

@ {\tt Dmenu} source distribution also contains module {\tt drw.c} responsible
for actually drawing text on X display. Git history is not quiet clear in this
regard, but hints at parts of this module being taken from libsl.

@(drw.c@>=
	@<Copyright notice@>@;
	@<Drw module enums...@>@;
	@<Definition of |struct Drw|@>@;
	@<Definition of |struct Fnt|@>@;

	@<Drw module functions@>;	

@ The copyright notice at the beginning of source refers reader to the file
named LICENSE in the source distribution; it cites MIT/X Consortium License.
For completeness, we give it's full text, below.\smallskip

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:\smallskip

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.\smallskip

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.\smallskip

@<Copyright notice@>=
/* See LICENSE file for copyright and license details. */

@* Configuring defaults in {\tt config.h}. As in other suckless programs,
configuration is moved from runtime and parsing of dot files to compile time
where default values of configuration parameters are set in the source as
initial values of the appropriate program variables. These initializations
are usually grouped into one or more header files which then play the role
of more traditional dot files. While this frees our code from having to
laboriously parse dot file syntax, it requires recompilation on every change;
as a compromise, some suckless programs also reads some of these values,
if present there, from X server resource database at program start-up.

@ In {\tt dmenu} default values of configuration parameters are set in
header file {\tt config.h}; they can be overridden by command line.

@(config.h@>=

	@<Copyright notice@>

@ This controls whether menu appears at top or bottom of the screen; command
line option {\tt -b} or value of zero places it on the bottom.

@(config.h@>+=
	static int topbar = 1;

@ Default font-set used to draw the menu. Command line option {\tt -fn} overrides
primary font only --- as things stands now, this is the only place to specify
fallback fonts.

@(config.h@>+=
static const char *fonts[] = {
	"monospace:size=10"
};

@ Text of the prompt to the left of input field; there will be no prompt if set
to |NULL|. Overridden by {\tt -p} command line option.

@(config.h@>+=
static const char *prompt      = NULL;

@ Default color scheme. These colors can be overridden using command line; for
foreground colors, use {\tt -nf} and {\tt -sf}, for background {\tt -nb} and
{\tt -sb}.

@(config.h@>+=
static const char *colors[SchemeLast][2] = { @t\1@>@/
	[SchemeNorm] = { "#bbbbbb", "#222222" },@/
	[SchemeSel] = { "#eeeeee", "#005577" },@/
	[SchemeOut] = { "#000000", "#00ffff" },@t\2@>@/
};

@ This variable controls whether {\tt dmenu} uses horizontal or vertical list
of menu items; when non-zero it determines number of lines in vertical list. 

@(config.h@>+=
static unsigned int lines      = 0;

@ Characters not considered part of a word while deleting words, for example
|" /?\"[]"|.

@(config.h@>+=
static const char worddelimiters[] = " ";

@* Local patches.

@ {\bf Line height.\ } This patch due to {\tt Xarchus@@comcast.net} is taken
directly from suckless official page\footnote*{\tt https://tools.suckless.org/
dmenu/patches/line-height/dmenu-lineheight-4.7.diff}.
It adds new command line option to set the minimum height of {\tt dmenu}
line, for better integration with other UI elements that require a particular
vertical size; for example, in order to completely cover the panel bar it
partially overlaps.

@ Line height is determined by a new configuration parameter {\tt lineheight}.

@(config.h@>+=
static unsigned int lineheight = 0;         /* -h option; minimum height of a menu line      */

@ It simply overrides default line height of font height plus 2 pixels.

@<Calculate menu geometry...@>=

	bh = drw->fonts->h + 2;
	bh = MAX(bh, lineheight);
	lines = MAX(lines, 0);
	mh = (lines + 1) * bh;

@ Since text is vertically centered anyway, the only thing that needs
adjusting is vertical cursor position in the input line.

@<Draw cursor@>=

	curpos = TEXTW(text) - TEXTW(&text[cursor]);
	if ((curpos += lrpad / 2 - 1) < w) {
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_rect(drw, x + curpos, 2 + (bh-fh)/2, 2, fh - 4, 1, 0);
	}

@ Variable |fh| above stands for font height.

@<Local variables (drawmenu)@>+=

	int fh = drw->fonts->h;

@ All of this is controlled by new command line option {\tt -h}.

@<Check for min line height patch option@>=

	if (!strcmp(argv[i], "-h")) {  /* minimum height of one menu line  */
			lineheight = atoi(argv[++i]);
			lineheight = MAX(lineheight, 8); }

@ {\bf Inter-line gap.\ } The next patch in a way goes together with
the one preceding it; it adds a new command line option to set inter-line
gap when menu is displayed in vertical mode. This is controlled by a new
configuration parameter {\tt intlinegap}.

@(config.h@>+=
static unsigned int intlinegap = 0;         /* -gp option; inter-line gap                    */

@ The widget must provide space for these gaps.

@<Calculate menu geometry...@>=

	bh = drw->fonts->h + 2;
	bh = MAX(bh, lineheight);
	lines = MAX(lines, 0);
	mh = (lines + 1) * (bh + intlinegap);

@ Aside from some additional command line parsing, all remaining changes are
confined to the function |drawmenu|. All elements in the first line of the
widget are shifted down by an offset of |intlinegap/2| to account for upper
half of inter-line gap.

@<Local variables (drawmenu)@>=

	int x = 0, y = intlinegap/2;
	int w;

@ @<Draw prompt@>=
	if (prompt && *prompt) {
		drw_setscheme(drw, scheme[SchemeSel]);
		x = drw_text(drw, x, y, promptw, bh, lrpad / 2, prompt, 0);
	}

@ @<Draw input field@>=

	w = (lines > 0 || !matches) ? mw - x : inputw;
	drw_setscheme(drw, scheme[SchemeNorm]);
	drw_text(drw, x, y, w, bh, lrpad / 2, text, 0);
	x += inputw;

@ @<Draw cursor@>=

	curpos = TEXTW(text) - TEXTW(&text[cursor]);
	if ((curpos += lrpad / 2 - 1) < w) {
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_rect(drw, x + curpos, y + 2 + (bh-fh)/2, 2, fh - 4, 1, 0);
	}

@ @<Draw horizontal list@>=
	w = TEXTW("<");
	if (curr->left) {
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_text(drw, x, y, w, bh, lrpad / 2, "<", 0);
	}
	x += w;

@ @<Draw horizontal list@>+=

	for (item = curr; item != next; item = item->right)@/
		x = drawitem(item, x, y, MIN(TEXTW(aitem->text), mw - x - TEXTW(">")));

@ @<Draw horizontal list@>+=

	if (next) {
		w = TEXTW(">");
		drw_setscheme(drw, scheme[SchemeNorm]);
		drw_text(drw, mw - w, y, w, bh, lrpad / 2, ">", 0);
	}

@ When menu is in vertical mode, we skip |intlinegap| pixels between each
two subsequent lines.

@<Draw vertical list@>=
	for (item = curr; aitem != next; item = item->right) @/
		drawitem(item, x, y += intlinegap+bh, mw - x);

@ Inter-line gap parameter is controlled by a command line option {\tt -gp}.

@<Check for inter-line gap option@>=

	else if (!strcmp(argv[i], "-gp"))  /* inter-line gap  */
		intlinegap = atoi(argv[++i]);

@ {\bf Position and width.\ } This patch adds options {\tt -x}, {\tt -y}
and {\tt -w} setting window position on the target monitor and it's width
respectively; if option {\t -b} is used, y offset is measured from the
bottom of the screen. Window geometry is controlled by three configuration
parameters.

@(config.h@>+=

static int geomx = 0, geomy = 0;            /* options -x, -y, -w, -h: widget geometry       */
static int geomw = 0;

@ After menu geometry has been determined with respect to {\tt XINERAMA},
we apply geometry specified on the command line.

@<Apply geometry...@>=

	x += geomx;
	y += topbar ? geomy : -geomy;
	mw = geomw  ? geomw : mw - geomx;

@ This is controlled by three new command line options.

@<Check for geometry options@>=

	else @+if (!strcmp(argv[i], "-x"))@t\2@>
		geomx = atoi(argv[++i]);
	else if (!strcmp(argv[i], "-y"))
		geomy = atoi(argv[++i]);
	else if (!strcmp(argv[i], "-w"))
		geomw = atoi(argv[++i]);

@ {\bf Horizontal and vertical centering.\ } Two additional configuration
parameters determine whether menu window should be centered in horizontal
and vertical direction.

@(config.h@>+=
static int centerx = 0, centery = 0;

@ These parameters are controlled by two command line options {\tt -xc}
and {\tt -yc}.

@<Check for centering options@>=

	if (!strcmp(argv[i], "-xc"))
		centerx = 1;
	else if (!strcmp(argv[i], "-yc"))
		centery = 1;

@ For vertical centering, we need screen height.

@<Local variables (setup)@>=

	int sh;

@ @<Calculate menu geometry...@>=

#ifdef XINERAMA
	if (parentwin == root && (info = XineramaQueryScreens(dpy, &n))) {
		@<Get menu geometry from {\tt XINERAMA}@>;
	} else
#endif
	{
		if (!XGetWindowAttributes(dpy, parentwin, &wa))
			die("could not get embedding window attributes: 0x%lx",
			    parentwin);
		x = 0;
		y = topbar ? 0 : wa.height - mh;
		mw = wa.width;
		sh = wa.height;
	}

@ @<Get menu geometry from...@>+=

	x = info[i].x_org;
	y = info[i].y_org + (topbar ? 0 : info[i].height - mh);
	mw = info[i].width;
	sh = info[i].height;
	XFree(info);

@ If no window width is specified on the command line, default width spans
the whole screen and thus renders horizontal centering a noop; in that case,
horizontal centering uses x offset, if specified, as total width of the
margin.

@<Apply geometry...@>=

	if (centerx) x = (geomw ? mw - geomw : geomx) / 2;
	else x += geomx;@#
	if (centery) y = (sh - mh) / 2;
	else y += topbar ? geomy : -geomy;@#
	mw = geomw  ? geomw : mw - geomx;

@ Command line option {\tt -center} is an abbreviation for {\tt -xc -yc}.

@<Check for centering options@>+=

	else if (!strcmp(argv[i], "-center"))
		centerx = centery = 1;

@ {\bf Dynamically resize dmenu window.\ } Configuration parameter |dynheight|
controls an option to keep dynamically resizing dmenu window so that it never
gets larger then it's necessary to show matched menu items.

@(config.h@>+=

	static int dynheight = 0;

@ Global variable |actualheight| at any given time keeps track of current window
height.

@<Global variables@>+=

	static int actualheight = 0;

@ At the start of the program, it is initialized to match dmenu height on
startup.

@<Apply geometry...@>+=

	actualheight = lines;

@ The remaining changes are all confined to the function |drawmenu|. We count
menu items as they are beeing drawn in vertical mode.

@<Local variables (drawmenu)@>+=

	int linesdrawn = 0;

@ @<Draw vertical list@>=
	for (item = curr; item != next; item = item->right, linesdrawn++) @/
		drawitem(item, x, y += intlinegap+bh, mw - x);

@ If this number doesn't match the actual widow size while |dynheight|
option is active, we take action and resize the window.

@<Resize window, if necessary@>=

	if (dynheight && actualheight != linesdrawn) {
		XResizeWindow(drw->dpy, win, mw, (linesdrawn + 1) * (bh + intlinegap));
		actualheight = linesdrawn;
	}

@* The End.
