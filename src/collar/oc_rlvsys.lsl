// Licensed under the GPLv2.  See LICENSE for full details.

string g_sScriptVersion         = "7.4";
string g_sParentMenu            = "Main";
string g_sSubMenu               = "RLV";
string UPMENU                   = "BACK";
string TURNON                   = "ON";
string TURNOFF                  = "OFF";
string CLEAR                    = "CLEAR ALL";
string g_sSettingToken          = "rlvsys_";
string g_sGlobalToken           = "global_";
string g_sRlvVersionString      = "(unknown)";
string g_sRlvaVersionString     = "(unknown)";

integer g_iRLVOn                = TRUE;
integer g_iRLVOff               = FALSE;
integer g_iViewerCheck          = FALSE;
integer g_iRlvActive            = FALSE;
integer g_iWaitRelay;
integer g_iListener;
integer g_iRlvVersion;
integer g_iRlvaVersion;
integer g_iCheckCount;
integer g_iMaxViewerChecks      = 3;
integer g_iCollarLocked         = FALSE;
integer g_iMenuStride           = 3;
integer RELAY_CHANNEL           = -1812221819;
integer LINK_CMD_DEBUG          = 1999;
integer CMD_OWNER               = 500;
integer CMD_WEARER              = 503;
integer CMD_EVERYONE            = 504;
integer CMD_RLV_RELAY           = 507;
integer CMD_SAFEWORD            = 510;
integer CMD_RELAY_SAFEWORD      = 511;
integer NOTIFY                  = 1002;
integer REBOOT                  = -1000;
integer LOADPIN                 = -1904;
integer LM_SETTING_SAVE         = 2000;
integer LM_SETTING_REQUEST      = 2001;
integer LM_SETTING_RESPONSE     = 2002;
integer MENUNAME_REQUEST        = 3000;
integer MENUNAME_RESPONSE       = 3001;
integer MENUNAME_REMOVE         = 3003;
integer RLV_CMD                 = 6000;
integer RLV_REFRESH             = 6001;     //RLV plugins should reinstate their restrictions upon receiving this message.
integer RLV_CLEAR               = 6002;     //RLV plugins should clear their restriction lists upon receiving this message.
integer RLV_VERSION             = 6003;     //RLV Plugins can recieve the used RLV viewer version upon receiving this message..
integer RLVA_VERSION            = 6004;     //RLV Plugins can recieve the used RLVa viewer version upon receiving this message..
integer RLV_OFF                 = 6100;
integer RLV_ON                  = 6101;
integer RLV_QUERY               = 6102;
integer RLV_RESPONSE            = 6103;
integer DIALOG                  = -9000;
integer DIALOG_RESPONSE         = -9001;
integer DIALOG_TIMEOUT          = -9002;
integer CMD_ADDSRC              = 11;
integer CMD_REMSRC              = 12;

float g_fVersionTimeOut         = 30.0;

key g_kWearer;
key g_kSitter                   = NULL_KEY;
key g_kSitTarget                = NULL_KEY;

list g_lMenu;
list g_lMenuIDs;
list g_lOwners;
list g_lRestrictions;
list g_lBaked                   = [];       //list of restrictions currently in force


