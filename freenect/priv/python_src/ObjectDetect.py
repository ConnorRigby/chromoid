#!/usr/bin/env python3
import os

import numpy
import numpy as np
import cv2
from PIL import Image
import erlang

import ErlCmd

face_cascade = cv2.CascadeClassifier("/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml")

def detectObjects(img):
  # gray_img = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
  gray_img = img
  faces = face_cascade.detectMultiScale(gray_img)
  # print(faces)
  # draw rectangle around the cars
  for (x,y,w,h) in faces:
      cv2.rectangle(img, (x,y), (x+w, y+h), (0,255,0), 2)
      cv2.putText(img, 'face', (x, y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
  cv2.imshow("detected", img)
  cv2.waitKey(1)
  return img

if __name__ == '__main__':
    input, output = os.fdopen(3, 'rb'), os.fdopen(4, 'wb')
    for data in ErlCmd.recv_loop(input):
      if data[0] == ErlCmd.ATOM_BUFFER_BOTH:
        # image = Image.frombuffer("RGB", (640, 480), data[1].value, 'raw', "RGB", 0, 1)
        # image = Image.frombuffer("L", (640, 480), data[1].value, 'raw', "L", 0, 1)
        image = Image.frombuffer("L", (640, 480), data[2].value, 'raw', "L", 0, 1)

        image = np.array(image)
        image = detectObjects(image)
        # _, image = cv2.imencode('.jpeg', image)
        # print(image)
        term = erlang.OtpErlangAtom(b'test')
        # term = erlang.OtpErlangBinary(image.tobytes())
        ErlCmd.send(term, output)

