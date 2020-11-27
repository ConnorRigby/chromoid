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
#include "defs.h"

#define DEBUG

#ifdef DEBUG
#define log_location stderr
#define debug(...)                      \
	do                                    \
	{                                     \
		fprintf(log_location, __VA_ARGS__); \
		fflush(log_location);               \
	} while (0)
#define error(...)      \
	do                    \
	{                     \
		debug(__VA_ARGS__); \
	} while (0)
#else
#define debug(...)
#define error(...)                \
	do                              \
	{                               \
		fprintf(stderr, __VA_ARGS__); \
		fprintf(stderr, "\n");        \
	} while (0)
#endif

static struct erlcmd handler;
static struct pollfd fdset[2];
static int num_pollfds = 0;

// back: owned by libfreenect (implicit for depth)
// mid: owned by callbacks, "latest frame ready"
uint8_t *depth_back, *depth_mid;
uint8_t *rgb_back, *rgb_mid;
uint16_t t_gamma[2048];

int camera_rotate = 0;
int tilt_changed = 0;

freenect_context *f_ctx;
freenect_device *f_dev;

int freenect_angle = 0;
int freenect_led = LED_RED;

bool buffer_rgb_subscribe = false;
bool buffer_depth_subscribe  = true;

// freenect_video_format requested_video_format = FREENECT_VIDEO_YUV_RGB;
// freenect_video_format current_video_format = FREENECT_VIDEO_YUV_RGB;
freenect_video_format requested_video_format = FREENECT_VIDEO_RGB;
freenect_video_format current_video_format = FREENECT_VIDEO_RGB;

// freenect_video_format requested_video_format = FREENECT_VIDEO_IR_8BIT;
// freenect_video_format current_video_format = FREENECT_VIDEO_IR_8BIT;

freenect_depth_format requested_depth_format = FREENECT_DEPTH_REGISTERED;
freenect_depth_format current_depth_format = FREENECT_DEPTH_REGISTERED;

// freenect_depth_format requested_depth_format = FREENECT_DEPTH_11BIT;
// freenect_depth_format current_depth_format = FREENECT_DEPTH_11BIT;

freenect_frame_mode video_mode;
freenect_frame_mode depth_mode;

#define NBANDS 3
#define WIDTH 640
#define HEIGHT 480

#define PITCH WIDTH *NBANDS
#define JPEGQUALITY 50

tjhandle tjhandle_;

int tj_init()
{
	tjhandle_ = tjInitCompress();
	if (tjhandle_ == NULL)
	{
		const char *err = (const char *)tjGetErrorStr();
		printf(err);
		return -1;
	}
	return 0;
}

unsigned char *encode_jpeg(enum TJSAMP samp, char *srcBuf, unsigned long *jpegSize, unsigned char *jpegBuf)
{
	int tj_stat;
	if (current_video_format == FREENECT_VIDEO_RGB || current_video_format == FREENECT_VIDEO_YUV_RGB)
	{
		tj_stat = tjCompress2(tjhandle_, srcBuf, WIDTH, PITCH, HEIGHT, TJPF_RGB, &jpegBuf, jpegSize, samp, JPEGQUALITY, 0);
	}
	else
	{
		srcBuf+=640*4;
		tj_stat = tjCompress2(tjhandle_, srcBuf, WIDTH, PITCH, HEIGHT, TJPF_RGB, &jpegBuf, jpegSize, samp, JPEGQUALITY, 0);
	}
	if (tj_stat != 0)
	{
		const char *err = (const char *)tjGetErrorStr();
		printf(err);
		tjDestroy(tjhandle_);
		tjhandle_ = NULL;
		return NULL;
	}

	return jpegBuf;
}

void dispatch_tilt_state(freenect_raw_tilt_state *tilt_state)
{
	size_t msglen = sizeof(uint32_t) + // packet: 4
									sizeof(uint8_t) +	 // opcode
									sizeof(uint16_t) + // accelerometer_x
									sizeof(uint16_t) + // accelerometer_y
									sizeof(uint16_t) + // accelerometer_z
									sizeof(uint8_t) +	 // tilt_angle
									sizeof(uint8_t);	 // tilt_status

	char *erlcmdBuf = malloc(msglen);
	memset(erlcmdBuf, 0, msglen);

	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_TILT_STATE;
	debug("dispatching tilt state: \r\n");
	debug("x=%lu, y=%lu, z=%lu\r\n", tilt_state->accelerometer_x,
				tilt_state->accelerometer_y,
				tilt_state->accelerometer_z);

	debug("angle=%lu, status=%lu\r\n", tilt_state->tilt_angle,
				tilt_state->tilt_status);

	erlcmd_send(erlcmdBuf, msglen);
	free(erlcmdBuf);
}

