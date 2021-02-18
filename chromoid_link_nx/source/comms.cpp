#include <sys/time.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
// #include <pthread.h>

#include <GLES2/gl2.h>
// #include <GLES2/gl2ext.h>


#include <sys/select.h>

#include "types.h"
#include "comms.h"
#include "render_script.h"
#include "tx.h"
#include "utils.h"

#define   MSG_OUT_CLOSE             0x00
#define   MSG_OUT_STATS             0x01
#define   MSG_OUT_PUTS              0x02
#define   MSG_OUT_WRITE             0x03
#define   MSG_OUT_INSPECT           0x04
#define   MSG_OUT_RESHAPE           0x05
#define   MSG_OUT_READY             0x06
#define   MSG_OUT_DRAW_READY        0x07

#define   MSG_OUT_KEY               0x0A
#define   MSG_OUT_CODEPOINT         0x0B
#define   MSG_OUT_CURSOR_POS        0x0C
#define   MSG_OUT_MOUSE_BUTTON      0x0D
#define   MSG_OUT_MOUSE_SCROLL      0x0E
#define   MSG_OUT_CURSOR_ENTER      0x0F
#define   MSG_OUT_DROP_PATHS        0x10
#define   MSG_OUT_STATIC_TEXTURE_MISS 0x20
#define   MSG_OUT_DYNAMIC_TEXTURE_MISS 0x21

#define   MSG_OUT_FONT_MISS         0x22

// #define   MSG_OUT_NEW_DL_ID         0x30
#define   MSG_OUT_NEW_TX_ID         0x31
#define   MSG_OUT_NEW_FONT_ID       0x32



#define   CMD_RENDER_GRAPH          0x01
#define   CMD_CLEAR_GRAPH           0x02
#define   CMD_SET_ROOT              0x03

#define   CMD_CLEAR_COLOR           0x05

// #define   CMD_CACHE_LOAD            0x03
// #define   CMD_CACHE_RELEASE         0x04

#define   CMD_INPUT                 0x0A

#define   CMD_QUIT                  0x20
#define   CMD_QUERY_STATS           0x21
#define   CMD_RESHAPE               0x22
#define   CMD_POSITION              0x23
#define   CMD_FOCUS                 0x24
#define   CMD_ICONIFY               0x25
#define   CMD_MAXIMIZE              0x26
#define   CMD_RESTORE               0x27
#define   CMD_SHOW                  0x28
#define   CMD_HIDE                  0x29

// #define   CMD_NEW_DL_ID             0x30
// #define   CMD_FREE_DL_ID            0x31

#define   CMD_NEW_TX_ID             0x32
#define   CMD_FREE_TX_ID            0x33
#define   CMD_PUT_TX_BLOB           0x34
#define   CMD_PUT_TX_RAW            0x35


#define   CMD_LOAD_FONT_FILE        0X37
#define   CMD_LOAD_FONT_BLOB        0X38
#define   CMD_FREE_FONT             0X39

// here to test recovery
#define   CMD_CRASH                 0xFE



// handy time definitions in microseconds
#define MILLISECONDS_8              8000
#define MILLISECONDS_16             16000
#define MILLISECONDS_20             20000
#define MILLISECONDS_32             32000
#define MILLISECONDS_64             64000
#define MILLISECONDS_128            128000


// Setting the timeout too high means input will be laggy as you
// are starving the input polling. Setting it too low means using
// energy for no purpose. Probably best if set similar to the
// frame rate of the application
#define STDIO_TIMEOUT               MILLISECONDS_32

// https://stackoverflow.com/questions/2182002/convert-big-endian-to-little-endian-in-c-without-using-provided-func
#define SWAP_UINT16(x) (((x) >> 8) | ((x) << 8))
#define SWAP_UINT32(x) (((x) >> 24) | (((x) & 0x00FF0000) >> 8) | (((x) & 0x0000FF00) << 8) | ((x) << 24))

static bool f_little_endian;

