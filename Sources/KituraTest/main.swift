import Kitura
import KituraStencil
import KituraSession
import Foundation
import SwiftKuery
import SwiftyJSON
import SwiftKueryPostgreSQL

let router = Router()

// Store the current session data
var sessionState: SessionState?
// Initialising the session
let session = Session(secret: "kitura_session")

// Router Information
router.all("/", middleware: BodyParser(), StaticFileServer(path: "./Public"), session)
router.setDefault(templateEngine: StencilTemplateEngine())

// Class Users
class Users : Table {
    let tableName = "users"
    let pseudo = Column("pseudo", Varchar.self, length: 50)
    let password = Column("password", Varchar.self, length: 50)
}

// Class Messages
class Messages : Table {
    let tableName = "messages"
    let content = Column("content", Varchar.self, length: 280)
    let expediteur = Column("expediteur", Varchar.self, length: 50)
}

let users = Users()
let messages = Messages()

let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("kitchat")])

connection.connect { (error) in
    print(error as Any)
    users.create(connection: connection) { (result) in
        print(result)
    }
    connection.closeConnection()
}

router.get("/") { request, response, next in
    
    // Get the current session
    sessionState = request.session
    
    //Check if we have a session and it has a value for pseudo
    if let sessionState = sessionState, let _ = sessionState["pseudo"].string {
        try response.redirect("room").end()
    } else {
        try response.render("index", context: ["useless": "useless"]).end()
    }
}

router.get("/signin") { request, response, next in
    
    //Check if we have a session and it has a value for pseudo
    if let sessionState = sessionState, let _ = sessionState["pseudo"].string {
        try response.redirect("room").end()
    } else {
        try response.render("signin", context: ["useless": "useless"]).end()
    }
}

router.post("/login") { request, response, next in
    
    // Get the current session
    sessionState = request.session
    
    guard let body = request.body else {
        try response.status(.badRequest).end()
        return
    }
    
    guard case .urlEncoded(let data) = body else {
        try response.status(.badRequest).end()
        return
    }
    
    let pseudoLogin = data["pseudo_login"]
    let passwordLogin = data["password_login"]
    
    connection.connect() { error in
        if error != nil {
            print("Error")
            return
        }
        else {
            let query = Select(users.pseudo, users.password, from: users).where(
                users.pseudo == pseudoLogin! && users.password == passwordLogin!
            )
            
            connection.execute(query: query,onCompletion: { (result) in
                if result.success {
                    if result.asResultSet != nil {
                        if let pseudo = pseudoLogin, let sessionState = sessionState {
                            sessionState["pseudo"] = JSON(pseudo)
                            do {
                                try response.redirect("room").end()
                            } catch {
                                print("Error")
                            }
                        }
                    } else {
                        do {
                            try response.redirect("/").end()
                        }
                        catch {
                            print("Error")
                        }
                    }
                }
                else if result.asError != nil {
                    print("error")
                }
            })
            connection.closeConnection()
        }
    }
}

router.get("/room") { request, response, next in
    
    if let sessionState = sessionState, let _ = sessionState["pseudo"].string {
        print("Session")
    } else {
        try response.redirect("/").end()
    }
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Select(messages.content, messages.expediteur, from: messages)
            connection.execute(query: query) { result in
                if let rows = result.asRows {
                    do {
                        try response.render("room", context: ["messages": rows, "sessionState": sessionState] ).end()
                    }
                    catch {
                        print("error")
                    }
                }
                else if result.asError != nil {
                    print("nok")
                }
            }
        }
    }
}

router.post("/room") { request, response, next in
    
    if let sessionState = sessionState, let _ = sessionState["pseudo"].string {
        print("Session")
    } else {
        try response.redirect("/").end()
    }
    
    guard let body = request.body else {
        try response.status(.badRequest).end()
        return
    }
    
    guard case .urlEncoded(let data) = body else {
        try response.status(.badRequest).end()
        return
    }
    
    let content = data["content"]
    let expediteur = sessionState!["pseudo"].string
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        } else {
            let query = Insert(into: messages, values: content ?? "", expediteur ?? "")
            
            connection.execute(query: query) { result in
                do {
                    try response.redirect("/room").end()
                }
                catch {
                    print("Error")
                }
            }
        }
    }
}

router.post("/signin") { request, response, next in
    
    guard let body = request.body else {
        try response.status(.badRequest).end()
        return
    }
    
    guard case .urlEncoded(let data) = body else {
        try response.status(.badRequest).end()
        return
    }
    
    let pseudo = data["pseudo_signin"]
    let password = data["password_signin"]
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Insert(into: users, values: pseudo ?? "", password ?? "")
            
            connection.execute(query: query) { result in
                do {
                    try response.redirect("/").end()
                }
                catch {
                    print("error")
                }
            }
        }
    }
}

router.get("/logout") { request, response, next in
    sessionState?.destroy() {
        (error: NSError?) in
        if error != nil {}
    }
    try response.render("index", context: ["users": users, "messages": messages]).end()
}

// Use port 8080 unless overridden by environment variable
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080

Kitura.addHTTPServer(onPort: port, with: router)
Kitura.run()
