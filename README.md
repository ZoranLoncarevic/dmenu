# My personal fork of dmenu

[Dmenu](https://tools.suckless.org/dmenu/) is a suckless dynamic menu for X.
The code in this repository is based on [https://git.suckless.org/dmenu](https://git.suckless.org/dmenu)
as of commit `bbc464dc80225b8cf9390f14fac6c682f63940d2` but contains additional
features, some of which are taken from patches at
[https://tools.suckless.org/dmenu/patches/](https://tools.suckless.org/dmenu/patches/)
while others are of my own creation. These include options to set text line
height and interline spacing in pixels, horizontal and vertical position
and width of dmenu window (including an option to center it horizontally
and/or vertically on the screen), support for translucent colors with
an alpha channel given as `#AARRGGBB` and various options to draw
borders around the window and between the input line and menu items.
Additionally, this version of 'dmenu' can dim the screen in order to
focus user on the menu by overlaying the screen with a full-screen sized
and appropriately colored translucent window.

It also works under Wayland on GNOME Desktop Environment, since it now
requests keyboard grab on it's own rather than on the root window and then
asks for focus. Note that it still requires you to have

```
gsettings set org.gnome.mutter.wayland xwayland-allow-grabs true
gsettings set org.gnome.mutter.wayland xwayland-grab-access-rules '["dmenu"]'
```