// pthread_rwlock_t comms_out_lock = PTHREAD_RWLOCK_INITIALIZER;

//=============================================================================
// raw comms with host app
// from erl_comm.c
// http://erlang.org/doc/tutorial/c_port.html#id64377

void test_endian() {
  uint32_t i=0x01234567;
  f_little_endian = (*((uint8_t*)(&i))) == 0x67;
}

//---------------------------------------------------------
// the length indicator from erlang is always big-endian
int write_cmd(struct my_conn* mco, byte *buf, unsigned int len)
{
  printf("write_cmd\n");
  int written = 0;
  // unsigned char write_buf[LWS_PRE + len];
  // memcpy(write_buf, &buf[LWS_PRE], len);
  lwsl_hexdump_notice(buf, len);
  // written = lws_write(wsi, &write_buf[LWS_PRE], len, LWS_WRITE_BINARY);
  written = lws_write(mco->wsi, buf, len, LWS_WRITE_BINARY);
  printf("lws_write done\n");
  return written;
}

//---------------------------------------------------------
// Starts by using select to see if there is any data to be read
// if not in timeout, then returns with -1
// Setting the timeout too high means input will be laggy as you
// are starving the input polling. Setting it too low means using
// energy for no purpose. Probably best if set similar to the
// frame rate
// int read_msg_length(struct timeval *ptv) {
//   byte  buff[4];

//   fd_set rfds;
//   int retval;

//   // Watch stdin (fd 0) to see when it has input.
//   FD_ZERO(&rfds);
//   FD_SET(0, &rfds);

//   // look for data
//   retval = select(1, &rfds, NULL, NULL, ptv);
//   if (retval == -1) {
//     return -1;  // error
//   }
//   else if (retval) {
//     if (read_exact(buff, 4) != 4) return(-1);
//     // length from erlang is always big endian
//     uint32_t len = *((uint32_t*)&buff);
//     if (f_little_endian) len = SWAP_UINT32(len);
//     return len;
//   } else {
//     // no data within the timeout
//     return -1;
//   }
// }

//=============================================================================
// send messages up to caller

//---------------------------------------------------------
void send_puts( const char* msg ) {
  // uint32_t msg_len = strlen(msg);
  // uint32_t cmd_len = msg_len + sizeof(uint32_t);
  // uint32_t cmd = MSG_OUT_PUTS;

  // if (f_little_endian) cmd_len = SWAP_UINT32(cmd_len);

  // write_exact((byte*)&cmd_len, sizeof(uint32_t));
  // write_exact((byte*)&cmd, sizeof(uint32_t));
  // write_exact((byte*)msg, msg_len);
}

//---------------------------------------------------------
void send_write( const char* msg ) {
  printf("===send_write stub====\n");
  // uint32_t msg_len = strlen(msg);
  // uint32_t cmd_len = msg_len + sizeof(uint32_t);
  // uint32_t cmd = MSG_OUT_WRITE;

  // if (f_little_endian) cmd_len = SWAP_UINT32(cmd_len);

  // write_exact((byte*)&cmd_len, sizeof(uint32_t));
  // write_exact((byte*)&cmd, sizeof(uint32_t));
  // write_exact((byte*)msg, msg_len);
}

//---------------------------------------------------------
void send_inspect( void* data, int length ) {
  printf("===send_inspect stub====\n");
  // uint32_t cmd_len = length + sizeof(uint32_t);
  // uint32_t cmd = MSG_OUT_INSPECT;

  // if (f_little_endian) cmd_len = SWAP_UINT32(cmd_len);

  // write_exact((byte*)&cmd_len, sizeof(uint32_t));
  // write_exact((byte*)&cmd, sizeof(uint32_t));
  // write_exact(data, length);
}

