:class RIDE ⍝ V1.00 

⍝ This class will start an APL task and communicate with it in order to
⍝ control it. To start a new task do
⍝    T←⎕NEW RIDE [port]

⍝ If no port is supplied port 4600 will be used.
⍝ More than one task can be started. Subsequent tasks should use a different
⍝ port number. If none is supplied again the class will use 4601 and so on.
⍝ To start a new task on a specific IP address or with special environment
⍝ variables (e.g. MAXWS=3G,...) use 
⍝    T←⎕NEW RIDE '+address=... +port=... +params=...' 

⍝ Once a task has started you can control it with the Execute method, e.g.
⍝    T.Execute ')LIB'

⍝ This version brings in DRC and HTTPUtils if they are not available at the same level

    ⎕io←⎕ml←1
    (CR NL)←⎕ucs 13 10 

    :field BUFFER←''
    :field public CConn ⍝ Conga connection
    :field public shared MinRIDEport←4600
    :field public shared DEBUG←0 ⍝ set to 1 to trace
    Trace←{DEBUG:⎕←⍵⋄⍵}

    getLen←⍎'{323 ⎕dr ',(1↑83 ⎕dr 256)↓'⌽4↑⍵}'
    addHead←{0∊⍴⍵:⍵ ⋄ ('RIDE',⍵),⍨⎕ucs(4/256)⊤8+≢⍵}
     
   ⍝ To make this code independent of the presence of DRC's presence we do
    def←{0≠##.⎕nc'DRC':0    ⍝ to prevent a VALUE error when defining this class
      ⎕←')COPYing DRC'
     ⍎⎕fx'r←CY' 'r←1' '(↑''DRC'' ''HTTPUtils'')##.⎕cy''conga'''
     }
    def 0

    (U DRC)←##.(HTTPUtils DRC) 
    
    ∇ Here
      :Access public
      :Implements constructor
      Contact'127.0.0.1' 0 ⍬
    ∇

    ∇ SameMachine port;arg
      :Access public
      :Implements constructor
      :If 3=10|⎕DR port
          Contact'127.0.0.1'port ⍬
      :Else
          arg←(⎕NEW ⎕SE.Parser'+port= +host= +aplparms= +debug').Parse port
          DEBUG←arg.debug
          Contact arg.(host port aplparms)
      :EndIf
    ∇

    ∇ DifferentMachine(host port)
      :Access public
      :Implements constructor
      Contact host port ⍬
    ∇

    ∇ Contact(host port aplparms);cmd;r;_;tm1;tm2;⎕USING;APL;P;params;sign
      {}DRC.Init''
     ⍝ A <0 port # means "don't start a new task"
      :If port≥0 ⍝ then start a new APL task using
          :If port=0
              port←MinRIDEport ⋄ MinRIDEport+←1
          :EndIf
          APL←1⊃2 ⎕NQ'.' 'getcommandlineargs' ⍝ pick the same interpreter
          ⎕USING←'System.Diagnostics,system.dll'
         ⍝ We can supply other parameters like MAXWS
          params←{b\⍵/⍨b←⍵≠','}aplparms~0
          P←Process.Start APL(params,' RIDE_INIT=serve::',⍕port)
          ⎕DL 0.3
          :If P.HasExited
              ...
          :EndIf
      :EndIf 
      port←|port
      :If 0∊host,⍴host ⋄ host←'127.0.0.1' ⋄ :EndIf
      :If 0=⊃(_ CConn)←2↑r←DRC.Clt''host port'Text' 100000
          tm1←'SupportedProtocols=2' ⋄ tm2←'UsingProtocol=2'
      :AndIf 0=1⊃r←Trace Send tm1
    ⍝  :AndIf ∧/(2⊃r)∊tm1 tm2
      :AndIf 0=1⊃r←Trace Send tm2
    ⍝  :AndIf ∧/(2⊃r)∊tm1 tm2
      :AndIf 0=1⊃r←Trace Send'["Identify",{"identity":1}]'
      :AndIf 0=1⊃r←Trace Send'["Connect",{"remoteId":2}]'
      :AndIf 0=1⊃r←Trace Send'["GetWindowLayout",{}]'
     ⍝ The contact should have been properly established
     ⍝ Let's verify that:
          r←¯1 (1⌽')Unable to establish proper connection (tried ',sign←'¨¯<⍒⍋⌽⍫')
      :AndIf (sign,CR)≡P←Execute'⎕ucs ',⍕⎕UCS sign
          ⎕←'New APL task started on port ',⍕port
      :Else
          ('Connection failed ',,⍕r)⎕SIGNAL 11
      :EndIf
     
      ⎕DF host,':',⍕port
    ∇

    ∇ r←Send msg;wr;HTTPUtils;len;fromutf8;done;r1;data
      :Access public
      fromutf8←{0::(⎕AV,'?')[⎕AVU⍳⍵] ⋄ ⎕UCS'UTF-8'⎕UCS ⍵} ⍝ Turn raw UTF-8 input into text
      r←0 '(no answer?)'
      :If 0=⊃wr←DRC.Send CConn(addHead fromutf8 msg)
          data←⍴done←len←0 ⋄ r1←1 ⍝ 1st run
          :Repeat
              :If ~done←0≠1⊃wr←DRC.Wait CConn(⌊2000*r1)       ⍝ Wait up to 5 secs
                  :If wr[3]∊'Block' 'BlockLast'               ⍝ If we got some data
                      :If 8≤≢BUFFER←BUFFER,4⊃wr
                          {}÷'RIDE'≡4↑4↓BUFFER ⍝ are we talking to the right entity?
                          :While (len←getLen BUFFER)≤≢BUFFER
                              data,←⊂'UTF-8'⎕UCS⎕UCS 8↓len↑BUFFER ⋄ BUFFER←len↓BUFFER
                          :EndWhile
                      :EndIf
                  :Else
                      ⎕←wr ⍝ Error?
                      ∘∘∘
                  :EndIf
              :EndIf
              r1←0.2
     
          :Until done
          r←0 data
      :Else
          r←1('Connection failed ',,⍕wr)
      :EndIf
    ∇

    JS←7159⌶

    ∇ answer←Execute expression;answer;list;what;ans;gotit
      :Access public
      list←Send'["Execute",{"text":"',expression,'\n"}]'
      answer←⍴gotit←0
    ⍝ Several responses are possible, mixed
      :While 0=1⊃Trace list
          :For ans :In 2⊃list
              :Select 1⊃(what what)←JS ans
              :Case 'CanAcceptInput'
              :Case 'SetPromptType'
                  gotit←×what.type ⍝ ≥1 means we can
              :Case 'AppendSessionOutput'
                  answer,←{NL=¯1↑⍵:(¯1↓⍵),CR ⋄ ⍵} what.result
              :Case 'FocusThread'
              :Case 'EchoInput'
              :Case 'HadError'
              :Case 'Identify'
              :case'Disconnect'
              ⎕←what.message
              :Else
                  ⎕←'Unknown command: ',ans
              :EndSelect
          :EndFor
          :If ~gotit ⍝ then ask for some more
              gotit←0 ⍬≡list←Send'["CanSessionAcceptInput",{}] '
          :EndIf
      :Until gotit
    ∇

    ∇ terminate
      :Implements destructor 
      {}Send'⎕OFF'
      {}DRC.Close CConn
    ∇

:Endclass
