#!/usr/bin/env python3

"""Lets you collect cookies"""

import multiprocessing as mp
import collections
import pickle

big_cookie = """
                             WNXXXXXNWW                                       
                      WNNXK0OkkOO0OOO000KXXNNW                                
                   WN0O0O0kOOOO000OOkOOkOKK0OkO0N                             
                 N0kkOkdxxkkOOOOkkxkxddxkkkOK0kxk0KKXXNW                      
                XkOOkxddkxkkOOkkkloddoodl;.;x0koOkdodxdddxk0XW                
              WK0O0OkdokkkOkdddl:ooodxdkxoloc:lkx000kdo;..,,,dON              
           Xxx:l0OkdkO0Okkxxdc::dkO0000OxxxdxoodOkdO00o';cd. :xk0N            
          XkOd'cxxkO0kdc.. .. .:llkOkxdolododdxkOOkkOOOOo:'  coodx0NW         
       WXKOO00OkkkxkOd'  .cko:;':cdxdddoolllooooocclloooddkklxxoodxkO0X       
     WKkOOkkoddxxkkkOko...lkk,.;ooooolllcc;::lllc:cclc:lloddxxkkkxooxddK      
    XOOkkxdokddoddxxxkOo;'...,dOkxxkdc,..;ooccccclc,..ll:;:;:ookOOkdxxxxK     
   NOkOOxdolodoodddoddlxxdo:dOkOxkko....';ldxxdoxxOk.:kc:lxdc:oxdcddl::xk0W   
  Nkkxkkxdll:cocc:ool::l;;lxkkxkkdll:'.'oxx:k000Kkkk. ...;.cdxkkxxx:.  'dx0   
 NkkxdddoolcooddxocdxxkodO00kxkOk'..lol,..:;;kkkkOdO; .    'lxko,.     .lddX  
 KxxxxdddddxxdoxkxdkOOOOOO0Odlxkk;.. 'lc:;,::xkxoxxkO. .''.;dkxo,..  ..,lodk  
 Oxxxxxxxolc'.  ckcdxkkOOOOxl'cOkx:. ;oolcdkxoldk0000x'oxol:dkkllol'';odddddX 
Nxxxdxxxdoc:;,. .l:ooxdxkxxxkkk00kdc:c:odxkkk0Ooxkkkxkkk0Okkxxdxkxl:odxdddddK 1
KxdxxxxkkkkckkxkkOOx:dddxxddxo:,cldxxxdodxxkOOOl:clllodxxdkxddxdooccodxdooodxW
Xdoloxxoxkkdlc:;,oxx:cddddddoccllxxxdddlxkkkxdddo:cllloodxldkOOOolxxdooolloolX
 kddoddodxdxxxkkocxkx:,loododxcc:;,,ldlcxxxdooooclcllloddxkxokOO;.'lxdxxxolclK
 0dddxxx:dkxxokkkkkkOk::xdddll:. .:. .okxdoooooooooolloloddOOxxl.  'ooddddollN
 Nxdolddl;OOxlxxxxdxxd:cxxkxlc;. .. . .lllo:cll;.:xkxdlcooxxxxdd,. ;dodoloolk 
  XddoldocxOklldddoddlclddxolkOx'     :cloc;:  .';'oxdddododooooc..cddxlloolX 
   Oddlololxkklcddddo;ccc:::.oxo:. .;lcoxxl        .dxxoooodooll;;;;:ooooooo  
    XOdclxxdxooloolollkkkoddc:ooc:okkxdloxk;      ..odooodoodxxdcllll:clooo0  
      0odxdlo:odddllcxOkocllclxkOOkkxkxdodxxl'   .'ldoooo:;;,:lc;ddddoooolO   
      Nxodddddddxxldlokxc;;,xkxdddxxxkxxxdddkko,:::cclodo.... .  ;dddlcllcX   
       Nlloxol;llc::;,;.',cooddodooddxkxxdo:clllcloc;coodo.  ..,ldxollolcx    
        K......:;,ld,..   'ooododoooodddoc,;coooodxl:;;:cllcclooooooolollW    
         0' ...;.;okxxxlcdOkdl:clooooolddddoooddlclodl::ccllccodoolooll,k     
          Wxlddxoxxdolldddxxxdlcclllol:l,.  . .;ccllll::cc:;::ccoddooo;x      
             Wdoxxdool::::ccccclodxddxd;       ,olllcclcccclooxdoolccdW       
              W0oloddodooclodxxxooddxxxd;. .  .:c:;::cooooooccoollox0W        
                 0occlolcloodxddxdooooddkkc,,.okdlclooodlcddlccclxX           
                   Xkocc::::cllodoooolcc:ccllcccoooooddxo,,':coON             
                      XOdclclcc:llcllolc:;;cllooooddldooooxk0X                
                         NK0kdlcc:::ccc:clcllllcooooclx0XW                    
                               WNXXKOxoc;:cccccccldOKW                        
                                        NOOddkOXW                             
"""

little_cookie = """
   ╱───╲
 ╱○    ○ ╲
│    ○ ○  │
 ╲ ○  ○  ╱
   ╲───╱
"""

def say_cookies(num):
    if num == 1:
        return "cookie"
    else:
        return "cookies"

def save(obj, name):
    with open(name, "wb") as f:
        pickle.dump(obj, f, pickle.HIGHEST_PROTOCOL)

def load(name):
    with open(name, "rb") as f:
        return pickle.load(f)

if __name__ == "__main__":
    state = {
        "cookies": 0
    }

    dispatch = {
        "": lambda st: {"cookies": st["cookies"] + 1},
        "help": lambda _: print("""
Available commands:
    save [save name] - save current game state
    load [save name] - load previous save
    help - get this message
    cookie - see a minicookie
    <ENTER> - get cookies
        """),
        "save": lambda st, save_name: save(st, save_name),
        "load": lambda _, save_name: load(save_name),
        "cookie": lambda _: print(little_cookie)
    }

    print(big_cookie)

    while True:
        print("You have %d %s." % (state["cookies"], say_cookies(state["cookies"])))

        result_tokens = input(u"|||> ").split(" ")

        try:
            selected_func = dispatch[result_tokens[0]]
        except:
            print("Command not found.")
            dispatch["help"](state)
            continue

        change = selected_func(state, *result_tokens[1:])

        try: # An operation might return nothing instead of changing state.
            for k, v in change.items():
                state[k] = v
        except:
            pass