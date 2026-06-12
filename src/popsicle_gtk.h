#pragma once
#include <stdint.h>

/* Opaque GTK/Cairo handles passed as void* to Zig */

/* Lifecycle */
void*    pg_create_window(int anchor_left, int margin);
void     pg_window_show(void* window);
void     pg_window_realize(void* window);
void     pg_set_input_shape(void* window, int x, int y, int w, int h);
void     pg_queue_draw(void* window);
void     pg_gtk_init(void);
void     pg_gtk_main(void);
void     pg_gtk_main_quit(void);

/* GLib timers/idle — callbacks are (void*) -> int  (return 0=remove, 1=continue) */
typedef int (*PgCallback)(void* data);
unsigned int pg_timeout_add(unsigned int ms, PgCallback cb, void* data);
unsigned int pg_idle_add(PgCallback cb, void* data);
void         pg_source_remove(unsigned int id);

/* Signal connection */
typedef int  (*PgDrawCb)(void* widget, void* cr, void* data);
typedef int  (*PgButtonCb)(void* widget, void* event, void* data);
typedef void (*PgDestroyCb)(void* widget, void* data);
void pg_connect_draw(void* window, PgDrawCb cb);
void pg_connect_button_press(void* window, PgButtonCb cb);
void pg_connect_destroy(void* window, PgDestroyCb cb);

/* Cairo drawing — cr is the cairo_t* passed to the draw callback */
void pg_draw_clear(void* cr);
void pg_draw_stop_button(void* cr, double cx, double cy, double r);
void pg_draw_bubble(void* cr,
                    const char* text, int text_len,
                    int show_cursor,
                    int is_combo,
                    double opacity,
                    double x, double y,
                    double max_text_w,
                    double pad_x, double pad_y,
                    double bubble_radius,
                    /* output */ double* out_bh);

/* Button press event */
void pg_event_coords(void* event, double* x, double* y);
