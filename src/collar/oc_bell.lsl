// Licensed under the GPLv2.  See LICENSE for full details.

string g_sScriptVersion         = "7.4";
string g_sAppVersion            = "1.1";
string g_sSubMenu               = "Bell";
string g_sParentMenu            = "Apps";
string g_sBellOn                = "ON";     // menu text of bell on
string g_sBellOff               = "OFF";    // menu text of bell off
string g_sBellShow              = "SHOW";   //menu text of bell visible
string g_sBellHide              = "HIDE";   //menu text of bell hidden
string UPMENU                   = "BACK";
string g_sSettingToken          = "bell_";

integer LINK_CMD_DEBUG          = 1999;
integer g_iMenuStride           = 3;
integer g_iBellOn               = 0;        // are we ringing. Off is 0, On = Auth of person which enabled
integer g_iBellShow             = FALSE;    // is the bell visible
integer g_iCurrentBellSound;                // curent bell sound sumber
integer g_iBellSoundCount;                  // number of avail bell sounds
integer g_iHasControl           = FALSE;    // dow we have control over the keyboard?
integer g_iHide;                            // global hide
integer CMD_OWNER               = 500;
integer CMD_GROUP               = 502;
integer CMD_WEARER              = 503;
integer CMD_EVERYONE            = 504;
integer NOTIFY                  = 1002;
integer SAY                     = 1004;
integer REBOOT                  = -1000;
integer LM_SETTING_SAVE         = 2000;
integer LM_SETTING_RESPONSE     = 2002;
integer MENUNAME_REQUEST        = 3000;
integer MENUNAME_RESPONSE       = 3001;
integer MENUNAME_REMOVE         = 3003;
integer DIALOG                  = -9000;
integer DIALOG_RESPONSE         = -9001;
integer DIALOG_TIMEOUT          = -9002;
integer g_iHasBellPrims;

float g_fVolume                 = 0.5;      // volume of the bell
float g_fVolumeStep             = 0.1;      // stepping for volume
float g_fNextRing;
float g_fNextTouch;                         // store time for the next touch

key g_kCurrentBellSound;                    // curent bell sound key
key g_kLastToucher ;                        // store toucher key
key g_kWearer;                              // key of the current wearer to reset only on owner changes

list g_lMenuIDs;                            //three strided list of avkey, dialogid, and menuname
list g_listBellSounds           =["ae3a836f-4d69-2b74-1d52-9c78a9106206","503d2360-99f8-7a4a-8b89-43c5122927bd","a3ff9ca6-8289-0007-5b6b-d4c993580a6b","843adc44-1189-2d67-6f3a-72a80b3a9ed4","4c84b9b7-b363-b501-c019-8eef5fb4d3c2","3b95831e-8da5-597f-3b4d-713a03945cb6","285b317c-23d1-de51-84bc-938eb3df9e46","074b9b37-f6a3-a0a3-f40e-14bc57502435"]; // list with 4.0 bell sounds
list g_lBellElements;                       // list with number of prims related to the bell
list g_lGlows;                              // 2-strided list [integer link_num, float glow]

DebugOutput(key kID, list ITEMS)
{
    integer i=0;
    integer end=llGetListLength(ITEMS);
    string final;
    for(i=0;i<end;i++){
        final+=llList2String(ITEMS,i)+" ";
    }
    llInstantMessage(kID, llGetScriptName() +final);
}


Dialog(key kRCPT, string sPrompt, list lChoices, list lUtilityButtons, integer iPage, integer iAuth, string iMenuType)
{
    key kMenuID = llGenerateKey();
    llMessageLinked(LINK_SET, DIALOG, (string)kRCPT + "|" + sPrompt + "|" + (string)iPage + "|" + llDumpList2String(lChoices, "`") + "|" + llDumpList2String(lUtilityButtons, "`") + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kRCPT]);
    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kRCPT, kMenuID, iMenuType], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kRCPT, kMenuID, iMenuType];
}

