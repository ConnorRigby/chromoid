/*
#  Created by Boyd Multerer on June 6, 2018.
#  Copyright © 2018 Kry10 Industries. All rights reserved.
#

Functions to load textures onto the graphics card
*/

#include <stdlib.h>

#include <stdio.h>

// #include <GLFW/glfw3.h>
#include <GLES2/gl2.h>

#include "nanovg.h"
#include "types.h"
#include "comms.h"

#include "uthash.h"

#define MAX_KEY_LENGTH      64

//=============================================================================
// uthash setup

//---------------------------------------------------------
typedef struct
{
  const char*     key;
  int             id;
  UT_hash_handle  hh;
} tx_id_t;

//---------------------------------------------------------
static tx_id_t* put_tx_id(tx_id_t* p_tx_ids, char* p_key, int key_size, int id, int* old_id) {
  tx_id_t *found;

  // check if the key is already assigned.
  HASH_FIND_STR(p_tx_ids, p_key, found);
  if (found) {
    // pass out the old id.
    *old_id = found->id;
    // store the new id in the existing record
    found->id = id;
    // return
    return p_tx_ids;
  }

  // prepare a new id record
  unsigned int size = sizeof(tx_id_t) + key_size;
  tx_id_t* p_tx_id = (tx_id_t*)malloc(size);
  memset(p_tx_id, 0, size );
  p_tx_id->id = id;
  p_tx_id->key = (char*)p_tx_id + sizeof(tx_id_t);
  memcpy((char*)p_tx_id->key, p_key, key_size);

  HASH_ADD_KEYPTR( hh, p_tx_ids, p_tx_id->key, strlen(p_tx_id->key), p_tx_id );

  return p_tx_ids;
}

//---------------------------------------------------------
int get_tx_id(void* p_tx_ids, char* p_key) {
  if (p_tx_ids == NULL) {return -1;}
  tx_id_t* found;
  HASH_FIND_STR( (tx_id_t*)p_tx_ids, p_key, found );
  if (found) return found->id;
  return -1;
}

//---------------------------------------------------------
// removes from the hash by id, and frees the pointer
static tx_id_t* delete_tx_id(tx_id_t* p_tx_ids, char* p_key) {
  if (p_tx_ids == NULL) {return NULL;}

  tx_id_t* found;
  HASH_FIND_STR( p_tx_ids, p_key, found );
  if (found != NULL) {
    HASH_DEL( p_tx_ids, found );
    free( found );
  }
  return p_tx_ids;
}

//=============================================================================

//---------------------------------------------------------
void receive_put_tx_blob( driver_data_t* p_data, char* payload, size_t len ) {
  NVGcontext* p_ctx = p_data->p_ctx;

  // read in the data from the stream
  GLuint key_size;
  GLuint file_size;
  // read_bytes_down( &key_size, sizeof(GLuint), p_msg_length);
  memcpy(&key_size, payload, sizeof(GLuint));
  len-=sizeof(GLuint);
  payload+=sizeof(GLuint);

  // read_bytes_down( &file_size, sizeof(GLuint), p_msg_length);
  memcpy(&file_size, payload, sizeof(GLuint));
  len-=sizeof(GLuint);
  payload+=sizeof(GLuint);

  // Allocate and read the key. Need to free from now on
  char* p_key = (char*)malloc(key_size);
  // read_bytes_down( p_key, key_size, p_msg_length);
  memcpy(p_key, payload, key_size);
  len-=key_size;
  payload+=key_size;

  // Allocate and read the main data. Need to free from now on
  void* p_tx_file = malloc(file_size);
  // read_bytes_down( p_tx_file, file_size, p_msg_length);
  memcpy(p_tx_file, payload, file_size);
  len-=file_size;
  payload+=file_size;


  // load the texture
  int id = nvgCreateImageMem(p_ctx, NVG_IMAGE_GENERATE_MIPMAPS, (unsigned char*)p_tx_file, file_size);

  // store the key/id pair
  int old_id;
  p_data->p_tx_ids = put_tx_id( (tx_id_t *)p_data->p_tx_ids, p_key, key_size, id, &old_id );

  free(p_key);
  free(p_tx_file);
}

//---------------------------------------------------------
typedef struct __attribute__((__packed__))
{
  GLuint key_size;
  GLuint pixel_size;
  GLuint depth;
  GLuint width;
  GLuint height;
} tx_pixels_t;

