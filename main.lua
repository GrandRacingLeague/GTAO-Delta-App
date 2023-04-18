--DELTA APP ERROR
openProcess'GTA5.exe'
autoAssemble([[
unregistersymbol(adr)
unregistersymbol(TimesPTR)]])
FL.InitPanel.Visible=true
form_show(FL)
markMyRid = -1
LoadedTime = false
ADR = 0
Metrics = 1
SpeedStatus = 1
Gears = 1
Inputs = 1

function InitOffsets()
  pCNetPlayerInfo = 0xA0
  pCNetPed = 0x1E8
  oNumPlayers = 0x180
  oRid = 0x090
  pCPed = 0x8
  pCPlayerInfo = 0x10A8
  oCurCheck = 0x11558 --11830  11110 0x10F48 --119C8 tomo | 11568
  oCurLap = 0x11550   --11828  118280 11108 x10F40 --119C0 tomo | 11560
end

InitOffsets()

--Check player ID

function GetPTRs()
  autoAssemble([[
  aobscanmodule(WorldPTR,GTA5.exe,48 8B 05 ? ? ? ? 45 ? ? ? ? 48 8B 48 08 48 85 C9 74 07)
  registersymbol(WorldPTR)
  aobscanmodule(PlayerCountPTR,GTA5.exe,48 8B 0D ? ? ? ? E8 ? ? ? ? 48 8B C8 E8 ? ? ? ? 48 8B CF)
  registersymbol(PlayerCountPTR)
  aobscanmodule(UnkPTR,GTA5.exe,48 39 3D ? ? ? ? 75 2D)
  registerSymbol(UnkPTR)
  ]])
  addr=getAddress("WorldPTR")
  addr=addr+readInteger(addr+3)+7
  unregisterSymbol("WorldPTR")
  registerSymbol("WorldPTR", addr, true)
  WorldPTR = readQword("WorldPTR")

  addr=getAddress("PlayerCountPTR")
  addr=addr+readInteger(addr+3)+7
  unregisterSymbol("PlayerCountPTR")
  registerSymbol("PlayerCountPTR", addr, true)
  WorldPTR = readQword("PlayerCountPTR")

  UnkPTR=getAddress('UnkPTR') UnkPTR = UnkPTR + readInteger(UnkPTR + 3) + 7
  unregisterSymbol('UnkPTR') registerSymbol('UnkPTR',UnkPTR,true)
  UNK = readQword("UnkPTR")
  end

  function mark_MYRid()
  local contest = getAddressSafe('WorldPTR')

  local ridaddr = "[[[WorldPTR]+pCPed]+pCPlayerInfo]+oRid"

  local testy = readPointer(ridaddr)

  if not testy then
  else
    markMyRid = testy
  end
end

function FoundMyCurrentID()
  local CNetworkPlayerMgr=readPointer("PlayerCountPTR")
  if markMyRid == -1 then mark_MYRid() end
  --Never use goto kids. This isn't my function.
  for i=0,32,1 do
    local CNetGamePlayer = readPointer(CNetworkPlayerMgr + oNumPlayers + (i*8))
    if not CNetGamePlayer then
      goto continue
    end
    local CPlayerInfo = readPointer(CNetGamePlayer + pCNetPlayerInfo)
    if not CPlayerInfo then
      goto continue
    end
    local CPed = readPointer(CPlayerInfo + pCNetPed)
    if not CPed or CPed == 0 then
      goto continue
    end
    local ORGRid = readPointer(CPlayerInfo + oRid)
    if ORGRid == markMyRid then
      MyIDNumber = i
      goto found
    end
    ::continue::
  end
  ::found::
end

function Fetch()
  GetPTRs()
  FoundMyCurrentID()
end

function ActivateApp()
  FL.Enable.Caption = "Activating app"
  FL.InitPanel.Enabled=false
  FL.InitPanel.Visible=false
  FL.StartDetect.Enabled=true
  NewCheckpoint=true
  NewSector=true
  DeltaMils=1
  FirstLap=true
  Enable=false
  LogsEnabled=false
  FL.FormStyle = 'fsSystemStayOnTop'
  Speed = createTimer(nil, false)
  timer_onTimer(Speed, ReadSpeed)
  timer_setInterval(Speed, 50)
  timer_setEnabled(Speed, true)
