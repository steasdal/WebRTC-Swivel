Grails Websocket WebRTC Arduino Video Portal
============================================
A Grails remote control video portal with pan/tilt capabilities.

Requirements
------------
*  [Grails 2.4.4](https://grails.org)
*  [Arduino 1.0.6 (for the USB driver)](http://arduino.cc/en/Main/Software)
*  [Arduino Uno](http://www.adafruit.com/products/50)
*  [Adafruit Servo Shield](http://www.adafruit.com/products/1411)
*  [Robot Geek Pan/Tilt Kit](http://www.trossenrobotics.com/robotgeek-pantilt.aspx)

Optional
--------
*   Custom 3d printed base (see **Base Plate.stl** in the /parts folder)
*   [Bluefruit EZ-Link Shield](http://www.adafruit.com/products/1628) or [Bluefruit EZ-Link Bluetooth Link & Arduino Programmer](http://www.adafruit.com/products/1588)

Configuration
-------------
Modify the **grails-app/conf/ArduinoSerialConfig.txt** file and set **serial.portname** to the name of your Arduino's COM port.

Usage
-----
Simply run **grails run-app** or, better yet, **grails run-app -https** and navigate the the resulting URL.