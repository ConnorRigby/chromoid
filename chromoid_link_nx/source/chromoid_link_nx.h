#ifndef CHROMOID_LINK_NX_H
#define CHROMOID_LINK_NX_H

#include <libwebsockets.h>

void websocket_interrupt();

void websocket_init(lws_sorted_usec_list_t*);
int websocket_handle(struct lws*, enum lws_callback_reasons, void*, void*, size_t);
void websocket_handle_receive(struct lws* wsi, struct my_conn* mco, char* data, size_t len);
void* websocket_process(void* user);

#endif