#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>

#include <erl_nif.h>
#include <nfc/nfc.h>

#include "nfc-utils.h"

#define DEBUG

#ifdef DEBUG
#define log_location stderr
//#define LOG_PATH "/tmp/circuits_gpio.log"
#define debug(...) do { enif_fprintf(log_location, __VA_ARGS__); enif_fprintf(log_location, "\r\n"); fflush(log_location); } while(0)
#define error(...) do { debug(__VA_ARGS__); } while (0)
#define start_timing() ErlNifTime __start = enif_monotonic_time(ERL_NIF_USEC)
#define elapsed_microseconds() (enif_monotonic_time(ERL_NIF_USEC) - __start)
#else
#define debug(...)
#define error(...) do { enif_fprintf(stderr, __VA_ARGS__); enif_fprintf(stderr, "\n"); } while(0)
#define start_timing()
#define elapsed_microseconds() 0
#endif

struct nfc_priv {
    ERL_NIF_TERM atom_ok;
    ErlNifResourceType *nfc_rt;
};

struct nfc_state {
    nfc_device *pnd;
    nfc_context *context;
    uint8_t uiPollNr;
    uint8_t uiPeriod;
    size_t szModulations;
    nfc_modulation* nmModulations;
    nfc_target nt;
    ErlNifTid poller_tid;
    ErlNifPid pid;
    bool thread_running;
};

static void nfc_rt_dtor(ErlNifEnv *env, void *obj)
{
    struct nfc_priv *priv = enif_priv_data(env);
    (void) priv;
    struct nfc_state *state = (struct nfc_state*) obj;
    state->thread_running = false;
    if (state->pnd != NULL) {
      nfc_abort_command(state->pnd);
    }

    debug("joining thread");
    enif_thread_join(state->poller_tid, NULL);
    debug("joined thread");


    debug("closing pnd");
    // nfc_close(state->pnd);
    debug("closed");
    debug("exit");
    // nfc_exit(state->context);
    debug("exited");
    debug("nfc_rt_dtor called");
}

static void nfc_rt_stop(ErlNifEnv *env, void *obj, int fd, int is_direct_call)
{
    (void) env;
    (void) obj;
    (void) fd;
    (void) is_direct_call;
#ifdef DEBUG
    debug("nfc_rt_stop called %s", (is_direct_call ? "DIRECT" : "LATER"));
#endif
}

static void nfc_rt_down(ErlNifEnv *env, void *obj, ErlNifPid *pid, ErlNifMonitor *monitor)
{
    (void) env;
    (void) obj;
    (void) pid;
    (void) monitor;
#ifdef DEBUG
    debug("nfc_rt_down called");
#endif
}

static ErlNifResourceTypeInit nfc_rt_init = {nfc_rt_dtor, nfc_rt_stop, nfc_rt_down};

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM info)
{
    (void) info;
    debug("load");

    struct nfc_priv *priv = enif_alloc(sizeof(struct nfc_priv));
    if (!priv) {
        error("Can't allocate nfc_priv");
        return 1;
    }

    priv->atom_ok = enif_make_atom(env, "ok");

    priv->nfc_rt = enif_open_resource_type_x(env, "nfc", &nfc_rt_init, ERL_NIF_RT_CREATE, NULL);

    *priv_data = (void *) priv;
    return 0;
}

static void unload(ErlNifEnv *env, void *priv_data)
{
    (void) env;

    struct nfc_priv *priv = priv_data;
    (void) priv;
    debug("unload");
}

static int map_put(ErlNifEnv *env, ERL_NIF_TERM *map, const char* key, ERL_NIF_TERM value)
{
  return enif_make_map_put(env, *map, enif_make_atom(env, key), value, map);
}

