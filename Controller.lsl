//---------------------------------------------------------------------------------------
// Lite Collar 
// Version 0.9.4
// A light weight collar script with rlv functions for use inplace of open collar
// Compatible with open collar leash holders
// By Dawn Pienaar
//---------------------------------------------------------------------------------------

integer menu_chan; //set to random chan on state entry
integer oc_chan = -8888; //open collars leash holder channel

integer listen_id_menu;
integer listen_id_oc;

integer menu_index; 
integer timeout = 60;

integer alert;
integer public_access;

integer rlv_enabled = TRUE; 
integer rlv_sit = TRUE;
integer rlv_teleport;

integer hidden;

key leash_holder = NULL_KEY;
key menu_user = NULL_KEY;
key slave = NULL_KEY;

key key_query = NULL_KEY;

list doms = [];
list dom_keys = []; //store dom keys for rlv auto accept teleport not needed else where may merge with dom list later

list temp_object_list = [];

integer agent_exists(key agent)
{
    list parcel_vistor = llGetAgentList(AGENT_LIST_PARCEL, []);
    integer number_detected = llGetListLength(parcel_vistor);
    integer i;
    for(i = 0; i < number_detected; i++)
        if(llList2Key(parcel_vistor, i) == agent)
            return TRUE;
            
    return FALSE;
}

string fix_name(string data)
{
    list str = llParseString2List(data,[" ", "."],[]);
    string first = llList2String(str,0);
    string last = llList2String(str,1); 
    
    if(last == "" || last == " ") last = "resident";
    
    return llToLower(first + " " + last); 
}

integer start_listen(integer channel, key avatar) 
{   
    if(channel != -8888) //if listen started on channel other then oc
        llSetTimerEvent(timeout); //start timeout other wise just start listen
    
    return llListen(channel, "", avatar, ""); //setup listen channel and return id
}

stop_listen(integer id) 
{   
    llListenRemove(id); //remove listen
    
    if(id == listen_id_menu) //listen sorting for the future currently oc is paused and not fully closed. 
    {
        llSetTimerEvent(0); //end timeout if still active   
        menu_index = 0; //set menu index
        menu_user = NULL_KEY; //reset menu user
        listen_id_menu = FALSE; //clear listen id
        if(llGetListLength(temp_object_list)) temp_object_list = []; //clear temp leash to list. 
    }
}

resume_listen(integer id) //using this for oc channel I assume its faster to pause listen to fully start one new instance.
{
    llListenControl(id, TRUE); //set listen instance to active
}

pause_listen(integer id)
{
    llListenControl(id, FALSE); //set listen instance to inactive
}

