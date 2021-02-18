/*
#  Created by Boyd Multerer on 12/05/17.
#  Copyright © 2017 Kry10 Industries. All rights reserved.
#
*/

// one unified place for the various structures


#ifndef RENDER_DRIVER_TYPES
#define RENDER_DRIVER_TYPES

#include <libwebsockets.h>

#ifndef bool
#include <stdbool.h>
#endif

#include <EGL/egl.h>    // EGL library
#include <EGL/eglext.h> // EGL extensions
#include <glad/glad.h>  // glad library (OpenGL loader)

#ifndef NANOVG_H
#include "nanovg.h"
#endif

typedef unsigned char byte;

//---------------------------------------------------------
typedef struct __attribute__((__packed__))
{
  float x;
  float y;
} Vector2f;

//---------------------------------------------------------
// the data pointed to by the window private data pointer
typedef struct {
  bool              keep_going;
  uint32_t          input_flags;
  float             last_x;
  float             last_y;
  void**            p_scripts;
  int               root_script;
  int               num_scripts;
  void*             p_tx_ids;
  void*             p_fonts;
  NVGcontext*       p_ctx;
  int               screen_width;
  int               screen_height;
} driver_data_t;

typedef struct {
  EGLDisplay display;
  EGLConfig config;
  EGLSurface surface;
  EGLContext context;
  int screen_width;
  int screen_height;
  int major_version;
  int minor_version;
  NVGcontext* p_ctx;
} egl_data_t;

typedef struct my_conn
{
    struct lws_context* context;
    int ssl_connection; 
    lws_sorted_usec_list_t sul; 
    struct lws* wsi;            
    uint16_t retry_count;
    bool interrupted;
    driver_data_t* data;
    egl_data_t* egl_data;
    bool render_ready;
} conn_data_t;


#endif