BellMenu(key kID, integer iAuth)
{
    string sPrompt = "\n[ Main > Apps > Bell ]";
    list lMyButtons;

    if (g_iBellOn>0)
    {
        lMyButtons+= g_sBellOff;
        lMyButtons += ["Next Sound","Vol +","Vol -"];

        if (g_iBellShow) lMyButtons+= g_sBellHide;
        else lMyButtons+= g_sBellShow;

        sPrompt += "\n\n\tBell Volume:  \t"+(string)((integer)(g_fVolume*10))+"/10\n";
        sPrompt += "\tActive Sound:\t"+(string)(g_iCurrentBellSound+1)+"/"+(string)g_iBellSoundCount+"\n";
    }
    else lMyButtons+= g_sBellOn;
    Dialog(kID, sPrompt, lMyButtons, [UPMENU], 0, iAuth, "BellMenu");
}

SetBellElementAlpha()
{
    if (g_iHide) return ;
    //loop through stored links, setting color if element type is bell
    integer n;
    integer iLinkElements = llGetListLength(g_lBellElements);
    for (n = 0; n < iLinkElements; n++)
    {
        llSetLinkAlpha(llList2Integer(g_lBellElements,n), (float)g_iBellShow, ALL_SIDES);
        UpdateGlow(llList2Integer(g_lBellElements,n), g_iBellShow);
    }
}

UpdateGlow(integer link, integer alpha)
{
    if (alpha == 0)
    {
        SavePrimGlow(link);
        llSetLinkPrimitiveParamsFast(link, [PRIM_GLOW, ALL_SIDES, 0.0]);  // set no glow;
    }
    else RestorePrimGlow(link);
}

SavePrimGlow(integer link)
{
    float glow = llList2Float(llGetLinkPrimitiveParams(link,[PRIM_GLOW,0]),0);
    integer i = llListFindList(g_lGlows,[link]);
    if (i !=-1 && glow > 0) g_lGlows = llListReplaceList(g_lGlows,[glow],i+1,i+1);
    if (i !=-1 && glow == 0) g_lGlows = llDeleteSubList(g_lGlows,i,i+1);
    if (i == -1 && glow > 0) g_lGlows += [link, glow];
}

RestorePrimGlow(integer link)
{
    integer i = llListFindList(g_lGlows,[link]);
    if (i != -1) llSetLinkPrimitiveParamsFast(link, [PRIM_GLOW, ALL_SIDES, llList2Float(g_lGlows, i+1)]);
}

BuildBellElementList()
{
    list lParams;
    g_lBellElements = [];
    //root prim is 1, so start at 2
    integer i = 2;
    for (; i <= llGetNumberOfPrims(); i++)
    {
        lParams=llParseString2List((string)llGetLinkPrimitiveParams(i,[PRIM_DESC]), ["~"], []);
        if (llList2String(lParams, 0)=="Bell") g_lBellElements += [i];
    }
    if (llGetListLength(g_lBellElements)) g_iHasBellPrims = TRUE;
}

PrepareSounds()
{
    integer i;
    string sSoundName;
    for (; i < llGetInventoryNumber(INVENTORY_SOUND); i++)
    {
        sSoundName = llGetInventoryName(INVENTORY_SOUND,i);
        if (llSubStringIndex(sSoundName,"bell_")==0) g_listBellSounds+=llGetInventoryKey(sSoundName);
    }
    g_iBellSoundCount=llGetListLength(g_listBellSounds);
    g_iCurrentBellSound=0;
    g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);
}

