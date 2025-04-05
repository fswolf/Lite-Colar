//partical_emitter_link change this number to link number you want 
//the particals to emitte from by default 0 OR 1 is the root prim
integer partical_emitter_link = 2; 

integer rlv_enabled = TRUE;
integer distance_check_time = 2; 
integer target_id;

float leash_length = 2.0; 

key handle_key = NULL_KEY;
key dom_key = NULL_KEY;

particles(integer link, key target) 
{
    llLinkParticleSystem(link, [PSYS_PART_MAX_AGE, 3.5,
                                PSYS_PART_FLAGS, PSYS_PART_FOLLOW_VELOCITY_MASK | PSYS_PART_TARGET_POS_MASK | PSYS_PART_FOLLOW_SRC_MASK,
                                PSYS_PART_START_COLOR, <1.00000, 1.00000, 1.00000>,
                                PSYS_PART_START_SCALE, <0.04, 0.04, 1.0>,
                                PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_DROP,
                                PSYS_SRC_BURST_RATE, 0.0,
                                PSYS_SRC_ACCEL, <0.0,0.0,-1.0>,
                                PSYS_SRC_BURST_PART_COUNT, 1,
                                PSYS_SRC_TARGET_KEY, target,
                                PSYS_SRC_MAX_AGE, 0,
                                PSYS_SRC_TEXTURE, "4cde01ac-4279-2742-71e1-47ff81cc3529"]); //chain texture from open collar
}

remove_particles(integer link)
{
    llLinkParticleSystem(link, []);
} 

yank_leash(key target) 
{
    llMoveToTarget(llList2Vector(llGetObjectDetails(target, [OBJECT_POS]), 0), 0.5);
    if(rlv_enabled)
        if(llGetAgentInfo(llGetOwner()) & AGENT_SITTING) 
            llOwnerSay("@unsit=force");
    llSleep(1.0);
    llStopMoveToTarget();
}

leash()
{
    key leash_to_key = handle_key;
    
    if(handle_key == NULL_KEY)
    {
        leash_to_key = dom_key;  
        llSay(-8888, (string)dom_key + "handle");  
    }
    
    particles(partical_emitter_link, leash_to_key);
    llSetTimerEvent(distance_check_time);   
}

unleash()
{ 
    llSetTimerEvent(0);
    if(target_id) llTargetRemove(target_id);
    remove_particles(partical_emitter_link);
    target_id = FALSE;
    dom_key = NULL_KEY;
    handle_key = NULL_KEY;
    if(distance_check_time > 2) distance_check_time = 2; 
}

look_at()
{
    vector agent_pos = llList2Vector(llGetObjectDetails(dom_key, [OBJECT_POS]), 0) - llGetPos();
    llOwnerSay("@setrot:" + (string)llAtan2(agent_pos.x, agent_pos.y) + "=force");
}

stop_move()
{
    llStopMoveToTarget();
    llTargetRemove(target_id);
    target_id = FALSE;
}

default
{
    attach(key id)
    {
        if(id != NULL_KEY) llResetScript();  
    }
    
    state_entry()
    {
        llSetMemoryLimit(16384); //Impose memory limit to save resources example 32768 16384 
        llScriptProfiler(PROFILE_SCRIPT_MEMORY); //Set limited profile.
        remove_particles(partical_emitter_link); //remove particals if emitting 
        unleash(); //reset leash if leashed
    }

    link_message(integer source, integer chan, string message, key uuid)
    {
        //llOwnerSay("source: " + (string)source + "\nnum: " + (string)chan + "\nMsg: " + message + "\nid: " + (string)uuid);
        //message from root prim
        //all mesh objects that root is 0 if there object has more then one link root becomes 1
        if(source <= 2) 
        {
            list input = llParseString2List(message, [" "], []);
            string command = llList2String(input, 0);
                
            if(chan == 0) //leash commands 
            {
                if(command == "leash")
                {
                    dom_key = uuid;
                    leash();
                }   
                else if(command == "unleash")
                {
                    unleash();
                }   
                else if(command == "grab")
                {
                    dom_key = uuid;
                    yank_leash(uuid); 
                    leash();
                }   
                else if(command == "yank")
                {
                    yank_leash(uuid);  
                }   
            }
            else if(chan == 1) //Handle commands and uuid passoff
            {
                if(command == "handle")
                {
                    string parameters = llList2String(input, 1);
                    if(parameters == "ok")
                    {
                        handle_key = uuid;
                        if(dom_key != NULL_KEY) particles(partical_emitter_link, handle_key); //if dom is using update partical location
                    }
                    else if(parameters == "remove")
                    {
                        if(uuid == dom_key) unleash(); //double check handle has removed by user
                    }
                } 
            }
            else if(chan == 2) //settings from main controller
            {                
                if(command == "memory")
                {
                    llRegionSayTo(uuid, 0, llGetScriptName() + ", Memory Used: " + (string)(llGetUsedMemory() / 1024) + "/" + (string)(llGetMemoryLimit() / 1024) + " kb");
                }
                else if(command == "reset")
                {
                    llResetScript();
                }
                else if(command == "length")
                {
                    leash_length = llList2Float(input, 1);
                }
                else if(command == "rlv")
                {
                    rlv_enabled = llList2Integer(input, 1); 
                }
            }
        }
    }
    
    at_target(integer id, vector target_pos, vector my_pos) 
    {
        if(id == target_id)
        {
            stop_move();
            if(rlv_enabled) look_at();
        }
    }
    
    not_at_target()
    {
        vector dom_pos = llList2Vector(llGetObjectDetails(dom_key, [OBJECT_POS]), 0);
        if (dom_pos == ZERO_VECTOR || llVecDist(llGetPos(), dom_pos) < 0.6) //Avatar lost or close enough <3
        {
            stop_move();
        }
        llSleep(0.1);//sleep 0.1ms to save on cpu time during move
    }
    
    timer()
    {
        if(dom_key) //make sure we have  a dom key... incase it dispeers ? :?
        {
            vector dom_pos = llList2Vector(llGetObjectDetails(dom_key, [OBJECT_POS]), 0);
            float distance_to_dom = llVecDist(llGetPos(), dom_pos);
            if(distance_to_dom <= 255 && dom_pos != ZERO_VECTOR) //on same sim or inrange
            {
                if(distance_to_dom > leash_length)
                {
                    if(!target_id) target_id = llTarget(dom_pos, 1.0);
                    llMoveToTarget(dom_pos, 0.4);
                    
                    if(distance_check_time > 2) //timer was slowed restore to defualt
                    {
                        distance_check_time = 2;
                        llSetTimerEvent(distance_check_time);   
                    }
                }
            }
            else
            {
                if(distance_check_time == 2)
                {
                    distance_check_time = 8; //no dom is in distance or on sim slow timer to save resources
                    llSetTimerEvent(distance_check_time);
                }   
            }   
        }
        else //running with no dom key stop every thing....
        {
            llSetTimerEvent(0);
            unleash();   
        }
    }
}
