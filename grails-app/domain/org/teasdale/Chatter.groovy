package org.teasdale

class Chatter {
    String name
    String chatId

    static constraints = {
        name blank: false, nullable: false, unique: true, size: 1..64
        chatId blank: false, nullable: false, unique: true
    }
}
