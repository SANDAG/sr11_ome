//Running with base network
//VOT x2
//Updates
//**************
// Unmet demand
// Wait time look up tables
// With bi-conjugate assignment
// POE congested time used for subsquent hour
// Implement first hour preload
// moved parameters to front
// split SP into SE (SENTRI) and RE (Ready)
// Use queue formula "0.5 *(Volume - (Lanes * ProcRate))*(60/ProcRate)/Lanes" instead of lookup tables
// Add stacked lanes (_STL) and stacked rate VPH (_STV) to the poe_rates
// Changed wait time reported to not include processing and transit time FF_TIME[]
// v6 - Added additional DELAY to OM trucks
// v7 - Limit FAST to 5 lanes at OM
// v8 - Added PM penalty for OM trucks
// v9 - Increase negative toll-increments to speed toll decrement after peaks.
// v10 - Read max lanes from POE_RATES input for each hour
//       Drop the previous average volume at iteration 20 to try to speed up convergence.
// v11 - Remove iteration 20 average volume change.
// v12 - reduce damping on toll adjustments
// v13 - Fixed error in lane balance logic that could result in negative lanes.
// v14 - Add parameter for trip table scaling

//Beginning of Toll Model Macro
Macro "POEDelay"    // Initialization
RunMacro("TCB Init")

scenarios = {"17Baseline"}

//set up loop for scenarios

for alts = 1 to scenarios.length do

        // Input Files
    
    parentfolder = "E:\\SANDAG\\_17BaselineConstrained2\\"
    data_in_dir =  parentfolder + "data_in\\"
    data_out_dir = parentfolder + "data_out\\"
    
    highway_layer = parentfolder + "Network\\b2050OME.dbd"
    turn_penalty_type = data_in_dir + "tpenalt.dbf"
    capacity_table = data_in_dir + "Capacity.dbf"
    poe_rates_table = data_in_dir + "poe_rates_constrain0327.csv"    
    
    // Output Files
	
    assgn_file_path = data_out_dir + scenarios[alts] + "_da_assign.bin" 
	
        // Set Output Table File
	log_file_path = data_out_dir + scenarios[alts] + "_poe_traffic.csv"
	
	run_file_path = data_out_dir + scenarios[alts] + "_run_file.csv"
	
	restart_file_path = data_out_dir + scenarios[alts] + "_restart_file.csv"

	do_toll = 1
	do_ome = 1
	
	max_xing_time = 20
	max_iterations = 40
	convergence_criteria = 0.01
	cnt_poe_links = 11
	if (do_ome) then cnt_poe_links = 18

	nb_pov_min_toll = 0
	sb_pov_min_toll = 0
	nb_trk_min_toll = 0
	sb_trk_min_toll = 0

	if (do_toll) then do
		nb_pov_min_toll = 2
		sb_pov_min_toll = 1
		nb_trk_min_toll = 10
		sb_trk_min_toll = 5
	end
	
	//Setup base processing time
	if alts = 1 then do  //for 2017
		FF_TIME = {7.2,6.52,6.12,6.12,7.2,6.52,6.12,6.12,12,10,8,7.2,6.52,6.12,6.12,12,10,8}
		Add_Delay = {0,0,0,0,0,0,0,0,30,30,0,0,0,0,0,0,0,0}
		PM_PEN = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
		end
	if alts = 2 then do  //for 2030
		FF_TIME = {7.2,6.52,6.12,6.12,7.2,6.52,6.12,6.12,12,10,8,7.2,6.52,6.12,6.12,12,10,8}
		Add_Delay = {0,0,0,0,0,0,0,0,35,35,0,0,0,0,0,0,0,0}
		PM_PEN = {0,0,0,0,0,0,0,0,10,10,0,0,0,0,0,0,0,0}
		end
	if alts = 3 then do  //for 2040
		FF_TIME = {7.2,6.52,6.12,6.12,7.2,6.52,6.12,6.12,12,10,8,7.2,6.52,6.12,6.12,12,10,8}
		Add_Delay = {0,0,0,0,0,0,0,0,40,40,0,0,0,0,0,0,0,0}
		PM_PEN = {0,0,0,0,0,0,0,0,20,20,0,0,0,0,0,0,0,0}
		end
	DELAY = CopyArray(Add_Delay)

	POE_NAME = {"SY","OM"}
	if (do_ome) then POE_NAME = {"SY","OM","OME"}
	LANE_TYPE = {"POV_GP","POV_RE","POV_SE","POV_SB","COM_GP","COM_SP","COM_SB"}
	FLOW_TYPE = {"Tot_Flow"}
	PRELOAD = {440,160,30,0,130,20,0,0,0,0,0}
	if (do_ome) then PRELOAD = {440,160,30,0,130,20,0,0,0,0,0,0,0,0,0,0,0,0}
	
	rate_names = {"SY_GP_VEH","SY_RE_VEH","SY_SE_VEH","SY_SB_VEH","OM_GP_VEH","OM_RE_VEH","OM_SE_VEH","OM_SB_VEH","OMC_GP_VEH",
	"OMC_SP_VEH","OMC_SB_VEH"}
	lane_names = {"SY_GP_OPEN","SY_RE_OPEN","SY_SE_OPEN","SY_SB_OPEN","OM_GP_OPEN","OM_RE_OPEN","OM_SE_OPEN","OM_SB_OPEN","OMC_GP_OPEN",
	"OMC_SP_OPEN","OMC_SB_OPEN"}
	stack_rate_names = {"SY_GP_STV","SY_RE_STV","SY_SE_STV","SY_SB_STV","OM_GP_STV","OM_RE_STV","OM_SE_STV","OM_SB_STV","OMC_GP_STV",
	"OMC_SP_STV","OMC_SB_STV"}
	stack_lane_names = {"SY_GP_STL","SY_RE_STL","SY_SE_STL","SY_SB_STL","OM_GP_STL","OM_RE_STL","OM_SE_STL","OM_SB_STL","OMC_GP_STL",
	"OMC_SP_STL","OMC_SB_STL"}
	max_lane_names = {"SY_GP_MAX","SY_RE_MAX","SY_SE_MAX","SY_SB_MAX","OM_GP_MAX","OM_RE_MAX","OM_SE_MAX","OM_SB_MAX","OMC_GP_MAX",
	"OMC_SP_MAX","OMC_SB_MAX"}

	if (do_ome) then do
		rate_names = {"SY_GP_VEH","SY_RE_VEH","SY_SE_VEH","SY_SB_VEH","OM_GP_VEH","OM_RE_VEH","OM_SE_VEH","OM_SB_VEH","OMC_GP_VEH",
		"OMC_SP_VEH","OMC_SB_VEH","OME_GP_VEH","OME_RE_VEH","OME_SE_VEH","OME_SB_VEH","OMEC_GP_VEH",
		"OMEC_SP_VEH","OMEC_SB_VEH"}
		lane_names = {"SY_GP_OPEN","SY_RE_OPEN","SY_SE_OPEN","SY_SB_OPEN","OM_GP_OPEN","OM_RE_OPEN","OM_SE_OPEN","OM_SB_OPEN","OMC_GP_OPEN",
		"OMC_SP_OPEN","OMC_SB_OPEN","OME_GP_OPEN","OME_RE_OPEN","OME_SE_OPEN","OME_SB_OPEN","OMEC_GP_OPEN",
		"OMEC_SP_OPEN","OMEC_SB_OPEN"}
		stack_rate_names = {"SY_GP_STV","SY_RE_STV","SY_SE_STV","SY_SB_STV","OM_GP_STV","OM_RE_STV","OM_SE_STV","OM_SB_STV","OMC_GP_STV",
		"OMC_SP_STV","OMC_SB_STV","OME_GP_STV","OME_RE_STV","OME_SE_STV","OME_SB_STV","OMEC_GP_STV",
		"OMEC_SP_STV","OMEC_SB_STV"}
		stack_lane_names = {"SY_GP_STL","SY_RE_STL","SY_SE_STL","SY_SB_STL","OM_GP_STL","OM_RE_STL","OM_SE_STL","OM_SB_STL","OMC_GP_STL",
		"OMC_SP_STL","OMC_SB_STL","OME_GP_STL","OME_RE_STL","OME_SE_STL","OME_SB_STL","OMEC_GP_STL",
		"OMEC_SP_STL","OMEC_SB_STL"}
		max_lane_names = {"SY_GP_MAX","SY_RE_MAX","SY_SE_MAX","SY_SB_MAX","OM_GP_MAX","OM_RE_MAX","OM_SE_MAX","OM_SB_MAX","OMC_GP_MAX",
		"OMC_SP_MAX","OMC_SB_MAX","OME_GP_MAX","OME_RE_MAX","OME_SE_MAX","OME_SB_MAX","OMEC_GP_MAX",
		"OMEC_SP_MAX","OMEC_SB_MAX"}
	end
	toll_names = {"POV_TOLL","TRK_TOLL"}
	
	min_lanes = {1,1,0.5,3,1,1,0.5,2,0.5,0.5,4,1,1,0.5,3,0.5,0.5,4}
	inc_lanes = {0.5,0.5,0.5,0,0.5,0.5,0.5,0,0.5,0.5,0,0.5,0.5,0.5,0,0.5,0.5,0}
	// read from input //max_lanes = {33,33,33,3,13,13,13,2,10,5,4,10,10,10,3,10,10,4}
	stack_lanes = {14,14,0,0,0,0,0,0,0,0,0,10,10,0,0,0,0,0}

	min_wait = {25,15,5,0,25,15,5,0,18,12,0,5,5,5,0,5,5,0}
	max_wait = {45,25,20,0,45,25,20,0,28,19,0,10,10,10,0,10,10,0}
	max_gen_wait = 120

	lanes_group = {1,1,1,0,2,2,2,0,3,3,0,4,4,4,0,5,5,0}
	balance_factor = {1,1.45,0,0,1,1.45,0,0,1,1.22,0,1,1.1,1.25,0,1,1.2,0}
	
	trips_scale = 1.0
	
    map = RunMacro("G30 new map", highway_layer, "False")
    layers = GetDBlayers(highway_layer)
    nlayer = layers[1]
    llayer = layers[2]

    db_nodelyr = highway_layer + "|" + nlayer
    db_linklyr = highway_layer + "|" + llayer

    SetLayer(llayer)
    SetView(llayer)
    
    //Update Travel Time, Capacity, Alpha, and Beta
        
        CAPACITY = OpenTable("CAPACITY","DBASE", {capacity_table})
        CAPexp="String(FUNCCODE)" 	              //from DBASE
        LYRexp="String(IFC)"                 //from llayer
        CAPlink = CreateExpression(CAPACITY,"CAPlink",CAPexp,)
        LYRlink = CreateExpression(llayer,"AB_Link",LYRexp,)
        CAPView = JoinViews("CapView",llayer + ".AB_Link","CAPACITY.CAPlink",)
        
        
       // Centroid links are populated with unlimited capacity
        
            rec = GetFirstRecord(CAPView + "|",)
               
               while rec <> null do
           	
                  _Alpha = CAPView.F_ALPHA
           	      _Beta  = CAPView.F_BETA
            
               if CAPView.IFC = 10 then do
				   _AB_Cap = 9999
				   _BA_Cap = 9999 
				   _ABFF_TIME = CAPView.Length/ CAPView.ISPD * 60 //AB Time on bi-directional links
				   _BAFF_TIME = CAPView.Length/ CAPView.ISPD * 60 //BA Time on bi-directional links
				   SetRecordValues(CAPView,rec,{{"Preload",0},{"AB_Cap",_AB_Cap},{"BA_CAP",_BA_Cap},{"ALPHA_",_Alpha},
				   {"BETA_",_Beta},{"ABFF_TIME",_ABFF_TIME},{"BAFF_TIME",_BAFF_TIME}})
			   end
               
               
               if CAPView.IFC > 10 then do
				_ABFF_TIME = CAPView.Length/ CAPView.ISPD * 60
				_BAFF_TIME = CAPView.Length/ CAPView.ISPD * 60
				SetRecordValues(CAPView,rec,{{"Preload",0},{"ALPHA_",_Alpha},
				   {"BETA_",_Beta},{"ABFF_TIME",_ABFF_TIME},{"BAFF_TIME",_BAFF_TIME}})
			   end
		
	       if CAPView.IFC < 10 then do	       
			   if CAPView.Dir = 1  then _AB_Cap = ((CAPView.ABLNO* CAPView.ABPLC + CAPView.ABAU* 1200)*1.05)  //SANDAG Capacity/Lane 
			   if CAPView.Dir = -1 then _BA_Cap = ((CAPView.BALNO* CAPView.BAPLC + CAPView.BAAU* 1200)*1.05)  //SANDAG Capacity/Lane 
			   if CAPView.Dir = 0  then _AB_Cap = ((CAPView.ABLNO* CAPView.ABPLC + CAPView.ABAU* 1200)*1.05)  //SANDAG Capacity/Lane 
			   if CAPView.Dir = 0  then _BA_Cap = ((CAPView.BALNO* CAPView.BAPLC + CAPView.BAAU* 1200)*1.05)  //SANDAG Capacity/Lane 

			   if CAPView.IHOV >1 and CAPView.Dir =1 then _AB_Cap = CAPView.AB_Cap + 1600  //Adjustment for HOV lane, 1600 lane capacity/hour
			   if CAPView.IHOV >1 and CAPView.Dir =-1 then _BA_Cap = CAPView.BA_Cap + 1600 //Adjustment for HOV lane, 1600 lane capacity/hour         

			   if CAPView.Dir = 1  then _ABFF_TIME = CAPView.Length/ CAPView.ISPD * 60 //AB Time populated on active links
			   if CAPView.Dir = -1 then _BAFF_TIME = CAPView.Length/ CAPView.ISPD * 60 //BA Time populated on active links
			   if CAPView.Dir = 0  then _ABFF_TIME = CAPView.Length/ CAPView.ISPD * 60 //AB Time on bi-directional links
			   if CAPView.Dir = 0  then _BAFF_TIME = CAPView.Length/ CAPView.ISPD * 60 //BA Time on bi-directional links 	      
				   SetRecordValues(CAPView,rec,{{"Preload",0},{"AB_Cap",_AB_Cap},{"BA_CAP",_BA_Cap},{"ALPHA_",_Alpha},
				   {"BETA_",_Beta},{"ABFF_TIME",_ABFF_TIME},{"BAFF_TIME",_BAFF_TIME}})
	       end
           
           _Alpha = null
           _Beta = null
           _AB_Cap = null
           _BA_Cap = null
           _ABFF_TIME = null
           _BAFF_TIME = null
      
           rec = GetNextRecord(CAPView + "|",rec,)
               
           end //while rec <> null do
       CloseView("CAPView")     

