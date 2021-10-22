import asynchttpserver, asyncdispatch
import volekino_proxy/rpc
import json

var server = newAsyncHttpServer()

server.listen(Port 12990)


proc asyncLoop {.async.} =
  let requestHandler = proc(r: Request) {.async, gcsafe.} =
    if r.reqMethod == HttpPost:
      echo r.body
      try:
        let rpc = parseJson(r.body).to(RpcBody)
        processCommands(rpc)
        when defined(test):
          await r.respond(Http200, $(% output))
        else:
          await r.respond(Http200, "OK")
      except UnauthorizedError:
        await r.respond(Http401, "Password incorrect")
      except:
        await r.respond(Http400, "Bad input")
        
      #await r.respond(Http200, "OK")
    else:
      await r.respond(Http400, "Invalid method")
      
  
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(requestHandler)
    else:
      await sleepAsync 10
  


waitFor asyncLoop()
