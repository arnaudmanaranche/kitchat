import Kitura
import KituraStencil
import KituraSession
import Foundation
import SwiftKuery
import SwiftyJSON
import SwiftKueryPostgreSQL

let router = Router()

// Router Information
router.all("/", middleware: BodyParser(), StaticFileServer(path: "./Public"))
router.setDefault(templateEngine: StencilTemplateEngine())

// Class Users
class Users : Table {
    let tableName = "users"
    let pseudo = Column("pseudo", Varchar.self, length: 50)
    let password = Column("password", Varchar.self, length: 50)
}

let users = Users()

let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("kitchat")])

connection.connect { (error) in
    print(error as Any)
    users.create(connection: connection) { (result) in
        print(result)
    }
    connection.closeConnection()
}

router.get("/") { request, response, next in
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Select(users.pseudo, from: users)
            
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
                        try response.render("index", context: ["users": retString]).end()
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

router.post("/login") { request, response, next in
    
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
    
    connection.connect() { error in
        if error != nil {
            print("nok")
            return
        }
        else {
            let query = Select(users.pseudo, users.password, from: users).where(users.pseudo == pseudo! && users.password == password!)
            
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
                print(query)
            }
        }
    }
}

// Use port 8080 unless overridden by environment variable
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080

Kitura.addHTTPServer(onPort: port, with: router)
Kitura.run()
