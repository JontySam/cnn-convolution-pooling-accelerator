#!/usr/bin/python

import sys
import cv2
import numpy as np

img = cv2.imread('lena.jpg',0)

img_pad = np.zeros(shape = (img.shape[0]+2,img.shape[1]+2)) 
# pad image boundry pixels with zero
img_pad[1:img.shape[0]+1, 1:img.shape[1]+1] = img[0:img.shape[0], 0:img.shape[1]]

f1_0 = open('./conv_pool_0.output', 'w')
f1_1 = open('./conv_pool_1.output', 'w')
f1_2 = open('./conv_pool_2.output', 'w')

# different types of kernel
kernel_sharp = np.array([[-1,-1,-1],[-1,9,-1],[-1,-1,-1]])
kernel_edge = np.array([[-1,-1,-1],[-1,8,-1],[-1,-1,-1]])
kernel_blur = np.array([[1/8,1/8,1/8],[1/8,1/8,1/8],[1/8,1/8,1/8]])

# kernel definition
kernel_0 = kernel_sharp
kernel_1 = kernel_edge
kernel_2 = kernel_blur

# 3x3 convolution function definition
def conv_3x3 (img, kernel_0, kernel_1, kernel_2):
  conv_out_0 = 0
  conv_out_1 = 0
  conv_out_2 = 0
  for i in range(3):
    for j in range(3):
      conv_out_0 = conv_out_0 + img[i,j] * kernel_0[i,j]
      conv_out_1 = conv_out_1 + img[i,j] * kernel_1[i,j]
      conv_out_2 = conv_out_2 + img[i,j] * kernel_2[i,j]

  if conv_out_0 < 0 :
    conv_out_0 = 0;
  if conv_out_0 > 255 :
    conv_out_0 = 255;

  if conv_out_1 < 0 :
    conv_out_1 = 0;
  if conv_out_1 > 255 :
    conv_out_1 = 255;

  if conv_out_2 < 0 :
    conv_out_2 = 0;
  if conv_out_2 > 255 :
    conv_out_2 = 255;

  return conv_out_0, conv_out_1, conv_out_2


img_4x4 = np.zeros(shape = (4, 4))
img_conv_0 = np.zeros(shape = (img.shape[0], img.shape[1]))
img_conv_1 = np.zeros(shape = (img.shape[0], img.shape[1]))
img_conv_2 = np.zeros(shape = (img.shape[0], img.shape[1]))

# Iterate through the whole image
for row in range(1, img.shape[0], 2):
  for col in range(1, img.shape[1], 2):
    # obtain 4x4 sub-image from the original image by strides of 2
    img_4x4 = np.array(img_pad[row-1:row+3, col-1:col+3])	

    # generate input data file for Verilog simulation
    for i in range(4):
      for j in range(4):
        sys.stdout.write("%02X" % int(img_4x4[i,j]))
    print ('')

    # Four 3x3 convolution operations
    img_conv_0[row-1, col-1], img_conv_1[row-1, col-1], img_conv_2[row-1, col-1]= conv_3x3(img_4x4[0:3, 0:3], kernel_0, kernel_1, kernel_2)
    img_conv_0[row-1, col  ], img_conv_1[row-1, col  ], img_conv_2[row-1, col  ]= conv_3x3(img_4x4[0:3, 1:4], kernel_0, kernel_1, kernel_2)
    img_conv_0[row,   col-1], img_conv_1[row,   col-1], img_conv_2[row,   col-1]= conv_3x3(img_4x4[1:4, 0:3], kernel_0, kernel_1, kernel_2)
    img_conv_0[row,   col  ], img_conv_1[row,   col  ], img_conv_2[row,   col  ]= conv_3x3(img_4x4[1:4, 1:4], kernel_0, kernel_1, kernel_2)

    # Max-pooling operation
    list = [img_conv_0[row-1, col-1], img_conv_0[row-1, col], img_conv_0[row, col-1], img_conv_0[row, col]]
    max_conv = max(list)
    # generate golden output data file that should match with Verilog simulation output
    print("%X" % int(max_conv), file=f1_0)
    
    # Max-pooling operation
    list = [img_conv_1[row-1, col-1], img_conv_1[row-1, col], img_conv_1[row, col-1], img_conv_1[row, col]]
    max_conv = max(list)
    # generate golden output data file that should match with Verilog simulation output
    print("%X" % int(max_conv), file=f1_1)
    
    # Max-pooling operation
    list = [img_conv_2[row-1, col-1], img_conv_2[row-1, col], img_conv_2[row, col-1], img_conv_2[row, col]]
    max_conv = max(list)
    # generate golden output data file that should match with Verilog simulation output
    print("%X" % int(max_conv), file=f1_2)
    
f1_0.close()
f1_1.close()
f1_2.close()

# read the golden output file or Verilog simulation output file
f2_0 = open('./conv_pool_0.output', 'r')
f2_1 = open('./conv_pool_1.output', 'r')
f2_2 = open('./conv_pool_2.output', 'r')

img_pool = np.zeros(shape = (int(img.shape[0]/2), int(img.shape[1]/2)))

# generate image matrix from file
count = 0
for line in f2_0:
  x = line.rstrip('\n')
  img_pool[int(count / (img.shape[1]/2)), int(count % (img.shape[1]/2))] = int(x,16)
  count = count + 1 

# generate image (visualize convolution output) 
cv2.imwrite('lena_convonly_0.jpg',img_conv_0)

# generate image (visualize convolution + pooling output) 
cv2.imwrite('lena_convpool_0.jpg',img_pool)

# generate image matrix from file
count = 0
for line in f2_1:
  x = line.rstrip('\n')
  img_pool[int(count / (img.shape[1]/2)), int(count % (img.shape[1]/2))] = int(x,16)
  count = count + 1 

# generate image (visualize convolution output) 
cv2.imwrite('lena_convonly_1.jpg',img_conv_1)

# generate image (visualize convolution + pooling output) 
cv2.imwrite('lena_convpool_1.jpg',img_pool)

# generate image matrix from file
count = 0
for line in f2_2:
  x = line.rstrip('\n')
  img_pool[int(count / (img.shape[1]/2)), int(count % (img.shape[1]/2))] = int(x,16)
  count = count + 1 

# generate image (visualize convolution output) 
cv2.imwrite('lena_convonly_2.jpg',img_conv_2)

# generate image (visualize convolution + pooling output) 
cv2.imwrite('lena_convpool_2.jpg',img_pool)

