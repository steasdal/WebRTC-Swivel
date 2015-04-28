<!DOCTYPE html>

<html>
<head>
    <meta name="layout" content="spartan"/>

    <asset:javascript src="jquery" />
    <asset:javascript src="spring-websocket" />
    <asset:javascript src="adapter.js" />
    <asset:javascript src="screensaver.js" />
    <asset:stylesheet href="chat.css"/>

    <script type="text/javascript">
        $(function() {
            var chatId = $("#chatId").val();
            var name = $("#name").val();

            var socket = new SockJS("${createLink(uri: '/stomp')}");
            var client = Stomp.over(socket);

            var rtcMessageSubscription;

            var localVideo = $("#localVideo")[0];
            var remoteVideo = $("#remoteVideo")[0];

            var localStream, remoteStream, rtcPeerConnection;
            var isInitiator = false;
            var isStarted = false;

            var remoteChatter = undefined;
            var remoteChatterName = undefined;

            var rtcConstraints = {video: true, audio:true};

            // We'll use Google's unofficial public STUN server (NO TURN support!)
            var rtcConfiguration = {'iceServers': [{'url': 'stun:stun.l.google.com:19302'}]};

            client.connect({}, function() {

                // Register the existence of this new chat client with the server
                var json = {"name": name, "chatId": chatId};
                client.send("/app/register", {}, JSON.stringify(json));

                // Subscribe to my own private channel for WebRTC messages
                rtcMessageSubscription = client.subscribe("/topic/rtcMessage/" + chatId, function(rawMessage) {
                    var messageBody = JSON.parse(rawMessage.body);

                    switch(messageBody.type) {
                        case "chat-offer":               // A chat offer has been received from some chat participant - prepare to chat!
                            remoteChatter = messageBody.sender;
                            remoteChatterName = messageBody.name;
                            acknowledgeChatInvitation();
                            prepareForVideoChat();
                            startChat();
                            console.log("Remote chatting with " + remoteChatter);
                            break;
                        case "disconnect-offer":         // You've received a disconnect offer from your chat participant - prepare to disconnect
                            acknowledgeChatHangup();
                            endChat();
                            remoteChatter = undefined;
                            remoteChatterName = undefined;
                            cleanupAfterVideoChat();
                            console.log("Disconnecting from chat with " + messageBody.sender);
                            break;
                        case "disconnect-acknowledged":  // You've sent a disconnect offer to your chat participant and received this acknowledgement - disconnect complete
                            endChat();
                            cleanupAfterVideoChat();
                            console.log("Disconnected from chat with " + messageBody.sender);
                            break;
                        case "offer":                    // Your chat partner has sent you an offer (an RTC Session Description)
                            console.log("offer received from " + remoteChatter);
                            rtcPeerConnection.setRemoteDescription(new RTCSessionDescription(messageBody));
                            doAnswer();
                            break;
                        case "answer":                   // Your chat partner has responded to your offer with an answer (also an RTC Session Description)
                            console.log("answer received from " + remoteChatter);
                            rtcPeerConnection.setRemoteDescription(new RTCSessionDescription(messageBody));
                            break;
                        case "candidate":                // Your chat partner has sent you one of presumably many ICE candidates
                            console.log("ice candidate received from " + remoteChatter);
                            var candidate = new RTCIceCandidate({sdpMLineIndex:messageBody.label, candidate:messageBody.candidate});
                            rtcPeerConnection.addIceCandidate(candidate);
                            break;
                        default:
                            console.log("Unknown message type: ", messageBody.type);
                    }
                });

                startLocalVideo();
                enableScreenSaver();
            });

            /*************************************************************************************/

            function sendMessage(message){
                console.log('Sending message to ' + remoteChatter + ': ', message);
                client.send("/app/rtcMessage/" + remoteChatter, {}, JSON.stringify(message));
            }

            function acknowledgeChatInvitation() {
                var json = {type:'chat-acknowledged', sender:chatId};
                sendMessage(json);
            }

            function sendChatHangup() {
                var json = {type:'disconnect-offer', sender:chatId};
                sendMessage(json);
            }

            function acknowledgeChatHangup() {
                var json = {type:'disconnect-acknowledged', sender:chatId};
                sendMessage(json);
            }

            function prepareForVideoChat() {
                $("#chatterName").val("chatting with " + remoteChatterName);
            }

            function cleanupAfterVideoChat() {
                isInitiator = false;
                $("#chatterName").val("");
            }

            /*************************************************************************************/

            function handleUserMedia(stream) {
                localStream = stream;

                console.log(stream.getVideoTracks()[0]);

                attachMediaStream(localVideo, stream);
                console.log('Adding local stream.');
            }

            function handleUserMediaError(error){
                console.log('navigator.getUserMedia error: ', error);
            }

            function startLocalVideo() {
                console.log('Getting user media with rtcConstraints', rtcConstraints);
                getUserMedia(rtcConstraints, handleUserMedia, handleUserMediaError);
            }

            function startChat() {
                if (!isStarted && localStream) {
                    createPeerConnection();
                    rtcPeerConnection.addStream(localStream);
                    isStarted = true;
                    if (isInitiator) {
                        doCall();
                    }

                    disableScreenSaver();
                }
            }

            function endChat() {
                if(isStarted) {
                    isStarted = false;
                    rtcPeerConnection.close();
                    rtcPeerConnection = null;
                    remoteStream = null;

                    enableScreenSaver();
                }
            }

            function createPeerConnection() {
                try {
                    rtcPeerConnection = new RTCPeerConnection(rtcConfiguration);
                    rtcPeerConnection.onicecandidate = handleIceCandidate;
                    console.log('Created RTCPeerConnnection');
                } catch (e) {
                    console.log('Failed to create PeerConnection, exception: ' + e.message);
                    alert('Cannot create RTCPeerConnection object.');
                    return;
                }
                rtcPeerConnection.onaddstream = handleRemoteStreamAdded;
                rtcPeerConnection.onremovestream = handleRemoteStreamRemoved;
            }

            function doCall() {
                console.log('Sending offer to peer');
                rtcPeerConnection.createOffer(setLocalAndSendMessage, null);
            }

            function doAnswer() {
                console.log('Sending answer to peer.');
                rtcPeerConnection.createAnswer(setLocalAndSendMessage, null);
            }

            function tryHangup() {
                if(isStarted) {
                    sendChatHangup();
                    remoteChatter = undefined;
                    remoteChatterName = undefined;
                }
            }

            function setLocalAndSendMessage(sessionDescription) {
                rtcPeerConnection.setLocalDescription(sessionDescription);
                sendMessage(sessionDescription)
            }

            function handleRemoteStreamAdded(event) {
                console.log( event.stream ? "Remote stream NOT added" : "Remote stream added" );
                console.log(event);

                attachMediaStream(remoteVideo, event.stream);
                remoteStream = event.stream;
            }
            function handleRemoteStreamRemoved(event) {
                console.log('Remote stream removed. Event: ', event);
            }

            function handleIceCandidate(event) {
                console.log('handleIceCandidate event: ', event);
                if (event.candidate) {
                    var messageMap = {
                        type: 'candidate',
                        label: event.candidate.sdpMLineIndex,
                        id: event.candidate.sdpMid,
                        candidate: event.candidate.candidate
                    };

                    sendMessage(messageMap);
                } else {
                    console.log('End of candidates.');
                }
            }

            /*************************************************************************************/

            var canvas = $("#canvas").get(0);

            function enableScreenSaver() {
                $("#canvas").show();
                startScreenSaver(canvas);
            }

            function disableScreenSaver() {
                stopScreenSaver();
                $("#canvas").hide();
            }

            /*************************************************************************************/

            // Exit neatly on window unload
            $(window).on('beforeunload', function(){
                // Perchance we happen to be in a video chat, hang up.
                tryHangup();

                // Unsubscribe from all channels
                rtcMessageSubscription.unsubscribe();

                // Delete this chatter from the Chatter table
                json = {"chatId": chatId};
                client.send("/app/unregister", {}, JSON.stringify(json));

                // Disconnect the websocket connection
                client.disconnect();
            });

            // ******* debug messages to the console, please ********
            client.debug = function(str) {
                console.log(str);
            };
        });
    </script>
</head>
    <body class="videoBody">
        <g:hiddenField name="chatId" value="${chatId}" />
        <g:hiddenField name="name" value="Portal" />

        <canvas id="canvas"></canvas>

        <input class="statusText" type="text" id="chatterName" readonly />

        <video id="localVideo" class="localVideoWindow" autoplay muted></video>
        <video id="remoteVideo" class="remotevideoWindow" autoplay></video>
    </body>
</html>