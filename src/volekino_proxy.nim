# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.


import regex
import os, osproc, strformat, streams, strutils, options, posix


let
#  USERDEL = findExe("userdel")
#  USERADD = findExe("useradd")
#  PASSWD = findExe("passwd")
  NGINX = findExe("nginx")
  SSHD = findExe("sshd")
  RSYSLOGD = findExe("rsyslogd")
  RPC_CONTROLLER = findExe("rpc_controller")


#[
proc deleteUser*(username: string) =
  discard execCmd(&"{USERDEL} {username}") == 0
  

proc createUser*(username: string) =
  discard execCMD(&"{USERADD} {username}")
  
proc setPassword*(username, password: string) =
  let process = startProcess(PASSWD, args=[username], options={poEchoCmd})
  var f: File

  discard f.open(process.inputHandle, fmWrite)

  f.write(&"{password}\n{password}")
  f.close()

]#
  
const 
  passwordLogin = re"Accepted password for (\S+) from (\S+)"
  localForwarding = re"Local forwarding listening on (path )?(\S+)"
  pidRe = re"User child is on pid (\d+)"
  pidRe2 = re"sshd\[(\d+)\]:"
  childRe = re"sshd: ([a-zA-Z][a-zA-Z0-9]*)"
  addrInUseRe = re"unix_listener: cannot bind to path (\S+) Address already in use"
  sessionClosedRe = re"session closed for user ([a-zA-Z][a-zA-Z0-9]*)"

type LoginSource = tuple[user: string, ip: string]
proc parseLogin(s: string): Option[LoginSource] =
  var m: RegexMatch
  if s.find(passwordLogin, m):
    try:
      result = some((
        s[m.captures[0][0]],
        s[m.captures[1][0]]
      ))
    except: discard

proc parseLocalForwarding(s: string): string =
  var m: RegexMatch
  if s.find(localForwarding, m):
    try:
      result = s[m.captures[1][0]][0..^2]
    except: discard

proc parsePid(s: string): int =
  var m: RegexMatch
  if s.find(pidRe, m):
    try: result = parseInt s[m.captures[0][0]]
    except: discard


proc parseChildUser(s: string): string =
  var m: RegexMatch
  if s.find(childRe, m):
    try: result = s[m.captures[0][0]]
    except: discard

proc getChildUser(pid: int): string =
  parseChildUser(readFile &"/proc/{pid}/cmdline")

proc getPid(s: string): int =
  var m: RegexMatch
  if s.find(pidRe2, m):
    try: result = parseInt s[m.captures[0][0]]
    except: discard

proc getAddressInUse(s: string): string =
  var m: RegexMatch
  if s.find(addrInUseRe, m):
    try:
      result = s[m.captures[0][0]][0..^2]
    except: discard

proc disconnectSession(pid: int) =
  # 0 is success
  discard kill(cint pid, SIGINT)

proc getCloseSocket(s: string): string =
  var m: RegexMatch
  if s.find(sessionClosedRe, m):
    try:
      result = "/tmp/" & s[m.captures[0][0]]
    except: discard

  
when defined(test):
  assert (parseLogin "Accepted password for andrew from 172.17.0.1 port 39718 ssh2").get() == ("andrew", "172.17.0.1")
  assert (parseLocalForwarding "Oct 10 22:15:57 fd06a4e46635 sshd[45]: debug1: Local forwarding listening on path /tmp/andrew.") == "/tmp/andrew"
  assert (parsePid " User child is on pid 39") == 39
  assert (parseChildUser "sshd: andrew") == "andrew"
  assert (getPid "Oct 10 21:57:03 2a732fbe8a59 sshd[44]: debug2: fd 3 setting O_NONBLOCK") == 44
  assert (getAddressInUse "unix_listener: cannot bind to path /tmp/andrew: Address already in use") == "/tmp/andrew"
  assert (getCloseSocket "Oct 11 22:50:31 4da872d90893 sshd[434]: pam_unix(sshd:session): session closed for user andrew") == "/tmp/andrew"

  quit 0

proc verifyUser(pid:int, forwarding:string): bool  =
  let childUser = getChildUser(pid)
  if ("/tmp/" & childUser) == forwarding:
    echo "FORWARDING MATCHES USER"
    return true
  else:
    echo "childUser: ", childUser, childUser.len
    echo forwarding
    echo "forwarding: ", forwarding, forwarding.len
    echo "NOT A MATCH!!!"

when isMainModule:
  #createUser("andrew")
  #echo "andrew created"
  #setPassword("andrew", "zhopa")
  #echo "password set"

  #/usr/local/nginx/conf/nginx.conf.tempalte
  discard startProcess("envsubst '$PROXY_CACHE_MAX_SIZE $SLICE_SIZE' < /usr/local/nginx/conf/nginx.conf.tempalte > /usr/local/nginx/conf/nginx.conf && echo 'envsubst successful'", options={poEvalCommand, poParentStreams}).waitForExit()
  let nginxTest = startProcess(NGINX, args=["-t"], options={poParentStreams})
  if nginxTest.waitForExit != 0:
    echo "nginx test failed"
    quit 0


  


  if mkfifo(cstring"/var/log/auth.log", Mode O_RDWR) != 0:
    echo "couldn't create fifo"
    quit 1
  let
    o = {poStdErrToStdOut, poEchoCmd}
    controller = startProcess(RPC_CONTROLLER, options=(o + {poParentStreams}))
    nginx = startProcess(NGINX, options=o)
    sshd = startProcess(SSHD, options=o)
    rsyslog = startProcess(RSYSLOGD, options=o)
    log = newFileStream("/var/log/auth.log")



  var 
    currentLogin: LoginSource
    currentForwardingTarget: string
    currentPid: int
    childUser: string
  while true:
    if log.atEnd:
      sleep 100
    else:
      let
        line = log.readline
        pid = getPid line
      if pid == 0: continue
      let
        login = parseLogin line
        forwarding = parseLocalForwarding line
        childPid = parsePid line
        addressInUse = getAddressInUse line
        closeSocket = getCloseSocket line
      if login.isSome():
        echo login.get()
        # we should expect a forwarding from this user
        currentLogin = login.get()
      elif forwarding.len > 0:
        currentForwardingTarget = forwarding
        if verifyUser(pid, forwarding):
          setFilePermissions(forwarding, {fpUserWrite, fpUserRead, fpGroupWrite, fpGroupRead, fpOthersWrite, fpOthersRead})
        else:
          disconnectSession(pid)
      elif addressInUse.len > 0:
        if verifyUser(pid, addressInUse):
          removeFile(addressInUse)

        disconnectSession(pid)
      elif closeSocket.len > 0:
        removeFile(closeSocket)
      
      echo line
  #echo sshd.waitForExit
  #echo "user deleted ", deleteUser("kaka")