DoMenu(key kID, integer iAuth)
{
    string sPrompt;
    key kMenuID = llGenerateKey();
    
    sPrompt = "\n[ Main > rlv ]";
    //string sPrompt = "\n[Remote Scripted Viewer Controls]\n";
/*    
    if (g_iRlvActive)
    {
        if (g_iRlvVersion) sPrompt += "\nRestrainedLove API: RLV v"+g_sRlvVersionString;
        if (g_iRlvaVersion) sPrompt += " / RLVa v"+g_sRlvaVersionString;
    }
*/    
    if (g_iRLVOff) sPrompt += "\n\n\t[Error]\tRLV is Disabled";
    else
    {
        if (g_iRLVOn) sPrompt += "\nThe rlv script is still trying to handshake with the RL-viewer. Just wait another minute and try again.\n\n[ON] restarts the RLV handshake cycle with the viewer.";
        else sPrompt += "\nRLV appears to be disabled in the viewer's preferences.\n\n[ON] attempts another RLV handshake with the viewer.";
        sPrompt += "\n\n[OFF] will prevent the %DEVICETYPE% from attempting another \"@versionnew=293847\" handshake at the next login.\n\nNOTE: Turning RLV off here means that it has to be turned on manually once it is activated in the viewer.";
    }

    list lButtons;

    if (g_iRlvActive)
    {
        lButtons = llListSort(g_lMenu, 1, TRUE);
        lButtons = [TURNOFF, CLEAR] + lButtons;
    }
    else if (g_iRLVOff) lButtons = [TURNON];
    else lButtons = [TURNON, TURNOFF];
    llMessageLinked(LINK_SET, DIALOG, (string)kID + "|" + sPrompt + "|0|" + llDumpList2String(lButtons, "`") + "|" + UPMENU + "|" + (string)iAuth, kMenuID);
    integer iIndex = llListFindList(g_lMenuIDs, [kID]);

    if (~iIndex) g_lMenuIDs = llListReplaceList(g_lMenuIDs, [kID, kMenuID, g_sSubMenu], iIndex, iIndex + g_iMenuStride - 1);
    else g_lMenuIDs += [kID, kMenuID, g_sSubMenu];
}

rebakeSourceRestrictions(key kSource)
{
    integer iSourceIndex=llListFindList(g_lRestrictions,[kSource]);
    if (~iSourceIndex)
    {
        list lRestr=llParseString2List(llList2String(g_lRestrictions,iSourceIndex+1),["§"],[]);
        while(llGetListLength(lRestr))
        {
            ApplyAdd(llList2String(lRestr,-1));
            lRestr=llDeleteSubList(lRestr,-1,-1);
        }
    }
}

DoLock()
{
    integer numSources=llGetListLength(llList2ListStrided(g_lRestrictions,0,-2,2));
    while (numSources--)
    {
        if ((key)llList2Key(llList2ListStrided(g_lRestrictions,0,-2,2),numSources))
        {
            ApplyAdd("detach");
            return;
        }
    }
    ApplyRem("detach");
}

setRlvState()
{
    if (g_iRLVOn && g_iViewerCheck)
    {
        if (!g_iRlvActive)
        {
            g_iRlvActive=TRUE;
            g_lMenu = [] ;
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
            llMessageLinked(LINK_SET, RLV_REFRESH, "", NULL_KEY);
            g_iWaitRelay = 1;
            llSetTimerEvent(1.5);
        }
    }
    else if (g_iRlvActive)
    {
        g_iRlvActive=FALSE;
        while (llGetListLength(g_lBaked))
        {
            llOwnerSay("@"+llList2String(g_lBaked,-1)+"=y");
            g_lBaked=llDeleteSubList(g_lBaked,-1,-1);
        }
        llMessageLinked(LINK_SET, RLV_OFF, "", NULL_KEY);
    }
    else if (g_iRLVOn)
    {
        if (g_iListener) llListenRemove(g_iListener);
        g_iListener = llListen(293847, "", g_kWearer, "");
        llSetTimerEvent(g_fVersionTimeOut);
        g_iCheckCount=0;
        llOwnerSay("@versionnew=293847");
    }
    else llSetTimerEvent(0.0);
}

