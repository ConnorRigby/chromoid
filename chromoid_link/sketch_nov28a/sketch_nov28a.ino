#include <Adafruit_NeoPixel.h>
#include <avr/power.h>
#define NUMPIXELS 100

Adafruit_NeoPixel pixels = Adafruit_NeoPixel(NUMPIXELS, 6, NEO_GRB + NEO_KHZ800);


void setup()
{
  initErlcmd();
  pixels.begin();
  pinMode(13, OUTPUT);
  digitalWrite(13, LOW);
}

void loop()
{
  
}

void handlePayload(uint8_t* fromErl, uint16_t msglen)
{
  digitalWrite(13, HIGH);
  delay(100);
  digitalWrite(13, LOW);

  switch(fromErl[0]) {
    case 0x69:
      uint32_t color = pixels.Color(fromErl[2], fromErl[1], fromErl[3]);
      pixels.fill(color, 0, NUMPIXELS);
      pixels.show();
      uint8_t* replyPayload = malloc(2);
      replyPayload[0] = 0x69;
      replyPayload[1] = 0;
      reply(replyPayload, 2);
      free(replyPayload);
      break;
    default:
      digitalWrite(13, HIGH);
      break;
  }
}

//void printf(char *fmt, ...) {
//  va_list va;
//  va_start(va, fmt);
//  uint16_t len = vsnprintf(NULL, 0, fmt, va);
//  char buf[len];
//  vsprintf(buf, fmt, va);
//  reply(buf, len);
//  va_end(va);
//}

/**
 * ErlCmd packet impl Most of this was lifted from Frank Hunleth
 */

#define BUFLEN 0xff
uint8_t buffer[BUFLEN];
uint16_t index = 0;
uint8_t msglen = 0;
uint16_t bytesRead = 0;
uint8_t* payload;

#define htons(x) ( ((x)<< 8 & 0xFF00) | \
                   ((x)>> 8 & 0x00FF) )
#define ntohs(x) htons(x)

#define htonl(x) ( ((x)<<24 & 0xFF000000UL) | \
                   ((x)<< 8 & 0x00FF0000UL) | \
                   ((x)>> 8 & 0x0000FF00UL) | \
                   ((x)>>24 & 0x000000FFUL) )
#define ntohl(x) htonl(x)

void initErlcmd() 
{
  Serial.begin(115200);
  memset(buffer, 0, BUFLEN);
}

void reply(uint8_t* replyPayload, uint16_t msglen) {
  uint8_t* reply = malloc(sizeof(uint16_t) + msglen);
  uint32_t be_len = ntohs(msglen);
  memcpy(reply, &be_len, sizeof(uint16_t));
  memcpy(reply+sizeof(uint16_t), replyPayload, msglen);
  Serial.write(reply, sizeof(uint16_t) + msglen);
  free(reply);
}

void serialEvent()
{
  while (Serial.available()) {
    buffer[index++] = Serial.read();
    bytesRead++;
    if(bytesRead == sizeof(uint16_t)) {
      uint16_t be_len;
      memcpy(&be_len, buffer, sizeof(uint16_t));
      msglen = ntohs(be_len);
    }

    if(bytesRead > sizeof(uint16_t) && bytesRead-sizeof(uint16_t) == msglen) {
      payload = malloc(msglen);
      memcpy(payload, &buffer[sizeof(uint16_t)], msglen);
      handlePayload(payload, msglen);
      free(payload);
      index = 0;
      bytesRead = 0;
      memset(buffer, 0, BUFLEN);
    }
  }
}
