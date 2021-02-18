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

alignas(16) u8 __nx_exception_stack[0x1000];
u64 __nx_exception_stack_size = sizeof(__nx_exception_stack);
extern struct my_conn mco;

void __libnx_exception_handler(ThreadExceptionDump *ctx)
{
    int i;
    FILE *f = fopen("exception_dump", "w");
    if(f==NULL)return;

    fprintf(f, "error_desc: 0x%x\n", ctx->error_desc);//You can also parse this with ThreadExceptionDesc.
    //This assumes AArch64, however you can also use threadExceptionIsAArch64().
    for(i=0; i<29; i++)fprintf(f, "[X%d]: 0x%lx\n", i, ctx->cpu_gprs[i].x);
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

int main(int argc, const char **argv)
{
    consoleInit(NULL);
    pthread_t websocket_thread;

    // Configure our supported input layout: a single player with standard controller styles
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);

    // Initialize the default gamepad (which reads handheld mode inputs as well as the first connected controller)
    PadState pad;
    padInitializeDefault(&pad);

    // Initialise sockets
    socketInitializeDefault();

    printf("Hello World!\n");

    // Display arguments sent from nxlink
    printf("%d arguments\n", argc);

    for (int i = 0; i < argc; i++)
    {
        printf("argv[%d] = %s\n", i, argv[i]);
    }

    // the host ip where nxlink was launched
    printf("nxlink host is %s\n", inet_ntoa(__nxlink_host));

    // redirect stdout & stderr over network to nxlink
    nxlinkStdio();

    // this text should display on nxlink host
    printf("printf output now goes to nxlink server\n");
    pthread_create(&websocket_thread, NULL, websocket_process, &mco);

    // Main loop
    while (appletMainLoop())
    {
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

    socketExit();
    consoleExit(NULL);
    return 0;
}
