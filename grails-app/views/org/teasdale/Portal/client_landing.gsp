<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>

    <asset:javascript src="jquery" />
    <asset:javascript src="spring-websocket" />
    <asset:stylesheet href="chat.css"/>

    <title>Client Landing Page</title>

    <script type="text/javascript">
        $(function() {
            var socket = new SockJS("${createLink(uri: '/stomp')}");
            var client = Stomp.over(socket);

            var submitButton = $("#submit");
            var statusMessage = $("#statusMessage");
            var statusSubscription;

            client.connect({}, function() {

                // Register for status updates
                statusSubscription = client.subscribe("/topic/status", function(message) {
                    var obj = JSON.parse(message.body);

                    switch(obj.status) {
                        case "no_server":  // The server page hasn't been opened yet
                            submitButton.prop('disabled', true);
                            statusMessage.val("Offline");
                            break;
                        case "busy":       // Some other client is controlling the server portal
                            submitButton.prop('disabled', true);
                            statusMessage.val("Busy");
                            break;
                        case "ready":      // Awww yeah, we're ready to chat!
                            submitButton.prop('disabled', false);
                            statusMessage.val("Ready");
                            break;
                        default:           // Uh... what?  Where'd this come from?
                            console.log("Unexpected status from /topic/status: " + obj.status);
                            break;
                    }
                });

                // Trigger a status update
                client.send("/app/status", {}, "");
            });

            // Exit neatly on window unload
            $(window).on('beforeunload', function(){

                // Unsubscribe from the status channel
                statusSubscription.unsubscribe();

                // Disconnect the websocket connection
                client.disconnect();
            });
        });
    </script>

</head>

<body>
    <g:form name="client" action="client" >
        <g:hiddenField name="chatId" value="${chatId}" />

        <div class="boxed">
            <label for="name">Enter your name: </label>
            <g:textField name="name" required="" />
        </div>

        <div class = "boxed">
            <label for="statusMessage">Host status:</label>
            <input type="text" id="statusMessage" readonly>
        </div>

        <fieldset class="buttons">
            <g:submitButton name="submit" class="submit" value="Connect as Client" disabled="disabled"/>
        </fieldset>
    </g:form>
</body>
</html>