void dispatch_led_state(freenect_led_options led_options)
{
	size_t msglen = sizeof(uint32_t) + // packet: 4
									sizeof(uint8_t) +	 // opcode
									sizeof(uint8_t);	 // led_status
	char *erlcmdBuf = malloc(msglen);
	memset(erlcmdBuf, 0, msglen);
	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_LED_STATE;
	erlcmdBuf[sizeof(uint32_t) + 1] = led_options;
	erlcmd_send(erlcmdBuf, msglen);
	free(erlcmdBuf);
}

void dispatch_rgb_jpeg(uint8_t* rgb)
{
	unsigned long jpegSize = 0;
	unsigned char* jpegBuf = encode_jpeg(TJSAMP_411, rgb, &jpegSize, NULL);
	if(jpegBuf == NULL) {
		debug("failed to encode jpeg\r\n");
		return;
	} else {
		debug("made rgb jpeg\r\n");
	}

	size_t msglen = sizeof(uint32_t) + // packet: 4
									sizeof(uint8_t) + // opcode
									jpegSize;

	unsigned char* erlcmdBuf = malloc(msglen);
	memset(erlcmdBuf, 0, msglen);
	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_BUFFER_RGB_JPEG;
	memcpy(&erlcmdBuf[sizeof(uint32_t)+1], jpegBuf, jpegSize);
	erlcmd_send(erlcmdBuf, msglen);
	free(jpegBuf);
	free(erlcmdBuf);
}

void dispatch_depth_jpeg(uint8_t* depth)
{
	unsigned long jpegSize = 0;
	unsigned char* jpegBuf = encode_jpeg(TJSAMP_GRAY, depth, &jpegSize, NULL);
	if(jpegBuf == NULL) {
		debug("failed to encode jpeg\r\n");
		return;
	} else {
		debug("made depth jpeg\r\n");
	}

	size_t msglen = sizeof(uint32_t) + // packet: 4
									sizeof(uint8_t) + // opcode
									jpegSize;

	unsigned char* erlcmdBuf = malloc(msglen);
	memset(erlcmdBuf, 0, msglen);
	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_BUFFER_DEPTH_JPEG;
	memcpy(&erlcmdBuf[sizeof(uint32_t)+1], jpegBuf, jpegSize);
	erlcmd_send(erlcmdBuf, msglen);
	free(jpegBuf);
	free(erlcmdBuf);
}

void dispatch_rgb(uint8_t* rgb)
{
	size_t msglen = sizeof(uint32_t) + // packet: 4
									sizeof(uint8_t) + // opcode
									video_mode.bytes;

	unsigned char* erlcmdBuf = malloc(msglen);
	memset(erlcmdBuf, 0, msglen);
	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_BUFFER_RGB;
	memcpy(&erlcmdBuf[sizeof(uint32_t)+1], rgb, video_mode.bytes);
	erlcmd_send(erlcmdBuf, msglen);
	free(erlcmdBuf);
}

void dispatch_depth(uint8_t* depth)
{
	size_t msglen = sizeof(uint32_t) + // packet: 4
									sizeof(uint8_t) + // opcode
									depth_mode.bytes;

	unsigned char* erlcmdBuf = malloc(msglen);
	memset(erlcmdBuf, 0, msglen);
	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_BUFFER_DEPTH;
	memcpy(&erlcmdBuf[sizeof(uint32_t)+1], depth, depth_mode.bytes);
	erlcmd_send(erlcmdBuf, msglen);
	free(erlcmdBuf);
}