AddRestriction(key kID, string sBehav)
{
    integer iSource=llListFindList(g_lRestrictions,[kID]);

    if (! ~iSource )
    {
        g_lRestrictions += [kID,""];
        iSource=-2;
        if ((key)kID) llMessageLinked(LINK_SET, CMD_ADDSRC,"",kID);
    }
    string sSrcRestr = llList2String(g_lRestrictions,iSource+1);

    if (!~llSubStringIndex("§"+sSrcRestr+"§","§"+sBehav+"§"))
    {
        sSrcRestr+="§"+sBehav;
        if (llSubStringIndex(sSrcRestr,"§")==0) sSrcRestr=llGetSubString(sSrcRestr,1,-1);

        g_lRestrictions=llListReplaceList(g_lRestrictions,[sSrcRestr],iSource+1, iSource+1);
        ApplyAdd(sBehav);

        if (sBehav=="unsit")
        {
            g_kSitTarget = llList2Key(llGetObjectDetails(g_kWearer, [OBJECT_ROOT]), 0);
            g_kSitter=kID;
        }
    }
    DoLock();
}

ApplyAdd (string sBehav)
{
    if (! ~llListFindList(g_lBaked, [sBehav]))
    {
        g_lBaked+=[sBehav];
        llOwnerSay("@"+sBehav+"=n");
    }
}

RemRestriction(key kID, string sBehav)
{
    integer iSource=llListFindList(g_lRestrictions,[kID]);
    if (~iSource)
    {
        list lSrcRestr = llParseString2List(llList2String(g_lRestrictions,iSource+1),["§"],[]);
        integer iRestr=llListFindList(lSrcRestr,[sBehav]);

        if (~iRestr || sBehav=="ALL")
        {
            if (llGetListLength(lSrcRestr)==1)
            {
                g_lRestrictions=llDeleteSubList(g_lRestrictions,iSource, iSource+1);
                if ((key)kID) llMessageLinked(LINK_SET, CMD_REMSRC,"",kID);
            }
            else
            {
                lSrcRestr=llDeleteSubList(lSrcRestr,iRestr,iRestr);
                g_lRestrictions=llListReplaceList(g_lRestrictions,[llDumpList2String(lSrcRestr,"§")] ,iSource+1,iSource+1);
            }
            if (sBehav=="unsit"&&g_kSitter==kID)
            {
                g_kSitter=NULL_KEY;
                g_kSitTarget=NULL_KEY;
            }
            lSrcRestr=[];
            ApplyRem(sBehav);
        }
    }
    DoLock();
}

ApplyRem(string sBehav)
{
    integer iRestr=llListFindList(g_lBaked, [sBehav]);
    if (~iRestr)
    {
        integer i;
        for (i=0;i<=llGetListLength(g_lRestrictions);i++)
        {
            list lSrcRestr=llParseString2List(llList2String(g_lRestrictions,i),["§"],[]);
            if (llListFindList(lSrcRestr, [sBehav])!=-1) return;
        }
        g_lBaked=llDeleteSubList(g_lBaked,iRestr,iRestr);
        llOwnerSay("@"+sBehav+"=y");
    }
}

SafeWord(key kID)
{
    integer numRestrictions=llGetListLength(g_lRestrictions);
    while (numRestrictions)
    {
        numRestrictions -= 2;
        string kSource=llList2String(g_lRestrictions,numRestrictions);
        if (kSource != "main" && kSource != "rlvex" && llSubStringIndex(kSource,"utility_") != 0)
            llMessageLinked(LINK_SET,RLV_CMD,"clear",kSource);
    }
    llMessageLinked(LINK_SET, NOTIFY, "0RLV was cleared and you may now stand up", g_kWearer);
    llMessageLinked(LINK_SET,RLV_CLEAR,"","");
    if (kID) llMessageLinked(LINK_SET,NOTIFY,"1"+"RLV restrictions cleared.",kID);
}

