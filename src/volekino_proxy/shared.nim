import os, osproc, strformat
let
  USERDEL = findExe("userdel")
  USERADD = findExe("useradd")
  PASSWD = findExe("passwd")

proc deleteUser*(username: string): bool =
  execCmd(&"{USERDEL} {username}") == 0
  

proc createUser*(username: string): bool =
  execCMD(&"{USERADD} {username}") == 0
  
proc setPassword*(username, password: string): bool =
  let process = startProcess(PASSWD, args=[username], options={poEchoCmd})
  var f: File

  discard f.open(process.inputHandle, fmWrite)

  f.write(&"{password}\n{password}")
  f.close()
