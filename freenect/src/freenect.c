#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <assert.h>
#include <math.h>
#include <poll.h>
#include <errno.h>
#include <turbojpeg.h>
#include <libfreenect.h>
#include "erlcmd.h"

#define DEBUG

#ifdef DEBUG
#define log_location stderr
#define debug(...) do { fprintf(log_location, __VA_ARGS__); fflush(log_location); } while(0)
#define error(...) do { debug(__VA_ARGS__); } while (0)
#else
#define debug(...)
#define error(...) do { fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } while(0)
#endif

static struct erlcmd handler;
static struct pollfd fdset[2];
static int num_pollfds = 0;

volatile int die = 0;

// back: owned by libfreenect (implicit for depth)
// mid: owned by callbacks, "latest frame ready"
uint8_t *depth_mid;
uint8_t *rgb_back, *rgb_mid;

int camera_rotate = 0;
int tilt_changed = 0;

freenect_context *f_ctx;
freenect_device *f_dev;
int freenect_angle = 0;
int freenect_led;

// freenect_video_format requested_format = FREENECT_VIDEO_IR_8BIT;
// freenect_video_format current_format = FREENECT_VIDEO_IR_8BIT;

freenect_video_format requested_format = FREENECT_VIDEO_YUV_RGB;
freenect_video_format current_format = FREENECT_VIDEO_YUV_RGB;

int got_rgb = 0;
int got_depth = 0;

uint16_t t_gamma[2048];

#define NBANDS 3
#define WIDTH 640
#define HEIGHT 480

#define PITCH WIDTH*NBANDS

// #define PIXELFORMAT TJPF_GRAY
// #define JPEGSUBSAMP TJSAMP_GRAY

// #define PIXELFORMAT TJPF_RGB
// #define JPEGSUBSAMP TJSAMP_411

#define JPEGQUALITY 50

tjhandle tjhandle_;

int tj_init() {
    tjhandle_ = tjInitCompress();
    if(tjhandle_ == NULL)
    {
        const char *err = (const char *) tjGetErrorStr();
        printf(err);
        return -1;
    }
    return 0;
}

unsigned char* encode_jpeg(enum TJSAMP samp, char* srcBuf, unsigned long* jpegSize, unsigned char* jpegBuf) {
		int tj_stat;
		if (current_format == FREENECT_VIDEO_RGB || current_format == FREENECT_VIDEO_YUV_RGB) {
			tj_stat = tjCompress2(tjhandle_, srcBuf, WIDTH, PITCH, HEIGHT, TJPF_RGB, &jpegBuf, jpegSize, samp, JPEGQUALITY, 0);
		} else {
		// srcBuf+=640*4;
			tj_stat = tjCompress2(tjhandle_, srcBuf, WIDTH, PITCH, HEIGHT, TJPF_RGB, &jpegBuf, jpegSize, samp, JPEGQUALITY, 0);
		}
    if(tj_stat != 0)
    {
        const char *err = (const char *) tjGetErrorStr();
        printf(err);
        tjDestroy(tjhandle_);
        tjhandle_ = NULL;
        return NULL;
    }

    return jpegBuf;
}

void rgb_cb(freenect_device *dev, void *rgb, uint32_t timestamp)
{
	// swap buffers
	assert (rgb_back == rgb);
	rgb_back = rgb_mid;
	freenect_set_video_buffer(dev, rgb_back);
	rgb_mid = (uint8_t*)rgb;

	got_rgb++;
}

void depth_cb(freenect_device *dev, void *v_depth, uint32_t timestamp)
{
	int i;
	uint16_t *depth = (uint16_t*)v_depth;
	for (i=0; i<WIDTH*HEIGHT; i++) {
		int pval = t_gamma[depth[i]];
		int lb = pval & 0xff;
		switch (pval>>8) {
			case 0:
				depth_mid[3*i+0] = 255;
				depth_mid[3*i+1] = 255-lb;
				depth_mid[3*i+2] = 255-lb;
				break;
			case 1:
				depth_mid[3*i+0] = 255;
				depth_mid[3*i+1] = lb;
				depth_mid[3*i+2] = 0;
				break;
			case 2:
				depth_mid[3*i+0] = 255-lb;
				depth_mid[3*i+1] = 255;
				depth_mid[3*i+2] = 0;
				break;
			case 3:
				depth_mid[3*i+0] = 0;
				depth_mid[3*i+1] = 255;
				depth_mid[3*i+2] = lb;
				break;
			case 4:
				depth_mid[3*i+0] = 0;
				depth_mid[3*i+1] = 255-lb;
				depth_mid[3*i+2] = 255;
				break;
			case 5:
				depth_mid[3*i+0] = 0;
				depth_mid[3*i+1] = 0;
				depth_mid[3*i+2] = 255-lb;
				break;
			default:
				depth_mid[3*i+0] = 0;
				depth_mid[3*i+1] = 0;
				depth_mid[3*i+2] = 0;
				break;
		}
	}
	got_depth++;
}

#define ERLCMD_GET_RGB_AS_JPEG 0x0
#define ERLCMD_GET_DEPTH_AS_JPEG 0x1

