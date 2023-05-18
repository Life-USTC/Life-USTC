// new console.log() function that sends logs to the native app
function log(emoji, type, args) {
    window.webkit.messageHandlers.logging.postMessage(
          `${emoji} JS ${type}: ${Object.values(args)
          .map(v => typeof(v) === "undefined" ? "undefined" : typeof(v) === "object" ? JSON.stringify(v) : v.toString())
          .map(v => v.substring(0, 3000)) // Limit msg to 3000 chars
          .join(", ")}`)
}

let originalLog = console.log
let originalWarn = console.warn
let originalError = console.error
let originalDebug = console.debug

console.log = function() { log("📗", "log", arguments); originalLog.apply(null, arguments) }
console.warn = function() { log("📙", "warning", arguments); originalWarn.apply(null, arguments) }
console.error = function() { log("📕", "error", arguments); originalError.apply(null, arguments) }
console.debug = function() { log("📘", "debug", arguments); originalDebug.apply(null, arguments) }

window.addEventListener("error", function(e) {
    log("💥", "Uncaught", [`${e.message} at ${e.filename}:${e.lineno}:${e.colno}`])
})

// new XMLHttpRequest() function that sends requests to the native app
let originalXMLHttpRequest = XMLHttpRequest
XMLHttpRequest = function() {
    let xhr = new originalXMLHttpRequest()
    let originalOpen = xhr.open
    xhr.open = function(method, url, async, user, password) {
        log("📩", "XHR", [method, url])
        // proxy the url to the native app
        originalOpen.apply(xhr, ["GET", "lu-bridge://proxy?url=" + encodeURIComponent(url) + "&method=" + method, async, user, password])
    }
    let originalSend = xhr.send
    xhr.send = function(body) {
        log("📩", "XHR", [body])
        originalSend.apply(xhr, arguments)
    }
    return xhr
}