import os
import ./shared
type RpcBody* = ref object
  password*: string
  commands*: seq[string]


const
  COMMAND_ADD = "add"
  COMMAND_DEL = "del"
  COMMAND_PASS = "pass"

when defined(test):
  putEnv("VOLEKINO_RPC_PASS", "zhopa")

let PASSWORD = getEnv("VOLEKINO_RPC_PASS")

when defined(test):
  import strformat
  var output*: seq[string]
  proc processAdd(username, password: string) =
    output.add(&"add:{username}:{password}")
    

  proc processDel(username: string) =
    output.add(&"del:{username}")

  proc processPass(username, password: string) =
    output.add(&"pass:{username}:{password}")


else:
  proc processAdd(username, password: string) =
    discard createUser(username)
    discard setPassword(username, password)
  
  proc processDel(username: string) =
    discard deleteUser(username)
    removeFile("/tmp" / username)

  proc processPass(username, password: string) =
    discard setPassword(username, password)
  

type UnauthorizedError* = object of CatchableError

proc processCommands*(rpcbody: RpcBody) =
  if rpcbody.password != PASSWORD: raise newException(UnauthorizedError, "Incorrect password")
  let commands = rpcbody.commands
  var 
    expectedArgs = 0
    currentCommand: string
    args = newSeqOfCap[string](2)

  
  for i in 0..commands.len:
    var command: string
    if i < commands.len: command = commands[i]
    if expectedArgs == 0:
      if currentCommand.len > 0:
        case currentCommand:
        of COMMAND_ADD: processAdd(args[0], args[1])
        of COMMAND_DEL: processDel(args[0])
        of COMMAND_PASS: processPass(args[0], args[1])
        else: discard
        args.setlen 0

      currentCommand = command
      case command:
      of COMMAND_ADD, COMMAND_PASS: expectedArgs = 2
      of COMMAND_DEL: expectedArgs = 1
      else: discard
    else:
      args.add command
      expectedArgs -= 1
        

when defined(test):
  processCommands(RpcBody(commands: @["add", "andrew", "zhopa", "del", "lu", "pass", "andrew", "llama"], password: "zhopa"))

  assert output == @["add:andrew:zhopa", "del:lu", "pass:andrew:llama"]
