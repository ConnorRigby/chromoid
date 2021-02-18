#include <stdbool.h>

#include <libwebsockets.h>
#include <json-c/json.h>

#include "chromoid_link_nx.h"

#define CHROMOID_HOSTNAME "192.168.1.123"
#define CHROMOID_PATH "/console_socket/websocket"
#define CHROMOID_PORT 4000
#define CHROMOID_LINK_PROTOCOL_NAME "chromoid-link-client"

/*
 * This represents your object that "contains" the client connection and has
 * the client connection bound to it
 */
struct my_conn
{
    struct lws_context* context;
    int ssl_connection; 
    lws_sorted_usec_list_t sul; 
    struct lws* wsi;            
    uint16_t retry_count;
    bool interrupted;
    char* socket_buffer;
} mco;

const struct lws_protocols protocols[] = {
    {CHROMOID_LINK_PROTOCOL_NAME, websocket_handle, 0, 0},
    {NULL, NULL, 0, 0}
};

static const uint32_t backoff_ms[] = {1000, 2000, 3000, 4000, 5000};

static const lws_retry_bo_t retry = {
    .retry_ms_table = backoff_ms,
    .retry_ms_table_count = LWS_ARRAY_SIZE(backoff_ms),
    .conceal_count = LWS_ARRAY_SIZE(backoff_ms),

    .secs_since_valid_ping = 3,    /* force PINGs after secs idle */
    .secs_since_valid_hangup = 10, /* hangup after secs idle */

    .jitter_percent = 20,
};

/*
 * Scheduled sul callback that starts the connection attempt
 */
void websocket_init(lws_sorted_usec_list_t* sul)
{
    printf("websocket_init\n");
    struct my_conn* mco = lws_container_of(sul, struct my_conn, sul);
    struct lws_client_connect_info i;

    memset(&i, 0, sizeof(i));
    // ssl_connection |= LCCSCF_SKIP_SERVER_CERT_HOSTNAME_CHECK;
    // ssl_connection |= LCCSCF_ALLOW_EXPIRED;
    // ssl_connection |= LCCSCF_ALLOW_INSECURE;

    i.context = mco->context;
    i.local_protocol_name = CHROMOID_LINK_PROTOCOL_NAME;
    i.address = CHROMOID_HOSTNAME;
    i.port = CHROMOID_PORT;
    i.path = CHROMOID_PATH;
    i.host = i.address;
    i.origin = i.address;
    i.ssl_connection = mco->ssl_connection;
    i.pwsi = &mco->wsi;
    i.retry_and_idle_policy = &retry;
    i.userdata = mco;

    printf("lws_client_connect_via_info\n");
    if (!lws_client_connect_via_info(&i))
        /*
		 * Failed... schedule a retry... we can't use the _retry_wsi()
		 * convenience wrapper api here because no valid wsi at this
		 * point.
		 */
        if (lws_retry_sul_schedule(mco->context, 0, sul, &retry, websocket_init, &mco->retry_count))
        {
            lwsl_err("%s: connection attempts exhausted\n", __func__);
            mco->interrupted = true;
        }
}

int websocket_handle(struct lws* wsi, enum lws_callback_reasons reason, void* user, void* in, size_t len)
{
    struct my_conn* mco = (struct my_conn*)user;

    switch (reason)
    {

    case LWS_CALLBACK_CLIENT_CONNECTION_ERROR:
        lwsl_err("CLIENT_CONNECTION_ERROR: %s\n",
                 in ? (char *)in : "(null)");
        goto do_retry;
        break;

    case LWS_CALLBACK_CLIENT_RECEIVE:
        // lwsl_hexdump_notice(in, len);
        websocket_handle_receive(wsi, mco, (char*)in, len);
        break;

    case LWS_CALLBACK_CLIENT_ESTABLISHED:
        lwsl_user("%s: established\n", __func__);
        printf("connected to websocket!");
        break;

    case LWS_CALLBACK_CLIENT_CLOSED:
        lwsl_err("CLIENT_DISCONNECT: %s\n",
                 in ? (char *)in : "(null)");
        goto do_retry;

    default:
        break;
    }

    return lws_callback_http_dummy(wsi, reason, user, in, len);

do_retry:
    /*
	 * retry the connection to keep it nailed up
	 *
	 * For this example, we try to conceal any problem for one set of
	 * backoff retries and then exit the app.
	 *
	 * If you set retry.conceal_count to be larger than the number of
	 * elements in the backoff table, it will never give up and keep
	 * retrying at the last backoff delay plus the random jitter amount.
	 */
    if (lws_retry_sul_schedule_retry_wsi(wsi, &mco->sul, websocket_init, &mco->retry_count))
    {
        lwsl_err("%s: connection attempts exhausted\n", __func__);
        mco->interrupted = 1;
    }

    return 0;
}

void websocket_handle_receive(struct lws* wsi, struct my_conn* mco, char* data, size_t len)
{
    json_object* payload = json_tokener_parse(data);
    printf("%s", json_object_to_json_string_ext(payload, JSON_C_TO_STRING_SPACED | JSON_C_TO_STRING_PRETTY));
}

void* websocket_process(void* user)
{
    struct my_conn* mco = (struct my_conn*)user;
    struct lws_context_creation_info info;
    int n;
    memset(&info, 0, sizeof info);

    lwsl_user("Chromoid Link NX socket setup\n");
    info.options = LWS_SERVER_OPTION_DO_SSL_GLOBAL_INIT;
    info.port = CONTEXT_PORT_NO_LISTEN; /* we do not run any server */
    info.protocols = protocols;
    mco->context = lws_create_context(&info);
    if (!mco->context)
    {
        lwsl_err("lws init failed\n");
        return NULL;
    }
    lwsl_user("lws_create_context\r\n");

    /* schedule the first client connection attempt to happen immediately */
    lws_sul_schedule(mco->context, 0, &mco->sul, websocket_init, 1);
    while((n >= 0) && !mco->interrupted) {
        n = lws_service(mco->context, 0);
    }
    lws_context_destroy(mco->context);
    lwsl_user("Completed\n");
    return NULL;
}

void websocket_interrupt()
{
  mco.interrupted = true;
}