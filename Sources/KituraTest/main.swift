import Kitura

// Create a new router
let router = Router()

// Handle HTTP GET requests to /
router.get("/") {
    request, response, next in
    response.send("Hello World")
    next()
}

// Handle HTTP GET requests to /hello/:user
router.get("/hello/:name") {
    request, response, next in
    let name = request.parameters["name"] ?? "Platymus"
    try response.send("Hello \(name)").end()
    next()
}

// Add an HTTP server and connect it to the router
Kitura.addHTTPServer(onPort: 8090, with: router)

// Start the Kitura runloop (this call never returns)
Kitura.run()
