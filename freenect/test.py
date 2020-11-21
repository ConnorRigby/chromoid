import cv2
from PIL import Image
import numpy as np

with open("test.rgb", mode='rb') as file: # b is important -> binary
    fileContent = file.read()

buffer = np.frombuffer(fileContent)
image = Image.frombuffer("RGB", (640, 480), buffer, 'raw', "RGB", 0, 1) 
print(image)
cv2.imshow('URL2Image',np.array(image))
cv2.waitKey()