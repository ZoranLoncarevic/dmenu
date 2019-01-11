/* See LICENSE file for copyright and license details. */
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "util.h"

void *
ecalloc(size_t nmemb, size_t size)
{
	void *p;

	if (!(p = calloc(nmemb, size)))
		die("calloc:");
	return p;
}

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

int isargb(const char *clrname)
{
	int n=8;

	if (*clrname != '#')
		return 0;

	while (isxdigit(*++clrname) && n--) ;

	return !*clrname && !n;
}

int hexdigittoi(const char *s)
{
	if (isdigit(*s))
		return *s - '0';
	else if (isalpha(*s))
		return *s - (isupper(*s) ? 'A' : 'a') + 10;
	else
		return 0;
}

int twohexdigitstoi(const char *s)
{
	return (hexdigittoi(s) << 4) | hexdigittoi(s+1);
}

#define BADCOLOR 0xFFFFFFFFU;

unsigned long int strtoargb(const char *clrname)
{
	int alpha;
	long int result;

	if (*clrname != '#')
		return BADCOLOR;

	alpha = twohexdigitstoi(clrname + 1);

	result  = alpha << 24;
	result |= (twohexdigitstoi(clrname + 3) * alpha << 8) & 0xFF0000;
	result |= (twohexdigitstoi(clrname + 5) * alpha ) & 0xFF00;
	result |=  twohexdigitstoi(clrname + 7) * alpha >> 8;

	return result;
}
