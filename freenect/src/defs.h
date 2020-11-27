#ifndef FREENECT_PORT_DEFS
#define FREENECT_PORT_DEFS

#define ERLCMD_EVENT_BUFFER_RGB 0x0
#define ERLCMD_EVENT_BUFFER_DEPTH 0x1
#define ERLCMD_EVENT_BUFFER_RGB_JPEG 0x2
#define ERLCMD_EVENT_BUFFER_DEPTH_JPEG 0x3

#define ERLCMD_EVENT_LED_STATE 0x7
#define ERLCMD_EVENT_TILT_STATE 0x8
#define ERLCMD_EVENT_LOG 0x9

#define ERLCMD_GET_BUFFER_RGB 0x10
#define ERLCMD_GET_BUFFER_DEPTH 0x11
#define ERLCMD_GET_BUFFER_RGB_JPEG 0x12
#define ERLCMD_GET_BUFFER_DEPTH_JPEG 0x13

#define ERLCMD_GET_LED_STATE 0x17
#define ERLCMD_GET_TILT_STATE 0x18

#define ERLCMD_SET_LED_STATE 0x27
#define ERLCMD_SET_TILT_STATE 0x28

#define ERLCMD_SET_VIDEO_FORMAT 0x30
#define ERLCMD_SET_DEPTH_FORMAT 0x31

#define ERLCMD_SUBSCRIBE_BUFFER_RGB 0x40
#define ERLCMD_SUBSCRIBE_BUFFER_DEPTH 0x41

#endif
