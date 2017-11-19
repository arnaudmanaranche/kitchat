import Kitura
import KituraStencil
import KituraSession
import Foundation
import SwiftyJSON

// Structure User
struct User {
    var pseudo:String
}

// Structure Message
struct Message {
    var content:String
    var expediteur:User
    var date = Date()
}

var users = [User]()
var messages = [Message]()

// Store the current session data
var sessionState: SessionState?
// Initialising the session
let session = Session(secret: "kitura_session")

let router = Router()

// Router Information
router.all("/", middleware: BodyParser(), StaticFileServer(path: "./Public"), session)
router.setDefault(templateEngine: StencilTemplateEngine())

router.get("/") { request, response, next in
    
    // Get the current session
    sessionState = request.session
    
    //Check if we have a session and it has a value for email
    if let sessionState = sessionState, let pseudo = sessionState["pseudo"].string {
        try response.render("rooms", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    } else {
        try response.render("index", context: ["users": users]).end()
    }
}

router.post("/rooms/:id") { request, response, next in
    
    if let body = request.body {
        switch body {
        case .urlEncoded(let params):
            let content = params["content"] ?? ""
            let pseudo = sessionState!["pseudo"].string ?? ""
            let expediteur = User(pseudo: pseudo)
            let date = Date()
            
            users.append(User(pseudo: pseudo))
            messages.append(Message(content: content, expediteur: expediteur, date: date))
            
            try response.render("room", context: ["users": users, "messages": messages, "sessionState": sessionState]).end()
        default:
            try response.redirect("/error").end()
        }
    }
    next()
}

router.post("/rooms") { request, response, next in
    // Get the current session
    sessionState = request.session
    
    var maybePseudo: String?
    
    switch request.body {
    case .urlEncoded(let params)?:
        maybePseudo = params["pseudo"]
    default: break
    }
    
    if let pseudo = maybePseudo, let sessionState = sessionState {
        sessionState["pseudo"] = JSON(pseudo)
        try response.render("rooms", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    }
}

router.get("/logout") { request, response, next in
    sessionState?.destroy() {
        (error: NSError?) in
        if let error = error {
        }
    }
    try response.render("index", context: ["users": users, "messages": messages]).end()
}

let port: Int
let defaultPort = 8080

if let requestedPort = ProcessInfo.processInfo.environment["PORT"] {
    port = Int(requestedPort) ?? defaultPort
} else {
    port = defaultPort
}

Kitura.addHTTPServer(onPort: port, with: router)
Kitura.run()
