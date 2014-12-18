package org.teasdale

import org.springframework.messaging.Message
import org.springframework.messaging.handler.annotation.DestinationVariable
import org.springframework.messaging.handler.annotation.MessageMapping
import org.springframework.messaging.handler.annotation.SendTo
import org.springframework.messaging.simp.SimpMessagingTemplate
import org.springframework.stereotype.Controller

@Controller
class MessagingService {

    ChatterService chatterService
    ArduinoControllerService arduinoControllerService
    SimpMessagingTemplate brokerMessagingTemplate

    /**
     * Register a new chat participant.  This'll create a record for the new
     * chatter in the Chatters table.
     *
     * @param registrationMessage a RegistrationMessage
     */
    @MessageMapping("/register")
    protected void register(RegistrationMessage registrationMessage) {
        try {
            Chatter chatter = chatterService.newChatter(registrationMessage.name, registrationMessage.chatId)
        } catch (Exception exception) {
            System.out.println exception.getMessage()
        }

        if( registrationMessage.chatId == Constants.SERVER_CHAT_ID ) {
            arduinoControllerService.open()
        }

        updateRegistrations()
    }

    /**
     * Unregister an existing chat participant.  This'll delete a chatter's
     * record from the Chatters table.
     *
     * @param unregistrationMessage a RegistrationMessage
     */
    @MessageMapping("/unregister")
    protected void unregister(RegistrationMessage unregistrationMessage) {
        try {
            chatterService.deleteChatter(unregistrationMessage.chatId)
        } catch (Exception exception) {
            System.out.println exception.getMessage()
        }

        if( unregistrationMessage.chatId == Constants.SERVER_CHAT_ID ) {
            arduinoControllerService.close()
        }

        updateRegistrations()
    }

    /**
     * Broadcast a list of all chat participants
     */
    private void updateRegistrations() {
        Collection<Chatter> chatters = chatterService.getAllChatters()

        if(chatters.size() > 0) {
            def payload = [
                    chatters: chatters.collect { [name: it.name, chatId: it.chatId] }
            ]
            String destination = "/topic/registrations"

            brokerMessagingTemplate.convertAndSend destination, payload
        }
    }

    /**
     * Forward a WebRtc message to a particular chatter.
     * @param chatterId The ID of the message's intended recipient
     * @param message The message to forward to the intended recipient
     */
    @MessageMapping("/rtcMessage/{chatterId}")
    protected void rtcMessage(@DestinationVariable String chatterId, Message message) {
        String destination = "/topic/rtcMessage/$chatterId"
        brokerMessagingTemplate.send destination, message
    }

    /*********************************************************************************************/

    /**
     * Set the position of Servo 01
     * @param position the desired position of Servo 01
     */
    @MessageMapping("/servo01")
    protected void setServo01(String position) {
        arduinoControllerService.updateServo1( Integer.parseInt(position) )
    }

    /**
     * Set the position of Servo 02
     * @param position the desired position of Servo 02
     */
    @MessageMapping("/servo02")
    protected void setServo02(String position) {
        arduinoControllerService.updateServo2( Integer.parseInt(position) )
    }
}