//---------------------------------------------------------
void send_static_texture_miss(const char* key)
{
  printf("===send_static_texture_miss stub====\n");
  // uint32_t msg_len = strlen(key);
  // uint32_t cmd_len = msg_len + sizeof(uint32_t);
  // uint32_t cmd     = MSG_OUT_STATIC_TEXTURE_MISS;

  // if (f_little_endian)
  //   cmd_len = SWAP_UINT32(cmd_len);

  // write_exact((byte*) &cmd_len, sizeof(uint32_t));
  // write_exact((byte*) &cmd, sizeof(uint32_t));
  // write_exact((byte*) key, msg_len);
}

//---------------------------------------------------------
void send_dynamic_texture_miss(const char* key)
{
  printf("===send_dynamic_texture_miss stub====\n");
  // uint32_t msg_len = strlen(key);
  // uint32_t cmd_len = msg_len + sizeof(uint32_t);
  // uint32_t cmd     = MSG_OUT_DYNAMIC_TEXTURE_MISS;

  // if (f_little_endian)
  //   cmd_len = SWAP_UINT32(cmd_len);

  // write_exact((byte*) &cmd_len, sizeof(uint32_t));
  // write_exact((byte*) &cmd, sizeof(uint32_t));
  // write_exact((byte*) key, msg_len);
}

//---------------------------------------------------------
void send_font_miss( struct my_conn* mco, const char* key ) {
  printf("===send_font_miss====\n");
  uint32_t msg_len = strlen(key);
  uint32_t cmd_len = msg_len + sizeof(uint32_t);
  uint32_t cmd = MSG_OUT_FONT_MISS;

  // if (f_little_endian) cmd_len = SWAP_UINT32(cmd_len);
  byte *buf;
  buf = (byte*)malloc(cmd_len);
  memset(buf, 0, cmd_len);
  memcpy(buf, &cmd, sizeof(uint32_t));
  memcpy(buf+sizeof(uint32_t), key, msg_len);
  write_cmd(mco, buf, msg_len + sizeof(uint32_t));

  // write_exact((byte*)&cmd_len, sizeof(uint32_t));
  // write_exact((byte*)&cmd, sizeof(uint32_t));
  // write_exact((byte*)key, msg_len);
}


//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t    msg_id;
  uint32_t    key;
  uint32_t    scancode;
  uint32_t    action;
  uint32_t    mods;
} msg_key_t;

void send_key(int key, int scancode, int action, int mods) {
  printf("===send_key stub====\n");
  msg_key_t msg = { MSG_OUT_KEY, key, scancode, action, mods };
  // write_cmd( (byte*)&msg, sizeof(msg_key_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  uint32_t    codepoint;
  uint32_t    mods;
} msg_codepoint_t;

void send_codepoint(unsigned int codepoint, int mods) {
  printf("===send_codepoint stub====\n");
  msg_codepoint_t msg = { MSG_OUT_CODEPOINT, codepoint, mods };
  // write_cmd( (byte*)&msg, sizeof(msg_codepoint_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  float           x;
  float           y;
} msg_cursor_pos_t;

void send_cursor_pos(float xpos, float ypos) {
  printf("===send_cursor_pos stub====\n");
  msg_cursor_pos_t  msg = { MSG_OUT_CURSOR_POS, xpos, ypos };
  // write_cmd( (byte*)&msg, sizeof(msg_cursor_pos_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  uint32_t    button;
  uint32_t    action;
  uint32_t    mods;
  float           xpos;
  float           ypos;
} msg_mouse_button_t;

void send_mouse_button(int button, int action, int mods, float xpos, float ypos) {
  printf("===send_mouse_button stub====\n");
  msg_mouse_button_t  msg = { MSG_OUT_MOUSE_BUTTON, button, action, mods, xpos, ypos };
  // write_cmd( (byte*)&msg, sizeof(msg_mouse_button_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  float           x_offset;
  float           y_offset;
  float           x;
  float           y;
} msg_scroll_t;

void send_scroll(float xoffset, float yoffset, float xpos, float ypos) {
  printf("===send_scroll stub====\n");
  msg_scroll_t  msg = { MSG_OUT_MOUSE_SCROLL, xoffset, yoffset, xpos, ypos };
  // write_cmd( (byte*)&msg, sizeof(msg_scroll_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  int32_t             entered;
  float           x;
  float           y;
} msg_cursor_enter_t;