static void handle_from_elixir(const uint8_t *buffer, size_t length, void *cookie) {
  if(buffer[sizeof(uint32_t) + 0] == ERLCMD_GET_RGB_AS_JPEG) {
		unsigned long jpegSize = 0;
    unsigned char* jpegBuf = encode_jpeg(TJSAMP_411, rgb_mid, &jpegSize, NULL);
    if(jpegBuf == NULL) {
      debug("failed to encode jpeg\r\n");
			return;
    } else {
      debug("made rgb jpeg\r\n");
    }
    unsigned char* erlcmdBuf = malloc(jpegSize + sizeof(uint32_t));
    memset(erlcmdBuf, 0, jpegSize + sizeof(uint32_t));
    memcpy(erlcmdBuf+sizeof(uint32_t), jpegBuf, jpegSize);
    erlcmd_send(erlcmdBuf, jpegSize + sizeof(uint32_t));
    free(jpegBuf);

  } else if(buffer[sizeof(uint32_t) + 1] == ERLCMD_GET_DEPTH_AS_JPEG) {
		unsigned long jpegSize = 0;
    unsigned char* jpegBuf = encode_jpeg(TJSAMP_GRAY, depth_mid, &jpegSize, NULL);
    if(jpegBuf == NULL) {
      debug("failed to encode jpeg\r\n");
			return;
    } else {
      debug("made depth jpeg\r\n");
    }
    unsigned char* erlcmdBuf = malloc(jpegSize + sizeof(uint32_t));
    memset(erlcmdBuf, 0, jpegSize + sizeof(uint32_t));
    memcpy(erlcmdBuf+sizeof(uint32_t), jpegBuf, jpegSize);
    erlcmd_send(erlcmdBuf, jpegSize + sizeof(uint32_t));
    free(jpegBuf);
	} 
	else {
    debug("handle_from_elixir: len=%lu", length);
  }
}

bool isCallerDown()
{
  struct pollfd ufd;
  memset(&ufd, 0, sizeof ufd);
  ufd.fd     = ERLCMD_READ_FD;
  ufd.events = POLLIN;
  if (poll(&ufd, 1, 0) < 0)
    return true;
  return ufd.revents & POLLHUP;
}

int main(int argc, char **argv)
{
	int res;
  res = tj_init();
  if(res< 0) {
    debug("failed to init turbojpeg\r\n");
    return res;
  }

  erlcmd_init(&handler, handle_from_elixir, NULL);

  // Initialize the file descriptor set for polling
  memset(fdset, -1, sizeof(fdset));
  fdset[0].fd = ERLCMD_READ_FD;
  fdset[0].events = POLLIN;
  fdset[0].revents = 0;
  num_pollfds = 1;

	depth_mid = (uint8_t*)malloc(WIDTH*HEIGHT*3);
	rgb_back = (uint8_t*)malloc(WIDTH*HEIGHT*3);
	rgb_mid = (uint8_t*)malloc(WIDTH*HEIGHT*3);

	debug("Kinect camera test\n");

	int i;
	for (i=0; i<2048; i++) {
		float v = i/2048.0;
		v = powf(v, 3)* 6;
		t_gamma[i] = v*6*256;
	}

	if (freenect_init(&f_ctx, NULL) < 0) {
		debug("freenect_init() failed\n");
		return 1;
	}

	freenect_set_log_level(f_ctx, FREENECT_LOG_DEBUG);
	freenect_select_subdevices(f_ctx, (freenect_device_flags)(FREENECT_DEVICE_MOTOR | FREENECT_DEVICE_CAMERA));

	int nr_devices = freenect_num_devices (f_ctx);
	printf ("Number of devices found: %d\n", nr_devices);

	if (nr_devices < 1) {
		freenect_shutdown(f_ctx);
		return 1;
	}

	if (freenect_open_device(f_ctx, &f_dev, 0) < 0) {
		debug("Could not open device\n");
		freenect_shutdown(f_ctx);
		return 1;
	}

  freenect_set_tilt_degs(f_dev,freenect_angle);
	freenect_set_led(f_dev,LED_RED);
	freenect_set_depth_callback(f_dev, depth_cb);
	freenect_set_video_callback(f_dev, rgb_cb);
	freenect_set_video_mode(f_dev, freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, current_format));
	freenect_set_depth_mode(f_dev, freenect_find_depth_mode(FREENECT_RESOLUTION_MEDIUM, FREENECT_DEPTH_11BIT));
	freenect_set_video_buffer(f_dev, rgb_back);

	freenect_start_depth(f_dev);
	freenect_start_video(f_dev);


	int accelCount = 0;
	while (!isCallerDown() && freenect_process_events(f_ctx) >= 0) {
    for (int i = 0; i < num_pollfds; i++)
        fdset[i].revents = 0;

    int rc = poll(fdset, num_pollfds, 0);
    if (rc < 0) {
        // Retry if EINTR
        if (errno == EINTR)
            continue;
        error("poll failed with %d", errno);
    }

    if (fdset[0].revents & (POLLIN | POLLHUP))
        erlcmd_process(&handler);


		if (requested_format != current_format) {
			freenect_stop_video(f_dev);
			freenect_set_video_mode(f_dev, freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, requested_format));
			freenect_start_video(f_dev);
			current_format = requested_format;
		}
	}

	debug("\nshutting down streams...\n");

	freenect_stop_depth(f_dev);
	freenect_stop_video(f_dev);

	freenect_close_device(f_dev);
	freenect_shutdown(f_ctx);

  tjDestroy(tjhandle_); //should deallocate data buffer
	return 0;
}