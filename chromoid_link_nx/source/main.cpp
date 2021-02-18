#include <arpa/inet.h>
#include <pthread.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/socket.h>
#include <unistd.h>

#include <switch.h>
#include "chromoid_link_nx.h"

#define USE_OPENGL
#include <EGL/egl.h>    // EGL library
#include <EGL/eglext.h> // EGL extensions
#include <glad/glad.h>  // glad library (OpenGL loader)

#define GLM_FORCE_PURE
#define GLM_ENABLE_EXPERIMENTAL
#include "nanovg.h"

#define NANOVG_GL3_IMPLEMENTATION
#include "nanovg_gl.h"

#include "types.h"
#include "render_script.h"
#define ENABLE_NXLINK
#ifndef ENABLE_NXLINK
#define TRACE(fmt, ...) ((void)0)
#else
#include <unistd.h>
#define TRACE(fmt, ...) printf("%s: " fmt "\n", __PRETTY_FUNCTION__, ##__VA_ARGS__)

static int s_nxlinkSock = -1;

static void initNxLink()
{
  if (R_FAILED(socketInitializeDefault()))
    return;

  s_nxlinkSock = nxlinkStdio();
  if (s_nxlinkSock >= 0)
    TRACE("printf output now goes to nxlink server");
  else
    socketExit();
}

static void deinitNxLink()
{
  if (s_nxlinkSock >= 0)
  {
    close(s_nxlinkSock);
    socketExit();
    s_nxlinkSock = -1;
  }
}

extern "C" void userAppInit(void)
{
  initNxLink();
  Result res = romfsInit();
  if (R_FAILED(res))
    fatalThrow(res);
}

extern "C" void userAppExit(void)
{
  romfsExit();
  deinitNxLink();
}

#endif

// alignas(16) u8 __nx_exception_stack[0x1000];
// u64 __nx_exception_stack_size = sizeof(__nx_exception_stack);

extern conn_data_t mco;

void __libnx_exception_handler(ThreadExceptionDump *ctx)
{
  int i;
  FILE *f = fopen("exception_dump", "w");
  if (f == NULL)
    return;

  fprintf(f, "error_desc: 0x%x\n", ctx->error_desc); //You can also parse this with ThreadExceptionDesc.
  //This assumes AArch64, however you can also use threadExceptionIsAArch64().
  for (i = 0; i < 29; i++)
    fprintf(f, "[X%d]: 0x%lx\n", i, ctx->cpu_gprs[i].x);
  fprintf(f, "fp: 0x%lx\n", ctx->fp.x);
  fprintf(f, "lr: 0x%lx\n", ctx->lr.x);
  fprintf(f, "sp: 0x%lx\n", ctx->sp.x);
  fprintf(f, "pc: 0x%lx\n", ctx->pc.x);

  //You could print fpu_gprs if you want.

  fprintf(f, "pstate: 0x%x\n", ctx->pstate);
  fprintf(f, "afsr0: 0x%x\n", ctx->afsr0);
  fprintf(f, "afsr1: 0x%x\n", ctx->afsr1);
  fprintf(f, "esr: 0x%x\n", ctx->esr);

  fprintf(f, "far: 0x%lx\n", ctx->far.x);

  fclose(f);
}

