/* See LICENSE file for copyright and license details. */

#include <X11/Xlib.h>
#include <X11/Xft/Xft.h>
#include "drw.h"
#include "util.h"
#include "border.h"


Drawable corner[4];
static int corners_not_initialized = 1;

#define paint_4_corners(x, y, pixel) {\
	XPutPixel(xim[0], x, y, pixel);\
	XPutPixel(xim[1], radius-1-x, y, pixel);\
	XPutPixel(xim[2], radius-1-x, radius-1-y, pixel);\
	XPutPixel(xim[3], x, radius-1-y, pixel);\
}

void initialize_corners(Drw *drw, int width, int radius, Clr *c1, Clr *c2)
{
	XImage *xim[4];
	int i, x, y;

	/* Allocate XImages */
	for(i=0; i<4; i++) {
		if ((xim[i] = XCreateImage(drw->dpy, drw->visual, drw->depth,
				ZPixmap, 0, NULL, radius, radius, 32, 0)) == NULL)
			die("cannot allocate XImage");
		if ((xim[i]->data = malloc(xim[i]->bytes_per_line * radius+1)) == NULL)
			die("cannot allocate image");
	}

	for( x = 0; x < radius ; x++)
		for( y = 0 ; y < radius ; y++ )
			paint_4_corners(x, y, x < radius-y ? c1[ColBg].pixel : c1[ColFg].pixel);

	/* Upload XImages to Pixmaps on the server  */
	for(i=0; i<4; i++) {
		corner[i] = XCreatePixmap(drw->dpy, drw->drawable, radius, radius, drw->depth);
		XPutImage(drw->dpy, corner[i], drw->gc, xim[i], 0, 0, 0, 0, radius, radius);
	}

	corners_not_initialized = 0;
}

void draw_antialiased_rounded_border(Drw *drw, int mw, int mh, int width, int radius,
			Clr *schemeBorder, Clr *schemeNorm)
{
	drw_setscheme(drw, schemeNorm);
	drw_rect(drw, 0, 0, mw, mh, 1, 1);

	drw_setscheme(drw, schemeBorder);
	drw_rect(drw, radius, 0, mw-2*radius, width, 1, 0);
	drw_rect(drw, mw-width, radius, width, mh-2*radius, 1, 0);
	drw_rect(drw, radius, mh-width, mw-2*radius, width, 1, 0);
	drw_rect(drw, 0, radius, width, mh-2*radius, 1, 0);

	if (corners_not_initialized)
		initialize_corners(drw, width, radius, schemeBorder, schemeNorm);

	XCopyArea(drw->dpy, corner[0], drw->drawable, drw->gc, 0, 0, radius, radius, 0, 0);
	XCopyArea(drw->dpy, corner[1], drw->drawable, drw->gc, 0, 0, radius, radius, mw-radius, 0);
	XCopyArea(drw->dpy, corner[2], drw->drawable, drw->gc, 0, 0, radius, radius, mw-radius, mh-radius);
	XCopyArea(drw->dpy, corner[3], drw->drawable, drw->gc, 0, 0, radius, radius, 0, mh-radius);
}

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