void send_iso14443a(ErlNifEnv *env, ErlNifPid* pid, nfc_iso14443a_info* info)
{
  if(info == NULL) {
    error("info == NULL");
    return;
  }

  ErlNifBinary abtAtqa_bin;
  ErlNifBinary abtUid_bin;
  ErlNifBinary abtAts_bin;

  ERL_NIF_TERM abtAtq;
  ERL_NIF_TERM abtUid;
  ERL_NIF_TERM abtAts;
  ERL_NIF_TERM btSak;
  ERL_NIF_TERM type;
  ERL_NIF_TERM module;
  ERL_NIF_TERM payload;
  ERL_NIF_TERM msg;

  // abtAtqa
  if(enif_alloc_binary(2, &abtAtqa_bin) < 0) {
    error("send_iso14443a enif_alloc_binary abtAtqa");
    return;
  }
  memset(abtAtqa_bin.data, 0, 2);
  memcpy(abtAtqa_bin.data, info->abtAtqa, 2);
  abtAtq = enif_make_binary(env, &abtAtqa_bin);
  // abtAtqa

  // btSak
  btSak = enif_make_int(env, info->btSak);
  // btSak

  // abtUid
  if(enif_alloc_binary(info->szUidLen, &abtUid_bin) < 0) {
    error("send_iso14443a enif_alloc_binary abtUid");
    return;
  }

  memset(abtUid_bin.data, 0, info->szUidLen);
  memcpy(abtUid_bin.data, info->abtUid, info->szUidLen);
  abtUid = enif_make_binary(env, &abtUid_bin);

  // abtUid

  // abtAts
  if(enif_alloc_binary(info->szAtsLen, &abtAts_bin) < 0) {
    error("send_iso14443a enif_alloc_binary abtAtqa");
    return;
  }
  memset(abtAts_bin.data, 0, info->szAtsLen);
  memcpy(abtAts_bin.data, info->abtAts, info->szAtsLen);
  abtAts = enif_make_binary(env, &abtAts_bin);
  // abtAts

  module = enif_make_atom(env, "Elixir.NFC.ISO14443a");
  type = enif_make_atom(env, "iso14443a");
  payload = enif_make_new_map(env);
  map_put(env, &payload, "__struct__", module);
  map_put(env, &payload, "abtAtq", abtAtq);
  map_put(env, &payload, "abtUid", abtUid);
  map_put(env, &payload, "abtAts", abtAts);
  map_put(env, &payload, "btSak", btSak);

  msg = enif_make_tuple(env, 2, type, payload);
  enif_send(env, pid, NULL, msg);
}

void *nfc_rt_poller_thread(void *arg)
{
  int res = 0;
  struct nfc_state *state = arg;
  ErlNifEnv *env = enif_alloc_env();
  while(state->thread_running == true)
  {
    debug("polling");
    // debug("NFC device will poll during %ld ms (%u pollings of %lu ms for %" PRIdPTR " modulations)\n", (unsigned long) state->uiPollNr * state->szModulations * state->uiPeriod * 150, state->uiPollNr, (unsigned long) state->uiPeriod * 150, state->szModulations);
    res = nfc_initiator_poll_target(state->pnd,
                                    state->nmModulations,
                                    state->szModulations,
                                    state->uiPollNr,
                                    state->uiPeriod,
                                    &state->nt);
    if (res < 0) {
      nfc_perror(state->pnd, "nfc_initiator_poll_target");
      nfc_close(state->pnd);
      nfc_exit(state->context);
      break;
    }

    if (res > 0) {
      char *s;
      str_nfc_target(&s, &state->nt, false);
      debug("%s", s);
      nfc_free(s);

      switch(state->nt.nm.nmt) {
        case(NMT_ISO14443A):
          send_iso14443a(env, &state->pid, &state->nt.nti.nai);
        break;
        case(NMT_ISO14443B):
          enif_send(env, &state->pid, NULL, enif_make_atom(env, "NMT_ISO14443B"));
        break;
        break;
        case(NMT_FELICA):
          enif_send(env, &state->pid, NULL, enif_make_atom(env, "NMT_FELICA"));
        break;
        case(NMT_JEWEL):
          enif_send(env, &state->pid, NULL, enif_make_atom(env, "NMT_JEWEL"));
        break;
        case(NMT_ISO14443BICLASS):
          enif_send(env, &state->pid, NULL, enif_make_atom(env, "NMT_ISO14443BICLASS"));
        break;
        default:
          error("Unknown nmt");
      }
      debug("Waiting for card removing...");
      while (0 == nfc_initiator_target_is_present(state->pnd, NULL)) {}
      // nfc_perror(state->pnd, "nfc_initiator_target_is_present");
    } else {
      debug("No target found.\n");
    }
  }
  debug("Thread stopped!");
  return NULL;
}

