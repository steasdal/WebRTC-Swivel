package org.teasdale

class PortalController {

    ArduinoControllerService arduinoControllerService

    def index() {
        // If the incoming connection is from localhost, we'll consider
        // this the "server" connection - the page that'll be the portal.
        // All other (external) connections will be considered clients.
        if( ["127.0.0.1", "0:0:0:0:0:0:0:1"].contains(request.remoteAddr)) {
            render(view: "/org/teasdale/Portal/server_landing")
        } else
        {
            render(view: "/org/teasdale/Portal/client_landing", model: [chatId:UUID.randomUUID().toString()])
        }
    }

    def server() {
        render(view: "/org/teasdale/Portal/server", model: [chatId:Constants.SERVER_CHAT_ID])
    }

    def client() {
        render(view: "/org/teasdale/Portal/client", model: [name:params.name, chatId:params.chatId, serverId:Constants.SERVER_CHAT_ID])
    }
}