void send_cursor_enter(int entered, float xpos, float ypos) {
  printf("===send_cursor_enter stub====\n");
  msg_cursor_enter_t  msg = { MSG_OUT_CURSOR_ENTER, entered, xpos, ypos };
  // write_cmd( (byte*)&msg, sizeof(msg_cursor_enter_t) );
}

//---------------------------------------------------------
void send_close() {
  printf("===send_close stub====\n");
  uint32_t  msg = MSG_OUT_CLOSE;
  // write_cmd( (byte*)&msg, sizeof(uint32_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  int32_t             empty_dl;
  int32_t             width;
  int32_t             height;
} msg_ready_t;
void send_ready(struct my_conn* mco, int root_id, int width, int height ) {
  msg_ready_t  msg = { MSG_OUT_READY, root_id, width, height };
  write_cmd(mco, (byte*)&msg, sizeof(msg_ready_t) );
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t   msg_id;
  uint32_t    id;
} msg_draw_ready_t;

void send_draw_ready( struct my_conn* mco, unsigned int id ) {
  msg_draw_ready_t  msg = { MSG_OUT_DRAW_READY, id};
  write_cmd( mco, (byte*)&msg, sizeof(msg_draw_ready_t) );
}

//=============================================================================
// incoming messages


//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  uint32_t      msg_id;
  uint32_t      input_flags;
  int32_t       xpos;
  int32_t       ypos;
  int32_t       width;
  int32_t       height;
} msg_stats_t;
void receive_query_stats( struct my_conn* mco, char* payload, size_t len ) {
  printf("receive_query_stats\n");
  msg_stats_t   msg;

  msg.msg_id = MSG_OUT_STATS;
  // msg.input_flags = p_data->input_flags;
  msg.input_flags = 0;

  // can't point into packed structure...
  // glfwGetWindowPos(window, &a, &b);
  msg.xpos = 0;
  msg.ypos = 0;

  // can't point into packed structure...
  msg.width = mco->data->screen_width;
  msg.height = mco->data->screen_height;

  write_cmd(mco, (byte*)&msg, sizeof(msg_stats_t) );
}

// //---------------------------------------------------------
// void receive_input( int* p_msg_length, GLFWwindow* window ) {
//   window_data_t*  p_window_data = glfwGetWindowUserPointer( window );
//   read_bytes_down( &p_window_data->input_flags, sizeof(uint32_t), p_msg_length);
// }


//---------------------------------------------------------
void receive_quit( driver_data_t* p_data, char* payload, size_t len ) {
  // clear the keep_going control flag, this ends the main thread loop
  p_data->keep_going = false;
}

//---------------------------------------------------------
void receive_crash() {
  send_puts( "receive_crash - exit" );
  exit(EXIT_FAILURE);
}


//---------------------------------------------------------
void receive_render( struct my_conn* mco, char* payload, size_t len ) {

  // get the draw list id to compile
  GLuint id;
  // read_bytes_down( &id, sizeof(GLuint), p_msg_length);
  memcpy(&id, payload, sizeof(GLuint));
  len-=sizeof(GLuint);
  payload+=sizeof(GLuint);
  printf("receiving script id=%d len=%lu\n", id, len);

  // extract the render script itself
  void* p_script = malloc(len);
  // read_bytes_down( p_script, *p_msg_length, p_msg_length);
  memcpy(p_script, payload, len);
  len-=len;
  payload+=len;
  
  // char buff[200];
  // sprintf(buff, "receive_render %d", id);
  // send_puts( buff );

  // save the script away for later
  put_script( mco->data, id, p_script );

  // render the graph
//  if ( pthread_rwlock_wrlock(&p_data->context.gl_lock) == 0 ) {
    // render( p_msg_length, p_data );
//    pthread_rwlock_unlock(&p_data->context.gl_lock);
//  }

// send the signal that drawing is done
  send_draw_ready( mco, id );
}