static ERL_NIF_TERM open_nfc_rt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  struct nfc_priv *priv = enif_priv_data(env);


  struct nfc_state *state = enif_alloc_resource(priv->nfc_rt, sizeof(struct nfc_state));

  if(!enif_get_local_pid(env, argv[0], &state->pid))
    return enif_make_badarg(env);

  state->uiPollNr = 20;
  state->uiPeriod = 2;
  state->szModulations = 6;

  state->nmModulations = malloc(sizeof(nfc_modulation) * state->szModulations);
  if(state->nmModulations == NULL)
    return enif_make_badarg(env);

  state->nmModulations[0] = (nfc_modulation) { .nmt = NMT_ISO14443A, .nbr = NBR_106 };
  state->nmModulations[1] = (nfc_modulation) { .nmt = NMT_ISO14443B, .nbr = NBR_106 };
  state->nmModulations[2] = (nfc_modulation) { .nmt = NMT_FELICA, .nbr = NBR_212 };
  state->nmModulations[3] = (nfc_modulation) { .nmt = NMT_FELICA, .nbr = NBR_424 };
  state->nmModulations[4] = (nfc_modulation) { .nmt = NMT_JEWEL, .nbr = NBR_106 };
  state->nmModulations[5] = (nfc_modulation) { .nmt = NMT_ISO14443BICLASS, .nbr = NBR_106 };
  state->pnd = NULL;
  state->thread_running = true;

  nfc_init(&state->context);
  if (state->context == NULL) {
    error("Failed to init libnfc");
    return enif_make_badarg(env);
  }

  state->pnd = nfc_open(state->context, NULL);

  if (state->pnd == NULL) {
    error("Unable to open NFC device.");
    nfc_exit(state->context);
    return enif_make_badarg(env);
  }

  if (nfc_initiator_init(state->pnd) < 0) {
    nfc_perror(state->pnd, "nfc_initiator_init");
    nfc_close(state->pnd);
    nfc_exit(state->context);
    return enif_make_badarg(env);
  }
  debug("NFC reader: %s opened\n", nfc_device_get_name(state->pnd));

  if (enif_thread_create("nfc_poller", &state->poller_tid, nfc_rt_poller_thread, state, NULL) != 0) {
    error("enif_thread_create failed");
    nfc_perror(state->pnd, "enif_thread_create");
    nfc_close(state->pnd);
    nfc_exit(state->context);
    enif_make_badarg(env);
  }

  // Transfer ownership of the resource to Erlang so that it can be garbage collected.
  ERL_NIF_TERM state_resource = enif_make_resource(env, state);
  enif_release_resource(state);
  return enif_make_tuple2(env, priv->atom_ok, state_resource);
}

static ERL_NIF_TERM close_nfc_rt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  struct nfc_priv *priv = enif_priv_data(env);
  return priv->atom_ok;
}

static ErlNifFunc nif_funcs[] = {
    {"open", 1, open_nfc_rt, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"close", 1, close_nfc_rt, 0},
};

ERL_NIF_INIT(Elixir.NFC.Nif, nif_funcs, load, NULL, NULL, unload)