end


function InitTrackInfo()
  --Build Sectors
  S1_raw=0
  S2_raw=0
  S3_raw=0
  MaxCheckpoints = readInteger('adr + CBF40') --new D 16C0 del prev 97C60 928
  local Track_Name = readString('adr + DE218')
  FL.Caption = Track_Name.." DeltaApp by Vi'o'lence"
  CurLapLastCheckpointTime = 0
  LastCheckpoint = 100
  CurrentLapSectors = {}
  FastLapSectors = {}
  if LoadedTime == false then
    for i=0,MaxCheckpoints-1 do
      CurrentLapSectors[i]=0
      FastLapSectors[i]=10000000
    end
    LatestFastLapSectors=10000000
  else
    for i=0,MaxCheckpoints-1 do
      CurrentLapSectors[i]=0
    end
    LatestFastLapSectors=FastLapSectors[0]
    FirstLap=false
  end
  S1 = MaxCheckpoints//3
  S2 = S1 + MaxCheckpoints//3
  S3 = 0
  Fetch()
end

function CloseToTheEnd()
  if CurCheckpoint==MaxCheckpoints-1 and CurLapMils>1000 then
    if NewCheckpoint==true then
      CurrentLapSectors[MaxCheckpoints-1]=CurLapMils
      NewCheckpoint=false
      CanWrite=true
    end
    CurLapLastCheckpointTime=CurLapMils
  end
end

--CloseToTheEnd
function NewC()
  if NewCheckpoint==true and CurCheckpoint>0 then
    if CurCheckpoint ~= MaxCheckpoints-1 then
      CurrentLapSectors[CurCheckpoint]=CurLapMils
      NewCheckpoint=false
    else
      CloseToTheEnd()
    end
    LastCheckpoint=CurCheckpoint
  end
end

--NewC
function Drive()
  if LastCheckpoint ~= CurCheckpoint then
    NewCheckpoint = true
    NewSector=true
    NewC()
  end
end