void init_video_core(egl_data_t *p_data, int debug_mode)
{
  printf("eglGetDisplay\n");
  // get a handle to the display
  EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
  printf("eglGetDisplay done\n");

  if (display == EGL_NO_DISPLAY)
  {
    printf("scenic_driver error: Unable get handle to the default screen on HDMI");
    return;
  }

  p_data->display = display;

  // initialize the EGL display connection
  EGLint major_version;
  EGLint minor_version;

  printf("eglInitialize\n");

  // returns a pass/fail boolean
  if (eglInitialize(display, &major_version, &minor_version) == EGL_FALSE)
  {
    printf("scenic_driver error: Unable initialize EGL\n");
    return;
  }

  printf("eglInitialize done\n");

  printf("eglBindAPI\n");
  // use open gl es
  if (eglBindAPI(EGL_OPENGL_API) == EGL_FALSE)
  {
    printf("scenic_driver error: Unable to bind to GLES\n");
    return;
  }
  printf("eglBindAPI done\n");

  p_data->major_version = major_version;
  p_data->minor_version = minor_version;
  // prepare an appropriate EGL frame buffer configuration request
  static const EGLint attribute_list[] = {
    EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
    EGL_RED_SIZE,     8,
    EGL_GREEN_SIZE,   8,
    EGL_BLUE_SIZE,    8,
    EGL_ALPHA_SIZE,   8,
    EGL_DEPTH_SIZE,   24,
    EGL_STENCIL_SIZE, 8,
    EGL_NONE
  };
  static const EGLint context_attributes[] = {
    EGL_CONTEXT_OPENGL_PROFILE_MASK_KHR, EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR,
    EGL_CONTEXT_MAJOR_VERSION_KHR, 4,
    EGL_CONTEXT_MINOR_VERSION_KHR, 3,
    EGL_NONE
  };
  EGLConfig config;
  EGLint num_config;

  printf("eglChooseConfig\n");
  // get an appropriate EGL frame buffer configuration
  if (eglChooseConfig(display, attribute_list, &config, 1, &num_config) == EGL_FALSE)
  {
    printf("scenic_driver error: Unable to get usable display config\n");
    return;
  }
  p_data->config = config;
  printf("eglChooseConfig done\n");

  u32 screen_width;
  u32 screen_height;

  printf("nwindowGetDimensions\n");
  NWindow *win = nwindowGetDefault();
  nwindowGetDimensions(win, &screen_width, &screen_height);
  printf("nwindowGetDimensionsdone %d %d \n", screen_width, screen_height);
  p_data->screen_width = screen_width;
  p_data->screen_height = screen_height;

  printf("eglCreateWindowSurface\n");
  EGLSurface surface = eglCreateWindowSurface(display, config, win, NULL);
  if (surface == EGL_NO_SURFACE)
  {
    printf("scenic_driver error: Unable create the native window surface\n");
    return;
  }
  p_data->surface = surface;
  printf("eglCreateWindowSurface done\n");

  printf("eglCreateContext\n");
  // create an EGL graphics context
  EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
  if (!context)
  {
    printf("scenic_driver error: Failed to create EGL context %d\n", eglGetError());
    return;
  }
  p_data->context = context;
  printf("eglCreateContext done\n");

  printf("eglMakeCurrent\n");
  // connect the context to the surface and make it current
  if (eglMakeCurrent(display, surface, surface, context) == EGL_FALSE)
  {
    printf("scenic_driver error: Unable make the surface current\n");
    return;
  }
  printf("eglMakeCurrent done\n");

  printf("gladLoadGL\n");
  gladLoadGL();
  printf("gladLoadGL done\n");

  //-------------------
  // config gles

  printf("glViewport\n");
  // set the view port to the new size passed in
  glViewport(0, 0, screen_width, screen_height);
  printf("glViewport done\n");

  // This turns on/off depth test.
  // With this ON, whatever we draw FIRST is
  // "on top" and each subsequent draw is BELOW
  // the draw calls before it.
  // With this OFF, whatever we draw LAST is
  // "on top" and each subsequent draw is ABOVE
  // the draw calls before it.
  printf("glDisable(GL_DEPTH_TEST)\n");
  glDisable(GL_DEPTH_TEST);
  printf("glDisable(GL_DEPTH_TEST) done\n");


  // Probably need this on, enables Gouraud Shading
  // printf("glShadeModel(GL_SMOOTH) \n");
  // glShadeModel(GL_SMOOTH);
  // printf("glShadeModel(GL_SMOOTH) done\n");

  // Turn on Alpha Blending
  // There are some efficiencies to be gained by ONLY
  // turning this on when we have a primitive with a
  // style that has an alpha channel != 1.0f but we
  // don't have code to detect that.  Easy to do if we need it!
  printf("glEnable(GL_BLEND) \n");
  glEnable(GL_BLEND);
  printf("glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA) \n");
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

  //-------------------
  // initialize nanovg

  printf("nvgCreateGL3\n");
  p_data->p_ctx = nvgCreateGL3(NVG_ANTIALIAS | NVG_STENCIL_STROKES | NVG_DEBUG);
  if (p_data->p_ctx == NULL)
  {
    printf("scenic_driver error: failed nvgCreateGL3\n");
    return;
  }
  printf("nvgCreateGL3 done\n");
}

