package org.teasdale

import org.teasdale.api.ArduinoSerialConfig
import org.teasdale.api.ArduinoSerialConnection
import org.teasdale.api.ArduinoSerialFactory
import org.teasdale.api.ArduinoSerialListener

class ArduinoControllerService {

    static ArduinoSerialConfig arduinoSerialConfig
    static ArduinoSerialConnection arduinoSerialConnection

    private static void doConfig() {
        if( !arduinoSerialConfig ) {
            // Read the ArduinoSerialConfig.txt file in the /conf directory to an InputStream
            InputStream configStream = Thread.currentThread().contextClassLoader.getResourceAsStream("ArduinoSerialConfig.txt")

            // Pass the InputStream representing the config file to the getArduinoSerialConfig
            // method which will return an ArduinoSerialConfig instance configured according
            // to the config file settings.
            arduinoSerialConfig = ArduinoSerialFactory.getInstance().getArduinoSerialConfig(configStream)

            // Register the embedded SerialListener class to receive incoming serial message strings.
            arduinoSerialConfig.registerListener(new SerialListener())
        }
    }

    private static void doOpen() {
        if( !arduinoSerialConnection ) {
            arduinoSerialConnection = ArduinoSerialFactory.getInstance().getArduinoSerialConnection(arduinoSerialConfig)
            arduinoSerialConnection.open()
        }
    }

    private static void doClose() {
        if( arduinoSerialConnection ) {
            arduinoSerialConnection.close()
            arduinoSerialConnection = null;
        }
    }

    private static void doUpdateCommand(String command, int interval) {
        doConfig()
        doOpen()
        arduinoSerialConnection.updateCommand(command, interval)
    }

    def open() {
        doConfig()
        doOpen()
    }

    def close() {
        doClose()
    }

    def updateBlink(int interval) { doUpdateCommand("BLINK", interval) }
    def updateServo1(int position) { doUpdateCommand("SRV1", position) }
    def updateServo2(int position) { doUpdateCommand("SRV2", position) }

    /* ***************************************************************************************** */

    // This listener will simply print out any serial
    // strings received from the arduino to stdout.
    static private class SerialListener implements ArduinoSerialListener {
        @Override
        void stringReceived(String string) {
            println string
        }
    }
}