//---------------------------------------------------------
void receive_clear( driver_data_t* p_data, char* payload, size_t len ) {
  printf("====receive_clear===");
  // get and validate the dl_id
  GLuint id;
  // read_bytes_down( &id, sizeof(GLint), p_msg_length);
  memcpy(&id, payload, sizeof(GLuint));
  len-=sizeof(GLuint);
  payload+=sizeof(GLuint);

  // char buff[200];
  // sprintf(buff, "delete_render %d", id);
  // send_puts( buff );

  // delete the list
  delete_script( p_data, id );

  // post a message to kick the display loop
  // glfwPostEmptyEvent();
}

//---------------------------------------------------------
void receive_set_root( driver_data_t* p_data, char* payload, size_t len ) {
  // get and validate the dl_id
  GLint id;
  // read_bytes_down( &id, sizeof(GLint), p_msg_length);
  memcpy(&id, payload, sizeof(GLuint));
  len-=sizeof(GLuint);
  payload+=sizeof(GLuint);
  printf("receive_set_root=%d\n", id);

  // update the current_dl with the incoming id
//  if ( pthread_rwlock_wrlock(&p_data->context.gl_lock) == 0 ) {
    p_data->root_script = id;
//    pthread_rwlock_unlock(&p_data->context.gl_lock);
//  }
}


//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  GLuint r;
  GLuint g;
  GLuint b;
  GLuint a;
} clear_color_t;
void receive_clear_color( driver_data_t* p_data, char* payload, size_t len ) {
  // get the clear_color
  clear_color_t cc;
  // read_bytes_down( &cc, sizeof(clear_color_t), p_msg_length);
  memcpy(&cc, payload, sizeof(clear_color_t));
  len-=sizeof(clear_color_t);
  payload+=sizeof(clear_color_t);
  glClearColor(cc.r/255.0, cc.g/255.0, cc.b/255.0, cc.a/255.0);
}


//---------------------------------------------------------
typedef struct __attribute__((__packed__)) 
{
  GLuint name_length;
  GLuint data_length;
} font_info_t;

void receive_load_font_file( driver_data_t* p_data, char* payload, size_t len ) {
  NVGcontext* p_ctx = p_data->p_ctx;

  font_info_t font_info;
  // read_bytes_down( &font_info, sizeof(font_info_t), p_msg_length);
  memcpy(&font_info, payload, sizeof(font_info_t));
  len-=sizeof(font_info_t);
  payload+=sizeof(font_info_t);

  // create the name and data
  char* p_name = (char*)malloc(font_info.name_length);
  // read_bytes_down( p_name, font_info.name_length, p_msg_length);
  memcpy(p_name, payload, font_info.name_length);
  len-=font_info.name_length;
  payload+=font_info.name_length;

  char* p_path = (char*)malloc(font_info.data_length);
  // read_bytes_down( p_path, font_info.data_length, p_msg_length);
  memcpy(p_path, payload, font_info.data_length);
  len-=font_info.data_length;
  payload+=font_info.data_length;

  // only load the font if it is not already loaded!
  if (nvgFindFont(p_ctx, p_name) < 0) {
    nvgCreateFont(p_ctx, p_name, p_path);
  }

  free(p_name);
  free(p_path);
}


//---------------------------------------------------------
void receive_load_font_blob( driver_data_t* p_data, char* payload, size_t len ) {
  NVGcontext* p_ctx = p_data->p_ctx;

  font_info_t font_info;
  // read_bytes_down( &font_info, sizeof(font_info_t), p_msg_length);
  memcpy(&font_info, payload, sizeof(font_info_t));
  len-=sizeof(font_info_t);
  payload+=sizeof(font_info_t);

  // create the name and data
  void* p_name = malloc(font_info.name_length);
  // read_bytes_down( p_name, font_info.name_length, p_msg_length);
  memcpy(p_name, payload, font_info.name_length);
  len-=font_info.name_length;
  payload+=font_info.name_length;

  void* p_blob = malloc(font_info.data_length);
  // read_bytes_down( p_blob, font_info.data_length, p_msg_length);
  memcpy(p_blob, payload, font_info.data_length);
  len-=font_info.data_length;
  payload+=font_info.data_length;

  // only load the font if it is not already loaded!
  if (nvgFindFont(p_ctx, (const char*)p_name) < 0) {
    nvgCreateFontMem(p_ctx, (const char*)p_name, (unsigned char *)p_blob, font_info.data_length, true);
  }

  free(p_name);
}
    // case CMD_FREE_FONT:       receive_free_font( &msg_length );               break;




