/* See LICENSE file for copyright and license details. */

#include <X11/Xlib.h>
#include <X11/Xft/Xft.h>
#include "drw.h"
#include "util.h"
#include "border.h"

void draw_rounded_border(Drw *drw, int mw, int mh, int borderwidth, int borderradius,
			Clr *schemeBorder, Clr *schemeNorm)
{
	drw_setscheme(drw, schemeBorder);
	drw_rect(drw, 0, 0, mw, mh, 1, 1);
	drw_rounded_rect(drw, 0, 0, mw, mh, borderradius, 1, 0);
	drw_setscheme(drw, schemeNorm);
	drw_rounded_rect(drw, borderwidth, borderwidth , mw-2*borderwidth, mh-2*borderwidth, 
		borderradius > borderwidth ? borderradius - borderwidth : borderradius, 1, 1);
}

void draw_border(Drw *drw, int mw, int mh, int borderwidth,
			Clr *schemeBorder, Clr *schemeNorm)
{
	drw_setscheme(drw, schemeBorder);
	drw_rect(drw, 0, 0, mw, mh, 1, 0);
	drw_setscheme(drw, schemeNorm);
	drw_rect(drw, borderwidth, borderwidth , mw-2*borderwidth, mh-2*borderwidth, 1, 1);
}
