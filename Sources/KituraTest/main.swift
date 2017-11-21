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
    var date:Any
}

var users = [User]()
var messages = [Message]()

let dateFormatter = DateFormatter()

dateFormatter.dateStyle = .full
dateFormatter.timeStyle = .full

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
    if let sessionState = sessionState {
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    } else {
        try response.render("index", context: ["users": users]).end()
    }
}

router.post("/room") { request, response, next in
    
    if let body = request.body {
        switch body {
        case .urlEncoded(let params):
            let content = params["content"] ?? ""
            let pseudo = sessionState!["pseudo"].string ?? ""
            let expediteur = User(pseudo: pseudo)
            let date = Date()
            let convertedDate: String = dateFormatter.string(from: date)
            
            users.append(User(pseudo: pseudo))
            messages.append(Message(content: content, expediteur: expediteur, date: convertedDate))
            
            try response.render("room", context: ["users": users, "messages": messages, "sessionState": sessionState as Any]).end()
        default:
            try response.redirect("/error").end()
        }
    }
    next()
}

router.get("/room") { request, response, next in
    
    if let sessionState = sessionState {
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    } else {
        try response.render("index", context: ["users": users]).end()
    }
}

router.post("/") { request, response, next in
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
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    }
}

router.get("/logout") { request, response, next in
    sessionState?.destroy() {
        (error: NSError?) in
        if error != nil {}
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
