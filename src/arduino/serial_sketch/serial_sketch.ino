/****************************************************************************************
 This sketch requires the following two libraries to compile:
 
 Adafruit PWM Servo Driver Library:
 https://github.com/adafruit/Adafruit-PWM-Servo-Driver-Library
 
 Standard C++ for Arduino Library:
 https://github.com/maniacbug/StandardCplusplus
 
 Instructions for installing Arduino libraries can be found here:
 http://arduino.cc/en/Guide/Libraries
 
 This Arduino sketch is designed to work in conjunction with its accompanying
 Java API to provide a relatively robust and easily extensible method for
 sending a stream of commands to an Arduino over a USB serial connection.
 
 Each command will have an initial value and a current value.  If the Arduino
 stops receiving commands after a configurable period of time, all command values
 will be automatically set to their initial values.  The prototypical example
 involves sending commands for controlling the speed of a DC motor (which might
 be used in a remote control vehicle, robot, etc.)  If the the API stops sending
 regular updates, the motor speed should be automatically be set its initial
 value of zero (e.g stop).
 
 ---------------------------------------------------------------------------------------
 
 Adding support for a new command requires following steps:
 
 1) Define a const String command name.  This string will be sent by the accompanying
    API along with a command value.  Don't get too fancy with long, elaborate command
    names; remember that the Arduino serial buffer is, by default, only 64 bytes long.
    
 2) Create an initialization handler function that takes an int value and returns void.  
    The function must have this exact signature [ void function(int) ].  This function
    will be called when the API first connects to the Arduino and will be be passed an 
    int initialization value.
    
 3) Create a command handler function that takes an int value and returns void.  The
    function must have this exact signature [ void function(int) ].  This function will
    be called whenever a new command update is received.
    
 4) Register your init and command handler functions in the registerInitHandlers() and
    registerCommandHandlers() functions below.  Just pass your command name and
    function name to the registerInitHandler() and registerCommandHandler functions
    respectively.
    
 5) Add some kind of command initialization to the initializeCommands() function below.
    The initializeCommands() function is called when the Arduino stops receiving 
    data from the API.  Typically, you'd reset your command value to the initialization
    value passed into your initialization handler function defined in step 2.
    
 6) If you require any kind of setup before the loop starts, put it in a function and
    add that function to the setup() function.
 
 If you're having trouble making sense of these instructions, just take a look at how
 it's been implemented Servo section below.
****************************************************************************************/

#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>

#include <StandardCplusplus.h>
#include <map>

#include "command_handlers.h"
#include "util_functions.h"
#include "serial_handler.h"
#include "update_handler.h"

/*******************************************
 SERVOS - SERVOS - SERVOS - SERVOS - SERVOS
*******************************************/
// called this way, it uses the default address 0x40
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver();

#define PWM_FREQ  65
#define SERVOMIN  150
#define SERVOMAX  600

const String SERVO_01 = "SRV1";
const String SERVO_02 = "SRV2";

const uint8_t SERVO_NUM_01 = 0;
const uint8_t SERVO_NUM_02 = 1;

int servo01Init = 90;
int servo02Init = 90;

void updateServo01Init(int newInitValue) {
  servo01Init = newInitValue;
  sendInitMessage(SERVO_01, newInitValue);
}

void updateServo02Init(int newInitValue) {
  servo02Init = newInitValue;
  sendInitMessage(SERVO_02, newInitValue);
}

void setServo01(int servoValue) {
  double pulselength = map( constrain(servoValue, 0, 180), 0, 180, SERVOMIN, SERVOMAX);
  pwm.setPWM(SERVO_NUM_01, 0, pulselength);
  sendUpdateMessage(SERVO_01, servoValue);
}

void setServo02(int servoValue) {
  double pulselength = map( constrain(servoValue, 0, 180), 0, 180, SERVOMIN, SERVOMAX);
  pwm.setPWM(SERVO_NUM_02, 0, pulselength);
  sendUpdateMessage(SERVO_02, servoValue);
}

void setupServos() {
  pwm.begin();
  pwm.setPWMFreq(PWM_FREQ);
}

/************************************************
 REGISTER INIT HANDLERS - REGISTER INIT HANDLERS
************************************************/
void registerInitHandlers() {
  registerInitHandler(SERVO_01, updateServo01Init);
  registerInitHandler(SERVO_02, updateServo02Init);
}

/******************************************************
 REGISTER COMMAND HANDLERS - REGISTER COMMAND HANDLERS
******************************************************/
void registerCommandHandlers() {
  registerCommandHandler(SERVO_01, setServo01);
  registerCommandHandler(SERVO_02, setServo02);
}

/*********************************************
 REINITIALIZE COMMANDS - REINITIALIZE COMMANDS
**********************************************/
void initializeCommands() {
  setServo01(servo01Init);
  setServo02(servo02Init);
}

/****************************************************************
 SETUP AND MAIN LOOP - SETUP AND MAIN LOOP - SETUP AND MAIN LOOP
****************************************************************/
void setup() {
  setupServos();
  
  registerInitHandlers();
  registerCommandHandlers(); 
  setupUpdateHandler(initializeCommands);
  setupSerialHandler();
  
  Serial.begin(9600);
  
  sendSerialMessage("free SRAM: " + String( freeRam() ));
}

void loop() {
  processSerialData();
  checkForUpdateExpiration();
}

