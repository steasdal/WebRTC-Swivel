package org.teasdale

class PortalController {

    ArduinoControllerService arduinoControllerService

    def index() {
        // If the incoming connection is from localhost, we'll consider
        // this the "server" connection - the page that'll be the portal.
        // All other (external) connections will be considered clients.
        if( ["127.0.0.1", "0:0:0:0:0:0:0:1"].contains(request.remoteAddr)) {
            String chatId = Constants.SERVER_CHAT_ID
            render(view: "/org/teasdale/Portal/server_landing", model: [chatId:chatId])
        } else
        {
            String chatId = UUID.randomUUID().toString()
            render(view: "/org/teasdale/Portal/client_landing", model: [chatId:chatId])
        }
    }

    def server() {
        render(view: "/org/teasdale/Portal/server", model: [chatId:params.chatId])
    }

    def client() {
        render(view: "/org/teasdale/Portal/client", model: [name:params.name, chatId:params.chatId, serverId:Constants.SERVER_CHAT_ID])
    }
}