UserCommand(integer iNum, string sStr, key kID)
{
    sStr = llToLower(sStr);
    if (sStr == "menu bell" || sStr == "bell" || sStr == g_sSubMenu) BellMenu(kID, iNum);
    else if (llSubStringIndex(sStr,"bell")==0)
    {
        list lParams = llParseString2List(sStr, [" "], []);
        string sToken = llList2String(lParams, 1);
        string sValue = llList2String(lParams, 2);

        if (sToken=="volume")
        {
            integer n=(integer)sValue;
            if (n<1) n=1;
            if (n>10) n=10;
            g_fVolume=(float)n/10;
            llPlaySound(g_kCurrentBellSound,g_fVolume);
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "vol=" + (string)llFloor(g_fVolume*10), "");
        }
        else if (sToken=="show" || sToken=="hide")
        {
            if (sToken=="show") g_iBellShow=TRUE;
            else g_iBellShow=FALSE;

            SetBellElementAlpha();
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "show=" + (string)g_iBellShow, "");
        }
        else if (sToken=="on")
        {
            if (iNum!=CMD_GROUP)
            {
                if (g_iBellOn==0)
                {
                    g_iBellOn=iNum;
                    if (!g_iHasControl) llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "on=" + (string)g_iBellOn, "");
                }
            }
            else llMessageLinked(LINK_SET,NOTIFY,"0"+"%NOACCESS% to bell",kID);
        }
        else if (sToken=="off")
        {
            if ((g_iBellOn>0)&&(iNum!=CMD_GROUP))
            {
                g_iBellOn=0;
                if (g_iHasControl)
                {
                    llReleaseControls();
                    g_iHasControl=FALSE;
                }
                llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "on=" + (string)g_iBellOn, "");
            }
            else llMessageLinked(LINK_SET,NOTIFY,"0"+"%NOACCESS% to bell",kID);
        }
        else if (sToken=="nextsound")
        {
            g_iCurrentBellSound++;
            if (g_iCurrentBellSound>=g_iBellSoundCount) g_iCurrentBellSound=0;
            g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);
            llPlaySound(g_kCurrentBellSound,g_fVolume);
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "sound=" + (string)g_iCurrentBellSound, "");
            llMessageLinked(LINK_SET,NOTIFY,"1"+"Bell sound changed, now using "+(string)(g_iCurrentBellSound+1)+" of "+(string)g_iBellSoundCount+".",kID);
        }
        else if (sToken=="ring")
        {
            g_fNextRing=llGetTime()+1.0;
            llPlaySound(g_kCurrentBellSound,g_fVolume);
        }
    }
}