function NewLapProcedure()
  if CurCheckpoint == 0 and LastCheckpoint ~= 0 and CurLapLastCheckpointTime ~= 0 then
    CurrentLapSectors[0] = CurLapLastCheckpointTime
    --LOGS
    if LogsEnabled == true and CanWrite==true then
      --Record laptime
      LogsLaptime = CurLapLastCheckpointTime
      --Record Sectors
      LogsSector1 = S1_raw
      LogsSector2 = S2_raw
      LogsSector3 = CurLapLastCheckpointTime-S1_raw-S2_raw
      --RecordLap
      CurrentLap = readInteger(ChecksPTR + oCurLap + (MyIDNumber*0x658))
      LogsLap = CurrentLap - 1
      local SpeedTrap = GetSpeed()
      --LogArray=LogArray.."Lap №"..LogsLap..": Lap time - "..LogsLaptime.."\n".." With sectors: S1-"..LogsSector1.." S2-"..LogsSector2.." S3-"..LogsSector3.."\n"
      LogArray = LogArray..LogsLap..", "..LogsLaptime..", "..SpeedTrap..", "..((SpeedTrap/1.6)*10//1/10)..", "..TopSpeed..", "..((TopSpeed/1.6)*10//1/10)..", "..AvgSpeed..", "..((AvgSpeed/1.6)*10//1/10)..", "..LogsSector1..", "..LogsSector2..", "..LogsSector3.."\n"
      TopSpeed = 0
      AvgSpeed = nil
      CanWrite = false
    end
      --LOGS
    FirstLap = false
    if CurrentLapSectors[0] < FastLapSectors[0] then
      LatestFastLapSectors = FastLapSectors[0]
      for i=0,MaxCheckpoints-1 do
        FastLapSectors[i] = CurrentLapSectors[i]
      end
    end
  end
end

function UpdateInfo()

  if Enable == true then
    Enable = false
    FL.StartDetect.Caption='START'
    if LogsEnabled ==true then
      PackLogs()
      LogsSwitcher()
    end
    LoadedTime = false
    FL.LoadFLButton.Enabled = false
    FL.LogBuildingButton.Enabled = false
    FL.Caption = "DeltaApp by Vi'o'lence"
  elseif Enable == false then
    UpdateCar()
    InitTrackInfo()
    Enable = true
    FL.StartDetect.Caption='STOP'
    ChecksPTR = getAddress('TimesPTR')
    ForLogs_TrackName=readString('adr + DE218') --new E3998 del 3A388 prev A9610
    if LogsEnabled == true then
      CanWrite=false
    end
    LogArray=''
    TopSpeed=0
    AvgSpeed=nil
    FL.LogBuildingButton.Enabled = true
    FL.SaveFLButton.Enabled = true
    FL.LoadFLButton.Enabled = true
  end

  local timer_ps = createTimer()
  timer_ps.Interval = 1
  timer_ps.OnTimer =
  function (ps)

    if Enable == true then
      --Take values
      CurLapMils = readInteger('TimesPTR - 250') --3D0 basic
      --FastLapMils = readInteger('TimesPTR + 11228') --EA10 E960
      CurCheckpoint = readInteger(ChecksPTR + oCurCheck + (MyIDNumber*0x670)) --7598 74E8
      --print(CurCheckpoint)
      FL.LapProgress.Position=(((CurCheckpoint)*100)/MaxCheckpoints)

      --Checks
      Drive()
      CloseToTheEnd()
      NewLapProcedure()

      --Display
      if FirstLap==false then

        if CurCheckpoint==0 then
          DeltaMils=CurrentLapSectors[0]-LatestFastLapSectors
        else
          DeltaMils=CurrentLapSectors[CurCheckpoint]-FastLapSectors[CurCheckpoint]
        end

        if DeltaMils>9999 then

          FL.DeltaLabel.Caption="+ 9.999"
          FL.DeltaLabel.Font.Color=clRed

        elseif DeltaMils>0 then

          if (DeltaMils-1000*(DeltaMils//1000))<10 then
            FL.DeltaLabel.Caption='+'..(DeltaMils//1000)..'.00'..(DeltaMils-1000*(DeltaMils//1000))
          elseif (DeltaMils-1000*(DeltaMils//1000))<100 then
            FL.DeltaLabel.Caption='+'..(DeltaMils//1000)..'.0'..(DeltaMils-1000*(DeltaMils//1000))
          else
            FL.DeltaLabel.Caption='+'..(DeltaMils//1000)..'.'..(DeltaMils-1000*(DeltaMils//1000))
          end
          FL.DeltaLabel.Font.Color=clRed

        elseif DeltaMils<-9999 then

          FL.DeltaLabel.Caption="- 9.999"
          FL.DeltaLabel.Font.Color=clLime

        elseif DeltaMils<0 then

          DeltaMils=DeltaMils*(-1)
          if (DeltaMils-1000*(DeltaMils//1000))<10 then
            FL.DeltaLabel.Caption='-'..(DeltaMils//1000)..'.00'..(DeltaMils-1000*(DeltaMils//1000))
          elseif (DeltaMils-1000*(DeltaMils//1000))<100 then
            FL.DeltaLabel.Caption='-'..(DeltaMils//1000)..'.0'..(DeltaMils-1000*(DeltaMils//1000))
          else
            FL.DeltaLabel.Caption='-'..(DeltaMils//1000)..'.'..(DeltaMils-1000*(DeltaMils//1000))
          end
          FL.DeltaLabel.Font.Color=clLime

        elseif DeltaMils==0 then
          FL.DeltaLabel.Caption="0.000"
          FL.DeltaLabel.Font.Color=clWhite

        end
      end

      --If you read this and trying to understand it, know... you are awesome

      --FREEZE Last Lap
      if CurCheckpoint~=0 then

        local TimeStamp=FastLapSectors[0]

        --Display laptime info
        CalcMins = CurLapMils//60000
        CalcSec = (CurLapMils - (60000*CalcMins))//1000
        CalcMils = (CurLapMils - (CalcMins*60000) - (CalcSec*1000))
        if CalcMils<10 then
          FL.CurrentLapValue.Caption=CalcMins..':'..CalcSec..'.00'..CalcMils
        elseif CalcMils<100 then
          FL.CurrentLapValue.Caption=CalcMins..':'..CalcSec..'.0'..CalcMils
        else
          FL.CurrentLapValue.Caption=CalcMins..':'..CalcSec..'.'..CalcMils
        end

        FCalcMins = TimeStamp//60000
        FCalcSec = (TimeStamp - (60000*FCalcMins))//1000
        FCalcMils = (TimeStamp - 60000*FCalcMins - 1000*FCalcSec)
        if FCalcMils<10 then
          FL.FastestLapValue.Caption=FCalcMins..':'..FCalcSec..'.00'..FCalcMils
        elseif FCalcMils<100 then
          FL.FastestLapValue.Caption=FCalcMins..':'..FCalcSec..'.0'..FCalcMils
        else
          FL.FastestLapValue.Caption=FCalcMins..':'..FCalcSec..'.'..FCalcMils
        end

      elseif CurCheckpoint==0 then

        --NewLapProcedure()
        local TimeStamp=FastLapSectors[0]
        CalculateMins = CurLapLastCheckpointTime//60000
        CalculateSec = (CurLapLastCheckpointTime - (60000*CalculateMins))//1000
        CalculateMils = (CurLapLastCheckpointTime - 60000*CalculateMins - 1000*CalculateSec)
        if CalculateMils<10 then
          FL.CurrentLapValue.Caption=CalculateMins..':'..CalculateSec..'.00'..CalculateMils
        elseif CalculateMils<100 then
          FL.CurrentLapValue.Caption=CalculateMins..':'..CalculateSec..'.0'..CalculateMils
        else
          FL.CurrentLapValue.Caption=CalculateMins..':'..CalculateSec..'.'..CalculateMils
        end

        FCalculateMins = TimeStamp//60000
        FCalculateSec = (TimeStamp - (60000*FCalculateMins))//1000
        FCalculateMils = (TimeStamp - 60000*FCalculateMins - 1000*FCalculateSec)
        if FCalculateMils<10 then
          FL.FastestLapValue.Caption=FCalculateMins..':'..FCalculateSec..'.00'..FCalculateMils
        elseif FCalculateMils<100 then
          FL.FastestLapValue.Caption=FCalculateMins..':'..FCalculateSec..'.0'..FCalculateMils
        else
          FL.FastestLapValue.Caption=FCalculateMins..':'..FCalculateSec..'.'..FCalculateMils
        end

      end

      --Detect Sector's marks
      local TimeSectors=CurLapMils
      if CurCheckpoint == S1 and NewSector==true then
        S1_raw = TimeSectors
        if S3_raw ~= 0 then
          S2_raw=0
          S3_raw=0
        end
        NewSector=false
      elseif CurCheckpoint == S2 and NewSector==true then
        S2_raw = TimeSectors - S1_raw
        NewSector=false
      elseif CurCheckpoint == 0 and S2_raw ~= 0 and S1_raw ~= 0 and NewSector==true then
        S3_raw = CurLapLastCheckpointTime - S1_raw - S2_raw
        NewSector=false
      end

      --Convert milis in time for Sectors
      S1_sec = S1_raw//1000
      S1_mil = S1_raw - 1000*S1_sec

      S2_sec = S2_raw//1000
      S2_mil = S2_raw - 1000*S2_sec

      S3_sec = S3_raw//1000
      S3_mil = S3_raw - 1000*S3_sec

      --Display Sector info

      if S1_mil<10 then
        FL.S1Label.Caption=S1_sec..'.00'..S1_mil
        if S1_mil<100 then
          FL.S1Label.Caption=S1_sec..'.0'..S1_mil
        end
      else
        FL.S1Label.Caption=S1_sec..'.'..S1_mil
      end

      if S2_mil<10 then
        FL.S2Label.Caption=S2_sec..'.00'..S2_mil
        if S2_mil<100 then
          FL.S2Label.Caption=S2_sec..'.0'..S2_mil
        end
      else
        FL.S2Label.Caption=S2_sec..'.'..S2_mil
      end

      if S3_mil<10 then
        FL.S3Label.Caption=S3_sec..'.00'..S3_mil
        if S3_mil<100 then
          FL.S3Label.Caption=S3_sec..'.0'..S3_mil
        end
      else
        FL.S3Label.Caption=S3_sec..'.'..S3_mil
      end

    end
  end
end

--STARTUP FUNCS

function FindAdr()
  FL.Enable.Caption = "Scanning memory 1/3"
  local results = AOBScan('02 00 00 00 ?? 0? 00 00 FF FF FF FF 00 00 00 00 00 00 00 00 ?? 0? 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ?? 0? 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00', '*X*C*W', 2, '000')
  assert(results, 'aobscan failed')
  local addr = results[0]
  results.destroy()
  registerSymbol('adr',addr)
end

function FindTimes()
  FL.Enable.Caption = "Scanning memory 2/3"
  local results = AOBScan('FF FF FF FF 00 00 00 00 00 00 00 00 ?? 0? 00 00 08 00 00 00 00 00 00 00 05 00 00 00 00 00 00 00 ?? ?? ?? ?? 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 EC FF FF FF ?? 0?', '-X-C+W', 2, '8')
  assert(results, 'aobscan failed')
  local addr = results[0]
  results.destroy()
  registerSymbol('TimesPTR',addr)
end

function FindCar()
  FL.Enable.Caption = "Scanning memory 3/3"
  autoAssemble([[
  aobscanmodule(WorldPTR,GTA5.exe,48 8B 05 ? ? ? ? 45 ? ? ? ? 48 8B 48 08 48 85 C9 74 07)
  registersymbol(WorldPTR)
  ]])
  addr=getAddress("WorldPTR")
  addr=addr+readInteger(addr+3)+7
  unregisterSymbol("WorldPTR")
  registerSymbol("WorldPTR", addr, true)
  PTR = readQword("WorldPTR")
  --CarNameADR = getAddress("[[[PTR+8]+D10]+20]+298")
  --CarNameCurrent = readString(CarNameADR)
  --284EA541160
end

function UpdateCar()
  if CarNameCurrent ~= readString(CarNameADR) then CarNameCurrent = readString(CarNameADR) end
end

function LogsSwitcher()
  if LogsEnabled == false then
    LogsEnabled=true
    FL.LogBuildingButton.Caption = 'LOGS ON'
    LastElement = 100
  else
    LogsEnabled=false
    FL.LogBuildingButton.Caption = 'LOGS OFF'
  end
end

function PackLogs()
  local ForLogs_TrackName = readString('adr + DE218')
  local save_dialog = createSaveDialog(self)
  save_dialog.InitalDir = os.getenv('%USERPROFILE%')
  if save_dialog.execute() then
    local s=(save_dialog.FileName..'.csv')
    file = io.open(s, "a+")
    CurrentDate=os.date("%x")
    file:write(ForLogs_TrackName.."\n")
    file:write(CurrentDate.."\n")
    file:write("Lap, Laptime, Speed_S/F(KPH), Speed_S/F(MPH), TopSpeed(KPH), TopSpeed(MPH), AverageSpeed(KPH), AverageSpeed(MPH), S1, S2, S3".."\n")
    file:write(LogArray)
    file:close()
  end
end

function ShowTime()
       local TimeStamp=FastLapSectors[0]
        local FMins = TimeStamp//60000
        FSec = (TimeStamp - (60000*FMins))//1000
        FMils = (TimeStamp - 60000*FMins - 1000*FSec)
        if FMils<10 then
          FL.SaveFLButton.Caption=FMins..':'..FSec..'.00'..FMils
        elseif FMils<100 then
          FL.SaveFLButton.Caption=FMins..':'..FSec..'.0'..FMils
        else
          FL.SaveFLButton.Caption=FMins..':'..FSec..'.'..FMils
        end
end

function RevertCaption()
         FL.SaveFLButton.Caption="SAVE LAP"
end

function SaveFastLap()
  local FLdata = ""
  for i=0,MaxCheckpoints-1 do
      FLdata = FLdata..FastLapSectors[i].."\n"
  end
  local TrackName = readString('adr + DE218')
  local save_dialog = createSaveDialog(self)
  save_dialog.InitalDir = os.getenv('%USERPROFILE%')
  if save_dialog.execute() then
    local s=(save_dialog.FileName..'.HOTLAP')
    file = io.open(s, "a+")
    CurrentDate=os.date("%x")
    file:write(TrackName..'\n')
    file:write(FLdata..'\n')
    file:close()
  end
end

function TestFL()
  local FLdata = ""
  for i=0,MaxCheckpoints-1 do
      FLdata = FLdata .. tostring(FastLapSectors[i]).."\n"
  end
  print(FLdata)
end

function LoadFastLap()
     load_dialog = createOpenDialog(self)
     load_dialog.InitalDir = os.getenv('%USERPROFILE%')
     if load_dialog.execute() then
     file = io.open(load_dialog.FileName, "r")
     local Track = tostring(file:read())
     if Track == readString('adr + DE218') then
        for i=0,MaxCheckpoints-1 do
            FastLapSectors[i] = tonumber(file:read())
        end
     LoadedTime = true
     end
     end
end

function Startup()
  --StartHotkey = createHotkey(UpdateInfo,VK_DOWN)
  FL.Enable.Enabled = false
  FindAdr()
  FindTimes()
  FindCar()
  ActivateApp()
  if FL.SteamVersion.Checked == true then ADR = 0 end
  if FL.NonSteamVersion.Checked == true then ADR = 1 end
end

function RescanUNK()
    if UNK ~= readQword("UnkPTR") then
      autoAssemble([[
        aobscanmodule(UnkPTR,GTA5.exe,48 39 3D ? ? ? ? 75 2D)
        registerSymbol(UnkPTR)
      ]])
      UnkPTR=getAddress('UnkPTR') UnkPTR=UnkPTR+readInteger(UnkPTR+3)+7
      unregisterSymbol('UnkPTR') registerSymbol('UnkPTR',UnkPTR,true)
      UNK = readQword("UnkPTR")
    end
end

function ShowHideSettings()
  if FL.SettingPanel.Visible == true then
     FL.SettingPanel.Visible = false
     FL.SettingPanel.Enable = false
  else
     FL.SettingPanel.Visible = true
     FL.SettingPanel.Enable = true
  end
end

function ChangeMetrics()
  if Metrics == 1 then
     Metrics = 0
     FL.MetricsTurnOn.Caption = "SPEED: MPH"
  elseif Metrics == 0 then
     Metrics = 1
     FL.MetricsTurnOn.Caption = "SPEED: KPH"
  end
end

function ChangeSpeed()
  if SpeedStatus == 1 then
     SpeedStatus = 0
     FL.SpeedTurnOn.Caption = "SPEED: OFF"
     FL.SpeedLabel.Visible = false
  elseif SpeedStatus == 0 then
     SpeedStatus = 1
     FL.SpeedTurnOn.Caption = "SPEED: ON"
     FL.SpeedLabel.Visible = true
  end
end

function ChangeGears()
  if Gears == 1 then
     Gears = 0
     FL.GearsTurnOn.Caption = "GEARS: OFF"
     FL.GearLabel.Visible = false
  elseif Gears == 0 then
     Gears = 1
     FL.GearsTurnOn.Caption = "GEARS: ON"
     FL.GearLabel.Visible = true
  end
end

function ChangeInputs()
  if Inputs == 1 then
     Inputs = 0
     FL.InputsTurnOn.Caption = "INPUT: OFF"
     FL.Gas.Visible = false
     FL.Brake.Visible = false
     FL.Steer.Visible = false
  elseif Inputs == 0 then
     Inputs = 1
     FL.InputsTurnOn.Caption = "INPUT: ON"
     FL.Gas.Visible = true
     FL.Brake.Visible = true
     FL.Steer.Visible = true
  end
end

function GetSpeed()
   if ADR == 0 then
       Speed = readFloat("GTA5.exe+2669A48")
       if Speed ~= nil then
         if Metrics == 1 then
            Speed = Speed * 10 //1 /10
            return Speed
         else
             Speed = Speed/1.6
             Speed = Speed * 10 //1 /10
             return Speed
         end
       end
    elseif ADR == 1 then
       Speed = readFloat("GTA5.exe+2669A48")
       if Speed ~= nil then
         if Metrics == 1 then
            Speed = Speed * 10 //1 /10
            return Speed
         else
             Speed = Speed/1.6
             Speed = Speed * 10 //1 /10
             return Speed
         end
       end
    end
end

function ReadSpeed()
  local Speed = 0
  if SpeedStatus == 1 then
    if ADR == 0 then
       Speed = readFloat("GTA5.exe+2669A48")
       if Speed ~= nil then
         if Metrics == 1 then
            Speed = Speed * 10 //1 /10
            FL.SpeedLabel.Caption = "Kph: "..Speed
         else
             Speed = Speed/1.6
             Speed = Speed * 10 //1 /10
             FL.SpeedLabel.Caption = "Mph: "..Speed
         end
         if LogsEnabled == true and Enable == true then
           if Speed > TopSpeed  then TopSpeed = Speed end
           if AvgSpeed == nil then AvgSpeed = Speed
           else AvgSpeed = ((AvgSpeed + Speed)/2)*10//1/10
           end
         end
       end
    elseif ADR == 1 then
       Speed = readFloat("GTA5.exe+2669A48")
       if Speed ~= nil then
         if Metrics == 1 then
            Speed = Speed * 10 //1 /10
            FL.SpeedLabel.Caption = "Kph: "..Speed
         else
             Speed = Speed/1.6
             Speed = Speed * 10 //1 /10
             FL.SpeedLabel.Caption = "Mph: "..Speed
         end
         if LogsEnabled == true and Enable == true then
           if Speed > TopSpeed  then TopSpeed = Speed end
           if AvgSpeed == nil then AvgSpeed = Speed
           else AvgSpeed = ((AvgSpeed + Speed)/2)*10//1/10
           end
         end
       end
    end
  end

  if Gears == 1 then
     RescanUNK()
     local RPM = readFloat("UNK+E50")
     local Gear = readInteger("UNK+FD4")
     if Gear and RPM then
        if Gear == 0 then FL.GearLabel.Caption = "N" end
        if Gear == 0 and Speed < 0 then FL.GearLabel.Caption = "R" end
        if Gear > 0 then FL.GearLabel.Caption = Gear end
        if RPM > 0.5 then FL.RPM1.Visible = true
           if RPM > 0.7 then FL.RPM2.Visible = true
              if RPM > 0.8 then FL.RPM3.Visible = true
                 if RPM > 0.9 then FL.RPM4.Visible = true
                   if RPM > 0.96 then FL.GearLabel.Font.Color = clRed
                   else FL.GearLabel.Font.Color = clWhite
                   end
                 else FL.RPM4.Visible = false
                 end
              else
                  FL.RPM3.Visible = false
                  FL.RPM4.Visible = false
              end
           else
             FL.RPM2.Visible = false
             FL.RPM3.Visible = false
             FL.RPM4.Visible = false
           end
        else
          FL.RPM1.Visible = false
          FL.RPM2.Visible = false
          FL.RPM3.Visible = false
          FL.RPM4.Visible = false
        end
     end
  else
    FL.RPM1.Visible = false
    FL.RPM2.Visible = false
    FL.RPM3.Visible = false
  end

  if Inputs == 1 then
     local SteerPos = readFloat("UNK+CA8")
     local BrakePos = readFloat("GTA5.exe+25B904C")
     local ThrottlePos = readFloat("GTA5.exe+25B9004")
     if SteerPos ~= nil then
       if SteerPos < 0 then
          FL.Steer.Position = (((SteerPos * (-1) *50) + 50) // 1)
       elseif SteerPos > 0 then
              FL.Steer.Position = ((50 - (SteerPos *50)) // 1)
       else
           FL.Steer.Position = 50
       end
     end
     FL.Brake.Caption = BrakePos * 100 // 1
     FL.Gas.Caption = ThrottlePos * 100 // 1
  end

end

function ex()
  CloseCE()
end