void log_cb(freenect_context *dev, freenect_loglevel level, const char *msg)
{
	size_t msglen = strlen(msg);
	char *erlcmdBuf = malloc(msglen + sizeof(uint8_t) + sizeof(uint8_t) + sizeof(uint32_t));
	memset(erlcmdBuf, 0, msglen + sizeof(uint8_t) + sizeof(uint8_t) + sizeof(uint32_t));
	erlcmdBuf[sizeof(uint32_t)] = ERLCMD_EVENT_LOG;
	erlcmdBuf[sizeof(uint32_t) + 1] = level;
	memcpy(&erlcmdBuf[sizeof(uint32_t) + 2], msg, msglen);
	erlcmd_send(erlcmdBuf, msglen + sizeof(uint8_t) + sizeof(uint8_t) + sizeof(uint32_t));
	free(erlcmdBuf);
}

void rgb_cb(freenect_device *dev, void *rgb, uint32_t timestamp)
{
	// swap buffers
	assert (rgb_back == rgb);
	rgb_back = rgb_mid;
	freenect_set_video_buffer(dev, rgb_back);
	rgb_mid = (uint8_t*)rgb;
	// if(buffer_rgb_subscribe)
		// dispatch_rgb(rgb_mid);
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
	// if(buffer_depth_subscribe)
		// dispatch_rgb(depth_mid);
}

static void handle_from_elixir(const uint8_t *buffer, size_t length, void *cookie)
{
	uint8_t opcode = buffer[sizeof(uint32_t)];
	switch (opcode)
	{
	case ERLCMD_GET_BUFFER_RGB:
		// debug("Dispatching RGB Buffer\r\n");
		dispatch_rgb(rgb_mid);
		break;

	case ERLCMD_GET_BUFFER_DEPTH:
		// debug("Dispatching Depth Buffer\r\n");
		dispatch_depth(depth_back);
		break;

	case ERLCMD_GET_BUFFER_RGB_JPEG:
		debug("Dispatching RGB Buffer as jpeg\r\n");
		dispatch_rgb_jpeg(rgb_mid);
		break;

	case ERLCMD_GET_BUFFER_DEPTH_JPEG:
		debug("Dispatching DEPTH Buffer as jpeg\r\n");
		dispatch_depth_jpeg(depth_mid);
		break;

	case ERLCMD_GET_LED_STATE:
		debug("Dispatching LED state\r\n");
		dispatch_led_state(freenect_led);
		break;

	case ERLCMD_GET_TILT_STATE:
		debug("Dispatching Tilt state\r\n");
		dispatch_tilt_state(freenect_get_tilt_state(f_dev));
		break;

	case ERLCMD_SET_LED_STATE:
		debug("Setting LED state\r\n");
		freenect_led = buffer[sizeof(uint32_t) + 1];
		freenect_set_led(f_dev, freenect_led);
		dispatch_led_state(freenect_led);
		break;

	case ERLCMD_SET_TILT_STATE:
		debug("Setting Tilt state\r\n");
		freenect_set_tilt_degs(f_dev, buffer[sizeof(uint32_t) + 1]);
		dispatch_tilt_state(freenect_get_tilt_state(f_dev));
		break;

	case ERLCMD_SET_VIDEO_FORMAT:
		debug("Setting Video Format\r\n");
		requested_video_format = buffer[sizeof(uint32_t) + 1];
		break;

	case ERLCMD_SET_DEPTH_FORMAT:
		debug("Setting Depth Format\r\n");
		requested_depth_format = buffer[sizeof(uint32_t) + 1];
		break;

	case ERLCMD_SUBSCRIBE_BUFFER_RGB:
		debug("Subscribe RGB\r\n");
		buffer_rgb_subscribe = !buffer_rgb_subscribe;
		break;

	case ERLCMD_SUBSCRIBE_BUFFER_DEPTH:
		debug("Subscribe Depth\r\n");
		buffer_depth_subscribe = !buffer_depth_subscribe;
		break;

	default:
		debug("unhandled payload[%lu] from Elixir: \r\n", length);
		for (int i = 0; i < length; i++)
			debug("%lu ", buffer[i + sizeof(uint32_t)]);
		debug("\r\n");
		break;
	}
}

bool isCallerDown()
{
	struct pollfd ufd;
	memset(&ufd, 0, sizeof ufd);
	ufd.fd = ERLCMD_READ_FD;
	ufd.events = POLLIN;
	if (poll(&ufd, 1, 0) < 0)
		return true;
	return ufd.revents & POLLHUP;
}