default
{
    on_rez(integer param)
    {
        g_kWearer=llGetOwner();
        if (g_iBellOn) llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);
    }

    state_entry()
    {
        g_kWearer=llGetOwner();
        llResetTime(); // reset script time used for ringing the bell in intervalls
        BuildBellElementList();
        PrepareSounds();
        SetBellElementAlpha();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu) llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
        else if (iNum >= CMD_OWNER && iNum <= CMD_EVERYONE) UserCommand(iNum, sStr, kID);
        else if (iNum == DIALOG_RESPONSE)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex)
            {
                string sMenuType = llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAV = llList2String(lMenuParams, 0);
                string sMessage = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);

                if (sMessage == UPMENU)
                {
                    llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAV);
                    return;
                }
                else if (sMessage == "Vol +")
                {
                    g_fVolume+=g_fVolumeStep;
                    if (g_fVolume>1.0) g_fVolume=1.0;
                    llPlaySound(g_kCurrentBellSound,g_fVolume);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "vol=" + (string)llFloor(g_fVolume*10), "");
                }
                else if (sMessage == "Vol -")
                {
                    g_fVolume-=g_fVolumeStep;
                    if (g_fVolume<0.1) g_fVolume=0.1;
                    llPlaySound(g_kCurrentBellSound,g_fVolume);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "vol=" + (string)llFloor(g_fVolume*10), "");
                }
                else if (sMessage == "Next Sound")
                {
                    g_iCurrentBellSound++;
                    if (g_iCurrentBellSound>=g_iBellSoundCount) g_iCurrentBellSound=0;
                    g_kCurrentBellSound=llList2Key(g_listBellSounds,g_iCurrentBellSound);
                    llPlaySound(g_kCurrentBellSound,g_fVolume);
                    llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "sound=" + (string)g_iCurrentBellSound, "");
                }
                else if (sMessage == g_sBellOff || sMessage == g_sBellOn) UserCommand(iAuth,"bell "+llToLower(sMessage),kAV);
                else if (sMessage == g_sBellShow || sMessage == g_sBellHide)
                {
                    if (g_iHasBellPrims)
                    {
                        g_iBellShow = !g_iBellShow;
                        SetBellElementAlpha();
                        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "show=" + (string)g_iBellShow, "");
                    }
                    else llMessageLinked(LINK_SET, NOTIFY, "0"+"[Error]\tThis %DEVICETYPE% has no visual bell element.", kAV);
                }
                BellMenu(kAV, iAuth);
            }
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex +3);
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            integer i = llSubStringIndex(sStr, "=");
            string sToken = llGetSubString(sStr, 0, i - 1);
            string sValue = llGetSubString(sStr, i + 1, -1);
            i = llSubStringIndex(sToken, "_");

            if (llGetSubString(sToken, 0, i) == g_sSettingToken)
            {
                sToken = llGetSubString(sToken, i + 1, -1);
                if (sToken == "on")
                {
                    g_iBellOn=(integer)sValue;

                    if (g_iBellOn && !g_iHasControl) llRequestPermissions(g_kWearer,PERMISSION_TAKE_CONTROLS);
                    else if (!g_iBellOn && g_iHasControl)
                    {
                        llReleaseControls();
                        g_iHasControl = FALSE;
                    }
                }
                else if (sToken == "show")
                {
                    g_iBellShow=(integer)sValue;
                    SetBellElementAlpha();
                }
                else if (sToken == "sound")
                {
                    g_iCurrentBellSound = (integer)sValue;
                    g_kCurrentBellSound = llList2Key(g_listBellSounds,g_iCurrentBellSound);
                }
                else if (sToken == "vol") g_fVolume = (float)sValue/10;
            }
        }
        else if(iNum == CMD_OWNER && sStr == "runaway")
        {
            llSleep(4);
            SetBellElementAlpha();
        }
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
        else if(iNum == LINK_CMD_DEBUG)
        {
            integer onlyver=0;
            if(sStr == "ver")onlyver=1;
            llInstantMessage(kID, llGetScriptName() +" SCRIPT VERSION: "+g_sScriptVersion+", APPVERSION: "+g_sAppVersion);
            if(onlyver)return;
            DebugOutput(kID, [" HAS BELL PRIMS:", g_iHasBellPrims]);
            DebugOutput(kID, [" BELL VISIBLE:", g_iBellShow]);
            DebugOutput(kID, [" BELL ON:", g_iBellOn]);
        }
    }

    control( key kID, integer nHeld, integer nChange )
    {
        if (!g_iBellOn) return;
        if (nChange & (CONTROL_LEFT|CONTROL_RIGHT|CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK)) llPlaySound(g_kCurrentBellSound,g_fVolume);
        if ((nHeld & (CONTROL_FWD|CONTROL_BACK)) && (llGetAgentInfo(g_kWearer) & AGENT_ALWAYS_RUN))
        {
            if (llGetTime()>g_fNextRing)
            {
                g_fNextRing=llGetTime()+1.0;
                llPlaySound(g_kCurrentBellSound,g_fVolume);
            }
        }
    }

    collision_start(integer iNum)
    {
        if (g_iBellOn) llPlaySound(g_kCurrentBellSound,g_fVolume);
    }

    run_time_permissions(integer nParam)
    {
        if( nParam & PERMISSION_TAKE_CONTROLS)
        {
            llTakeControls( CONTROL_DOWN|CONTROL_UP|CONTROL_FWD|CONTROL_BACK|CONTROL_LEFT|CONTROL_RIGHT|CONTROL_ROT_LEFT|CONTROL_ROT_RIGHT, TRUE, TRUE);
            g_iHasControl=TRUE;
        }
    }

    touch_start(integer n)
    {
        if (g_iBellShow && !g_iHide && ~llListFindList(g_lBellElements,[llDetectedLinkNumber(0)]))
        {
            key toucher = llDetectedKey(0);
            if (toucher != g_kLastToucher || llGetTime() > g_fNextTouch)
            {
                g_fNextTouch = llGetTime()+10.0;
                g_kLastToucher = toucher;
                llPlaySound(g_kCurrentBellSound,g_fVolume);
                llMessageLinked(LINK_SET,SAY,"1"+ "secondlife:///app/agent/"+(string)toucher+"/about plays with the trinket on %WEARERNAME%'s %DEVICETYPE%.","");
            }
        }
    }

    changed(integer iChange)
    {
        if(iChange & CHANGED_LINK) BuildBellElementList();
        else if (iChange & CHANGED_INVENTORY) PrepareSounds();

        if (iChange & CHANGED_COLOR)
        {
            integer iNewHide=!(integer)llGetAlpha(ALL_SIDES) ; //check alpha
            if (g_iHide != iNewHide)
            {
                g_iHide = iNewHide;
                SetBellElementAlpha();
            }
        }
        if (iChange & CHANGED_OWNER) llResetScript();
    }
}