menu()
{
    string text = "Menu index out of bounds";
    list buttons = ["◄ Back", " ", "✖ Cancel"]; 
    
    if(menu_index == 0) 
    {
        text = "Lite Collar v0.9.4\n\nOwners - Manage Owners\nLeash - Leash Options\nSettings - Collar settings";
        buttons = ["✿ Settings", " ", "✖ Cancel", "Owners", "Leash", " "];
        if(rlv_enabled && rlv_sit)
        {
            text += "\nRLV - Real life viewer options\n";
            buttons = llListReplaceList(buttons, ["RLV"], 5, 5);
        }
    }
    else if(menu_index == 1) //owners list
    {
        //if text over 512 btyes script will crash, we should have enough for 12 name entrys
        //512 / 36 = 14.2 Avatar names 36 char max thats 14 names we use 12 most people use 30 btye names ish 
        //72 free chars, 24 name numbers, 21 list title (*** Owners: 10/12 ***) 45 out of 72 used
        integer i;
        integer count_owners = llGetListLength(doms);
        text = "\n*** Owners(" + (string)count_owners + "/12) ***\n\n"; 
        for(i = 0; i < count_owners; i++)
            text += (string)(i + 1) + ") " + llList2String(doms, i) + "\n"; //add 1 to i because humans dont start count at 0
            
        buttons = ["◄ Back", " ", "✖ Cancel", "Add", "Remove", " "]; 
    }
    else if(menu_index == 2)
    {
        text = "\nUnleash - Remove Leash\nYank - Pull slave to you\nLength - Change length of leash chain\nPost - Leash to post\nGive - Leash to avatar\n";
        buttons = ["◄ Back", " ", "✖ Cancel",  "Post", "Give", " ", "Unleash", "Yank", "Length"];
            
        if(leash_holder == NULL_KEY)
        {
            text = "\nLeash - Leash slave to owner\nGrab - Pull slave to you and leash there collar\nHandle - Get leash handle to wear\nPost - Leash to post\nGive - Leash to avatar\n";
            buttons = ["◄ Back", " ", "✖ Cancel", "Post", "Give", " ", "Leash", "Grab", "Handle"];
        }
    }
    else if(menu_index == 3) //4, 5 in use by text box selection for owner add/remove
    {
        string access_state = "Public ☹"; 
        string alert_state = "Enabled ✔";
        if(!public_access) access_state = "Private ☺";
        if(!alert) alert_state = "Disabled ✕";
        text = "-------------------------------------------\n";
        text += "Access: " + access_state + "\nAlerts: " + alert_state + "\n";
        text += "-------------------------------------------\n";
        text += "Access - Set menu acces public/private\nAlerts - Toggle touch alerts\nRLV - Manage rlv settings\nMemory - Check scripts memory use\nReset - Reset Script";
        buttons = ["◄ Back", " ", "✖ Cancel", "Memory", "Hide", "Reset", "Access", "Alerts", "RLV"];
        if(hidden) buttons = llListReplaceList(buttons, ["Show"], 4, 4);
    }
    else if(menu_index == 6)
    {
        text = "Please select a leash length by default the length is set to 2 meters.";
        buttons = ["◄ Back", "6", "✖ Cancel", "3", "4", "5", "1", "1.5",  "2"];
    }
    else if(menu_index == 8) //7 in use my leash to options menu see index under listen function.
    {
        text = "\nSit - Seat avatar on object\nGround - Seat avatar on ground\n";
        buttons = ["◄ Back", " ", "✖ Cancel", "Sit", "Ground", " "];
        if(llGetAgentInfo(llGetOwner()) & AGENT_SITTING) 
        {
            text += "Unsit - Force avatar to stand\n";
            buttons = llListReplaceList(buttons, ["Unsit"], 5, 5); //add unsit button if avatar is sat
        }
    }
    else if(menu_index == 9) //RVL settings
    {
        string rlv_state = "Enabled ✔";
        string sit_state = "Enabled ✔";
        string tp_state = "Enabled ✔";
        if(!rlv_enabled) rlv_state = "Disabled ✕";
        if(!rlv_sit) sit_state = "Disabled ✕";
        if(!rlv_teleport) tp_state = "Disabled ✕"; 
        
        text = "-------------------------------------------\n";
        text+= "RLV: " + rlv_state + "\nSit/Unsit: " + sit_state + "\nTeleport: " + tp_state + "\n";
        text+= "-------------------------------------------\n";
        text+= "RLV - Toggle all rlv functions\nSit - Allow unsit and sit\nTeleport - Automaticly accept teleport from owner";
        buttons = ["◄ Back", " ", "✖ Cancel", "RLV", "Sit", "Teleport"];
    }
    llDialog(menu_user, text, buttons, menu_chan);
}

text_box()
{
    string text = "Selection out of bounds.";
    if(menu_index == 4) text = "Please add avatar name for new owner.";
    else if(menu_index == 5) text = "Please add avatar name to remove from owner list.";
    llTextBox(menu_user, text, menu_chan);
}

sensor_selection_menu()
{
    list buttons = ["◄ Back", " ", "✖ Cancel"]; 
    string text = "Null List passed to menu."; 
    
    integer len = llGetListLength(temp_object_list);
    integer i;
    for(i = 0; i < len; i++)
    {
        if(i == 0) text = ""; //clear text if list not empty thought list never be empty
        buttons += (string)(i + 1); //add buttons to menu from 1-9 depending on list length
        text += (string)(i + 1) + ") " + llList2String(llParseString2List(llList2String(temp_object_list, i), [","], [""]), 0) + "\n"; //build menu text from temp list names
    }
    llDialog(menu_user, text, buttons, menu_chan);
}

update_allow_teleport(integer switch) 
{
    string perm = "rem";
    if(switch) perm = "add";

    integer key_list = llGetListLength(dom_keys);
    while(key_list--) 
        llOwnerSay("@accepttp:" + llList2String(dom_keys, key_list) + "=" + perm);
}