UserCommand(integer iNum, string sStr, key kID)
{
    sStr = llToLower(sStr);
    if (sStr=="runaway" && kID==g_kWearer)
    {
        llSleep(2);
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "on="+(string)g_iRLVOn, "");
    }
    else if (sStr == "rlv" || sStr == "menu rlv" )
    {
        DoMenu(kID, iNum);
    }
    else if (sStr == "rlv on")
    {
        llMessageLinked(LINK_SET,NOTIFY,"0"+"Starting RLV...",g_kWearer);
        llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "on=1", "");
        g_iRLVOn = TRUE;
        g_iRLVOff = FALSE;
        setRlvState();
    }
    else if (sStr == "rlv off")
    {
        if (iNum == CMD_OWNER)
        {
            llMessageLinked(LINK_SET, LM_SETTING_SAVE, g_sSettingToken + "on=0", "");
            llSetTimerEvent(0.0);
            g_iRLVOn = FALSE;
            g_iRLVOff = TRUE;
            setRlvState();
            llMessageLinked(LINK_SET,NOTIFY,"0"+"RLV disabled.",g_kWearer);
        }
        else llMessageLinked(LINK_SET,NOTIFY,"0"+"%NOACCESS% to changing rlv",kID);
    }
    else if (sStr == "clear")
    {
        if (iNum == CMD_OWNER) SafeWord(kID);
        else llMessageLinked(LINK_SET,NOTIFY,"1"+"%NOACCESS% to clearing RLV",kID);
    }
    else if (llGetSubString(sStr,0,13) == "rlv handshakes")
    {
        if (iNum != CMD_WEARER && iNum != CMD_OWNER) llMessageLinked(LINK_SET,NOTIFY,"0"+"%NOACCESS% to changing handshake count",kID);
        else
        {
            if ((integer)llGetSubString(sStr,-2,-1))
            {
                g_iMaxViewerChecks = (integer)llGetSubString(sStr,-2,-1);
                llMessageLinked(LINK_SET,NOTIFY,"1"+"Next time RLV is turned on or the %DEVICETYPE% attached with RLV turned on, there will be "+(string)g_iMaxViewerChecks+" extra handshake attempts before disabling RLV.", kID);
                llMessageLinked(LINK_SET,LM_SETTING_SAVE,g_sSettingToken + "handshakes="+(string)g_iMaxViewerChecks, "");
            }
            else llMessageLinked(LINK_SET,NOTIFY,"0"+"\n\nRLV handshakes means the set number of attempts to check for active RLV support in the viewer. Being on slow connections and/or having an unusually large inventory might mean having to check more often than the default of 3 times.\n\nCommand syntax: %PREFIX% rlv handshakes [number]\n", kID);
        }
    }
    else if (sStr=="show restrictions")
    {
        string sOut="\n\n%WEARERNAME% is restricted by the following sources:\n";
        integer numRestrictions=llGetListLength(g_lRestrictions);

        if (!numRestrictions) sOut="There are no restrictions right now.";
        while (numRestrictions)
        {
            key kSource=(key)llList2String(g_lRestrictions,numRestrictions-2);
            if ((key)kSource)
                sOut+="\n"+llKey2Name((key)kSource)+" ("+(string)kSource+"): "+llList2String(g_lRestrictions,numRestrictions-1)+"\n";
            else
                sOut+="\nThis %DEVICETYPE% ("+(string)kSource+"): "+llList2String(g_lRestrictions,numRestrictions-1)+"\n";
            numRestrictions -= 2;
        }
        llMessageLinked(LINK_SET,NOTIFY,"0"+sOut,kID);
    }
}

ExtractPart()
{
    g_sScriptPart = llList2String(llParseString2List(llGetScriptName(), ["_"],[]),1);
}

string g_sScriptPart;
integer INDICATOR_THIS;
SearchIndicators()
{
    ExtractPart();
    integer i=0;
    integer end = llGetNumberOfPrims();

    for(i=0;i<end;i++)
    {
        list Params = llParseStringKeepNulls(llList2String(llGetLinkPrimitiveParams(i,[PRIM_DESC]),0), ["~"],[]);

        if(llListFindList(Params, ["indicator_"+g_sScriptPart])!=-1)
        {
            INDICATOR_THIS = i;
            return;
        }
    }
}