void test_draw(egl_data_t* p_data) {
  //-----------------------------------
  // Set background color and clear buffers
  // glClearColor(0.15f, 0.25f, 0.35f, 1.0f);
  // glClearColor(0.098f, 0.098f, 0.439f, 1.0f);    // midnight blue
  // glClearColor(0.545f, 0.000f, 0.000f, 1.0f);    // dark red
  // glClearColor(0.184f, 0.310f, 0.310f, 1.0f);       // dark slate gray
  // glClearColor(0.0f, 0.0f, 0.0f, 1.0f);       // black

  // glClear(GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);

  NVGcontext* p_ctx = p_data->p_ctx;
  int screen_width = p_data->screen_width;
  int screen_height = p_data->screen_height;

  nvgBeginFrame(p_ctx, screen_width, screen_height, 1.0f);

    // Next, draw graph line
  nvgBeginPath(p_ctx);
  nvgMoveTo(p_ctx, 0, 0);
  nvgLineTo(p_ctx, screen_width, screen_height);
  nvgStrokeColor(p_ctx, nvgRGBA(0, 160, 192, 255));
  nvgStrokeWidth(p_ctx, 3.0f);
  nvgStroke(p_ctx);

  nvgBeginPath(p_ctx);
  nvgMoveTo(p_ctx, screen_width, 0);
  nvgLineTo(p_ctx, 0, screen_height);
  nvgStrokeColor(p_ctx, nvgRGBA(0, 160, 192, 255));
  nvgStrokeWidth(p_ctx, 3.0f);
  nvgStroke(p_ctx);

  nvgBeginPath(p_ctx);
  nvgCircle(p_ctx, screen_width / 2, screen_height / 2, 50);
  nvgFillColor(p_ctx, nvgRGBAf(0.545f, 0.000f, 0.000f, 1.0f));
  nvgFill(p_data->p_ctx);
  nvgStroke(p_ctx);

  nvgEndFrame(p_ctx);

  eglSwapBuffers(p_data->display, p_data->surface);
}

int main(int argc, const char **argv)
{
  // redirect stdout & stderr over network to nxlink
  // nxlinkStdio();

  // consoleInit(NULL);
  pthread_t websocket_thread;

  // Configure our supported input layout: a single player with standard controller styles
  padConfigureInput(1, HidNpadStyleSet_NpadStandard);

  // Initialize the default gamepad (which reads handheld mode inputs as well as the first connected controller)
  PadState pad;
  padInitializeDefault(&pad);

  // Initialise sockets
  // socketInitializeDefault();

  printf("Hello World!\n");

  // Display arguments sent from nxlink
  printf("%d arguments\n", argc);

  for (int i = 0; i < argc; i++)
  {
    printf("argv[%d] = %s\n", i, argv[i]);
  }

  // the host ip where nxlink was launched
  printf("nxlink host is %s\n", inet_ntoa(__nxlink_host));

  // this text should display on nxlink host
  printf("printf output now goes to nxlink server\n");

  printf("initializing video\n");

  mco.egl_data = (egl_data_t *)malloc(sizeof(egl_data_t));
  int num_scripts = 128;

  // init graphics
  init_video_core(mco.egl_data, 0);

  printf("initialized video %d %d %p\n", mco.egl_data->screen_width, mco.egl_data->screen_height, &mco);

  mco.render_ready = false;
  mco.data = (driver_data_t *)malloc(sizeof(driver_data_t));
  // set up the scripts table
  memset(mco.data, 0, sizeof(driver_data_t));
  mco.data->p_scripts = (void **)malloc(sizeof(driver_data_t *) * num_scripts);
  memset(mco.data->p_scripts, 0, sizeof(void *) * num_scripts);
  mco.data->keep_going = true;
  mco.data->num_scripts = num_scripts;
  mco.data->p_ctx = mco.egl_data->p_ctx;
  mco.data->screen_width = mco.egl_data->screen_width;
  mco.data->screen_height = mco.egl_data->screen_height;

  // test_draw(mco.egl_data);

  printf("initializing socket thread");
  pthread_create(&websocket_thread, NULL, websocket_process, &mco);

  // Main loop
  while (appletMainLoop())
  {
    if(mco.render_ready)
    {
      printf("rendering\n");
      test_draw(mco.egl_data);
      // clear the buffer
      glClear(GL_COLOR_BUFFER_BIT);

      // render the scene
      nvgBeginFrame( mco.egl_data->p_ctx, mco.egl_data->screen_width, mco.egl_data->screen_height, 1.0f);
      if ( mco.data->root_script >= 0 ) {
          run_script( mco.data->root_script, mco.data );
      }
      nvgEndFrame(mco.data->p_ctx);

      // Swap front and back buffers
      eglSwapBuffers(mco.egl_data->display, mco.egl_data->surface);
      mco.render_ready = false;
    }
    // Scan the gamepad. This should be done once for each frame
    padUpdate(&pad);

    // Your code goes here

    // padGetButtonsDown returns the set of buttons that have been newly pressed in this frame compared to the previous one
    u32 kDown = padGetButtonsDown(&pad);

    if (kDown & HidNpadButton_Plus)
    {
      websocket_interrupt();
      break; // break in order to return to hbmenu
    }

    if (kDown & HidNpadButton_A)
    {
    }
    if (kDown & HidNpadButton_B)
    {
    }

    if (kDown & HidNpadButton_X)
    {
    }

    if (kDown & HidNpadButton_Y)
    {
    }

    consoleUpdate(NULL);
  }
  pthread_join(websocket_thread, NULL);

  // socketExit();
  // consoleExit(NULL);
  return 0;
}