// #include <err.h>
// #include <inttypes.h>
// #include <signal.h>
// #include <stdio.h>
// #include <stddef.h>
// #include <stdlib.h>
// #include <string.h>

// #include <nfc/nfc.h>
// #include <nfc/nfc-types.h>

// #include "nfc-utils.h"

// #define MAX_DEVICE_COUNT 16

// static nfc_device *pnd = NULL;
// static nfc_context *context;

// static void stop_polling(int sig)
// {
//   (void) sig;
//   if (pnd != NULL)
//     nfc_abort_command(pnd);
//   else {
//     nfc_exit(context);
//     exit(EXIT_FAILURE);
//   }
// }

// static void
// print_usage(const char *progname)
// {
//   printf("usage: %s [-v]\n", progname);
//   printf("  -v\t verbose display\n");
// }

// int
// main(int argc, const char *argv[])
// {
//   bool verbose = false;

//   signal(SIGINT, stop_polling);

//   // Display libnfc version
//   const char *acLibnfcVersion = nfc_version();

//   printf("%s uses libnfc %s\n", argv[0], acLibnfcVersion);
//   if (argc != 1) {
//     if ((argc == 2) && (0 == strcmp("-v", argv[1]))) {
//       verbose = true;
//     } else {
//       print_usage(argv[0]);
//       exit(EXIT_FAILURE);
//     }
//   }

//   const uint8_t uiPollNr = 20;
//   const uint8_t uiPeriod = 2;
//   const nfc_modulation nmModulations[6] = {
//     { .nmt = NMT_ISO14443A, .nbr = NBR_106 },
//     { .nmt = NMT_ISO14443B, .nbr = NBR_106 },
//     { .nmt = NMT_FELICA, .nbr = NBR_212 },
//     { .nmt = NMT_FELICA, .nbr = NBR_424 },
//     { .nmt = NMT_JEWEL, .nbr = NBR_106 },
//     { .nmt = NMT_ISO14443BICLASS, .nbr = NBR_106 },
//   };
//   const size_t szModulations = 6;

//   nfc_target nt;
//   int res = 0;

//   nfc_init(&context);
//   if (context == NULL) {
//     ERR("Unable to init libnfc (malloc)");
//     exit(EXIT_FAILURE);
//   }

//   pnd = nfc_open(context, NULL);

//   if (pnd == NULL) {
//     ERR("%s", "Unable to open NFC device.");
//     nfc_exit(context);
//     exit(EXIT_FAILURE);
//   }

//   if (nfc_initiator_init(pnd) < 0) {
//     nfc_perror(pnd, "nfc_initiator_init");
//     nfc_close(pnd);
//     nfc_exit(context);
//     exit(EXIT_FAILURE);
//   }

//   printf("NFC reader: %s opened\n", nfc_device_get_name(pnd));
//   printf("NFC device will poll during %ld ms (%u pollings of %lu ms for %" PRIdPTR " modulations)\n", (unsigned long) uiPollNr * szModulations * uiPeriod * 150, uiPollNr, (unsigned long) uiPeriod * 150, szModulations);
//   if ((res = nfc_initiator_poll_target(pnd, nmModulations, szModulations, uiPollNr, uiPeriod, &nt))  < 0) {
//     nfc_perror(pnd, "nfc_initiator_poll_target");
//     nfc_close(pnd);
//     nfc_exit(context);
//     exit(EXIT_FAILURE);
//   }

//   if (res > 0) {
//     print_nfc_target(&nt, verbose);
//     printf("Waiting for card removing...");
//     fflush(stdout);
//     while (0 == nfc_initiator_target_is_present(pnd, NULL)) {}
//     nfc_perror(pnd, "nfc_initiator_target_is_present");
//     printf("done.\n");
//   } else {
//     printf("No target found.\n");
//   }

//   nfc_close(pnd);
//   nfc_exit(context);
//   exit(EXIT_SUCCESS);
// }