//GET POE CAPACITY

ptype = RunMacro("G30 table type", poe_rates_table)
pth = SplitPath(poe_rates_table)
ratevw = OpenTable(pth[3], ptype, {poe_rates_table})

rh = LocateRecord(ratevw + "|","TIME",{1},{{"Exact","True"}})
rates = GetRecordValues(ratevw,rh,rate_names)
lanes = GetRecordValues(ratevw,rh,lane_names)
open_lanes = GetRecordValues(ratevw,rh,lane_names)
stk_rates = GetRecordValues(ratevw,rh,stack_rate_names)
stk_lanes = GetRecordValues(ratevw,rh,stack_lane_names)
max_lanes = GetRecordValues(ratevw,rh,max_lane_names)
CloseView(ratevw)

SetView(llayer)
	   
//UPDATE POE LINKS WITH INITIAL FREE FLOW TIMES AND POE CAPACITY
//UPDATE PRELOAD TO ZERO

time_period = 0
skip_restart = 1
// PARAMETERS
 
	dim nb_pov_toll[25]
	dim sb_pov_toll[25]
	dim nb_trk_toll[25]
	dim sb_trk_toll[25]

	nb_pov_toll[1] = nb_pov_min_toll
	sb_pov_toll[1] = sb_pov_min_toll
	nb_trk_toll[1] = nb_trk_min_toll
	sb_trk_toll[1] = sb_trk_min_toll
	

	//If restart file exists then open it.
	f_info = GetFileInfo(restart_file_path)
	if f_info <> null then do
		skip_restart = 0
		mtype = RunMacro("G30 table type", restart_file_path)
		mth = SplitPath(restart_file_path)
		restart_file_vw = OpenTable(mth[3], mtype, {restart_file_path})
		rec2 = GetFirstRecord(restart_file_vw + "|",)
	end
	else do
		log_file_vw = CreateTable("poe_traffic", log_file_path,"CSV", {{"Time","Integer",8,null},{"POE","String",8,null},
		{"Lane","String",8,null},{"Open","Real",8,2},{"Stacked","Real",8,2},{"Volume","Real",8,2},{"Capacity","Real",8,2},{"Unmet","Real",8,2},
		{"Wait_Time","Real",8,2},{"NB_POV_Toll","Real",8,2},{"NB_Trk_Toll","Real",8,2},{"SB_POV_Toll","Real",8,2},
		{"SB_Trk_Toll","Real",8,2}})
		
		run_file_vw = CreateTable("run_file", run_file_path,"CSV", {{"Time","Integer",8,null},{"POE","String",8,null},
		{"Lane","String",8,null},{"Open","Real",8,2},{"Stacked","Real",8,2},{"Capacity","Integer",8,null},{"Iteration","Integer",8,null},{"Tot_Vol","Real",8,2},
		{"Avg_Vol","Real",8,2},{"Toll_Log","Integer",8,null},{"Wait","Real",8,2},{"NB_POV_Toll","Real",8,2},{"NB_Trk_Toll","Real",8,2},
		{"SB_POV_Toll","Real",8,2},{"SB_Trk_Toll","Real",8,2}})
	end


	counter = 1
	For i = 1 to POE_NAME.Length do
		For j = 1 to LANE_TYPE.Length do
			SetView(llayer)
			set_sql = "Select * where POE = '" + POE_NAME[i] + "' and POE_Lane = '" + LANE_TYPE[j] + "'"
			n2 = SelectByQuery(POE_NAME[i] + "_" + LANE_TYPE[j],"Several",set_sql,)
			if n2 > 0 then do
				if skip_restart = 1 then do //If no restart file then load default info to POE links
					rec = GetFirstRecord(llayer + "|" + POE_NAME[i] + "_" + LANE_TYPE[j],)
					if lanes[counter][2] = 0 then AdjFF_TIME = 9999 else AdjFF_TIME = FF_TIME[counter] + DELAY[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					SetRecordValues(llayer,rec,{{"ABFF_TIME",AdjFF_TIME},{"BAFF_TIME",AdjFF_TIME},{"Preload",PRELOAD[counter]},
					{"AB_Cap",adj_cap},{"ABLNO",lanes[counter][2]}})
				end
				if skip_restart = 0 then do //If restart file then load restart info to POE links
					rec = GetFirstRecord(llayer + "|" + POE_NAME[i] + "_" + LANE_TYPE[j],)
					if restart_file_vw.Lanes = 0 then AdjWait_TIME = 9999 else AdjWait_TIME = restart_file_vw.Wait_Time
					time_period = restart_file_vw.Time
					if (time_period = 16) then AdjWait_TIME = AdjWait_TIME + PM_PEN[counter]
					if (time_period = 20) then AdjWait_TIME = AdjWait_TIME - PM_PEN[counter]
					SetRecordValues(llayer,rec,{{"ABFF_TIME",AdjWait_TIME},{"BAFF_TIME",AdjWait_TIME},{"Preload",restart_file_vw.Unmet},
					{"AB_Cap",restart_file_vw.Capacity},{"ABLNO",restart_file_vw.Lanes}})
					lanes[counter][2] = restart_file_vw.Lanes
					stk_lanes[counter][2] = restart_file_vw.Stacked
					if (do_toll) then do
						nb_pov_toll[time_period] = restart_file_vw.NB_POV_Toll
						sb_pov_toll[time_period] = restart_file_vw.SB_POV_Toll
						nb_trk_toll[time_period] = restart_file_vw.NB_Trk_Toll
						sb_trk_toll[time_period] = restart_file_vw.SB_Trk_Toll
						nb_pov_toll[time_period + 1] = nb_pov_toll[time_period]
						sb_pov_toll[time_period + 1] = sb_pov_toll[time_period]
						nb_trk_toll[time_period + 1] = nb_trk_toll[time_period]
						sb_trk_toll[time_period + 1] = sb_trk_toll[time_period]	
					end

					rec2 = GetNextRecord(restart_file_vw + "|", null,)
				end
				counter = counter + 1
			end
		end	
	end
    
	if skip_restart = 0 then do //If restart file then load lane info for POE links
		ptype = RunMacro("G30 table type", poe_rates_table)
		pth = SplitPath(poe_rates_table)
		ratevw = OpenTable(pth[3], ptype, {poe_rates_table})

		rh = LocateRecord(ratevw + "|","TIME",{time_period + 1},{{"Exact","True"}})
		rates = GetRecordValues(ratevw,rh,rate_names)
		open_lanes = GetRecordValues(ratevw,rh,lane_names)
		stk_rates = GetRecordValues(ratevw,rh,stack_rate_names)
		max_lanes = GetRecordValues(ratevw,rh,max_lane_names)
		CloseView(ratevw)
	end

	//Update toll link with default or restart info
	if (do_toll) then do
		rh = LocateRecord(llayer + "|","ID",{37546},{{"Exact","True"}})
		SetRecordValues(llayer,rh,{{"AB_Toll",nb_pov_toll[time_period + 1]},{"AB_TrkToll",nb_trk_toll[time_period + 1]},{"BA_Toll",sb_pov_toll[time_period + 1]},{"BA_TrkToll",sb_trk_toll[time_period + 1]}})	
	end

//close the maps
maps = GetMapNames()
for i = 1 to maps.length do
CloseMap(maps[i])
end

//close views
vws = GetViewNames()
for i=1 to vws.length do
CloseView(vws[i])
end

	
// SET UP LOOP FOR MODEL PERIODS (use while loop for restart ability)

while time_period < 24 do

	time_period = time_period + 1
	
	converged = 0
	iteration = 0
	dim avg_vol[3,7]
	dim prev_vol[3,7]
	dim last_vol[3,7]
	dim wait_time[3,7]
	dim last_wait[3,7]
	dim prev_wait[3,7]
	dim proc_veh[3,7]	
	
	DELAY = CopyArray(Add_Delay)
	if (time_period > 16 and time_period < 21) then do
		for counter = 1 to DELAY.Length do
			DELAY[counter] = DELAY[counter] + PM_PEN[counter]
		end
	end
	
	assignment_table = data_out_dir + scenarios[alts] + "_assign_" + string(time_period) + ".bin"
	network_file = data_out_dir + scenarios[alts] + "_network_" + string(time_period) + ".net"
	od_matrix = "E:\\SANDAG\\" + "Data_" + scenarios[alts] + "\\Trips_" + string(time_period) + ".mtx"
	
	map = RunMacro("G30 new map", highway_layer, "False")
	layers = GetDBlayers(highway_layer)
	nlayer = layers[1]
	llayer = layers[2]
			
	SetLayer(llayer)
	
	//Toll Estimation Loop
	
While converged = 0 do

	    toll_flag = 0
	    
	    map = RunMacro("G30 new map", highway_layer, "False")
	    layers = GetDBlayers(highway_layer)
	    nlayer = layers[1]
	    llayer = layers[2]
	
	// STEP 1: Build Highway Network
		Opts = null
		Opts.Input.[Link Set] = {db_linklyr, llayer}
		Opts.Global.[Network Options].[Link Type] = {"IFC", llayer + ".IFC", llayer + ".IFC"}
		Opts.Global.[Network Options].[Node ID] = nlayer + ".ID"
		Opts.Global.[Network Options].[Link ID] = llayer + ".ID"
		Opts.Global.[Network Options].[Keep Duplicate Links] = "FALSE"
		Opts.Global.[Network Options].[Ignore Link Direction] = "FALSE"
		Opts.Global.[Network Options].[Time Unit] = "Minutes"
		Opts.Global.[Length Unit] = "Miles"
		Opts.Global.[Link Options] = {{"Length", {llayer + ".Length", llayer + ".Length", , , "False"}},
		{"[ABFF_Time / BAFF_Time]", {llayer + ".ABFF_Time", llayer + ".BAFF_Time", , , "True"}}, 
		{"[AB_Cap / BA_Cap]", {llayer + ".AB_Cap", llayer + ".BA_Cap", , , "False"}},
		{"Preload", {llayer + ".Preload", llayer + ".Preload", , , "False"}},
		{"ALPHA_", {llayer + ".ALPHA_", llayer + ".ALPHA_", , , "False"}},
		{"BETA_", {llayer + ".BETA_", llayer + ".BETA_", , , "False"}}}
		if (do_toll) then Opts.Global.[Link Options] = {{"Length", {llayer + ".Length", llayer + ".Length", , , "False"}},
			{"[ABFF_Time / BAFF_Time]", {llayer + ".ABFF_Time", llayer + ".BAFF_Time", , , "True"}}, 
			{"[AB_Cap / BA_Cap]", {llayer + ".AB_Cap", llayer + ".BA_Cap", , , "False"}},
			{"Preload", {llayer + ".Preload", llayer + ".Preload", , , "False"}},
			{"ALPHA_", {llayer + ".ALPHA_", llayer + ".ALPHA_", , , "False"}},
			{"BETA_", {llayer + ".BETA_", llayer + ".BETA_", , , "False"}},
			{"[AB_Toll / BA_Toll]",{llayer + ".AB_Toll",llayer + ".BA_Toll", , , "False"}},
			{"[AB_TrkToll / BA_TrkToll]", {llayer + ".AB_TrkToll",llayer + ".BA_TrkToll", , , "False"}}}
		Opts.Output.[Network File] = network_file

		ret_value = RunMacro("TCB Run Operation", 1, "Build Highway Network", Opts)

		if !ret_value then goto quit

	// STEP 2: Highway Network Setting
		Opts = null
		Opts.Input.Database = highway_layer
		Opts.Input.Network = network_file
		Opts.Input.[Centroids Set] = {db_nodelyr, nlayer, "Centroid", "Select * where Centroid=1"}
		if (do_toll) then Opts.Input.[Toll Set] = {db_linklyr, llayer, "Toll_Link", "Select * where POE = 'TOLL'"}

		ret_value = RunMacro("TCB Run Operation", 2, "Highway Network Setting", Opts)

		if !ret_value then goto quit

	//OD MATRIX Cores

	//HBO_General
	//HBO_Ready
	//HBO_SENTRI
	//HBW_General
	//HBW_Ready
	//HBW_SENTRI
	//HBS_General
	//HBS_Ready
	//HBS_SENTRI
	//Loaded_GP
	//Loaded_FAST
	//Empty_GP
	//Empty_FAST
	//Ambient

	POE_GP = {db_linklyr, "binational", "POE_GP", "Select * where POE_Lane='POV_RE' or POE_Lane='POV_SE' or POE_Lane='COM_GP' or POE_Lane='COM_SP' or POE_Lane='COM_SB' or POE_LANE=''"}
	POE_RE = {db_linklyr, "binational", "POE_RE", "Select * where POE_Lane='POV_GP' or POE_Lane='POV_SE' or POE_Lane='COM_GP' or POE_Lane='COM_SP' or POE_Lane='COM_SB' or POE_LANE=''"}
	POE_SE = {db_linklyr, "binational", "POE_SE", "Select * where POE_Lane='POV_GP' or POE_Lane='POV_RE' or POE_Lane='COM_GP' or POE_Lane='COM_SP' or POE_Lane='COM_SB' or POE_LANE=''"}
	COM_GP = {db_linklyr, "binational", "COM_GP", "Select * where POE_Lane='POV_GP' or POE_Lane='POV_RE' or POE_Lane='POV_SE' or POE_Lane='COM_SP' or POE_Lane='POV_SB' or POE_LANE=''"}
	COM_SP = {db_linklyr, "binational", "COM_SP", "Select * where POE_Lane='POV_GP' or POE_Lane='POV_RE' or POE_Lane='POV_SE' or POE_Lane='COM_GP' or POE_Lane='POV_SB' or POE_LANE=''"}
	background = {db_linklyr, "binational", "Background", "Select * where POE_Lane <>'All'"}

				
	// STEP 1: MMA
		 Opts = null
		 Opts.Input.Database = highway_layer
		 Opts.Input.Network = network_file
		 Opts.Input.[OD Matrix Currency] = {od_matrix, "HBO_General", "Row index", "Column index"}
		 Opts.Input.[Exclusion Link Sets] = {POE_GP,POE_RE,POE_SE,POE_GP,POE_RE,POE_SE,POE_GP, POE_RE,POE_SE, COM_GP, COM_SP, COM_GP, COM_SP, background}
		 Opts.Field.[Vehicle Classes] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14}
		 if (do_toll) then Opts.Field.[Fixed Toll Fields] = {"[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_Toll / BA_Toll]", "[AB_TrkToll / BA_TrkToll]", "[AB_TrkToll / BA_TrkToll]", "[AB_TrkToll / BA_TrkToll]", "[AB_TrkToll / BA_TrkToll]","n/a"}
		 Opts.Field.[PCE Fields] = {"None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None", "None"}
		 Opts.Field.[VDF Fld Names] = {"[ABFF_TIME / BAFF_TIME]", "[AB_CAP / BA_CAP]", "ALPHA_", "BETA_", "Preload"}
		 Opts.Global.[Load Method] = "NCFW"
		 Opts.Global.[N Conjugate] = 2
		 Opts.Global.[Loading Multiplier] = trips_scale
		 Opts.Global.Convergence = convergence_criteria
		 Opts.Global.Iterations = 7
		 Opts.Global.[Number of Classes] = 14
		 Opts.Global.[Class PCEs] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1}
		 Opts.Global.[Class VOIs] = {0.125, 0.395, 0.395, 0.112, 0.168, 0.168, 0.142, 0.21, 0.21, 0.312, 0.542, 0.312, 0.542, 0.166}  
		 Opts.Global.[Cost Function File] = "bpr.vdf"
		 Opts.Global.[VDF Defaults] = {, , 0.15, 4, 0}
		 Opts.Output.[Flow Table] = assignment_table


		 ret_value = RunMacro("TCB Run Procedure", "MMA", Opts, &Ret)

		 if !ret_value then goto quit
	
	//WAIT, LANES, TOLL ADJUST LOOPS
	
		//LOOP THROUGH POE LINKS FOR WAIT TIME COMPUTATION	
					
		rtype = RunMacro("G30 table type", run_file_path)
		rth = SplitPath(run_file_path)
		run_file_vw = OpenTable(rth[3], rtype, {run_file_path})
		
		linklyr = llayer + ".ID"

		atype = RunMacro("G30 table type", assignment_table)
		ath = SplitPath(assignment_table)
		avw = OpenTable(ath[3], atype, {assignment_table})

		avwlyr = avw + ".ID1"

		link_view = JoinViews("Link_View_" + string(time_period), linklyr, avwlyr,{{"E",}})

		counter = 1
		For i = 1 to POE_NAME.Length do
			For j = 1 to LANE_TYPE.Length do
				SetView(link_view)
				set_sql = "Select * where POE = '" + POE_NAME[i] + "' and POE_Lane = '" + LANE_TYPE[j] + "'"
				n2 = SelectByQuery(POE_NAME[i] + "_" + LANE_TYPE[j],"Several",set_sql,)
				if n2 > 0 then do
					rec = GetFirstRecord(link_view + "|" + POE_NAME[i] + "_" + LANE_TYPE[j],)
					volume = GetRecordValues(link_view,rec,{"AB_FLOW"})
					preload = GetRecordValues(link_view,rec,{"Preload"})
					tot_vol = volume[1][2] + preload[1][2]
					capacity = GetRecordValues(link_view,rec,{"AB_Cap"})
					
					prev_vol[i][j] = avg_vol[i][j]
					
					//Method of Successive Averages
					
					factor = 1 / (iteration + 1)
					factor1 = iteration / (iteration + 1)
					if iteration = 0 then avg_vol[i][j] = tot_vol
					if iteration > 0 then avg_vol[i][j] = (avg_vol[i][j] * factor1) + (tot_vol * factor)
					
					last_vol[i][j] = tot_vol

					//CHECK CONVERGENCE AGAINST PREVIOUS VOLUME
					
					if (iteration > 0) then do 
						if avg_vol[i][j] > 0 then if Abs((avg_vol[i][j] - prev_vol[i][j]) / avg_vol[i][j]) < 0.02 then toll_flag = toll_flag + 1
						if avg_vol[i][j] = 0 and prev_vol[i][j] = 0 then toll_flag = toll_flag + 1
						if iteration > max_iterations|toll_flag = cnt_poe_links then converged = 1
					end
							
					//Wait time by formula
					if avg_vol[i][j] > 0 then do
							if open_lanes[1][2] > 0 then wait_time[i][j] = Max((0.5 * (avg_vol[i][j] - capacity[1][2]) * (60/capacity[1][2])), 0) + FF_TIME[counter] + DELAY[counter]
							else wait_time[i][j] = 999
						end
					else do
						wait_time[i][j] = FF_TIME[counter] + DELAY[counter]
						end
										
					if avg_vol[i][j] > 0 then proc_veh[i][j] = Max(avg_vol[i][j] - capacity[1][2], 0)
						else do
						proc_veh[i][j] = 0
						end	
			
					if lanes[counter][2] = 0 then AdjWait_TIME = 9999 else AdjWait_TIME = wait_time[i][j]	
			
					//UPDATE WAIT TIME IN HIGHWAY FILE

					SetRecordValues(link_view,rec,{{"ABFF_TIME",AdjWait_TIME}})

					if lanes[counter][2] = 0 then LogWait_TIME = 9999 else LogWait_TIME = wait_time[i][j] - FF_TIME[counter]	
					
					//UPDATE LOG FILE
					record_handle = AddRecord(run_file_vw, {{"Time",time_period},{"POE",POE_NAME[i]},{"Lane",LANE_TYPE[j]},{"Iteration",iteration},
					{"Open",lanes[counter][2]},{"Capacity",capacity[1][2]},{"Tot_Vol",tot_vol},{"Avg_Vol",avg_vol[i][j]},{"Toll_Log",toll_flag},
					{"Wait",LogWait_TIME},{"Stacked",stk_lanes[counter][2]}})			
					
					counter = counter + 1
				end

				rec = null
				rec1 = null
				volume = 0
				tot_vol = 0
				value = null
			end
		end //WAIT TIME STORED
		
		if converged then goto converged_flag
		
	//RECOMPUTE LANES ALLOCATIONS
		
		//SY-NB POV
		lane_sum = 0
		poe = 1
		
		//SENTRI
		lantyp = 3
		counter = lantyp
		while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
			lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
			adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
			wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
		end
		while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2] - 2))  do
			lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
			adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
			wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
		end
		sentri_lanes = lanes[counter][2]
		
		//GENERAL and READY
		for lantyp = 1 to 2 do
			counter = lantyp
			while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
				if (stk_lanes[counter][2] > 0) then stk_lanes[counter][2] = stk_lanes[counter][2] - inc_lanes[counter]
				else lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
				adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
				wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
			end
			while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (stk_lanes[counter][2] < (max_lanes[counter][2] - sentri_lanes)) do
				if (lanes[counter][2] < max_lanes[counter][2] - sentri_lanes) then lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
				else stk_lanes[counter][2] = stk_lanes[counter][2] + inc_lanes[counter]
				adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
				wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
			end
			lane_sum = lane_sum + lanes[counter][2]
		end

		//BALANCE SY READY AND GENERAL
		sentri_ctr = 3
		ready_ctr = 2
		gen_ctr = 1
		gen_type = 1
		ready_type = 2
		
		lane_avail = max_lanes[gen_ctr][2] - sentri_lanes
		if (lane_sum > lane_avail) then do

			lanes[ready_ctr][2] = round((lanes[ready_ctr][2] * (lane_avail) / lane_sum) *2, 0) /2
			stk_lanes[ready_ctr][2] = min(lanes[ready_ctr][2], stk_lanes[ready_ctr][2])
			adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
			ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
			while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
				stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
				adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
				ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
			end

			lanes[gen_ctr][2] = round((lanes[gen_ctr][2] * (lane_avail) / lane_sum *2), 0) /2
			stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])
			adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
			gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
			while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
				stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
				adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
				gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
			end

			while gen_wait < max_gen_wait and (ready_wait * balance_factor[ready_ctr]) > (gen_wait * balance_factor[gen_ctr]) and (lanes[gen_ctr][2] > min_lanes[gen_ctr]) do
				lanes[ready_ctr][2] = lanes[ready_ctr][2] + max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
				stk_lanes[ready_ctr][2] = 0
				lanes[gen_ctr][2] = lanes[gen_ctr][2] - max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
				stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])

				adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
				ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
				while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
					stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
					adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
					ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
				end
				
				adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
				gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
				while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
					stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
					adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
					gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
				end
			end

			wait_time[poe][ready_type] = ready_wait + FF_TIME[ready_ctr] + DELAY[ready_ctr]
			wait_time[poe][gen_type] = gen_wait + FF_TIME[gen_ctr] + DELAY[gen_ctr]

		end //balance ready and general
			
		//OM-NB POV
		lane_sum = 0
		poe = 2
		
		//SENTRI
		lantyp = 3
		counter = lantyp + 4
		if lanes[counter][2] > 0 then do
			while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
				lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
				adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
				wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
			end
			while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2] - 2)) do
				lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
				adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
				wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
			end
		end
		sentri_lanes = lanes[counter][2]
		
		//GENERAL and READY
		for lantyp = 1 to 2 do
			counter = lantyp + 4
			if lanes[counter][2] > 0 then do
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
					lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2] - sentri_lanes)) do
					lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
			end
			lane_sum = lane_sum + lanes[counter][2]
		end

		//BALANCE OM READY AND GENERAL
		sentri_ctr = 3 + 4
		ready_ctr = 2 + 4
		gen_ctr = 1 + 4
		gen_type = 1
		ready_type = 2
		
		lane_avail = max_lanes[gen_ctr][2] - sentri_lanes
		if (lane_sum > lane_avail) then do

			lanes[ready_ctr][2] = round((lanes[ready_ctr][2] * (lane_avail) / lane_sum)*2, 0)/2
			adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
			ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)

			lanes[gen_ctr][2] = round((lanes[gen_ctr][2] * (lane_avail) / lane_sum)*2, 0)/2
			adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
			gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)

			while gen_wait < max_gen_wait and (ready_wait * balance_factor[ready_ctr]) > (gen_wait * balance_factor[gen_ctr]) and (lanes[gen_ctr][2] > min_lanes[gen_ctr]) do
				lanes[ready_ctr][2] = lanes[ready_ctr][2] + max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
				lanes[gen_ctr][2] = lanes[gen_ctr][2] - max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])

				adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
				ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
				
				adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
				gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
			end

			wait_time[poe][ready_type] = ready_wait + FF_TIME[ready_ctr] + DELAY[ready_ctr]
			wait_time[poe][gen_type] = gen_wait + FF_TIME[gen_ctr] + DELAY[gen_ctr]

		end //balance ready and general
			
		//OM GP Truck and FAST
		lane_sum = 0
		for lantyp = 5 to 6 do
			counter = lantyp + 4
			if lanes[counter][2] > 0 then do
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
					lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2])) do
					lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
			end
			lane_sum = lane_sum + lanes[counter][2]
		end

		//BALANCE OM FAST AND GP Truck
		fast_ctr = 6 + 4
		gp_ctr = 5 + 4
		gp_type = 5
		fast_type = 6
		
		lane_avail = max_lanes[gp_ctr][2]
		if (lane_sum > lane_avail) then do

			lanes[fast_ctr][2] = round((lanes[fast_ctr][2] * (lane_avail) / lane_sum)*2, 0)/2
			adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
			fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)

			lanes[gp_ctr][2] = round((lanes[gp_ctr][2] * (lane_avail) / lane_sum)*2, 0)/2
			adj_cap = Max((rates[gp_ctr][2] * (lanes[gp_ctr][2]-stk_lanes[gp_ctr][2]))+(stk_rates[gp_ctr][2] * stk_lanes[gp_ctr][2]),1)
			gp_wait = Max((0.5 * (avg_vol[poe][gp_type] - adj_cap) * (60/adj_cap)), 0)

			while gp_wait < max_gen_wait and (fast_wait * balance_factor[fast_ctr]) > (gp_wait * balance_factor[gp_ctr]) and lanes[fast_ctr][2] < max_lanes[fast_ctr][2] do
				lanes[fast_ctr][2] = lanes[fast_ctr][2] + max(inc_lanes[gp_ctr], inc_lanes[fast_ctr])
				lanes[gp_ctr][2] = lanes[gp_ctr][2] - max(inc_lanes[gp_ctr], inc_lanes[fast_ctr])

				adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
				fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)
				
				adj_cap = Max((rates[gp_ctr][2] * (lanes[gp_ctr][2]-stk_lanes[gp_ctr][2]))+(stk_rates[gp_ctr][2] * stk_lanes[gp_ctr][2]),1)
				gp_wait = Max((0.5 * (avg_vol[poe][gp_type] - adj_cap) * (60/adj_cap)), 0)
			end

			wait_time[poe][fast_type] = fast_wait + FF_TIME[fast_ctr] + DELAY[fast_ctr]
			wait_time[poe][gp_type] = gp_wait + FF_TIME[gp_ctr] + DELAY[gp_ctr]

		end //OM balance FAST and GP Truck
		
		if do_ome then do
			if do_toll then do
				//OME-NB POV
				lane_sum = 0
				poe = 3
				
				//SENTRI
				lantyp = 3
				counter = lantyp + 11
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) and nb_pov_toll[time_period] = nb_pov_min_toll do
					lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2] - 1))  do
					lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
				lane_sum = lane_sum + lanes[counter][2]
				
				//GENERAL and READY
				for lantyp = 1 to 2 do
					counter = lantyp + 11
					while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) and nb_pov_toll[time_period] = nb_pov_min_toll do
						if (stk_lanes[counter][2] > 0) then stk_lanes[counter][2] = stk_lanes[counter][2] - inc_lanes[counter]
						else lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
						adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
						wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
					end
					while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (stk_lanes[counter][2] < (max_lanes[counter][2] - 1)) do
						if (lanes[counter][2] < max_lanes[counter][2] - 1) then lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
						else stk_lanes[counter][2] = stk_lanes[counter][2] + inc_lanes[counter]
						adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
						wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
					end
					lane_sum = lane_sum + lanes[counter][2]
				end

				//BALANCE SENTRI, READY AND GENERAL
				sentri_ctr = 3 + 11
				ready_ctr = 2 + 11
				gen_ctr = 1 + 11
				gen_type = 1 
				ready_type = 2
				sentri_type = 3
				
				lane_avail = max_lanes[gen_ctr][2]
				if (lane_sum = lane_avail) and (nb_pov_toll[time_period] > nb_pov_min_toll) then do

					adj_cap = Max((rates[sentri_ctr][2] * (lanes[sentri_ctr][2]-stk_lanes[sentri_ctr][2]))+(stk_rates[sentri_ctr][2] * stk_lanes[sentri_ctr][2]),1)
					sentri_wait = Max((0.5 * (avg_vol[poe][sentri_type] - adj_cap) * (60/adj_cap)), 0)
					while sentri_wait < min_wait[sentri_ctr] and lanes[sentri_ctr][2] > min_lanes[sentri_ctr] do
						lanes[sentri_ctr][2] = lanes[sentri_ctr][2] - inc_lanes[sentri_ctr]
						stk_lanes[sentri_ctr][2] = 0
						lanes[ready_ctr][2] = lanes[ready_ctr][2] + inc_lanes[sentri_ctr]
						stk_lanes[ready_ctr][2] = lanes[ready_ctr][2]

						adj_cap = Max((rates[sentri_ctr][2] * (lanes[sentri_ctr][2]-stk_lanes[sentri_ctr][2]))+(stk_rates[sentri_ctr][2] * stk_lanes[sentri_ctr][2]),1)
						sentri_wait = Max((0.5 * (avg_vol[poe][sentri_type] - adj_cap) * (60/adj_cap)), 0)
						
						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					end

					adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
					ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					while ready_wait < min_wait[ready_ctr] and lanes[ready_ctr][2] > min_lanes[ready_ctr] do
						lanes[ready_ctr][2] = lanes[ready_ctr][2] - inc_lanes[ready_ctr]
						stk_lanes[ready_ctr][2] = lanes[ready_ctr][2]
						lanes[gen_ctr][2] = lanes[gen_ctr][2] + inc_lanes[ready_ctr]
						stk_lanes[gen_ctr][2] = lanes[gen_ctr][2]

						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					end

					adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
					gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
					while (ready_wait * balance_factor[ready_ctr]) > (gen_wait * balance_factor[gen_ctr]) and lanes[gen_ctr][2] > min_lanes[gen_ctr] do
						lanes[ready_ctr][2] = lanes[ready_ctr][2] + max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
						//stk_lanes[ready_ctr][2] = 0
						lanes[gen_ctr][2] = lanes[gen_ctr][2] - max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
						stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])

						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
							stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
							adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
							ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						end
						
						adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
						gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
						while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
							stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
							adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
							gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
						end
					end

					while (sentri_wait * balance_factor[sentri_ctr]) > (ready_wait * balance_factor[ready_ctr]) and lanes[ready_ctr][2] > min_lanes[ready_ctr] do
						lanes[sentri_ctr][2] = lanes[sentri_ctr][2] + max(inc_lanes[ready_ctr], inc_lanes[sentri_ctr])
						stk_lanes[sentri_ctr][2] = 0
						lanes[ready_ctr][2] = lanes[ready_ctr][2] - max(inc_lanes[ready_ctr], inc_lanes[sentri_ctr])
						stk_lanes[ready_ctr][2] = min(lanes[ready_ctr][2], stk_lanes[ready_ctr][2])

						adj_cap = Max((rates[sentri_ctr][2] * (lanes[sentri_ctr][2]-stk_lanes[sentri_ctr][2]))+(stk_rates[sentri_ctr][2] * stk_lanes[sentri_ctr][2]),1)
						sentri_wait = Max((0.5 * (avg_vol[poe][sentri_type] - adj_cap) * (60/adj_cap)), 0)
						
						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
							stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
							adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
							ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						end
					end

					wait_time[poe][sentri_type] = sentri_wait + FF_TIME[sentri_ctr] + DELAY[sentri_ctr]
					wait_time[poe][ready_type] = ready_wait + FF_TIME[ready_ctr] + DELAY[ready_ctr]
					wait_time[poe][gen_type] = gen_wait + FF_TIME[gen_ctr] + DELAY[gen_ctr]

				end //balance sentri, ready and general lanes=avail and toll>min

				if (lane_sum > lane_avail) then do

					lanes[sentri_ctr][2] = round((lanes[sentri_ctr][2] * (lane_avail) / lane_sum) *2, 0) /2
					adj_cap = Max((rates[sentri_ctr][2] * (lanes[sentri_ctr][2]-stk_lanes[sentri_ctr][2]))+(stk_rates[sentri_ctr][2] * stk_lanes[sentri_ctr][2]),1)
					sentri_wait = Max((0.5 * (avg_vol[poe][sentri_type] - adj_cap) * (60/adj_cap)), 0)

					lanes[ready_ctr][2] = round((lanes[ready_ctr][2] * (lane_avail) / lane_sum) *2, 0) /2
					stk_lanes[ready_ctr][2] = min(lanes[ready_ctr][2], stk_lanes[ready_ctr][2])
					adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
					ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
						stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					end

					lanes[gen_ctr][2] = round((lanes[gen_ctr][2] * (lane_avail) / lane_sum *2), 0) /2
					stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])
					adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
					gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
					while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
						stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
						adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
						gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
					end

					while (ready_wait * balance_factor[ready_ctr]) > (gen_wait * balance_factor[gen_ctr]) and lanes[gen_ctr][2] > min_lanes[gen_ctr] do
						lanes[ready_ctr][2] = lanes[ready_ctr][2] + max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
						stk_lanes[ready_ctr][2] = 0
						lanes[gen_ctr][2] = lanes[gen_ctr][2] - max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
						stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])

						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
							stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
							adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
							ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						end
						
						adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
						gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
						while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
							stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
							adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
							gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
						end
					end

					while (sentri_wait * balance_factor[sentri_ctr]) > (ready_wait * balance_factor[ready_ctr]) and lanes[ready_ctr][2] > min_lanes[ready_ctr] do
						lanes[sentri_ctr][2] = lanes[sentri_ctr][2] + max(inc_lanes[ready_ctr], inc_lanes[sentri_ctr])
						stk_lanes[sentri_ctr][2] = 0
						lanes[ready_ctr][2] = lanes[ready_ctr][2] - max(inc_lanes[ready_ctr], inc_lanes[sentri_ctr])
						stk_lanes[ready_ctr][2] = min(lanes[ready_ctr][2], stk_lanes[ready_ctr][2])

						adj_cap = Max((rates[sentri_ctr][2] * (lanes[sentri_ctr][2]-stk_lanes[sentri_ctr][2]))+(stk_rates[sentri_ctr][2] * stk_lanes[sentri_ctr][2]),1)
						sentri_wait = Max((0.5 * (avg_vol[poe][sentri_type] - adj_cap) * (60/adj_cap)), 0)
						
						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
							stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
							adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
							ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						end
					end

					wait_time[poe][sentri_type] = sentri_wait + FF_TIME[sentri_ctr] + DELAY[sentri_ctr]
					wait_time[poe][ready_type] = ready_wait + FF_TIME[ready_ctr] + DELAY[ready_ctr]
					wait_time[poe][gen_type] = gen_wait + FF_TIME[gen_ctr] + DELAY[gen_ctr]

				end //balance sentri, ready and general lanes>avail
			end //OME POV Toll
			
			if not do_toll then do
				//OME-NB POV
				lane_sum = 0
				poe = 3
				
				//SENTRI
				lantyp = 3
				counter = lantyp + 11
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
					lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
				while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2] - 2))  do
					lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
				end
				sentri_lanes = lanes[counter][2]
				
				//GENERAL and READY
				for lantyp = 1 to 2 do
					counter = lantyp + 11
					while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) do
						if (stk_lanes[counter][2] > 0) then stk_lanes[counter][2] = stk_lanes[counter][2] - inc_lanes[counter]
						else lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
						adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
						wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
					end
					while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (stk_lanes[counter][2] < (max_lanes[counter][2] - sentri_lanes)) do
						if (lanes[counter][2] < max_lanes[counter][2] - sentri_lanes) then lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
						else stk_lanes[counter][2] = stk_lanes[counter][2] + inc_lanes[counter]
						adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
						wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
					end
					lane_sum = lane_sum + lanes[counter][2]
				end

				//BALANCE OME READY AND GENERAL
				sentri_ctr = 3 + 11
				ready_ctr = 2 + 11
				gen_ctr = 1 + 11
				gen_type = 1
				ready_type = 2
				
				lane_avail = max_lanes[gen_ctr][2] - sentri_lanes
				if (lane_sum > lane_avail) then do

					lanes[ready_ctr][2] = round((lanes[ready_ctr][2] * (lane_avail) / lane_sum) *2, 0) /2
					stk_lanes[ready_ctr][2] = min(lanes[ready_ctr][2], stk_lanes[ready_ctr][2])
					adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
					ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
						stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
					end

					lanes[gen_ctr][2] = round((lanes[gen_ctr][2] * (lane_avail) / lane_sum *2), 0) /2
					stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])
					adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
					gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
					while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
						stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
						adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
						gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
					end

					while gen_wait < max_gen_wait and (ready_wait * balance_factor[ready_ctr]) > (gen_wait * balance_factor[gen_ctr]) and lanes[gen_ctr][2] > min_lanes[gen_ctr] do
						lanes[ready_ctr][2] = lanes[ready_ctr][2] + max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
						stk_lanes[ready_ctr][2] = 0
						lanes[gen_ctr][2] = lanes[gen_ctr][2] - max(inc_lanes[gen_ctr], inc_lanes[ready_ctr])
						stk_lanes[gen_ctr][2] = min(lanes[gen_ctr][2], stk_lanes[gen_ctr][2])

						adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
						ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						while ready_wait > max_wait[ready_ctr] and stk_lanes[ready_ctr][2] < lanes[ready_ctr][2] do
							stk_lanes[ready_ctr][2] = stk_lanes[ready_ctr][2] + inc_lanes[ready_ctr]
							adj_cap = Max((rates[ready_ctr][2] * (lanes[ready_ctr][2]-stk_lanes[ready_ctr][2]))+(stk_rates[ready_ctr][2] * stk_lanes[ready_ctr][2]),1)
							ready_wait = Max((0.5 * (avg_vol[poe][ready_type] - adj_cap) * (60/adj_cap)), 0)
						end
						
						adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
						gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
						while gen_wait > max_wait[gen_ctr] and stk_lanes[gen_ctr][2] < lanes[gen_ctr][2] do
							stk_lanes[gen_ctr][2] = stk_lanes[gen_ctr][2] + inc_lanes[gen_ctr]
							adj_cap = Max((rates[gen_ctr][2] * (lanes[gen_ctr][2]-stk_lanes[gen_ctr][2]))+(stk_rates[gen_ctr][2] * stk_lanes[gen_ctr][2]),1)
							gen_wait = Max((0.5 * (avg_vol[poe][gen_type] - adj_cap) * (60/adj_cap)), 0)
						end
					end

					wait_time[poe][ready_type] = ready_wait + FF_TIME[ready_ctr] + DELAY[ready_ctr]
					wait_time[poe][gen_type] = gen_wait + FF_TIME[gen_ctr] + DELAY[gen_ctr]

				end //balance ready and general
			end //not toll

		//OME GP Truck and FAST
			lane_sum = 0
			for lantyp = 5 to 6 do
				counter = lantyp + 11
				if lanes[counter][2] > 0 then do
					while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] < min_wait[counter]) and (lanes[counter][2] > min_lanes[counter]) and (nb_trk_toll[time_period] = nb_trk_min_toll) do
						lanes[counter][2] = lanes[counter][2] - inc_lanes[counter]
						adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
						wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
					end
					while (wait_time[poe][lantyp] - FF_TIME[counter] - DELAY[counter] > max_wait[counter]) and (lanes[counter][2] < (max_lanes[counter][2])) do
						lanes[counter][2] = lanes[counter][2] + inc_lanes[counter]
						adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
						wait_time[poe][lantyp] = Max((0.5 * (avg_vol[poe][lantyp] - adj_cap) * (60/adj_cap)), 0) + FF_TIME[counter] + DELAY[counter]
					end
				end
				lane_sum = lane_sum + lanes[counter][2]
			end

			//BALANCE OME FAST AND GP Truck
			fast_ctr = 6 + 11
			gp_ctr = 5 + 11
			gp_type = 5
			fast_type = 6
			
			lane_avail = max_lanes[gp_ctr][2]
			if (lane_sum = lane_avail) and (nb_trk_toll[time_period] > nb_trk_min_toll) then do

				adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
				fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)
				while fast_wait < min_wait[fast_ctr] and lanes[fast_ctr][2] > min_lanes[fast_ctr] do
					lanes[fast_ctr][2] = lanes[fast_ctr][2] - inc_lanes[fast_ctr]
					lanes[gp_ctr][2] = lanes[gp_ctr][2] + inc_lanes[fast_ctr]

					adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
					fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)
				end
					
				adj_cap = Max((rates[gp_ctr][2] * (lanes[gp_ctr][2]-stk_lanes[gp_ctr][2]))+(stk_rates[gp_ctr][2] * stk_lanes[gp_ctr][2]),1)
				gp_wait = Max((0.5 * (avg_vol[poe][gp_type] - adj_cap) * (60/adj_cap)), 0)

				while gp_wait < max_gen_wait and (fast_wait * balance_factor[fast_ctr]) > (gp_wait * balance_factor[gp_ctr]) and lanes[gp_ctr][2] > min_lanes[gp_ctr] do
					lanes[fast_ctr][2] = lanes[fast_ctr][2] + max(inc_lanes[gp_ctr], inc_lanes[fast_ctr])
					lanes[gp_ctr][2] = lanes[gp_ctr][2] - max(inc_lanes[gp_ctr], inc_lanes[fast_ctr])

					adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
					fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)
					
					adj_cap = Max((rates[gp_ctr][2] * (lanes[gp_ctr][2]-stk_lanes[gp_ctr][2]))+(stk_rates[gp_ctr][2] * stk_lanes[gp_ctr][2]),1)
					gp_wait = Max((0.5 * (avg_vol[poe][gp_type] - adj_cap) * (60/adj_cap)), 0)
				end
				wait_time[poe][fast_type] = fast_wait + FF_TIME[fast_ctr] + DELAY[fast_ctr]
				wait_time[poe][gp_type] = gp_wait + FF_TIME[gp_ctr] + DELAY[gp_ctr]

			end //OME balance FAST and GP Truck lanes=avail and toll>min
			
			if (lane_sum > lane_avail) then do

				lanes[fast_ctr][2] = round((lanes[fast_ctr][2] * (lane_avail) / lane_sum)*2, 0)/2
				adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
				fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)

				lanes[gp_ctr][2] = round((lanes[gp_ctr][2] * (lane_avail) / lane_sum)*2, 0)/2
				adj_cap = Max((rates[gp_ctr][2] * (lanes[gp_ctr][2]-stk_lanes[gp_ctr][2]))+(stk_rates[gp_ctr][2] * stk_lanes[gp_ctr][2]),1)
				gp_wait = Max((0.5 * (avg_vol[poe][gp_type] - adj_cap) * (60/adj_cap)), 0)

				while gp_wait < max_gen_wait and (fast_wait * balance_factor[fast_ctr]) > (gp_wait * balance_factor[gp_ctr]) and lanes[gp_ctr][2] > min_lanes[gp_ctr] do
					lanes[fast_ctr][2] = lanes[fast_ctr][2] + max(inc_lanes[gp_ctr], inc_lanes[fast_ctr])
					lanes[gp_ctr][2] = lanes[gp_ctr][2] - max(inc_lanes[gp_ctr], inc_lanes[fast_ctr])

					adj_cap = Max((rates[fast_ctr][2] * (lanes[fast_ctr][2]-stk_lanes[fast_ctr][2]))+(stk_rates[fast_ctr][2] * stk_lanes[fast_ctr][2]),1)
					fast_wait = Max((0.5 * (avg_vol[poe][fast_type] - adj_cap) * (60/adj_cap)), 0)
					
					adj_cap = Max((rates[gp_ctr][2] * (lanes[gp_ctr][2]-stk_lanes[gp_ctr][2]))+(stk_rates[gp_ctr][2] * stk_lanes[gp_ctr][2]),1)
					gp_wait = Max((0.5 * (avg_vol[poe][gp_type] - adj_cap) * (60/adj_cap)), 0)
				end

				wait_time[poe][fast_type] = fast_wait + FF_TIME[fast_ctr] + DELAY[fast_ctr]
				wait_time[poe][gp_type] = gp_wait + FF_TIME[gp_ctr] + DELAY[gp_ctr]

			end //OME balance FAST and GP Truck

		end //OME adjust/balance
		
	//LOOP THROUGH POE LINKS TO ADJUST LANE ALLOCATIONS
		counter = 1
		For i = 1 to POE_NAME.Length do
			For j = 1 to LANE_TYPE.Length do
				SetView(link_view)
				set_sql = "Select * where POE = '" + POE_NAME[i] + "' and POE_Lane = '" + LANE_TYPE[j] + "'"
				n2 = SelectByQuery(POE_NAME[i] + "_" + LANE_TYPE[j],"Several",set_sql,)
				if n2 > 0 then do
					rec = GetFirstRecord(link_view + "|" + POE_NAME[i] + "_" + LANE_TYPE[j],)
					
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					if lanes[counter][2] = 0 then AdjWait_TIME = 9999 else AdjWait_TIME = wait_time[i][j]	
			
					if lanes[counter][2] = 0 then last_wait[i][j] = 0
					else last_wait[i][j] = Max((0.5 * (last_vol[i][j] - adj_cap) * (60/adj_cap)), 0)	

					SetRecordValues(llayer,rec,{{"AB_Cap",adj_cap},{"ABLNO",lanes[counter][2]},{"ABFF_TIME",AdjWait_TIME}})

					capacity = GetRecordValues(link_view,rec,{"AB_Cap"})

					if lanes[counter][2] = 0 then LogWait_TIME = 9999 else LogWait_TIME = wait_time[i][j] - FF_TIME[counter]	
					//UPDATE LOG FILE
					record_handle = AddRecord(run_file_vw, {{"Time",time_period},{"POE",POE_NAME[i]},{"Lane",LANE_TYPE[j]},{"Iteration",iteration},
					{"Open",lanes[counter][2]},{"Stacked",stk_lanes[counter][2]},{"Capacity",capacity[1][2]},{"Avg_Vol",avg_vol[i][j]},{"Wait",LogWait_TIME}})			

					counter = counter + 1
				end
			end
		end

	//LOOP THROUGH POE LINKS TO ADJUST TOLLS
		if (do_toll) then do

			factor = 1 / (iteration + 1) * 2
			For i = 1 to POE_NAME.Length do
				For j = 1 to LANE_TYPE.Length do
					//UPDATE NB POV TOLL

					if i = 3 and j = 3 and iteration > 0 then do
					
						if mean({avg_vol[3][1],avg_vol[3][2],avg_vol[3][3]}) > 0 then do 
							max_wait_time = max(wait_time[3][1],wait_time[3][2])
							end
							else max_wait_time = 0
						toll_increment = ceil((max_wait_time - max_xing_time) * 0.167 *2)/2
						if (toll_increment <= -1) then toll_increment = toll_increment * 2
						if (toll_increment < 0) then toll_increment = toll_increment * 2
						nb_pov_toll[time_period] = nb_pov_toll[time_period] + (toll_increment * factor)
						if nb_pov_toll[time_period] < nb_pov_min_toll then nb_pov_toll[time_period] = nb_pov_min_toll				
						
						//Update toll link
						rh = LocateRecord(llayer + "|","ID",{37546},{{"Exact","True"}})
						SetRecordValues(llayer,rh,{{"AB_Toll",nb_pov_toll[time_period]}})
					end
					
					//UPDATE SB POV TOLL
					
					if i = 3 and j = 4 and iteration > 0 then do
					
						toll_increment = ceil((wait_time[3][4] - max_xing_time) * 0.167 *2)/2
						if (toll_increment <= -1) then toll_increment = toll_increment * 2
						if (toll_increment < 0) then toll_increment = toll_increment * 2
						sb_pov_toll[time_period] = sb_pov_toll[time_period] + (toll_increment * factor)
						if sb_pov_toll[time_period] < sb_pov_min_toll then sb_pov_toll[time_period] = sb_pov_min_toll
						
						//Update toll link
						rh = LocateRecord(llayer + "|","ID",{37546},{{"Exact","True"}})
						SetRecordValues(llayer,rh,{{"BA_Toll",sb_pov_toll[time_period]}})
					end
					
					//UPDATE NB TRK TOLL
					
					if i = 3 and j = 6 and iteration > 0 then do
					
						if mean({avg_vol[3][5],avg_vol[3][6]}) > 0 then do 
							max_wait_time = max(wait_time[3][5],wait_time[3][6])
							end
							else max_wait_time = 0
						toll_increment = ceil((max_wait_time - max_xing_time) * 0.334 *2)/2		
						if (toll_increment <= -1) then toll_increment = toll_increment * 2
						if (toll_increment < 0) then toll_increment = toll_increment * 2
						nb_trk_toll[time_period] = nb_trk_toll[time_period] + (toll_increment * factor)
						if nb_trk_toll[time_period] < nb_trk_min_toll then nb_trk_toll[time_period] = nb_trk_min_toll
						
						//Update toll link
						rh = LocateRecord(llayer + "|","ID",{37546},{{"Exact","True"}})
						SetRecordValues(llayer,rh,{{"AB_TrkToll",nb_trk_toll[time_period]}})

					end
					
					//UPDATE SB TRK TOLL
					
					if i = 3 and j = 7 and iteration > 0 then do
					
						toll_increment = ceil((wait_time[3][7] - max_xing_time) * 0.334 *2)/2	
						if (toll_increment <= -1) then toll_increment = toll_increment * 2
						if (toll_increment < 0) then toll_increment = toll_increment * 2
						sb_trk_toll[time_period] = sb_trk_toll[time_period] + (toll_increment * factor)
						if sb_trk_toll[time_period] < sb_trk_min_toll then sb_trk_toll[time_period] = sb_trk_min_toll
						
						//Update toll link
						rh = LocateRecord(llayer + "|","ID",{37546},{{"Exact","True"}})
						SetRecordValues(llayer,rh,{{"BA_TrkToll",sb_trk_toll[time_period]}})

					end

					//UPDATE LOG FILE
					record_handle = AddRecord(run_file_vw, {{"Time",time_period},{"POE",POE_NAME[i]},{"Lane",LANE_TYPE[j]},{"Iteration",iteration},
					{"NB_POV_Toll",nb_pov_toll[time_period]},{"NB_Trk_Toll",nb_trk_toll[time_period]},
					{"SB_POV_Toll",sb_pov_toll[time_period]},{"SB_Trk_Toll",sb_trk_toll[time_period]}})			
	
				end
			end
		end  //(do_toll)
		
	converged_flag:
	
	CloseView(run_file_vw)
	
	iteration = iteration + 1
	
	//UPDATE PRELOAD, LANECAP, OPEN LANES FOR NEXT TIME PERIOD IF CONVERGED
	
	if converged = 1 then do
	
		mtype = RunMacro("G30 table type", log_file_path)
		mth = SplitPath(log_file_path)
		log_file_vw = OpenTable(mth[3], mtype, {log_file_path})

		counter = 1
		SetView(llayer)
		For i = 1 to POE_NAME.Length do
			For j = 1 to LANE_TYPE.Length do
				set_sql = "Select * where POE = '" + POE_NAME[i] + "' and POE_Lane = '" + LANE_TYPE[j] + "'"
				n2 = SelectByQuery(POE_NAME[i] + "_" + LANE_TYPE[j],"Several",set_sql,)
				if n2 > 0 then do
					rec = GetFirstRecord(llayer + "|" + POE_NAME[i] + "_" + LANE_TYPE[j],)
					lane_cap = GetRecordValues(link_view,rec,{"AB_Cap"})
					log_wait_time = wait_time[i][j] - FF_TIME[counter]
					
					//Write out results
					record_handle = AddRecord(log_file_vw, {{"Time",time_period},{"POE",POE_NAME[i]},{"Lane",LANE_TYPE[j]},{"Open",lanes[counter][2]},
					{"Stacked",stk_lanes[counter][2]},{"Volume",avg_vol[i][j]},
					{"Capacity",lane_cap[1][2]},{"Wait_Time",log_wait_time},{"Unmet",proc_veh[i][j]},{"NB_POV_Toll",nb_pov_toll[time_period]},
					{"NB_Trk_Toll",nb_trk_toll[time_period]},{"SB_POV_Toll",sb_pov_toll[time_period]},{"SB_Trk_Toll",sb_trk_toll[time_period]}})

					counter = counter + 1
					
				end
			end	
		end	

		ptype = RunMacro("G30 table type", poe_rates_table)
		pth = SplitPath(poe_rates_table)
		ratevw = OpenTable(pth[3], ptype, {poe_rates_table})

		rh = LocateRecord(ratevw + "|","TIME",{time_period + 1},{{"Exact","True"}})
		rates = GetRecordValues(ratevw,rh,rate_names)
		open_lanes = GetRecordValues(ratevw,rh,lane_names)
		stk_rates = GetRecordValues(ratevw,rh,stack_rate_names)
		max_lanes = GetRecordValues(ratevw,rh,max_lane_names)
		CloseView(ratevw)

		restart_file_vw = CreateTable("restart_file", restart_file_path,"CSV", {{"Time","Integer",8,null},{"POE","String",8,null},
		{"Lane","String",8,null},{"Lanes","Real",8,2},{"Stacked","Real",8,2},{"Capacity","Real",8,2},{"Unmet","Real",8,2},
		{"Wait_Time","Real",8,2},{"NB_POV_Toll","Real",8,2},{"NB_Trk_Toll","Real",8,2},{"SB_POV_Toll","Real",8,2},
		{"SB_Trk_Toll","Real",8,2}})

		skip_restart = 1
		counter = 1
		SetView(llayer)
		For i = 1 to POE_NAME.Length do
			For j = 1 to LANE_TYPE.Length do
				set_sql = "Select * where POE = '" + POE_NAME[i] + "' and POE_Lane = '" + LANE_TYPE[j] + "'"
				n2 = SelectByQuery(POE_NAME[i] + "_" + LANE_TYPE[j],"Several",set_sql,)
				if n2 > 0 then do
					rec = GetFirstRecord(llayer + "|" + POE_NAME[i] + "_" + LANE_TYPE[j],)
					tot_vol = GetRecordValues(link_view,rec,{"Tot_Flow"})
					lane_cap = GetRecordValues(link_view,rec,{"AB_Cap"})
					if open_lanes[counter][2] = 0 then do
						lanes[counter][2] = 0
						stk_lanes[counter][2] = 0
						end
					else if lanes[counter][2] = 0 then lanes[counter][2] = open_lanes[counter][2]
					
					adj_cap = Max((rates[counter][2] * (lanes[counter][2]-stk_lanes[counter][2]))+(stk_rates[counter][2] * stk_lanes[counter][2]),1)
					log_wait_time = wait_time[i][j] - FF_TIME[counter]
					last_fftime = GetRecordValues(link_view,rec,{"ABFF_TIME"})
					new_wait_time = last_fftime[1][2]

					SetRecordValues(llayer,rec,{{"Preload",proc_veh[i][j]},{"AB_Cap",adj_cap},{"ABLNO",lanes[counter][2]}})
					if lanes[counter][2] = 0 then SetRecordValues(llayer,rec,{{"ABFF_TIME",9999}})
					if lanes[counter][2] <> 0 and last_fftime[1][2] > 9000 then do
						if (i>1 and j<4) then new_wait_time = wait_time[1][j]
						else new_wait_time = FF_TIME[counter] + DELAY[counter]
						SetRecordValues(llayer,rec,{{"ABFF_TIME",new_wait_time}})
					end
					
					if (time_period = 16) then do
						new_wait_time = new_wait_time + PM_PEN[counter]
						SetRecordValues(llayer,rec,{{"ABFF_TIME",new_wait_time}})
					end
					
					if (time_period = 20) then do
						new_wait_time = new_wait_time - PM_PEN[counter]
						SetRecordValues(llayer,rec,{{"ABFF_TIME",new_wait_time}})
					end
					
					//Save restart info to jump start the model from this hour
					record_handle = AddRecord(restart_file_vw, {{"Time",time_period},{"POE",POE_NAME[i]},{"Lane",LANE_TYPE[j]},{"Lanes",lanes[counter][2]},
					{"Stacked",stk_lanes[counter][2]},
					{"Capacity",adj_cap},{"Wait_Time",wait_time[i][j]},{"Unmet",proc_veh[i][j]},{"NB_POV_Toll",nb_pov_toll[time_period]},
					{"NB_Trk_Toll",nb_trk_toll[time_period]},{"SB_POV_Toll",sb_pov_toll[time_period]},{"SB_Trk_Toll",sb_trk_toll[time_period]}})	

					counter = counter + 1
					avg_vol[i][j] = null
					prev_vol[i][j] = null
					
				end
			end	
		end	

		nb_pov_toll[time_period + 1] = nb_pov_toll[time_period]
		sb_pov_toll[time_period + 1] = sb_pov_toll[time_period]
		nb_trk_toll[time_period + 1] = nb_trk_toll[time_period]
		sb_trk_toll[time_period + 1] = sb_trk_toll[time_period]	

	end
	
	//close the maps
	maps = GetMapNames()
	for i = 1 to maps.length do
	CloseMap(maps[i])
	end
	
	//close views
	vws = GetViewNames()
	for i=1 to vws.length do
	CloseView(vws[i])
	end

end		//End toll estimation loop
	
//close the maps
maps = GetMapNames()
for i = 1 to maps.length do
CloseMap(maps[i])
end

//close views
vws = GetViewNames()
for i=1 to vws.length do
CloseView(vws[i])
end

end //TIME PERIOD

	//close the maps
	maps = GetMapNames()
	for i = 1 to maps.length do
	CloseMap(maps[i])
	end
	  
	//close views
	vws = GetViewNames()
	for i=1 to vws.length do
	CloseView(vws[i])
	end
	
	//Delete restart file after a completed model run
	DeleteTableFiles("CSV", restart_file_path,)

//end alt scenario loop	
end

    quit:
    Return( RunMacro("TCB Closing", ret_value, True ) )
 
  
endMacro
