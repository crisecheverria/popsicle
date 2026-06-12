#include "popsicle_gtk.h"

#include <gtk/gtk.h>
#include <gtk-layer-shell/gtk-layer-shell.h>
#include <cairo/cairo.h>
#include <pango/pango.h>
#include <pango/pangocairo.h>
#include <math.h>
#include <string.h>

#define FONT_DESC "sans 14"

void pg_gtk_init(void) {
    gtk_init(NULL, NULL);
}

void pg_gtk_main(void) {
    gtk_main();
}

void pg_gtk_main_quit(void) {
    gtk_main_quit();
}

void* pg_create_window(int anchor_left, int margin) {
    GtkWidget* win = gtk_window_new(GTK_WINDOW_TOPLEVEL);

    gtk_layer_init_for_window(GTK_WINDOW(win));
    gtk_layer_set_layer(GTK_WINDOW(win), GTK_LAYER_SHELL_LAYER_OVERLAY);
    gtk_layer_set_anchor(GTK_WINDOW(win), GTK_LAYER_SHELL_EDGE_BOTTOM, TRUE);
    GtkLayerShellEdge h_edge = anchor_left ? GTK_LAYER_SHELL_EDGE_LEFT : GTK_LAYER_SHELL_EDGE_RIGHT;
    gtk_layer_set_anchor(GTK_WINDOW(win), h_edge, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(win), GTK_LAYER_SHELL_EDGE_BOTTOM, margin);
    gtk_layer_set_margin(GTK_WINDOW(win), h_edge, margin);
    gtk_layer_set_keyboard_mode(GTK_WINDOW(win), GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
    gtk_layer_set_exclusive_zone(GTK_WINDOW(win), -1);

    GdkScreen* screen = gtk_widget_get_screen(win);
    GdkVisual* visual = gdk_screen_get_rgba_visual(screen);
    if (visual) gtk_widget_set_visual(win, visual);
    gtk_widget_set_app_paintable(win, TRUE);

    gtk_widget_set_size_request(win, 700, 320);
    gtk_widget_add_events(win, GDK_BUTTON_PRESS_MASK);

    return win;
}

void pg_window_show(void* window) {
    gtk_widget_show_all((GtkWidget*)window);
}

void pg_window_realize(void* window) {
    gtk_widget_realize((GtkWidget*)window);
}

void pg_set_input_shape(void* window, int x, int y, int w, int h) {
    cairo_rectangle_int_t rect = { x, y, w, h };
    cairo_region_t* region = cairo_region_create_rectangle(&rect);
    gdk_window_input_shape_combine_region(
        gtk_widget_get_window((GtkWidget*)window),
        region, 0, 0);
    cairo_region_destroy(region);
}

void pg_queue_draw(void* window) {
    gtk_widget_queue_draw((GtkWidget*)window);
}

unsigned int pg_timeout_add(unsigned int ms, PgCallback cb, void* data) {
    return g_timeout_add(ms, (GSourceFunc)cb, data);
}

unsigned int pg_idle_add(PgCallback cb, void* data) {
    return g_idle_add((GSourceFunc)cb, data);
}

void pg_source_remove(unsigned int id) {
    g_source_remove(id);
}

void pg_connect_draw(void* window, PgDrawCb cb) {
    g_signal_connect(window, "draw", G_CALLBACK(cb), NULL);
}

void pg_connect_button_press(void* window, PgButtonCb cb) {
    g_signal_connect(window, "button-press-event", G_CALLBACK(cb), NULL);
}

void pg_connect_destroy(void* window, PgDestroyCb cb) {
    g_signal_connect(window, "destroy", G_CALLBACK(cb), NULL);
}

void pg_event_coords(void* event, double* x, double* y) {
    GdkEventButton* ev = (GdkEventButton*)event;
    *x = ev->x;
    *y = ev->y;
}

void pg_draw_clear(void* cr) {
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
}

void pg_draw_stop_button(void* cr, double cx, double cy, double r) {
    cairo_new_path(cr);
    cairo_arc(cr, cx, cy, r, 0, 2 * M_PI);
    cairo_set_source_rgba(cr, 0.15, 0.15, 0.20, 0.65);
    cairo_fill(cr);

    cairo_new_path(cr);
    cairo_select_font_face(cr, "sans",
        CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
    cairo_set_font_size(cr, 14);
    cairo_text_extents_t ext;
    const char* x_char = "\xc3\x97"; /* × U+00D7 */
    cairo_text_extents(cr, x_char, &ext);
    cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.80);
    cairo_move_to(cr,
        cx - ext.width / 2 - ext.x_bearing,
        cy - ext.height / 2 - ext.y_bearing);
    cairo_show_text(cr, x_char);
}

/* Normal bubble colours */
static const double BG_NORMAL[4] = { 0.93, 0.96, 1.00, 0.90 };
static const double BG_COMBO[4]  = { 0.88, 0.91, 1.00, 0.93 };
static const double FG_NORMAL[4] = { 0.13, 0.13, 0.18, 1.00 };
static const double FG_COMBO[4]  = { 0.25, 0.10, 0.55, 1.00 };

void pg_draw_bubble(void* cr,
                    const char* text, int text_len,
                    int show_cursor,
                    int is_combo,
                    double opacity,
                    double x, double y,
                    double max_text_w,
                    double pad_x, double pad_y,
                    double bubble_radius,
                    double* out_bh)
{
    /* Build display text with optional cursor */
    char display[516];
    int dlen = text_len < 512 ? text_len : 512;
    memcpy(display, text, dlen);
    if (show_cursor) display[dlen++] = '_';
    display[dlen] = '\0';

    PangoLayout* layout = pango_cairo_create_layout((cairo_t*)cr);
    pango_layout_set_text(layout, display, dlen);
    PangoFontDescription* fd = pango_font_description_from_string(FONT_DESC);
    pango_layout_set_font_description(layout, fd);
    pango_font_description_free(fd);
    pango_layout_set_width(layout, (int)(max_text_w * PANGO_SCALE));
    pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR);

    int pw, ph;
    pango_layout_get_pixel_size(layout, &pw, &ph);

    double bw = pw + pad_x * 2;
    double bh = ph + pad_y * 2;
    double r  = bubble_radius < bh / 2 ? bubble_radius : bh / 2;

    const double* bg = is_combo ? BG_COMBO : BG_NORMAL;
    const double* fg = is_combo ? FG_COMBO : FG_NORMAL;

    /* Rounded rectangle */
    cairo_new_path(cr);
    cairo_set_source_rgba(cr, bg[0], bg[1], bg[2], bg[3] * opacity);
    cairo_arc(cr, x + r,       y + r,       r, M_PI,       1.5 * M_PI);
    cairo_arc(cr, x + bw - r,  y + r,       r, 1.5 * M_PI, 0);
    cairo_arc(cr, x + bw - r,  y + bh - r,  r, 0,          0.5 * M_PI);
    cairo_arc(cr, x + r,       y + bh - r,  r, 0.5 * M_PI, M_PI);
    cairo_close_path(cr);
    cairo_fill(cr);

    /* Text */
    cairo_new_path(cr);
    cairo_set_source_rgba(cr, fg[0], fg[1], fg[2], fg[3] * opacity);
    cairo_move_to(cr, x + pad_x, y + pad_y);
    pango_cairo_show_layout((cairo_t*)cr, layout);

    g_object_unref(layout);

    if (out_bh) *out_bh = bh;
}