int main(int argc, char **argv)
{
	int res;
	res = tj_init();
	if (res < 0)
	{
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

	if (freenect_init(&f_ctx, NULL) < 0)
	{
		debug("freenect_init() failed\n");
		return 1;
	}

	// Setup logging
	freenect_set_log_level(f_ctx, FREENECT_LOG_DEBUG);
	freenect_set_log_callback(f_ctx, log_cb);
	freenect_select_subdevices(f_ctx, (freenect_device_flags)(FREENECT_DEVICE_MOTOR | FREENECT_DEVICE_CAMERA));

	size_t nr_devices = freenect_num_devices(f_ctx);
	printf("Number of devices found: %d\n", nr_devices);

	if (nr_devices < 1)
	{
		freenect_shutdown(f_ctx);
		return 1;
	}

	if (freenect_open_device(f_ctx, &f_dev, 0) < 0)
	{
		debug("Could not open device\n");
		freenect_shutdown(f_ctx);
		return 1;
	}

	// Reset tild and LED to a "known" state
	freenect_set_tilt_degs(f_dev, freenect_angle);
	freenect_set_led(f_dev, freenect_led);

	video_mode = freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, current_video_format);
	depth_mode = freenect_find_depth_mode(FREENECT_RESOLUTION_MEDIUM, current_depth_format);

	// Setup buffers
	rgb_back = (uint8_t*)malloc(video_mode.bytes);
	rgb_mid = (uint8_t*)malloc(video_mode.bytes);

	depth_back = (uint8_t*)malloc(depth_mode.bytes);
	depth_mid = (uint8_t*)malloc(depth_mode.bytes);

	for (size_t i=0; i<2048; i++) {
		float v = i/2048.0;
		v = powf(v, 3)* 6;
		t_gamma[i] = v*6*256;
	}

	// Setup RGB camera
	freenect_set_video_callback(f_dev, rgb_cb);
	freenect_set_video_mode(f_dev, video_mode);
	freenect_set_video_buffer(f_dev, rgb_back);
	freenect_start_video(f_dev);

	// Setup Depth camera
	freenect_set_depth_callback(f_dev, depth_cb);
	freenect_set_depth_mode(f_dev, depth_mode);
	freenect_set_depth_buffer(f_dev, depth_back);
	freenect_start_depth(f_dev);

	size_t accelCount = 0;
	while (!isCallerDown() && freenect_process_events(f_ctx) >= 0)
	{
		for (size_t i = 0; i < num_pollfds; i++)
			fdset[i].revents = 0;

		size_t rc = poll(fdset, num_pollfds, 0);
		if (rc < 0)
		{
			// Retry if EINTR
			if (errno == EINTR)
				continue;
			error("poll failed with %d", errno);
		}

		// Process messages from Elixir
		if (fdset[0].revents & (POLLIN | POLLHUP))
			erlcmd_process(&handler);

		// CHange RGB camera format if necessary
		if (requested_video_format != current_video_format)
		{
			debug("Changing Requested video format\r\n");
			freenect_stop_video(f_dev);
			video_mode = freenect_find_video_mode(FREENECT_RESOLUTION_MEDIUM, requested_video_format);
			free(rgb_back);
			free(rgb_mid);
			rgb_back = (uint8_t*)malloc(video_mode.bytes);
			rgb_mid = (uint8_t*)malloc(video_mode.bytes);
			freenect_set_video_mode(f_dev, video_mode);
			freenect_start_video(f_dev);
			current_video_format = requested_video_format;
		}

		if(requested_depth_format != current_depth_format)
		{
			debug("Changing Requested depth format\r\n");
			freenect_stop_depth(f_dev);
			depth_mode = freenect_find_depth_mode(FREENECT_RESOLUTION_MEDIUM, requested_depth_format);
			free(depth_back);
			free(depth_mid);
			depth_back = (uint8_t*)malloc(depth_mode.bytes);
			depth_mid = (uint8_t*)malloc(depth_mode.bytes);
			freenect_set_depth_mode(f_dev, depth_mode);
			freenect_start_depth(f_dev);
			current_depth_format = requested_depth_format;
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
