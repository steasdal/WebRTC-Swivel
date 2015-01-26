<!DOCTYPE html>

<html>
<head>
    <meta name="layout" content="main"/>

    <asset:javascript src="jquery" />
    <asset:javascript src="spring-websocket" />
    <asset:javascript src="adapter.js" />
    <asset:stylesheet href="chat.css"/>
    <jqui:resources/>

    <script type="text/javascript">
        $(function() {
            var name = $("#name").val();
            var chatId = $("#chatId").val();
            var serverId = $("#serverId").val();

            var socket = new SockJS("${createLink(uri: '/stomp')}");
            var client = Stomp.over(socket);

            var rtcMessageSubscription;

            var localVideo = $("#localVideo")[0];
            var remoteVideo = $("#remoteVideo")[0];

            var localStream, remoteStream, rtcPeerConnection;
            var isInitiator = false;
            var isStarted = false;

            var remoteChatter = undefined;

            var rtcConstraints = {video: true, audio:true};

            var servoUpdateIntervalId;
            var servoUpdatePollFrequency = 63; // poll 16 times a second; 1000/16 = 62.5 so we'll round up to 63 milliseconds

            var gamepadPollIntervalId;
            var gamepadPollFrequency = 50;     // poll 20 times a second; 1000/20 = 50 milliseconds
            var gamepadAxis0position = 0.0;
            var gamepadAxis1position = 0.0;
            var gamepadButton10value = 0.0;

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
                        case "chat-acknowledged":        // You've sent a chat offer and the remote participant has acknowledged - prepare to chat!
                            if( messageBody.sender === remoteChatter ) {
                                console.log("Chat acknowledged by " + remoteChatter);
                                startChat();
                            } else {
                                console.log("Chat acknowledgement expected by " + remoteChatter + " but received by " + messageBody.sender);
                            }
                            break;
                        case "disconnect-offer":         // You've received a disconnect offer from your chat participant - prepare to disconnect
                            acknowledgeChatHangup();
                            endChat();
                            cleanupAfterVideoChat();
                            remoteChatter = undefined;
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

                startUpdatePolling();
                startLocalVideo();
            });

            /*************************************************************************************/

            function sendMessage(message){
                console.log('Sending message to ' + remoteChatter + ': ', message);
                client.send("/app/rtcMessage/" + remoteChatter, {}, JSON.stringify(message));
            }

            function sendChatInvitation() {
                var json = {type:'chat-offer', sender:chatId, name:name};
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

            function cleanupAfterVideoChat() {
                isInitiator = false;
            }

            /*************************************************************************************/

            function handleUserMedia(stream) {
                localStream = stream;

                console.log(stream.getVideoTracks()[0]);

                attachMediaStream(localVideo, stream);
                console.log('Local media stream added.  Initiating session...');

                // Once the local video stream is obtained, immediately
                // initiate a video session with the server portal.
                remoteChatter = serverId;
                isInitiator = true;
                sendChatInvitation();
                console.log('Session initiated');
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
                }
            }

            function endChat() {
                if(isStarted) {
                    isStarted = false;
                    rtcPeerConnection.close();
                    rtcPeerConnection = null;
                    remoteStream = null;
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

            var panMin = 0;
            var panMax = 180;
            var panHome = 90;

            var tiltMin = 60;
            var tiltMax = 105;
            var tiltHome = 90;

            var panCurrentPosition = panHome;
            var tiltCurrentPosition = tiltHome;

            var panUpdatePosition = 90;
            var tiltUpdatePosition = 90;

            // Pan servo
            $("#servo01value").val(90);
            $("#servo01-slider").slider({
                value:panCurrentPosition,
                min: panMin,
                max: panMax,
                animate: true,
                slide: function( event, ui ) {
                    var slideval = ui.value;
                    setPanPosition(slideval);
                }
            });

            // Tilt servo
            $("#servo02value").val(90);
            $("#servo02-slider").slider({
                value:tiltCurrentPosition,
                min: tiltMin,
                max: tiltMax,
                animate: true,
                slide: function( event, ui ) {
                    var slideval = ui.value;
                    setTiltPosition(slideval);
                }
            });

            function setPanPosition(value) {
                $("#servo01value").val(value);
                panUpdatePosition = value;
            }

            function setTiltPosition(value) {
                $("#servo02value").val(value);
                tiltUpdatePosition = value;
            }

            function sendPositionUpdates() {
                if(panUpdatePosition != panCurrentPosition) {
                    panCurrentPosition = panUpdatePosition;
                    client.send("/app/servo01", {}, JSON.stringify(panMax - panCurrentPosition));
                }

                if(tiltUpdatePosition != tiltCurrentPosition) {
                    tiltCurrentPosition = tiltUpdatePosition;
                    client.send("/app/servo02", {}, JSON.stringify(tiltCurrentPosition));
                }
            }

            function startUpdatePolling() {
                servoUpdateIntervalId = setInterval(sendPositionUpdates, servoUpdatePollFrequency);
            }

            /*************************************************************************************/

            window.addEventListener("gamepadconnected", function(event) {
                console.log("Gamepad connected: " + event.gamepad.id);
                gamepadPollIntervalId = setInterval(pollGamepad, gamepadPollFrequency);
            });

            window.addEventListener("gamepaddisconnected", function(event) {
                console.log("Disconnecting gamepad: " + event.gamepad.id);
                clearInterval(gamepadPollIntervalId);
            });

            function pollGamepad() {
                var gamepads = navigator.getGamepads ? navigator.getGamepads() : (navigator.webkitGetGamepads ? navigator.webkitGetGamepads : []);

                if (!gamepads) {
                    return;
                }

                var gamepad = gamepads[0];

                if(gamepad) {
                    if(gamepad.buttons[10].value != gamepadButton10value) {
                        gamepadButton10value = gamepad.buttons[10].value;
                        console.log("Gamepad Button 10 Value: " +  gamepadButton10value);

                        $("#servo01-slider").slider('value', panHome);
                        setPanPosition(panHome);

                        $("#servo02-slider").slider('value', tiltHome);
                        setTiltPosition(tiltHome);
                    }

                    var panIncrement = Math.round(map_range(gamepad.axes[0], -1.0, 1.0, -5, 5));
                    var panSliderPosition = panCurrentPosition;

                    if( panIncrement ) {
                        if( panIncrement > 0 ) {
                            panSliderPosition = Math.min(panMax, panCurrentPosition + panIncrement);
                        } else if( panIncrement < 0 ) {
                            panSliderPosition = Math.max(panMin, panCurrentPosition + panIncrement);
                        }

                        $("#servo01-slider").slider('value', panSliderPosition);
                        setPanPosition(panSliderPosition);
                    }

                    var tiltIncrement = Math.round(map_range(gamepad.axes[1], -1.0, 1.0, -3, 3));
                    var tiltSliderPosition = tiltCurrentPosition;

                    if( tiltIncrement ) {
                        if( tiltIncrement > 0 ) {
                            tiltSliderPosition = Math.min(tiltMax, tiltCurrentPosition + tiltIncrement);
                        } else if( tiltIncrement < 0 ) {
                            tiltSliderPosition = Math.max(tiltMin, tiltCurrentPosition + tiltIncrement);
                        }

                        $("#servo02-slider").slider('value', tiltSliderPosition);
                        setTiltPosition(tiltSliderPosition);
                    }
                }
            }

            function map_range(value, low1, high1, low2, high2) {
                return low2 + (high2 - low2) * (value - low1) / (high1 - low1);
            }

            /*************************************************************************************/

            // Exit neatly on window unload
            $(window).on('beforeunload', function(){
                // Perchance we happen to be in a video chat, hang up.
                tryHangup();

                // Stop polling for updates
                clearInterval(servoUpdateIntervalId);

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
    <body>
        <div class="nav" role="navigation">
            <ul>
                <li><a class="home" href="${createLink(uri: '/')}"><g:message code="default.home.label"/></a></li>
            </ul>
        </div>

        <br/>

        <g:hiddenField name="chatId" value="${chatId}" />
        <g:hiddenField name="serverId" value="${serverId}" />
        <g:hiddenField name="name" value="${name}" />

        <div class="boxed" >
            <video id="localVideo" class="videoWindow" autoplay muted></video>
            <video id="remoteVideo" class="videoWindow" autoplay></video>
        </div>

        <div id="slider-controls" class="content" role="main">
            <label for="servo01value">Pan:</label>
            <input type="text" id="servo01value" readonly style="border:0; color:#f6931f; font-weight:bold;">
            <div id="servo01-slider"></div>

            <br>

            <label for="servo02value">Tilt:</label>
            <input type="text" id="servo02value" readonly style="border:0; color:#f6931f; font-weight:bold;">
            <div id="servo02-slider"></div>
        </div>

    </body>
</html>