Indicator(integer iMode)
{
    if(iMode)
        llSetLinkPrimitiveParamsFast(INDICATOR_THIS,[PRIM_FULLBRIGHT,ALL_SIDES,TRUE,PRIM_BUMP_SHINY,ALL_SIDES,PRIM_SHINY_NONE,PRIM_BUMP_NONE,PRIM_GLOW,ALL_SIDES,0.4]);
    else
        llSetLinkPrimitiveParamsFast(INDICATOR_THIS,[PRIM_FULLBRIGHT,ALL_SIDES,FALSE,PRIM_BUMP_SHINY,ALL_SIDES,PRIM_SHINY_HIGH,PRIM_BUMP_NONE,PRIM_GLOW,ALL_SIDES,0.0]);
}


default
{
    on_rez(integer param)
    {
        g_iRlvActive=FALSE;
        g_iViewerCheck=FALSE;
        g_iRLVOn=FALSE;
        g_lBaked=[];
    }

    state_entry()
    {
        if (llGetStartParameter()!=0)
        {
            state inUpdate;
        }
        setRlvState();
        llOwnerSay("@clear");
        g_kWearer = llGetOwner();
    }

    listen(integer iChan, string sName, key kID, string sMsg)
    {
        llListenRemove(g_iListener);
        llSetTimerEvent(0.0);
        g_iCheckCount = 0;
        g_iViewerCheck = TRUE;

        list lParam = llParseString2List(sMsg,[" "],[""]);
        list lVersionSplit = llParseString2List(llGetSubString(llList2String(lParam,2), 1, -1),["."],[]);
        g_iRlvVersion = llList2Integer(lVersionSplit,0) * 100 + llList2Integer(lVersionSplit,1);
        string sRlvResponseString = llList2String(lParam,2);
        g_sRlvVersionString = llGetSubString(sRlvResponseString,llSubStringIndex(sRlvResponseString,"v")+1,llSubStringIndex(sRlvResponseString,")") );
        string sRlvaResponseString = llList2String(lParam,4);
        g_sRlvaVersionString = llGetSubString(sRlvaResponseString,0,llSubStringIndex(sRlvaResponseString,")") -1);
        lVersionSplit = llParseString2List(g_sRlvaVersionString,["."],[]);
        g_iRlvaVersion = llList2Integer(lVersionSplit,0) * 100 + llList2Integer(lVersionSplit,1);
        setRlvState();
    }

    link_message(integer iSender, integer iNum, string sStr, key kID)
    {
        if (iNum == MENUNAME_REQUEST && sStr == g_sParentMenu)
        {
            llMessageLinked(iSender, MENUNAME_RESPONSE, g_sParentMenu + "|" + g_sSubMenu, "");
            g_lMenu = [] ;
            llMessageLinked(LINK_SET, MENUNAME_REQUEST, g_sSubMenu, "");
        }
        else if (iNum <= CMD_EVERYONE && iNum >= CMD_OWNER) UserCommand(iNum, sStr, kID);
        else if (iNum == DIALOG_RESPONSE)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            if (~iMenuIndex)
            {
                Indicator(TRUE);
                llSensorRepeat("N0thin9","abc",ACTIVE,0.1,0.1,0.22);
                list lMenuParams = llParseString2List(sStr, ["|"], []);
                key kAv = (key)llList2String(lMenuParams, 0);
                string sMsg = llList2String(lMenuParams, 1);
                integer iAuth = (integer)llList2String(lMenuParams, 3);
                lMenuParams=[];
                string sMenu=llList2String(g_lMenuIDs, iMenuIndex + 1);
                g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);

                if (sMenu == g_sSubMenu)
                {
                    if (sMsg == TURNON)
                    {
                        UserCommand(iAuth, "rlv on", kAv);
                    }
                    else if (sMsg == TURNOFF)
                    {
                        UserCommand(iAuth, "rlv off", kAv);
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMsg == CLEAR)
                    {
                        UserCommand(iAuth, "clear", kAv);
                        DoMenu(kAv, iAuth);
                    }
                    else if (sMsg == UPMENU)
                    {
                        llMessageLinked(LINK_SET, iAuth, "menu "+g_sParentMenu, kAv);
                    }
                    else if (~llListFindList(g_lMenu, [sMsg]))
                    {
                        llMessageLinked(LINK_SET, iAuth, "menu " + sMsg, kAv);
                    }
                }
            }
        }
        else if (iNum == DIALOG_TIMEOUT)
        {
            integer iMenuIndex = llListFindList(g_lMenuIDs, [kID]);
            g_lMenuIDs = llDeleteSubList(g_lMenuIDs, iMenuIndex - 1, iMenuIndex - 2 + g_iMenuStride);
        }
        else if (iNum == LM_SETTING_REQUEST && sStr == "ALL")
        {
            if (g_iRlvActive == TRUE)
            {
                llSleep(2);
                llMessageLinked(LINK_SET, RLV_ON, "", NULL_KEY);
                if (g_iRlvaVersion) llMessageLinked(LINK_SET, RLVA_VERSION, (string) g_iRlvaVersion, NULL_KEY);
            }
        }
        else if (iNum == LM_SETTING_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["="], []);
            string sToken = llList2String(lParams, 0);
            string sValue = llList2String(lParams, 1);
            lParams=[];
            if (sToken == "auth_owner") g_lOwners = llParseString2List(sValue, [","], []);
            else if (sToken==g_sGlobalToken+"lock") g_iCollarLocked=(integer)sValue;
            else if (sToken==g_sSettingToken+"handshakes") g_iMaxViewerChecks=(integer)sValue;
            else if (sToken==g_sSettingToken+"on")
            {
                g_iRLVOn=(integer)sValue;
                g_iRLVOff = !g_iRLVOn;
                setRlvState();
            }
        }
        else if (iNum == CMD_SAFEWORD || iNum == CMD_RELAY_SAFEWORD) SafeWord("");
        else if (iNum==RLV_QUERY)
        {
            if (g_iRlvActive) llMessageLinked(LINK_SET, RLV_RESPONSE, "ON", "");
            else llMessageLinked(LINK_SET, RLV_RESPONSE, "OFF", "");
        }
        else if (iNum == MENUNAME_RESPONSE)
        {
            list lParams = llParseString2List(sStr, ["|"], []);
            string sThisParent = llList2String(lParams, 0);
            string sChild = llList2String(lParams, 1);
            lParams=[];
            if (sThisParent == g_sSubMenu)
            {
                if (! ~llListFindList(g_lMenu, [sChild]))
                {
                    g_lMenu += [sChild];
                }
            }
        }
        else if (iNum == MENUNAME_REMOVE)
        {
            list lParams = llParseString2List(sStr, ["|"], []);
            string sThisParent = llList2String(lParams, 0);
            string sChild = llList2String(lParams, 1);
            lParams=[];

            if (sThisParent == g_sSubMenu)
            {
                integer iIndex = llListFindList(g_lMenu, [sChild]);
                if (iIndex != -1)
                {
                    g_lMenu = llDeleteSubList(g_lMenu, iIndex, iIndex);
                }
            }
        }
        else if (iNum == LOADPIN && sStr == llGetScriptName())
        {
            integer iPin = (integer)llFrand(99999.0)+1;
            llSetRemoteScriptAccessPin(iPin);
            llMessageLinked(iSender, LOADPIN, (string)iPin+"@"+llGetScriptName(),llGetKey());
        }
        else if (iNum == REBOOT && sStr == "reboot") llResetScript();
        else if (g_iRlvActive)
        {
            Indicator(TRUE);
            llSensorRepeat("N0thin9","abc",ACTIVE,0.1,0.1,0.22);

            if (iNum == RLV_CMD)
            {
                list lCommands=llParseString2List(llToLower(sStr),[","],[]);
                while (llGetListLength(lCommands))
                {
                    string sCommand=llToLower(llList2String(lCommands,0));
                    list lArgs = llParseString2List(sCommand,["="],[]);
                    string sCom = llList2String(lArgs,0);
                    if (llGetSubString(sCom,-1,-1)==":") sCom=llGetSubString(sCom,0,-2);
                    string sVal = llList2String(lArgs,1);
                    lArgs=[];
                    if (sVal=="n"||sVal=="add") AddRestriction(kID,sCom);
                    else if (sVal=="y"||sVal=="rem") RemRestriction(kID,sCom);
                    else if (sCom=="clear")
                    {
                        integer iSource=llListFindList(g_lRestrictions,[kID]);
                        if (kID=="rlvex")
                        {
                            RemRestriction(kID,sVal);
                        }
                        else if (~iSource)
                        {
                            list lSrcRestr=llParseString2List(llList2String(g_lRestrictions,iSource+1),["§"],[]);
                            list lRestrictionsToRemove;

                            while (llGetListLength(lSrcRestr))
                            {
                                string  sBehav=llList2String(lSrcRestr,-1);
                                if (sVal=="" || llSubStringIndex(sBehav,sVal)!=-1)
                                {
                                    lRestrictionsToRemove+=sBehav;
                                }
                                lSrcRestr=llDeleteSubList(lSrcRestr,-1,-1);
                            }
                            lSrcRestr=[];
                            while(llGetListLength(lRestrictionsToRemove))
                            {
                                RemRestriction(kID,llList2String(lRestrictionsToRemove,-1));
                                lRestrictionsToRemove=llDeleteSubList(lRestrictionsToRemove,-1,-1);
                            }
                        }
                    }
                    else
                    {
                        if (llSubStringIndex(sCom,"tpto")==0)
                        {
                            if ( ~llListFindList(g_lBaked,["tploc"])  || ~llListFindList(g_lBaked,["unsit"]) )
                            {
                                if ((key)kID) llMessageLinked(LINK_SET,NOTIFY,"1"+"Can't teleport due to RLV restrictions",kID);
                                return;
                            }
                        }
                        else if (sStr=="unsit=force")
                        {
                            if (~llListFindList(g_lBaked,["unsit"]) )
                            {
                                if ((key)kID) llMessageLinked(LINK_SET,NOTIFY,"1"+"Can't force stand due to RLV restrictions",kID);
                                return;
                            }
                        }
                        llOwnerSay("@"+sCommand);

                        if (g_kSitter==NULL_KEY&&llGetSubString(sCommand,0,3)=="sit:")
                        {
                            g_kSitter=kID;
                            g_kSitTarget=(key)llGetSubString(sCom,4,-1);
                        }
                    }
                    lCommands=llDeleteSubList(lCommands,0,0);
                }
            }
            else if (iNum == CMD_RLV_RELAY)
            {
                if (llGetSubString(sStr,-43,-1)== ","+(string)g_kWearer+",!pong")
                {
                    if (kID==g_kSitter) llOwnerSay("@"+"sit:"+(string)g_kSitTarget+"=force");  //if we stored a sitter, sit on it
                    rebakeSourceRestrictions(kID);
                }
            }
        }

        if(iNum == LINK_CMD_DEBUG)
        {
            integer onlyver=0;
            if(sStr == "ver")onlyver=1;
            llInstantMessage(kID, llGetScriptName() +" SCRIPT VERSION: "+g_sScriptVersion);
            if(onlyver)return;
            llInstantMessage(kID, llGetScriptName() +" FREE MEMORY: "+(string)llGetFreeMemory()+" bytes");
            llInstantMessage(kID, llGetScriptName()+" RLV_ON: "+(string)g_iRLVOn);
        }
    }

    no_sensor()
    {
        Indicator(FALSE);
        llSensorRemove();
    }

    timer()
    {
        if (g_iWaitRelay)
        {
            if (g_iWaitRelay < 2)
            {
                g_iWaitRelay = 2;
                llMessageLinked(LINK_SET, RLV_ON, "", NULL_KEY);
                llMessageLinked(LINK_SET, RLV_VERSION, (string)g_iRlvVersion, "");
                if (g_iRlvaVersion)
                    llMessageLinked(LINK_SET, RLVA_VERSION, (string)g_iRlvaVersion, "");
                DoLock();
                llSetTimerEvent(3.0);
            }
            else
            {
                llSetTimerEvent(0.0);
                g_iWaitRelay = FALSE;
                integer i;

                for (i=0;i<llGetListLength(g_lRestrictions)/2;i++)
                {
                    key kSource=(key)llList2String(llList2ListStrided(g_lRestrictions,0,-1,2),i);
                    if ((key)kSource) llShout(RELAY_CHANNEL,"ping,"+(string)kSource+",ping,ping");
                    else rebakeSourceRestrictions(kSource);
                }
                if (!llGetStartParameter()) llMessageLinked(LINK_SET,NOTIFY,"0"+"RLV ready!",g_kWearer);
            }
        }
        else
        {
            if (g_iCheckCount++ < g_iMaxViewerChecks)
            {
                llOwnerSay("@versionnew=293847");
            }
            else
            {
                llMessageLinked(LINK_SET, NOTIFY, "0"+"\n\nRLV appears to be not currently activated in your viewer. There will be no further attempted handshakes \"@versionnew=293847\" until the next time you log in. To permanently turn RLV off, type \"/%CHANNEL% %PREFIX% rlv off\" but keep in mind that you will have to manually enable it if you wish to use it in the future.\n", g_kWearer);
                llSetTimerEvent(0.0);
                llListenRemove(g_iListener);
                g_iCheckCount=0;
                g_iViewerCheck = FALSE;
                g_iRlvVersion = FALSE;
                g_iRlvaVersion = FALSE;
                g_iRLVOn = FALSE;
            }
        }
    }

    changed(integer iChange)
    {
        if (iChange & CHANGED_OWNER) llResetScript();
        if (iChange & CHANGED_TELEPORT || iChange & CHANGED_REGION)
        {
            integer numBaked=llGetListLength(g_lBaked);
            while (numBaked--)
            {
                llOwnerSay("@"+llList2String(g_lBaked,numBaked)+"=n");
            }
        }
    }
}

