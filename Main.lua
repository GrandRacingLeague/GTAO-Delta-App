openProcess'GTA5.exe'
autoAssemble([[
unregistersymbol(adr)
unregistersymbol(TimesPTR)]])
FL.InitPanel.Visible=true
form_show(FL)
markMyRid = -1

function InitOffsets()
  pCNetPlayerInfo = 0xA0
  pCNetPed = 0x1E8
  oNumPlayers = 0x180
  oRid = 0x090
  pCPed = 0x8
  pCPlayerInfo = 0x10C8
  oCurCheck = 0x11110 --0x10F48 --119C8 tomo | 11568
  oCurLap = 0x11108 --0x10F40 --119C0 tomo | 11560
end

InitOffsets()

--Check player ID

function GetPTRs()
  autoAssemble([[
  aobscanmodule(WorldPTR,GTA5.exe,48 8B 05 ? ? ? ? 45 ? ? ? ? 48 8B 48 08 48 85 C9 74 07)
  registersymbol(WorldPTR)
  aobscanmodule(PlayerCountPTR,GTA5.exe,48 8B 0D ? ? ? ? E8 ? ? ? ? 48 8B C8 E8 ? ? ? ? 48 8B CF)
  registersymbol(PlayerCountPTR)
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
end


function InitTrackInfo()
  --Build Sectors
  S1_raw=0
  S2_raw=0
  S3_raw=0
  MaxCheckpoints = readInteger('adr + 97C60')
  CurLapLastCheckpointTime = 0
  LastCheckpoint = 100
  CurrentLapSectors = {}
  FastLapSectors = {}
  for i=0,MaxCheckpoints-1 do
    CurrentLapSectors[i]=0
    FastLapSectors[i]=10000000
  end
  LatestFastLapSectors=10000000
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
  if CurCheckpoint == 0 and LastCheckpoint~=0 and CurLapLastCheckpointTime~=0 then
    CurrentLapSectors[0]=CurLapLastCheckpointTime
    --LOGS
    if LogsEnabled == true and CanWrite==true then
      --Record laptime
      LogsLaptime=CurLapLastCheckpointTime
      --Record Sectors
      LogsSector1=S1_raw
      LogsSector2=S2_raw
      LogsSector3=CurLapLastCheckpointTime-S1_raw-S2_raw
      --RecordLap
      CurrentLap = readInteger(ChecksPTR + oCurLap + (MyIDNumber*0x658))
      LogsLap = CurrentLap - 1
      LogArray=LogArray.."Lap №"..LogsLap..": Lap time - "..LogsLaptime.."\n".." With sectors: S1-"..LogsSector1.." S2-"..LogsSector2.." S3-"..LogsSector3.."\n"
      CanWrite=false
    end
      --LOGS
    FirstLap=false
    if CurrentLapSectors[0]<FastLapSectors[0] then
      LatestFastLapSectors=FastLapSectors[0]
      for i=0,MaxCheckpoints-1 do
        FastLapSectors[i]=CurrentLapSectors[i]
      end
    end
  end
end

function UpdateInfo()

  if Enable == true then
    Enable = false
    FL.StartDetect.Caption='Start'
    if LogsEnabled ==true then
      PackLogs()
      LogsSwitcher()
    end
  elseif Enable == false then
    UpdateCar()
    InitTrackInfo()
    Enable = true
    FL.StartDetect.Caption='Stop'
    ChecksPTR = getAddress('TimesPTR')
    ForLogs_CarName=CarNameCurrent
    ForLogs_TrackName=readString('adr + A9610')
    if LogsEnabled == true then
      CanWrite=false
      LogArray=''
    end
  end

  local timer_ps = createTimer()
  timer_ps.Interval = 1
  timer_ps.OnTimer =
  function (ps)

    if Enable == true then
      --Take values
      CurLapMils = readInteger('TimesPTR - 250') --3D0 basic
      --FastLapMils = readInteger('TimesPTR + 11228') --EA10 E960
      CurCheckpoint = readInteger(ChecksPTR + oCurCheck + (MyIDNumber*0x658)) --7598 74E8
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
  local results = AOBScan('02 00 00 00 ?? 0? 00 00 FF FF FF FF 00 00 00 00 00 00 00 00 ?? 0? 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ?? 0? 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00', '*X*C*W', 2, '000')
  assert(results, 'aobscan failed')
  local addr = results[0]
  results.destroy()
  registerSymbol('adr',addr)
end

function FindTimes()
  local results = AOBScan('FF FF FF FF 00 00 00 00 00 00 00 00 ?? 0? 00 00 08 00 00 00 00 00 00 00 05 00 00 00 00 00 00 00 ?? ?? ?? ?? 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 EC FF FF FF ?? 0?', '-X-C+W', 2, '0')
  assert(results, 'aobscan failed')
  local addr = results[0]
  results.destroy()
  registerSymbol('TimesPTR',addr)
end

function FindCar()
  autoAssemble([[
  aobscanmodule(WorldPTR,GTA5.exe,48 8B 05 ? ? ? ? 45 ? ? ? ? 48 8B 48 08 48 85 C9 74 07)
  registersymbol(WorldPTR)
  ]])
  addr=getAddress("WorldPTR")
  addr=addr+readInteger(addr+3)+7
  unregisterSymbol("WorldPTR")
  registerSymbol("WorldPTR", addr, true)
  PTR = readQword("WorldPTR")
  CarNameADR = getAddress("[[[PTR+8]+D30]+20]+298")
  CarNameCurrent = readString(CarNameADR)
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
  local save_dialog = createSaveDialog(self)
  save_dialog.InitalDir = os.getenv('%USERPROFILE%')
  if save_dialog.execute() then
    local s=(save_dialog.FileName..'.txt')
    file = io.open(s, "a+")
    CurrentDate=os.date("%x")
    file:write(ForLogs_TrackName..'_'..ForLogs_CarName..'_'..CurrentDate..'.LOG'..'\n')
    file:write(LogArray.."LOG BUILDING FINISHED")
    file:close()
  end
end

function Startup()
  FindAdr()
  FindTimes()
  FindCar()
  ActivateApp()
end

function ex()
  CloseCE()
end
