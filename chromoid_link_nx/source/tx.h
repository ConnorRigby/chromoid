/*
#  Created by Boyd Multerer on June 6, 2018.
#  Copyright © 2018 Kry10 Industries. All rights reserved.
#

Functions to load textures onto the graphics card
*/


int get_tx_id(void* p_tx_ids, char* p_key);

void receive_put_tx_blob( driver_data_t* window , char* payload, size_t len);
void receive_put_tx_pixels( driver_data_t* window, char* payload, size_t len);
void receive_free_tx_id( driver_data_t* window , char* payload, size_t len);
