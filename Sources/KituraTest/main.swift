import Kitura
import KituraStencil
import KituraSession
import Foundation
import SwiftyJSON

// Struc User
struct User {
    var pseudo:String
}

// Struc Message
struct Message {
    var content:String
    var expediteur:User
}

var users = [User]()
var messages = [Message]()

// Where we will store the current session data
var sess: SessionState?

// Initialising our KituraSession
let session = Session(secret: "kitura_session")

// Create a new router
let router = Router()

router.all("/", middleware: BodyParser(), StaticFileServer(path: "./Public"), session)

router.setDefault(templateEngine: StencilTemplateEngine())

// Handle HTTP GET requests to /hello/:user
router.get("/") { request, response, next in
    
    //Again get the current session
    sess = request.session
    
    //Check if we have a session and it has a value for email
    if let sess = sess, let pseudo = sess["pseudo"].string {
        try response.render("index", context: ["users": users, "messages": messages]).end()
    } else {
        try response.render("index", context: ["users": users]).end()
    }
    
    next()
}

router.post("/") { request, response, next in
    
    if let body = request.body {
        
        switch body {
        case .urlEncoded(let params):
            let content = params["content"] ?? ""
            let pseudo = sess!["pseudo"].string ?? ""
            let expediteur = User(pseudo: pseudo)
            
            users.append(User(pseudo: pseudo))
            messages.append(Message(content: content, expediteur: expediteur))
            
            try response.render("room", context: ["users": users, "messages": messages]).end()
        default:
            try response.redirect("/error").end()
        }
    }
    
    next()
}

router.post("/room") { request, response, next in
    
    //Get current session
    sess = request.session
    
    var maybePseudo: String?
    
    switch request.body {
    case .urlEncoded(let params)?:
        maybePseudo = params["pseudo"]
    default: break
    }
    
    if let pseudo = maybePseudo, let sess = sess {
        sess["pseudo"] = JSON(pseudo)
        try response.render("room", context: ["user": "pseudo"]).end()
    }
    
}

router.get("/logout") {
    request, response, next in
    
    //Destroy all data in our session
    sess?.destroy() {
        (error: NSError?) in
        if let error = error {
        }
    }
    try response.render("index", context: ["users": users, "messages": messages]).end()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
