<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>
    <asset:stylesheet href="chat.css"/>
    <title>Client Landing Page</title>
</head>

<body>
    Your chat id is ${chatId}

    <g:form name="client" action="client" >
        <g:hiddenField name="chatId" value="${chatId}" />

        <br>

        <div class="boxed">
            <label for="name">Enter your name: </label>
            <g:textField name="name" required="" />
        </div>

        <br>

        <fieldset class="buttons">
            <g:submitButton name="client" class="client" value="Connect as Client"/>
        </fieldset>
    </g:form>
</body>
</html>