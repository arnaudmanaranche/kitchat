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
    
    //Check if we have a session and it has a value for email
    if let sessionState = sessionState, let pseudo = sessionState["pseudo"].string {
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    } else {
        try response.render("index", context: ["users": users]).end()
    }
}

router.get("/signin") { request, response, next in
    if let sessionState = sessionState, let pseudo = sessionState["pseudo"].string {
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    } else {
        try response.render("signin", context: ["test": ""]).end()
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
    
    let pseudo = data["pseudo1"]
    let password = data["password1"]
    
    if let pseudoo = pseudo, let sessionState = sessionState {
        sessionState["pseudo"] = JSON(pseudoo)
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    }
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Select(users.pseudo, users.password, from: users).where(users.pseudo == pseudo! && users.password == password!)
            
            connection.execute(query: query) { result in
                do {
                    try response.redirect("/room").end()
                }
                catch {
                    print("error")
                }
            }
        }
    }
}

router.get("/room") { request, response, next in
    
    if let sessionState = sessionState, let pseudo = sessionState["pseudo"].string {
        try response.render("room", context: [
            "users": users,
            "messages": messages,
            "sessionState": sessionState,
            ]).end()
    } else {
        try response.render("index", context: ["test": ""]).end()
    }
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Select(messages.content, from: messages)
            
            connection.execute(query: query) { result in
                if let resultSet = result.asResultSet {
                    var retString = ""
                    
                    for row in resultSet.rows {
                        for value in row {
                            if let value = value {
                                let valueString = String(describing: value)
                                retString.append("\(valueString)")
                            }
                        }
                        retString.append("\n")
                    }
                    do {
                        try response.render("room", context: ["messages": retString]).end()
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
    
    guard let body = request.body else {
        try response.status(.badRequest).end()
        return
    }
    
    guard case .urlEncoded(let data) = body else {
        try response.status(.badRequest).end()
        return
    }
    
    let content = data["content"]
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Insert(into: messages, values: content)
            
            connection.execute(query: query) { result in
                print(query)
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
    
    let pseudo = data["pseudo"]
    let password = data["password"]
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Insert(into: users, values: pseudo, password)
            
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