object_alpha(float alpha)
{
    integer i;
    integer prims = llGetNumberOfPrims();
    for(i=0; i <= prims; i++) llSetLinkAlpha(i, alpha, ALL_SIDES);
}

reset_timeout()
{
    llSetTimerEvent(0);
    llSetTimerEvent(timeout);   
}

default
{
    attach(key id)
    {
        if(id == slave)
        {
            if(listen_id_menu) stop_listen(listen_id_menu); //reset menu if it was use
            pause_listen(listen_id_oc); //set instance to inactive well leash is not used.
            leash_holder = NULL_KEY; //remove leash user if leash was in use so its reset on relog
            llMessageLinked(LINK_THIS, 2, "rlv " + (string)rlv_enabled, NULL_KEY);//remind leash script that of rlv state
            if(rlv_enabled && rlv_teleport) update_allow_teleport(rlv_teleport); //update client allowed teleport list on re attach
        }
        else //key found not old owner if null object is being detached if not its new owner
        {  
            if(id == NULL_KEY) //null key passed object detatched
                if(rlv_enabled && rlv_teleport) 
                    update_allow_teleport(FALSE); //clear auto teleport on detach current entrys seem to break with objects when re attached
        }
    }
    
    changed(integer change)
    {
        if (change & CHANGED_OWNER) llResetScript(); //this might not work as intended and might be done in object worn check
    }
    
    state_entry() //State entry gets called on reset ingored on attach
    {
        llSetMemoryLimit(1028 * 48); //Impose memory limit to save resources
        llScriptProfiler(PROFILE_SCRIPT_MEMORY); //Set limited profile.
        
        if(slave == NULL_KEY) slave = llGetOwner(); //Script was reset check we got right owner
        if(!menu_chan) menu_chan = (integer)llFrand(2147483646)*-1; //Set random listen channel for object
        if(menu_chan == 0 || menu_chan == -8888) menu_chan = (integer)llFrand(2147483646)*-1; //make sure menu is not set to open collar or public

        listen_id_oc = start_listen(oc_chan, NULL_KEY); //start listne for OC object
        pause_listen(listen_id_oc); //set instance to inactive well leash is not used.
    }

    touch_start(integer total_number)
    {
        key toucher = llDetectedKey(0);
        if((public_access) || (toucher == slave) || (~llListFindList(doms, [llToLower(llKey2Name(toucher))]))) //check if toucher slave or on owner list or public on
        {
            if((toucher == menu_user) || (menu_user == NULL_KEY)) //check if new menu user or current menu user
            {
                if(!listen_id_menu) //Set up new listen instance is there is none
                {
                    menu_user = toucher;
                    listen_id_menu = start_listen(menu_chan, toucher); //create new listen instance and time out for instance
                }
                if(menu_user != NULL_KEY) reset_timeout(); //If user has retouched for menu reset time out
                if(menu_index == 4 || menu_index == 5) text_box(); 
                else menu();
            }
            else
            {
                llRegionSayTo(toucher, 0, "Menu is currently being used by " + llKey2Name(menu_user));
            }
        }
        if(toucher != slave && alert) llRegionSayTo(slave, 0, llKey2Name(toucher) + " has touched your collar");
    }

    listen(integer channel, string avatar, key uuid, string message) 
    {
        if(channel == menu_chan)
        {
            if(menu_index == 0) // Main menu
            {
                if(message == "Owners") menu_index = 1;
                else if(message == "Leash") menu_index = 2;
                else if(message == "✿ Settings") menu_index = 3;
                else if(message == "RLV") menu_index = 8;
                
                if(message != "✖ Cancel") menu();
                else stop_listen(listen_id_menu);
            }
            else if(menu_index == 1) //Manage Owners  
            {
                if(message == "Add")
                {
                    if(uuid == slave)
                    {
                        menu_index = 4;
                        reset_timeout();
                        text_box();
                    }
                    else
                    {
                        llRegionSayTo(uuid, 0, "Only the collar owner is able to manager owners list.");
                        stop_listen(listen_id_menu);
                    }
                }
                else if(message == "Remove")
                {
                    if(uuid == slave)
                    {
                        menu_index = 5;
                        reset_timeout();
                        text_box();
                    }
                    else
                    {
                        llRegionSayTo(uuid, 0, "Only the collar owner is able to manager owners list.");
                        stop_listen(listen_id_menu);
                    }
                }
                else if(message == "◄ Back") 
                {
                    menu_index = 0;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
            }
            else if(menu_index == 2) //Leash options
            {
                if(message == "Leash")
                {
                    resume_listen(listen_id_oc);
                    leash_holder = uuid;
                    llMessageLinked(LINK_THIS, 0, "leash", uuid);
                    llRegionSayTo(slave, 0, avatar + " has leashed your collar.");
                    menu();
                }
                else if(message == "Unleash")
                {
                    pause_listen(listen_id_oc); //pause listen instance for oc objects
                
                    if(uuid == slave)
                        if(agent_exists(leash_holder)) 
                            llRegionSayTo(leash_holder, 0, avatar + " has has unleashed them selfs.");
                    else
                        llRegionSayTo(slave, 0, avatar + " has unleashed your collar.");         
                    
                    leash_holder = NULL_KEY;
                    llMessageLinked(LINK_THIS, 0, "unleash", uuid);
                    
                    pause_listen(listen_id_oc);
                    stop_listen(listen_id_menu); //remove menu listen instance for user
                }
                else if(message == "Grab")
                {
                    resume_listen(listen_id_oc);
                    leash_holder = uuid;
                    llMessageLinked(LINK_THIS, 0, "grab", uuid);
                    llRegionSayTo(slave, 0, avatar + " grabs hold of your collar and places you on a leash.");
                    menu();
                }
                else if(message == "Yank")
                {
                    llMessageLinked(LINK_THIS, 0, "yank", uuid);
                    llRegionSayTo(slave, 0, avatar + " Yanks on your leash.");
                    stop_listen(listen_id_menu);
                }
                else if(message == "Length")
                {
                    menu_index = 6;
                    reset_timeout();
                    menu();
                }
                else if(message == "Handle")
                {
                    string object = llGetInventoryName(INVENTORY_OBJECT, 0);
                    if(object) llGiveInventory(uuid, object);
                    else llRegionSayTo(uuid, 0, "No object found to give.");
                    
                    stop_listen(listen_id_menu);      
                }
                else if(message == "Post")
                {
                    menu_index = 7;
                    llSensor("", NULL_KEY, SCRIPTED, 8, PI);   
                }
                else if(message == "Give")
                {
                    menu_index = 7;
                    llSensor("", NULL_KEY, AGENT, 8, PI);   
                }
                else if(message == "◄ Back") 
                {
                    menu_index = 0;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
            }
            else if(menu_index == 3) //Settings 
            {
                if(uuid == slave)
                {
                    if(message == "RLV")
                    {
                        menu_index = 9;
                        menu();
                    }
                    else if(message == "Access")
                    {
                        if(public_access)public_access = FALSE;
                        else public_access = TRUE;  
                        menu();
                    }
                    else if(message == "Alerts")
                    {
                        if(alert) alert = FALSE;
                        else alert = TRUE;
                        menu();
                    }
                    else if(message == "Hide")
                    {
                        object_alpha(0.0);
                        hidden = TRUE;
                        menu();
                    }
                    else if(message == "Show")
                    {
                        object_alpha(1.0);
                        hidden = FALSE;
                        menu();
                    }
                    else if(message == "Memory")
                    {
                        llRegionSayTo(uuid, 0, "CPU Time: " + (string)(llList2Float(llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME])), 0) * 1000) + " ms"); //get average cpu time from server records
                        llRegionSayTo(uuid, 0, llGetScriptName() + ", Memory Used: " + (string)(llGetUsedMemory() / 1024) + "/" + (string)(llGetMemoryLimit() / 1024) + " kb");  //check memory allogations 
                        llMessageLinked(LINK_THIS, 2, "memory", uuid);
                        stop_listen(listen_id_menu); 
                    }
                    else if(message == "Reset")
                    {
                        llRegionSayTo(uuid, 0, "Resetting scripts...");
                        llMessageLinked(LINK_THIS, 2, "reset", slave); //i could loop thought script names and reset state but this will due.
                        llResetScript();
                    }
                    else if(message == "◄ Back") 
                    {
                        menu_index = 0;
                        menu();
                    }
                    else if(message == "✖ Cancel") 
                    { 
                        stop_listen(listen_id_menu);
                    } 
                }
                else
                {
                    if(message == "◄ Back") 
                    {
                        menu_index = 0;
                        menu();
                    }
                    else if(message == "✖ Cancel") 
                    { 
                        stop_listen(listen_id_menu);
                    } 
                    else
                    {
                        llRegionSayTo(uuid, 0, "Only collar owner is able to change settings.");
                        stop_listen(listen_id_menu);
                    }
                }
            }
            else if(menu_index == 4) //add owner
            {
                if(llStringLength(message) >= 4)
                {
                    if(llGetListLength(doms) <= 11) //set limit to 12 (0-11) doms for memory and basicly after 8 your a slut admit it
                    {                               //also if admin list is being viewed in menu more then 
                        string name = fix_name(message);
                        if(llListFindList(doms, [name]) == -1)
                        {
                            doms += name;
                            key_query = llRequestUserKey(name);
                        }
                        else
                        {
                            llRegionSayTo(slave, 0, name + " is all ready on owners list.");   
                        }
                    }
                    else
                    {
                        llRegionSayTo(slave, 0, "You can not have more then 12 owners on list.");   
                    }
                }
                else
                {
                   llRegionSayTo(uuid, 0, "Name Length can not be less then 4 chars.");
                }
                menu_index = 1;
                menu();
            }
            else if(menu_index == 5) //remove owner
            {
                if(llStringLength(message) > 4)
                {
                    string name = fix_name(message);
                    integer row = llListFindList(doms, [name]);
                    if(row == -1)
                    {
                        llRegionSayTo(uuid, 0, "Name not found on list.");
                    }
                    else
                    {
                        string dom_key = llList2String(dom_keys, row);
                        doms = llDeleteSubList(doms, row, row);
                        dom_keys = llDeleteSubList(dom_keys, row, row);  
                        if(rlv_teleport) llOwnerSay("@accepttp:" + dom_key + "=rem");
                    }
                }
                else
                {
                   llRegionSayTo(uuid, 0, "Name Length can not be less then 4 chars.");
                }
                menu_index = 1;
                menu();
            }
            else if(menu_index == 6) //leash length
            {
                if(message == "◄ Back") 
                {
                    menu_index = 2;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
                else
                {
                    if(message != " ")
                    {
                        if((float)message) //check message is a float
                        { 
                            llMessageLinked(LINK_THIS, 2, "length " + message, NULL_KEY); //channel 2 setting channel
                            llRegionSayTo(uuid, 0, "Leash length has been changed to " + message + " meters.");
                        }
                        else
                        {
                            llRegionSayTo(uuid, 0, "Length value is not float");   
                        }
                        stop_listen(listen_id_menu);
                    }
                }
            }
            else if(menu_index == 7) //menu selection leash to object or avatar
            {
                if(message == "◄ Back") 
                {
                    menu_index = 2;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
                else
                {
                    list raw = llParseString2List(llList2String(temp_object_list, (integer)message - 1), [","], [""]);
                    leash_holder = llList2Key(raw, 1);
                    
                    if(leash_holder)
                    {
                        if(agent_exists(leash_holder)) resume_listen(listen_id_oc); //If leashed to avatar and not object start OC listen for leash handle.
                        llMessageLinked(LINK_THIS, 0, "leash", leash_holder);
                        llRegionSayTo(slave, 0, "Your collar has been leashed to " + llList2String(raw, 0));
                    }
                    else
                    {
                        leash_holder = NULL_KEY;
                        llRegionSayTo(uuid, 0, "Invalid key passed unable to leash.");   
                    }
                    stop_listen(listen_id_menu);
                }
            }
            else if(menu_index == 8) //RLV menu options
            {
                if(message == "Sit")
                {
                    menu_index = 10; //get selection for force sit
                    llSensor("", NULL_KEY, SCRIPTED, 8, PI);  
                }
                else if(message == "Ground") 
                {
                    llOwnerSay("@sitground=force");
                    llSleep(1); //sleep for a second so status can update before menu is called
                    menu();
                }
                else if(message == "Unsit") 
                {
                    llOwnerSay("@unsit=force");
                    llSleep(1); //sleep for a second so status can update before menu is called
                    menu();
                }
                else if(message == "◄ Back") 
                {
                    menu_index = 0;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
            }
            else if(menu_index == 9) //RLV Settings
            {
                if(message == "RLV")
                {
                    if(rlv_enabled)
                    {
                        rlv_enabled = FALSE;
                        rlv_sit = FALSE;
                        rlv_teleport = FALSE;
                        llRegionSayTo(uuid, 0, "rlv disabled some features of the collar may not work properly.");   
                    }
                    else
                    {
                        rlv_enabled = TRUE;
                        rlv_sit = TRUE;
                    }
                    llMessageLinked(LINK_THIS, 2, "rlv " + (string)rlv_enabled, NULL_KEY);
                    menu();
                }
                else if(message == "Sit")
                {
                    if(rlv_sit) rlv_sit = FALSE;
                    else rlv_sit = TRUE;
                    menu();
                }
                else if(message == "Teleport")
                {
                    if(rlv_teleport) rlv_teleport = FALSE;                    
                    else rlv_teleport = TRUE;
                    
                    update_allow_teleport(rlv_teleport);
                    menu();
                }
                else if(message == "◄ Back") 
                {
                    menu_index = 3;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
            }
            else if(menu_index == 10) //RLV Force sit object selection
            {
                if(message == "◄ Back") 
                {
                    menu_index = 8;
                    menu();
                }
                else if(message == "✖ Cancel") 
                { 
                    stop_listen(listen_id_menu);
                } 
                else
                {
                    key object_uuid = llList2Key(llParseString2List(llList2String(temp_object_list, (integer)message - 1), [","], [""]), 1);
                    if(object_uuid) llOwnerSay("@sit:" + (string)object_uuid + "=force");
                    else llRegionSayTo(uuid, 0, "Invalid key passed unable to sit avatar.");   
                    stop_listen(listen_id_menu);
                }
            }
            
            if(listen_id_menu) reset_timeout(); //reset timer after menu selection so menu doesnt not time out before user is done normal action
        }
        
        if(channel == oc_chan) //Open collar channel
        {
            key holder_owner_key = (key)llGetSubString(message, 0, 35); //get key from message string 
        
            if(holder_owner_key) //if valid key not null value
            {
                if(holder_owner_key == leash_holder) //check avatar key is same as current avatar leashed to
                {
                    string tmp_str = llGetSubString(message, 36, llStringLength(message)); //get request from string
                    list input = llParseString2List(tmp_str, [" "], []);
                    
                    if(llList2String(input, 0) == "handle")
                    {
                        if(llList2String(input, 1) == "ok")
                        {
                            llMessageLinked(LINK_THIS, 1, "handle ok", uuid);
                        }
                        else if(llList2String(input, 1) == "detached")
                        {
                            llMessageLinked(LINK_THIS, 1, "handle remove", holder_owner_key); //tell slave script to stop particals 
                            if(menu_user == leash_holder && listen_id_menu) stop_listen(listen_id_menu);  //leash holder left menu open and detached leash reset menu
                            pause_listen(listen_id_oc); //pause listen instance for oc objects
                            leash_holder = NULL_KEY;
                        }
                    }
                }
            }
        }
    }

    timer() 
    {
        if(menu_user == slave)
             llRegionSayTo(slave, 0,"Menu has timed out...");
        else 
            if(agent_exists(menu_user)) 
                llRegionSayTo(menu_user, 0, "Menu has timed out...");
        
        if(listen_id_menu) stop_listen(listen_id_menu);
    }

    sensor(integer detected)
    {
        if(llGetListLength(temp_object_list)) temp_object_list = []; //clear temp list if old entrys
        
        integer i;
        for(i = 0; i < detected; i++) //cycle thought detected from from 0 to length
        {
            temp_object_list += llGetSubString(llDetectedName(i), 0, 42) + "," + (string)llDetectedKey(i); //put results in temp list
            if(i >= 8) jump break; //get first 9 (0-8) objects or people we dont need pages just nearest hits
        }
        @break; //jump to break loop lsl doenst have break lol
        sensor_selection_menu();
    }

    no_sensor()
    {  
        llRegionSayTo(menu_user, 0, "Unable to find targets.");
        if(listen_id_menu) stop_listen(listen_id_menu);
    } 

    dataserver(key queryid, string data) 
    {
        if (key_query == queryid)
        {
            if(data != NULL_KEY)
            {
                dom_keys += data;
                if(rlv_teleport) llOwnerSay("@accepttp:" + data + "=add");
            }
        }
    }    
}