state inUpdate
{
    link_message(integer iSender, integer iNum, string sMsg, key kID)
    {
        if(iNum == REBOOT)llResetScript();
        else if(iNum == 0)
        {
            if(sMsg == "do_move")
            {
                if(llGetLinkNumber()==LINK_ROOT)return;
                list Parameters = llParseStringKeepNulls(llList2String(llGetLinkPrimitiveParams(llGetLinkNumber(), [PRIM_DESC]),0), ["~"],[]);
                ExtractPart();
                Parameters += "indicator_"+g_sScriptPart;
                llSetLinkPrimitiveParams(llGetLinkNumber(), [PRIM_DESC, llDumpList2String(Parameters,"~")]);
                llOwnerSay("Moving "+llGetScriptName()+"!");
                integer i=0;
                integer end=llGetInventoryNumber(INVENTORY_ALL);
                for(i=0;i<end;i++)
                {
                    string item = llGetInventoryName(INVENTORY_ALL,i);

                    if(llGetInventoryType(item)==INVENTORY_SCRIPT && item!=llGetScriptName())
                    {
                        llRemoveInventory(item);
                    }
                    else if(llGetInventoryType(item)!=INVENTORY_SCRIPT)
                    {
                        llGiveInventory(kID, item);
                        llRemoveInventory(item);
                        i=-1;
                        end=llGetInventoryNumber(INVENTORY_ALL);
                    }
                }
                llRemoveInventory(llGetScriptName());
            }
        }
    }
}