//---------------------------------------------------------
bool dispatch_message(struct my_conn* mco, char* payload, size_t len) {

  bool render = false;

  char buff[200];
  // send_puts("--------------------------------------------------");
  // sprintf(buff, "start dispatch_message 0x%02X", msg_id);
  // send_puts( buff );

  check_gl_error( "starting error: " );
  uint32_t msg_id = 0;
  memcpy(&msg_id, payload, sizeof(uint32_t));
  len-=sizeof(uint32_t);
  payload+=sizeof(uint32_t);
  printf("message_id: %04x\n", msg_id);

  switch( msg_id ) {
    case CMD_QUIT:            receive_quit( mco->data, payload, len );                         return false;

    case CMD_RENDER_GRAPH:    receive_render( mco, payload, len );          render = true; break;
    case CMD_CLEAR_GRAPH:     receive_clear( mco->data, payload, len );           render = true; break;    
    case CMD_SET_ROOT:        receive_set_root( mco->data, payload, len );        render = true; break;

    case CMD_CLEAR_COLOR:     receive_clear_color( mco->data, payload, len );             render = true; break;

    // case CMD_INPUT:           receive_input( mco->data, payload, len );           break;

    case CMD_QUERY_STATS:     receive_query_stats( mco, payload, len );                  break;

    // font handling
    case CMD_LOAD_FONT_FILE:  receive_load_font_file( mco->data, payload, len );  render = true; break;
    case CMD_LOAD_FONT_BLOB:  receive_load_font_blob( mco->data, payload, len );  render = true; break;
    // case CMD_FREE_FONT:       receive_free_font( mco->data, payload, len );       break;

    // the next two are in texture.c
    case CMD_PUT_TX_BLOB:     receive_put_tx_blob( mco->data, payload, len );     render = true; break;
    // case CMD_PUT_TX_RAW:      receive_put_tx_raw( mco->data, payload, len );      render = true; break;
    case CMD_FREE_TX_ID:      receive_free_tx_id( mco->data, payload, len );      break;

    // the next set are in text.c
    // case CMD_PUT_FONT:        receive_put_font_atlas( mco->data, payload, len );  render = true; break;
    // case CMD_FREE_FONT_ID:    receive_free_font_atlas( mco->data, payload, len ); render = true; break;

    case CMD_CRASH:           receive_crash();                                break;

    default:
      sprintf( buff, "Unknown message: 0x%02X", msg_id );
      send_puts( buff );
  }

  // if there are any bytes left to read in the message, need to get rid of them here...
  // if ( msg_length > 0 ) {
  //   sprintf( buff, "WARNING Excess message bytes! %d", msg_length );
  //   send_puts( buff );
  //   void* p = malloc(msg_length);
  //   read_bytes_down( p, msg_length, &msg_length);
  //   free(p);
  // }

  sprintf(buff, "end dispatch_message %d", msg_id);
  check_gl_error( buff );

  return render;
}

uint64_t get_time_stamp() {
    struct timeval tv;
    gettimeofday(&tv,NULL);
    return tv.tv_sec*(uint64_t)1000000+tv.tv_usec;
}

bool handle_data_in( struct my_conn* mco, char* payload, size_t len )
{
  printf("Received data size=%lu\r\n", len);
  // lwsl_hexdump_notice(payload, len);
  return dispatch_message(mco, payload, len);
}
