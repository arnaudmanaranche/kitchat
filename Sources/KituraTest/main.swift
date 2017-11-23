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
class Grades : Table {
    let tableName = "grades"
    let key = Column("key")
    let course = Column("course")
    let grade = Column("grade")
    let studentId = Column("studentId")
}

let grades = Grades()

let connection = PostgreSQLConnection(host: "localhost", port: 5432, options: [.databaseName("kitchat")])

func grades(_ callback:@escaping (String)->Void) -> Void {
    connection.connect() { error in
        if let error = error {
            callback("Error is \(error)")
            return
        }
        else {
            // Build and execute your query here.
            
            // First build query
            let query = Select(grades.course, grades.grade, from: grades)
            
            connection.execute(query: query) { result in
                if let resultSet = result.asResultSet {
                    var retString = ""
                    
                    for title in resultSet.titles {
                        // The column names of the result.
                        retString.append("\(title.padding(toLength: 35, withPad: " ", startingAt: 0))")
                    }
                    retString.append("\n")
                    
                    for row in resultSet.rows {
                        for value in row {
                            if let value = value {
                                let valueString = String(describing: value)
                                retString.append("\(valueString.padding(toLength: 35, withPad: " ", startingAt: 0))")
                            }
                        }
                        retString.append("\n")
                    }
                    callback(retString)
                }
                else if let queryError = result.asError {
                    // Something went wrong.
                    callback("Something went wrong \(queryError)")
                }
            }
        }
    }
}

router.get("/") {
    request, response, next in
    
    grades() {
        resp in
        response.send(resp)
        next()
    }
}

// Use port 8080 unless overridden by environment variable
let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080

Kitura.addHTTPServer(onPort: port, with: router)
Kitura.run()
