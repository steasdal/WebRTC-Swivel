<%@ page contentType="text/html;charset=UTF-8" %>
<html>
<head>
    <meta name="layout" content="main"/>
    <asset:stylesheet href="chat.css"/>
    <title>Server Landing Page</title>
</head>

<body>
    <br>
    <H4>You're connecting from localhost... you'll be the portal!</H4>
    <br>

    <g:form name="server" action="server" >
        <g:hiddenField name="chatId" value="${chatId}" />

        <fieldset class="buttons">
            <g:submitButton name="server" class="server" value="Connect as Portal"/>
        </fieldset>
    </g:form>
</body>
</html>