void receive_put_tx_pixels(driver_data_t* p_data, char* payload, size_t len)
{
  NVGcontext* p_ctx = p_data->p_ctx;

  // read in the data from the stream
  tx_pixels_t header;
  // read_bytes_down(&header, sizeof(tx_pixels_t), p_msg_length);
  memcpy(&header, payload, sizeof(tx_pixels_t));
  len-=sizeof(tx_pixels_t);
  payload+=sizeof(tx_pixels_t);

  GLuint pixel_count = header.width * header.height;

  // Allocate and read the key. Need to free from now on
  char* p_key = (char*)malloc(header.key_size);
  // read_bytes_down(p_key, header.key_size, p_msg_length);
  memcpy(p_key, payload, header.key_size);
  len-=header.key_size;
  payload+=header.key_size;

  // Allocate and read the main data. Need to free from now on
  unsigned char* p_tx_pixels = (unsigned char*)malloc(header.pixel_size);
  // read_bytes_down(p_tx_pixels, header.pixel_size, p_msg_length);
  memcpy(p_tx_pixels, payload, header.pixel_size);
  len-=header.pixel_size;
  payload+=header.pixel_size;

  // expand the texture as appropriate depending on the depth
  GLuint src_i;
  GLuint dst_i;
  unsigned char* p_tx_source = p_tx_pixels;
  switch (header.depth)
  {
    case 4: // already good
      break;
    case 3:
      p_tx_pixels = (unsigned char*)malloc(pixel_count * 4);
      for( unsigned int i = 0; i < pixel_count; i++ ) {
        dst_i = i * 4;
        src_i = i * 3;
        p_tx_pixels[dst_i] = p_tx_source[src_i];
        p_tx_pixels[dst_i + 1] = p_tx_source[src_i + 1];
        p_tx_pixels[dst_i + 2] = p_tx_source[src_i + 2];
        p_tx_pixels[dst_i + 3] = 0xff;
      }
      free(p_tx_source);
      break;
    case 2:
      p_tx_pixels = (unsigned char*)malloc(pixel_count * 4);
      for( unsigned int i = 0; i < pixel_count; i++ ) {
        dst_i = i * 4;
        src_i = i * 2;
        p_tx_pixels[dst_i] = p_tx_source[src_i];
        p_tx_pixels[dst_i + 1] = p_tx_source[src_i];
        p_tx_pixels[dst_i + 2] = p_tx_source[src_i];
        p_tx_pixels[dst_i + 3] = p_tx_source[src_i + 1];
      }
      free(p_tx_source);
      break;
    case 1:
      p_tx_pixels = (unsigned char*)malloc(pixel_count * 4);
      for( unsigned int i = 0; i < pixel_count; i++ ) {
        dst_i = i * 4;
        p_tx_pixels[dst_i] = p_tx_source[i];
        p_tx_pixels[dst_i + 1] = p_tx_source[i];
        p_tx_pixels[dst_i + 2] = p_tx_source[i];
        p_tx_pixels[dst_i + 3] = 0xff;
      }
      free(p_tx_source);
      break;
  }

  // load the texture
  int id = nvgCreateImageRGBA(p_ctx, header.width, header.height,
    NVG_IMAGE_GENERATE_MIPMAPS, p_tx_pixels);

  // store the key/id pair
  int old_id;
  p_data->p_tx_ids = put_tx_id((tx_id_t *)p_data->p_tx_ids, p_key, header.key_size, id, &old_id);

  free(p_key);
  free(p_tx_pixels);
}

//---------------------------------------------------------
void receive_free_tx_id( driver_data_t* p_data, char* payload, size_t len ) {
  NVGcontext* p_ctx = p_data->p_ctx;

  GLuint key_size;
  // read_bytes_down( &key_size, sizeof(GLuint), p_msg_length);
  memcpy(&key_size, payload, sizeof(GLuint));
  len-=sizeof(GLuint);
  payload+=sizeof(GLuint);

  // Allocate and read the key. Need to free from now on
  char* p_key = (char*)malloc(key_size);
  // read_bytes_down( p_key, key_size, p_msg_length);
  memcpy(p_key, payload, key_size);
  len-=key_size;
  payload+=key_size;

// char buff[200];
// sprintf(buff, "TX delete key: %s", p_key);
// send_puts(buff);

  int id = get_tx_id((tx_id_t *)p_data->p_tx_ids, p_key);
  if (id >= 0) {
    p_data->p_tx_ids = delete_tx_id((tx_id_t *)p_data->p_tx_ids, p_key);
    nvgDeleteImage(p_ctx, id);
  }

  free(p_key);
}