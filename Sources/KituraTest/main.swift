import Kitura
import KituraMarkdown

// Create a new router
let router = Router()

router.all("/", middleware: BodyParser())

router.add(templateEngine: KituraMarkdown())

// Handle HTTP GET requests to /
router.get("/") {
    request, response, next in
    try response.render("/docs/index.md", context: [String:Any]())
    next()
}

// Handle HTTP GET requests to /hello/:user
router.get("/hello/:name") {
    request, response, next in
    let name = request.parameters["name"] ?? "Platymus"
    try response.send("Hello \(name)").end()
    next()
}

router.post("/") {
    request, response, next in
    
    guard let body = request.body else {
        try response.status(.badRequest).end()
        return
    }
    
    guard case .urlEncoded(let data) = body else {
        try response.status(.badRequest).end()
        return
    }
    
    if let text = data["champ"] {
        try response.send(text).end()
    } else {
        try response.send("nok").end()
    }
    next()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
